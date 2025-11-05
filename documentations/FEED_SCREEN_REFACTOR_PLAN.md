# FeedScreen UX Refactor - Comprehensive Implementation Plan
**Freegram Social App | Flutter/Firebase**

**Document Version:** 1.0  
**Date:** 2025  
**Author:** UX Architecture & Product Design Team

---

## Table of Contents
1. [Phase 1: Research & UX Strategy](#phase-1-research--ux-strategy)
2. [Phase 2: Strategic Plan & UI Audit](#phase-2-strategic-plan--ui-audit)
3. [Phase 3: Detailed Implementation Blueprint](#phase-3-detailed-implementation-blueprint)

---

# Phase 1: Research & UX Strategy

## 1.1 Modern Feed Merging Analysis

### Top-Tier App Patterns (2025):

#### **Instagram's Approach:**
- **Architecture:** Dual-tab system with algorithmically mixed content
  - **"Following" Tab:** Pure chronological feed from followed accounts
  - **"Favorites" Tab (iOS):** Prioritized subset of followed accounts
  - **"For You" Tab:** Algorithmically mixed content including:
    - Discover posts (from accounts you don't follow)
    - Suggested accounts
    - Reels (injected as video cards)
    - Ads (labeled clearly, appearing every 3-4 posts)
  
**Key Insight:** Clear separation between "intentional" (Following) and "discovery" (For You) reduces cognitive load. Users know what to expect in each tab.

#### **X/Twitter's Approach:**
- **Architecture:** Single unified feed with smart sorting
  - **"For You" Tab:** Algorithm-driven mix of:
    - Followed accounts
    - Trending topics
    - Suggested accounts/tweets
    - Promoted tweets (clearly labeled)
  - **"Following" Tab:** Pure chronological
  
**Key Insight:** Algorithm-first approach maximizes engagement but requires careful content labeling to maintain trust.

#### **TikTok's Approach:**
- **Architecture:** Single "For You" feed (discovery-first)
  - Full-screen video cards
  - Algorithm-driven with no manual filtering
  - Promoted content appears naturally with subtle "Promoted" labels
  
**Key Insight:** For video-first apps, a single algorithmic feed works best. For mixed-content apps (text, images, video), tabs provide better UX.

#### **LinkedIn's Approach:**
- **Architecture:** Single feed with "smart" injection
  - Mixes posts, job suggestions, connection suggestions, and ads
  - Uses "carousel" widgets for suggestions (horizontal scroll)
  - Clear visual hierarchy between content types
  
**Key Insight:** Carousel widgets for suggestions feel less intrusive than inline cards.

---

### **Research Findings - Feed Merging Best Practices:**

1. **Tab-Based Separation Wins for Mixed Content:**
   - Users prefer predictable content organization
   - Clear mental model: "Following" = my network, "For You" = discovery
   - Reduces "where did this come from?" confusion

2. **Algorithmic Mixing Requires Clear Labeling:**
   - Users need to understand why content appears
   - Visual indicators (badges, labels) build trust
   - Transparency prevents "feeling manipulated"

3. **Injection Points Matter:**
   - Ads: Every 4-6 posts (industry standard)
   - Suggestions: After every 10-15 posts (less intrusive)
   - Trending content: Naturally interspersed (feels organic)

---

## 1.2 Respectful Ad & Promoted Content Integration

### **Design Best Practices:**

#### **Visual Hierarchy:**
1. **Labeling:**
   - **Ads:** Clear "Sponsored" or "Ad" label in contrasting color (usually subtle gray/blue)
   - **Promoted Posts:** "Promoted" label (distinct from ads, indicates organic post with paid boost)
   - **Organic:** No label needed (default state)

2. **Placement Rules:**
   - Ads should never be the first item in a feed
   - Maintain minimum 3-4 organic posts between ads
   - Never place ads consecutively
   - Ads should feel "native" but be unmistakably labeled

3. **Trust Indicators:**
   - "Why am I seeing this?" disclosure (on long-press or info icon)
   - Clear distinction between paid promotion and algorithmic suggestion

#### **Platform Compliance:**
- **FTC Guidelines:** All ads must be clearly labeled
- **Platform-Specific:**
  - **Instagram:** "Sponsored" label in top-right
  - **X/Twitter:** "Promoted" badge with disclosure
  - **LinkedIn:** "Ad" label with contextual explanation

---

## 1.3 Future-Proofing for Stories, Reels, and Carousels

### **Stories Integration:**
**Best Practice (Instagram Model):**
- Horizontal tray at the top of feed (persistent across tabs)
- First item: "Your Story" (create button)
- Remaining items: Circle avatars with gradient ring for "has new story"
- Tapping opens full-screen story viewer

### **Reels/Short-Form Video:**
**Recommendation:** **Dedicated Tab in Bottom Navigation**
- **Rationale:**
  - Reels require full-screen vertical scrolling (different interaction model)
  - Mixing with feed posts creates cognitive switching cost
  - TikTok model proves dedicated space = higher engagement
  - Prevents feed clutter

**Alternative (Not Recommended):** Injecting Reels as cards in feed
- **Cons:** Breaks scrolling rhythm, requires complex video player management, feels forced

### **Suggestion Carousels:**
**Best Practice (LinkedIn Model):**
- Horizontal scrollable widgets inserted at strategic points
- Title above carousel ("People You May Know", "Pages You Might Like")
- Dismissible (X button in corner)
- Appears max once per session, after user has scrolled 10+ items

---

# Phase 2: Strategic Plan & UI Audit

## 2.1 Final Recommendation: Feed Merging Strategy

### **RECOMMENDED APPROACH: "2-Tab Hybrid System"**

**Architecture:**
```
FeedScreen
├── AppBar (with Stories Tray below)
├── TabBar
│   ├── "Following" Tab
│   └── "For You" Tab
└── TabBarView
    ├── FollowingFeedTab (Pure chronological from friends/pages)
    └── ForYouFeedTab (Algorithmic mix: Trending, Nearby, Discovery, Ads)
```

**Justification:**

1. **User Intent Clarity:**
   - **"Following"** = User knows they'll see friends/pages they follow
   - **"For You"** = User expects discovery, suggestions, trending content
   - Clear mental model reduces confusion

2. **Engagement Optimization:**
   - "Following" serves users who want predictable, personal content
   - "For You" serves users who want discovery, maximizing time in app
   - Algorithm can learn from both interactions

3. **Scalability:**
   - Easy to add more tabs (e.g., "Trending", "Nearby") in future
   - Each tab can have independent BLoC/state management
   - Maintains clean separation of concerns

4. **Monetization-Friendly:**
   - "For You" tab can contain ads without annoying users looking for friend content
   - "Following" tab remains ad-free (premium feature opportunity)

5. **Content Type Handling:**
   - Stories: Persistent across both tabs (top tray)
   - Ads: Only in "For You" tab
   - Suggestions: Only in "For You" tab
   - Boosted Posts: Can appear in both (clearly labeled)

---

## 2.2 UI Component Audit

### **ADD:**

#### **Top-Level Components:**
1. **`FeedScreen` with TabBar:**
   - AppBar with logo/actions
   - Stories tray (below AppBar, persistent)
   - TabBar widget ("Following" | "For You")
   - TabBarView with two child tabs

2. **`StoriesTrayWidget`:**
   - Horizontal `ListView.builder`
   - First item: "Your Story" button
   - Remaining items: `StoryAvatarWidget` (circle with gradient ring)

3. **`StoryAvatarWidget`:**
   - CircleAvatar with network image
   - Gradient ring border for "has new story"
   - Tap opens story viewer (placeholder)

4. **`SuggestionCarouselWidget`:**
   - Horizontal `ListView.builder`
   - Title text ("People You May Know")
   - Dismiss button (X icon)
   - `SuggestionCardWidget` items

5. **`SuggestionCardWidget`:**
   - Avatar image
   - Name/username
   - "Follow" button
   - Optional: "X mutual friends"

6. **`FeedItem` Sealed Class/Union Type:**
   - `PostItem(PostModel)`
   - `AdItem(AdModel)`
   - `BoostedPostItem(PostModel, BoostData)`
   - `SuggestionCarouselItem(SuggestionType, List<UserModel/PageModel>)`

#### **PostCard Enhancements:**
7. **Enhanced `PostCard` Widget:**
   - Multiple visual states (organic, page, boosted, ad, trending, nearby)
   - Badge/label system for content type
   - Improved spacing and typography

---

### **REFINE:**

1. **`FeedBloc`:**
   - Split into `FollowingFeedBloc` and `ForYouFeedBloc`
   - Or: Keep `FeedBloc` but add `FeedTab` enum and separate state management
   - Support `FeedItem` union type instead of just `PostModel`

2. **`PostCard` Widget:**
   - Accept `FeedItem` instead of just `PostModel`
   - Add conditional rendering for different post types
   - Enhanced header with badges
   - Improved visual hierarchy

3. **Feed Loading States:**
   - Separate loading/error states per tab
   - Pull-to-refresh per tab
   - Infinite scroll per tab

---

### **REMOVE:**

1. **Simple `ListView` of posts:**
   - Replace with `TabBarView` with proper state management

2. **Monolithic feed logic:**
   - Split into tab-specific logic

---

# Phase 3: Detailed Implementation Blueprint

## 3.1 Main `FeedScreen` Layout (Scaffold Refactor)

### **AppBar Structure:**

```dart
AppBar(
  elevation: 0,
  automaticallyImplyLeading: false, // No back button in main feed
  title: Row(
    children: [
      // Logo/Brand (left)
      Text(
        'Freegram',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      Spacer(),
      // Actions (right)
      IconButton(
        icon: Icon(Icons.chat_bubble_outline),
        onPressed: () => navigateToChatList(),
        tooltip: 'Messages',
      ),
      IconButton(
        icon: Badge(
          child: Icon(Icons.notifications_outlined),
          // Show count if unread
        ),
        onPressed: () => navigateToNotifications(),
        tooltip: 'Notifications',
      ),
    ],
  ),
  bottom: PreferredSize(
    preferredSize: Size.fromHeight(48), // Stories tray height
    child: StoriesTrayWidget(), // Custom widget below AppBar
  ),
)
```

### **Body Structure:**

```dart
Column(
  children: [
    // TabBar
    TabBar(
      controller: _tabController,
      tabs: [
        Tab(text: 'Following'),
        Tab(text: 'For You'),
      ],
      indicatorColor: Theme.of(context).colorScheme.primary,
      labelColor: Theme.of(context).colorScheme.primary,
      unselectedLabelColor: Colors.grey,
    ),
    // TabBarView
    Expanded(
      child: TabBarView(
        controller: _tabController,
        children: [
          FollowingFeedTab(),
          ForYouFeedTab(),
        ],
      ),
    ),
  ],
)
```

---

## 3.2 Future Feature Placeholders

### **3.2.1 Stories Tray**

#### **Location:**
- Below `AppBar`, above `TabBar`
- Persistent across both tabs (same content, doesn't reload)

#### **Widget: `StoriesTrayWidget`**

```dart
class StoriesTrayWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 8),
        itemCount: _stories.length + 1, // +1 for "Your Story"
        itemBuilder: (context, index) {
          if (index == 0) {
            return _YourStoryButton();
          }
          return StoryAvatarWidget(
            story: _stories[index - 1],
            onTap: () => _openStory(_stories[index - 1]),
          );
        },
      ),
    );
  }
}
```

#### **Widget: `StoryAvatarWidget`**

```dart
class StoryAvatarWidget extends StatelessWidget {
  final StoryModel story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Gradient ring if has new story
                gradient: story.hasNewContent
                    ? LinearGradient(
                        colors: [Colors.purple, Colors.orange, Colors.red],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: Border.all(
                  color: story.hasNewContent ? Colors.transparent : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              padding: EdgeInsets.all(3),
              child: CircleAvatar(
                backgroundImage: NetworkImage(story.userAvatarUrl),
              ),
            ),
            SizedBox(height: 4),
            Text(
              story.username,
              style: TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
```

**Model Placeholder:**
```dart
class StoryModel {
  final String userId;
  final String username;
  final String userAvatarUrl;
  final bool hasNewContent;
  // Placeholder - actual implementation in Stories phase
}
```

---

### **3.2.2 Suggestion Carousels**

#### **Injection Logic:**

**In `ForYouFeedTab`:**
- After every **12 posts**, insert a `SuggestionCarouselWidget`
- Only show **1 carousel per session** (track in state)
- Dismissible (removes from current feed session)

#### **Widget: `SuggestionCarouselWidget`**

```dart
class SuggestionCarouselWidget extends StatelessWidget {
  final SuggestionType type; // FRIENDS or PAGES
  final List<dynamic> suggestions; // List<UserModel> or List<PageModel>
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and dismiss button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  type == SuggestionType.FRIENDS
                      ? 'People You May Know'
                      : 'Pages You Might Like',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: Icon(Icons.close, size: 18),
                    onPressed: onDismiss,
                    tooltip: 'Dismiss',
                  ),
              ],
            ),
          ),
          // Horizontal list
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 8),
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                return SuggestionCardWidget(
                  suggestion: suggestions[index],
                  type: type,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

#### **Widget: `SuggestionCardWidget`**

```dart
class SuggestionCardWidget extends StatelessWidget {
  final dynamic suggestion; // UserModel or PageModel
  final SuggestionType type;

  @override
  Widget build(BuildContext context) {
    final isUser = type == SuggestionType.FRIENDS;
    final name = isUser
        ? (suggestion as UserModel).username
        : (suggestion as PageModel).pageName;
    final avatarUrl = isUser
        ? (suggestion as UserModel).photoUrl
        : (suggestion as PageModel).profileImageUrl;

    return Container(
      width: 100,
      margin: EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage(avatarUrl),
          ),
          SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          ElevatedButton(
            onPressed: () => _handleFollow(suggestion),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              minimumSize: Size(80, 32),
            ),
            child: Text('Follow'),
          ),
        ],
      ),
    );
  }
}
```

---

### **3.2.3 Reels Strategy**

**RECOMMENDATION: Dedicated Tab in Bottom Navigation**

**Rationale:**
1. **Different Interaction Model:**
   - Reels require full-screen vertical scrolling
   - Feed posts require horizontal scrolling with interaction
   - Mixing creates cognitive switching cost

2. **TikTok Model Success:**
   - Dedicated space = higher engagement
   - Users go to Reels tab when they want video content
   - Clear mental model

3. **Technical Benefits:**
   - Independent video player management
   - Optimized for autoplay, sound, gestures
   - No conflicts with feed scrolling

**Implementation Plan:**
- Add "Reels" tab to `MainScreen`'s `BottomNavigationBar`
- Create `ReelsScreen` (full-screen vertical `PageView`)
- No placeholder needed in `FeedScreen`

**Alternative (Not Recommended):** Injecting Reels as video cards in feed
- **Rejected because:** Breaks scrolling rhythm, requires complex state management, feels forced

---

## 3.3 `FeedBloc` Refactor

### **Current State Analysis:**
- Single `FeedBloc` handling all feed types
- Mixed state for following/trending/nearby

### **Proposed Architecture:**

#### **Option A: Split into Separate BLoCs (Recommended)**

```dart
// New BLoCs
class FollowingFeedBloc extends Bloc<FollowingFeedEvent, FollowingFeedState> {}
class ForYouFeedBloc extends Bloc<ForYouFeedEvent, ForYouFeedState> {}
```

**Benefits:**
- Clean separation of concerns
- Independent state management per tab
- Easier to test and maintain
- Can optimize each feed type independently

#### **Option B: Unified BLoC with Tab Management (Alternative)**

```dart
// Enhanced existing FeedBloc
enum FeedTab { following, forYou }

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedTab _activeTab = FeedTab.following;
  
  // Methods to switch tabs and manage state
}
```

**Benefits:**
- Single source of truth
- Easier to share state between tabs
- Less boilerplate

**Decision: Choose Option A** - Better for scalability and maintainability.

---

### **3.3.1 FeedItem Union Type (Sealed Class)**

```dart
// lib/models/feed_item_model.dart

sealed class FeedItem extends Equatable {
  const FeedItem();
  
  @override
  List<Object?> get props => [];
}

class PostFeedItem extends FeedItem {
  final PostModel post;
  final PostDisplayType displayType; // ORGANIC, BOOSTED, TRENDING, NEARBY
  
  const PostFeedItem({
    required this.post,
    this.displayType = PostDisplayType.ORGANIC,
  });
  
  @override
  List<Object?> get props => [post, displayType];
}

class AdFeedItem extends FeedItem {
  final AdModel ad;
  
  const AdFeedItem({required this.ad});
  
  @override
  List<Object?> get props => [ad];
}

class SuggestionCarouselFeedItem extends FeedItem {
  final SuggestionType type; // FRIENDS or PAGES
  final List<dynamic> suggestions; // List<UserModel> or List<PageModel>
  
  const SuggestionCarouselFeedItem({
    required this.type,
    required this.suggestions,
  });
  
  @override
  List<Object?> get props => [type, suggestions];
}

enum PostDisplayType {
  organic,
  boosted,
  trending,
  nearby,
  page,
}

enum SuggestionType {
  friends,
  pages,
}
```

---

### **3.3.2 ForYouFeedBloc State Management**

```dart
// States
class ForYouFeedState extends Equatable {
  final List<FeedItem> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final DocumentSnapshot? lastDocument;

  const ForYouFeedState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.lastDocument,
  });

  @override
  List<Object?> get props => [items, isLoading, hasMore, error, lastDocument];
}

// Events
class LoadForYouFeedEvent extends ForYouFeedEvent {
  final String userId;
}

class LoadMoreForYouFeedEvent extends ForYouFeedEvent {}

// Event Handler Logic:
Future<void> _onLoadForYouFeed(LoadForYouFeedEvent event) async {
  emit(state.copyWith(isLoading: true));
  
  try {
    // Fetch in parallel:
    final results = await Future.wait([
      _postRepository.getTrendingPosts(limit: 10),
      _postRepository.getNearbyPosts(userId: event.userId, limit: 5),
      _postRepository.getBoostedPosts(userId: event.userId, limit: 3),
      _adService.getNextAd(), // Single ad per load
      _userRepository.getFriendSuggestions(event.userId, limit: 5),
    ]);
    
    final trendingPosts = results[0] as List<PostModel>;
    final nearbyPosts = results[1] as List<PostModel>;
    final boostedPosts = results[2] as List<PostModel>;
    final ad = results[3] as AdModel?;
    final friendSuggestions = results[4] as List<UserModel>;
    
    // Mix algorithmically:
    final mixedItems = _mixFeedItems(
      trending: trendingPosts,
      nearby: nearbyPosts,
      boosted: boostedPosts,
      ad: ad,
      suggestions: friendSuggestions,
    );
    
    emit(state.copyWith(
      items: mixedItems,
      isLoading: false,
    ));
  } catch (e) {
    emit(state.copyWith(
      error: e.toString(),
      isLoading: false,
    ));
  }
}

List<FeedItem> _mixFeedItems({
  required List<PostModel> trending,
  required List<PostModel> nearby,
  required List<PostModel> boosted,
  AdModel? ad,
  required List<UserModel> suggestions,
}) {
  final items = <FeedItem>[];
  
  // Algorithm: 1 ad per 8 posts, 1 suggestion carousel per 12 posts
  int postCount = 0;
  int adCount = 0;
  int suggestionCount = 0;
  
  // Mix trending, nearby, and boosted posts
  final allPosts = [
    ...trending.map((p) => PostFeedItem(post: p, displayType: PostDisplayType.trending)),
    ...nearby.map((p) => PostFeedItem(post: p, displayType: PostDisplayType.nearby)),
    ...boosted.map((p) => PostFeedItem(post: p, displayType: PostDisplayType.boosted)),
  ];
  
  // Shuffle for variety (or use ranking algorithm)
  allPosts.shuffle();
  
  for (final postItem in allPosts) {
    items.add(postItem);
    postCount++;
    
    // Insert ad every 8 posts
    if (ad != null && postCount % 8 == 0 && adCount == 0) {
      items.add(AdFeedItem(ad: ad));
      adCount++;
    }
    
    // Insert suggestion carousel every 12 posts
    if (postCount % 12 == 0 && suggestionCount == 0 && suggestions.isNotEmpty) {
      items.add(SuggestionCarouselFeedItem(
        type: SuggestionType.friends,
        suggestions: suggestions,
      ));
      suggestionCount++;
    }
  }
  
  return items;
}
```

---

### **3.3.3 FollowingFeedBloc (Simpler)**

```dart
// States
class FollowingFeedState extends Equatable {
  final List<PostFeedItem> posts; // Only posts, no ads or suggestions
  final bool isLoading;
  final bool hasMore;
  final String? error;
  
  // ... similar structure
}

// Events
class LoadFollowingFeedEvent extends FollowingFeedEvent {
  final String userId;
}

// Logic: Simple chronological fetch from friends + followed pages
Future<void> _onLoadFollowingFeed(LoadFollowingFeedEvent event) async {
  // Fetch posts from friends and followed pages
  final posts = await _postRepository.getFollowingFeed(userId: event.userId);
  
  emit(state.copyWith(
    posts: posts.map((p) => PostFeedItem(
      post: p,
      displayType: p.pageId != null 
          ? PostDisplayType.page 
          : PostDisplayType.organic,
    )).toList(),
  ));
}
```

---

## 3.4 `PostCard` Widget Refactor (Visual Hierarchy)

### **New Signature:**

```dart
class PostCard extends StatelessWidget {
  final FeedItem item; // Instead of PostModel directly
  
  const PostCard({required this.item});
  
  @override
  Widget build(BuildContext context) {
    // Handle different FeedItem types
    return switch (item) {
      PostFeedItem() => _buildPostCard(item.post, item.displayType),
      AdFeedItem() => _buildAdCard(item.ad),
      SuggestionCarouselFeedItem() => SuggestionCarouselWidget(
        type: item.type,
        suggestions: item.suggestions,
      ),
    };
  }
  
  Widget _buildPostCard(PostModel post, PostDisplayType displayType) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER SECTION
          _buildHeader(post, displayType),
          
          // CONTENT SECTION
          if (post.content.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(post.content),
            ),
          
          // MEDIA SECTION
          if (post.mediaItems.isNotEmpty)
            _buildMediaSection(post),
          
          // ACTIONS SECTION (Like, Comment, Share)
          _buildActionsSection(post),
          
          // ENGAGEMENT SECTION (Likes count, comments)
          _buildEngagementSection(post),
        ],
      ),
    );
  }
  
  Widget _buildHeader(PostModel post, PostDisplayType displayType) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () => _navigateToProfile(post),
            child: CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(
                post.pagePhotoUrl ?? post.authorPhotoUrl,
              ),
            ),
          ),
          SizedBox(width: 12),
          
          // Author info + badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _navigateToProfile(post),
                      child: Text(
                        post.pageName ?? post.authorUsername,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    // Verified badge (if page)
                    if (post.pageIsVerified == true) ...[
                      SizedBox(width: 4),
                      Icon(Icons.verified, size: 16, color: Colors.blue),
                    ],
                    // Display type badge
                    if (displayType != PostDisplayType.organic) ...[
                      SizedBox(width: 6),
                      _buildDisplayTypeBadge(displayType),
                    ],
                  ],
                ),
                // Location or timestamp
                Row(
                  children: [
                    if (post.locationInfo != null) ...[
                      Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        post.locationInfo!['placeName'] ?? 'Location',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('•', style: TextStyle(color: Colors.grey[400])),
                      SizedBox(width: 8),
                    ],
                    Text(
                      _formatTimestamp(post.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (post.edited) ...[
                      SizedBox(width: 4),
                      Text(
                        '(Edited)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // More options menu
          PopupMenuButton<String>(
            // ... existing menu items
          ),
        ],
      ),
    );
  }
  
  Widget _buildDisplayTypeBadge(PostDisplayType type) {
    final (label, color, icon) = switch (type) {
      PostDisplayType.boosted => ('Promoted', Colors.orange, Icons.trending_up),
      PostDisplayType.trending => ('🔥 Trending', Colors.red, Icons.local_fire_department),
      PostDisplayType.nearby => ('📍 Near You', Colors.green, Icons.location_on),
      PostDisplayType.page => ('', Colors.transparent, null),
      PostDisplayType.organic => ('', Colors.transparent, null),
    };
    
    if (label.isEmpty) return SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAdCard(AdModel ad) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.blue[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AD LABEL (Top-left, mandatory)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            width: double.infinity,
            child: Row(
              children: [
                Icon(Icons.campaign, size: 14, color: Colors.blue[700]),
                SizedBox(width: 4),
                Text(
                  'Sponsored',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                Spacer(),
                TextButton(
                  onPressed: () => _showAdDisclosure(ad),
                  child: Text(
                    'Why this ad?',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          
          // AD CONTENT (use existing AdCard widget or create new)
          AdCard(ad: ad),
        ],
      ),
    );
  }
}
```

---

## 3.5 Implementation Checklist

### **Phase 1: Foundation (Week 1)**
- [ ] Create `FeedItem` sealed class and related models
- [ ] Split `FeedBloc` into `FollowingFeedBloc` and `ForYouFeedBloc`
- [ ] Implement feed mixing algorithm in `ForYouFeedBloc`
- [ ] Refactor `PostCard` to accept `FeedItem`

### **Phase 2: UI Structure (Week 1-2)**
- [ ] Refactor `FeedScreen` with `TabBar` and `TabBarView`
- [ ] Create `FollowingFeedTab` widget
- [ ] Create `ForYouFeedTab` widget
- [ ] Implement pull-to-refresh per tab
- [ ] Implement infinite scroll per tab

### **Phase 3: Visual Enhancements (Week 2)**
- [ ] Add badges/labels to `PostCard` for different post types
- [ ] Enhance header with page icons and verification badges
- [ ] Improve spacing and typography
- [ ] Add subtle animations for feed updates

### **Phase 4: Placeholders (Week 2-3)**
- [ ] Create `StoriesTrayWidget` placeholder
- [ ] Create `StoryAvatarWidget`
- [ ] Create `SuggestionCarouselWidget`
- [ ] Create `SuggestionCardWidget`
- [ ] Integrate carousels into `ForYouFeedTab`

### **Phase 5: Testing & Polish (Week 3)**
- [ ] Test feed switching performance
- [ ] Test ad placement logic
- [ ] Test suggestion carousel dismissal
- [ ] Optimize scroll performance
- [ ] Add loading skeletons
- [ ] Add error states

---

## 3.6 Additional Considerations

### **Performance Optimization:**
1. **Lazy Loading:**
   - Load stories tray only once (cache)
   - Load suggestions on-demand
   - Paginate ads (preload next ad)

2. **Caching:**
   - Cache "Following" feed (refresh on app resume)
   - Cache "For You" feed with shorter TTL (refresh more frequently)

3. **Preloading:**
   - Preload next page when user is 3 items from bottom
   - Preload ad when current ad is visible

### **Accessibility:**
- Add semantic labels for badges ("Promoted post", "Sponsored content")
- Ensure contrast ratios meet WCAG AA
- Support screen readers for feed navigation

### **Analytics Integration:**
- Track tab switches (Following vs For You)
- Track ad impressions and clicks
- Track suggestion carousel interactions
- Track story views

---

## Summary

This refactor plan transforms `FeedScreen` from a simple list into a modern, engaging, and scalable social feed experience. The 2-tab architecture provides clear user intent separation while maintaining flexibility for future features. The `FeedItem` union type enables clean handling of mixed content, and the visual enhancements ensure users can easily distinguish between organic, promoted, and sponsored content.

**Next Steps:** Begin with Phase 1 (Foundation) to establish the data models and BLoC architecture before touching UI components.

