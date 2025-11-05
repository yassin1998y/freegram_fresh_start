# Stories Feature UI/UX Refactoring Plan
## Facebook-Style Professional Refactor

---

## 📋 Executive Summary

This plan outlines a complete refactoring of the Stories feature UI/UX to achieve a professional, clean, and intuitive Facebook/Messenger-style experience. All components will be refactored to use `app_theme.dart` for consistent theming.

**Scope**: Stories module only (no impact on main feed)

---

## 🎯 Phase 1: Entry Point Refactor (`StoriesTrayWidget`)

### Current State Analysis
- Simple horizontal list of circles
- "Your Story" button is a modified avatar with a "+" icon
- Basic styling with hardcoded colors
- No distinct "Create Story" card component

### Refactoring Goals

#### 1.1 Create New `CreateStoryCard` Widget
**File**: `lib/widgets/feed_widgets/create_story_card.dart` (NEW)

**Design Specifications**:
- **Layout**: Rounded rectangle card (using `theme.cardTheme`)
- **Structure**:
  - Top half: User's avatar (circular, using `CircleAvatar`)
  - Bottom half: 
    - "Create Story" text (using `theme.textTheme.labelMedium`)
    - Small "+" icon or `FilledButton` (using `theme.colorScheme.primary`)
- **Dimensions**: 90px width × 120px height (or proportional to tray)
- **Styling**: 
  - Background: `theme.cardTheme.color`
  - Border radius: `theme.cardTheme.shape.borderRadius`
  - Padding: `EdgeInsets.all(8)`
- **Interaction**: Tap opens modal bottom sheet (see Phase 2)

#### 1.2 Refactor `StoryAvatarWidget`
**File**: `lib/widgets/feed_widgets/story_avatar.dart`

**Changes**:
1. **Unread Ring Gradient**:
   - Use `theme.colorScheme.primary` and `theme.colorScheme.secondary`
   - Replace hardcoded `Color(0xFF00BFA5)` with `theme.colorScheme.primary`
   - Replace hardcoded `Color(0xFF5DF2D6)` with `theme.colorScheme.secondary`

2. **Username Text**:
   - Use `theme.textTheme.bodySmall` instead of hardcoded `TextStyle(fontSize: 12)`
   - Apply theme color: `theme.textTheme.bodySmall?.color`

#### 1.3 Update `StoriesTrayWidget`
**File**: `lib/widgets/feed_widgets/stories_tray.dart`

**Changes**:
1. Replace `_YourStoryButton` with `CreateStoryCard` widget
2. Position `CreateStoryCard` as the first item in `ListView.builder`
3. Remove the old `_YourStoryButton` method
4. Update logic to handle "Your Story" viewing separately (if user has story, show viewer; if not, show creator modal)

---

## 🎯 Phase 2: Creation Flow Refactor (`StoryCreatorScreen`)

### Current State Analysis
- Single screen with media picker shown immediately on init
- Toolbar buttons at bottom (Text, Draw, Stickers)
- Share button in AppBar
- No modal entry point selection
- Hardcoded colors and styles

### Refactoring Goals

#### 2.1 Create New `StoryCreatorTypeScreen` Modal
**File**: `lib/widgets/story_widgets/story_creator_type_screen.dart` (NEW)

**Design Specifications**:
- **Entry Point**: Modal bottom sheet (using `showModalBottomSheet`)
- **Trigger**: When `CreateStoryCard` is tapped
- **Layout**: 
  - Safe area with handle bar (using theme colors)
  - 3-4 large option cards in a `Column` or `GridView`
  
**Option Cards**:
1. **📷 Camera**:
   - Large icon: `Icons.camera_alt`
   - Text: "Camera"
   - Action: Opens camera directly
   
2. **🖼️ Gallery**:
   - Large icon: `Icons.photo_library`
   - Text: "Gallery"
   - Action: Opens gallery picker
   
3. **⌨️ Text Story**:
   - Large icon: `Icons.text_fields`
   - Text: "Text Story"
   - Action: Opens new `TextStoryCreatorScreen` (see 2.2)

**Styling**:
- Each card uses `Card` widget (from `theme.cardTheme`)
- Icons: `theme.iconTheme`
- Text: `theme.textTheme.titleMedium`
- Background: `theme.scaffoldBackgroundColor`
- Border radius: `theme.cardTheme.shape.borderRadius`

#### 2.2 Create New `TextStoryCreatorScreen`
**File**: `lib/screens/text_story_creator_screen.dart` (NEW)

**Design Specifications**:
- **Purpose**: Simple screen for creating text-only stories
- **Layout**:
  - Full-screen with colored background (gradient using theme colors)
  - Large text field in center
  - Color picker at bottom
  - Background color selector
- **Styling**:
  - Text field: `theme.inputDecorationTheme`
  - Colors: `theme.colorScheme.primary`, `theme.colorScheme.secondary`
  - Share button: `FilledButton` using `theme.filledButtonTheme` (if available) or `ElevatedButton` with `theme.elevatedButtonTheme`

#### 2.3 Refactor `StoryCreatorScreen` (Editor)
**File**: `lib/screens/story_creator_screen.dart`

**Changes**:

1. **Remove Auto-Picker on Init**:
   - Remove `_showMediaPicker()` call from `initState`
   - Screen should only show when media is already selected

2. **Clean Toolbar at Top Right**:
   - Move "Text", "Draw", "Stickers" buttons from bottom toolbar to top-right
   - Convert to `Row` of `IconButton`s
   - Position: `Positioned(top: MediaQuery.padding.top + 8, right: 8)`
   - Styling:
     - Icons: `theme.colorScheme.onPrimary` (white/light color for visibility on media)
     - Background: Semi-transparent container with `Colors.black.withOpacity(0.3)`
     - Spacing: `EdgeInsets.all(8)`

3. **Share Button Redesign**:
   - Move from AppBar to bottom-right corner
   - Use `FilledButton` (if `theme.filledButtonTheme` exists) or `ElevatedButton`
   - Style: `theme.elevatedButtonTheme.style` or `FilledButton.styleFrom(backgroundColor: theme.colorScheme.primary)`
   - Position: `Positioned(bottom: 24, right: 24)`
   - Icon: `Icons.send` or `Icons.share`
   - Text: "Share" using `theme.textTheme.labelLarge`

4. **AppBar Simplification**:
   - Keep only close button (`IconButton` with `Icons.close`)
   - Background: Transparent
   - Icon color: `theme.colorScheme.onPrimary` (white)

5. **Media Picker Modal Theming**:
   - Update `_showMediaPicker()` to use theme colors
   - Background: `theme.dialogBackgroundColor` or `theme.colorScheme.surface`
   - Text: `theme.textTheme.bodyMedium`
   - Icons: `theme.iconTheme`

---

## 🎯 Phase 3: Viewer Refactor (`StoryViewerScreen`)

### Current State Analysis
- Functional but lacks polish
- Header has basic user info
- Progress bars use hardcoded colors
- Reply bar exists but could be more professional
- No immersive mode

### Refactoring Goals

#### 3.1 Immersive Layout
**File**: `lib/screens/story_viewer_screen.dart`

**Changes**:
1. **Hide System UI**:
   - Add `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)` in `initState`
   - Restore in `dispose`: `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`

2. **Full-Screen Background**:
   - Ensure media fills entire screen (already implemented, verify)

#### 3.2 Redesign Header
**File**: `lib/screens/story_viewer_screen.dart` - `_buildUserHeader()` method

**New Design**:
```
┌─────────────────────────────────────────┐
│ [Avatar] [Username] [Timestamp] [Spacer] [Close] │
└─────────────────────────────────────────┘
```

**Specifications**:
- **Position**: Top overlay with safe area padding
- **Layout**: `Row` with:
  1. `CircleAvatar` (radius: 20)
  2. `Column` (crossAxisAlignment: start):
     - Username: `theme.textTheme.titleSmall.copyWith(color: Colors.white)`
     - Timestamp: `theme.textTheme.bodySmall.copyWith(color: Colors.grey[300])`
  3. `Spacer()`
  4. `IconButton` (Icons.close, color: Colors.white)
- **Background**: Optional gradient overlay `Colors.black.withOpacity(0.3)` at top
- **Padding**: `EdgeInsets.all(16)`

#### 3.3 Themed Progress Bars
**File**: `lib/screens/story_viewer_screen.dart` - `_buildProgressBars()` method

**Changes**:
1. **Active Segment**:
   - Color: `theme.colorScheme.primary` (replace `Colors.white`)
   - Keep animation and pause color (orange) logic

2. **Background Segments**:
   - Color: `theme.colorScheme.onSurface.withOpacity(0.3)` (replace `Colors.white.withOpacity(0.3)`)

#### 3.4 Professional Reply Footer
**File**: `lib/screens/story_viewer_screen.dart` - `_buildReplyBar()` method

**New Design**:
```
┌─────────────────────────────────────────┐
│ [TextField] [❤️] [😂] [Send]           │
└─────────────────────────────────────────┘
```

**Specifications**:
1. **Position**: Very bottom of screen (above safe area)
2. **Layout**: `Row` with:
   - `Expanded` `TextField`:
     - Hint: "Send reply..."
     - Styling: `theme.inputDecorationTheme`
     - Background: `theme.colorScheme.surface.withOpacity(0.8)`
     - Border radius: `BorderRadius.circular(24)`
   - `IconButton` for quick emoji reactions (❤️, 😂)
   - `IconButton` for send (or auto-send on enter)
3. **Background**: Gradient overlay at bottom
4. **Animation**: Keep existing slide animation

**Quick Emoji Reactions**:
- Show 2-3 emoji buttons (❤️, 😂, 👍)
- On tap: Send emoji as reply directly
- Visual feedback: Scale animation on tap

---

## 📐 Theme Integration Checklist

### Colors
- [ ] Replace all hardcoded `Color(0xFF00BFA5)` with `theme.colorScheme.primary`
- [ ] Replace all hardcoded `Color(0xFF5DF2D6)` with `theme.colorScheme.secondary`
- [ ] Use `theme.colorScheme.onPrimary` for icons on dark backgrounds
- [ ] Use `theme.colorScheme.surface` for cards and containers
- [ ] Use `theme.colorScheme.onSurface` for text and icons

### Typography
- [ ] Replace `TextStyle(fontSize: 12)` with `theme.textTheme.bodySmall`
- [ ] Replace `TextStyle(fontSize: 16)` with `theme.textTheme.bodyMedium`
- [ ] Replace `TextStyle(fontSize: 20, fontWeight: bold)` with `theme.textTheme.titleLarge`
- [ ] Use `theme.textTheme.labelMedium` for button labels
- [ ] Use `theme.textTheme.titleSmall` for usernames

### Components
- [ ] Use `Card` widget with `theme.cardTheme` for all cards
- [ ] Use `FilledButton` or `ElevatedButton` with `theme.elevatedButtonTheme`
- [ ] Use `TextField` with `theme.inputDecorationTheme`
- [ ] Use `IconButton` with `theme.iconTheme`

### Spacing & Borders
- [ ] Use `theme.cardTheme.shape.borderRadius` for card borders
- [ ] Use `theme.inputDecorationTheme.border` for text fields
- [ ] Consistent padding: `EdgeInsets.all(8)` or `EdgeInsets.all(16)`

---

## 🗂️ New Files to Create

1. `lib/widgets/feed_widgets/create_story_card.dart` - New "Create Story" card widget
2. `lib/widgets/story_widgets/story_creator_type_screen.dart` - Modal selection screen
3. `lib/screens/text_story_creator_screen.dart` - Text-only story creator

---

## 📝 Files to Modify

1. `lib/widgets/feed_widgets/stories_tray.dart` - Replace `_YourStoryButton` with `CreateStoryCard`
2. `lib/widgets/feed_widgets/story_avatar.dart` - Theme integration
3. `lib/screens/story_creator_screen.dart` - Toolbar redesign, theming, modal entry
4. `lib/screens/story_viewer_screen.dart` - Immersive mode, header redesign, themed progress bars, reply footer

---

## ✅ Testing Checklist

### Entry Point
- [ ] Create Story card appears first in tray
- [ ] Card uses theme colors correctly
- [ ] Tapping card opens modal
- [ ] Story avatars show correct gradient for unread stories
- [ ] Username text uses theme typography

### Creation Flow
- [ ] Modal bottom sheet shows 3-4 options
- [ ] Each option uses theme styling
- [ ] Camera opens correctly
- [ ] Gallery opens correctly
- [ ] Text Story opens new screen
- [ ] Editor toolbar is at top-right
- [ ] Share button is at bottom-right with theme styling
- [ ] All icons use theme colors

### Viewer
- [ ] System UI is hidden (immersive mode)
- [ ] Header shows avatar, username, timestamp, close button
- [ ] Progress bars use theme colors
- [ ] Reply bar has themed TextField
- [ ] Quick emoji reactions work
- [ ] All text uses theme typography

### Theme Consistency
- [ ] Light theme works correctly
- [ ] Dark theme works correctly
- [ ] All colors come from theme
- [ ] All typography comes from theme
- [ ] All components use theme styles

---

## 🚀 Implementation Order

1. **Phase 1**: Entry Point (`CreateStoryCard`, `StoryAvatarWidget`, `StoriesTrayWidget`)
2. **Phase 2**: Creation Flow (`StoryCreatorTypeScreen`, `TextStoryCreatorScreen`, `StoryCreatorScreen` refactor)
3. **Phase 3**: Viewer (`StoryViewerScreen` refactor)

---

## 📌 Notes

- All changes must be isolated to Stories module
- No breaking changes to main feed
- Maintain backward compatibility with existing story data
- Test on both light and dark themes
- Ensure accessibility (touch targets, contrast ratios)

---

**Ready for Execution**: This plan is comprehensive and ready for implementation. Please review and approve before proceeding to Phase 3 (Execution).

