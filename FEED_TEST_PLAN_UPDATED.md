# Feed Screen Test Plan - Updated for For You & Nearby Tabs

## Test Environment Setup
- **Platform:** Android & iOS
- **Network Conditions:** Test on both WiFi and Mobile Data
- **Device Types:** Low-end, Mid-range, High-end devices
- **OS Versions:** Minimum SDK and Latest SDK

---

## 1. Tab Switching & State Management

### Test Case 1.1: Tab Switching Functionality
- **Action:** 
  - Open the app and navigate to FeedScreen
  - Switch between "For You" and "Nearby" tabs multiple times
- **Expected Result:**
  - Tabs switch smoothly with animation
  - Each tab maintains its scroll position independently
  - No crashes or memory leaks
  - "For You" tab is selected by default

### Test Case 1.2: Tab State Persistence
- **Action:**
  - Scroll down the "For You" tab to position X
  - Switch to "Nearby" tab and scroll to position Y
  - Switch back to "For You" tab
- **Expected Result:**
  - "For You" tab returns to position X
  - "Nearby" tab returns to position Y when switched back
  - State persists even after app backgrounding

### Test Case 1.3: Tab Controller Initialization
- **Action:**
  - Open FeedScreen for the first time after login
- **Expected Result:**
  - "For You" tab is selected by default (initialIndex: 0)
  - Both tabs initialize their BLoCs correctly (ForYouFeedBloc, NearbyFeedBloc)
  - No duplicate BLoC instances

---

## 2. "For You" Feed Tests

### Test Case 2.1: Feed Content Display
- **Action:**
  - View the "For You" feed
- **Expected Result:**
  - Stories tray visible at the top (index 0)
  - Trending horizontal section visible (index 1)
  - Mixed feed content below: trending posts, nearby posts, boosted posts
  - Ads appear every ~8 posts
  - Suggestion carousels appear after ~12 posts
  - Posts show correct badges (🔥 Trending, 📍 Near You, Promoted)

### Test Case 2.2: Stories Tray Integration
- **Action:**
  - View the "For You" feed
  - Scroll up and down
- **Expected Result:**
  - Stories tray is always at the top (first item in ListView)
  - Stories scroll with the feed (not in separate AppBar)
  - Stories tray is scrollable horizontally
  - Your Story button is visible and functional
  - Story avatars load correctly

### Test Case 2.3: Trending Section Performance
- **Action:**
  - Open "For You" feed
  - Observe the trending horizontal section
- **Expected Result:**
  - Trending section loads quickly (shows 4 placeholder items immediately)
  - Placeholders are replaced with real trending posts when data loads
  - Real posts display with PostCard components
  - Horizontal scrolling works smoothly
  - No long loading delays

### Test Case 2.4: Real-time Post Updates
- **Action:**
  - View the "For You" feed
  - Pull-to-refresh the feed
- **Expected Result:**
  - New posts appear at the top of the feed (after Stories/Trending sections)
  - Pull-to-refresh successfully loads new content
  - Loading indicator appears during refresh
  - Stories and Trending sections refresh too
  - Old content remains visible below

### Test Case 2.5: Infinite Scroll - For You Feed
- **Action:**
  - Scroll to the bottom of the "For You" feed
  - Continue scrolling
- **Expected Result:**
  - Loading indicator appears at bottom
  - Next page of mixed content loads automatically
  - Posts append to the list (no duplicates)
  - Ads and suggestions continue to be mixed in
  - Scroll position is maintained after loading
  - Loading indicator disappears after content loads

### Test Case 2.6: Empty State - For You Feed
- **Action:**
  - View "For You" feed with no content available
- **Expected Result:**
  - Shows empty state message: "No content to discover yet"
  - Stories tray may still be visible
  - Appropriate call-to-action displayed
  - No crashes or errors

---

## 3. "Nearby" Feed Tests

### Test Case 3.1: Feed Content Display
- **Action:**
  - Switch to "Nearby" tab
  - View the feed
- **Expected Result:**
  - Nearby Trending horizontal section visible at top (index 0)
  - Nearby Reels horizontal section visible (index 1)
  - Nearby posts displayed below with 📍 Near You badge
  - Posts are location-based or fallback to public posts
  - Location info displayed if available

### Test Case 3.2: Nearby Trending Section
- **Action:**
  - View the "Nearby" feed
  - Observe the Nearby Trending horizontal section
- **Expected Result:**
  - Horizontal section displays with 🔥 icon and "Nearby Trending" title
  - Trending posts from nearby area are displayed
  - Posts are scrollable horizontally
  - Posts show trending badge
  - Section loads efficiently

### Test Case 3.3: Nearby Reels Section
- **Action:**
  - View the "Nearby" feed
  - Observe the Nearby Reels horizontal section
- **Expected Result:**
  - Horizontal section displays with video icon and "Nearby Reels" title
  - Video posts (reels) from nearby area are displayed
  - Posts are scrollable horizontally
  - Only video/mixed media posts shown
  - Section loads efficiently

### Test Case 3.4: Nearby Posts Feed
- **Action:**
  - Scroll through the "Nearby" feed posts
- **Expected Result:**
  - Posts display 📍 Near You badge (green color scheme)
  - Posts show location information if available
  - Posts are ordered by proximity (or fallback to chronological)
  - PostCard displays correctly with location info

### Test Case 3.5: Infinite Scroll - Nearby Feed
- **Action:**
  - Scroll to the bottom of "Nearby" feed
  - Continue scrolling
- **Expected Result:**
  - Loading indicator appears at bottom
  - Next page of nearby posts loads automatically
  - Posts append to the list (no duplicates)
  - Scroll position is maintained after loading
  - Loading indicator disappears after content loads

### Test Case 3.6: Empty State - Nearby Feed
- **Action:**
  - View "Nearby" feed with no nearby content available
- **Expected Result:**
  - Shows empty state message: "No nearby posts yet"
  - Location icon displayed
  - "Create your first post!" button visible
  - No crashes or errors

---

## 4. Content Mixing & Placeholders (For You Feed)

### Test Case 4.1: Ad Placement Algorithm
- **Action:**
  - Scroll through the "For You" feed
- **Expected Result:**
  - First `AdCard` appears after ~8 posts
  - Subsequent ads appear every ~8 posts
  - Ad shows "Sponsored" label at top
  - Ad has blue border (distinguished from posts)
  - "Why this ad?" button is visible and functional

### Test Case 4.2: Suggestion Carousel Placement
- **Action:**
  - Scroll through the "For You" feed
- **Expected Result:**
  - First `SuggestionCarouselWidget` appears after ~12 posts
  - Carousel shows "People You May Know" or "Pages You Might Like"
  - Dismiss button (X) is visible and functional
  - Carousel items are scrollable horizontally

### Test Case 4.3: Content Mixing Verification
- **Action:**
  - Scroll through entire "For You" feed
- **Expected Result:**
  - Ads and suggestion carousels are evenly distributed
  - No two ads appear consecutively (unless intentional)
  - Mix feels natural and not forced
  - Content types are clearly distinguishable

---

## 5. Error & Loading States

### Test Case 5.1: Network Error - For You Feed
- **Action:**
  - Turn off network/internet
  - Try to load "For You" feed
- **Expected Result:**
  - Error state displays with message
  - "Retry" button is visible and functional
  - "Nearby" tab remains unaffected
  - No crashes

### Test Case 5.2: Network Error - Nearby Feed
- **Action:**
  - Turn off network/internet
  - Try to load "Nearby" feed
- **Expected Result:**
  - Error state displays with message
  - "Retry" button is visible and functional
  - "For You" tab remains unaffected
  - No crashes

### Test Case 5.3: Pull-to-Refresh - For You Feed
- **Action:**
  - Pull down on "For You" feed to refresh
- **Expected Result:**
  - Refresh indicator appears
  - Feed reloads with latest content
  - Scroll position resets to top (shows Stories/Trending)
  - Loading skeleton appears briefly
  - New posts appear at top
  - Stories and Trending sections refresh

### Test Case 5.4: Pull-to-Refresh - Nearby Feed
- **Action:**
  - Pull down on "Nearby" feed to refresh
- **Expected Result:**
  - Refresh indicator appears
  - Feed reloads with new nearby content
  - Scroll position resets to top (shows Nearby Trending/Reels)
  - Loading skeleton appears briefly
  - Nearby Trending and Reels sections refresh

### Test Case 5.5: Loading Skeleton - For You Feed
- **Action:**
  - Clear app data
  - Open FeedScreen for first time
  - View "For You" tab
- **Expected Result:**
  - Loading skeleton (shimmer) displays
  - Skeleton matches post card layout
  - No RenderFlex overflow errors
  - Skeleton disappears when content loads
  - No blank screens

### Test Case 5.6: Loading Skeleton - Nearby Feed
- **Action:**
  - Clear app data
  - Open FeedScreen for first time
  - View "Nearby" tab
- **Expected Result:**
  - Loading skeleton (shimmer) displays
  - Skeleton matches post card layout
  - No RenderFlex overflow errors
  - Skeleton disappears when content loads
  - No blank screens

---

## 6. Performance Tests

### Test Case 6.1: Scroll Performance
- **Action:**
  - Scroll rapidly through both "For You" and "Nearby" feeds
- **Expected Result:**
  - Smooth 60fps scrolling
  - No jank or frame drops
  - Images load progressively (not all at once)
  - Memory usage remains stable
  - Horizontal sections (Trending/Reels) scroll smoothly

### Test Case 6.2: Trending Section Loading Speed
- **Action:**
  - Open "For You" feed multiple times
  - Measure time to display trending section
- **Expected Result:**
  - Trending section placeholder appears immediately (< 100ms)
  - Real data loads within 2-3 seconds
  - No blocking of main feed load
  - Section updates reactively when data arrives

### Test Case 6.3: Memory Usage
- **Action:**
  - Scroll through 100+ posts in both tabs
  - Monitor memory usage
- **Expected Result:**
  - Memory usage remains reasonable (< 200MB)
  - No memory leaks
  - Old posts are disposed correctly
  - Horizontal sections don't cause memory spikes

---

## 7. PostCard Display Tests

### Test Case 7.1: Post Display Types in For You Feed
- **Action:**
  - View posts in "For You" feed with different display types
- **Expected Result:**
  - Badges display correctly:
    - Organic: No badge (or subtle indicator)
    - Boosted: "Promoted" badge (orange)
    - Trending: "🔥 Trending" badge (red/orange)
    - Nearby: "📍 Near You" badge (green)
    - Page: Page icon/name visible

### Test Case 7.2: Post Display Types in Nearby Feed
- **Action:**
  - View posts in "Nearby" feed
- **Expected Result:**
  - Posts display "📍 Near You" badge (green)
  - Location information visible
  - Nearby Trending posts show trending badge
  - Nearby Reels show video indicators

---

## 8. Integration Tests

### Test Case 8.1: Feed Navigation
- **Action:**
  - Navigate to FeedScreen from different entry points
- **Expected Result:**
  - Feed loads correctly from all entry points
  - "For You" tab is always selected by default
  - Tab state is preserved
  - No navigation issues

### Test Case 8.2: Feed Icon Tap Behavior
- **Action:**
  - Navigate to FeedScreen
  - Tap Feed icon in bottom nav while already on FeedScreen
- **Expected Result:**
  - Scrolls to top of "For You" feed
  - Triggers refresh of feed content
  - Stories and Trending sections refresh
  - Smooth animation to top

---

## 9. Edge Cases & Stress Tests

### Test Case 9.1: Rapid Tab Switching
- **Action:**
  - Switch between "For You" and "Nearby" tabs rapidly (10+ times in 2 seconds)
- **Expected Result:**
  - No crashes
  - No memory leaks
  - Tabs remain functional
  - Content loads correctly in both tabs

### Test Case 9.2: Concurrent Operations
- **Action:**
  - Pull-to-refresh while infinite scroll is loading
- **Expected Result:**
  - Operations handle correctly
  - No race conditions
  - Correct state is displayed
  - No duplicate loading indicators

---

## Test Execution Checklist

- [ ] All test cases executed on Android
- [ ] All test cases executed on iOS
- [ ] Performance tests run on low-end device
- [ ] Performance tests run on high-end device
- [ ] Network conditions tested (WiFi, 3G, 4G, 5G)
- [ ] Edge cases verified
- [ ] Memory leaks checked with DevTools
- [ ] Crash reports reviewed
- [ ] Accessibility verified with screen readers
- [ ] Dark mode compatibility checked
- [ ] Trending section loading speed verified
- [ ] Stories integration verified (no duplicate AppBar)

---

## Summary of Changes from Original Test Plan

1. **Tabs Changed:**
   - Removed: "Following" tab
   - Kept: "For You" tab (now default)
   - Added: "Nearby" tab

2. **For You Tab Structure:**
   - Stories tray at top (index 0)
   - Trending horizontal section (index 1)
   - Mixed feed content below

3. **Nearby Tab Structure:**
   - Nearby Trending horizontal section (index 0)
   - Nearby Reels horizontal section (index 1)
   - Nearby posts feed below

4. **New Test Focus Areas:**
   - Trending section performance optimization
   - Stories tray integration (no separate AppBar)
   - Nearby-specific content sections
   - Horizontal scrolling performance

---

**Test Plan Version:** 2.0  
**Last Updated:** [Current Date]  
**Changes:** Updated for For You & Nearby tab structure
