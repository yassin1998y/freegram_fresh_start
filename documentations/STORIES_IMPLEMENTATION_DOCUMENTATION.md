# Stories Feature - Implementation Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Data Models](#data-models)
4. [UI Components](#ui-components)
5. [State Management](#state-management)
6. [Repository Layer](#repository-layer)
7. [Services](#services)
8. [User Flows](#user-flows)
9. [Features](#features)
10. [File Structure](#file-structure)
11. [Backend Integration](#backend-integration)
12. [Technical Details](#technical-details)

---

## Overview

The Stories feature is a social media component that allows users to share temporary media content (images and videos) that expires after 24 hours. Similar to Instagram Stories, it provides:

- **Temporary Content**: Stories automatically expire after 24 hours
- **Rich Media**: Support for images and videos (max 15 seconds)
- **Interactive Elements**: Text overlays, drawings, and stickers
- **Real-time Updates**: Live story tray updates using polling mechanism
- **View Tracking**: Automatic view counting and reply system
- **Owner Controls**: Delete stories, view insights, and manage content

---

## Architecture

The Stories feature follows a clean architecture pattern with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────┐
│                    UI Layer                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Story Creator │  │ Story Viewer │  │ Stories Tray │ │
│  │   Screen     │  │    Screen    │  │   Widget     │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│                 State Management                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │          StoryViewerCubit (BLoC)                 │  │
│  │  - Auto-advance timer management                 │  │
│  │  - Progress tracking                             │  │
│  │  - Navigation control                            │  │
│  │  - Pause/resume functionality                   │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│              Repository Layer                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │          StoryRepository                         │  │
│  │  - CRUD operations                               │  │
│  │  - Story tray streaming                         │  │
│  │  - View tracking                                 │  │
│  │  - Reply handling                                │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                        │
        ┌───────────────┴───────────────┐
        ▼                               ▼
┌──────────────────┐          ┌──────────────────┐
│  Cloudinary      │          │    Firestore     │
│     Service      │          │   Database      │
│  - Media upload  │          │  - Story data    │
│  - Thumbnails    │          │  - View tracking │
└──────────────────┘          └──────────────────┘
```

---

## Data Models

### 1. StoryMedia

**Location**: `lib/models/story_media_model.dart`

The primary model representing a story in the system.

**Properties**:
```dart
class StoryMedia {
  final String storyId;              // Unique identifier
  final String authorId;             // User who created the story
  final String mediaUrl;             // Cloudinary URL for media
  final String mediaType;            // 'image' | 'video'
  final String? thumbnailUrl;        // Video thumbnail URL
  final double? duration;             // Video duration in seconds
  final String? caption;              // Optional caption
  final List<TextOverlay>? textOverlays;  // Text overlays on story
  final List<DrawingPath>? drawings;      // Drawing paths
  final List<String>? stickerIds;        // Sticker IDs
  final DateTime createdAt;          // Creation timestamp
  final DateTime expiresAt;           // Expiration timestamp (24h)
  final int viewerCount;              // Number of viewers
  final int replyCount;               // Number of replies
  final bool isActive;                // Soft delete flag
}
```

**Key Features**:
- Supports both image and video media
- Rich content overlays (text, drawings, stickers)
- Automatic expiration tracking
- View and reply statistics
- Cross-platform timestamp handling (handles web-specific `LegacyJavaScriptObject`)

### 2. StoryTrayItem

**Location**: `lib/models/story_tray_item_model.dart`

Model for displaying stories in the horizontal tray.

**Properties**:
```dart
class StoryTrayItem {
  final String userId;              // Story author ID
  final String username;            // Story author username
  final String userAvatarUrl;       // Author avatar URL
  final bool hasUnreadStory;        // Unread indicator
  final int storyCount;             // Number of stories by user
}
```

### 3. TextOverlay

**Location**: `lib/models/text_overlay_model.dart`

Represents text overlays on stories.

**Properties**:
```dart
class TextOverlay {
  final String text;                // Text content
  final double x;                   // Normalized X position (0-1)
  final double y;                   // Normalized Y position (0-1)
  final double fontSize;            // Font size
  final String color;               // Hex color string
  final String style;               // 'bold' | 'outline' | 'neon'
  final double rotation;            // Rotation angle in degrees
}
```

### 4. DrawingPath

**Location**: `lib/models/drawing_path_model.dart`

Represents drawing paths on stories.

**Properties**:
```dart
class DrawingPath {
  final List<OffsetPoint> points;   // Drawing points
  final String color;               // Hex color string
  final double strokeWidth;         // Stroke width
}

class OffsetPoint {
  final double x;                   // Normalized X (0-1)
  final double y;                   // Normalized Y (0-1)
}
```

---

## UI Components

### 1. StoriesTrayWidget

**Location**: `lib/widgets/feed_widgets/stories_tray.dart`

Horizontal scrolling list of story avatars displayed at the top of the feed.

**Features**:
- Displays user's own story button first
- Shows friends' stories with unread indicators
- Real-time updates via stream (polling every 2 seconds)
- Loading skeletons while fetching
- Error state handling

**UI Structure**:
```
┌────────────────────────────────────────────────┐
│  [Your Story] [Friend 1] [Friend 2] [Friend 3] │
│     (64x64)     (64x64)    (64x64)    (64x64)   │
│                                                  │
│  Your Story    Username   Username   Username   │
└────────────────────────────────────────────────┘
```

**Key Code**:
```dart
StreamBuilder<List<StoryTrayItem>>(
  stream: storyRepository.getStoryTrayStream(userId),
  builder: (context, snapshot) {
    // Render horizontal list of story avatars
  },
)
```

### 2. StoryAvatarWidget

**Location**: `lib/widgets/feed_widgets/story_avatar.dart`

Individual story avatar in the tray with unread indicator.

**Features**:
- Circular avatar with gradient border
- Unread story indicator (colored ring)
- Tap to view stories
- Shows story count badge

### 3. StoryCreatorScreen

**Location**: `lib/screens/story_creator_screen.dart`

Full-screen interface for creating and editing stories.

**Features**:
- **Media Selection**:
  - Camera capture (photo/video)
  - Gallery selection
  - Web platform support (bytes-based upload)
  
- **Camera Controls**:
  - Front/back camera switching
  - Photo capture button
  - Video recording (long-press, max 15s)
  - Auto-stop after 15 seconds
  
- **Editing Tools**:
  - Text overlay editor
  - Drawing tool (planned)
  - Sticker picker (planned)
  
- **Posting Flow**:
  - Upload to Cloudinary
  - Save to Firestore
  - Option to post multiple stories
  - Success feedback

**UI Structure**:
```
┌─────────────────────────────────────┐
│  [X]              [Share]           │  AppBar
├─────────────────────────────────────┤
│                                     │
│         Media Preview              │
│      (Image or Video)              │
│                                     │
├─────────────────────────────────────┤
│  [Text] [Draw] [Stickers]         │  Toolbar
└─────────────────────────────────────┘
```

**Key Flows**:
1. **Media Selection**:
   - Show bottom sheet (Camera/Gallery)
   - Initialize camera if selected
   - Pick media from gallery
   - Handle web platform (bytes)

2. **Camera Mode**:
   - Camera preview fills screen
   - Top controls: Close, Switch camera
   - Bottom controls: Photo button, Video button (long-press)
   - Recording indicator during video

3. **Preview Mode**:
   - Display selected media
   - Show editing toolbar
   - Share button in AppBar

### 4. StoryViewerScreen

**Location**: `lib/screens/story_viewer_screen.dart`

Full-screen immersive story viewer with auto-advance.

**Features**:
- **Progress Indicators**:
  - Horizontal progress bars at top
  - One bar per story
  - Animated progress (updates every 100ms)
  - Orange color when paused
  
- **Media Display**:
  - Image: `CachedNetworkImage` with placeholder/error
  - Video: `VideoPlayer` with aspect ratio
  - Automatic video initialization
  
- **Content Overlays**:
  - Text overlays (positioned widgets)
  - Drawing paths (CustomPaint)
  
- **User Header**:
  - Avatar and username
  - Time ago indicator
  - Pause indicator (if paused)
  - Options menu (three dots)
  
- **Gestures**:
  - Tap left: Previous story
  - Tap right: Next story
  - Tap center: Toggle reply bar
  - Long-press: Pause story
  - Swipe up: Show reply bar
  - Swipe down: Exit viewer
  
- **Owner Actions**:
  - Delete story (with confirmation)
  - View insights (views, replies, stats)
  - Report story (all users)

**UI Structure**:
```
┌─────────────────────────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │  Progress bars
│                                     │
│  [Avatar] Username       [PAUSED] [⋮]│  Header
│           2h ago                    │
│                                     │
│                                     │
│         Story Media                 │
│      (Image or Video)              │
│                                     │
│                                     │
│         [Text Overlays]             │
│         [Drawings]                  │
│                                     │
│                                     │
│  ┌──────────────────────────────┐  │
│  │ 💬 Reply...           [Send] │  │  Reply bar
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
```

---

## State Management

### StoryViewerCubit

**Location**: `lib/blocs/story_viewer_cubit.dart`

BLoC-based state management for story viewing.

**State Classes**:
```dart
// Initial state
class StoryViewerInitial extends StoryViewerState

// Loading state
class StoryViewerLoading extends StoryViewerState

// Loaded state
class StoryViewerLoaded extends StoryViewerState {
  final List<StoryUser> usersWithStories;    // Users with active stories
  final int currentUserIndex;                 // Current user index
  final int currentStoryIndex;               // Current story index
  final Map<String, List<StoryMedia>> userStoriesMap;  // Stories by user
  final Map<String, double> progressMap;     // Progress by story ID
  final bool isPaused;                       // Pause state
}

// Error state
class StoryViewerError extends StoryViewerState {
  final String error;
}
```

**Key Methods**:

1. **loadStoriesForUsers()**:
   - Fetches stories for multiple users
   - Finds starting user
   - Initializes viewer state
   - Starts auto-advance timer

2. **nextStory()**:
   - Navigates to next story in current user's reel
   - Moves to next user if at end
   - Resets progress and starts timer

3. **previousStory()**:
   - Navigates to previous story
   - Moves to previous user if at start

4. **pauseStory()**:
   - Cancels progress and auto-advance timers
   - Sets paused state
   - Stops video playback

5. **resumeStory()**:
   - Calculates remaining time
   - Resumes progress timer
   - Resumes auto-advance timer
   - Resumes video playback

6. **updateProgress()**:
   - Updates progress map for current story
   - Triggers UI rebuild for progress bar

7. **deleteCurrentStory()**:
   - Validates ownership
   - Deletes from repository
   - Updates state
   - Navigates appropriately

**Timer Management**:
- **Auto-advance Timer**: Single timer that triggers next story
- **Progress Timer**: Periodic timer (100ms) for smooth progress updates
- **Duration Calculation**:
  - Images: 5 seconds
  - Videos: Actual duration (clamped to 15 seconds)

**Progress Calculation**:
```dart
final elapsed = DateTime.now().difference(_storyStartTime!);
final progress = (elapsed.inMilliseconds / _storyDuration!.inMilliseconds)
    .clamp(0.0, 1.0);
```

---

## Repository Layer

### StoryRepository

**Location**: `lib/repositories/story_repository.dart`

Centralized data access layer for stories.

**Key Methods**:

#### 1. createStory()
Creates a new story from a File (mobile).

**Flow**:
1. Upload media to Cloudinary
   - Images: Direct upload
   - Videos: Upload + generate thumbnail
2. Extract video duration if needed
3. Create Firestore document in `story_media` collection
4. Set expiration (24 hours from now)
5. Return story ID

**Parameters**:
- `userId`: Story author
- `mediaFile`: File to upload
- `mediaType`: 'image' | 'video'
- `caption`: Optional caption
- `textOverlays`: Optional text overlays
- `drawings`: Optional drawings
- `stickerIds`: Optional sticker IDs
- `videoDuration`: Optional pre-calculated duration

#### 2. createStoryFromBytes()
Creates story from bytes (web platform).

**Flow**:
- Similar to `createStory()` but uses bytes instead of File
- Currently only supports images (video not implemented for web)

#### 3. getStoryTrayStream()
Returns stream of story tray items for horizontal list.

**Implementation**:
- Uses `Stream.periodic` (every 2 seconds) for polling
- Fetches user's friends list
- Queries Firestore for active stories
- Groups by author
- Checks unread status
- Sorts: Own story first, then unread, then by story count

**Query**:
```dart
.collection('story_media')
.where('authorId', whereIn: batch)
.where('isActive', isEqualTo: true)
.orderBy('createdAt', descending: true)
```

**Index Required**:
- Collection: `story_media`
- Fields: `authorId` (ASC), `isActive` (ASC), `createdAt` (DESC)

#### 4. getUserStories()
Fetches all active stories for a specific user.

**Query**:
```dart
.collection('story_media')
.where('authorId', isEqualTo: userId)
.where('isActive', isEqualTo: true)
.orderBy('createdAt', descending: true)
```

**Filtering**:
- Filters expired stories in memory (avoids complex index)
- Sorts by creation time (newest first)

#### 5. markStoryAsViewed()
Marks a story as viewed by a user.

**Implementation**:
- Creates document in `story_media/{storyId}/viewers/{viewerId}`
- Cloud Function updates `viewerCount` automatically

#### 6. replyToStory()
Creates a reply to a story.

**Flow**:
1. Create reply document in `story_media/{storyId}/replies/{replyId}`
2. Increment reply count
3. Create/update DM chat
4. Create message in chat with story reference
5. Cloud Function sends notification

#### 7. deleteStory()
Soft deletes a story (sets `isActive: false`).

**Validation**:
- Checks story exists
- Verifies ownership
- Updates `isActive` flag

---

## Services

### CloudinaryService

**Location**: `lib/services/cloudinary_service.dart`

Handles media uploads to Cloudinary CDN.

**Key Methods**:

#### 1. uploadImageFromFile()
Uploads image from File object (mobile).

#### 2. uploadImageFromBytes()
Uploads image from bytes (web).

#### 3. uploadVideoFromFile()
Uploads video from File (mobile).

**Features**:
- Secure credential management via `.env`
- Progress tracking support
- Automatic retry on network failures
- Timeout handling (30s images, 60s videos)
- Error handling and logging

**Configuration**:
- Cloud name: `CLOUDINARY_CLOUD_NAME`
- Upload preset: `CLOUDINARY_UPLOAD_PRESET`

**Video Thumbnail Generation**:
- Uses `video_thumbnail` package
- Generates JPEG thumbnail (400px width, 75% quality)
- Uploads thumbnail separately
- Cleans up temporary files

---

## User Flows

### Flow 1: Creating a Story

```
1. User taps "Your Story" button (no story) or "+" icon
   ↓
2. StoryCreatorScreen opens
   ↓
3. Bottom sheet: Camera / Gallery
   ↓
4a. Camera Selected:
   - Request camera permission
   - Initialize camera
   - Show camera preview
   - User captures photo or records video
   ↓
4b. Gallery Selected:
   - Request storage permission
   - Open image picker
   - User selects media
   ↓
5. Media preview shown
   ↓
6. Optional: Add text overlays, drawings, stickers
   ↓
7. User taps "Share"
   ↓
8. Upload to Cloudinary (with progress)
   ↓
9. Create Firestore document
   ↓
10. Success dialog: "Post Another?" or "Done"
    ↓
11a. Post Another: Reset state, show picker again
11b. Done: Close screen
```

### Flow 2: Viewing Stories

```
1. User taps story avatar in tray
   ↓
2. StoryViewerScreen opens
   ↓
3. StoryViewerCubit loads stories:
   - Fetch stories for starting user
   - Fetch stories for friends
   - Find starting position
   ↓
4. Display first story:
   - Initialize media (image/video)
   - Start auto-advance timer
   - Start progress timer
   ↓
5. User interactions:
   - Tap left: Previous story
   - Tap right: Next story
   - Long-press: Pause
   - Swipe down: Exit
   ↓
6. Auto-advance:
   - Progress reaches 100%
   - Timer triggers nextStory()
   - Navigate to next story
   ↓
7. Story ends:
   - Move to next user
   - Or close if no more stories
```

### Flow 3: Managing Own Stories

```
1. User views own story
   ↓
2. Taps three dots menu
   ↓
3. Options shown:
   - Delete Story
   - View Insights
   - Report Story
   ↓
4a. Delete Selected:
   - Confirmation dialog
   - Delete from Firestore
   - Update state
   - Navigate to next story
   ↓
4b. Insights Selected:
   - Show dialog with stats:
     * Views count
     * Replies count
     * Media type
     * Duration
```

### Flow 4: Replying to Stories

```
1. User views story
   ↓
2. Swipes up or taps center
   ↓
3. Reply bar appears
   ↓
4. User types reply
   ↓
5. Taps send
   ↓
6. StoryRepository.replyToStory():
   - Create reply document
   - Update reply count
   - Create/update DM chat
   - Create message
   ↓
7. Cloud Function sends notification
```

---

## Features

### 1. Real-time Progress Timer

**Implementation**:
- Progress updates every 100ms
- Smooth animation using `AnimatedContainer`
- Visual feedback:
  - White: Playing
  - Orange: Paused
  - Progress bar shows time remaining

**Code**:
```dart
Timer.periodic(const Duration(milliseconds: 100), (timer) {
  final elapsed = DateTime.now().difference(_storyStartTime!);
  final progress = (elapsed.inMilliseconds / _storyDuration!.inMilliseconds)
      .clamp(0.0, 1.0);
  updateProgress(story.storyId, progress);
});
```

### 2. Auto-advance

**Behavior**:
- Images: 5 seconds
- Videos: Actual duration (max 15 seconds)
- Pauses on long-press
- Resumes from current position
- Smooth transitions between stories

### 3. Multiple Stories per User

**Support**:
- Users can post unlimited stories
- All active stories shown in viewer
- Progress bars for each story
- Navigation between stories

### 4. Delete Functionality

**Features**:
- Owner-only deletion
- Confirmation dialog
- Soft delete (sets `isActive: false`)
- Immediate UI update
- Navigates to next story if deleted

### 5. Story Insights

**Metrics**:
- View count
- Reply count
- Media type
- Duration (for videos)

### 6. Unread Indicators

**Implementation**:
- Checks `viewers` subcollection
- Shows colored ring if any story unread
- Updates in real-time

### 7. Web Platform Support

**Adaptations**:
- Uses bytes instead of File
- `Image.memory` instead of `Image.file`
- Handles web-specific Firestore timestamps

### 8. Long-press Pause

**Gesture**:
- Long-press anywhere on story
- Pauses auto-advance
- Pauses video playback
- Shows "PAUSED" indicator
- Release to resume

---

## File Structure

```
lib/
├── models/
│   ├── story_media_model.dart          # Main story model
│   ├── story_tray_item_model.dart       # Tray item model
│   ├── text_overlay_model.dart          # Text overlay model
│   └── drawing_path_model.dart          # Drawing path model
│
├── screens/
│   ├── story_creator_screen.dart        # Story creation UI
│   └── story_viewer_screen.dart         # Story viewing UI
│
├── widgets/
│   └── feed_widgets/
│       ├── stories_tray.dart            # Horizontal story tray
│       └── story_avatar.dart            # Individual story avatar
│
├── blocs/
│   └── story_viewer_cubit.dart          # Story viewer state management
│
├── repositories/
│   └── story_repository.dart            # Data access layer
│
└── services/
    └── cloudinary_service.dart           # Media upload service
```

---

## Backend Integration

### Firestore Collections

#### 1. story_media
Main collection for stories.

**Document Structure**:
```json
{
  "storyId": "string",
  "authorId": "string",
  "mediaUrl": "string (Cloudinary URL)",
  "mediaType": "image | video",
  "thumbnailUrl": "string (optional)",
  "duration": "number (optional, seconds)",
  "caption": "string (optional)",
  "textOverlays": [TextOverlay],
  "drawings": [DrawingPath],
  "stickerIds": ["string"],
  "createdAt": "Timestamp",
  "expiresAt": "Timestamp",
  "viewerCount": "number",
  "replyCount": "number",
  "isActive": "boolean"
}
```

#### 2. story_media/{storyId}/viewers/{viewerId}
Subcollection for tracking viewers.

**Document Structure**:
```json
{
  "viewerId": "string",
  "viewedAt": "Timestamp"
}
```

#### 3. story_media/{storyId}/replies/{replyId}
Subcollection for story replies.

**Document Structure**:
```json
{
  "replyId": "string",
  "replierId": "string",
  "replyType": "text | emoji",
  "content": "string",
  "createdAt": "Timestamp"
}
```

### Firestore Indexes

**Required Composite Index**:
```
Collection: story_media
Fields:
  - authorId (ASC)
  - isActive (ASC)
  - createdAt (DESC)
```

**Location**: `firestore.indexes.json`

### Cloud Functions

**Automatic Updates**:
- `viewerCount`: Updated when viewer document is created
- Notifications: Sent when story is replied to

### TTL Policies

**Automatic Deletion**:
- Stories are soft-deleted (`isActive: false`) after 24 hours
- Can be configured with Firestore TTL policies for hard deletion

---

## Technical Details

### Platform Compatibility

**Web**:
- Uses `Uint8List` instead of `File`
- `Image.memory` for image display
- Handles `LegacyJavaScriptObject` for Firestore timestamps

**Mobile**:
- Uses `File` objects
- `Image.file` for local preview
- Camera integration

### Performance Optimizations

1. **Streaming**: Uses polling instead of real-time listeners (reduces Firestore costs)
2. **Caching**: `CachedNetworkImage` for story media
3. **Batch Queries**: Processes users in batches of 10 (Firestore limit)
4. **Lazy Loading**: Stories loaded on-demand
5. **Timer Management**: Proper cleanup on dispose

### Error Handling

**Strategies**:
- Try-catch blocks around async operations
- Fallback queries (without orderBy if index missing)
- User-friendly error messages
- Graceful degradation (show empty state)

### Security

**Firestore Rules** (required):
```javascript
match /story_media/{storyId} {
  // Read: Own stories or friends' active stories
  allow read: if request.auth != null && 
    (resource.data.authorId == request.auth.uid ||
     resource.data.isActive == true);
  
  // Write: Only own stories
  allow write: if request.auth != null && 
    request.auth.uid == resource.data.authorId;
}
```

### Dependencies

**Key Packages**:
- `flutter_bloc`: State management
- `cloud_firestore`: Database
- `cached_network_image`: Image caching
- `video_player`: Video playback
- `video_thumbnail`: Thumbnail generation
- `camera`: Camera capture
- `image_picker`: Media selection
- `http`: Cloudinary uploads

---

## Summary

The Stories feature is a comprehensive implementation that provides:

✅ **Full CRUD operations** for stories  
✅ **Real-time updates** via polling  
✅ **Rich media support** (images & videos)  
✅ **Interactive content** (text, drawings)  
✅ **Auto-advance** with progress indicators  
✅ **Owner controls** (delete, insights)  
✅ **View tracking** and replies  
✅ **Cross-platform** support (web & mobile)  
✅ **Professional UX** with smooth animations  

The architecture follows best practices with clear separation of concerns, proper state management, and comprehensive error handling.

