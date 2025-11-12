// lib/repositories/story_repository.dart

import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/story_media_model.dart';
import 'package:freegram/models/story_tray_data_model.dart';
import 'package:freegram/models/text_overlay_model.dart';
import 'package:freegram/models/drawing_path_model.dart';
import 'package:freegram/models/sticker_overlay_model.dart';
import 'package:freegram/services/cloudinary_service.dart';
import 'package:freegram/services/video_upload_service.dart';
import 'package:freegram/repositories/chat_repository.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/utils/app_constants.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';

class StoryRepository {
  final FirebaseFirestore _db;

  StoryRepository({
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  /// Create a new story
  Future<String> createStory({
    required String userId,
    File? mediaFile,
    required String mediaType, // 'image' or 'video'
    String? caption,
    List<TextOverlay>? textOverlays,
    List<DrawingPath>? drawings,
    List<String>? stickerIds,
    List<StickerOverlay>? stickerOverlays,
    double? videoDuration,
    String? audioUrl, // Audio track URL (optional, for stories with audio)
    String?
        preUploadedMediaUrl, // Pre-uploaded media URL (optional, to skip upload)
    Map<String, String>?
        preUploadedVideoQualities, // Pre-uploaded video qualities (optional)
    String? preUploadedThumbnailUrl, // Pre-uploaded thumbnail URL (optional)
  }) async {
    // Store original videoDuration for later use
    double? finalVideoDuration = videoDuration;
    try {
      // 1. Upload media to Cloudinary (or use pre-uploaded URLs)
      String mediaUrl;
      String? thumbnailUrl;
      Map<String, String>?
          videoQualities; // For multi-quality video URLs (Phase 2.2)

      if (preUploadedMediaUrl != null) {
        // Use pre-uploaded URLs
        mediaUrl = preUploadedMediaUrl;
        thumbnailUrl = preUploadedThumbnailUrl;
        videoQualities = preUploadedVideoQualities;
      } else if (mediaFile != null) {
        if (mediaType == 'video') {
          // Generate thumbnail first (before upload)
          // Add timeout to prevent infinite loops from transcoder library
          final thumbnailData = await VideoThumbnail.thumbnailData(
            video: mediaFile.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 400,
            quality: 75,
          ).timeout(
            const Duration(
                seconds: 30), // 30 second timeout for thumbnail generation
            onTimeout: () {
              debugPrint('StoryRepository: Thumbnail generation timeout');
              return null; // Return null on timeout, thumbnail is optional
            },
          );

          if (thumbnailData != null) {
            final tempDir = await getTemporaryDirectory();
            final thumbnailFile = File(path.join(tempDir.path,
                'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg'));
            await thumbnailFile.writeAsBytes(thumbnailData);
            thumbnailUrl =
                await CloudinaryService.uploadImageFromFile(thumbnailFile);
            await thumbnailFile.delete(); // Clean up
          }

          // Get video duration if not provided
          if (finalVideoDuration == null) {
            try {
              final controller = VideoPlayerController.file(mediaFile);
              await controller.initialize();
              finalVideoDuration =
                  controller.value.duration.inSeconds.toDouble();
              await controller.dispose();
            } catch (e) {
              debugPrint('StoryRepository: Error getting video duration: $e');
              // Default to 5 seconds if can't determine
              finalVideoDuration = 5.0;
            }
          }

          // Upload video to Cloudinary with multiple qualities (Phase 2.2 - ABR support)
          final videoUploadService = VideoUploadService();
          videoQualities = await videoUploadService
              .uploadVideoWithMultipleQualities(mediaFile);

          if (videoQualities == null ||
              videoQualities['videoUrl'] == null ||
              videoQualities['videoUrl']!.isEmpty) {
            throw Exception('Failed to upload video to Cloudinary');
          }

          mediaUrl = videoQualities['videoUrl']!;
        } else {
          // Upload image
          mediaUrl =
              await CloudinaryService.uploadImageFromFile(mediaFile) ?? '';
          if (mediaUrl.isEmpty) {
            throw Exception('Failed to upload image to Cloudinary');
          }
        }
      } else {
        throw Exception(
            'Either mediaFile or preUploadedMediaUrl must be provided');
      }

      // 2. Create story document in Firestore
      final storyRef = _db.collection('story_media').doc();
      final now = FieldValue.serverTimestamp();
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      );

      final storyData = <String, dynamic>{
        'storyId': storyRef.id,
        'authorId': userId,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'thumbnailUrl': thumbnailUrl,
        'duration': finalVideoDuration,
        'caption': caption,
        'textOverlays': textOverlays?.map((t) => t.toMap()).toList(),
        'drawings': drawings?.map((d) => d.toMap()).toList(),
        'stickerIds': stickerIds ?? [],
        'stickerOverlays': stickerOverlays?.map((s) => s.toMap()).toList(),
        'createdAt': now,
        'expiresAt': expiresAt,
        'viewerCount': 0,
        'replyCount': 0,
        'isActive': true,
        if (audioUrl != null) 'audioUrl': audioUrl,
      };

      // Add multi-quality video URLs if available (Phase 2.2 - ABR support)
      if (mediaType == 'video' && videoQualities != null) {
        if (videoQualities['videoUrl360p'] != null) {
          storyData['videoUrl360p'] = videoQualities['videoUrl360p'];
        }
        if (videoQualities['videoUrl720p'] != null) {
          storyData['videoUrl720p'] = videoQualities['videoUrl720p'];
        }
        if (videoQualities['videoUrl1080p'] != null) {
          storyData['videoUrl1080p'] = videoQualities['videoUrl1080p'];
        }
      }

      await storyRef.set(storyData);

      debugPrint(
          'StoryRepository: Story created successfully with ID: ${storyRef.id}');
      debugPrint(
          'StoryRepository: Story data - authorId: $userId, mediaUrl: $mediaUrl, expiresAt: $expiresAt');
      return storyRef.id;
    } catch (e) {
      debugPrint('StoryRepository: Error creating story: $e');
      rethrow;
    }
  }

  /// Create a new story from bytes (for web platform)
  Future<String> createStoryFromBytes({
    required String userId,
    required Uint8List mediaBytes,
    required String mediaType, // 'image' or 'video'
    String? caption,
    List<TextOverlay>? textOverlays,
    List<DrawingPath>? drawings,
    List<String>? stickerIds,
    List<StickerOverlay>? stickerOverlays,
    double? videoDuration,
  }) async {
    // Store original videoDuration for later use
    double? finalVideoDuration = videoDuration;
    try {
      // 1. Upload media to Cloudinary
      String mediaUrl;
      String? thumbnailUrl;

      if (mediaType == 'video') {
        // Web video upload not yet supported
        throw UnimplementedError(
            'Video upload from bytes not yet implemented for web.');
      } else {
        // Upload image from bytes
        mediaUrl = await CloudinaryService.uploadImageFromBytes(
              mediaBytes,
              filename: 'story_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ) ??
            '';
        if (mediaUrl.isEmpty) {
          throw Exception('Failed to upload image to Cloudinary');
        }
      }

      // 2. Create story document in Firestore
      final storyRef = _db.collection('story_media').doc();
      final now = FieldValue.serverTimestamp();
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      );

      await storyRef.set({
        'storyId': storyRef.id,
        'authorId': userId,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'thumbnailUrl': thumbnailUrl,
        'duration': finalVideoDuration,
        'caption': caption,
        'textOverlays': textOverlays?.map((t) => t.toMap()).toList(),
        'drawings': drawings?.map((d) => d.toMap()).toList(),
        'stickerIds': stickerIds ?? [],
        'stickerOverlays': stickerOverlays?.map((s) => s.toMap()).toList(),
        'createdAt': now,
        'expiresAt': expiresAt,
        'viewerCount': 0,
        'replyCount': 0,
        'isActive': true,
      });

      debugPrint(
          'StoryRepository: Story created from bytes successfully with ID: ${storyRef.id}');
      debugPrint(
          'StoryRepository: Story data - authorId: $userId, mediaUrl: $mediaUrl, expiresAt: $expiresAt');
      return storyRef.id;
    } catch (e) {
      debugPrint('StoryRepository: Error creating story from bytes: $e');
      rethrow;
    }
  }

  /// Get story tray data stream (new Facebook-style sorted data)
  /// Returns StoryTrayData with myStory, unreadStories, and seenStories
  Stream<StoryTrayData> getStoryTrayDataStream(String userId) {
    try {
      return _db
          .collection('users')
          .doc(userId)
          .snapshots()
          .asyncExpand((userDoc) {
        if (!userDoc.exists) {
          return Stream.value(const StoryTrayData(
            unreadStories: [],
            seenStories: [],
            userAvatars: {},
            usernames: {},
          ));
        }

        final userData = userDoc.data()!;
        final friends = List<String>.from(userData['friends'] ?? []);
        final allUserIds = <String>[userId, ...friends];

        if (allUserIds.isEmpty) {
          return Stream.value(const StoryTrayData(
            unreadStories: [],
            seenStories: [],
            userAvatars: {},
            usernames: {},
          ));
        }

        return _db
            .collection('story_media')
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots()
            .asyncMap((snapshot) async {
          final now = Timestamp.now();
          final storiesByAuthor = <String, List<StoryMedia>>{};

          // Parse all stories
          for (var doc in snapshot.docs) {
            try {
              final story = StoryMedia.fromDoc(doc);
              if (allUserIds.contains(story.authorId) &&
                  story.expiresAt.isAfter(now.toDate())) {
                storiesByAuthor
                    .putIfAbsent(story.authorId, () => [])
                    .add(story);
              }
            } catch (e) {
              debugPrint('StoryRepository: Error parsing story ${doc.id}: $e');
            }
          }

          // Batch fetch user info
          final authorIds = storiesByAuthor.keys.toList();
          final userDocs = <String, Map<String, dynamic>>{};

          if (authorIds.isNotEmpty) {
            try {
              final batches = <List<String>>[];
              for (var i = 0; i < authorIds.length; i += 10) {
                batches.add(authorIds.sublist(
                  i,
                  i + 10 > authorIds.length ? authorIds.length : i + 10,
                ));
              }

              for (final batch in batches) {
                final futures = batch.map((authorId) => _db
                    .collection('users')
                    .doc(authorId)
                    .get()
                    .then((doc) =>
                        MapEntry(authorId, doc.exists ? doc.data() : null)));
                final results = await Future.wait(futures);
                for (final entry in results) {
                  if (entry.value != null) {
                    userDocs[entry.key] = entry.value!;
                  }
                }
              }
            } catch (e) {
              debugPrint('StoryRepository: Error batch fetching user info: $e');
            }
          }

          // Build user metadata maps
          final userAvatars = <String, String>{};
          final usernames = <String, String>{};

          for (final authorId in authorIds) {
            final authorData = userDocs[authorId];
            if (authorData != null) {
              final photoUrl = authorData['photoUrl'];
              final validatedUrl = (photoUrl != null &&
                      photoUrl is String &&
                      photoUrl.isNotEmpty &&
                      photoUrl.trim().isNotEmpty &&
                      (photoUrl.startsWith('http://') ||
                          photoUrl.startsWith('https://')))
                  ? photoUrl.trim()
                  : '';
              userAvatars[authorId] = validatedUrl;
              usernames[authorId] = authorData['username'] ?? 'Unknown';
            }
          }

          // Get user's own story (most recent)
          StoryMedia? myStory;
          final myStories = storiesByAuthor[userId] ?? [];
          if (myStories.isNotEmpty) {
            // Sort by createdAt descending and take the most recent
            myStories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            myStory = myStories.first;
          }

          // Check viewer status for all stories
          final storyIds = <String>[];
          for (final stories in storiesByAuthor.values) {
            for (final story in stories) {
              storyIds.add(story.storyId);
            }
          }

          final viewedStoryIds = <String>{};
          if (storyIds.isNotEmpty) {
            try {
              final batches = <List<String>>[];
              for (var i = 0; i < storyIds.length; i += 10) {
                batches.add(storyIds.sublist(
                  i,
                  i + 10 > storyIds.length ? storyIds.length : i + 10,
                ));
              }

              for (final batch in batches) {
                final futures = batch.map((storyId) => _db
                    .collection('story_media')
                    .doc(storyId)
                    .collection('viewers')
                    .doc(userId)
                    .get()
                    .then((doc) => MapEntry(storyId, doc.exists)));
                final results = await Future.wait(futures);
                for (final entry in results) {
                  if (entry.value) {
                    viewedStoryIds.add(entry.key);
                  }
                }
              }
            } catch (e) {
              debugPrint(
                  'StoryRepository: Error batch checking viewer status: $e');
            }
          }

          // Separate unread and seen stories (excluding user's own)
          // CRITICAL FIX: Only show ONE story per user (most recent) to prevent duplicates
          final unreadStories = <StoryMedia>[];
          final seenStories = <StoryMedia>[];
          final processedAuthors =
              <String>{}; // Track processed authors to prevent duplicates

          for (final authorId in allUserIds) {
            if (authorId == userId) continue; // Skip own story
            if (processedAuthors.contains(authorId))
              continue; // Skip if already processed

            final stories = storiesByAuthor[authorId] ?? [];
            if (stories.isEmpty) continue;

            // Sort stories by createdAt descending and take only the most recent
            stories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final mostRecentStory =
                stories.first; // Only take the most recent story

            // Mark author as processed
            processedAuthors.add(authorId);

            // Add to appropriate list based on view status
            final isUnread = !viewedStoryIds.contains(mostRecentStory.storyId);
            if (isUnread) {
              unreadStories.add(mostRecentStory);
            } else {
              seenStories.add(mostRecentStory);
            }
          }

          return StoryTrayData(
            myStory: myStory,
            unreadStories: unreadStories,
            seenStories: seenStories,
            userAvatars: userAvatars,
            usernames: usernames,
          );
        });
      }).handleError((error) {
        debugPrint('StoryRepository: Error in story tray data stream: $error');
        return const StoryTrayData(
          unreadStories: [],
          seenStories: [],
          userAvatars: {},
          usernames: {},
        );
      });
    } catch (e) {
      debugPrint('StoryRepository: Error getting story tray data stream: $e');
      return Stream.value(const StoryTrayData(
        unreadStories: [],
        seenStories: [],
        userAvatars: {},
        usernames: {},
      ));
    }
  }

  /// Get all active stories for a specific user
  Future<List<StoryMedia>> getUserStories(String userId) async {
    try {
      debugPrint('StoryRepository: Getting stories for user $userId');
      final now = Timestamp.now();

      // Use simpler query - only orderBy createdAt (descending) to avoid index requirement
      // Filter by expiresAt in memory instead
      final snapshot = await _db
          .collection('story_media')
          .where('authorId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      debugPrint(
          'StoryRepository: Found ${snapshot.docs.length} stories (before filtering)');

      // Filter by expiresAt in memory and sort
      final stories =
          snapshot.docs.map((doc) => StoryMedia.fromDoc(doc)).where((story) {
        // Check if story hasn't expired
        try {
          return story.expiresAt.isAfter(now.toDate());
        } catch (e) {
          debugPrint('StoryRepository: Error checking expiresAt: $e');
          return false;
        }
      }).toList();

      // Sort by createdAt descending (most recent first)
      stories.sort((a, b) {
        return b.createdAt.compareTo(a.createdAt);
      });

      debugPrint(
          'StoryRepository: Returning ${stories.length} active stories for user $userId');
      return stories;
    } catch (e) {
      debugPrint('StoryRepository: Error getting user stories: $e');
      // If the query fails due to missing index, try without orderBy
      try {
        debugPrint('StoryRepository: Retrying without orderBy...');
        final now = Timestamp.now();
        final snapshot = await _db
            .collection('story_media')
            .where('authorId', isEqualTo: userId)
            .where('isActive', isEqualTo: true)
            .get();

        final stories =
            snapshot.docs.map((doc) => StoryMedia.fromDoc(doc)).where((story) {
          try {
            return story.expiresAt.isAfter(now.toDate());
          } catch (e) {
            debugPrint(
                'StoryRepository: Error checking expiresAt in retry: $e');
            return false;
          }
        }).toList();

        stories.sort((a, b) {
          return b.createdAt.compareTo(a.createdAt);
        });

        debugPrint(
            'StoryRepository: Retry successful - returning ${stories.length} stories');
        return stories;
      } catch (retryError) {
        debugPrint('StoryRepository: Retry also failed: $retryError');
        return [];
      }
    }
  }

  /// Get stories for multiple users in parallel batches.
  ///
  /// This is an optimized version that loads stories for multiple users simultaneously
  /// using Firestore's whereIn query (limit 10). Processes batches in parallel with
  /// concurrency limits to avoid overloading Firestore.
  ///
  /// [userIds] - List of user IDs to fetch stories for
  ///
  /// Returns a [Map<String, List<StoryMedia>>] where keys are user IDs and values
  /// are lists of active stories for that user.
  Future<Map<String, List<StoryMedia>>> getStoriesForUsers(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) {
      return {};
    }

    debugPrint(
        'StoryRepository: Getting stories for ${userIds.length} users in parallel');
    final now = Timestamp.now();
    final Map<String, List<StoryMedia>> results = {};

    try {
      // Firestore whereIn limit is 10
      const int whereInLimit = 10;
      final List<List<String>> batches = [];

      // Split userIds into batches of 10
      for (var i = 0; i < userIds.length; i += whereInLimit) {
        batches.add(userIds.sublist(
          i,
          i + whereInLimit > userIds.length ? userIds.length : i + whereInLimit,
        ));
      }

      // Process batches in parallel with concurrency limit
      for (var i = 0;
          i < batches.length;
          i += AppConstants.maxConcurrentBatches) {
        final batchGroup = batches.sublist(
          i,
          i + AppConstants.maxConcurrentBatches > batches.length
              ? batches.length
              : i + AppConstants.maxConcurrentBatches,
        );

        final groupFutures = batchGroup.map((batch) async {
          try {
            // Query stories for this batch of users
            final snapshot = await _db
                .collection('story_media')
                .where('authorId', whereIn: batch)
                .where('isActive', isEqualTo: true)
                .orderBy('createdAt', descending: true)
                .get();

            // Group stories by authorId and filter expired
            final Map<String, List<StoryMedia>> batchResults = {};
            for (var doc in snapshot.docs) {
              try {
                final story = StoryMedia.fromDoc(doc);
                // Filter expired stories
                if (story.expiresAt.isAfter(now.toDate())) {
                  batchResults.putIfAbsent(story.authorId, () => []).add(story);
                }
              } catch (e) {
                debugPrint(
                    'StoryRepository: Error parsing story ${doc.id}: $e');
              }
            }

            // Sort stories by createdAt descending for each user
            for (final userId in batchResults.keys) {
              batchResults[userId]!.sort((a, b) {
                return b.createdAt.compareTo(a.createdAt);
              });
            }

            debugPrint(
                'StoryRepository: Batch query for ${batch.length} users returned stories for ${batchResults.length} users');
            return batchResults;
          } catch (e) {
            debugPrint(
                'StoryRepository: Error in batch query for users $batch: $e');
            // If query fails (e.g., missing index), fall back to individual queries
            final Map<String, List<StoryMedia>> fallbackResults = {};
            for (final userId in batch) {
              try {
                final stories = await getUserStories(userId);
                if (stories.isNotEmpty) {
                  fallbackResults[userId] = stories;
                }
              } catch (e) {
                debugPrint(
                    'StoryRepository: Fallback query failed for user $userId: $e');
              }
            }
            return fallbackResults;
          }
        });

        // Wait for this group to complete and merge results
        final batchResults = await Future.wait(groupFutures, eagerError: false);
        for (final batchResult in batchResults) {
          results.addAll(batchResult);
        }
      }

      debugPrint(
          'StoryRepository: Finished getting stories for ${userIds.length} users. Found stories for ${results.length} users');
      return results;
    } catch (e) {
      debugPrint('StoryRepository: Error getting stories for users: $e');
      // Fallback to individual queries if batch fails completely
      debugPrint('StoryRepository: Falling back to individual queries...');
      final Map<String, List<StoryMedia>> fallbackResults = {};
      for (final userId in userIds) {
        try {
          final stories = await getUserStories(userId);
          if (stories.isNotEmpty) {
            fallbackResults[userId] = stories;
          }
        } catch (e) {
          debugPrint(
              'StoryRepository: Individual query failed for user $userId: $e');
        }
      }
      return fallbackResults;
    }
  }

  /// Mark a story as viewed by a user
  Future<void> markStoryAsViewed(String storyId, String viewerId) async {
    try {
      // Check if already viewed
      final viewerDoc = await _db
          .collection('story_media')
          .doc(storyId)
          .collection('viewers')
          .doc(viewerId)
          .get();

      if (viewerDoc.exists) {
        return; // Already viewed
      }

      // Create viewer document
      await _db
          .collection('story_media')
          .doc(storyId)
          .collection('viewers')
          .doc(viewerId)
          .set({
        'viewerId': viewerId,
        'viewedAt': FieldValue.serverTimestamp(),
      });

      // Cloud Function will update viewerCount automatically
    } catch (e) {
      debugPrint('StoryRepository: Error marking story as viewed: $e');
      rethrow;
    }
  }

  /// Reply to a story (Facebook-style: Creates a private message instead of public reply)
  Future<void> replyToStory({
    required String storyId,
    required String replierId,
    required String content,
    required String replyType, // 'text' | 'emoji'
  }) async {
    try {
      // Get story to find author and story details
      final storyDoc = await _db.collection('story_media').doc(storyId).get();
      if (!storyDoc.exists) {
        throw Exception('Story not found');
      }

      final story = StoryMedia.fromDoc(storyDoc);
      final authorId = story.authorId;

      // If this is an emoji reaction, store it in the story document FIRST
      // This allows reactions to your own story (which is valid for reactions)
      if (replyType == 'emoji') {
        // Store emoji reaction (typically 1-4 characters, but accept any short string)
        // If it's marked as emoji type, trust it's an emoji
        try {
          debugPrint(
              'StoryRepository: Storing emoji reaction: "$content" (length: ${content.length}, runes: ${content.runes.length})');
          await addStoryReaction(
            storyId: storyId,
            userId: replierId,
            emoji: content,
          );
          debugPrint(
              'StoryRepository: Emoji reaction stored successfully in story document');
        } catch (e) {
          debugPrint('StoryRepository: Error storing emoji reaction: $e');
          // Don't rethrow - allow the chat message to still be sent
          // But log the error so we can debug
        }
      }

      // Don't allow text replies to your own story (but emoji reactions are OK)
      if (authorId == replierId && replyType != 'emoji') {
        throw Exception('Cannot reply to your own story');
      }

      // Skip chat message creation for your own story (reactions are already stored above)
      if (authorId == replierId) {
        debugPrint(
            'StoryRepository: Skipping chat message for own story reaction');
        return;
      }

      // Get author's username for story context
      final authorDoc = await _db.collection('users').doc(authorId).get();
      final authorUsername = authorDoc.data()?['username'] ?? 'Unknown';

      // Get replier's username for chat creation
      final replierDoc = await _db.collection('users').doc(replierId).get();
      final replierUsername = replierDoc.data()?['username'] ?? 'Unknown';

      // Import ChatRepository to use its methods
      // Note: We'll use locator to avoid circular dependencies
      final chatRepository = locator<ChatRepository>();

      // Create chat ID manually (same way ChatRepository does it)
      // Since startOrGetChat uses FirebaseAuth.currentUser, we need to create the chat manually
      final ids = [authorId, replierId]..sort();
      final chatId = ids.join('_');
      final chatRef = _db.collection('chats').doc(chatId);
      final chatDoc = await chatRef.get();

      if (!chatDoc.exists) {
        // Create chat with proper structure matching ChatRepository
        await chatRef.set({
          'users': [authorId, replierId],
          'usernames': {
            authorId: authorUsername,
            replierId: replierUsername,
          },
          'chatType': 'friend', // Story replies are between friends
          'unreadFor': [],
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Send private message with story context
      await chatRepository.sendMessage(
        chatId: chatId,
        senderId: replierId,
        text: content,
        storyReplyId: storyId,
        storyThumbnailUrl: story.thumbnailUrl,
        storyMediaUrl: story.mediaUrl,
        storyMediaType: story.mediaType,
        storyAuthorId: authorId,
        storyAuthorUsername: authorUsername,
      );

      // Cloud Function will send notification
      debugPrint(
          'StoryRepository: Story reply sent as private message to chat $chatId');
    } catch (e) {
      debugPrint('StoryRepository: Error replying to story: $e');
      rethrow;
    }
  }

  /// Get story viewers
  Future<List<String>> getStoryViewers(String storyId) async {
    try {
      final snapshot = await _db
          .collection('story_media')
          .doc(storyId)
          .collection('viewers')
          .orderBy('viewedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('StoryRepository: Error getting story viewers: $e');
      return [];
    }
  }

  /// Get story reactions (emoji replies) from story document
  /// Returns a map of userId -> emoji for users who reacted to the story
  Future<Map<String, String>> getStoryReactions(String storyId) async {
    try {
      debugPrint('StoryRepository: Getting reactions for story $storyId');

      final storyDoc = await _db.collection('story_media').doc(storyId).get();
      if (!storyDoc.exists) {
        debugPrint('StoryRepository: Story document not found: $storyId');
        return {};
      }

      final storyData = storyDoc.data() ?? {};
      debugPrint(
          'StoryRepository: Story data keys: ${storyData.keys.toList()}');

      // Check if reactions are stored directly in the story document
      if (storyData['reactions'] != null && storyData['reactions'] is Map) {
        final reactions = storyData['reactions'] as Map<String, dynamic>;
        final result =
            reactions.map((key, value) => MapEntry(key, value.toString()));
        debugPrint(
            'StoryRepository: Found ${result.length} reactions: $result');
        return result;
      }

      debugPrint('StoryRepository: No reactions field found in story document');
      return {};
    } catch (e) {
      debugPrint('StoryRepository: Error getting story reactions: $e');
      return {};
    }
  }

  /// Add or update a story reaction
  /// Stores the reaction in the story document for efficient querying
  Future<void> addStoryReaction({
    required String storyId,
    required String userId,
    required String emoji,
  }) async {
    try {
      debugPrint(
          'StoryRepository: Adding reaction $emoji from user $userId to story $storyId');

      final batch = _db.batch();
      final storyRef = _db.collection('story_media').doc(storyId);

      // Get current story data
      final storyDoc = await storyRef.get();
      if (!storyDoc.exists) {
        throw Exception('Story not found');
      }

      final storyData = storyDoc.data() ?? {};
      final currentReactions =
          Map<String, dynamic>.from(storyData['reactions'] ?? {});
      final currentReactionCount = storyData['reactionCount'] ?? 0;

      // Check if user already has a reaction
      final hadPreviousReaction = currentReactions.containsKey(userId);

      // Update or add reaction
      currentReactions[userId] = emoji;

      // Update reaction breakdown
      final reactionBreakdown =
          Map<String, int>.from(storyData['reactionBreakdown'] ?? {});
      if (hadPreviousReaction) {
        // User changed reaction, update breakdown
        final oldEmoji = storyData['reactions']?[userId]?.toString() ?? '';
        if (oldEmoji.isNotEmpty && reactionBreakdown.containsKey(oldEmoji)) {
          reactionBreakdown[oldEmoji] = (reactionBreakdown[oldEmoji]! - 1)
              .clamp(0, double.infinity)
              .toInt();
          if (reactionBreakdown[oldEmoji] == 0) {
            reactionBreakdown.remove(oldEmoji);
          }
        }
      }

      // Increment new emoji count
      reactionBreakdown[emoji] = (reactionBreakdown[emoji] ?? 0) + 1;

      // Update story document
      batch.update(storyRef, {
        'reactions': currentReactions,
        'reactionBreakdown': reactionBreakdown,
        'reactionCount': hadPreviousReaction
            ? currentReactionCount
            : currentReactionCount + 1,
      });

      await batch.commit();
      debugPrint('StoryRepository: Reaction added successfully');
    } catch (e) {
      debugPrint('StoryRepository: Error adding story reaction: $e');
      rethrow;
    }
  }

  /// Remove a story reaction
  Future<void> removeStoryReaction({
    required String storyId,
    required String userId,
  }) async {
    try {
      debugPrint(
          'StoryRepository: Removing reaction from user $userId for story $storyId');

      final batch = _db.batch();
      final storyRef = _db.collection('story_media').doc(storyId);

      // Get current story data
      final storyDoc = await storyRef.get();
      if (!storyDoc.exists) {
        throw Exception('Story not found');
      }

      final storyData = storyDoc.data() ?? {};
      final currentReactions =
          Map<String, dynamic>.from(storyData['reactions'] ?? {});
      final currentReactionCount = storyData['reactionCount'] ?? 0;

      if (!currentReactions.containsKey(userId)) {
        return; // No reaction to remove
      }

      // Get the emoji that was removed
      final removedEmoji = currentReactions[userId]?.toString() ?? '';

      // Remove reaction
      currentReactions.remove(userId);

      // Update reaction breakdown
      final reactionBreakdown =
          Map<String, int>.from(storyData['reactionBreakdown'] ?? {});
      if (removedEmoji.isNotEmpty &&
          reactionBreakdown.containsKey(removedEmoji)) {
        reactionBreakdown[removedEmoji] = (reactionBreakdown[removedEmoji]! - 1)
            .clamp(0, double.infinity)
            .toInt();
        if (reactionBreakdown[removedEmoji] == 0) {
          reactionBreakdown.remove(removedEmoji);
        }
      }

      // Update story document
      batch.update(storyRef, {
        'reactions': currentReactions,
        'reactionBreakdown': reactionBreakdown,
        'reactionCount':
            (currentReactionCount - 1).clamp(0, double.infinity).toInt(),
      });

      await batch.commit();
      debugPrint('StoryRepository: Reaction removed successfully');
    } catch (e) {
      debugPrint('StoryRepository: Error removing story reaction: $e');
      rethrow;
    }
  }

  /// Delete a story (soft delete)
  Future<void> deleteStory(String storyId, String userId) async {
    try {
      final storyDoc = await _db.collection('story_media').doc(storyId).get();
      if (!storyDoc.exists) {
        throw Exception('Story not found');
      }

      final story = StoryMedia.fromDoc(storyDoc);
      if (story.authorId != userId) {
        throw Exception('Not authorized to delete this story');
      }

      await _db.collection('story_media').doc(storyId).update({
        'isActive': false,
      });
    } catch (e) {
      debugPrint('StoryRepository: Error deleting story: $e');
      rethrow;
    }
  }
}
