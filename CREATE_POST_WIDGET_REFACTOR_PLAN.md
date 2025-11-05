# Create Post Widget Refactor Plan

## Overview
This document outlines the comprehensive refactoring plan to:
1. Update trending badges across the app
2. Enhance the horizontal trending posts trail
3. Transform `CreatePostWidget` into a full-featured inline post creation system
4. Merge all `CreatePostScreen` functionality into the widget
5. Remove `CreatePostScreen` dependency

---

## Phase 1: Trending Badge Consistency

### 1.1 Update PostCard Badge
**File:** `lib/widgets/feed_widgets/post_card.dart`

**Changes:**
- Replace the current trending badge in `_buildDisplayTypeBadge` with the same style used in `TrendingPostCard`
- Use the orange badge with white text and fire icon
- Match the exact styling: `Colors.orange.withOpacity(0.9)` background, `Icons.whatshot` icon, white text

**Current Badge (lines 636-700):**
```dart
PostDisplayType.trending => (
    'Trending',
    DesignTokens.errorColor,
    Icons.local_fire_department,
    'Trending post'
)
```

**New Badge Style:**
- Use the same container style as `TrendingPostCard` (lines 128-156)
- Orange background with opacity
- `Icons.whatshot` icon (12px size)
- White text with bold font weight
- Smaller, more compact design

---

## Phase 2: Horizontal Trending Trail Enhancements

### 2.1 Add Video/Reel Support with Play Button
**File:** `lib/widgets/feed_widgets/trending_post_card.dart`

**Changes:**
- Detect video/reel media types from `post.mediaItems` or `post.mediaUrls`
- Add play button overlay when media is video/reel
- Use `VideoPlayerController` to show thumbnail with play icon
- Position play button centered on the card

**New Method:** `_buildVideoWithPlayButton()`
- Check if media type is 'video' or 'reel'
- Show thumbnail with centered play icon
- Icon: `Icons.play_circle_filled` (size 48, white, with shadow)

### 2.2 Enhanced Text-Only Post Background
**File:** `lib/widgets/feed_widgets/trending_post_card.dart`

**Changes:**
- Replace `_buildPlaceholder` with a styled post preview background
- For text-only posts, create a gradient background using theme colors
- Show post content text with proper styling (overlay on gradient)
- Use a sample/post preview card design instead of just an icon

**New Method:** `_buildTextPostBackground()`
- Gradient background: `theme.colorScheme.primaryContainer` to `theme.colorScheme.secondaryContainer`
- Display post content with proper typography
- Add subtle pattern or texture overlay
- Show author name and content preview

---

## Phase 3: CreatePostWidget Complete Refactor

### 3.1 Widget State Management
**File:** `lib/widgets/feed_widgets/create_post_widget.dart`

**Convert to StatefulWidget:**
- Add state management for expansion states
- Track media selection, location, visibility, page selection
- Manage text input controller

**New State Variables:**
```dart
enum _ExpansionState {
  collapsed,      // Just input field + media icon
  expanded,       // Shows posting button + visibility
  mediaExpanded,  // Shows media preview/editor
}

_ExpansionState _currentState = _ExpansionState.collapsed;
final TextEditingController _contentController = TextEditingController();
List<MediaItem> _mediaItems = [];
List<XFile> _selectedFiles = [];
bool _isLocationEnabled = false;
String _visibility = 'public';
String? _selectedPageId;
List<PageModel> _userPages = [];
bool _isPosting = false;
```

### 3.2 Collapsed State (Default)
**Initial View:**
- Avatar (tappable for page selection)
- Text input field (tappable to expand)
- Media icon button (tappable to expand for media)

**Layout:**
```
[Avatar] [Text Input: "Quoi de neuf, {username}?"] [Media Icon]
```

**Functionality:**
- Tap text input → expands to `expanded` state
- Tap media icon → expands to `mediaExpanded` state
- Tap avatar → shows page selection bottom sheet

### 3.3 Expanded State (Text Input Focused)
**Trigger:** User taps text input field

**New UI Elements:**
- Expanded text field (multiline, min 3 lines)
- Post button (bottom right, enabled when text or media exists)
- Visibility selector (chip/button above post button)
- Location chip (if location enabled)
- Collapse button (X icon top right)

**Layout:**
```
[Collapse X] [Page Avatar/Name]
[Expanded Text Input (multiline)]
[Visibility: Public/Friends/Nearby] [Post Button]
[Location: Current Location] (if enabled)
```

**Functionality:**
- Can post text directly without media
- Visibility selector shows current visibility
- Post button uses `FilledButton` from theme
- Collapse button returns to collapsed state

### 3.4 Media Expanded State
**Trigger:** User taps media icon

**New UI Elements:**
- Media preview (image/video/reel)
- Media options (remove, edit, add more)
- Text input (below media)
- Post button
- Location option
- Visibility selector

**Layout:**
```
[Collapse X] [Page Avatar/Name]
[Media Preview/Editor]
[Text Input (optional)]
[Media Options: Add More, Remove]
[Location: Current Location] [Visibility] [Post Button]
```

**Functionality:**
- Image picker: `ImagePicker.pickMultiImage()`
- Video picker: `ImagePicker.pickVideo()`
- Reel support (future: dedicated reel picker)
- Media preview with remove option
- Can add multiple media items
- Text input for caption/content

### 3.5 Avatar/Page Selection
**Trigger:** User taps avatar

**Implementation:**
- Show bottom sheet with:
  - Current user (default)
  - All user pages (from `PageRepository`)
- User selects page → updates avatar and page name
- Sets `_selectedPageId` for posting

**UI:**
```
Modal Bottom Sheet:
- "Post as You" (current user)
- [Page 1 Avatar] Page 1 Name
- [Page 2 Avatar] Page 2 Name
- ...
```

### 3.6 Location Integration
**Current Location Only:**
- Remove `LocationPickerScreen` navigation
- Add "Use Current Location" button/toggle
- Use `Geolocator.getCurrentPosition()` directly
- Show location chip when enabled
- Store location as `GeoPoint` and reverse geocoded address

**UI:**
- Chip/button: "📍 Use Current Location"
- When enabled: Shows "📍 {address}" or "📍 Current Location"
- Toggle to remove location

### 3.7 Templates Integration
**Trigger:** Templates icon button (next to media icon)

**Implementation:**
- Show dropdown/popup menu with user templates
- Load templates from `PostTemplateRepository`
- Apply template directly to widget:
  - Sets content text
  - Sets media items (if template has media)
  - Expands widget to `expanded` or `mediaExpanded` state

**UI:**
```
[Media Icon] [Templates Icon ▼]
              ↓
          Template Menu:
          - Template 1
          - Template 2
          - ...
          - Manage Templates
```

### 3.8 Posting Functionality
**Merge all CreatePostScreen posting logic:**
- Image/video upload to Cloudinary
- Post creation via `PostRepository.createPost()`
- Location, visibility, pageId handling
- Success/error handling with SnackBar
- Reset widget state after successful post

**Post Button:**
- Uses `FilledButton` from theme
- Shows loading spinner when posting
- Disabled when no content and no media

---

## Phase 4: Theming & Design Tokens

### 4.1 Theme Integration
**All UI elements must use:**
- `Theme.of(context).colorScheme` for colors
- `Theme.of(context).textTheme` for typography
- `Theme.of(context).cardTheme` for cards
- `Theme.of(context).inputDecorationTheme` for inputs
- `DesignTokens` for spacing, radius, icons

### 4.2 Specific Theme Requirements
- **Text Input:** Use `InputDecorationTheme` with proper styling
- **Buttons:** Use `FilledButton.styleFrom` for primary actions
- **Cards:** Use `CardTheme` for media preview cards
- **Chips:** Use theme colors for visibility/location chips
- **Icons:** Use `DesignTokens.iconSM/MD/LG` sizes

---

## Phase 5: Remove CreatePostScreen Dependency

### 5.1 Update All Navigation References
**Files to update:**
- `lib/widgets/feed_widgets/create_post_widget.dart` (remove navigation)
- `lib/screens/feed/for_you_feed_tab.dart` (if any references)
- Any other files that navigate to `CreatePostScreen`

### 5.2 Deprecate CreatePostScreen
**File:** `lib/screens/create_post_screen.dart`
- Add deprecation comment
- Keep file for now (may be used for editing posts)
- Or remove entirely if editing is handled elsewhere

---

## Implementation Order

### Step 1: Trending Badge Updates
1. Update `PostCard` trending badge
2. Test badge consistency

### Step 2: Trending Trail Enhancements
1. Add video/reel support with play button
2. Enhance text-only post backgrounds
3. Test horizontal trail

### Step 3: CreatePostWidget Foundation
1. Convert to StatefulWidget
2. Implement collapsed state
3. Add state management variables

### Step 4: Expand Functionality
1. Implement expanded state (text input)
2. Add post button and visibility selector
3. Add location (current location only)

### Step 5: Media Functionality
1. Implement media expanded state
2. Add image/video picker
3. Add media preview and editing

### Step 6: Advanced Features
1. Add avatar/page selection
2. Add templates integration
3. Add posting functionality

### Step 7: Cleanup
1. Remove CreatePostScreen navigation
2. Update all references
3. Test complete flow

---

## Technical Considerations

### Media Handling
- Use `ImagePicker` for images and videos
- Support multiple media items
- Upload to Cloudinary before posting
- Show upload progress

### State Persistence
- Widget state resets after successful post
- Maintain state during expansion/collapse
- Handle widget disposal properly

### Performance
- Lazy load page list
- Lazy load templates
- Optimize media preview rendering
- Use `CachedNetworkImage` for avatars

### Error Handling
- Network errors during upload
- Permission errors (location, camera, gallery)
- Validation errors (empty post)
- Show user-friendly error messages

---

## Files to Modify

1. `lib/widgets/feed_widgets/post_card.dart` - Trending badge update
2. `lib/widgets/feed_widgets/trending_post_card.dart` - Video/reel support, text backgrounds
3. `lib/widgets/feed_widgets/create_post_widget.dart` - Complete refactor
4. `lib/screens/create_post_screen.dart` - Deprecate or remove
5. Any files referencing `CreatePostScreen` navigation

---

## Testing Checklist

- [ ] Trending badge matches across feed and trail
- [ ] Video posts show play button in trail
- [ ] Text-only posts have styled backgrounds
- [ ] Widget expands/collapses smoothly
- [ ] Text posting works without media
- [ ] Media selection and preview works
- [ ] Location (current) works
- [ ] Visibility selection works
- [ ] Page selection works
- [ ] Templates apply correctly
- [ ] Post creation works end-to-end
- [ ] All theme/design tokens applied
- [ ] No CreatePostScreen dependencies remain

---

## Notes

- Keep the widget lightweight and performant
- Use animations for state transitions
- Ensure accessibility (semantics, labels)
- Follow Material Design 3 guidelines
- Test on different screen sizes
- Handle edge cases (no pages, no templates, etc.)

