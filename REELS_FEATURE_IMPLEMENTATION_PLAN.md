# Reels Feature Implementation Plan

## 1. Analysis Summary

### Theme System Analysis

**`app_theme.dart` (SonarPulseTheme):**
- Primary accent color: `#00BFA5` (Teal/Cyan) with light/dark variants
- Uses Google Fonts (OpenSans) with a comprehensive TextTheme
- Light/Dark theme support with proper color schemes
- App-wide gradients (`appLinearGradient`, `appRadialGradient`)
- Card themes with 12px border radius
- Elevated button styles with 12px radius

**`design_tokens.dart` (DesignTokens):**
- 8px grid spacing system (spaceXS → spaceXXXL)
- Border radius scale (radiusXS → radiusXXL)
- Icon sizes (iconXS → iconXXL)
- Typography scale (fontSizeXS → fontSizeDisplay)
- Animation durations and curves
- Shadow definitions (shadowLight → shadowFloating)
- Opacity values for overlays

**Application to Reels UI:**
- All overlays will use `Theme.of(context).colorScheme` for colors
- Spacing from `DesignTokens.space*` for consistent padding/margins
- Icons sized using `DesignTokens.icon*` constants
- Text styles from `Theme.of(context).textTheme`
- Primary accent color (`#00BFA5`) for interactive elements (like button, heart icon when liked)
- Glassmorphic effects using `DesignTokens.glassmorphicGradient` for overlays
- Shadows from `DesignTokens.shadow*` for depth

---

## 2. File/Widget Structure

### New Files to Create:

```
lib/
├── models/
│   └── reel_model.dart                    # Reel data model
├── repositories/
│   └── reel_repository.dart               # Firestore operations for reels
├── blocs/
│   ├── reels_feed_bloc.dart              # BLoC for reels feed state management
│   ├── reels_feed_event.dart
│   └── reels_feed_state.dart
├── screens/
│   ├── reels_feed_screen.dart            # Main full-screen reels feed
│   └── create_reel_screen.dart           # Reel creation flow
├── widgets/
│   ├── reels/
│   │   ├── reels_player_widget.dart      # Single reel player with video
│   │   ├── reels_video_ui_overlay.dart   # Overlays (like, comment, share, user info)
│   │   ├── reels_side_actions.dart       # Right side action buttons
│   │   └── reels_bottom_sheet.dart       # Bottom sheet for comments/likes
│   └── reels/
│       └── reel_upload_progress.dart     # Upload progress indicator
└── services/
    └── video_upload_service.dart         # Video compression & upload service
```

### Packages to Add to `pubspec.yaml`:

```yaml
dependencies:
  # Video compression (add this - currently commented out)
  video_compress: ^3.1.2
  
  # Optional but recommended for smoother scrolling
  # preload_page_view: ^0.1.4  # If available, or use PageView with custom preloading
  
  # Already have these:
  # video_player: ^2.8.6
  # visibility_detector: ^0.4.0+2
  # cached_network_image: ^3.3.1
```

---

## 3. Firestore Data Model

### Collection: `reels`

```dart
// Document Structure
{
  "reelId": "string (auto-generated)",
  "uploaderId": "string (userId)",
  "uploaderUsername": "string",
  "uploaderAvatarUrl": "string",
  
  // Media
  "videoUrl": "string (Cloudinary URL)",
  "thumbnailUrl": "string (Cloudinary URL)",
  "duration": number (seconds),
  
  // Content
  "caption": "string (optional)",
  "hashtags": ["string"] (optional),
  "mentions": ["userId"] (optional),
  
  // Engagement
  "likeCount": number,
  "commentCount": number,
  "shareCount": number,
  "viewCount": number,
  
  // Metadata
  "createdAt": Timestamp,
  "updatedAt": Timestamp,
  "isActive": boolean,
  
  // Optional: Location
  "location": {
    "name": "string",
    "latitude": number,
    "longitude": number
  } (optional),
  
  // Optional: Audio/Music
  "audioTrack": {
    "title": "string",
    "artist": "string",
    "url": "string"
  } (optional)
}

// Subcollections:
reels/{reelId}/
  ├── likes/{userId}/
  │   └── { "userId": "string", "likedAt": Timestamp }
  │
  └── comments/{commentId}/
      └── {
          "commentId": "string",
          "userId": "string",
          "username": "string",
          "userAvatarUrl": "string",
          "text": "string",
          "createdAt": Timestamp,
          "likeCount": number,
          "replies": [] (optional)
        }
```

### Firestore Indexes Required:

```json
{
  "indexes": [
    {
      "collectionGroup": "reels",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "isActive", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

---

## 4. Key Code Implementation

### 4.1 Reel Model (`lib/models/reel_model.dart`)

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

class ReelModel extends Equatable {
  final String reelId;
  final String uploaderId;
  final String uploaderUsername;
  final String uploaderAvatarUrl;
  final String videoUrl;
  final String thumbnailUrl;
  final double duration; // in seconds
  final String? caption;
  final List<String> hashtags;
  final List<String> mentions;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int viewCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final Map<String, dynamic>? location;
  final Map<String, dynamic>? audioTrack;

  const ReelModel({
    required this.reelId,
    required this.uploaderId,
    required this.uploaderUsername,
    required this.uploaderAvatarUrl,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.duration,
    this.caption,
    this.hashtags = const [],
    this.mentions = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.viewCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.location,
    this.audioTrack,
  });

  factory ReelModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ReelModel.fromMap(doc.id, data);
  }

  factory ReelModel.fromMap(String reelId, Map<String, dynamic> data) {
    return ReelModel(
      reelId: reelId,
      uploaderId: data['uploaderId'] ?? '',
      uploaderUsername: data['uploaderUsername'] ?? 'Unknown',
      uploaderAvatarUrl: data['uploaderAvatarUrl'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      duration: (data['duration'] ?? 0).toDouble(),
      caption: data['caption'],
      hashtags: List<String>.from(data['hashtags'] ?? []),
      mentions: List<String>.from(data['mentions'] ?? []),
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _toDateTime(data['updatedAt']) ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      location: data['location'] as Map<String, dynamic>?,
      audioTrack: data['audioTrack'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uploaderId': uploaderId,
      'uploaderUsername': uploaderUsername,
      'uploaderAvatarUrl': uploaderAvatarUrl,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'caption': caption,
      'hashtags': hashtags,
      'mentions': mentions,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'viewCount': viewCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      if (location != null) 'location': location,
      if (audioTrack != null) 'audioTrack': audioTrack,
    };
  }

  static DateTime? _toDateTime(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is int) {
      return timestamp > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    }
    return null;
  }

  @override
  List<Object?> get props => [
        reelId,
        uploaderId,
        uploaderUsername,
        uploaderAvatarUrl,
        videoUrl,
        thumbnailUrl,
        duration,
        caption,
        hashtags,
        mentions,
        likeCount,
        commentCount,
        shareCount,
        viewCount,
        createdAt,
        updatedAt,
        isActive,
        location,
        audioTrack,
      ];
}
```

### 4.2 Reels Feed Screen (`lib/screens/reels_feed_screen.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:freegram/blocs/reels_feed_bloc.dart';
import 'package:freegram/widgets/reels/reels_player_widget.dart';
import 'package:freegram/theme/design_tokens.dart';

class ReelsFeedScreen extends StatefulWidget {
  const ReelsFeedScreen({Key? key}) : super(key: key);

  @override
  State<ReelsFeedScreen> createState() => _ReelsFeedScreenState();
}

class _ReelsFeedScreenState extends State<ReelsFeedScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    context.read<ReelsFeedBloc>().add(LoadReelsFeed());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: BlocBuilder<ReelsFeedBloc, ReelsFeedState>(
        builder: (context, state) {
          if (state is ReelsFeedLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            );
          }

          if (state is ReelsFeedError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: DesignTokens.iconXXL,
                    color: theme.colorScheme.error,
                  ),
                  SizedBox(height: DesignTokens.spaceMD),
                  Text(
                    state.message,
                    style: theme.textTheme.bodyLarge,
                  ),
                  SizedBox(height: DesignTokens.spaceLG),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ReelsFeedBloc>().add(LoadReelsFeed());
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is ReelsFeedLoaded) {
            if (state.reels.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      size: DesignTokens.iconXXL,
                      color: theme.colorScheme.onSurface.withOpacity(
                        DesignTokens.opacityMedium,
                      ),
                    ),
                    SizedBox(height: DesignTokens.spaceMD),
                    Text(
                      'No reels available',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(
                          DesignTokens.opacityMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                // Pause previous video, play current
                if (index > 0) {
                  context.read<ReelsFeedBloc>().add(
                    PauseReel(state.reels[index - 1].reelId),
                  );
                }
                context.read<ReelsFeedBloc>().add(
                  PlayReel(state.reels[index].reelId),
                );
              },
              itemCount: state.reels.length,
              itemBuilder: (context, index) {
                final reel = state.reels[index];
                return ReelsPlayerWidget(
                  reel: reel,
                  isCurrentReel: index == _currentIndex,
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
```

### 4.3 Reels Video UI Overlay (`lib/widgets/reels/reels_video_ui_overlay.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/reels/reels_side_actions.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';

class ReelsVideoUIOverlay extends StatelessWidget {
  final ReelModel reel;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onProfileTap;

  const ReelsVideoUIOverlay({
    Key? key,
    required this.reel,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onProfileTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Stack(
        children: [
          // Bottom section: User info + Caption
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: EdgeInsets.only(
                left: DesignTokens.spaceMD,
                right: DesignTokens.spaceMD,
                bottom: DesignTokens.spaceXL,
                top: DesignTokens.spaceLG,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // User info row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onProfileTap,
                        child: Container(
                          width: DesignTokens.iconLG,
                          height: DesignTokens.iconLG,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: reel.uploaderAvatarUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: reel.uploaderAvatarUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        Icon(
                                      Icons.person,
                                      color: theme.colorScheme.onSurface,
                                      size: DesignTokens.iconMD,
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    color: theme.colorScheme.onSurface,
                                    size: DesignTokens.iconMD,
                                  ),
                          ),
                        ),
                      ),
                      SizedBox(width: DesignTokens.spaceSM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: onProfileTap,
                              child: Text(
                                reel.uploaderUsername,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (reel.createdAt != null)
                              Text(
                                timeago.format(reel.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: DesignTokens.spaceMD),
                  // Caption
                  if (reel.caption != null && reel.caption!.isNotEmpty)
                    Text(
                      reel.caption!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        height: DesignTokens.lineHeightNormal,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          // Right side actions
          Positioned(
            right: DesignTokens.spaceMD,
            bottom: DesignTokens.spaceXXL,
            child: ReelsSideActions(
              reel: reel,
              isLiked: isLiked,
              onLike: onLike,
              onComment: onComment,
              onShare: onShare,
            ),
          ),
        ],
      ),
    );
  }
}
```

### 4.4 Reels Side Actions (`lib/widgets/reels/reels_side_actions.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ReelsSideActions extends StatelessWidget {
  final ReelModel reel;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const ReelsSideActions({
    Key? key,
    required this.reel,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Like button
        _ActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          iconColor: isLiked
              ? SonarPulseTheme.primaryAccent
              : Colors.white,
          count: reel.likeCount,
          onTap: onLike,
          showAnimation: isLiked,
        ),
        SizedBox(height: DesignTokens.spaceLG),
        // Comment button
        _ActionButton(
          icon: Icons.comment_outlined,
          iconColor: Colors.white,
          count: reel.commentCount,
          onTap: onComment,
        ),
        SizedBox(height: DesignTokens.spaceLG),
        // Share button
        _ActionButton(
          icon: Icons.share_outlined,
          iconColor: Colors.white,
          count: reel.shareCount,
          onTap: onShare,
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final int count;
  final VoidCallback onTap;
  final bool showAnimation;

  const _ActionButton({
    Key? key,
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.onTap,
    this.showAnimation = false,
  }) : super(key: key);

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: DesignTokens.durationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: DesignTokens.curveEaseOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (widget.showAnimation) {
              _controller.forward().then((_) {
                _controller.reverse();
              });
            }
            widget.onTap();
          },
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: DesignTokens.iconXL,
                  height: DesignTokens.iconXL,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.iconColor,
                    size: DesignTokens.iconLG,
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: DesignTokens.spaceXS),
        Text(
          _formatCount(widget.count),
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
```

### 4.5 Video Upload Service (`lib/services/video_upload_service.dart`)

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:freegram/services/cloudinary_service.dart';
import 'package:freegram/models/reel_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class VideoUploadService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Compress and upload video, then create Firestore entry
  /// Returns the created ReelModel on success
  Future<ReelModel?> uploadReel({
    required File videoFile,
    String? caption,
    List<String>? hashtags,
    List<String>? mentions,
    required Function(double progress) onProgress,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Step 1: Compress video (with progress tracking)
      debugPrint('VideoUploadService: Starting video compression...');
      onProgress(0.1);

      final compressedVideo = await _compressVideo(
        videoFile,
        onCompressionProgress: (progress) {
          // Compression takes ~30% of total progress
          onProgress(0.1 + (progress * 0.3));
        },
      );

      if (compressedVideo == null) {
        throw Exception('Video compression failed');
      }

      onProgress(0.4);

      // Step 2: Generate thumbnail
      debugPrint('VideoUploadService: Generating thumbnail...');
      final thumbnailFile = await _generateThumbnail(compressedVideo);
      onProgress(0.5);

      // Step 3: Upload video to Cloudinary (40% of progress)
      debugPrint('VideoUploadService: Uploading video to Cloudinary...');
      final videoUrl = await CloudinaryService.uploadVideoFromFile(
        compressedVideo,
        onProgress: (progress) {
          onProgress(0.5 + (progress * 0.4));
        },
      );

      if (videoUrl == null || videoUrl.isEmpty) {
        throw Exception('Video upload failed');
      }

      onProgress(0.9);

      // Step 4: Upload thumbnail
      debugPrint('VideoUploadService: Uploading thumbnail...');
      final thumbnailUrl = thumbnailFile != null
          ? await CloudinaryService.uploadImageFromFile(thumbnailFile)
          : null;

      // Step 5: Get video duration
      final duration = await _getVideoDuration(compressedVideo);

      // Step 6: Get user info
      final userDoc = await _db.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};
      final username = userData['username'] ?? 'Unknown';
      final avatarUrl = userData['photoUrl'] ?? '';

      // Step 7: Create Firestore document
      debugPrint('VideoUploadService: Creating Firestore entry...');
      final reelRef = _db.collection('reels').doc();
      
      final reelData = {
        'reelId': reelRef.id,
        'uploaderId': currentUser.uid,
        'uploaderUsername': username,
        'uploaderAvatarUrl': avatarUrl,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl ?? '',
        'duration': duration,
        'caption': caption,
        'hashtags': hashtags ?? [],
        'mentions': mentions ?? [],
        'likeCount': 0,
        'commentCount': 0,
        'shareCount': 0,
        'viewCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await reelRef.set(reelData);

      // Clean up compressed file
      try {
        await compressedVideo.delete();
      } catch (e) {
        debugPrint('VideoUploadService: Error deleting compressed file: $e');
      }

      if (thumbnailFile != null) {
        try {
          await thumbnailFile.delete();
        } catch (e) {
          debugPrint('VideoUploadService: Error deleting thumbnail: $e');
        }
      }

      onProgress(1.0);

      debugPrint('VideoUploadService: Reel uploaded successfully!');
      return ReelModel.fromDoc(await reelRef.get());
    } catch (e) {
      debugPrint('VideoUploadService: Error uploading reel: $e');
      rethrow;
    }
  }

  Future<File?> _compressVideo(
    File videoFile, {
    required Function(double progress) onCompressionProgress,
  }) async {
    try {
      // Compress video with quality settings
      final mediaInfo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality, // Adjust based on needs
        deleteOrigin: false,
        includeAudio: true,
      );

      if (mediaInfo == null) {
        return null;
      }

      return File(mediaInfo.path);
    } catch (e) {
      debugPrint('VideoUploadService: Compression error: $e');
      // If compression fails, return original file
      return videoFile;
    }
  }

  Future<File?> _generateThumbnail(File videoFile) async {
    try {
      final thumbnailData = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 85,
      );

      if (thumbnailData == null) {
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final thumbnailFile = File(
        path.join(
          tempDir.path,
          'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      await thumbnailFile.writeAsBytes(thumbnailData);
      return thumbnailFile;
    } catch (e) {
      debugPrint('VideoUploadService: Thumbnail generation error: $e');
      return null;
    }
  }

  Future<double> _getVideoDuration(File videoFile) async {
    try {
      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      final duration = controller.value.duration.inSeconds.toDouble();
      await controller.dispose();
      return duration;
    } catch (e) {
      debugPrint('VideoUploadService: Error getting duration: $e');
      return 0.0;
    }
  }
}
```

---

## 5. Additional Implementation Notes

### 5.1 BLoC Events & States (Skeleton)

```dart
// reels_feed_event.dart
abstract class ReelsFeedEvent extends Equatable {
  const ReelsFeedEvent();
}

class LoadReelsFeed extends ReelsFeedEvent {
  @override
  List<Object?> get props => [];
}

class PlayReel extends ReelsFeedEvent {
  final String reelId;
  const PlayReel(this.reelId);
  @override
  List<Object?> get props => [reelId];
}

class PauseReel extends ReelsFeedEvent {
  final String reelId;
  const PauseReel(this.reelId);
  @override
  List<Object?> get props => [reelId];
}

class LikeReel extends ReelsFeedEvent {
  final String reelId;
  const LikeReel(this.reelId);
  @override
  List<Object?> get props => [reelId];
}

// reels_feed_state.dart
abstract class ReelsFeedState extends Equatable {
  const ReelsFeedState();
}

class ReelsFeedLoading extends ReelsFeedState {
  @override
  List<Object?> get props => [];
}

class ReelsFeedLoaded extends ReelsFeedState {
  final List<ReelModel> reels;
  final String? currentPlayingReelId;
  
  const ReelsFeedLoaded({
    required this.reels,
    this.currentPlayingReelId,
  });
  
  @override
  List<Object?> get props => [reels, currentPlayingReelId];
}

class ReelsFeedError extends ReelsFeedState {
  final String message;
  const ReelsFeedError(this.message);
  @override
  List<Object?> get props => [message];
}
```

### 5.2 Update `pubspec.yaml`

Add this line to dependencies:

```yaml
video_compress: ^3.1.2
```

### 5.3 Register ReelRepository in `locator.dart`

```dart
// Add import
import 'package:freegram/repositories/reel_repository.dart';

// In setupLocator function:
locator.registerLazySingleton(() => ReelRepository());
```

---

## 6. Testing Checklist

- [ ] Video compression works correctly
- [ ] Upload progress indicator shows accurate progress
- [ ] Videos auto-play when scrolled into view
- [ ] Videos pause when scrolled away
- [ ] Like/comment/share actions work
- [ ] UI overlays use theme colors correctly
- [ ] Spacing follows DesignTokens
- [ ] Firestore document created only after successful upload
- [ ] Thumbnail generation works
- [ ] Error handling for failed uploads
- [ ] Background upload continues after navigation

---

## 7. Next Steps

1. Create all the files listed above
2. Implement the ReelRepository (similar to StoryRepository)
3. Add the BLoC implementation
4. Test video compression and upload flow
5. Integrate with navigation/routing
6. Add Firestore security rules for reels collection
7. Implement comments/likes functionality
8. Add analytics tracking

---

**End of Implementation Plan**

