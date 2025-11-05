// lib/repositories/story_repository.dart

import 'dart:io';
import 'dart:typed_data' show Uint8List;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/models/story_media_model.dart';
import 'package:freegram/models/story_tray_item_model.dart';
import 'package:freegram/models/story_tray_data_model.dart';
import 'package:freegram/models/text_overlay_model.dart';
import 'package:freegram/models/drawing_path_model.dart';
import 'package:freegram/models/sticker_overlay_model.dart';
import 'package:freegram/services/cloudinary_service.dart';
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
    required File mediaFile,
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
        // Generate thumbnail first (before upload)
        final thumbnailData = await VideoThumbnail.thumbnailData(
          video: mediaFile.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 400,
          quality: 75,
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
            finalVideoDuration = controller.value.duration.inSeconds.toDouble();
            await controller.dispose();
          } catch (e) {
            debugPrint('StoryRepository: Error getting video duration: $e');
            // Default to 5 seconds if can't determine
            finalVideoDuration = 5.0;
          }
        }

        // Upload video to Cloudinary
        mediaUrl = await CloudinaryService.uploadVideoFromFile(mediaFile) ?? '';
        if (mediaUrl.isEmpty) {
          throw Exception('Failed to upload video to Cloudinary');
        }
      } else {
        // Upload image
        mediaUrl = await CloudinaryService.uploadImageFromFile(mediaFile) ?? '';
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
          return Stream.value(StoryTrayData(
            unreadStories: [],
            seenStories: [],
            userAvatars: {},
            usernames: {},
          ));
        }

        final userData = userDoc.data()!;
        final friends = List<String>.from(userData['friends'] ?? []);
        final allUserIds = <String>[userId]..addAll(friends);

        if (allUserIds.isEmpty) {
          return Stream.value(StoryTrayData(
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
          final unreadStories = <StoryMedia>[];
          final seenStories = <StoryMedia>[];

          for (final authorId in allUserIds) {
            if (authorId == userId) continue; // Skip own story
            final stories = storiesByAuthor[authorId] ?? [];
            if (stories.isEmpty) continue;

            // Sort stories by createdAt descending
            stories.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            for (final story in stories) {
              final isUnread = !viewedStoryIds.contains(story.storyId);
              if (isUnread) {
                unreadStories.add(story);
              } else {
                seenStories.add(story);
              }
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
        return StoryTrayData(
          unreadStories: [],
          seenStories: [],
          userAvatars: {},
          usernames: {},
        );
      });
    } catch (e) {
      debugPrint('StoryRepository: Error getting story tray data stream: $e');
      return Stream.value(StoryTrayData(
        unreadStories: [],
        seenStories: [],
        userAvatars: {},
        usernames: {},
      ));
    }
  }

  /// Get story tray stream (active stories from followed users)
  /// Uses real-time Firestore listeners instead of polling
  /// @deprecated Use getStoryTrayDataStream instead
  Stream<List<StoryTrayItem>> getStoryTrayStream(String userId) {
    try {
      // Get user's friends list first
      return _db
          .collection('users')
          .doc(userId)
          .snapshots()
          .asyncExpand((userDoc) {
        if (!userDoc.exists) {
          return Stream.value(<StoryTrayItem>[]);
        }

        final userData = userDoc.data()!;
        final friends = List<String>.from(userData['friends'] ?? []);
        final allUserIds = <String>[userId]..addAll(friends);

        if (allUserIds.isEmpty) {
          return Stream.value(<StoryTrayItem>[]);
        }

        // Limit to 50 most recent active stories to manage costs
        // Use snapshots() for real-time updates
        return _db
            .collection('story_media')
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots()
            .asyncMap((snapshot) async {
          // Filter stories by friends and expiration
          final now = Timestamp.now();
          final storiesByAuthor = <String, List<StoryMedia>>{};

          for (var doc in snapshot.docs) {
            try {
              final story = StoryMedia.fromDoc(doc);
              // Only include stories from friends or self
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

          // Build tray items - ALWAYS include user's own story item so UI can detect it
          final trayItems = <StoryTrayItem>[];
          final processedAuthors = <String>{};

          // Batch fetch user info for all authors
          final authorIds = storiesByAuthor.keys.toList();
          final userDocs = <String, Map<String, dynamic>>{};

          if (authorIds.isNotEmpty) {
            try {
              // Batch fetch user documents (limit to 10 at a time due to Firestore limits)
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

          // Process user's own stories first
          final userStories = storiesByAuthor[userId] ?? [];
          if (userStories.isNotEmpty) {
            final userData = userDocs[userId];
            if (userData != null) {
              final photoUrl = userData['photoUrl'];
              // Validate URL - must be HTTP/HTTPS or empty string
              final validatedUrl = (photoUrl != null &&
                      photoUrl is String &&
                      photoUrl.isNotEmpty &&
                      photoUrl.trim().isNotEmpty &&
                      (photoUrl.startsWith('http://') ||
                          photoUrl.startsWith('https://')))
                  ? photoUrl.trim()
                  : '';
              trayItems.add(StoryTrayItem(
                userId: userId,
                username: userData['username'] ?? 'Unknown',
                userAvatarUrl: validatedUrl,
                hasUnreadStory: false, // Own stories are never unread
                storyCount: userStories.length,
              ));
              processedAuthors.add(userId);
            }
          }

          // Batch check viewer status for all stories
          final storyIds = <String>[];
          for (final stories in storiesByAuthor.values) {
            for (final story in stories) {
              storyIds.add(story.storyId);
            }
          }

          final viewedStoryIds = <String>{};
          if (storyIds.isNotEmpty) {
            try {
              // Batch check viewer documents (limit to 10 at a time)
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

          // Process friends' stories
          for (final authorId in allUserIds) {
            if (processedAuthors.contains(authorId)) continue;
            final stories = storiesByAuthor[authorId] ?? [];
            if (stories.isEmpty) continue;

            processedAuthors.add(authorId);

            final authorData = userDocs[authorId];
            if (authorData == null) continue;

            // Check if current user has viewed all stories
            bool hasUnread = false;
            for (final story in stories) {
              if (!viewedStoryIds.contains(story.storyId)) {
                hasUnread = true;
                break;
              }
            }

            final photoUrl = authorData['photoUrl'];
            // Validate URL - must be HTTP/HTTPS or empty string
            final validatedUrl = (photoUrl != null &&
                    photoUrl is String &&
                    photoUrl.isNotEmpty &&
                    photoUrl.trim().isNotEmpty &&
                    (photoUrl.startsWith('http://') ||
                        photoUrl.startsWith('https://')))
                ? photoUrl.trim()
                : '';
            trayItems.add(StoryTrayItem(
              userId: authorId,
              username: authorData['username'] ?? 'Unknown',
              userAvatarUrl: validatedUrl,
              hasUnreadStory: hasUnread,
              storyCount: stories.length,
            ));
          }

          // Sort friends' stories (but keep user's own story first)
          if (trayItems.length > 1) {
            final ownStory = trayItems.removeAt(0);
            trayItems.sort((a, b) {
              if (a.hasUnreadStory != b.hasUnreadStory) {
                return a.hasUnreadStory ? -1 : 1;
              }
              return b.storyCount.compareTo(a.storyCount);
            });
            trayItems.insert(0, ownStory);
          }

          return trayItems;
        });
      }).handleError((error) {
        debugPrint('StoryRepository: Error in story tray stream: $error');
        return <StoryTrayItem>[];
      });
    } catch (e) {
      debugPrint('StoryRepository: Error getting story tray stream: $e');
      return Stream.value(<StoryTrayItem>[]);
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

  /// Reply to a story
  Future<void> replyToStory({
    required String storyId,
    required String replierId,
    required String content,
    required String replyType, // 'text' | 'emoji'
  }) async {
    try {
      // Get story to find author
      final storyDoc = await _db.collection('story_media').doc(storyId).get();
      if (!storyDoc.exists) {
        throw Exception('Story not found');
      }

      final story = StoryMedia.fromDoc(storyDoc);
      final authorId = story.authorId;

      // Create reply document
      final replyRef = _db
          .collection('story_media')
          .doc(storyId)
          .collection('replies')
          .doc();

      await replyRef.set({
        'replyId': replyRef.id,
        'replierId': replierId,
        'replyType': replyType,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update reply count
      await _db.collection('story_media').doc(storyId).update({
        'replyCount': FieldValue.increment(1),
      });

      // Also create DM message in chats collection
      // Find or create chat between author and replier
      final chatId = _getChatId(authorId, replierId);
      final chatRef = _db.collection('chats').doc(chatId);

      // Check if chat exists
      final chatDoc = await chatRef.get();
      if (!chatDoc.exists) {
        // Create chat
        await chatRef.set({
          'chatId': chatId,
          'users': [authorId, replierId],
          'lastMessage': content,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update chat
        await chatRef.update({
          'lastMessage': content,
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
      }

      // Create message in chat
      final messageRef = chatRef.collection('messages').doc();
      await messageRef.set({
        'messageId': messageRef.id,
        'senderId': replierId,
        'text': content,
        'type': replyType == 'emoji' ? 'emoji' : 'text',
        'storyReplyId': storyId, // Reference to the story
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Cloud Function will send notification
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

  /// Helper method to generate consistent chat ID
  String _getChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}
