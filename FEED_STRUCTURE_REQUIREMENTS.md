# Feed Screen Structure Requirements

## Feed Content Order

The feed should display content in the following order:

1. **Stories Tray** (at top - existing)
2. **Create Post Widget** (existing)
3. **Trending Posts** (horizontal carousel - existing, needs positioning adjustment)
4. **Trending Reels** (horizontal carousel with Create Reel card first - NEW)
5. **Boosted Posts** (3 boosted posts from ads/sponsored content - NEW SECTION)
6. **Friends Suggestions** (horizontal carousel with "Add Friend" buttons - NEW)
7. **Regular Feed Posts** (organic, nearby, page posts - main feed)
8. **Pages Suggestions** (horizontal carousel, can appear multiple times throughout feed - NEW)
9. **Ads** (inserted every 8 posts after regular feed starts - existing)

## Detailed Requirements

### 1. Friends Suggestions Horizontal Trail

- **Action Button**: Use "Add Friend" instead of "Follow"
- **Position**: After Boosted Posts (3 posts), before Regular Feed Posts
- **Header**: "People You May Know" with dismiss functionality
- **Content**: User avatar, username, mutual friends count
- **Functionality**: 
  - Add Friend button (sends friend request)
  - Link to user profiles on tap
  - Track analytics for suggestion interactions
- **Implementation**: Update `SuggestionCarouselWidget` or create new widget that uses friend request system instead of follow

### 2. Pages Suggestions Horizontal Trail

- **Action Button**: Use "Follow" (pages use follow, not add friend)
- **Position**: After Regular Feed Posts (can appear multiple times throughout feed)
- **Header**: "Pages You Might Like" with dismiss functionality
- **Content**: Page avatar, page name, follower count
- **Functionality**:
  - Follow button (follows the page)
  - Link to page profiles on tap
  - Track analytics for suggestion interactions
- **Implementation**: Use existing `SuggestionCarouselWidget` with `SuggestionType.pages`

### 3. Trending Reels Horizontal Trail with Create Reel Card

- **Position**: After Trending Posts, before Boosted Posts
- **Create Reel Card**: First item in carousel, styled like Create Story card
  - User profile image at top half
  - "Create a reel" text at bottom half
  - + button overlay at seam between halves
  - Navigate to `/createReel` route on tap
  - Match card dimensions (110 width) and styling of Create Story card
- **Header**: "Trending Reels" with fire icon
- **Content**: Reel thumbnail with play button overlay, creator name, view count, like count
- **Functionality**: Link to reel detail screen or reels feed on tap
- **Implementation**: Create new `TrendingReelsCarouselWidget` component

### 4. Boosted Posts Section

- **Position**: After Trending Reels, before Friends Suggestions
- **Count**: Maximum 3 boosted/sponsored posts
- **Display**: Vertical list (not horizontal carousel) for better visibility
- **Badge**: Show "Sponsored" or "Boosted" badge on each post
- **Functionality**: 
  - Allow users to dismiss/hide individual boosted posts
  - Track analytics for boosted post impressions and interactions
- **Implementation**: Create new `BoostedPostsSectionWidget` component

## Files to Modify/Create

### Existing Files to Modify:
1. `lib/screens/feed/for_you_feed_tab.dart` - Update feed order and add new sections
2. `lib/blocs/unified_feed_bloc.dart` - Update feed ordering logic to support new structure
3. `lib/widgets/feed_widgets/suggestion_carousel.dart` - Update to support "Add Friend" for friends
4. `lib/widgets/feed_widgets/suggestion_card.dart` - Update button text/action based on type (Add Friend vs Follow)

### New Files to Create:
1. `lib/widgets/feed_widgets/trending_reels_carousel.dart` - Trending reels carousel widget
2. `lib/widgets/feed_widgets/create_reel_card.dart` - Create reel card widget (similar to Create Story card)
3. `lib/widgets/feed_widgets/boosted_posts_section.dart` - Boosted posts section widget

## Implementation Notes

- Friends suggestions should integrate with the friend request system (not follow system)
- Pages suggestions should use the existing follow system
- Trending Reels should fetch from reel repository (high engagement, recent reels, trending score)
- Boosted Posts should fetch from ad service with user targeting
- All new sections should handle empty states gracefully (hide if no content)
- Prefetch thumbnails for better performance where applicable

