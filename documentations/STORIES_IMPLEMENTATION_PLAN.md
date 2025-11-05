# Stories Feature - Comprehensive Implementation Plan

**Project:** Freegram V2 Development Sprint  
**Feature:** Ephemeral 24-Hour Stories System  
**Status:** Planning Phase  
**Created:** 2024

---

## Executive Summary

This document provides a complete, end-to-end implementation plan for the Stories feature - an ephemeral content system where users can share photos/videos that automatically expire after 24 hours. The plan follows a three-phase approach: Research & UX Strategy, Database Architecture, and Detailed Implementation Blueprint.

---

## Phase 1: Research & UX Strategy

### 1.1 Story Creation UX Analysis

#### Best-in-Class References
- **Instagram Stories**: Industry standard for story creation and viewing
- **Snapchat**: Pioneer of ephemeral content with intuitive gestures
- **WhatsApp Status**: Simple, accessible story system

#### MVP Must-Have Tools (Phase 1)
1. **Media Capture**
   - Camera capture (photo/video)
   - Gallery selection (photo/video)
   - Basic video recording (max 15 seconds for MVP)

2. **Text Overlay Tool**
   - Multiple text styles (bold, outline, neon)
   - Draggable and resizable text boxes
   - Color picker (8-12 preset colors)
   - Font size adjustment

3. **Simple Drawing Tool**
   - Pen tool with color selection
   - Brush size (3-5 presets)
   - Eraser (optional for MVP)

4. **Basic Image Stickers**
   - 5-10 preset emoji stickers
   - Draggable and resizable
   - Rotate capability

#### Deferred Features (Post-MVP)
- Music background integration
- Polls and quizzes
- GIF stickers (Giphy integration)
- Filters and effects
- Video trimming/editing
- Location stickers
- Mention stickers
- Link stickers

#### UX Flow for Story Creation
```
1. User taps "Your Story" button
2. StoryCreatorScreen opens
3. Camera viewfinder (default) OR Gallery button
4. User captures/selects media
5. Preview screen with editing tools:
   - Bottom toolbar: Text, Draw, Stickers, Delete
   - Top toolbar: Close, Done
6. User applies edits (text, drawing, stickers)
7. User taps "Share" → Story uploads → Returns to feed
```

### 1.2 Story Viewing UX Analysis

#### Gesture Handling (Industry Standard)
- **Tap Right (or Swipe Left)**: Next story in current user's reel
- **Tap Left (or Swipe Right)**: Previous story in current user's reel
- **Swipe Up**: Reply to story (opens reply composer)
- **Swipe Down**: Exit story viewer (returns to feed)
- **Tap and Hold**: Pause story (video only)
- **Long Press**: Reveal reply/emoji reaction bar

#### Auto-Advance Behavior
- **Image Stories**: 5 seconds display time
- **Video Stories**: Play duration (max 15 seconds)
- **Progress Indicators**: Top progress bars showing story count and current progress
- **Transition**: Smooth fade between stories in same reel

#### Replies/Reactions
- **Replies**: Direct message to story author (stored in DMs)
- **Emoji Reactions**: Quick reactions (❤️, 😂, 😮, 😢) sent as DM
- **Viewer List**: Story author can see who viewed their story
- **No Public Comments**: Stories don't support public comments (different from posts)

#### Viewing Flow
```
1. User taps StoryAvatarWidget in tray
2. StoryViewerScreen opens (fullscreen)
3. Shows first story from selected user
4. Auto-advances through user's stories
5. After last story, advances to next user with stories
6. User can exit at any time via swipe down
```

### 1.3 Technical Architecture Patterns

#### 24-Hour Expiry Handling

**Option A: Firestore TTL Policies (Recommended)**
- **Pros**: 
  - Automatic deletion, no Cloud Functions needed
  - Cost-efficient (no function execution costs)
  - Reliable (managed by Firebase)
- **Cons**: 
  - TTL is approximate (can be delayed by hours)
  - Requires `expiresAt` field as Timestamp
- **Implementation**: Set `expiresAt` field to `now + 24 hours` on story creation

**Option B: Scheduled Cloud Functions**
- **Pros**: 
  - Precise deletion timing
  - Can send notifications before expiry
- **Cons**: 
  - Higher cost (function execution + Firestore reads)
  - More complex to implement
- **Use Case**: If we need precise 24-hour expiry or pre-expiry notifications

**Recommendation**: Use **Firestore TTL Policies** for MVP. More cost-effective and simpler.

#### Highlights (Saved Stories) Implementation

**Architecture Pattern:**
- Stories are saved to a `highlights` subcollection on user document
- Each highlight is a collection (e.g., "Travel", "Food", "Daily Life")
- Highlight contains references to original story media URLs
- Original story document remains in `story_media` (expires after 24h)
- Highlight stores a copy of media URL and metadata

**Data Flow:**
```
1. User creates story → stored in `story_media` collection
2. User saves story to highlight → creates doc in `users/{userId}/highlights/{highlightId}/stories/{storyId}`
3. Original story expires after 24h
4. Highlight stories persist indefinitely (user can delete manually)
```

#### Viewer Lists Storage

**Scalability Challenge:**
- A popular story could have thousands of viewers
- Storing all viewers in a single document would hit Firestore's 1MB document limit

**Solution: Paginated Viewer List**
- **Option A**: Subcollection `story_media/{storyId}/viewers/{viewerId}`
  - Each viewer is a document with `viewedAt` timestamp
  - Pros: Scalable, can query recent viewers
  - Cons: More reads for viewer count
  
- **Option B**: Embedded Array with Viewer Count
  - Document has `viewerIds: [userId1, userId2, ...]` and `viewerCount: number`
  - Pros: Fast viewer count lookup
  - Cons: Limited to ~10,000 viewers (array size limit)
  
- **Option C**: Hybrid Approach (Recommended)
  - Store viewer count in story document: `viewerCount: number`
  - Store detailed viewer list in subcollection: `story_media/{storyId}/viewers/{viewerId}`
  - Use `viewerCount` for quick display, subcollection for detailed viewer list screen

**Recommendation**: Use **Hybrid Approach** for MVP.

---

## Phase 2: Firestore & Storage Architecture

### 2.1 Firestore Schema Design

#### Collection: `story_media`

**Purpose**: Stores individual story items (single photo/video)

**Document Structure:**
```typescript
{
  storyId: string,                    // Auto-generated document ID
  authorId: string,                    // User ID who created the story
  mediaUrl: string,                    // Firebase Storage URL (or Cloudinary URL)
  mediaType: 'image' | 'video',        // Media type
  thumbnailUrl?: string,               // Optional thumbnail for videos
  duration?: number,                   // Video duration in seconds (max 15)
  caption?: string,                    // Optional text caption
  textOverlays?: Array<{               // Text overlay data
    text: string,
    x: number,                          // Position X (0-1 normalized)
    y: number,                         // Position Y (0-1 normalized)
    fontSize: number,
    color: string,
    style: 'bold' | 'outline' | 'neon',
    rotation: number,                  // Rotation angle in degrees
  }>,
  drawings?: string,                   // Base64 encoded drawing paths (optional, for MVP use simple JSON)
  stickerIds?: Array<string>,          // Array of sticker IDs used
  createdAt: Timestamp,                // Story creation time
  expiresAt: Timestamp,                // TTL field for automatic deletion (createdAt + 24 hours)
  viewerCount: number,                 // Quick viewer count
  replyCount: number,                  // Quick reply count
  isActive: boolean,                   // Soft delete flag (set to false if manually deleted)
}
```

**Indexes Required:**
```javascript
// For fetching active stories from followed users
{
  collectionGroup: 'story_media',
  fields: [
    { fieldPath: 'authorId', order: 'ASCENDING' },
    { fieldPath: 'expiresAt', order: 'DESCENDING' },
    { fieldPath: 'isActive', order: 'ASCENDING' }
  ]
}
```

**TTL Policy:**
- Firestore will automatically delete documents where `expiresAt < now()`
- Set via Firebase Console: Collection → `story_media` → TTL → Enable → Field: `expiresAt`

#### Subcollection: `story_media/{storyId}/viewers`

**Purpose**: Stores detailed viewer information for each story

**Document Structure:**
```typescript
{
  viewerId: string,                   // User ID who viewed the story (document ID)
  viewedAt: Timestamp,                // When the story was viewed
  // Note: Document ID = viewerId for easy lookup
}
```

**Indexes Required:** None (simple queries by document ID)

#### Subcollection: `story_media/{storyId}/replies`

**Purpose**: Stores replies/reactions to stories (stored as DMs)

**Document Structure:**
```typescript
{
  replyId: string,                     // Auto-generated document ID
  replierId: string,                   // User ID who replied
  replyType: 'text' | 'emoji',         // Reply type
  content: string,                     // Text content or emoji
  createdAt: Timestamp,
  // Note: These replies also create DM messages in the chats collection
}
```

#### Collection: `users/{userId}/highlights`

**Purpose**: Stores saved story collections (highlights)

**Document Structure:**
```typescript
{
  highlightId: string,                 // Auto-generated document ID
  title: string,                       // Highlight title (e.g., "Travel", "Food")
  coverImageUrl: string,                // Cover image (first story's thumbnail)
  createdAt: Timestamp,
  updatedAt: Timestamp,
}
```

#### Subcollection: `users/{userId}/highlights/{highlightId}/stories`

**Purpose**: Stores story references within a highlight

**Document Structure:**
```typescript
{
  storyId: string,                     // Reference to original story_media document
  mediaUrl: string,                    // Copy of media URL (in case original expires)
  mediaType: 'image' | 'video',
  thumbnailUrl?: string,
  addedAt: Timestamp,
  // Note: Original story_media doc may expire, but highlight keeps media URL
}
```

### 2.2 Firebase Storage Structure

**Path Pattern:**
```
/stories/{userId}/{storyId}.{ext}
```

**Examples:**
- `/stories/user123/story_abc123.jpg` (image)
- `/stories/user123/story_abc123.mp4` (video)
- `/stories/user123/story_abc123_thumb.jpg` (video thumbnail)

**Storage Rules:**
```javascript
match /stories/{userId}/{storyId} {
  // Users can only upload to their own folder
  allow write: if request.auth != null && request.auth.uid == userId;
  
  // All authenticated users can read story media
  allow read: if request.auth != null;
  
  // File size limits
  allow write: if request.resource.size < 10 * 1024 * 1024; // 10MB max
}
```

**Note**: Consider using Cloudinary for story media (like posts) for better CDN performance and automatic optimization.

### 2.3 Cloud Functions Architecture

#### Function 1: Story Expiry Notification (Optional)

**Trigger**: Scheduled Cloud Function (runs every hour)
**Purpose**: Notify users before their story expires (optional feature)

**Implementation:**
```javascript
exports.notifyStoryExpiry = onSchedule('every 1 hours', async (event) => {
  // Query stories expiring in next 2 hours
  const expiringSoon = await admin.firestore()
    .collection('story_media')
    .where('expiresAt', '>', admin.firestore.Timestamp.now())
    .where('expiresAt', '<', admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 2 * 60 * 60 * 1000) // 2 hours from now
    ))
    .get();
  
  // Send notifications (if user wants this feature)
  // ...
});
```

#### Function 2: Story Reply Notification

**Trigger**: `onDocumentCreated('story_media/{storyId}/replies/{replyId}')`
**Purpose**: Notify story author when someone replies

**Implementation:**
```javascript
exports.notifyStoryReply = onDocumentCreated(
  'story_media/{storyId}/replies/{replyId}',
  async (event) => {
    const reply = event.data.data();
    const storyId = event.params.storyId;
    
    // Get story document
    const storyDoc = await admin.firestore()
      .collection('story_media')
      .doc(storyId)
      .get();
    
    if (!storyDoc.exists) return;
    
    const story = storyDoc.data();
    const authorId = story.authorId;
    const replierId = reply.replierId;
    
    // Get replier's username
    const replierDoc = await admin.firestore()
      .collection('users')
      .doc(replierId)
      .get();
    
    const replierUsername = replierDoc.data()?.username || 'Someone';
    
    // Send FCM notification to story author
    // (Similar to existing notification functions)
    // ...
  }
);
```

#### Function 3: Story View Tracking

**Trigger**: `onDocumentWritten('story_media/{storyId}/viewers/{viewerId}')`
**Purpose**: Update viewer count in story document

**Implementation:**
```javascript
exports.updateStoryViewCount = onDocumentWritten(
  'story_media/{storyId}/viewers/{viewerId}',
  async (event) => {
    const storyId = event.params.storyId;
    
    // Count viewers in subcollection
    const viewersSnapshot = await admin.firestore()
      .collection('story_media')
      .doc(storyId)
      .collection('viewers')
      .get();
    
    const viewerCount = viewersSnapshot.size;
    
    // Update story document
    await admin.firestore()
      .collection('story_media')
      .doc(storyId)
      .update({
        viewerCount: viewerCount,
      });
  }
);
```

---

## Phase 3: Detailed Implementation Blueprint

### 3.1 Story Creation UI

#### Screen: `StoryCreatorScreen`

**File**: `lib/screens/story_creator_screen.dart`

**Dependencies:**
- `image_picker` (already in pubspec.yaml)
- `camera` package (needs to be added)
- `video_player` (for video preview, needs to be added)

**State Management:**
- Use `StatefulWidget` with local state for MVP
- Consider `Cubit` if state becomes complex

**UI Structure:**
```dart
Scaffold(
  backgroundColor: Colors.black,
  body: Stack(
    children: [
      // Camera preview or selected media
      _buildMediaView(),
      
      // Top toolbar (Close button)
      _buildTopToolbar(),
      
      // Bottom toolbar (Text, Draw, Stickers, Share)
      _buildBottomToolbar(),
      
      // Text overlay widgets (if text tool active)
      ..._textOverlays,
      
      // Drawing canvas (if draw tool active)
      if (_drawingMode) _buildDrawingCanvas(),
      
      // Sticker widgets (if stickers added)
      ..._stickerWidgets,
    ],
  ),
)
```

**Key Methods:**

1. **`_initCamera()`**
   - Initialize camera controller
   - Request camera permission
   - Set camera preview

2. **`_pickFromGallery()`**
   - Use `ImagePicker` to select image/video
   - Support both image and video selection
   - Validate file size (max 10MB)

3. **`_capturePhoto()`**
   - Capture photo from camera
   - Save to temporary file
   - Switch to preview mode

4. **`_recordVideo()`**
   - Start video recording (max 15 seconds)
   - Show recording indicator
   - Stop recording on button release or timeout

5. **`_addTextOverlay()`**
   - Create draggable/resizable `TextField` widget
   - Position at center by default
   - Allow color/style selection

6. **`_addDrawing()`**
   - Use `CustomPainter` to draw on canvas
   - Store drawing paths as `List<Offset>`
   - Support color and brush size selection

7. **`_addSticker()`**
   - Show sticker picker bottom sheet
   - Add draggable/resizable sticker widget
   - Support rotation gesture

8. **`_shareStory()`**
   - Call `StoryRepository.createStory()`
   - Show upload progress
   - Navigate back to feed on success

#### Widget: `TextToolOverlay`

**File**: `lib/widgets/story_widgets/text_tool_overlay.dart`

**Features:**
- Draggable `TextField` wrapper
- Resize handles (corners)
- Color picker bottom sheet
- Style selector (bold, outline, neon)
- Font size slider

**Implementation:**
```dart
class TextToolOverlay extends StatefulWidget {
  final String initialText;
  final Function(String text, TextStyle style, Offset position, Size size) onUpdate;
  
  // ...
}

class _TextToolOverlayState extends State<TextToolOverlay> {
  Offset _position = Offset(0.5, 0.5); // Normalized position
  Size _size = Size(200, 50);
  String _text = '';
  Color _color = Colors.white;
  TextStyle _style = TextStyle();
  
  // GestureDetector for dragging
  // Resize handles at corners
  // TextField for editing
}
```

#### Widget: `DrawingToolOverlay`

**File**: `lib/widgets/story_widgets/drawing_tool_overlay.dart`

**Features:**
- Full-screen transparent canvas
- `CustomPainter` for drawing paths
- Color picker
- Brush size selector
- Clear button

**Implementation:**
```dart
class DrawingToolOverlay extends StatefulWidget {
  final Function(List<DrawingPath> paths) onDrawingComplete;
  // ...
}

class _DrawingToolOverlayState extends State<DrawingToolOverlay> {
  List<DrawingPath> _paths = [];
  Color _currentColor = Colors.white;
  double _brushSize = 5.0;
  
  // GestureDetector for pan gestures
  // CustomPainter to draw paths
}
```

#### Repository Method: `StoryRepository.createStory()`

**File**: `lib/repositories/story_repository.dart` (new file)

**Implementation:**
```dart
class StoryRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage? _storage; // Optional, if using Firebase Storage
  
  StoryRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage;
  
  /// Create a new story
  Future<String> createStory({
    required String userId,
    required File mediaFile, // Image or video file
    required String mediaType, // 'image' or 'video'
    String? caption,
    List<TextOverlay>? textOverlays,
    List<DrawingPath>? drawings,
    List<String>? stickerIds,
    double? videoDuration,
  }) async {
    try {
      // 1. Upload media to storage (Firebase Storage or Cloudinary)
      String mediaUrl;
      String? thumbnailUrl;
      
      if (mediaType == 'video') {
        // Upload video
        mediaUrl = await _uploadVideo(mediaFile);
        // Generate thumbnail (using video_thumbnail package or Cloudinary)
        thumbnailUrl = await _generateThumbnail(mediaFile);
      } else {
        // Upload image (using CloudinaryService like posts)
        mediaUrl = await CloudinaryService.uploadImageFromFile(mediaFile);
      }
      
      // 2. Create story document in Firestore
      final storyRef = _db.collection('story_media').doc();
      final now = FieldValue.serverTimestamp();
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24))
      );
      
      await storyRef.set({
        'storyId': storyRef.id,
        'authorId': userId,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'thumbnailUrl': thumbnailUrl,
        'duration': videoDuration,
        'caption': caption,
        'textOverlays': textOverlays?.map((t) => t.toMap()).toList(),
        'drawings': drawings?.map((d) => d.toMap()).toList(),
        'stickerIds': stickerIds ?? [],
        'createdAt': now,
        'expiresAt': expiresAt,
        'viewerCount': 0,
        'replyCount': 0,
        'isActive': true,
      });
      
      return storyRef.id;
    } catch (e) {
      debugPrint('StoryRepository: Error creating story: $e');
      rethrow;
    }
  }
  
  // Helper methods for upload
  Future<String> _uploadVideo(File videoFile) async {
    // Upload to Cloudinary or Firebase Storage
    // ...
  }
  
  Future<String> _generateThumbnail(File videoFile) async {
    // Generate thumbnail using video_thumbnail package
    // ...
  }
}
```

### 3.2 Story Viewing UI

#### Screen: `StoryViewerScreen`

**File**: `lib/screens/story_viewer_screen.dart`

**State Management:**
- Use `StoryViewerCubit` for managing story state
- Handle gesture detection, auto-advance, progress tracking

**UI Structure:**
```dart
Scaffold(
  backgroundColor: Colors.black,
  body: GestureDetector(
    onTapUp: _handleTap,
    onVerticalDragEnd: _handleVerticalSwipe,
    child: Stack(
      children: [
        // PageView for different users' stories
        PageView.builder(
          controller: _userPageController,
          itemCount: _usersWithStories.length,
          itemBuilder: (context, userIndex) {
            return _buildUserStoryReel(userIndex);
          },
        ),
        
        // Progress bars at top
        _buildProgressBars(),
        
        // User info header
        _buildUserHeader(),
        
        // Reply bar at bottom
        _buildReplyBar(),
      ],
    ),
  ),
)
```

**Key Methods:**

1. **`_buildUserStoryReel(int userIndex)`**
   - Returns a `PageView` for a single user's stories
   - Auto-advances through stories
   - Shows progress bars

2. **`_handleTap(TapUpDetails details)`**
   - Detect tap position (left/right)
   - Navigate to previous/next story
   - Pause video if tap-and-hold

3. **`_handleVerticalSwipe(DragEndDetails details)`**
   - Swipe up: Open reply composer
   - Swipe down: Exit viewer

4. **`_autoAdvanceStory()`**
   - Timer-based auto-advance
   - 5 seconds for images, video duration for videos
   - Update progress bar

5. **`_markStoryAsViewed(String storyId)`**
   - Create viewer document in subcollection
   - Increment viewer count (via Cloud Function)

6. **`_sendReply(String storyId, String content, String replyType)`**
   - Call `StoryRepository.replyToStory()`
   - Also create DM message in chats collection

#### Cubit: `StoryViewerCubit`

**File**: `lib/blocs/story_viewer_cubit.dart`

**States:**
```dart
abstract class StoryViewerState {}

class StoryViewerInitial extends StoryViewerState {}
class StoryViewerLoading extends StoryViewerState {}
class StoryViewerLoaded extends StoryViewerState {
  final List<StoryUser> usersWithStories;
  final int currentUserIndex;
  final int currentStoryIndex;
  final Map<String, List<StoryMedia>> userStoriesMap;
  final Map<String, double> progressMap; // Story ID -> progress (0-1)
}
class StoryViewerError extends StoryViewerState {
  final String error;
}
```

**Events (Methods):**
```dart
class StoryViewerCubit {
  // Load stories for users in tray
  Future<void> loadStoriesForUsers(List<String> userIds, String startingUserId);
  
  // Navigate to next story
  void nextStory();
  
  // Navigate to previous story
  void previousStory();
  
  // Navigate to next user
  void nextUser();
  
  // Navigate to previous user
  void previousUser();
  
  // Pause/Resume story
  void pauseStory();
  void resumeStory();
  
  // Mark story as viewed
  Future<void> markStoryAsViewed(String storyId);
  
  // Send reply
  Future<void> sendReply(String storyId, String content, String replyType);
}
```

#### Repository Methods: `StoryRepository`

**Additional Methods:**

1. **`getStoryTrayStream(String userId)`**
   ```dart
   Stream<List<StoryTrayItem>> getStoryTrayStream(String userId) {
     // Get user's friends list
     // Query active stories from friends
     // Return stream of StoryTrayItem (userId, username, avatar, hasUnread)
   }
   ```

2. **`getUserStories(String userId)`**
   ```dart
   Future<List<StoryMedia>> getUserStories(String userId) async {
     // Query story_media collection
     // Filter by authorId, isActive, expiresAt > now
     // Order by createdAt DESC
   }
   ```

3. **`markStoryAsViewed(String storyId, String viewerId)`**
   ```dart
   Future<void> markStoryAsViewed(String storyId, String viewerId) async {
     // Create document in story_media/{storyId}/viewers/{viewerId}
     // Cloud Function will update viewerCount
   }
   ```

4. **`replyToStory(String storyId, String replierId, String content, String replyType)`**
   ```dart
   Future<void> replyToStory(...) async {
     // Create reply document in story_media/{storyId}/replies/{replyId}
     // Also create DM message in chats collection
     // Cloud Function will send notification
   }
   ```

### 3.3 Integration with Feed

#### Widget Refactor: `StoriesTrayWidget`

**File**: `lib/widgets/feed_widgets/stories_tray.dart`

**Changes:**
1. Replace `_loadStories()` with `StreamBuilder`
2. Use `StoryRepository.getStoryTrayStream()`
3. Remove placeholder data
4. Handle loading and error states

**Updated Implementation:**
```dart
@override
Widget build(BuildContext context) {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return SizedBox.shrink();
  
  return StreamBuilder<List<StoryTrayItem>>(
    stream: StoryRepository().getStoryTrayStream(userId),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildLoadingSkeleton();
      }
      
      if (snapshot.hasError) {
        return _buildErrorState();
      }
      
      final stories = snapshot.data ?? [];
      
      return Container(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: stories.length + 1, // +1 for "Your Story"
          itemBuilder: (context, index) {
            if (index == 0) {
              return _YourStoryButton();
            }
            final story = stories[index - 1];
            return StoryAvatarWidget(
              story: story,
              onTap: () => _openStory(story.userId),
            );
          },
        ),
      );
    },
  );
}

void _openStory(String userId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => StoryViewerScreen(startingUserId: userId),
    ),
  );
}
```

#### Widget Refactor: `StoryAvatarWidget`

**File**: `lib/widgets/feed_widgets/story_avatar.dart`

**Changes:**
1. Update `StoryModel` to include `hasUnreadStory` field
2. Use `story.hasUnreadStory` to show gradient ring
3. Remove hardcoded `hasNewContent` logic

**Updated Implementation:**
```dart
class StoryAvatarWidget extends StatelessWidget {
  final StoryTrayItem story; // Changed from StoryModel
  final VoidCallback onTap;
  
  // ...
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              children: [
                // Gradient ring for unread stories
                if (story.hasUnreadStory)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.purple, Colors.orange, Colors.red],
                      ),
                    ),
                  ),
                // Avatar with border
                Container(
                  // ... existing avatar code
                ),
              ],
            ),
            // Username
            Text(story.username),
          ],
        ),
      ),
    );
  }
}
```

#### Model Update: `StoryModel`

**File**: `lib/models/story_model.dart`

**Updated Structure:**
```dart
class StoryModel {
  final String userId;
  final String username;
  final String userAvatarUrl;
  final bool hasUnreadStory; // Changed from hasNewContent
  
  // Factory constructor from Firestore
  factory StoryModel.fromDoc(DocumentSnapshot doc) {
    // ...
  }
}

// New model for story tray items
class StoryTrayItem {
  final String userId;
  final String username;
  final String userAvatarUrl;
  final bool hasUnreadStory;
  final int storyCount; // Number of active stories
  
  // ...
}
```

#### Navigation Updates

**"Your Story" Button:**
```dart
// In StoriesTrayWidget._YourStoryButton()
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => StoryCreatorScreen(),
    ),
  );
}
```

**Story Avatar Tap:**
```dart
// In StoriesTrayWidget
void _openStory(String userId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => StoryViewerScreen(startingUserId: userId),
    ),
  );
}
```

---

## Implementation Checklist

### Phase 1: Foundation
- [ ] Add required packages to `pubspec.yaml`:
  - [ ] `camera: ^0.10.5`
  - [ ] `video_player: ^2.8.6` (for video preview)
  - [ ] `video_thumbnail: ^0.5.3` (for video thumbnails)
  - [ ] `firebase_storage: ^11.6.0` (if using Firebase Storage instead of Cloudinary)
- [ ] Create `StoryRepository` class
- [ ] Update `StoryModel` with full schema
- [ ] Create `StoryMedia` model for individual story items
- [ ] Create `StoryTrayItem` model

### Phase 2: Database & Backend
- [ ] Deploy Firestore indexes for `story_media` collection
- [ ] Enable TTL policy on `story_media.expiresAt` field
- [ ] Implement Cloud Functions:
  - [ ] `notifyStoryReply` (reply notifications)
  - [ ] `updateStoryViewCount` (viewer count updates)
- [ ] Update Firestore security rules for `story_media` collection
- [ ] Update Firebase Storage rules (if using Firebase Storage)

### Phase 3: Story Creation
- [ ] Create `StoryCreatorScreen`
- [ ] Implement camera capture
- [ ] Implement gallery selection
- [ ] Create `TextToolOverlay` widget
- [ ] Create `DrawingToolOverlay` widget
- [ ] Implement sticker picker
- [ ] Implement story upload logic
- [ ] Add navigation from "Your Story" button

### Phase 4: Story Viewing
- [ ] Create `StoryViewerScreen`
- [ ] Create `StoryViewerCubit`
- [ ] Implement gesture handling (tap, swipe)
- [ ] Implement auto-advance logic
- [ ] Implement progress bars
- [ ] Implement reply functionality
- [ ] Implement viewer tracking

### Phase 5: Integration
- [ ] Refactor `StoriesTrayWidget` to use `StoryRepository`
- [ ] Refactor `StoryAvatarWidget` to use new data model
- [ ] Update navigation flows
- [ ] Test end-to-end flow

### Phase 6: Polish & Testing
- [ ] Add loading states
- [ ] Add error handling
- [ ] Add offline support (queue stories for upload)
- [ ] Performance optimization (image caching, video preloading)
- [ ] User testing and feedback

---

## Technical Decisions

### Media Storage
**Decision**: Use Cloudinary for story media (consistent with posts)
**Rationale**: 
- Already integrated in codebase
- Better CDN performance
- Automatic image/video optimization
- Lower Firebase Storage costs

### Video Duration
**Decision**: Maximum 15 seconds for MVP
**Rationale**: 
- Industry standard (Instagram, Snapchat use 15 seconds)
- Reduces storage costs
- Keeps user engagement high

### Story Expiry
**Decision**: Use Firestore TTL policies
**Rationale**: 
- Cost-effective (no Cloud Functions needed)
- Automatic and reliable
- Slight delay (hours) is acceptable for MVP

### Viewer Tracking
**Decision**: Hybrid approach (viewerCount + subcollection)
**Rationale**: 
- Fast viewer count for UI
- Scalable detailed viewer list
- Balances performance and cost

---

## Cost Considerations

### Firestore Reads
- **Story Tray**: ~10-20 reads per user (friends with stories)
- **Story Viewing**: ~5 reads per story viewed (story doc + viewer subcollection)
- **Estimated**: ~50-100 reads per active user per day

### Storage Costs
- **Image Stories**: ~2-5 MB per story
- **Video Stories**: ~5-10 MB per story (15 seconds, compressed)
- **Estimated**: ~10-20 MB per active user per day

### Cloud Functions
- **Story Reply Notification**: ~$0.40 per million invocations
- **Viewer Count Update**: ~$0.40 per million invocations
- **Estimated**: Minimal cost for MVP scale

---

## Future Enhancements (Post-MVP)

1. **Highlights Feature**
   - Save stories to collections
   - Custom highlight covers
   - Reorder stories in highlights

2. **Advanced Editing**
   - Music background
   - Filters and effects
   - Video trimming
   - GIF stickers

3. **Interactive Features**
   - Polls and quizzes
   - Question stickers
   - Location stickers
   - Mention stickers

4. **Analytics**
   - Story insights (views, replies, engagement)
   - Best time to post stories
   - Story performance metrics

---

## Conclusion

This implementation plan provides a comprehensive roadmap for building the Stories feature. The phased approach ensures a solid MVP foundation while leaving room for future enhancements. The architecture is scalable, cost-effective, and follows industry best practices.

**Next Steps:**
1. Review and approve this plan
2. Set up Firestore indexes and TTL policies
3. Begin Phase 1 implementation (Foundation)
4. Iterate based on user feedback

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Author**: Senior Mobile Architect & Product Designer

