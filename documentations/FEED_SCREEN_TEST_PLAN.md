# FeedScreen Refactor - Comprehensive Test Plan

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
  - Switch between "Following" and "For You" tabs multiple times
- **Expected Result:**
  - Tabs switch smoothly with animation
  - Each tab maintains its scroll position independently
  - No crashes or memory leaks

### Test Case 1.2: Tab State Persistence
- **Action:**
  - Scroll down the "Following" tab to position X
  - Switch to "For You" tab and scroll to position Y
  - Switch back to "Following" tab
- **Expected Result:**
  - "Following" tab returns to position X
  - "For You" tab returns to position Y when switched back
  - State persists even after app backgrounding

### Test Case 1.3: Tab Controller Initialization
- **Action:**
  - Open FeedScreen for the first time after login
- **Expected Result:**
  - "Following" tab is selected by default
  - Both tabs initialize their BLoCs correctly
  - No duplicate BLoC instances

---

## 2. "Following" Feed Tests

### Test Case 2.1: Feed Content Display
- **Action:**
  - View the "Following" feed
- **Expected Result:**
  - Posts from friends and followed pages are displayed
  - Posts are in chronological order (newest first)
  - Page posts show page name and avatar correctly
  - User posts show user name and avatar correctly

### Test Case 2.2: Real-time Post Updates
- **Action:**
  - Have a friend create a new post while viewing "Following" feed
  - OR pull-to-refresh the feed
- **Expected Result:**
  - New post appears at the top of the feed
  - Pull-to-refresh successfully loads new content
  - Loading indicator appears during refresh
  - Old content remains visible below

### Test Case 2.3: Post as Page
- **Action:**
  - Create a post as a Page (not as a user)
  - View the post in "Following" feed
- **Expected Result:**
  - PostCard displays:
    - Page name (not user name)
    - Page avatar/icon (not user avatar)
    - Verified badge (if page is verified)
    - Display type badge shows "Page" (if applicable)

### Test Case 2.4: Infinite Scroll - Following Feed
- **Action:**
  - Scroll to the bottom of the "Following" feed
  - Continue scrolling
- **Expected Result:**
  - Loading indicator appears at bottom
  - Next page of posts loads automatically
  - Posts append to the list (no duplicates)
  - Scroll position is maintained after loading
  - Loading indicator disappears after content loads

### Test Case 2.5: Empty State - Following Feed
- **Action:**
  - View "Following" feed with no friends or followed pages
- **Expected Result:**
  - Shows empty state message: "No posts from friends or followed pages yet"
  - Displays "Discover people and pages to follow!" button
  - No crashes or errors

### Test Case 2.6: Page Post Mixing
- **Action:**
  - Follow multiple pages
  - View "Following" feed
- **Expected Result:**
  - Page posts are mixed with friend posts
  - Chronological order is maintained
  - Page posts are clearly identifiable

---

## 3. "For You" Feed Tests (Content Mixing Algorithm)

### Test Case 3.1: Feed Content Display
- **Action:**
  - View the "For You" feed
- **Expected Result:**
  - Mix of trending, nearby, and boosted posts displayed
  - Posts show correct badges:
    - "🔥 Trending" for trending posts
    - "📍 Near You" for nearby posts
    - "Promoted" for boosted posts

### Test Case 3.2: Ad Placement Algorithm
- **Action:**
  - Scroll through the "For You" feed
- **Expected Result:**
  - First `AdCard` appears after ~8 posts
  - Subsequent ads appear every ~8 posts
  - Ad shows "Sponsored" label at top
  - Ad has blue border (distinguished from posts)
  - "Why this ad?" button is visible and functional

### Test Case 3.3: Suggestion Carousel Placement
- **Action:**
  - Scroll through the "For You" feed
- **Expected Result:**
  - First `SuggestionCarouselWidget` appears after ~12 posts
  - Carousel shows "People You May Know" or "Pages You Might Like"
  - Dismiss button (X) is visible and functional
  - Carousel items are scrollable horizontally

### Test Case 3.4: Content Mixing Verification
- **Action:**
  - Scroll through entire "For You" feed
- **Expected Result:**
  - Ads and suggestion carousels are evenly distributed
  - No two ads appear consecutively (unless intentional)
  - Mix feels natural and not forced
  - Content types are clearly distinguishable

### Test Case 3.5: Infinite Scroll - For You Feed
- **Action:**
  - Scroll to the bottom of "For You" feed
  - Continue scrolling
- **Expected Result:**
  - Loading indicator appears at bottom
  - Next batch of mixed content loads
  - Ads, posts, and suggestions continue to be mixed
  - Pagination works correctly

### Test Case 3.6: Trending Posts Display
- **Action:**
  - View "For You" feed
- **Expected Result:**
  - Trending posts display "🔥 Trending" badge
  - Badge has red/orange color scheme
  - Badge is positioned correctly next to author name

### Test Case 3.7: Nearby Posts Display
- **Action:**
  - View "For You" feed with location permissions enabled
- **Expected Result:**
  - Nearby posts display "📍 Near You" badge
  - Badge has green color scheme
  - Distance information may be shown (if implemented)

### Test Case 3.8: Boosted Posts Display
- **Action:**
  - View "For You" feed with boosted posts
- **Expected Result:**
  - Boosted posts display "Promoted" badge
  - Badge has orange color scheme
  - Post appears in feed based on targeting criteria

---

## 4. Placeholders & Future Features

### Test Case 4.1: Stories Tray Functionality
- **Action:**
  - Tap the "Your Story" button in StoriesTrayWidget
- **Expected Result:**
  - Placeholder action fires (SnackBar or debug print)
  - No crashes
  - UI remains stable

### Test Case 4.2: Story Avatar Interaction
- **Action:**
  - Tap on any story avatar in StoriesTrayWidget
- **Expected Result:**
  - Placeholder action fires
  - Gradient ring (if hasNewContent) is visible
  - Avatar image loads correctly

### Test Case 4.3: Suggestion Card Follow Action
- **Action:**
  - Tap "Follow" button on a SuggestionCardWidget (friend suggestion)
- **Expected Result:**
  - Follow action fires (friend request sent)
  - Button UI updates (becomes "Requested" or similar)
  - Success/error message displays
  - No crashes

### Test Case 4.4: Suggestion Card Page Follow
- **Action:**
  - Tap "Follow" button on a SuggestionCardWidget (page suggestion)
- **Expected Result:**
  - Page follow action fires
  - Button UI updates to "Following"
  - Page appears in "Following" feed
  - No crashes

### Test Case 4.5: Suggestion Carousel Dismiss
- **Action:**
  - Tap the dismiss (X) button on SuggestionCarouselWidget
- **Expected Result:**
  - Carousel is removed from feed
  - Feed reflows correctly
  - No duplicate carousels appear

---

## 5. Error & Loading States

### Test Case 5.1: Network Error - Following Feed
- **Action:**
  - Turn off network/internet
  - Try to load "Following" feed
- **Expected Result:**
  - Error state displays with message
  - "Retry" button is visible and functional
  - "For You" tab remains unaffected
  - No crashes

### Test Case 5.2: Network Error - For You Feed
- **Action:**
  - Turn off network/internet
  - Try to load "For You" feed
- **Expected Result:**
  - Error state displays with message
  - "Retry" button is visible and functional
  - "Following" tab remains unaffected
  - No crashes

### Test Case 5.3: Pull-to-Refresh - Following Feed
- **Action:**
  - Pull down on "Following" feed to refresh
- **Expected Result:**
  - Refresh indicator appears
  - Feed reloads with latest content
  - Scroll position resets to top
  - Loading skeleton appears briefly
  - New posts appear at top

### Test Case 5.4: Pull-to-Refresh - For You Feed
- **Action:**
  - Pull down on "For You" feed to refresh
- **Expected Result:**
  - Refresh indicator appears
  - Feed reloads with new mixed content
  - Scroll position resets to top
  - Loading skeleton appears briefly
  - Content mix refreshes (new ads, new suggestions)

### Test Case 5.5: Loading Skeleton - Following Feed
- **Action:**
  - Clear app data
  - Open FeedScreen for first time
  - View "Following" tab
- **Expected Result:**
  - Loading skeleton (shimmer) displays
  - Skeleton matches post card layout
  - Skeleton disappears when content loads
  - No blank screens

### Test Case 5.6: Loading Skeleton - For You Feed
- **Action:**
  - Clear app data
  - Open FeedScreen for first time
  - View "For You" tab
- **Expected Result:**
  - Loading skeleton (shimmer) displays
  - Skeleton matches mixed content layout
  - Skeleton disappears when content loads
  - No blank screens

### Test Case 5.7: Partial Load Error Handling
- **Action:**
  - Start loading feed
  - Interrupt network during load
- **Expected Result:**
  - Error state displays
  - Previously loaded content (if any) remains visible
  - User can retry without full reload

### Test Case 5.8: Empty Feed Error
- **Action:**
  - View feed with no content available
- **Expected Result:**
  - Empty state message displays
  - Appropriate call-to-action buttons shown
  - No error messages for empty state

---

## 6. Performance Tests

### Test Case 6.1: Scroll Performance
- **Action:**
  - Scroll rapidly through both feeds
- **Expected Result:**
  - Smooth 60fps scrolling
  - No jank or frame drops
  - Images load progressively (not all at once)
  - Memory usage remains stable

### Test Case 6.2: Image Caching
- **Action:**
  - Scroll through feed with images
  - Scroll back up
- **Expected Result:**
  - Images load from cache (no re-downloading)
  - No flickering when scrolling back
  - Cache persists after app restart

### Test Case 6.3: Memory Usage
- **Action:**
  - Scroll through 100+ posts
  - Monitor memory usage
- **Expected Result:**
  - Memory usage remains reasonable (< 200MB)
  - No memory leaks
  - Old posts are disposed correctly

### Test Case 6.4: Preloading Behavior
- **Action:**
  - Scroll slowly to bottom of feed
- **Expected Result:**
  - Next page starts loading at ~80% scroll position
  - Content appears smoothly without waiting
  - No duplicate loading triggers

---

## 7. PostCard Display Tests

### Test Case 7.1: Post Display Types
- **Action:**
  - View posts with different display types
- **Expected Result:**
  - Badges display correctly:
    - Organic: No badge (or subtle indicator)
    - Boosted: "Promoted" badge (orange)
    - Trending: "🔥 Trending" badge (red)
    - Nearby: "📍 Near You" badge (green)
    - Page: Page icon/name visible

### Test Case 7.2: Verified Badge
- **Action:**
  - View a post from a verified page
- **Expected Result:**
  - Blue verified badge (checkmark) appears next to page name
  - Badge is correctly sized and positioned
  - Badge is only shown for verified pages

### Test Case 7.3: Location Display
- **Action:**
  - View a post with location info
- **Expected Result:**
  - Place name displays below timestamp
  - Location icon is visible
  - Location is clickable (if implemented)

### Test Case 7.4: Edited Post Indicator
- **Action:**
  - View a post that was edited
- **Expected Result:**
  - "(Edited)" text appears after timestamp
  - Text is styled correctly (italic, gray)
  - Edit timestamp may be visible (if implemented)

### Test Case 7.5: Media Carousel
- **Action:**
  - View a post with multiple media items
- **Expected Result:**
  - PageView carousel displays correctly
  - Page indicator dots are visible and functional
  - Individual captions overlay on each image
  - Swipe navigation works smoothly

---

## 8. Ad Display Tests

### Test Case 8.1: Ad Card Display
- **Action:**
  - View an AdCard in "For You" feed
- **Expected Result:**
  - Blue border distinguishes ad from posts
  - "Sponsored" label at top with campaign icon
  - "Why this ad?" button is visible
  - Ad content loads and displays correctly

### Test Case 8.2: Ad Disclosure Dialog
- **Action:**
  - Tap "Why this ad?" button
- **Expected Result:**
  - Dialog opens with explanation
  - Dialog is dismissible
  - No crashes

### Test Case 8.3: Ad Loading States
- **Action:**
  - View feed while ads are loading
- **Expected Result:**
  - Loading skeleton shows for ads
  - Failed ads don't break layout
  - Ads appear when ready

---

## 9. Integration Tests

### Test Case 9.1: Feed Navigation
- **Action:**
  - Navigate to FeedScreen from different entry points
- **Expected Result:**
  - Feed loads correctly from all entry points
  - Tab state is preserved
  - No navigation issues

### Test Case 9.2: Deep Linking
- **Action:**
  - Open a post deep link
- **Expected Result:**
  - PostDetailScreen opens
  - Correct post is displayed
  - Navigation back to feed works

### Test Case 9.3: Notification Tap
- **Action:**
  - Receive notification about new post
  - Tap notification
- **Expected Result:**
  - FeedScreen opens (if applicable)
  - Relevant post is highlighted or navigated to
  - Feed refreshes if needed

---

## 10. Edge Cases & Stress Tests

### Test Case 10.1: Rapid Tab Switching
- **Action:**
  - Switch between tabs rapidly (10+ times in 2 seconds)
- **Expected Result:**
  - No crashes
  - No memory leaks
  - Tabs remain functional
  - Content loads correctly

### Test Case 10.2: Concurrent Operations
- **Action:**
  - Pull-to-refresh while infinite scroll is loading
- **Expected Result:**
  - Operations handle correctly
  - No race conditions
  - Correct state is displayed

### Test Case 10.3: Large Feed
- **Action:**
  - Load feed with 500+ posts
- **Expected Result:**
  - Performance remains acceptable
  - Memory usage doesn't spike
  - Scrolling is smooth

### Test Case 10.4: Empty Network Cache
- **Action:**
  - Clear network cache
  - Load feed offline (with cached data)
- **Expected Result:**
  - Cached content displays
  - Error state if no cache
  - Retry when online

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

---

## Known Issues & Workarounds

*(To be filled during testing)*

---

## Test Results Summary

| Category | Passed | Failed | Blocked | Total |
|----------|--------|--------|---------|-------|
| Tab Switching | | | | 3 |
| Following Feed | | | | 6 |
| For You Feed | | | | 8 |
| Placeholders | | | | 5 |
| Error States | | | | 8 |
| Performance | | | | 4 |
| PostCard Display | | | | 5 |
| Ad Display | | | | 3 |
| Integration | | | | 3 |
| Edge Cases | | | | 4 |
| **TOTAL** | | | | **49** |

---

**Test Plan Version:** 1.0  
**Last Updated:** [Current Date]  
**Reviewed By:** [QA Lead]

