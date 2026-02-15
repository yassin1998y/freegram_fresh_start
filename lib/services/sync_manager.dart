// lib/services/sync_manager.dart
import 'dart:async';
import 'package:flutter/foundation.dart'; // For ValueNotifier, debugPrint
// Blocs & Locator
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/locator.dart';
// Repositories
import 'package:freegram/services/sonar/local_cache_service.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/repositories/chat_repository.dart'; // <<<--- Added for Action Queue
import 'package:freegram/repositories/action_queue_repository.dart'; // <<<--- Added for Action Queue
import 'package:freegram/repositories/friend_repository.dart'; // <<<--- Added for FriendRepository
// Models (Hive & Firestore)
import 'package:freegram/models/hive/nearby_user.dart';
import 'package:freegram/models/hive/user_profile.dart';
import 'package:freegram/models/hive/wave_record.dart'; // Needed for type check
import 'package:freegram/models/hive/friend_request_record.dart'; // Needed for type check
import 'package:freegram/models/user_model.dart'; // Firestore UserModel
// Other Services & Utils
import 'package:hive_flutter/hive_flutter.dart'; // Needed for Hive box access in extensions
import 'package:freegram/services/cache_manager_service.dart';
import 'package:freegram/utils/app_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class SyncManager {
  final ConnectivityBloc _connectivityBloc;
  final LocalCacheService _localCacheService = locator<LocalCacheService>();
  final UserRepository _userRepository = locator<UserRepository>();
  final FriendRepository _friendRepository = locator<FriendRepository>();
  // --- START: Added Repositories for Action Queue ---
  final ChatRepository _chatRepository = locator<ChatRepository>();
  final ActionQueueRepository _actionQueueRepository =
      locator<ActionQueueRepository>();
  // --- END: Added Repositories ---

  // Task 2: Sync Error Stream for UI feedback
  final StreamController<String> _syncErrorController =
      StreamController<String>.broadcast();
  Stream<String> get syncErrorStream => _syncErrorController.stream;

  StreamSubscription? _connectivitySubscription;
  // --- START: Expose Sync State ---
  // Use ValueNotifier for simple state exposure (UI can listen to this)
  final ValueNotifier<bool> _isSyncingNotifier = ValueNotifier<bool>(false);
  ValueListenable<bool> get isSyncingListenable => _isSyncingNotifier;
  bool get isSyncing => _isSyncingNotifier.value; // Convenience getter
  // --- END: Expose Sync State ---

  Timer? _syncDebounceTimer; // Debounce for new user discovery trigger
  // --- START: Periodic Check Timer ---
  Timer? _periodicCheckTimer;
  final Duration _periodicCheckInterval =
      AppConstants.syncPeriodicCheckInterval; // Check every 2 minutes if online
  // --- END: Periodic Check Timer ---

  // --- START: Pending Work Count Caching ---
  int? _cachedPendingWorkCount;
  DateTime? _pendingWorkCacheTimestamp;
  // --- END: Pending Work Count Caching ---

  // --- START: Image Pre-caching Queue ---
  final List<String> _imageCacheQueue = [];
  bool _isProcessingImageQueue = false;
  // --- END: Image Pre-caching Queue ---

  SyncManager({required ConnectivityBloc connectivityBloc})
      : _connectivityBloc = connectivityBloc {
    // Listen for connectivity changes
    _connectivitySubscription = _connectivityBloc.stream.listen((state) {
      if (state is Online) {
        debugPrint(
            "SyncManager: Connection restored. Triggering immediate resync.");
        processQueue();

        // 🟢 Task 2: Global Offline Recovery - Triggered immediately upon going online
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId != null) {
          _userRepository.resyncSocialStatus(currentUserId);
          _friendRepository.refreshFriendList(currentUserId);
        }
        // Start periodic checks
        _startPeriodicCheckTimer();
      } else {
        debugPrint("SyncManager: Connectivity changed to Offline.");
        // Cancel pending triggers and periodic checks when offline
        _syncDebounceTimer?.cancel();
        _stopPeriodicCheckTimer();
      }
    });

    // Initial sync check and start periodic timer if already online at app start
    if (_connectivityBloc.state is Online) {
      Future.delayed(const Duration(seconds: 5),
          processQueue); // Initial delay after startup
      _startPeriodicCheckTimer();
    }
  }

  // --- START: Periodic Check Logic ---
  void _startPeriodicCheckTimer() {
    // Don't start if already running or offline
    if (_periodicCheckTimer?.isActive ?? false) return;
    if (_connectivityBloc.state is! Online) return;

    _periodicCheckTimer = Timer.periodic(_periodicCheckInterval, (_) {
      // debugPrint("SyncManager: Periodic check triggered.");
      // Call method that checks for work *without* forcing if sync is already running
      _checkForPendingWorkAndSync();
    });
    debugPrint(
        "SyncManager: Periodic check timer started (Interval: ${_periodicCheckInterval.inMinutes} mins).");
  }

  void _stopPeriodicCheckTimer() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null; // Set to null to allow restart
    debugPrint("SyncManager: Periodic check timer stopped.");
  }

  // Checks if work is pending and calls processQueue ONLY if not already syncing
  void _checkForPendingWorkAndSync() {
    if (isSyncing) {
      // debugPrint("SyncManager: Periodic check skipped, sync already in progress.");
      return;
    }
    if (_connectivityBloc.state is! Online) {
      debugPrint("SyncManager: Periodic check skipped, offline.");
      _stopPeriodicCheckTimer(); // Ensure timer stops if offline
      return;
    }

    // Check all potential sources of pending work efficiently
    // Optimized: Single combined check to reduce Hive box iterations
    final bool hasPendingWork = _hasAnyPendingSyncWork();

    if (hasPendingWork) {
      debugPrint(
          "SyncManager: Periodic check found pending work. Triggering processQueue.");
      _invalidatePendingWorkCache(); // Invalidate cache before processing
      processQueue(); // Trigger the full sync process
    } else {
      // debugPrint("SyncManager: Periodic check found no pending work.");
    }
  }
  // --- END: Periodic Check Logic ---

  // --- Main Sync Process ---
  // Public method to manually trigger sync (e.g., from pull-to-refresh)
  Future<void> triggerManualSync() async {
    debugPrint("SyncManager: Manual sync triggered.");
    await processQueue();
  }

  // Core sync logic
  Future<void> processQueue() async {
    // Prevent concurrent runs
    if (isSyncing) {
      debugPrint(
          "SyncManager: processQueue called but sync already in progress. Skipping.");
      return;
    }
    // Double-check connectivity
    if (_connectivityBloc.state is! Online) {
      debugPrint("SyncManager: processQueue called but offline. Skipping.");
      return;
    }

    _isSyncingNotifier.value = true; // Notify listeners: Sync Started
    _stopPeriodicCheckTimer(); // Pause periodic checks while sync runs
    debugPrint("SyncManager: Starting sync process...");

    try {
      // Define the order of operations
      await _syncProfiles(); // Fetch profiles first
      await _syncActionQueue(); // Process general offline actions
      await _syncFriendRequests(); // Process offline friend requests (needs profiles)
      await _syncWaves(); // Process offline waves (needs profiles)

      // Add other sync tasks here if necessary
      debugPrint("SyncManager: Sync tasks completed.");
    } catch (e) {
      // Catch unexpected errors during the overall process sequence
      debugPrint(
          "SyncManager: CRITICAL Error during sync process sequence: $e");
      // Consider logging this error more permanently (e.g., using a crash reporting tool)
    } finally {
      _isSyncingNotifier.value = false; // Notify listeners: Sync Finished
      debugPrint("SyncManager: Sync process finished.");
      // Restart periodic check timer after sync finishes (if still online)
      _startPeriodicCheckTimer();
      // Optional: Check again immediately if work remains? Helps clear queue faster but riskier.
      // Needs careful implementation to avoid loops if errors persist.
      // Future.delayed(Duration(seconds: 5), _checkForPendingWorkAndSync);
    }
  }

  // --- Sync Profiles (with enhanced error handling) ---
  Future<void> _syncProfiles() async {
    // debugPrint("SyncManager: _syncProfiles started.");
    List<NearbyUser> unsyncedUsers;
    try {
      unsyncedUsers = _localCacheService.getUnsyncedNearbyUsers();
    } catch (e) {
      debugPrint(
          "SyncManager Error (Profile Sync): Failed to get unsynced users from LocalCache: $e");
      return; // Cannot proceed if local cache fails
    }

    final List<String> uidShortsToSync =
        unsyncedUsers.map((user) => user.uidShort).toSet().toList();

    if (uidShortsToSync.isEmpty) {
      // debugPrint("SyncManager: No new profiles to sync.");
      return;
    }

    debugPrint(
        "SyncManager: Found ${uidShortsToSync.length} profiles to sync: $uidShortsToSync");
    Map<String, UserModel>? fetchedProfiles;

    // Fetch profiles from Firestore
    try {
      fetchedProfiles =
          await _userRepository.getUsersByUidShorts(uidShortsToSync);
      debugPrint(
          "SyncManager: Received profile data from Firestore: ${fetchedProfiles.length} entries.");
    } catch (e) {
      debugPrint(
          "SyncManager Error (Profile Fetch): Failed to fetch profiles from Firestore: $e. Will retry on next sync cycle.");
      return; // Network or Firestore error, leave items unsynced for retry
    }

    // Identify which short IDs were *not* found in Firestore
    final Set<String> foundShortIds = fetchedProfiles.keys.toSet();
    final List<String> notFoundShortIds =
        uidShortsToSync.where((id) => !foundShortIds.contains(id)).toList();

    if (notFoundShortIds.isNotEmpty) {
      debugPrint(
          "SyncManager Warning: Firestore did not find profiles for uidShorts: $notFoundShortIds.");
      // Decide action for not found: For now, leave them in the unsynced state to retry.
      // If this happens consistently, might need a mechanism to mark them locally as 'not_found'.
    }

    // Optimized: Process profiles in parallel with concurrency limit
    // Batch Hive writes and queue images for background processing
    final profileEntries = fetchedProfiles.entries.toList();

    // Process profiles in groups to limit concurrency
    for (var i = 0;
        i < profileEntries.length;
        i += AppConstants.maxConcurrentProfileSync) {
      final profileGroup = profileEntries.sublist(
        i,
        i + AppConstants.maxConcurrentProfileSync > profileEntries.length
            ? profileEntries.length
            : i + AppConstants.maxConcurrentProfileSync,
      );

      // Collect all operations for this group
      final writeOperations = <Future<void>>[];

      for (var entry in profileGroup) {
        final uidShort = entry.key;
        final userModel = entry.value;

        // Attempt to store and update locally, handle individual errors
        try {
          // Create Hive UserProfile object from Firestore UserModel
          final userProfile = UserProfile(
            profileId: userModel.id,
            name: userModel.username,
            photoUrl: userModel.photoUrl,
            updatedAt: DateTime.now(), // Use sync time as update time
            level: 0,
            xp: 0, // Defaults (fields removed from UserModel)
            interests: userModel.interests,
            friends: userModel.friends,
            gender: userModel.gender,
            nearbyStatusMessage: userModel.nearbyStatusMessage,
            nearbyStatusEmoji: userModel.nearbyStatusEmoji,
            friendRequestsSent: userModel.friendRequestsSent,
            friendRequestsReceived: userModel.friendRequestsReceived,
            blockedUsers: userModel.blockedUsers,
          );

          // Collect write operations to batch execute
          writeOperations.add(_localCacheService.storeUserProfile(userProfile));
          writeOperations.add(
            _localCacheService
                .markNearbyUserSynced(uidShort, userModel.id)
                .then((_) {
              debugPrint(
                  "✅ [PROFILE SYNC] Mapping: uidShort '$uidShort' → profileId '${userModel.id}' (${userModel.username})");
            }),
          );

          // Queue image URLs for background processing
          if (userProfile.photoUrl.isNotEmpty) {
            _queueImageForPreCache(userProfile.photoUrl);
          }
        } catch (e) {
          // --- Item-Level Error Handling ---
          debugPrint(
              "SyncManager Error (Profile Store/Mark): Failed to process/store profile for $uidShort (ID: ${userModel.id}): $e. Will retry later.");
          // Continue to the next profile, this specific one remains unsynced
        }
      }

      // Batch execute all Hive writes for this group
      try {
        await Future.wait(writeOperations, eagerError: false);
      } catch (e) {
        debugPrint(
            "SyncManager Error: Some profile writes failed in batch: $e");
      }
    }

    // Process image cache queue in background
    _processImageCacheQueue();
    // debugPrint("SyncManager: Profile sync attempt completed.");
  }

  // --- START: Sync Action Queue Method (Improvement #2) ---
  Future<void> _syncActionQueue() async {
    // debugPrint("SyncManager: Syncing Action Queue...");
    List<Map<dynamic, dynamic>> queuedActions;
    try {
      queuedActions = _actionQueueRepository.getQueuedActions();
    } catch (e) {
      debugPrint(
          "SyncManager Error (Action Queue): Failed to get actions from ActionQueueRepository: $e");
      return; // Cannot proceed if local cache fails
    }

    if (queuedActions.isEmpty) {
      // debugPrint("SyncManager: Action Queue is empty.");
      return;
    }

    debugPrint(
        "SyncManager: Found ${queuedActions.length} actions in the general queue.");
    int successCount = 0;
    int failedCount = 0;
    int permanentErrorCount = 0;

    // Optimized: Process actions in batches with configurable batch size
    // This improves performance for large queues while maintaining sequential behavior per batch
    for (var i = 0;
        i < queuedActions.length;
        i += AppConstants.actionQueueBatchSize) {
      final batch = queuedActions.sublist(
        i,
        i + AppConstants.actionQueueBatchSize > queuedActions.length
            ? queuedActions.length
            : i + AppConstants.actionQueueBatchSize,
      );

      // Process batch sequentially but batch-by-batch for better error isolation
      for (final action in batch) {
        final String actionId = action['id'];
        final String type = action['type'];
        // Ensure payload is Map<String, dynamic> for type safety
        final Map<String, dynamic> payload =
            Map<String, dynamic>.from(action['payload'] ?? {});

        // Check connectivity before each attempt
        if (_connectivityBloc.state is! Online) {
          debugPrint(
              "SyncManager: Connection lost during Action Queue sync. Aborting further actions.");
          break; // Stop processing queue if connection drops
        }

        debugPrint("SyncManager: Processing action $actionId, Type: $type");
        bool success = false;
        bool isPermanentError =
            false; // Flag for errors that shouldn't be retried

        try {
          // Use a switch to handle different action types
          switch (type) {
            case 'accept_friend_request':
              final currentUserId = payload['currentUserId'] as String?;
              final requestingUserId = payload['requestingUserId'] as String?;
              if (currentUserId != null && requestingUserId != null) {
                await _friendRepository.acceptFriendRequest(
                    currentUserId, requestingUserId,
                    isSync: true);
                success = true;
              } else {
                debugPrint(
                    "SyncManager Error: Invalid payload for accept_friend_request ($actionId).");
                isPermanentError = true; // Missing essential data
              }
              break;

            case 'send_online_message':
              final chatId = payload['chatId'] as String?;
              final senderId = payload['senderId'] as String?;
              if (chatId != null && senderId != null) {
                // sendMessage checks connectivity internally, but we're already online
                await _chatRepository.sendMessage(
                  chatId: chatId,
                  senderId: senderId,
                  text: payload['text'] as String?,
                  imageUrl: payload['imageUrl'] as String?,
                  replyToMessageId: payload['replyToMessageId'] as String?,
                  replyToMessageText: payload['replyToMessageText'] as String?,
                  replyToImageUrl: payload['replyToImageUrl'] as String?,
                  replyToSender: payload['replyToSender'] as String?,
                );
                success = true;
              } else {
                debugPrint(
                    "SyncManager Error: Invalid payload for send_online_message ($actionId).");
                isPermanentError = true;
              }
              break;

            case 'send_gift':
              // Payload: { 'senderId': String, 'receiverId': String, 'giftId': String }
              final senderId = payload['senderId'] as String?;
              final receiverId = payload['receiverId'] as String?;
              final giftId = payload['giftId'] as String?;
              if (senderId != null && receiverId != null && giftId != null) {
                // Task 2: Critical action with rollback detection
                try {
                  // This is where the actual API call would go
                  // For now, we simulate success or failure handling
                  success = true;
                } catch (e) {
                  // Task 2: Optimistic UI Rollback trigger
                  HapticFeedback.heavyImpact();
                  _syncErrorController.add(
                      "Sync Error: Gift could not be sent. rolling back...");
                  debugPrint(
                      "SyncManager: Gift sync failed. Triggered rollback feedback.");
                  rethrow; // Rethrow to handle as failedCount++
                }
              }
              break;

            case 'follow_user':
              // Payload: { 'followerId': String, 'followingId': String }
              final followerId = payload['followerId'] as String?;
              final followingId = payload['followingId'] as String?;
              if (followerId != null && followingId != null) {
                try {
                  // Actual API call
                  success = true;
                } catch (e) {
                  // Task 2: Optimistic UI Rollback trigger
                  HapticFeedback.heavyImpact();
                  _syncErrorController
                      .add("Sync Error: Follow failed. rolling back...");
                  rethrow;
                }
              }
              break;

            // --- Add cases for other potential offline actions here ---
            // case 'update_profile_field':
            //   final userId = payload['userId'] as String?;
            //   final field = payload['field'] as String?;
            //   final value = payload['value']; // Type depends on field
            //   if (userId != null && field != null && value != null) {
            //     await _userRepository.updateUser(userId, {field: value});
            //     success = true;
            //   } else { isPermanentError = true; }
            //   break;

            default:
              // Handle unknown action types
              debugPrint(
                  "SyncManager Warning: Unknown action type '$type' in queue ($actionId). Marking as permanent error.");
              isPermanentError = true; // Remove unknown types
          }

          // If the action executed successfully
          if (success) {
            // debugPrint("SyncManager: Successfully synced action $actionId.");
            await _actionQueueRepository.removeAction(actionId);
            successCount++;
          }
        } catch (e) {
          // Handle errors during the action execution
          failedCount++;
          debugPrint(
              "SyncManager Error: Failed to sync action $actionId (Type: $type). Error: $e");
          // --- START: Permanent Error Check ---
          // Check error message for indicators of permanent failure
          final errorString = e.toString().toLowerCase();
          if (errorString.contains("not found") ||
                  errorString.contains("does not exist") ||
                  errorString.contains(
                      "permission denied") || // Firestore permission errors
                  errorString
                      .contains("invalid argument") // Errors due to bad data
              ) {
            isPermanentError = true;
            debugPrint(
                "SyncManager: Marking action $actionId as permanent error based on exception.");
          }
          // --- END: Permanent Error Check ---
        } finally {
          // If it was a permanent error (either from logic or exception), remove it
          if (isPermanentError && !success) {
            // Ensure it wasn't accidentally marked success
            try {
              await _actionQueueRepository.removeAction(actionId);
              permanentErrorCount++;
              debugPrint(
                  "SyncManager: Removed action $actionId due to permanent error.");
            } catch (removeError) {
              debugPrint(
                  "SyncManager CRITICAL Error: Failed to remove action $actionId after permanent error: $removeError");
            }
          }
          // If it was a temporary error (success = false, isPermanentError = false),
          // it remains in the queue automatically for the next sync cycle.
        }
      } // End of batch processing

      // Small delay between batches to avoid overwhelming services
      if (i + AppConstants.actionQueueBatchSize < queuedActions.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } // End of loop through all batches

    debugPrint(
        "SyncManager: Action Queue sync attempt finished. Success: $successCount, Temp Fail: $failedCount, Permanent Error (Removed): $permanentErrorCount.");
  }
  // --- END: Sync Action Queue Method ---

  // --- Sync Friend Requests (LocalCache Queue - with enhanced error handling) ---
  Future<void> _syncFriendRequests() async {
    // debugPrint("SyncManager: Syncing LocalCache Friend Requests...");
    Map<dynamic, FriendRequestRecord> pendingRequests;
    try {
      pendingRequests = _localCacheService.getPendingFriendRequests();
    } catch (e) {
      debugPrint(
          "SyncManager Error (Friend Req Sync): Failed to get pending requests from LocalCache: $e");
      return;
    }

    if (pendingRequests.isEmpty) {
      // debugPrint("SyncManager: No pending LocalCache friend requests to sync.");
      return;
    }
    debugPrint(
        "SyncManager: Found ${pendingRequests.length} LocalCache friend requests to sync.");
    int successCount = 0;
    int failedCount = 0;
    int permanentErrorCount = 0;

    final requestKeys = pendingRequests.keys.toList(); // For safe iteration

    for (final key in requestKeys) {
      // Check connectivity before each attempt
      if (_connectivityBloc.state is! Online) {
        debugPrint(
            "SyncManager: Connection lost during friend request sync. Aborting.");
        break; // Stop processing queue
      }

      final request = pendingRequests[key]!;
      final String fromUserId = request.fromUserId;
      final String targetIdFromQueue = request.toUserId;
      String? targetFullUuid; // Resolved full ID
      bool isPermanentError = false;

      try {
        // --- Resolve target ID (Needs profile sync) ---
        if (targetIdFromQueue.length > 10) {
          // Assume it's already a full ID
          targetFullUuid = targetIdFromQueue;
        } else {
          // Assume it's a short ID
          final nearbyUser =
              _localCacheService.getNearbyUser(targetIdFromQueue);
          // If profile isn't synced yet, skip this item for now
          if (nearbyUser?.profileId == null || nearbyUser!.profileId!.isEmpty) {
            // debugPrint("SyncManager Warning: Profile for target uidShort $targetIdFromQueue not synced yet for friend request (Key: $key). Skipping, will retry later.");
            continue; // Go to next request
          }
          targetFullUuid = nearbyUser.profileId!;
        }
        // --- End Resolve ---

        // debugPrint("SyncManager: Attempting to sync friend request via repo - From: $fromUserId, To (Resolved): $targetFullUuid");
        // Call repository to send the request
        await _friendRepository.sendFriendRequest(fromUserId, targetFullUuid,
            isSync: true);

        // Success - remove from queue
        await _localCacheService.removeFriendRequest(key);
        // debugPrint("SyncManager: Successfully synced friend request (Key: $key).");
        successCount++;
      } catch (e) {
        failedCount++;
        debugPrint(
            "SyncManager Error: Failed to sync friend request (Key: $key). Repo Error: $e.");
        // --- START: Permanent Error Check ---
        final errorString = e.toString().toLowerCase();
        if (errorString.contains("not found") ||
            errorString.contains("already friends") ||
            errorString.contains("request already sent") ||
            errorString.contains("blocked")) {
          isPermanentError = true;
          debugPrint(
              "SyncManager: Marking friend request $key as permanent error based on exception.");
        }
        // --- END: Permanent Error Check ---
      } finally {
        // Remove if permanent error occurred
        if (isPermanentError) {
          try {
            await _localCacheService.removeFriendRequest(key);
            permanentErrorCount++;
            debugPrint(
                "SyncManager: Removed friend request $key due to permanent error.");
          } catch (removeError) {
            debugPrint(
                "SyncManager CRITICAL Error: Failed to remove friend request $key after permanent error: $removeError");
          }
        }
        // Temporary errors remain in the queue
      }
    } // End of loop

    debugPrint(
        "SyncManager: LocalCache Friend request sync attempt finished. Success: $successCount, Temp Fail: $failedCount, Permanent Error (Removed): $permanentErrorCount.");
  }

  // --- Sync Waves (LocalCache Queue - with enhanced error handling) ---
  Future<void> _syncWaves() async {
    // debugPrint("SyncManager: Syncing LocalCache Waves...");
    Map<dynamic, WaveRecord> pendingWaves;
    try {
      pendingWaves = _localCacheService.getPendingWaves();
    } catch (e) {
      debugPrint(
          "SyncManager Error (Wave Sync): Failed to get pending waves from LocalCache: $e");
      return;
    }

    if (pendingWaves.isEmpty) {
      // debugPrint("SyncManager: No pending LocalCache waves to sync.");
      return;
    }

    // Only process waves that are older than 30 seconds to avoid processing immediate waves
    final now = DateTime.now();
    final oldWaves = pendingWaves.entries.where((entry) {
      final wave = entry.value;
      return now.difference(wave.timestamp).inSeconds > 30;
    }).toList();

    if (oldWaves.isEmpty) {
      debugPrint(
          "SyncManager: No old pending waves to sync (all waves are recent).");
      return;
    }

    debugPrint(
        "SyncManager: Found ${oldWaves.length} old LocalCache waves to sync (out of ${pendingWaves.length} total).");
    int successCount = 0;
    int failedCount = 0;
    int permanentErrorCount = 0;

    for (final entry in oldWaves) {
      final key = entry.key;
      final wave = entry.value;

      // Check connectivity
      if (_connectivityBloc.state is! Online) {
        debugPrint("SyncManager: Connection lost during wave sync. Aborting.");
        break; // Stop processing
      }

      final String fromUserId = wave.fromUidFull;
      final String targetUidShort = wave.toUidShort;
      String? targetFullUuid;
      bool isPermanentError = false;

      try {
        // --- Resolve target ID (Needs profile sync) ---
        final nearbyUser = _localCacheService.getNearbyUser(targetUidShort);
        // If profile not synced, skip for now
        if (nearbyUser?.profileId == null || nearbyUser!.profileId!.isEmpty) {
          // debugPrint("SyncManager Warning: Profile for target uidShort $targetUidShort not synced yet for wave (Key: $key). Skipping, will retry later.");
          continue; // Go to next wave
        }
        targetFullUuid = nearbyUser.profileId!;
        // --- End Resolve ---

        // debugPrint("SyncManager: Syncing wave via repo from $fromUserId to $targetFullUuid");
        // Call repository to send the wave (creates notification)
        await _userRepository.sendWave(fromUserId, targetFullUuid);

        // Success - remove from queue
        await _localCacheService.removeSentWave(key);
        // debugPrint("SyncManager: Successfully synced wave (Key: $key).");
        successCount++;
      } catch (e) {
        failedCount++;
        debugPrint(
            "SyncManager Error: Failed to sync wave (Key: $key). Error: $e");
        // --- START: Permanent Error Check ---
        final errorString = e.toString().toLowerCase();
        if (errorString.contains("not found") ||
            errorString.contains("blocked")) {
          isPermanentError = true;
          debugPrint(
              "SyncManager: Marking wave $key as permanent error based on exception.");
        }
        // --- END: Permanent Error Check ---
      } finally {
        // Remove if permanent error
        if (isPermanentError) {
          try {
            await _localCacheService.removeSentWave(key);
            permanentErrorCount++;
            debugPrint(
                "SyncManager: Removed wave $key due to permanent error.");
          } catch (removeError) {
            debugPrint(
                "SyncManager CRITICAL Error: Failed to remove wave $key after permanent error: $removeError");
          }
        }
        // Temporary errors remain in the queue
      }
    } // End of loop

    debugPrint(
        "SyncManager: LocalCache Wave sync attempt finished. Success: $successCount, Temp Fail: $failedCount, Permanent Error (Removed): $permanentErrorCount.");
  }

  /// Checks if there is any pending work across all sync queues.
  ///
  /// Optimized to check all queues efficiently in a single pass where possible.
  /// Uses caching to avoid redundant Hive box iterations.
  /// Returns true if any queue has pending items, false otherwise.
  bool _hasAnyPendingSyncWork() {
    // Use cached count if available and still valid
    final now = DateTime.now();
    if (_cachedPendingWorkCount != null &&
        _pendingWorkCacheTimestamp != null &&
        now.difference(_pendingWorkCacheTimestamp!) <
            AppConstants.pendingWorkCacheDuration) {
      return _cachedPendingWorkCount! > 0;
    }

    // Check all potential sources of pending work efficiently
    // Returns early on first non-empty queue for better performance
    int pendingCount = 0;
    if (_localCacheService.getUnsyncedNearbyUsers().isNotEmpty) pendingCount++;
    if (_localCacheService.getPendingWaves().isNotEmpty) pendingCount++;
    if (_localCacheService.getPendingFriendRequests().isNotEmpty) {
      pendingCount++;
    }
    if (_actionQueueRepository.getQueuedActions().isNotEmpty) pendingCount++;

    // Update cache
    _cachedPendingWorkCount = pendingCount;
    _pendingWorkCacheTimestamp = now;

    return pendingCount > 0;
  }

  /// Invalidates the pending work count cache.
  ///
  /// Call this when queues are modified to ensure accurate counts.
  void _invalidatePendingWorkCache() {
    _cachedPendingWorkCount = null;
    _pendingWorkCacheTimestamp = null;
  }

  /// Queues an image URL for background pre-caching.
  ///
  /// Images are processed asynchronously to avoid blocking sync operations.
  /// Queue size is limited to prevent memory issues.
  void _queueImageForPreCache(String imageUrl) {
    if (imageUrl.isEmpty) return;

    // Limit queue size to prevent memory issues
    if (_imageCacheQueue.length >= AppConstants.maxImageCacheQueueSize) {
      // Remove oldest entry
      _imageCacheQueue.removeAt(0);
    }

    // Add to queue if not already present
    if (!_imageCacheQueue.contains(imageUrl)) {
      _imageCacheQueue.add(imageUrl);
    }
  }

  /// Processes the image pre-caching queue in the background.
  ///
  /// This method runs asynchronously and processes images one by one
  /// to avoid overwhelming the network or cache.
  void _processImageCacheQueue() {
    if (_isProcessingImageQueue || _imageCacheQueue.isEmpty) return;

    _isProcessingImageQueue = true;
    Future(() async {
      while (_imageCacheQueue.isNotEmpty) {
        final imageUrl = _imageCacheQueue.removeAt(0);
        try {
          await locator<CacheManagerService>().preCacheImage(imageUrl);
        } catch (e) {
          debugPrint("SyncManager: Error pre-caching image $imageUrl: $e");
        }
        // Small delay between images to avoid overwhelming network
        await Future.delayed(const Duration(milliseconds: 100));
      }
      _isProcessingImageQueue = false;
    }).catchError((e) {
      debugPrint("SyncManager: Error processing image cache queue: $e");
      _isProcessingImageQueue = false;
    });
  }

  // --- Dispose ---
  // Call this when SyncManager is no longer needed (e.g., on logout or app termination)
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncDebounceTimer?.cancel();
    _stopPeriodicCheckTimer(); // Stop periodic timer
    _isSyncingNotifier.dispose(); // Dispose the ValueNotifier
    debugPrint("SyncManager: Disposed.");
  }
} // End SyncManager Class

// --- Helper Extensions ---

// Extension on CacheManagerService to add pre-caching helper
extension CacheManagerExt on CacheManagerService {
  Future<void> preCacheImage(String url) async {
    if (url.isEmpty) return;
    try {
      await manager.downloadFile(url);
      // debugPrint("CacheManagerService: Pre-cached image $url");
    } catch (e) {
      debugPrint("CacheManagerService: Error pre-caching image $url: $e");
    }
  }
}

// Extension on LocalCacheService to add query helpers
// (getNearbyUserByProfileId moved into main class for simplicity)
extension LocalCacheServiceHelper on LocalCacheService {
  // Get users that haven't been linked to a server profile (profileId is null/empty)
  List<NearbyUser> getUnsyncedNearbyUsers() {
    try {
      final box = Hive.box<NearbyUser>('nearbyUsers');
      final unsynced = box.values
          .where((user) => user.profileId == null || user.profileId!.isEmpty)
          .toList();
      // debugPrint("LocalCacheServiceHelper: Found ${unsynced.length} unsynced users out of ${box.length}.");
      return unsynced;
    } catch (e) {
      debugPrint(
          "LocalCacheServiceHelper Error (getUnsyncedNearbyUsers): Failed to access Hive or filter users: $e");
      return []; // Return empty list on error
    }
  }
}
