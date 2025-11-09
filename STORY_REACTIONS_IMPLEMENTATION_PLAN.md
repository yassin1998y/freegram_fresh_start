# Story Reactions Implementation Plan

## Overview
Implement a complete story reactions system with 6 emoji options, reaction counts, animations, and reaction history viewing.

## Current State Analysis

### What Exists
- ✅ Emoji buttons (❤️, 😂, 👍) in reply bar
- ✅ `sendReply()` method that sends emoji as replies
- ✅ `ReactionModel` (for posts, not stories)
- ✅ Post reactions system (can be used as reference)

### What's Missing
- ❌ Story reaction data model
- ❌ Story reaction repository methods
- ❌ Reaction picker UI component
- ❌ Reaction count display with breakdown
- ❌ Reaction animations
- ❌ Reaction history view
- ❌ "Who reacted" functionality
- ❌ Story model reaction fields

---

## Implementation Steps

### Phase 1: Data Model & Backend (Foundation)

#### 1.1 Update StoryMedia Model
**File:** `lib/models/story_media_model.dart`

**Changes:**
- Add `reactionCount` field (total reactions)
- Add `reactions` field (Map<String, String> - userId -> emoji)
- Add `reactionBreakdown` field (Map<String, int> - emoji -> count)

```dart
final int reactionCount;
final Map<String, String> reactions; // userId -> emoji
final Map<String, int> reactionBreakdown; // emoji -> count

const StoryMedia({
  // ... existing fields
  this.reactionCount = 0,
  this.reactions = const {},
  this.reactionBreakdown = const {},
});
```

#### 1.2 Create Story Reaction Model
**File:** `lib/models/story_reaction_model.dart` (new file)

```dart
class StoryReactionModel extends Equatable {
  final String userId;
  final String storyId;
  final String emoji; // ❤️, 😂, 😮, 😢, 😡, 👏
  final DateTime timestamp;

  const StoryReactionModel({
    required this.userId,
    required this.storyId,
    required this.emoji,
    required this.timestamp,
  });

  // fromMap, toMap, fromDoc methods
}
```

#### 1.3 Update StoryRepository
**File:** `lib/repositories/story_repository.dart`

**New Methods:**
1. `addStoryReaction(String storyId, String userId, String emoji)`
   - Add/update reaction in Firestore
   - Update reaction count and breakdown
   - Use batch for atomic operations

2. `removeStoryReaction(String storyId, String userId)`
   - Remove reaction from Firestore
   - Update reaction count and breakdown

3. `getStoryReactions(String storyId)`
   - Stream of reactions for a story
   - Returns `Stream<List<StoryReactionModel>>`

4. `getStoryReactionBreakdown(String storyId)`
   - Get reaction breakdown (emoji -> count)
   - Returns `Future<Map<String, int>>`

5. `getStoryReactionsWithUsers(String storyId)`
   - Get reactions with user info
   - Returns `Stream<List<StoryReactionWithUser>>`

**Firestore Structure:**
```
stories/{storyId}/
  - reactionCount: number
  - reactions: {
      userId1: "❤️",
      userId2: "😂",
      ...
    }
  - reactionBreakdown: {
      "❤️": 5,
      "😂": 2,
      "😮": 1,
      ...
    }
  reactions/ (subcollection)
    {userId}/
      - userId: string
      - emoji: string
      - timestamp: timestamp
```

#### 1.4 Update StoryRepository.replyToStory
**Note:** Keep reply functionality separate from reactions. Reactions are quick emoji interactions, replies are text messages.

---

### Phase 2: State Management

#### 2.1 Update StoryViewerCubit
**File:** `lib/blocs/story_viewer_cubit.dart`

**New State Fields:**
```dart
class StoryViewerLoaded extends StoryViewerState {
  // ... existing fields
  final Map<String, Map<String, String>> storyReactionsMap; // storyId -> {userId -> emoji}
  final Map<String, Map<String, int>> storyReactionBreakdownMap; // storyId -> {emoji -> count}
  final Map<String, String> userReactionsMap; // storyId -> emoji (current user's reaction)
}
```

**New Methods:**
1. `addReaction(String storyId, String emoji)`
   - Call repository to add reaction
   - Update local state optimistically
   - Handle errors and rollback

2. `removeReaction(String storyId)`
   - Call repository to remove reaction
   - Update local state optimistically

3. `toggleReaction(String storyId, String emoji)`
   - If user has same reaction, remove it
   - If user has different reaction, update it
   - If no reaction, add it

4. `loadStoryReactions(String storyId)`
   - Load reactions for a story
   - Update state with reaction data

---

### Phase 3: UI Components

#### 3.1 Reaction Picker Widget
**File:** `lib/widgets/story_widgets/viewer/story_reaction_picker.dart` (new file)

**Features:**
- Floating action button that opens reaction picker
- 6 emoji options: ❤️, 😂, 😮, 😢, 😡, 👏
- Animated popup with scale animation
- Tap to select reaction
- Close on outside tap
- Positioned near story content (bottom-center or right side)

**Design:**
- Circular container with glassmorphic effect
- Emoji buttons in a row
- Scale animation on open/close
- Haptic feedback on selection

#### 3.2 Reaction Count Display
**File:** `lib/widgets/story_widgets/viewer/story_reaction_display.dart` (new file)

**Features:**
- Show total reaction count
- Show reaction breakdown (emoji -> count)
- Tap to see "who reacted" list
- AnimatedSwitcher for smooth updates
- Positioned below story header or above reply bar

**Design:**
- Horizontal list of emoji + count
- Example: "❤️ 5 😂 2 😮 1"
- Tap to expand and see users
- Animated transitions

#### 3.3 Reaction History Bottom Sheet
**File:** `lib/widgets/story_widgets/viewer/story_reactions_bottom_sheet.dart` (new file)

**Features:**
- Show all reactions for a story
- Group by emoji type
- Show user avatars and names
- Tap user to view profile
- Pull to refresh
- Close button

**Design:**
- Bottom sheet with rounded corners
- Sections for each emoji type
- User list with avatars
- Smooth animations

#### 3.4 Reaction Animation Widget
**File:** `lib/widgets/story_widgets/viewer/story_reaction_animation.dart` (new file)

**Features:**
- Heart animation on double-tap
- Scale + fade animation
- Particle effects (optional)
- Position at tap location
- Auto-dismiss after animation

**Design:**
- Scale from 0.5 to 1.5
- Fade out
- Rotate slightly
- Duration: 600ms

---

### Phase 4: Integration

#### 4.1 Update Story Viewer Screen
**File:** `lib/screens/story_viewer_screen.dart`

**Changes:**
1. Replace emoji reply buttons with reaction picker
2. Add reaction count display
3. Add reaction animation on double-tap
4. Listen to reaction stream updates
5. Update UI when reactions change

**Layout:**
```
Stack(
  children: [
    Story Media,
    Progress Segments,
    User Header,
    Reaction Count Display, // NEW
    Reaction Picker Button, // NEW
    Reply Bar,
  ],
)
```

#### 4.2 Update Story Controls
**File:** `lib/widgets/story_widgets/viewer/story_controls.dart`

**Changes:**
1. Add double-tap gesture detection
2. Trigger reaction animation
3. Add reaction picker toggle
4. Handle reaction gestures

#### 4.3 Update Reply Bar
**File:** `lib/screens/story_viewer_screen.dart`

**Changes:**
1. Remove emoji reply buttons (move to reaction picker)
2. Keep text reply functionality
3. Add reaction count display above reply bar
4. Show user's current reaction if any

---

### Phase 5: Animations & Polish

#### 5.1 Reaction Picker Animation
- Scale animation on open (0.8 → 1.0)
- Fade animation
- Stagger animation for emoji buttons
- Close animation (reverse)

#### 5.2 Reaction Count Animation
- AnimatedSwitcher for count changes
- Scale animation on update
- Color change on user reaction

#### 5.3 Double-Tap Reaction Animation
- Heart emoji scales and fades
- Particle effects (optional)
- Haptic feedback
- Auto-dismiss

#### 5.4 Reaction History Animation
- Slide up animation for bottom sheet
- Stagger animation for user list
- Smooth transitions

---

## Technical Details

### Firestore Rules
**File:** `firestore.rules`

```javascript
// Story reactions
match /stories/{storyId}/reactions/{userId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null && request.auth.uid == userId;
  allow update: if request.auth != null && request.auth.uid == userId;
  allow delete: if request.auth != null && request.auth.uid == userId;
}

// Story reaction counts
match /stories/{storyId} {
  allow read: if request.auth != null;
  allow update: if request.auth != null; // Only via Cloud Functions
}
```

### Cloud Functions (Optional)
**File:** `functions/index.js`

Consider adding Cloud Functions to:
- Update reaction counts atomically
- Prevent race conditions
- Send notifications for reactions
- Update reaction breakdown

### Performance Considerations
1. **Lazy Loading:** Load reactions only when needed
2. **Caching:** Cache reaction data in state
3. **Optimistic Updates:** Update UI immediately, sync with backend
4. **Batching:** Batch reaction updates to reduce Firestore reads
5. **Pagination:** Paginate reaction history for stories with many reactions

---

## Implementation Checklist

### Backend
- [ ] Update StoryMedia model with reaction fields
- [ ] Create StoryReactionModel
- [ ] Add addStoryReaction method to repository
- [ ] Add removeStoryReaction method to repository
- [ ] Add getStoryReactions method to repository
- [ ] Add getStoryReactionBreakdown method to repository
- [ ] Add getStoryReactionsWithUsers method to repository
- [ ] Update Firestore rules
- [ ] Test repository methods

### State Management
- [ ] Update StoryViewerCubit state with reaction fields
- [ ] Add addReaction method to cubit
- [ ] Add removeReaction method to cubit
- [ ] Add toggleReaction method to cubit
- [ ] Add loadStoryReactions method to cubit
- [ ] Handle reaction stream updates
- [ ] Test state management

### UI Components
- [ ] Create StoryReactionPicker widget
- [ ] Create StoryReactionDisplay widget
- [ ] Create StoryReactionsBottomSheet widget
- [ ] Create StoryReactionAnimation widget
- [ ] Add animations to components
- [ ] Test UI components

### Integration
- [ ] Update StoryViewerScreen with reaction picker
- [ ] Update StoryViewerScreen with reaction count display
- [ ] Add double-tap gesture for reaction
- [ ] Update reply bar (remove emoji buttons)
- [ ] Add reaction history button
- [ ] Test integration

### Polish
- [ ] Add reaction picker animations
- [ ] Add reaction count animations
- [ ] Add double-tap reaction animation
- [ ] Add haptic feedback
- [ ] Add error handling
- [ ] Add loading states
- [ ] Test animations

### Testing
- [ ] Test reaction addition
- [ ] Test reaction removal
- [ ] Test reaction toggle
- [ ] Test reaction count updates
- [ ] Test reaction history
- [ ] Test animations
- [ ] Test error handling
- [ ] Test performance

---

## User Experience Flow

### Adding a Reaction
1. User double-taps story → Heart animation plays
2. OR user taps reaction picker button → Picker opens
3. User selects emoji → Reaction added, animation plays
4. Reaction count updates → Smooth animation
5. User's reaction shown → Highlighted in picker

### Viewing Reactions
1. User taps reaction count → Bottom sheet opens
2. User sees all reactions grouped by emoji
3. User sees who reacted → User avatars and names
4. User can tap user → Navigate to profile (optional)

### Removing a Reaction
1. User taps their current reaction → Reaction removed
2. OR user selects same reaction again → Toggle off
3. Reaction count updates → Smooth animation
4. User's reaction cleared → No highlight in picker

---

## Design Specifications

### Reaction Picker
- **Size:** 200x60px
- **Position:** Bottom-center, 80px from bottom
- **Background:** Glassmorphic (black with opacity 0.8)
- **Border:** 1px white with opacity 0.2
- **Border Radius:** 30px
- **Emoji Size:** 32px
- **Spacing:** 8px between emojis
- **Animation:** Scale 0.8 → 1.0, 300ms

### Reaction Count Display
- **Position:** Above reply bar, centered
- **Height:** 40px
- **Background:** Transparent
- **Text Color:** White
- **Font Size:** 14px
- **Spacing:** 4px between emoji + count
- **Animation:** Scale 1.0 → 1.1 → 1.0, 200ms

### Reaction Animation
- **Size:** 80px
- **Duration:** 600ms
- **Scale:** 0.5 → 1.5 → 0.0
- **Opacity:** 1.0 → 0.0
- **Rotation:** 0° → 15° → -15° → 0°
- **Position:** At tap location

---

## Future Enhancements

1. **Reaction Notifications:** Notify story creator when someone reacts
2. **Reaction Analytics:** Show reaction trends over time
3. **Custom Reactions:** Allow users to add custom emoji reactions
4. **Reaction Stickers:** Animated reaction stickers
5. **Reaction Stories:** Create stories from reactions
6. **Reaction Feed:** Feed of stories with reactions from friends

---

## Notes

- **Separate from Replies:** Reactions are quick interactions, replies are messages
- **Performance:** Use optimistic updates for better UX
- **Accessibility:** Add semantic labels for screen readers
- **Localization:** Support different emoji sets if needed
- **Backwards Compatibility:** Handle stories without reaction data gracefully

---

## Estimated Time

- **Phase 1 (Backend):** 4-6 hours
- **Phase 2 (State Management):** 2-3 hours
- **Phase 3 (UI Components):** 6-8 hours
- **Phase 4 (Integration):** 3-4 hours
- **Phase 5 (Polish):** 4-6 hours
- **Testing:** 2-3 hours

**Total:** 21-30 hours

---

**Last Updated:** 2024-12-19

