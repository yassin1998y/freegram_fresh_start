# Freegram - Project Master Document (Golden Master V1.0)

## 1. Project Description: The Nearby-First Pivot

**Freegram** is a **Nearby-First Social Discovery Ecosystem** built with Flutter. Unlike traditional social networks that prioritize algorithmic feeds, Freegram's core philosophy is physical proximity and real-time presence. It bridges the digital and physical worlds by allowing users to discover, interact with, and gift unique virtual items to people around them, creating a gamified "Gifting Economy" layered over the real world.

The application is architected as a Local-First experience, prioritizing immediate interactivity and offline resilience through the **GlobalCacheCoordinator**.

---

## 2. The Sonar Nearby System (Primary Core)

The **Sonar System** is the heartbeat of Freegram, enabling the "Nearby-First" experience. It governs how users detect each other and visualization of that presence.

### Core Mechanisms
*   **BLE Advertising/Scanning Loops:**
    *   The app runs a continuous background service (foreground notification pinned) that toggles between advertising the user's encrypted `uid` via Bluetooth Low Energy (BLE) and scanning for packets from other devices.
    *   **Advertiser:** Broadcasts a UUID-masked packet containing critical social signals (Interest Hash, Avatar Hash).
    *   **Scanner:** Filters discovered packets by RSSI (Signal Strength) to estimate distance (Immediate, Near, Far).
*   **Presence Persistence (Hive-backed):**
    *   **Discovery Event:** When a device is found, it is immediately upserted into the `nearby_users` Hive box.
    *   **Offline/Online Logic:** A "Last Seen" timestamp is updated on every packet receipt. If a user is not seen for >30 seconds, they are marked "Ghost/Offline" in the UI but retained in the persistency layer to prevent UI flickering.
    *   **Truth:** The `GlobalCacheCoordinator` streams the Hive box state to the UI, ensuring that the visual list is always stable, even if the BLE scan cycle is intermittent.
*   **60FPS Radar Visualization:**
    *   **Engine:** Custom `Canvas`-based render loop.
    *   **Logic:** Users are mapped to polar coordinates (`distance`, `angle`) on the radar. The `angle` is randomized (visual only) while `distance` is derived from RSSI.
    *   **Interpolation:** Avatar positions are interpolated to ensure smooth movement (60fps) even if BLE updates arrive at 1Hz.
    *   **Pulse Effect:** A radial shader effect propagates from the center, synchronized with the scanning cycle.

---

## 3. Complete Screen Registry (71 Screens) [UPDATED]

All screens adhere to the **1px Border Rule** (using `DesignTokens.borders`) and **SWR (Stale-While-Revalidate)** caching strategies. Every screen is registered in `AppRoutes` and accessible via named navigation.

### A. Authentication & Onboarding (3 screens)
1. **LoginScreen** (`/login`) - Email/password authentication with social login options
2. **SignUpScreen** (`/signup`) - Multi-step registration with profile setup
3. **MultiStepOnboardingScreen** (`/onboarding`) - Interactive tutorial and preference collection

### B. Main Navigation Hub (7 screens)
4. **MainScreen** (`/main`) - Bottom navigation container with 5 tabs
5. **NearbyScreen** (`/nearby`) - Sonar radar with BLE-based user discovery
6. **FeedScreen** (`/feed`) - Unified social feed with posts and stories
7. **CreatePostScreen** (`/createPost`) - Multi-media post composer
8. **MatchScreen** (`/match`) - Swipe-based discovery interface
9. **FriendsListScreen** (`/friends`) - Friend management and requests
10. **MenuScreen** (`/menu`) - Settings and profile access hub

### C. Social Content & Discovery (11 screens)
11. **ProfileScreen** (`/profile`) - User profile with posts, reels, and stats
12. **PostDetailScreen** (`/postDetail`) - Full post view with comments
13. **HashtagExploreScreen** (`/hashtagExplore`) - Hashtag-based content discovery
14. **SearchScreen** (`/search`) - Global user and content search
15. **MentionedPostsScreen** (`/mentionedPosts`) - Posts where user is mentioned
16. **ReelsFeedScreen** (`/reels`) - Vertical short-form video feed
17. **CreateReelScreen** (`/createReel`) - Reel recording and editing
18. **StoryCreatorScreen** (`/storyCreator`) - Photo/video story creation
19. **TextStoryCreatorScreen** (`/textStoryCreator`) - Text-based story creation
20. **StoryViewerScreen** (`/storyViewer`) - Immersive story viewing experience
21. **LocationPickerScreen** (`/locationPicker`) - Map-based location selection

### D. Communication (6 screens)
22. **ImprovedChatListScreen** (`/chatList`) - Direct message inbox
23. **ImprovedChatScreen** (`/chat`) - One-on-one messaging interface
24. **NearbyChatListScreen** (`/nearbyChatList`) - Nearby users chat discovery
25. **NearbyChatScreen** (`/nearbyChat`) - Proximity-based chat interface
26. **NotificationsScreen** (`/notifications`) - Activity and interaction feed
27. **NotificationSettingsScreen** (`/notificationSettings`) - Notification preferences

### E. Economy & Gifting (13 screens)
28. **StoreScreen** (`/store`) - Main store hub with tabs (Coins, Boosts, Gifts, Profile, Marketplace)
29. **MarketplaceScreen** (`/marketplace`) - **[Status: Integrated]** User-to-user item trading
30. **CategoryBrowseScreen** (`/categoryBrowse`) - Gift category exploration
31. **GiftDetailScreen** (`/giftDetail`) - Individual gift item details
32. **GiftHistoryScreen** (`/giftHistory`) - Sent and received gift log
33. **GiftSendSelectionScreen** (`/giftSendSelection`) - Gift selection interface
34. **GiftSendComposerScreen** (`/gift-send-composer`) - Gift message composition
35. **GiftSendFriendPickerScreen** (`/gift-send-friend-picker`) - Recipient selection
36. **InventoryScreen** (`/inventory`) - User's owned items vault
37. **LimitedEditionsScreen** (`/limitedEditions`) - Time-limited exclusive items
38. **WishlistScreen** (`/wishlist`) - Saved items for future purchase
39. **BoostPostScreen** (`/boostPost`) - Post promotion with targeting options
40. **BoostAnalyticsScreen** (`/boostAnalytics`) - Boost campaign performance metrics

### F. Pages & Communities (4 screens)
41. **PageProfileScreen** (`/pageProfile`) - Public page/community profile
42. **PageSettingsScreen** (`/pageSettings`) - Page management and configuration
43. **PageAnalyticsScreen** (`/pageAnalytics`) - **[Status: Integrated]** Page growth and engagement metrics
44. **CreatePageScreen** (`/createPage`) - New page creation wizard

### G. Gamification & Progression (4 screens)
45. **AchievementsScreen** (`/achievements`) - Badge and milestone showcase
46. **LeaderboardScreen** (`/leaderboard`) - Global and local rankings
47. **DailyGiftScreen** (`/dailyRewards`) - Daily login reward collection
48. **ReferralScreen** (`/referral`) - Referral program and tracking

### H. User Management (4 screens)
49. **EditProfileScreen** (`/editProfile`) - Profile editing and customization
50. **SettingsScreen** (`/settings`) - App settings and preferences
51. **QrDisplayScreen** (`/qrDisplay`) - Personal QR code for quick connections
52. **MatchAnimationScreen** (`/matchAnimation`) - Celebration screen for mutual matches

### I. Media Viewers (3 screens)
53. **ImageGalleryScreen** (`/imageGallery`) - Full-screen image viewer with zoom
54. **VideoPlayerScreen** (`/videoPlayer`) - Dedicated video playback interface
55. **FeatureDiscoveryScreen** (`/featureDiscovery`) - App feature tutorials

### J. Administration & Moderation (3 screens)
56. **AnalyticsDashboardScreen** (`/analyticsDashboard`) - **[Status: Integrated]** Platform-wide analytics
57. **ModerationDashboardScreen** (`/moderationDashboard`) - **[Status: Integrated]** Content moderation tools
58. **ReportScreen** (`/report`) - User/content reporting interface

### K. Random Chat Module (13 screens in `/screens/random_chat/`)
59. **RandomChatHomeScreen** - Main random chat hub
60. **RandomChatSearchingScreen** - Peer discovery with pulse animation
61. **RandomChatConnectedScreen** - Active WebRTC video chat
62. **RandomChatEndedScreen** - Post-chat feedback and actions
63. **RandomChatReportScreen** - In-chat reporting
64. **RandomChatSettingsScreen** - Chat preferences (gender, age filters)
65. **RandomChatHistoryScreen** - Past chat sessions
66. **RandomChatBlockedUsersScreen** - Blocked user management
67. **RandomChatCoinsScreen** - Chat-specific coin purchases
68. **RandomChatGiftsScreen** - In-chat gift sending
69. **RandomChatProfileScreen** - Peer profile preview
70. **RandomChatFeedbackScreen** - Chat quality feedback
71. **RandomChatTutorialScreen** - First-time user guide

---

## 4. Navigation Architecture

### Route Registration
- **Central Registry:** All routes defined in `lib/navigation/app_routes.dart`
- **Type-Safe Arguments:** Dedicated argument classes for complex data passing
- **Route Handler:** `main.dart` `onGenerateRoute` callback handles all navigation
- **Navigation Service:** Centralized `NavigationService` for programmatic navigation

### Accessibility Standards
- **Maximum Depth:** All screens reachable within 3 taps from MainScreen
- **Hub Screens:** Store, Menu, and Main act as navigation hubs
- **Deep Linking:** All routes support deep link activation
- **State Preservation:** Navigation state persisted across app restarts

---

## 5. The 'Pure' Identity Appendix (Maintainer Registry)

This section defines the inviolable rules of the ecosystem.

### A. Color Sanctity
*   **Brand Green (`0xFF00BFA5`):** The ONLY color for success, growth, primary actions, and "online" status. Never use standard `Colors.green`.
*   **Pulsing Red (`0xFFEF5350`):** The ONLY color for errors, admin flags, blocks, and "offline" status. Never use standard `Colors.red`.
*   **Glass/Neutral:** All containers use white with alpha transparency (e.g., `0.05` to `0.1`) and `1px` borders (`alpha: 0.1` to `0.2`).

### B. Interaction Rules (The Three-Tier Haptic System)
1.  **Light (`HapticFeedback.lightImpact()`):**
    *   Tab switches.
    *   Scrolling ticks (pickers).
    *   Generic button taps.
2.  **Medium (`HapticFeedback.mediumImpact()`):**
    *   Refreshing a feed (Pull-to-refresh).
    *   Toggling Sonar/Radar.
    *   Sending a message.
3.  **Heavy (`HapticFeedback.heavyImpact()`):**
    *   **Match Success.**
    *   Unlocking a Rare/Legendary Item.
    *   Admin Ban actions.
    *   Error states.

### D. The 1px Border Rule [NEW]
*   **Global Constraint:** Every interactive container, card, and input MUST use a 1.0px width border with `Theme.of(context).dividerColor` and a consistent `16.0px` corner radius (defined in `DesignTokens`). This creates the tactile, "Pure" aesthetic that defines Freegram's visual premium.

### C. Architecture: The Local-First Truth
*   **Single Source of Truth:** `GlobalCacheCoordinator`.
*   **Rule:** UI **NEVER** waits for the network.
    *   **Read:** UI requests data -> Coordinator serves Hive data immediately -> Coordinator fetches Network -> Coordinator updates Hive -> UI updates via Stream.
    *   **Write:** UI sends action -> Coordinator optimistically updates Hive (visible immediately) -> Coordinator queues Network req -> Reverts if Network fails.

---

## 6. System Architecture & Tech Stack

*   **Framework:** Flutter (v3.2.6+)
*   **Architecture:** Clean Architecture + BLoC
*   **Local DB:** Hive (NoSQL) - *The Brain*
*   **Remote DB:** Firebase Firestore/Realtime DB - *The Cloud*
*   **Media:** Cloudinary (Images), WebRTC (Live Video)

---

## 7. Core User Journeys [NEW]

### A. The Discovery Flow
*   **Nearby Search:** User opens the Radar → **BLE Presence:** Scanner detects proximity signals → **Profile Preview:** Radar avatar tap peels open a glass card → **Match Animation:** Mutual interest triggers the Heavy Haptic celebration and full-screen animation.

### B. The Economic Flow
*   **Boutique Selection:** User enters the Store → **Purchase Trigger:** One-tap coin transaction with biometric verification → **Inventory Update:** Item appears instantly in the Local-First Vault → **Leaderboard Point Payout:** Global rank updates in real-time as points are attributed to the user's spending profile.

---

## 8. System Resilience [NEW]

### A. Web Compatibility Guards
*   **kIsWeb Logic:** The application uses explicit `foundation.dart` checks to bypass mobile-only hardware (BLE, Byte-Caching) on Web platforms. 
*   **Direct URL Streaming:** For Reels on Web, the system forces direct URL streaming via `VideoPlayerController.networkUrl`, ensuring playback stability where filesystem caches are unavailable.

### B. SWR Caching (Stale-While-Revalidate)
*   **Feed Stability:** The Unified Feed prioritizes `Hive` data for instant visual rendering while refreshing from `Firestore` in the background. 
*   **Bad State Protection:** All LRU services (MediaPrefetchService) include strict `isEmpty` guards to prevent crashes during rapid feed invalidation or high-frequency caching cycles.

---

## 9. Random Chat Evolution [NEW]

### A. Old State (Legacy)
*   **Architecture:** Monolithic controller managing UI, Signaling, and Media streams simultaneously.
*   **Stability:** Prone to resource leaks (camera/mic staying open), "Zombie" connections after backgrounding, and race conditions during peer discovery.
*   **Discovery:** Basic polling mechanism without proper queuing or handshake validation.

### B. The Fixes (Refactoring)
*   **Service Separation:** Decoupled logic into `WebRTCService` (Media/Signaling), `LoungeRepository` (Queue/Handshake), and `MatchHistoryRepository` (Persistence).
*   **State Machine:** Implemented a strict `Searching -> Handshake -> Connected -> Rated` flow to prevent invalid transitions.
*   **Resource Management:** Added `Wakelock` integration to prevent screen sleep during video calls and mandated `dispose()` patterns for stream cleanup.
*   **Auto-Reconnect:** Built-in signaling recovery to handle temporary network drops without ending the session.

### C. Current State (Production)
*   **Robustness:** Enterprise-grade WebRTC handling with clear separation of concerns.
*   **UX:** Pulse animation during search, haptic feedback on connection, and integrated safety reporting.
*   **Maintainability:** Modular structure allowing independent updates to the signaling protocol or audio/video subsystems.
