# Stories Feature UI/UX Refactoring Plan V2
## Facebook-Style Professional Refactor with Conditional Owner Logic

---

## 📋 Executive Summary

This plan outlines a comprehensive refactoring of the Stories feature UI/UX to achieve a professional, clean, and intuitive Facebook/Messenger-style experience. The refactor introduces **conditional UI logic** that differentiates between creating stories, viewing your own stories, and viewing others' stories.

**Scope**: Stories module only (no impact on main feed)

**Source of Truth**: `STORIES_IMPLEMENTATION_DOCUMENTATION.md` + `app_theme.dart`

---

## 🎯 Phase 1: Entry Point Refactor (`StoriesTrayWidget`)

### Current State Analysis
- Uses `CreateStoryCard` widget (rectangular card)
- First item is a card, not a round avatar
- Needs to revert to round avatars

### Refactoring Goals

#### 1.1 Revert to Round Avatar for "Create Story"
**File**: `lib/widgets/feed_widgets/stories_tray.dart`

**Changes**:
1. **Remove `CreateStoryCard` import and usage**
2. **First item must be `StoryAvatarWidget`** for the current user
3. **Add overlay badge**: Blue `CircleAvatar` with `Icons.add` icon positioned at bottom-right of the avatar
4. **Logic**:
   - If user has story: Tapping opens `StoryViewerScreen` (view own stories)
   - If user has no story: Tapping opens `StoryCreatorTypeScreen` modal

**Implementation Details**:
```dart
// First item in ListView.builder
if (index == 0) {
  return Stack(
    alignment: Alignment.center,
    children: [
      StoryAvatarWidget(
        storyItem: StoryTrayItem(
          userId: currentUserId,
          username: 'Your Story',
          userAvatarUrl: currentUser.photoURL ?? '',
          hasUnreadStory: false,
          storyCount: hasOwnStory ? ownStories.length : 0,
        ),
        onTap: hasOwnStory 
          ? () => _openStory(context, currentUserId)
          : () => StoryCreatorTypeScreen.show(context),
      ),
      // Blue "+" badge overlay
      Positioned(
        bottom: 0,
        right: 0,
        child: CircleAvatar(
          radius: 12,
          backgroundColor: theme.colorScheme.primary,
          child: Icon(
            Icons.add,
            size: 16,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ),
    ],
  );
}
```

#### 1.2 Refactor `StoryAvatarWidget` Gradient
**File**: `lib/widgets/feed_widgets/story_avatar.dart`

**Changes**:
1. **Ensure gradient uses ONLY 2-3 colors** from theme:
   - `theme.colorScheme.primary` (start color)
   - `theme.colorScheme.secondary` (end color)
   - Optionally: `theme.colorScheme.tertiary` if available (middle color)
2. **Gradient must NOT be a rainbow** - keep it clean and professional
3. **Text styling**: Already using `theme.textTheme.bodySmall` ✓

**Current State**: Already uses primary/secondary ✓ (just verify it's not rainbow)

---

## 🎯 Phase 2: Creation Flow Refactor (`StoryCreatorScreen`)

### Current State Analysis
- `StoryCreatorTypeScreen` exists but needs updates
- Modal shows 3 options but needs "Music Story" placeholder and Gallery photos list
- `StoryCreatorScreen` is already refactored but needs verification

### Refactoring Goals

#### 2.1 Update `StoryCreatorTypeScreen` Modal
**File**: `lib/widgets/story_widgets/story_creator_type_screen.dart`

**New Design**:
```
┌─────────────────────────────────────────┐
│         [Handle Bar]                     │
│         Create Story                     │
├─────────────────────────────────────────┤
│  [📝 Text Story]  [🎵 Music]  [📷 Camera]│
│      Card          Card        Card      │
├─────────────────────────────────────────┤
│  Recent Photos (Horizontal ListView)    │
│  [Photo] [Photo] [Photo] [Photo] ...    │
└─────────────────────────────────────────┘
```

**Specifications**:
1. **Top Section - 3 Option Cards** (using `theme.cardTheme`):
   - **Text Story Card**:
     - Icon: `Icons.text_fields` (using `theme.iconTheme`)
     - Text: "Text Story" (using `theme.textTheme.titleMedium`)
     - Action: Opens `TextStoryCreatorScreen`
   
   - **Music Story Card** (Placeholder):
     - Icon: `Icons.music_note` (using `theme.iconTheme`)
     - Text: "Music Story" (using `theme.textTheme.titleMedium`)
     - Action: Shows placeholder snackbar "Coming soon"
   
   - **Camera Card**:
     - Icon: `Icons.camera_alt` (using `theme.iconTheme`)
     - Text: "Camera" (using `theme.textTheme.titleMedium`)
     - Action: Opens `StoryCreatorScreen` in camera mode (pass parameter or set initial state)

2. **Bottom Section - Recent Gallery Photos**:
   - Horizontal `ListView` showing recent photos from device gallery
   - Use `image_picker` to get recent images (or `photo_manager` package if available)
   - Each photo is tappable and opens `StoryCreatorScreen` with that photo selected
   - Styling: Grid of thumbnail images with rounded corners

**Theming**:
- All cards use `theme.cardTheme`
- All icons use `theme.iconTheme`
- All text uses `theme.textTheme`
- Background: `theme.scaffoldBackgroundColor`

#### 2.2 Update `StoryCreatorScreen`
**File**: `lib/screens/story_creator_screen.dart`

**Changes**:
1. **Verify toolbar theming**: Ensure all `IconButton`s use `theme.colorScheme.onPrimary` (or `onSurface` if on solid background)
2. **Verify Share button**: Must be `FilledButton` using `theme.colorScheme.primary` and `theme.colorScheme.onPrimary`
3. **Camera mode entry**: When opened from "Camera" card, should immediately show camera (not picker)

**Note**: Most changes are already done from previous refactor, just need verification and gallery photos feature.

---

## 🎯 Phase 3: Viewer Refactor (`StoryViewerScreen`) - Conditional UI

### Current State Analysis
- Header already redesigned ✓
- Reply bar exists but shows for all stories
- Options menu exists but not conditional
- No "Viewers" button for own stories

### Refactoring Goals

#### 3.1 Add Owner Detection State
**File**: `lib/screens/story_viewer_screen.dart`

**Changes**:
1. **Add method to determine ownership**:
```dart
bool _isOwner(StoryMedia story, String currentUserId) {
  return story.authorId == currentUserId;
}
```

2. **Use in `_buildStoryView` method**:
```dart
final currentUser = FirebaseAuth.instance.currentUser;
final isOwner = currentUser != null && _isOwner(story, currentUser.uid);
```

#### 3.2 Conditional Footer (Owner vs. Non-Owner)
**File**: `lib/screens/story_viewer_screen.dart` - `_buildReplyBar()` method

**New Logic**:
```dart
Widget _buildFooter(BuildContext context, StoryViewerLoaded state, bool isOwner) {
  if (isOwner) {
    // Show "Viewers" button
    return _buildViewersButton(context, state);
  } else {
    // Show reply bar (existing implementation)
    return _buildReplyBar(context, state);
  }
}
```

**If `isOwner == true` (Viewing Your Own Story)**:
- **Do NOT show reply bar**
- **Show "Viewers" button**:
  - Position: Bottom of screen (above safe area)
  - Layout: `Row` with:
    - `Icon(Icons.remove_red_eye)` 
    - `Text("${story.viewerCount} Viewers")` using `theme.textTheme.bodySmall.copyWith(color: Colors.white)`
  - Tapping opens `ViewersListScreen` modal

**If `isOwner == false` (Viewing Others' Story)**:
- Show existing reply bar with:
  - Themed `TextField` using `theme.inputDecorationTheme`
  - Quick emoji reactions (❤️, 😂, 👍)
  - Send button

#### 3.3 Create New `ViewersListBottomSheet` Widget
**File**: `lib/widgets/story_widgets/viewers_list_bottom_sheet.dart` (NEW)

**Design**:
```
┌─────────────────────────────────────────┐
│         [Handle Bar]                     │
│         Story Viewers                    │
├─────────────────────────────────────────┤
│  [Avatar] Username 1                     │
│  [Avatar] Username 2                     │
│  [Avatar] Username 3                     │
│  ...                                     │
└─────────────────────────────────────────┘
```

**Specifications**:
- Modal bottom sheet (using `showModalBottomSheet`)
- Fetch viewer IDs using `storyRepository.getStoryViewers(storyId)`
- Fetch user info for each viewer ID using `userRepository.getUser(userId)`
- Display as `ListTile` with avatar, username, and timestamp
- Use `theme.cardTheme` and `theme.textTheme` for styling
- Show loading state while fetching
- Static method: `ViewersListBottomSheet.show(context, storyId)`

#### 3.4 Conditional Options Menu
**File**: `lib/screens/story_viewer_screen.dart` - `_showStoryOptions()` method

**Current**: Shows both "Delete Story" and "Report Story" conditionally

**Changes**:
1. **If `isOwner == true`**:
   - Show ONLY "Delete Story" option
   - Remove "Report Story" option (owners can't report their own story)

2. **If `isOwner == false`**:
   - Show ONLY "Report Story" option
   - Remove "Delete Story" option (non-owners can't delete)

**Note**: "View Insights" can stay for owners (already implemented)

#### 3.5 Update Header to Include Options Menu
**File**: `lib/screens/story_viewer_screen.dart` - `_buildUserHeader()` method

**Current**: Only has close button

**Change**: Add three-dots menu button (if not already present):
- Position: Between timestamp and close button
- Icon: `Icons.more_vert`
- Action: Calls `_showStoryOptions()` with conditional logic

---

## 📐 Theme Integration Checklist

### Colors
- [x] All hardcoded colors replaced with `theme.colorScheme.primary`
- [x] All hardcoded colors replaced with `theme.colorScheme.secondary`
- [x] Gradient uses only theme colors (2-3 colors max, no rainbow)
- [x] Icons use `theme.colorScheme.onPrimary` or `theme.colorScheme.onSurface`
- [x] Cards use `theme.colorScheme.surface`

### Typography
- [x] All text uses `theme.textTheme.bodySmall` for usernames
- [x] All text uses `theme.textTheme.titleMedium` for card titles
- [x] All text uses `theme.textTheme.titleSmall` for headers
- [x] All text uses `theme.textTheme.bodyMedium` for body text

### Components
- [x] All cards use `Card` widget with `theme.cardTheme`
- [x] All buttons use `FilledButton` with theme colors
- [x] All text fields use `theme.inputDecorationTheme`
- [x] All icon buttons use `theme.iconTheme`

---

## 🗂️ New Files to Create

1. `lib/widgets/story_widgets/viewers_list_bottom_sheet.dart` - Bottom sheet showing list of story viewers

---

## 📝 Files to Modify

1. `lib/widgets/feed_widgets/stories_tray.dart` - Revert to round avatar, add "+" badge
2. `lib/widgets/feed_widgets/story_avatar.dart` - Verify gradient (already correct, but double-check)
3. `lib/widgets/story_widgets/story_creator_type_screen.dart` - Add Music Story option, Gallery photos list
4. `lib/screens/story_creator_screen.dart` - Verify theming, add camera mode entry
5. `lib/screens/story_viewer_screen.dart` - Add owner detection, conditional footer, conditional menu, ViewersListScreen integration

---

## ✅ Testing Checklist

### Entry Point
- [ ] "Create Story" is a round avatar (not card)
- [ ] Blue "+" badge appears at bottom-right of avatar
- [ ] Tapping with no story opens modal
- [ ] Tapping with story opens viewer
- [ ] Gradient uses only 2-3 theme colors (not rainbow)
- [ ] Username text uses `theme.textTheme.bodySmall`

### Creation Flow
- [ ] Modal shows 3 option cards (Text, Music, Camera)
- [ ] Music Story shows "Coming soon" placeholder
- [ ] Camera opens camera mode directly
- [ ] Gallery photos show in horizontal list
- [ ] Tapping gallery photo opens creator with that photo
- [ ] All cards use theme styling

### Viewer (Owner - Your Own Story)
- [ ] Footer shows "X Viewers" button (not reply bar)
- [ ] Tapping "Viewers" button opens ViewersListScreen
- [ ] ViewersListScreen shows list of users who viewed
- [ ] Options menu shows "Delete Story" only
- [ ] Options menu does NOT show "Report Story"

### Viewer (Non-Owner - Others' Story)
- [ ] Footer shows reply bar with TextField
- [ ] Reply bar has themed TextField
- [ ] Quick emoji reactions work (❤️, 😂, 👍)
- [ ] Options menu shows "Report Story" only
- [ ] Options menu does NOT show "Delete Story"

### Theme Consistency
- [ ] Light theme works correctly
- [ ] Dark theme works correctly
- [ ] All colors come from theme
- [ ] All typography comes from theme

---

## 🚀 Implementation Order

1. **Phase 1**: Entry Point (`StoriesTrayWidget` - revert to round avatar)
2. **Phase 2**: Creation Flow (`StoryCreatorTypeScreen` updates, gallery photos)
3. **Phase 3**: Viewer (`StoryViewerScreen` conditional UI, ViewersListScreen)

---

## 📌 Key Implementation Notes

### Gallery Photos Feature
- **Option A**: Use `image_picker` package's built-in recent photos (if available)
- **Option B**: Use `photo_manager` package (needs to be added to `pubspec.yaml`)
- **Option C**: Show last 10-20 photos from device gallery using `image_picker.pickMultiImage()` or similar
- **Recommendation**: Start with Option C (simpler), can upgrade to Option B later for better UX

### Owner Detection
- Must compare `story.authorId` with `FirebaseAuth.instance.currentUser?.uid`
- Check for null safety before comparison
- Store `isOwner` boolean in local state or compute in build method

### ViewersListScreen Data Fetching
- Use `storyRepository.getStoryViewers(storyId)` to get viewer IDs
- Batch fetch user info using `userRepository.getUser(userId)` for each ID
- Show loading indicator while fetching
- Handle empty state (no viewers)

---

**Ready for Execution**: This plan is comprehensive and ready for implementation. Please review and approve before proceeding to Phase 3 (Execution).

