# Freegram - Social Media Platform

## App Overview

**Freegram** is a comprehensive social media platform built with Flutter that combines traditional social networking features with innovative gifting mechanics, location-based discovery, and rich multimedia content sharing. The app emphasizes user engagement through virtual gifts, real-time chat, short-form video content (Reels), ephemeral stories, and nearby user discovery.

**Platform**: Cross-platform (iOS, Android, Web, Desktop)  
**Framework**: Flutter 3.2.6+  
**Backend**: Firebase (Firestore, Auth, Storage, Cloud Functions, Realtime Database)  
**State Management**: BLoC Pattern with flutter_bloc

---

## Core Features

### 🎁 Virtual Gifting System
The centerpiece feature that sets Freegram apart from traditional social platforms.

**Gift Types & Rarity**
- **Common, Rare, Epic, Legendary** rarity tiers
- **Categories**: Love, Celebration, Funny, Seasonal, Special
- Animated gifts using Lottie animations and GIFs
- Limited edition gifts with availability windows
- Tradeable and upgradeable gift mechanics

**Gift Economy**
- In-app coin currency system
- Gift marketplace with dynamic pricing
- User inventory management
- Gift history tracking
- Wishlist functionality
- Gift showcase on user profiles
- Daily gift rewards

**Gift Interactions**
- Send gifts to friends via chat
- Gift notifications with rich animations
- Gift message banners in conversations
- Friend picker for gift sending
- Gift composer with personalized messages

### 💬 Advanced Chat System
Real-time messaging with rich media support and gift integration.

**Chat Features**
- One-on-one messaging
- Real-time message delivery
- Read receipts and typing indicators
- Message templates for quick replies
- Rich text formatting
- Smart text links (phone, email, URLs)

**Media Sharing**
- Photo and video sharing
- Audio messages with recording
- GIF support
- File attachments
- Gift sending within chat

**Chat Management**
- Chat list with unread counts
- Message search
- Chat archiving
- User blocking and reporting
- Professional notification system with action buttons

### 📹 Reels (Short-Form Video)
TikTok-style vertical video feed with creation tools.

**Reel Creation**
- Video recording with camera integration
- Video trimming and editing
- Client-side video compression
- Audio overlay and music
- Text overlays and stickers
- Drawing tools
- Draft saving system
- Background upload queue

**Reel Feed**
- Infinite scroll vertical feed
- Auto-play with preloading
- Like, comment, share interactions
- Reel analytics for creators
- Hashtag support
- Mention support

**Engagement**
- Like and comment system
- Share to other platforms
- Reel-specific notifications
- View count tracking
- Engagement analytics

### 📖 Stories
Instagram-style ephemeral content that disappears after 24 hours.

**Story Creation**
- Photo and video stories
- Text-only stories with customizable backgrounds
- Recent gallery photo selection
- Story camera with filters
- Text overlays with custom fonts
- Sticker overlays
- Drawing tools

**Story Viewing**
- Story tray with user avatars
- Tap to advance, hold to pause
- Story ring indicators (viewed/unviewed)
- Story viewer list
- Reply to stories via DM

**Story Management**
- 24-hour auto-deletion
- Manual story deletion
- Story privacy controls
- Story highlights (permanent collections)

### 👥 Social Networking

**Friend System**
- Send/receive friend requests
- Accept/decline requests with action buttons
- Friend list management
- Friend request limits to prevent spam
- Friend cache for performance
- Recent recipients tracking

**User Profiles**
- Customizable profile photos (Cloudinary integration)
- Bio and personal information
- Age, gender, country
- Gift showcase section
- Post grid
- Reel grid
- Story highlights
- Achievements display
- Verification badges

**Discovery & Search**
- User search by username
- Hashtag exploration
- Category browsing
- Trending content
- Mentioned posts view

### 📍 Nearby Discovery
Location-based features for discovering users and content in your area.

**Nearby Features**
- Bluetooth Low Energy (BLE) discovery
- Location-based user matching
- Nearby chat rooms
- Sonar-style radar visualization
- Wave sending to nearby users
- Match animations for connections

**Privacy & Permissions**
- Location permission handling
- Bluetooth permission management
- Privacy controls for nearby visibility
- Distance-based filtering

### 🏪 Marketplace & Store

**Virtual Store**
- Gift catalog with filtering
- Category-based browsing
- Limited edition items
- Coin packages for purchase
- In-app purchase integration (IAP)
- Wishlist management

**Marketplace**
- User-to-user gift trading
- Listing creation and management
- Offer system
- Transaction history
- Marketplace analytics

**Monetization**
- In-app purchases for coins
- Google Mobile Ads integration
- Ad impression tracking
- Boost post feature (promote content)
- Boost analytics dashboard

### 📱 Feed & Content Discovery

**Unified Feed**
- Algorithmic content ranking
- Post scoring system
- Feed caching for offline viewing
- Intelligent prefetching
- Pull-to-refresh
- Infinite scroll

**Post Types**
- Text posts
- Photo posts (single/multiple)
- Video posts
- Location-tagged posts
- Hashtag support
- User mentions

**Post Interactions**
- Like/unlike
- Comment system with threading
- Reactions (emoji-based)
- Share functionality
- Boost posts (paid promotion)
- Post analytics

### 🔔 Notifications

**Notification Types**
- Friend requests
- Friend request accepted
- New messages
- Post likes and comments
- Reel interactions
- Gift received
- Mentions
- Story replies

**Notification Features**
- Rich notifications with images
- Action buttons (Accept/Decline, Reply, View)
- Notification grouping
- Notification history
- Customizable notification preferences
- FCM (Firebase Cloud Messaging) integration
- Background notification handling

### 🎯 Gamification & Engagement

**Achievements System**
- Unlockable achievements
- Progress tracking
- Achievement notifications
- Leaderboards

**Daily Rewards**
- Daily login bonuses
- Coin rewards
- Streak tracking
- Daily gift system

**Referral Program**
- Referral code generation
- QR code sharing
- Referral rewards
- Referral tracking

### 🎨 Pages (Business Profiles)
Business/creator accounts with enhanced features.

**Page Features**
- Page creation and management
- Page analytics dashboard
- Follower insights
- Post performance metrics
- Page settings and customization
- Verification system

**Page Analytics**
- Follower growth tracking
- Engagement metrics
- Content performance
- Demographic insights

### ⚙️ Settings & Customization

**Account Settings**
- Profile editing
- Privacy controls
- Notification preferences
- Blocked users management
- Account deletion

**App Settings**
- Theme selection (Light/Dark/System)
- Language preferences
- Data usage controls
- Cache management

**Moderation**
- Content reporting system
- User reporting
- Moderation dashboard (admin)
- Report review and action

### 🔐 Authentication & Security

**Authentication Methods**
- Email/password sign-up and login
- Google Sign-In
- Facebook Authentication
- Multi-step onboarding for new users
- Session management
- Secure credential storage (.env)

**Security Features**
- Firebase security rules
- User data encryption
- Secure API key management
- Permission handling
- Privacy controls

---

## Technical Architecture

### State Management
- **BLoC Pattern**: Separation of business logic from UI
- **Key BLoCs**:
  - AuthBloc (authentication state)
  - ConnectivityBloc (network status)
  - FriendsBloc (friend management)
  - ProfileBloc (user profile)
  - NotificationBloc (notifications)
  - ReelUploadBloc (reel uploads)
  - ReelsFeedBloc (reel feed)
  - UnifiedFeedBloc (main feed)
  - NearbyBloc (location discovery)
  - SearchBloc (search functionality)

### Data Layer
- **Repositories**: Abstraction layer for data sources
  - AuthRepository
  - UserRepository
  - GiftRepository
  - PostRepository
  - ReelRepository
  - ChatRepository
  - NotificationRepository
  - And 16+ more specialized repositories

### Services (46+ Services)
**Core Services**
- NavigationService (app-wide navigation)
- AnalyticsService (Firebase Analytics)
- CacheManagerService (image/data caching)
- SessionManager (user session handling)

**Media Services**
- CloudinaryService (image upload/optimization)
- VideoUploadService (video processing)
- AudioMergerService (audio manipulation)
- GalleryService (photo selection)

**Social Services**
- GiftNotificationService (gift alerts)
- GiftSharingService (gift distribution)
- FriendCacheService (friend data caching)
- RealtimePresenceService (online status)

**Content Services**
- FeedCacheService (feed optimization)
- FeedScoringService (content ranking)
- IntelligentPrefetchService (predictive loading)
- MediaPrefetchService (media preloading)
- ReelsScoringService (reel ranking)

**Engagement Services**
- DailyRewardService (gamification)
- ReferralService (user growth)
- InAppPurchaseService (monetization)
- AdService (advertising)

**Bluetooth/Location Services**
- BluetoothService (BLE communication)
- BluetoothDiscoveryService (device discovery)
- WaveService (nearby interactions)

**Upload Services**
- UploadQueueService (background uploads)
- UploadProgressService (upload tracking)
- ReelUploadManager (reel upload orchestration)
- DraftPersistenceService (draft saving)

### Local Storage
- **Hive**: Fast, lightweight NoSQL database
- **SharedPreferences**: Simple key-value storage
- **Cache Manager**: Network image caching

### UI/UX
- **Theme**: Custom SonarPulse theme with light/dark modes
- **Design Tokens**: Consistent spacing, colors, typography
- **Google Fonts**: Custom typography
- **Animations**: Lottie, confetti, custom animations
- **Shimmer Loading**: Skeleton screens for better UX

---

## Key Dependencies

### Firebase
- firebase_core, firebase_auth, cloud_firestore
- firebase_storage, firebase_messaging
- firebase_database (Realtime Database for presence)
- firebase_analytics, cloud_functions

### UI/UX
- flutter_bloc, provider (state management)
- google_fonts, shimmer, confetti
- showcaseview (feature tutorials)
- lottie (animations)

### Media
- video_player, video_thumbnail, camera
- video_compress, image_picker, photo_manager
- cached_network_image, photo_view
- audioplayers, record (audio)

### Social
- google_sign_in, flutter_facebook_auth
- share_plus, url_launcher

### Location & Bluetooth
- geolocator, geocoding
- flutter_blue_plus, flutter_ble_peripheral
- permission_handler

### Monetization
- google_mobile_ads, in_app_purchase

### Utilities
- get_it (dependency injection)
- hive, shared_preferences (storage)
- connectivity_plus (network status)
- timeago, intl (formatting)
- uuid, crypto (utilities)
- fl_chart (analytics charts)

---

## User Flows

### New User Journey
1. **Splash Screen** → App initialization
2. **Login/Sign-Up** → Authentication
3. **Multi-Step Onboarding** → Profile setup (username, age, gender, country)
4. **Feature Discovery** → Interactive tutorials
5. **Main Screen** → Access to all features

### Gift Sending Flow
1. Open chat or profile
2. Tap gift icon
3. **Gift Selection Screen** → Browse/filter gifts
4. **Gift Composer** → Add personalized message
5. Confirm and send
6. Recipient receives notification
7. Gift appears in chat with animation

### Reel Creation Flow
1. Tap create reel button
2. Record video or select from gallery
3. Trim and edit video
4. Add music, text, stickers
5. Write caption with hashtags/mentions
6. Post or save as draft
7. Background upload with progress tracking

### Nearby Discovery Flow
1. Enable location and Bluetooth
2. Open Nearby screen
3. Sonar radar shows nearby users
4. Send wave to connect
5. Match animation on mutual interest
6. Start chatting

---

## Performance Optimizations

- **Feed Caching**: Offline-first architecture
- **Intelligent Prefetching**: Predictive content loading
- **Image Optimization**: Cloudinary CDN with transformations
- **Video Compression**: Client-side compression before upload
- **Background Uploads**: Queue system for reliable uploads
- **Stream Management**: Proper disposal to prevent memory leaks
- **Widget Caching**: Reusable cached widgets
- **Lazy Loading**: Infinite scroll with pagination

---

## Analytics & Tracking

- **User Analytics**: Session tracking, user behavior
- **Content Analytics**: Post/reel performance metrics
- **Engagement Metrics**: Likes, comments, shares, views
- **Boost Analytics**: Promoted content performance
- **Page Analytics**: Business account insights
- **Ad Impressions**: Visibility tracking for ads

---

## Moderation & Safety

- **Content Reporting**: User-generated content flagging
- **User Reporting**: Report inappropriate behavior
- **Moderation Dashboard**: Admin tools for content review
- **Blocking System**: User blocking functionality
- **Privacy Controls**: Granular privacy settings
- **Firestore Security Rules**: Server-side data protection

---

## Future Roadmap Considerations

Based on the codebase structure:
- Audio merging/trimming (currently disabled due to FFmpegKit deprecation)
- Enhanced video editing capabilities
- Group chat functionality
- Live streaming
- Advanced gift trading mechanics
- NFT-style collectible gifts
- Enhanced AR filters for stories
- Voice/video calls

---

## Development Notes

- **Min SDK**: Android 21+
- **Environment Variables**: Stored in `.env` file
- **Code Quality**: flutter_lints, manual code review
- **Testing**: Widget tests, integration tests (in progress)
- **CI/CD**: Firebase deployment for Cloud Functions
- **Version**: 1.0.0+1

---

This documentation provides a comprehensive overview of Freegram's features and architecture. For technical implementation details, refer to the source code and inline documentation.
