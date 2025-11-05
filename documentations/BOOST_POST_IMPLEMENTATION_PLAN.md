# Boost Post Feature - Comprehensive Implementation Plan

**Project:** Sonar Pulse Social App (Flutter, Firebase)  
**Status:** Planning Phase  
**Date:** 2024

---

## Executive Summary

This document provides a comprehensive, end-to-end implementation plan for a "Boost Post" feature similar to Facebook and Instagram. The plan covers database schema, backend logic, UI/UX flow, and all visual components, ensuring strict adherence to the existing `SonarPulseTheme` and `DesignTokens` design system.

**Monetization Model:** In-app currency ("Coins") system

---

## Table of Contents

1. [Phase 1: Database & Data Model Architecture](#phase-1-database--data-model-architecture)
2. [Phase 2: Backend Logic & Repository Layer](#phase-2-backend-logic--repository-layer)
3. [Phase 3: UI/UX Flow & Visual Components](#phase-3-uiux-flow--visual-components)
4. [Phase 4: Cloud Functions & Analytics](#phase-4-cloud-functions--analytics)
5. [Implementation Checklist](#implementation-checklist)

---

## Phase 1: Database & Data Model Architecture

### 1.1 PostModel Enhancements

**File:** `lib/models/post_model.dart`

**Current Status:** ✅ **ALREADY IMPLEMENTED**

The following boost fields already exist in `PostModel`:
- `isBoosted: bool` - Flag indicating if post is currently boosted
- `boostEndTime: Timestamp?` - Timestamp when boost expires
- `boostTargeting: Map<String, dynamic>?` - Audience targeting criteria
- `boostStats: Map<String, dynamic>?` - Performance statistics

**No changes needed** - The model already supports all required boost functionality.

---

### 1.2 BoostPackageModel

**File:** `lib/models/boost_package_model.dart`

**Current Status:** ✅ **ALREADY IMPLEMENTED**

The model exists with:
- `packageId: String` - Unique identifier
- `name: String` - Display name (e.g., "1 Day Boost", "3 Day Boost")
- `duration: int` - Duration in days
- `targetReach: int` - Estimated reach (e.g., 1000, 5000, 10000)
- `price: int` - Price in coins

**Default Packages:**
- 1 Day Boost: 500 coins, ~1000 reach
- 3 Day Boost: 1200 coins, ~3000 reach
- 7 Day Boost: 2500 coins, ~10000 reach

**Recommendation:** Consider adding a `packageType` enum for future expansion (e.g., "basic", "premium", "enterprise") and a `boostMultiplier` field for dynamic pricing.

---

### 1.3 Firestore Collection Structure

#### Option A: Embedded in Posts Collection (Current Implementation) ✅

**Pros:**
- ✅ Simpler queries (single collection)
- ✅ No joins required
- ✅ Atomic updates
- ✅ Lower read costs
- ✅ Already implemented

**Cons:**
- ❌ Harder to query all active boosts across all posts
- ❌ No centralized boost management

**Current Structure:**
```
posts/{postId}
  ├── isBoosted: bool
  ├── boostEndTime: Timestamp
  ├── boostTargeting: Map
  └── boostStats: Map
```

#### Option B: Separate `boosts` Collection (NOT RECOMMENDED)

**Pros:**
- ✅ Centralized boost management
- ✅ Easy to query all active boosts

**Cons:**
- ❌ Requires joins/denormalization
- ❌ Higher read costs
- ❌ More complex queries
- ❌ Potential data inconsistency

**Recommendation:** **Keep Option A** (current implementation). It's simpler, more cost-effective, and sufficient for the scale. If boost management dashboard becomes critical, we can add a Cloud Function to maintain a denormalized `boosts` collection for admin purposes only.

---

### 1.4 Firestore Indexes Required

**File:** `firestore.indexes.json`

**Required Composite Index:**
```json
{
  "collectionGroup": "posts",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "isBoosted", "order": "ASCENDING" },
    { "fieldPath": "deleted", "order": "ASCENDING" },
    { "fieldPath": "visibility", "order": "ASCENDING" },
    { "fieldPath": "boostEndTime", "order": "DESCENDING" },
    { "fieldPath": "timestamp", "order": "DESCENDING" }
  ]
}
```

**Status:** ✅ Index already configured in `getBoostedPosts()` query

---

### 1.5 Firestore Security Rules

**File:** `firestore.rules`

**Required Rules for Boost Fields:**

```javascript
match /posts/{postId} {
  // Allow users to update boost fields only if they own the post
  allow update: if isOwner(resource.data.authorId) 
    && request.resource.data.diff(resource.data).affectedKeys()
      .hasOnly(['isBoosted', 'boostEndTime', 'boostTargeting', 'boostStats', 'updatedAt']);
  
  // Allow system to increment boost stats (for analytics)
  allow update: if isAuthenticated()
    && request.resource.data.diff(resource.data).affectedKeys()
      .hasOnly(['boostStats', 'updatedAt']);
}
```

**Status:** ⚠️ **NEEDS REVIEW** - Verify current rules allow boost updates

---

## Phase 2: Backend Logic & Repository Layer

### 2.1 PostRepository Enhancements

**File:** `lib/repositories/post_repository.dart`

#### 2.1.1 `activatePostBoost()` Method

**Current Status:** ✅ **ALREADY IMPLEMENTED** as `boostPost()`

**Method Signature:**
```dart
Future<void> boostPost({
  required String postId,
  required String userId,
  required BoostPackageModel boostPackage,
  required Map<String, dynamic> targetingData,
}) async
```

**Current Implementation Steps:**
1. ✅ Verify post ownership
2. ✅ Calculate boost end time (`now + duration days`)
3. ✅ Initialize boost stats if not exists
4. ✅ Update post document with boost fields

**Missing Step:** ⚠️ **Coin Deduction** - Currently handled in `BoostPostScreen`, but should be atomic with post update

**Recommended Enhancement:**
- Create a transaction that:
  1. Checks user coin balance
  2. Verifies post ownership
  3. Deducts coins atomically
  4. Updates post boost fields
  5. Creates boost transaction log (optional)

**Implementation Plan:**
```dart
Future<void> activatePostBoost({
  required String postId,
  required String userId,
  required BoostPackageModel package,
  required Map<String, dynamic> targeting,
}) async {
  final userRef = _db.collection('users').doc(userId);
  final postRef = _db.collection('posts').doc(postId);
  
  return _db.runTransaction((transaction) async {
    // 1. Get user and post documents
    final userDoc = await transaction.get(userRef);
    final postDoc = await transaction.get(postRef);
    
    if (!userDoc.exists || !postDoc.exists) {
      throw Exception('User or post not found');
    }
    
    final userData = userDoc.data()!;
    final postData = postDoc.data()!;
    
    // 2. Verify ownership
    if (postData['authorId'] != userId) {
      throw Exception('User is not the author of this post');
    }
    
    // 3. Check coin balance
    final currentCoins = (userData['coins'] ?? 0) as int;
    if (currentCoins < package.price) {
      throw Exception('Insufficient coins. Required: ${package.price}, Available: $currentCoins');
    }
    
    // 4. Calculate boost end time
    final now = DateTime.now();
    final boostEndTime = now.add(Duration(days: package.duration));
    
    // 5. Initialize boost stats
    final boostStats = postData['boostStats'] as Map<String, dynamic>? ?? {
      'impressions': 0,
      'clicks': 0,
      'reach': 0,
      'engagement': 0,
    };
    
    // 6. Atomic updates
    transaction.update(userRef, {
      'coins': FieldValue.increment(-package.price),
    });
    
    transaction.update(postRef, {
      'isBoosted': true,
      'boostEndTime': Timestamp.fromDate(boostEndTime),
      'boostTargeting': targeting,
      'boostStats': boostStats,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });
}
```

---

#### 2.1.2 Feed Integration - `getForYouFeedPosts()` / `getUnifiedFeed()`

**Current Status:** ✅ **ALREADY IMPLEMENTED**

**File:** `lib/repositories/post_repository.dart`

**Current Implementation:**
- `getBoostedPosts()` method exists and queries:
  - `isBoosted == true`
  - `boostEndTime > now`
  - `deleted == false`
  - `visibility == 'public'`
- `getUnifiedFeed()` already merges boosted posts with trending/following posts
- `_filterByTargeting()` applies client-side targeting filters
- `_calculateBoostScore()` prioritizes posts by engagement

**Current Mixing Logic:**
- Boosted posts are fetched in parallel with trending/following posts
- Deduplication by post ID
- Boosted posts get high priority in the merge order

**Recommendation:** ✅ Current implementation is solid. Consider:
- **Injection Ratio:** Currently ~1 boosted post per 15 organic posts (configurable via `limit` parameter)
- **Priority:** Boosted posts appear early in feed (after user's own posts)

**Enhancement Suggestions:**
1. Add `boostInjectionRate` parameter (default: 0.15 = 15%)
2. Add `maxBoostedPerBatch` parameter (default: 3)
3. Consider A/B testing different injection rates

---

#### 2.1.3 Boost Analytics Methods

**Current Status:** ✅ **ALREADY IMPLEMENTED**

**Methods:**
- `trackBoostImpression(String postId)` - Increments impressions
- `trackBoostClick(String postId)` - Increments clicks
- `trackBoostReach(String postId, String userId)` - Tracks unique reach

**Implementation Notes:**
- Uses `FieldValue.increment()` for atomic updates
- Reach tracking uses subcollection `posts/{postId}/boostReach/{userId}` to prevent duplicates
- Non-blocking (errors don't throw)

**Status:** ✅ **NO CHANGES NEEDED**

---

### 2.2 StoreRepository Enhancements

**File:** `lib/repositories/store_repository.dart`

**Current Status:** ⚠️ **PARTIALLY IMPLEMENTED**

**Current Method:**
```dart
Future<void> purchaseWithCoins(String userId, {
  required int coinCost,
  required int superLikeAmount,
}) async
```

**Issue:** This method is designed for super likes, not boost purchases. The `superLikeAmount` parameter is irrelevant for boosts.

**Recommendation:** Create a dedicated method for boost purchases:

```dart
/// Deduct coins for boost purchase
/// Returns true if successful, throws exception if insufficient coins
Future<void> purchaseBoostWithCoins({
  required String userId,
  required int coinCost,
  required String boostType, // 'post_boost'
}) async {
  final userRef = _db.collection('users').doc(userId);
  
  return _db.runTransaction((transaction) async {
    final userDoc = await transaction.get(userRef);
    if (!userDoc.exists) {
      throw Exception('User not found');
    }
    
    final userData = userDoc.data()!;
    final currentCoins = (userData['coins'] ?? 0) as int;
    
    if (currentCoins < coinCost) {
      throw Exception('Insufficient coins. Required: $coinCost, Available: $currentCoins');
    }
    
    transaction.update(userRef, {
      'coins': FieldValue.increment(-coinCost),
    });
  });
}
```

**Alternative:** Enhance `purchaseWithCoins()` to accept optional parameters:
```dart
Future<void> purchaseWithCoins(
  String userId, {
  required int coinCost,
  int superLikeAmount = 0,
  String? transactionType, // 'super_like', 'boost', etc.
  Map<String, dynamic>? metadata,
}) async
```

---

### 2.3 Boost Package Repository (Optional)

**File:** `lib/repositories/boost_package_repository.dart` (NEW)

**Purpose:** Fetch boost packages from Firestore (for dynamic pricing)

**Current Status:** ❌ **NOT IMPLEMENTED** - Packages are hardcoded

**Recommendation:** Create a repository for admin-managed packages:

```dart
class BoostPackageRepository {
  final FirebaseFirestore _db;
  
  BoostPackageRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;
  
  /// Get all available boost packages
  Future<List<BoostPackageModel>> getAvailablePackages() async {
    final snapshot = await _db
        .collection('boostPackages')
        .where('isActive', isEqualTo: true)
        .orderBy('price', ascending: true)
        .get();
    
    return snapshot.docs
        .map((doc) => BoostPackageModel.fromMap(doc.data()))
        .toList();
  }
  
  /// Get default packages (fallback if Firestore is unavailable)
  Future<List<BoostPackageModel>> getPackages() async {
    try {
      final packages = await getAvailablePackages();
      return packages.isNotEmpty 
          ? packages 
          : BoostPackageModel.getDefaultPackages();
    } catch (e) {
      debugPrint('BoostPackageRepository: Error fetching packages: $e');
      return BoostPackageModel.getDefaultPackages();
    }
  }
}
```

**Firestore Collection:**
```
boostPackages/{packageId}
  ├── packageId: string
  ├── name: string
  ├── duration: number
  ├── targetReach: number
  ├── price: number
  ├── isActive: boolean
  └── createdAt: timestamp
```

**Priority:** 🟡 **LOW** - Can be added in Phase 2 if dynamic pricing is needed

---

## Phase 3: UI/UX Flow & Visual Components

### 3.1 PostCard Enhancements

**File:** `lib/widgets/feed_widgets/post_card.dart`

#### 3.1.1 Boost Button Trigger

**Current Status:** ❌ **NOT IMPLEMENTED**

**Location:** In the post header (near the "more options" menu)

**Requirements:**
- ✅ Only visible if `post.authorId == currentUser.id`
- ✅ Use `theme.colorScheme.primary` for button color
- ✅ Use `theme.textTheme.labelLarge` for text style
- ✅ Icon: `Icons.trending_up` or `Icons.rocket_launch`
- ✅ Position: Between author name and "more options" menu (or in the menu itself)

**Implementation Plan:**

**Option A: Add to Header Row (Recommended)**
```dart
// In _buildHeader() method, after author info, before PopupMenuButton
if (post.authorId == currentUserId) ...[
  if (post.isBoosted && post.boostEndTime != null && 
      post.boostEndTime!.toDate().isAfter(DateTime.now())) ...[
    // Show "View Insights" button for active boosts
    TextButton.icon(
      onPressed: () => _navigateToBoostInsights(context, post),
      icon: Icon(
        Icons.insights,
        size: DesignTokens.iconSM,
      ),
      label: Text(
        'View Insights',
        style: theme.textTheme.labelSmall,
      ),
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceSM,
          vertical: DesignTokens.spaceXS,
        ),
      ),
    ),
  ] else ...[
    // Show "Boost Post" button for non-boosted posts
    TextButton.icon(
      onPressed: () => _navigateToBoostPost(context, post),
      icon: Icon(
        Icons.trending_up,
        size: DesignTokens.iconSM,
      ),
      label: Text(
        'Boost',
        style: theme.textTheme.labelSmall,
      ),
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceSM,
          vertical: DesignTokens.spaceXS,
        ),
      ),
    ),
  ],
],
```

**Option B: Add to PopupMenu (Alternative)**
```dart
// In PopupMenuButton itemBuilder, add boost option
if (isOwner) ...[
  PopupMenuItem(
    value: post.isBoosted ? 'view_insights' : 'boost',
    child: Row(
      children: [
        Icon(
          post.isBoosted ? Icons.insights : Icons.trending_up,
          size: DesignTokens.iconMD,
          color: theme.colorScheme.primary,
        ),
        SizedBox(width: DesignTokens.spaceSM),
        Text(
          post.isBoosted ? 'View Boost Insights' : 'Boost Post',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    ),
  ),
  // ... other menu items
]
```

**Recommendation:** **Option A** (header button) - More discoverable and follows Instagram/Facebook pattern.

---

#### 3.1.2 "Promoted" Label for Boosted Posts

**Current Status:** ✅ **ALREADY IMPLEMENTED**

**Implementation:** The `_buildDisplayTypeBadge()` method already handles `PostDisplayType.boosted` with:
- Label: "Promoted"
- Color: `DesignTokens.warningColor`
- Icon: `Icons.trending_up`

**Styling:**
- Uses `theme.textTheme.bodySmall` with `fontWeight: FontWeight.bold`
- Background: `color.withOpacity(0.1)`
- Border: `color.withOpacity(0.3)`
- Border radius: `DesignTokens.radiusSM`

**Status:** ✅ **NO CHANGES NEEDED**

---

#### 3.1.3 Boost Impression Tracking

**Current Status:** ✅ **ALREADY IMPLEMENTED**

**Implementation:**
- `_hasTrackedBoostImpression` flag prevents duplicate tracking
- `_trackBoostImpression()` called in `initState()` if post is boosted
- Uses `VisibilityDetector` pattern (though not explicitly implemented for boosts)

**Recommendation:** Add explicit visibility detection:

```dart
// Wrap PostCard content with VisibilityDetector
VisibilityDetector(
  key: Key('boost_post_${post.id}'),
  onVisibilityChanged: (info) {
    if (info.visibleFraction > 0.5 && 
        post.isBoosted && 
        !_hasTrackedBoostImpression) {
      _trackBoostImpression(post);
    }
  },
  child: // ... existing post card content
)
```

---

### 3.2 BoostPostScreen (The Funnel)

**File:** `lib/screens/boost_post_screen.dart`

**Current Status:** ✅ **ALREADY IMPLEMENTED** (but needs design system compliance review)

#### 3.2.1 Screen Structure

**Current Implementation:**
1. ✅ Package Selection (Radio buttons)
2. ✅ Targeting Options (Location, Age, Gender, Interests)
3. ✅ Boost Button (with coin price)

**Design System Compliance Issues:**
- ⚠️ Uses hardcoded padding (`const EdgeInsets.all(16.0)`) instead of `DesignTokens`
- ⚠️ Uses hardcoded colors instead of theme colors
- ⚠️ AppBar doesn't use theme styling
- ⚠️ Button styling doesn't use `theme.elevatedButtonTheme`

#### 3.2.2 Required Design System Updates

**Step 1: Update AppBar**
```dart
AppBar(
  title: Text(
    'Boost Post',
    style: theme.textTheme.titleLarge,
  ),
  backgroundColor: theme.colorScheme.surface,
  foregroundColor: theme.colorScheme.onSurface,
  elevation: 0,
)
```

**Step 2: Update Padding**
```dart
// Replace all hardcoded padding
padding: EdgeInsets.all(DesignTokens.spaceMD),
```

**Step 3: Update Section Titles**
```dart
Widget _buildSectionTitle(String title) {
  return Text(
    title,
    style: theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onSurface,
    ),
  );
}
```

**Step 4: Update Package Cards**
```dart
Widget _buildPackageCard(BoostPackageModel package) {
  final isSelected = _selectedPackage?.packageId == package.packageId;
  final theme = Theme.of(context);
  
  return Card(
    margin: EdgeInsets.only(bottom: DesignTokens.spaceSM),
    elevation: isSelected ? DesignTokens.elevation2 : DesignTokens.elevation1,
    color: isSelected 
        ? theme.colorScheme.primaryContainer 
        : theme.cardTheme.color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      side: isSelected
          ? BorderSide(
              color: theme.colorScheme.primary,
              width: 2,
            )
          : BorderSide.none,
    ),
    child: InkWell(
      onTap: () => setState(() => _selectedPackage = package),
      borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      child: Padding(
        padding: EdgeInsets.all(DesignTokens.spaceMD),
        child: Row(
          children: [
            Radio<BoostPackageModel>(
              value: package,
              groupValue: _selectedPackage,
              onChanged: (value) => setState(() => _selectedPackage = value),
              activeColor: theme.colorScheme.primary,
            ),
            SizedBox(width: DesignTokens.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: DesignTokens.spaceXS),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: DesignTokens.iconSM,
                        color: theme.colorScheme.onSurface.withOpacity(
                          DesignTokens.opacityMedium,
                        ),
                      ),
                      SizedBox(width: DesignTokens.spaceXS),
                      Text(
                        '~${_formatNumber(package.targetReach)} estimated reach',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(
                            DesignTokens.opacityMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: DesignTokens.spaceXS),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: DesignTokens.iconSM,
                        color: theme.colorScheme.onSurface.withOpacity(
                          DesignTokens.opacityMedium,
                        ),
                      ),
                      SizedBox(width: DesignTokens.spaceXS),
                      Text(
                        '${package.duration} ${package.duration == 1 ? 'day' : 'days'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(
                            DesignTokens.opacityMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${package.price}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  'Coins',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(
                      DesignTokens.opacityMedium,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
```

**Step 5: Update Boost Button**
```dart
SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: _isProcessing ? null : _boostPost,
    style: theme.elevatedButtonTheme.style?.copyWith(
      backgroundColor: WidgetStateProperty.all(
        theme.colorScheme.primary,
      ),
      foregroundColor: WidgetStateProperty.all(
        theme.colorScheme.onPrimary,
      ),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(
          vertical: DesignTokens.spaceMD,
          horizontal: DesignTokens.spaceLG,
        ),
      ),
    ),
    child: _isProcessing
        ? SizedBox(
            width: DesignTokens.iconMD,
            height: DesignTokens.iconMD,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.onPrimary,
            ),
          )
        : Text(
            _selectedPackage != null
                ? 'Boost Now (${_selectedPackage!.price} Coins)'
                : 'Select Package',
            style: theme.textTheme.labelLarge,
          ),
  ),
)
```

**Step 6: Update Targeting Options**
- Use `theme.inputDecorationTheme` for TextFields
- Use `theme.switchTheme` for Switches
- Use `DesignTokens` for all spacing

---

#### 3.2.3 Multi-Step Flow (Optional Enhancement)

**Current:** Single scrollable screen with all options

**Recommended:** Multi-step wizard (Step 1: Audience, Step 2: Budget, Step 3: Confirmation)

**Implementation Plan:**

```dart
class _BoostPostScreenState extends State<BoostPostScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  
  // Step 1: Audience Selection
  Widget _buildAudienceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Audience',
          style: theme.textTheme.headlineSmall,
        ),
        SizedBox(height: DesignTokens.spaceLG),
        
        // Automatic vs Custom
        ToggleButtons(
          isSelected: [_audienceMode == 'automatic', _audienceMode == 'custom'],
          onPressed: (index) {
            setState(() {
              _audienceMode = index == 0 ? 'automatic' : 'custom';
            });
          },
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
              child: Text('Automatic'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
              child: Text('Create Your Own'),
            ),
          ],
        ),
        
        if (_audienceMode == 'custom') ...[
          SizedBox(height: DesignTokens.spaceLG),
          // Custom targeting fields
          // ... (existing targeting UI)
        ],
      ],
    );
  }
  
  // Step 2: Budget & Duration
  Widget _buildBudgetStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Boost Package',
          style: theme.textTheme.headlineSmall,
        ),
        SizedBox(height: DesignTokens.spaceLG),
        // Package cards (existing implementation)
        ...BoostPackageModel.getDefaultPackages().map((package) {
          return _buildPackageCard(package);
        }),
      ],
    );
  }
  
  // Step 3: Confirmation
  Widget _buildConfirmationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review & Confirm',
          style: theme.textTheme.headlineSmall,
        ),
        SizedBox(height: DesignTokens.spaceLG),
        Card(
          child: Padding(
            padding: EdgeInsets.all(DesignTokens.spaceMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryRow('Package', _selectedPackage?.name ?? ''),
                Divider(),
                _buildSummaryRow('Duration', '${_selectedPackage?.duration} days'),
                Divider(),
                _buildSummaryRow('Estimated Reach', '~${_selectedPackage?.targetReach} people'),
                Divider(),
                _buildSummaryRow('Cost', '${_selectedPackage?.price} Coins'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

**Priority:** 🟡 **MEDIUM** - Improves UX but current single-screen is acceptable

---

### 3.3 BoostInsightsScreen (Analytics)

**File:** `lib/screens/boost_analytics_screen.dart`

**Current Status:** ✅ **ALREADY IMPLEMENTED**

**Design System Compliance Issues:**
- ⚠️ Uses hardcoded colors instead of theme
- ⚠️ Uses hardcoded padding
- ⚠️ Metric cards don't use theme card styling

#### 3.3.1 Required Updates

**Step 1: Update Metric Cards**
```dart
Widget _buildMetricCard(
  BuildContext context,
  String label,
  String value,
  IconData icon,
  Color color,
) {
  final theme = Theme.of(context);
  
  return Card(
    elevation: DesignTokens.elevation2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
    ),
    child: Padding(
      padding: EdgeInsets.all(DesignTokens.spaceMD),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: DesignTokens.iconXL,
          ),
          SizedBox(height: DesignTokens.spaceSM),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: DesignTokens.spaceXS),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(
                DesignTokens.opacityMedium,
              ),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
```

**Step 2: Update Status Card**
```dart
Card(
  color: isActive
      ? theme.colorScheme.primaryContainer.withOpacity(0.3)
      : theme.colorScheme.surface,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
  ),
  child: Padding(
    padding: EdgeInsets.all(DesignTokens.spaceMD),
    // ... existing content
  ),
)
```

**Step 3: Add Chart Visualization (Bonus)**

**Package:** `fl_chart` (add to `pubspec.yaml`)

```dart
// Daily impressions chart
LineChart(
  LineChartData(
    gridData: FlGridData(show: false),
    titlesData: FlTitlesData(show: false),
    borderData: FlBorderData(show: false),
    lineBarsData: [
      LineChartBarData(
        spots: _dailyStats.map((stat) => 
          FlSpot(stat.day.toDouble(), stat.impressions.toDouble())
        ).toList(),
        isCurved: true,
        color: theme.colorScheme.primary,
        barWidth: 3,
        dotData: FlDotData(show: false),
      ),
    ],
  ),
)
```

**Priority:** 🟢 **HIGH** - Design system compliance is critical

---

## Phase 4: Cloud Functions & Analytics

### 4.1 Boost Analytics Cloud Function

**File:** `functions/index.js`

**Purpose:** Track boost impressions, clicks, and engagement server-side

**Current Status:** ❌ **NOT IMPLEMENTED**

**Implementation Plan:**

```javascript
// Track boost impression (called from client)
exports.trackBoostImpression = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const { postId } = data;
  if (!postId) {
    throw new functions.https.HttpsError('invalid-argument', 'postId is required');
  }
  
  const postRef = admin.firestore().collection('posts').doc(postId);
  
  return admin.firestore().runTransaction(async (transaction) => {
    const postDoc = await transaction.get(postRef);
    if (!postDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Post not found');
    }
    
    const postData = postDoc.data();
    if (!postData.isBoosted) {
      throw new functions.https.HttpsError('failed-precondition', 'Post is not boosted');
    }
    
    // Increment impressions
    transaction.update(postRef, {
      'boostStats.impressions': admin.firestore.FieldValue.increment(1),
      'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    });
    
    return { success: true };
  });
});

// Track boost engagement (likes, comments, shares)
exports.trackBoostEngagement = functions.firestore
  .document('posts/{postId}/reactions/{userId}')
  .onCreate(async (snap, context) => {
    const postId = context.params.postId;
    const postRef = admin.firestore().collection('posts').doc(postId);
    
    const postDoc = await postRef.get();
    if (!postDoc.exists || !postDoc.data().isBoosted) {
      return null; // Not a boosted post, ignore
    }
    
    // Increment engagement
    return postRef.update({
      'boostStats.engagement': admin.firestore.FieldValue.increment(1),
      'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    });
  });
```

**Priority:** 🟡 **MEDIUM** - Client-side tracking is sufficient for MVP

---

### 4.2 Boost Expiration Cleanup

**File:** `functions/index.js`

**Purpose:** Automatically disable expired boosts

**Current Status:** ❌ **NOT IMPLEMENTED**

**Implementation Plan:**

```javascript
// Scheduled function to clean up expired boosts (runs daily)
exports.cleanupExpiredBoosts = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const postsRef = admin.firestore().collection('posts');
    
    const expiredBoosts = await postsRef
      .where('isBoosted', '==', true)
      .where('boostEndTime', '<=', now)
      .limit(500)
      .get();
    
    const batch = admin.firestore().batch();
    let batchCount = 0;
    
    expiredBoosts.forEach((doc) => {
      batch.update(doc.ref, {
        'isBoosted': false,
        'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
      });
      batchCount++;
      
      if (batchCount === 500) {
        batch.commit();
        batchCount = 0;
      }
    });
    
    if (batchCount > 0) {
      await batch.commit();
    }
    
    console.log(`Cleaned up ${expiredBoosts.size} expired boosts`);
    return null;
  });
```

**Priority:** 🟢 **HIGH** - Ensures data consistency

---

### 4.3 Boost Analytics Dashboard (Admin)

**File:** `functions/index.js` or `lib/screens/admin_boost_dashboard.dart`

**Purpose:** Admin view of all active boosts and revenue

**Status:** 🟡 **FUTURE ENHANCEMENT**

**Priority:** 🔴 **LOW** - Can be added post-MVP

---

## Phase 5: Integration Points

### 5.1 Navigation Integration

**Files to Update:**
- `lib/screens/feed_screen.dart`
- `lib/widgets/feed_widgets/post_card.dart`

**Add Navigation:**
```dart
// In post_card.dart
void _navigateToBoostPost(BuildContext context, PostModel post) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => BoostPostScreen(post: post),
    ),
  ).then((boosted) {
    if (boosted == true) {
      // Refresh feed or show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post boosted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  });
}

void _navigateToBoostInsights(BuildContext context, PostModel post) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => BoostAnalyticsScreen(post: post),
    ),
  );
}
```

---

### 5.2 Coin Balance Display

**File:** `lib/screens/boost_post_screen.dart`

**Add Current Balance Display:**
```dart
// At top of screen, show user's current coin balance
FutureBuilder<UserModel?>(
  future: _userRepository.getUser(currentUser.uid),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return SizedBox.shrink();
    
    final user = snapshot.data!;
    return Card(
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: EdgeInsets.all(DesignTokens.spaceMD),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_wallet,
              color: theme.colorScheme.primary,
            ),
            SizedBox(width: DesignTokens.spaceSM),
            Text(
              'Your Balance: ',
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              '${user.coins} Coins',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  },
)
```

---

## Implementation Checklist

### Phase 1: Database & Models
- [x] PostModel boost fields (already implemented)
- [x] BoostPackageModel (already implemented)
- [x] Firestore indexes (already configured)
- [ ] Review Firestore security rules for boost fields

### Phase 2: Backend Logic
- [x] `boostPost()` method (already implemented)
- [ ] Enhance `boostPost()` with atomic coin deduction transaction
- [x] `getBoostedPosts()` method (already implemented)
- [x] `trackBoostImpression()` method (already implemented)
- [x] `trackBoostClick()` method (already implemented)
- [x] `trackBoostReach()` method (already implemented)
- [ ] Create `purchaseBoostWithCoins()` in StoreRepository
- [ ] (Optional) Create BoostPackageRepository for dynamic pricing

### Phase 3: UI Components
- [ ] Add "Boost Post" button to PostCard header
- [ ] Add "View Insights" button for active boosts
- [x] "Promoted" label display (already implemented)
- [ ] Update BoostPostScreen to use DesignTokens
- [ ] Update BoostPostScreen to use theme colors
- [ ] Update BoostInsightsScreen to use DesignTokens
- [ ] Update BoostInsightsScreen to use theme colors
- [ ] Add coin balance display to BoostPostScreen
- [ ] (Optional) Convert BoostPostScreen to multi-step wizard

### Phase 4: Cloud Functions
- [ ] Implement `trackBoostImpression` Cloud Function
- [ ] Implement `cleanupExpiredBoosts` scheduled function
- [ ] (Optional) Implement boost analytics dashboard

### Phase 5: Integration & Testing
- [ ] Test boost purchase flow end-to-end
- [ ] Test boost expiration
- [ ] Test boost analytics tracking
- [ ] Test feed injection of boosted posts
- [ ] Test targeting filters
- [ ] Test insufficient coins error handling
- [ ] Test boost insights display

---

## Design System Compliance Summary

### Colors
- ✅ Use `theme.colorScheme.primary` for primary actions
- ✅ Use `theme.colorScheme.onSurface` for text
- ✅ Use `theme.colorScheme.surface` for cards
- ✅ Use `DesignTokens.warningColor` for "Promoted" badge

### Typography
- ✅ Use `theme.textTheme.headlineSmall` for large numbers
- ✅ Use `theme.textTheme.bodyMedium` for labels
- ✅ Use `theme.textTheme.labelLarge` for buttons

### Spacing
- ✅ Use `DesignTokens.spaceXS/SM/MD/LG/XL` for all padding/margins
- ✅ Follow 8px grid system

### Components
- ✅ Use `theme.cardTheme` for cards
- ✅ Use `theme.elevatedButtonTheme` for buttons
- ✅ Use `theme.inputDecorationTheme` for inputs

---

## Future Enhancements

1. **A/B Testing:** Different boost injection rates
2. **Dynamic Pricing:** Adjust package prices based on demand
3. **Boost Scheduling:** Allow users to schedule boosts
4. **Boost Templates:** Pre-configured targeting presets
5. **Performance Predictions:** Show estimated engagement before purchase
6. **Boost History:** View all past boosts for a post
7. **Boost Recommendations:** Suggest optimal boost packages based on post content

---

## Notes

- Current implementation is ~80% complete
- Main gaps: Design system compliance, atomic transactions, UI polish
- Estimated implementation time: 2-3 days for remaining work
- Priority: Complete design system compliance first, then enhancements

---

**Document Version:** 1.0  
**Last Updated:** 2024  
**Author:** Senior Full-Stack Architect & Product Designer

