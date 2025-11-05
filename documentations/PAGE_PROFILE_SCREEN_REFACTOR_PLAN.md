# Page Profile Screen - Comprehensive Refactoring Plan

**Project:** Sonar Pulse Social App (Flutter, Firebase)  
**Feature Strike Team Analysis**  
**Date:** Generated from comprehensive codebase analysis

---

## 1. Analysis of Current State

### Problem 1 (Logic): Follow System Architecture Mismatch
**Current Implementation:**
- `PageRepository.followPage()` uses a subcollection approach: `pages/{pageId}/followers/{userId}`
- `UserModel` does NOT have a `followedPages` field
- `PostRepository.getFeedForUser()` only queries posts from `friends`, NOT from followed pages
- This creates a disconnect: users can follow pages, but their posts don't appear in the feed

**Impact:** Users can follow pages, but the follow action doesn't integrate with the feed system. This is the **biggest functional gap**.

### Problem 2 (UI/UX): Theme Non-Compliance
**Current Issues:**
- Uses hardcoded colors (`Colors.grey`, `Colors.blue`, `Colors.grey[300]`)
- Does not use `DesignTokens` for spacing, sizing, or radius
- Follow button uses basic `ElevatedButton.styleFrom()` instead of theme-compliant styling
- Avatar positioning and sizing are hardcoded (`radius: 50`, `radius: 48`)
- Tab bar is basic without theme integration
- Missing professional Facebook-style layout polish

### Problem 3 (Future-Proofing): Missing Placeholder Tabs
**Current State:**
- Only has "Posts" and "About" tabs
- No placeholders for future features (Shop, Events, etc.)
- Tab structure is not extensible

---

## 2. Part 1: Backend & Data Model (The "Follow" System)

### 2.1 Update `UserModel` (`lib/models/user_model.dart`)

**Action:** Add `followedPages` field to track which pages a user follows.

**Changes Required:**
```dart
// Add to class fields (around line 34, after friends)
final List<String> followedPages;

// Update constructor (around line 72, after friends)
this.followedPages = const [],

// Update fromMap (around line 166, after friends)
followedPages: _getList(data, 'followedPages'),

// Update toMap (around line 212, after friends)
'followedPages': followedPages,

// Update copyWith (around line 236, add new parameter)
List<String>? followedPages,

// Update props (around line 249, add to list)
followedPages,
```

**Rationale:** This allows efficient querying of followed pages without scanning subcollections. The array approach is more performant for feed queries.

---

### 2.2 Update `PageRepository` (`lib/repositories/page_repository.dart`)

**Action:** Refactor `followPage()` and `unfollowPage()` to use atomic batch operations that update BOTH the user's `followedPages` array AND the page's `followerCount`.

**Current Issue:** The existing methods only update the page's follower count and subcollection. They don't update the user's `followedPages` array.

**New Implementation:**
```dart
/// User follows a page - Atomic batch operation
Future<void> followPage(String pageId, String userId) async {
  try {
    final userRef = _db.collection('users').doc(userId);
    final pageRef = _db.collection('pages').doc(pageId);
    
    final batch = _db.batch();
    
    // Add pageId to user's 'followedPages' array
    batch.update(userRef, {
      'followedPages': FieldValue.arrayUnion([pageId])
    });
    
    // Increment the page's 'followerCount'
    batch.update(pageRef, {
      'followerCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    // Also maintain subcollection for backward compatibility (optional, but recommended)
    final followerRef = _db
        .collection('pages')
        .doc(pageId)
        .collection('followers')
        .doc(userId);
    batch.set(followerRef, {
      'userId': userId,
      'followedAt': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
  } catch (e) {
    debugPrint('PageRepository: Error following page: $e');
    rethrow;
  }
}

/// User unfollows a page - Atomic batch operation
Future<void> unfollowPage(String pageId, String userId) async {
  try {
    final userRef = _db.collection('users').doc(userId);
    final pageRef = _db.collection('pages').doc(pageId);
    
    final batch = _db.batch();
    
    // Remove pageId from user's 'followedPages' array
    batch.update(userRef, {
      'followedPages': FieldValue.arrayRemove([pageId])
    });
    
    // Decrement the page's 'followerCount'
    batch.update(pageRef, {
      'followerCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    // Also remove from subcollection for consistency
    final followerRef = _db
        .collection('pages')
        .doc(pageId)
        .collection('followers')
        .doc(userId);
    batch.delete(followerRef);
    
    await batch.commit();
  } catch (e) {
    debugPrint('PageRepository: Error unfollowing page: $e');
    rethrow;
  }
}
```

**Rationale:** Using `FieldValue.arrayUnion` and `FieldValue.arrayRemove` ensures atomic updates. The batch operation guarantees both updates succeed or fail together, preventing inconsistent state.

---

### 2.3 Update `UserRepository` (`lib/repositories/user_repository.dart`)

**Action:** Add a simple, efficient method to check if a user is following a page.

**New Method:**
```dart
/// Check if user is following a page
/// Uses the user's followedPages array for efficient lookup
Future<bool> isFollowingPage(String userId, String pageId) async {
  try {
    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) return false;
    
    final data = userDoc.data();
    if (data == null) return false;
    
    final followedPages = List<String>.from(data['followedPages'] ?? []);
    return followedPages.contains(pageId);
  } catch (e) {
    debugPrint('UserRepository: Error checking if following page: $e');
    return false;
  }
}
```

**Rationale:** This is more efficient than querying a subcollection. Single document read vs. subcollection query.

---

### 2.4 Update `PostRepository` (`lib/repositories/post_repository.dart`)

**Action:** CRITICAL - Update `getFeedForUser()` and `getUnifiedFeed()` to include posts from followed pages.

**Current Issue:** These methods only query posts where `authorId` is in the user's `friends` list. They completely ignore posts from followed pages.

**Solution:** Firestore doesn't support logical `OR` on different fields (`authorId` vs `pageId`). We must execute **two separate queries** and merge results.

**Updated `getFeedForUserWithPagination()` Method:**
```dart
Future<(List<PostModel>, DocumentSnapshot?)> getFeedForUserWithPagination({
  required String userId,
  DocumentSnapshot? lastDocument,
  int limit = 10,
}) async {
  try {
    // Get user's friends list AND followed pages
    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      debugPrint('PostRepository: User not found: $userId');
      return (<PostModel>[], null);
    }

    final userData = userDoc.data()!;
    final friends = List<String>.from(userData['friends'] ?? []);
    final followedPages = List<String>.from(userData['followedPages'] ?? []);

    // Query 1: Posts from friends OR public posts
    Query query1;
    if (friends.isNotEmpty) {
      query1 = _db.collection('posts')
          .where('deleted', isEqualTo: false)
          .where(Filter.or(
            Filter('authorId', whereIn: friends),
            Filter('visibility', isEqualTo: 'public'),
          ));
    } else {
      query1 = _db.collection('posts')
          .where('deleted', isEqualTo: false)
          .where('visibility', isEqualTo: 'public');
    }
    query1 = query1.orderBy('timestamp', descending: true).limit(limit);

    // Query 2: Posts from followed pages (if any)
    Query? query2;
    if (followedPages.isNotEmpty) {
      // Firestore 'whereIn' limit is 10, so batch if needed
      final List<PostModel> pagePosts = [];
      for (int i = 0; i < followedPages.length; i += 10) {
        final batch = followedPages.sublist(
          i,
          i + 10 > followedPages.length ? followedPages.length : i + 10,
        );
        
        var pageQuery = _db.collection('posts')
            .where('deleted', isEqualTo: false)
            .where('pageId', whereIn: batch)
            .orderBy('timestamp', descending: true)
            .limit(limit);
        
        final pageSnapshot = await pageQuery.get();
        pagePosts.addAll(
          pageSnapshot.docs.map((doc) => PostModel.fromDoc(doc)).toList(),
        );
      }
      
      // Merge results from both queries
      final friendPostsSnapshot = await query1.get();
      final friendPosts = friendPostsSnapshot.docs
          .map((doc) => PostModel.fromDoc(doc))
          .toList();
      
      // Combine and deduplicate
      final allPosts = <PostModel>[];
      final seenIds = <String>{};
      
      for (final post in friendPosts) {
        if (!seenIds.contains(post.id)) {
          allPosts.add(post);
          seenIds.add(post.id);
        }
      }
      
      for (final post in pagePosts) {
        if (!seenIds.contains(post.id)) {
          allPosts.add(post);
          seenIds.add(post.id);
        }
      }
      
      // Sort by timestamp (newest first)
      allPosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      // Apply pagination limit
      final limitedPosts = allPosts.take(limit).toList();
      final lastDoc = limitedPosts.isNotEmpty
          ? friendPostsSnapshot.docs.last
          : null;
      
      return (limitedPosts, lastDoc);
    } else {
      // No followed pages, just return friend posts
      final snapshot = await query1.get();
      final posts = snapshot.docs.map((doc) => PostModel.fromDoc(doc)).toList();
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      return (posts, lastDoc);
    }
  } catch (e) {
    debugPrint('PostRepository: Error getting feed for user: $e');
    rethrow;
  }
}
```

**Also Update `getUnifiedFeed()`:** Similar logic - add followed pages query alongside existing queries.

**Rationale:** This ensures posts from followed pages appear in the user's feed, making the follow system functional end-to-end.

---

## 3. Part 2: UI/UX Refactor (`PageProfileScreen`)

### 3.1 Overall Structure

**File:** `lib/screens/page_profile_screen.dart`

**State Management:** Keep as `StatefulWidget` (or consider BLoC for complex state).

**Key Changes:**
1. Replace ALL hardcoded colors with `theme.colorScheme.*`
2. Replace ALL hardcoded spacing with `DesignTokens.space*`
3. Replace ALL hardcoded sizes with `DesignTokens.*` constants
4. Add future placeholder tabs (Shop, Events)
5. Improve Follow button styling and behavior
6. Professional header layout with better avatar positioning

---

### 3.2 Header Section Refactor

**Current Issues:**
- Hardcoded `expandedHeight: 250.0`
- Hardcoded avatar radius (`50`, `48`)
- Hardcoded colors (`Colors.grey[300]`, `Colors.black.withOpacity(0.5)`)
- Avatar positioning uses hardcoded values (`left: 16`, `bottom: -30`)

**New Implementation:**
```dart
SliverAppBar(
  expandedHeight: 200.0, // Use DesignTokens if needed
  floating: false,
  pinned: true,
  flexibleSpace: FlexibleSpaceBar(
    background: Stack(
      fit: StackFit.expand,
      children: [
        // Cover Image
        _page!.coverImageUrl != null && _page!.coverImageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: _page!.coverImageUrl!,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  color: theme.colorScheme.surfaceVariant,
                ),
              )
            : Container(
                color: theme.colorScheme.surfaceVariant,
              ),
        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                theme.colorScheme.surface.withOpacity(0.7),
              ],
            ),
          ),
        ),
        // Avatar over cover (centered at bottom)
        if (_page != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: -DesignTokens.avatarSizeLarge / 2,
            child: Center(
              child: CircleAvatar(
                radius: DesignTokens.avatarSizeLarge / 2,
                backgroundColor: theme.colorScheme.surface,
                child: CircleAvatar(
                  radius: (DesignTokens.avatarSizeLarge / 2) - 2,
                  backgroundImage: _page!.profileImageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(_page!.profileImageUrl)
                      : null,
                  child: _page!.profileImageUrl.isEmpty
                      ? Icon(
                          Icons.business,
                          size: DesignTokens.iconXL,
                          color: theme.colorScheme.onSurface,
                        )
                      : null,
                ),
              ),
            ),
          ),
      ],
    ),
  ),
  actions: [
    if (isAdmin)
      IconButton(
        icon: Icon(Icons.settings),
        color: theme.colorScheme.onSurface,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PageSettingsScreen(pageId: widget.pageId),
            ),
          );
        },
      ),
  ],
),
```

---

### 3.3 Info Block Refactor

**Current Issues:**
- Hardcoded padding (`EdgeInsets.all(16.0)`)
- Hardcoded colors (`Colors.grey`, `Colors.blue`)
- Missing theme compliance

**New Implementation:**
```dart
Padding(
  padding: EdgeInsets.all(DesignTokens.spaceMD),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(height: DesignTokens.avatarSizeLarge / 2 + DesignTokens.spaceSM),
      // Page Name and Handle
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _page!.pageName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (_page!.verificationStatus == VerificationStatus.verified) ...[
                      SizedBox(width: DesignTokens.spaceSM),
                      Icon(
                        Icons.verified,
                        color: theme.colorScheme.primary,
                        size: DesignTokens.iconMD,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: DesignTokens.spaceXS),
                Text(
                  '@${_page!.pageHandle}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(
                      DesignTokens.opacityMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      SizedBox(height: DesignTokens.spaceMD),
      // Follower Count
      Text(
        '${_page!.followerCount} followers',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(
            DesignTokens.opacityMedium,
          ),
        ),
      ),
    ],
  ),
),
```

---

### 3.4 Action Buttons Refactor

**Current Issues:**
- Follow button uses basic styling
- Missing proper state management
- No loading states that match theme

**New Implementation:**
```dart
// Action Buttons Row
Padding(
  padding: EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
  child: Row(
    children: [
      // Follow/Following Button
      Expanded(
        child: FutureBuilder<bool>(
          future: _userRepository.isFollowingPage(
            FirebaseAuth.instance.currentUser!.uid,
            widget.pageId,
          ),
          builder: (context, snapshot) {
            final isFollowing = snapshot.data ?? _isFollowing;
            
            if (isFollowing) {
              return OutlinedButton.icon(
                onPressed: _isLoadingFollow ? null : _toggleFollow,
                icon: Icon(
                  Icons.check,
                  size: DesignTokens.iconSM,
                ),
                label: Text('Following'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(
                    color: theme.colorScheme.outline,
                    width: 1,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMD,
                    vertical: DesignTokens.spaceSM,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                  ),
                ),
              );
            } else {
              return FilledButton.icon(
                onPressed: _isLoadingFollow ? null : _toggleFollow,
                icon: Icon(
                  Icons.add,
                  size: DesignTokens.iconSM,
                ),
                label: Text('Follow'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMD,
                    vertical: DesignTokens.spaceSM,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                  ),
                ),
              );
            }
          },
        ),
      ),
      SizedBox(width: DesignTokens.spaceSM),
      // Message Button (IconButton)
      IconButton(
        icon: Icon(Icons.message_outlined),
        onPressed: () {
          // TODO: Navigate to page message screen
        },
        style: IconButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
        ),
      ),
    ],
  ),
),
```

---

### 3.5 TabBar Refactor with Future Placeholders

**Current Issues:**
- Only 2 tabs (Posts, About)
- No placeholders for Shop/Events

**New Implementation:**
```dart
// Update TabController initialization
_tabController = TabController(length: 4, vsync: this);

// TabBar
TabBar(
  controller: _tabController,
  indicatorColor: theme.colorScheme.primary,
  labelColor: theme.colorScheme.primary,
  unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(
    DesignTokens.opacityMedium,
  ),
  tabs: [
    Tab(
      icon: Icon(Icons.article_outlined, size: DesignTokens.iconMD),
      text: 'Posts',
    ),
    Tab(
      icon: Icon(Icons.info_outline, size: DesignTokens.iconMD),
      text: 'About',
    ),
    Tab(
      icon: Icon(Icons.storefront_outlined, size: DesignTokens.iconMD),
      text: 'Shop',
    ),
    Tab(
      icon: Icon(Icons.event_outlined, size: DesignTokens.iconMD),
      text: 'Events',
    ),
  ],
),

// TabBarView
TabBarView(
  controller: _tabController,
  children: [
    _buildPostsTab(),
    _buildAboutTab(),
    _buildShopTab(), // NEW - Placeholder
    _buildEventsTab(), // NEW - Placeholder
  ],
),
```

**New Placeholder Tab Methods:**
```dart
Widget _buildShopTab() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.storefront_outlined,
          size: DesignTokens.iconXXL,
          color: theme.colorScheme.onSurface.withOpacity(
            DesignTokens.opacityMedium,
          ),
        ),
        SizedBox(height: DesignTokens.spaceMD),
        Text(
          'Shop Coming Soon',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(
              DesignTokens.opacityMedium,
            ),
          ),
        ),
        SizedBox(height: DesignTokens.spaceSM),
        Text(
          'This feature will be available soon!',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(
              DesignTokens.opacityMedium,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildEventsTab() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.event_outlined,
          size: DesignTokens.iconXXL,
          color: theme.colorScheme.onSurface.withOpacity(
            DesignTokens.opacityMedium,
          ),
        ),
        SizedBox(height: DesignTokens.spaceMD),
        Text(
          'Events Coming Soon',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(
              DesignTokens.opacityMedium,
            ),
          ),
        ),
        SizedBox(height: DesignTokens.spaceSM),
        Text(
          'This feature will be available soon!',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(
              DesignTokens.opacityMedium,
            ),
          ),
        ),
      ],
    ),
  );
}
```

---

### 3.6 Posts Tab Refactor

**Current Issues:**
- Uses hardcoded colors for empty state
- Missing theme compliance

**New Implementation:**
```dart
Widget _buildPostsTab() {
  return FutureBuilder(
    future: _pageRepository.getPagePosts(pageId: widget.pageId),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(
          child: CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
        );
      }

      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: DesignTokens.iconXXL,
                color: DesignTokens.errorColor,
              ),
              SizedBox(height: DesignTokens.spaceMD),
              Text(
                'Error: ${snapshot.error}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: DesignTokens.errorColor,
                ),
              ),
            ],
          ),
        );
      }

      final posts = snapshot.data ?? [];

      if (posts.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.post_add,
                size: DesignTokens.iconXXL,
                color: theme.colorScheme.onSurface.withOpacity(
                  DesignTokens.opacityMedium,
                ),
              ),
              SizedBox(height: DesignTokens.spaceMD),
              Text(
                'No posts yet',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(
                    DesignTokens.opacityMedium,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.all(DesignTokens.spaceSM),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(bottom: DesignTokens.spaceSM),
            child: PostCard(
              item: PostFeedItem(
                post: posts[index],
                displayType: PostDisplayType.page,
              ),
            ),
          );
        },
      );
    },
  );
}
```

---

### 3.7 About Tab Refactor

**Current Issues:**
- Hardcoded padding and spacing
- Hardcoded colors

**New Implementation:**
```dart
Widget _buildAboutTab() {
  final theme = Theme.of(context);
  
  return SingleChildScrollView(
    padding: EdgeInsets.all(DesignTokens.spaceMD),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_page!.description.isNotEmpty) ...[
          Text(
            'About',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: DesignTokens.spaceSM),
          Text(
            _page!.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: DesignTokens.spaceLG),
        ],
        if (_page!.category.isNotEmpty) ...[
          Text(
            'Category',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: DesignTokens.spaceSM),
          Chip(
            label: Text(_page!.category),
            backgroundColor: theme.colorScheme.primaryContainer,
            labelStyle: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          SizedBox(height: DesignTokens.spaceLG),
        ],
        if (_page!.website != null && _page!.website!.isNotEmpty) ...[
          Text(
            'Website',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: DesignTokens.spaceSM),
          InkWell(
            onTap: () {
              // TODO: Open website URL
            },
            child: Row(
              children: [
                Icon(
                  Icons.link,
                  size: DesignTokens.iconSM,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(width: DesignTokens.spaceSM),
                Text(
                  _page!.website!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: DesignTokens.spaceLG),
        ],
        if (_page!.contactEmail != null && _page!.contactEmail!.isNotEmpty) ...[
          Text(
            'Contact Email',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: DesignTokens.spaceSM),
          Text(
            _page!.contactEmail!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: DesignTokens.spaceLG),
        ],
      ],
    ),
  );
}
```

---

## 4. Implementation Priority

### Phase 1: Backend (Critical - Must Do First)
1. ✅ Update `UserModel` - Add `followedPages` field
2. ✅ Update `PageRepository` - Refactor `followPage()` and `unfollowPage()`
3. ✅ Update `UserRepository` - Add `isFollowingPage()` method
4. ✅ Update `PostRepository` - Integrate followed pages into feed queries

### Phase 2: UI Refactor (High Priority)
5. ✅ Refactor `PageProfileScreen` - Theme compliance
6. ✅ Add future placeholder tabs (Shop, Events)
7. ✅ Improve Follow button styling and behavior

---

## 5. Testing Checklist

### Backend Testing
- [ ] User can follow a page (updates user's `followedPages` array)
- [ ] User can unfollow a page (removes from array)
- [ ] Page's `followerCount` increments/decrements correctly
- [ ] `isFollowingPage()` returns correct boolean
- [ ] Posts from followed pages appear in user's feed
- [ ] Atomic operations prevent inconsistent state

### UI Testing
- [ ] All colors use theme (`theme.colorScheme.*`)
- [ ] All spacing uses `DesignTokens.space*`
- [ ] All sizes use `DesignTokens.*` constants
- [ ] Follow button shows correct state (Follow vs Following)
- [ ] All tabs render correctly
- [ ] Placeholder tabs show "Coming Soon" messages
- [ ] Avatar positioning is correct
- [ ] Cover image displays properly
- [ ] Empty states are theme-compliant

---

## 6. Migration Notes

### Data Migration
**Important:** Existing users who have followed pages (via subcollection) will NOT have those pages in their `followedPages` array. Consider:

1. **Option A (Recommended):** Run a one-time migration script to populate `followedPages` from subcollections:
   ```dart
   // Migration script (run once)
   Future<void> migrateFollowedPages() async {
     final usersSnapshot = await _db.collection('users').get();
     for (final userDoc in usersSnapshot.docs) {
       final userId = userDoc.id;
       final followersSnapshot = await _db
           .collectionGroup('followers')
           .where('userId', isEqualTo: userId)
           .get();
       
       final pageIds = followersSnapshot.docs
           .map((doc) => doc.reference.parent.parent!.id)
           .toList();
       
       if (pageIds.isNotEmpty) {
         await _db.collection('users').doc(userId).update({
           'followedPages': pageIds,
         });
       }
     }
   }
   ```

2. **Option B:** Keep both systems (subcollection + array) for backward compatibility.

### Backward Compatibility
- Keep `PageRepository.isFollowingPage()` checking subcollection as fallback
- Or migrate all existing data before deployment

---

## 7. Security Rules Update

**File:** `firestore.rules`

**Action:** Ensure users can update their own `followedPages` array.

**Add Rule:**
```javascript
match /users/{userId} {
  allow update: if request.auth != null && request.auth.uid == userId
    && request.resource.data.diff(resource.data).affectedKeys()
        .hasOnly(['followedPages', 'updatedAt']);
}
```

---

## 8. Summary

This refactoring plan addresses:
1. ✅ **Follow System Integration:** Complete end-to-end functionality
2. ✅ **Theme Compliance:** 100% adherence to `app_theme.dart` and `design_tokens.dart`
3. ✅ **Future-Proofing:** Extensible tab structure with placeholders
4. ✅ **Professional UI/UX:** Facebook-style page layout

**Estimated Implementation Time:** 4-6 hours for a senior developer

**Risk Level:** Low (mostly additive changes, atomic operations prevent data corruption)

---

**END OF REFACTORING PLAN**

---

## Next Steps

Once you approve this plan, I will:
1. Implement all backend changes (models, repositories)
2. Implement all UI changes (PageProfileScreen refactor)
3. Provide complete, tested code for each file
4. Include migration script if needed

**Ready to proceed with implementation?** 🚀

