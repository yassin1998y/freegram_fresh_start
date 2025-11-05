# Stories Feature - Quick Reference Guide

**Quick reference for developers implementing the Stories feature.**

---

## Data Models

### StoryMedia Model
```dart
class StoryMedia {
  final String storyId;
  final String authorId;
  final String mediaUrl;
  final String mediaType; // 'image' | 'video'
  final String? thumbnailUrl;
  final double? duration; // Video duration in seconds
  final String? caption;
  final List<TextOverlay>? textOverlays;
  final List<DrawingPath>? drawings;
  final List<String>? stickerIds;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewerCount;
  final int replyCount;
  final bool isActive;
}
```

### StoryTrayItem Model
```dart
class StoryTrayItem {
  final String userId;
  final String username;
  final String userAvatarUrl;
  final bool hasUnreadStory;
  final int storyCount;
}
```

### TextOverlay Model
```dart
class TextOverlay {
  final String text;
  final double x; // 0-1 normalized
  final double y; // 0-1 normalized
  final double fontSize;
  final String color; // Hex color
  final String style; // 'bold' | 'outline' | 'neon'
  final double rotation; // Degrees
}
```

---

## Firestore Collections

### `story_media` (Top-level collection)
```
story_media/{storyId}
  - storyId: string
  - authorId: string
  - mediaUrl: string
  - mediaType: 'image' | 'video'
  - thumbnailUrl?: string
  - duration?: number
  - caption?: string
  - textOverlays?: array
  - drawings?: string
  - stickerIds?: array
  - createdAt: timestamp
  - expiresAt: timestamp (TTL field)
  - viewerCount: number
  - replyCount: number
  - isActive: boolean
```

### `story_media/{storyId}/viewers` (Subcollection)
```
viewers/{viewerId}
  - viewerId: string (document ID)
  - viewedAt: timestamp
```

### `story_media/{storyId}/replies` (Subcollection)
```
replies/{replyId}
  - replyId: string
  - replierId: string
  - replyType: 'text' | 'emoji'
  - content: string
  - createdAt: timestamp
```

### `users/{userId}/highlights` (Subcollection)
```
highlights/{highlightId}
  - highlightId: string
  - title: string
  - coverImageUrl: string
  - createdAt: timestamp
  - updatedAt: timestamp
```

### `users/{userId}/highlights/{highlightId}/stories` (Subcollection)
```
stories/{storyId}
  - storyId: string
  - mediaUrl: string
  - mediaType: 'image' | 'video'
  - thumbnailUrl?: string
  - addedAt: timestamp
```

---

## Repository Methods

### StoryRepository.createStory()
```dart
Future<String> createStory({
  required String userId,
  required File mediaFile,
  required String mediaType,
  String? caption,
  List<TextOverlay>? textOverlays,
  List<DrawingPath>? drawings,
  List<String>? stickerIds,
  double? videoDuration,
}) async
```

### StoryRepository.getStoryTrayStream()
```dart
Stream<List<StoryTrayItem>> getStoryTrayStream(String userId)
```

### StoryRepository.getUserStories()
```dart
Future<List<StoryMedia>> getUserStories(String userId) async
```

### StoryRepository.markStoryAsViewed()
```dart
Future<void> markStoryAsViewed(String storyId, String viewerId) async
```

### StoryRepository.replyToStory()
```dart
Future<void> replyToStory(
  String storyId,
  String replierId,
  String content,
  String replyType,
) async
```

---

## Key Constants

```dart
class StoryConstants {
  static const maxVideoDurationSeconds = 15;
  static const imageStoryDurationSeconds = 5;
  static const maxFileSizeBytes = 10 * 1024 * 1024; // 10MB
  static const storyExpiryHours = 24;
}
```

---

## Navigation Routes

```dart
// From StoriesTrayWidget
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => StoryCreatorScreen(), // "Your Story" button
  ),
);

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => StoryViewerScreen(startingUserId: userId), // Story avatar tap
  ),
);
```

---

## Required Packages

Add to `pubspec.yaml`:
```yaml
dependencies:
  camera: ^0.10.5
  video_player: ^2.8.6
  video_thumbnail: ^0.5.3
  # firebase_storage: ^11.6.0 # Optional, if not using Cloudinary
```

---

## Firestore Indexes

```javascript
// Required index for story tray queries
{
  collectionGroup: 'story_media',
  fields: [
    { fieldPath: 'authorId', order: 'ASCENDING' },
    { fieldPath: 'expiresAt', order: 'DESCENDING' },
    { fieldPath: 'isActive', order: 'ASCENDING' }
  ]
}
```

---

## TTL Policy Setup

1. Go to Firebase Console → Firestore → Indexes
2. Enable TTL policy on `story_media` collection
3. Field: `expiresAt`
4. Documents will be automatically deleted after expiry

---

## Cloud Functions

### notifyStoryReply
**Trigger**: `onDocumentCreated('story_media/{storyId}/replies/{replyId}')`  
**Purpose**: Send FCM notification to story author when someone replies

### updateStoryViewCount
**Trigger**: `onDocumentWritten('story_media/{storyId}/viewers/{viewerId}')`  
**Purpose**: Update `viewerCount` field in story document

---

## Storage Paths

**Pattern**: `/stories/{userId}/{storyId}.{ext}`

**Examples**:
- `/stories/user123/story_abc123.jpg` (image)
- `/stories/user123/story_abc123.mp4` (video)
- `/stories/user123/story_abc123_thumb.jpg` (thumbnail)

**Note**: Consider using Cloudinary (consistent with posts) instead of Firebase Storage.

---

## Gesture Handling

| Gesture | Action |
|---------|--------|
| Tap Right / Swipe Left | Next story |
| Tap Left / Swipe Right | Previous story |
| Swipe Up | Reply to story |
| Swipe Down | Exit viewer |
| Tap and Hold | Pause video |
| Long Press | Show reply bar |

---

## Story Display Duration

- **Image Stories**: 5 seconds
- **Video Stories**: Play duration (max 15 seconds)

---

## MVP Feature Checklist

### Story Creation
- [x] Camera capture
- [x] Gallery selection
- [x] Text overlay tool
- [x] Simple drawing tool
- [x] Basic stickers
- [ ] Music (deferred)
- [ ] Polls (deferred)
- [ ] Filters (deferred)

### Story Viewing
- [x] Auto-advance
- [x] Progress bars
- [x] Gesture navigation
- [x] Reply functionality
- [x] Viewer tracking
- [ ] Highlights (deferred)

---

## Testing Checklist

- [ ] Story creation (photo)
- [ ] Story creation (video)
- [ ] Text overlay editing
- [ ] Drawing tool
- [ ] Sticker placement
- [ ] Story upload
- [ ] Story viewing
- [ ] Auto-advance
- [ ] Gesture handling
- [ ] Reply sending
- [ ] Viewer tracking
- [ ] Story expiry (24 hours)
- [ ] Offline queue (if implemented)

---

**Quick Reference Version**: 1.0  
**Last Updated**: 2024

