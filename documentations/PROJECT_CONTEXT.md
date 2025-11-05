# Freegram Fresh Start - Complete Project Context

## Project Overview
**Freegram** is a Flutter-based social discovery app that enables users to discover and connect with people nearby using Bluetooth technology combined with Firebase backend services.

## Tech Stack

### Core Technologies
- **Flutter** (SDK >= 3.2.6 < 4.0.0)
- **Firebase** (Firestore, Auth, Messaging, Realtime Database)
- **BLoC** for state management
- **GetIt** for dependency injection
- **Hive** for local storage
- **Google Sign-In** & **Facebook Auth** for authentication

### Key Libraries
- `flutter_blue_plus` - Bluetooth LE scanning/advertising
- `cloudinary` - Image hosting
- `connectivity_plus` - Network monitoring
- `flutter_local_notifications` - Local notifications
- `google_mobile_ads` - Ad integration
- `in_app_purchase` - In-app purchases
- `country_picker` - Country selection
- `qr_flutter` - QR code generation

## Architecture

### Project Structure
```
lib/
├── main.dart                          # App entry point, initialization
├── locator.dart                       # Dependency injection setup
├── routes.dart                        # Legacy route constants
├── navigation/app_routes.dart        # Type-safe routing with arguments
│
├── blocs/                            # State management
│   ├── auth_bloc.dart                # Authentication state
│   ├── connectivity_bloc.dart        # Online/offline state
│   ├── profile_bloc.dart             # User profile updates
│   ├── friends_bloc/                 # Friends management
│   ├── nearby_bloc.dart              # Nearby user discovery
│   ├── nearby_chat_bloc.dart         # Bluetooth chat
│   └── notification_bloc/            # Notifications
│
├── repositories/                     # Data layer
│   ├── auth_repository.dart          # Firebase Auth, social sign-in
│   ├── user_repository.dart          # User CRUD, friends, matches
│   ├── chat_repository.dart          # Firestore chat management
│   ├── nearby_chat_repository.dart   # Bluetooth chat storage
│   ├── notification_repository.dart  # Push notifications
│   ├── action_queue_repository.dart  # Offline action queue
│   └── store_repository.dart         # In-app purchases
│
├── services/                         # Business logic
│   ├── sync_manager.dart             # Offline sync orchestration
│   ├── presence_manager.dart         # Online status tracking
│   ├── sonar/                        # Bluetooth discovery system
│   │   ├── sonar_controller.dart     # Main orchestrator
│   │   ├── bluetooth_discovery_service.dart  # BLE wrapper
│   │   ├── local_cache_service.dart  # Hive storage
│   │   ├── wave_service.dart         # Wave notifications
│   │   ├── notification_service.dart # Local notifications
│   │   ├── ble_scanner.dart          # BLE scanner
│   │   ├── ble_advertiser.dart       # BLE advertiser
│   │   └── bluetooth_service.dart    # Status management
│   ├── navigation_service.dart       # Screen navigation
│   ├── fcm_token_service.dart        # Push token management
│   ├── cloudinary_service.dart       # Image uploads
│   ├── cache_manager_service.dart    # Network cache
│   ├── friend_cache_service.dart     # Friend list caching
│   ├── friend_request_rate_limiter.dart
│   ├── friend_action_retry_service.dart
│   ├── network_quality_service.dart
│   └── loading_overlay_service.dart
│
├── models/                           # Data models
│   ├── user_model.dart               # Main user data
│   ├── message.dart                  # Chat messages
│   ├── nearby_message.dart           # Bluetooth messages
│   ├── notification_model.dart       # Notifications
│   └── hive/                         # Hive local models
│       ├── nearby_user.dart          # Discovered users (local)
│       ├── user_profile.dart         # Cached profiles
│       ├── wave_record.dart          # Pending waves
│       └── friend_request_record.dart
│
├── screens/                          # UI screens
│   ├── main_screen.dart              # Bottom nav container
│   ├── login_screen.dart             # Email/social login
│   ├── signup_screen.dart            # User registration
│   ├── onboarding_screen.dart        # App tutorial
│   ├── multi_step_onboarding_screen.dart  # Profile setup
│   ├── nearby_screen.dart            # Bluetooth discovery UI
│   ├── match_screen.dart             # Swipe/Match interface
│   ├── friends_list_screen.dart      # Friends & requests
│   ├── improved_chat_list_screen.dart     # Chat list
│   ├── improved_chat_screen.dart     # Individual chat
│   ├── nearby_chat_screen.dart       # Bluetooth chat
│   ├── profile_screen.dart           # View profiles
│   ├── edit_profile_screen.dart      # Edit profile
│   ├── settings_screen.dart          # App settings
│   ├── notifications_screen.dart     # Notification center
│   ├── menu_screen.dart              # Side menu
│   ├── store_screen.dart             # In-app purchases
│   └── qr_display_screen.dart        # QR code display
│
├── widgets/                          # Reusable components
│   ├── chat_widgets/                 # Chat-specific UI
│   │   ├── professional_message_bubble.dart
│   │   ├── message_reaction_display.dart
│   │   ├── professional_chat_list_item.dart
│   │   ├── enhanced_message_input.dart
│   │   ├── professional_presence_indicator.dart
│   │   ├── celebration_match_badge.dart
│   │   └── shimmer_chat_skeleton.dart
│   ├── sonar_view.dart               # Nearby discovery UI
│   ├── island_popup.dart             # FCM foreground notifications
│   ├── guided_overlay.dart           # User onboarding
│   ├── offline_overlay.dart          # Offline indicator
│   ├── professional_components.dart  # Common UI elements
│   └── responsive_system.dart        # Layout helpers
│
├── theme/                            # Theming
│   ├── app_theme.dart                # Material theme config
│   └── design_tokens.dart            # Design constants
│
└── utils/                            # Helpers & constants
    ├── app_constants.dart            # Global constants
    ├── auth_constants.dart           # Auth-related constants
    ├── auth_error_mapper.dart        # Error message mapping
    ├── chat_presence_constants.dart  # Presence configuration
    ├── friend_list_helpers.dart      # Friend utilities
    ├── match_screen_constants.dart   # Match screen config
    └── mutual_friends_helper.dart    # Mutual friends logic
```

## Core Features

### 1. Authentication System
**Files**: `lib/blocs/auth_bloc.dart`, `lib/repositories/auth_repository.dart`

- Email/password authentication
- Google Sign-In OAuth
- Facebook OAuth
- Password reset via email
- Secure user creation with Firestore
- FCM token management

**States**: `Authenticated`, `Unauthenticated`, `AuthLoading`, `AuthError`

### 2. User Discovery (Sonar System)
**Files**: `lib/services/sonar/`, `lib/screens/nearby_screen.dart`

**Architecture**:
- **SonarController**: Orchestrates entire discovery system
- **BluetoothDiscoveryService**: Manages BLE scanner/advertiser
- **LocalCacheService**: Stores discovered users in Hive
- **WaveService**: Handles wave notifications
- **NotificationService**: Shows local notifications

**Flow**:
1. User enables "Nearby" discovery
2. BLE scanner discovers nearby devices (uuidShort in advertisement)
3. Profile data fetched from Firestore via `uidShort`
4. User can send "wave" to discovered users
5. Waving triggers notification for recipient

**Key Features**:
- Auto-start on app launch
- Auto-pause on app background
- Foreground service for MIUI/Xiaomi devices
- Offline wave queue with sync
- Permissions management (location, BLE scan/advertise)

### 3. Friendship System
**Files**: `lib/repositories/user_repository.dart`, `lib/blocs/friends_bloc/`

- Send/accept/decline friend requests
- Block/unblock users
- Transaction-safe friend operations
- Rate limiting on friend requests
- Retry service for failed requests
- Offline queue support

**Types**:
- `contact_request` - Initial chat before accepting
- `friend_chat` - Full friend chat

### 4. Chat System
**Files**: `lib/repositories/chat_repository.dart`, `lib/screens/improved_chat_screen.dart`

**Features**:
- Real-time Firestore messaging
- Image support (via Cloudinary)
- Read receipts (`isSeen`, `isDelivered`)
- Typing indicators
- Message reactions
- Reply to messages
- Message editing
- Unread count tracking
- Pagination support

**Optimizations**:
- Optimistic UI updates
- Offline queue for messages
- Presence integration
- Professional UI with shimmer loading

### 5. Presence System
**Files**: `lib/services/presence_manager.dart`

**States**: `active`, `online`, `away`, `offline`

**Architecture**:
- Firebase Realtime Database for real-time updates
- Firestore for querying/persistence
- Heartbeat mechanism (30s intervals)
- App lifecycle integration
- Cached presence data
- Auto-offline on disconnect

### 6. Offline Sync System
**Files**: `lib/services/sync_manager.dart`

**Sync Queue Types**:
1. **Profile Sync**: Fetch Firestore profiles for discovered users
2. **Action Queue**: General offline actions (chat messages, etc.)
3. **Friend Requests**: Pending friend requests
4. **Waves**: Offline wave notifications

**Features**:
- Automatic retry on connectivity
- Permanent error detection
- Periodic sync checks
- Image pre-caching
- Batch processing with concurrency limits
- Debounced triggers

### 7. Push Notifications
**Files**: `lib/services/professional_notification_manager.dart`, `lib/services/fcm_*.dart`

**Types**:
- `newMessage` - Chat notifications
- `friendRequest` - Friend request notifications
- `requestAccepted` - Friend accepted
- `superLike` - Match notifications
- `nearbyWave` - Bluetooth wave notifications

**Behavior**:
- **Foreground**: Island popup (Android 13+ style)
- **Background/Terminated**: Rich local notifications
- Grouped notifications for multiple messages
- Navigation on tap
- Deep link support

### 8. Match/Swipe System
**Files**: `lib/screens/match_screen.dart`, `lib/repositories/user_repository.dart`

- Potential match discovery
- Swipe actions (Smash, Super Like, Pass)
- Match detection
- Super Like currency system
- Match animation screen

### 9. Profile Management
**Files**: `lib/blocs/profile_bloc.dart`, `lib/screens/edit_profile_screen.dart`

- Edit bio, age, country, gender
- Profile picture uploads (Cloudinary)
- Interest selection
- QR code generation/display
- Photo versioning for cache busting

### 10. In-App Purchases
**Files**: `lib/repositories/store_repository.dart`, `lib/services/in_app_purchase_service.dart`

- Coins purchase
- Super Like purchase
- Google Play IAP integration
- Purchase validation

## Data Flow Patterns

### Authentication Flow
```
LoginScreen → AuthBloc → AuthRepository → Firebase Auth
                                          ↓
                             Firestore User Creation
                                          ↓
                              AuthWrapper (StreamBuilder)
                                          ↓
                            MainScreen or Onboarding
```

### Nearby Discovery Flow
```
NearbyScreen → SonarController.startSonar()
                             ↓
         BluetoothDiscoveryService (BLE Scanner)
                             ↓
         Discovery Event (uuidShort found)
                             ↓
         LocalCacheService.storeNearbyUser()
                             ↓
         SyncManager triggers (if online)
                             ↓
         UserRepository.getUsersByUidShorts()
                             ↓
         UserProfile stored in Hive
                             ↓
         UI displays discovered user
```

### Chat Message Flow
```
ChatScreen → ChatRepository.sendMessage()
                      ↓
          Check connectivity
                      ↓
              [Offline] → ActionQueue
              [Online] → Firestore
                      ↓
         Firestore Cloud Messaging
                      ↓
         FCM → Recipient device
                      ↓
         Local notification (background)
         or Island popup (foreground)
```

### Friend Request Flow
```
FriendsScreen → UserRepository.sendFriendRequest()
                         ↓
            Transaction-safe update (both users)
                         ↓
            NotificationRepository.addNotification()
                         ↓
            Firebase Cloud Messaging
                         ↓
            Recipient notification
                         ↓
            Accept/Decline → UserRepository
```

## Offline Handling

### Queues
1. **ActionQueue** (`lib/repositories/action_queue_repository.dart`)
   - General actions (messages, etc.)
   - Processed by SyncManager

2. **LocalCache Queues** (Hive boxes)
   - Pending waves
   - Pending friend requests
   - Unsynced nearby users

3. **Sync Triggers**
   - App resume → Sync
   - Connectivity change → Sync
   - Periodic check (2 min intervals)

## Critical Implementation Details

### State Management
- **BLoC pattern** for reactive state
- **GetIt** for singleton services
- **StreamSubscription** cleanup in all BLoCs
- Equatable for state comparison

### Lifecycle Management
- `MainScreenWrapper` handles app lifecycle
- `PresenceManager` observes app state
- `SonarController` pauses/resumes on lifecycle
- Proper disposal in all streams

### Permissions
- Location (when in use)
- Bluetooth scan
- Bluetooth connect
- Bluetooth advertise
- Camera (profile pics)
- Storage (image picker)

### Connectivity
- `ConnectivityBloc` monitors network state
- Real internet check (not just WiFi connection)
- Offline overlay UI
- Bluetooth-only mode indicator

### Error Handling
- Try-catch blocks throughout
- Permanent vs temporary errors
- Retry logic with exponential backoff
- User-friendly error messages
- Firebase error mapping

### Performance Optimizations
- IndexedStack for tab navigation (preserves state)
- AutomaticKeepAliveClientMixin for screens
- Pagination for lists
- Image pre-caching
- Friend list caching
- Firestore query limits
- Batch Hive operations
- Concurrency limits

### Security
- Firebase Auth integration
- Firestore security rules
- FCM token refresh
- Cloudinary signed uploads
- Password hashing (Firebase)
- Blocked users filtering

## Environment Configuration

### .env File (Required)
```
FIREBASE_API_KEY=
FIREBASE_APP_ID=
GOOGLE_WEB_CLIENT_ID=
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
CLOUDINARY_UPLOAD_PRESET=
```

## Firebase Structure

### Collections
```
users/
  {uid}/
    - username, email, photoUrl
    - presence, lastSeen
    - friends[], friendRequestsSent[], friendRequestsReceived[]
    - blockedUsers[]
    - coins, superLikes
    - nearbyStatusMessage, nearbyStatusEmoji
    - sharedMusicTrack

chats/
  {chatId}/
    - users[], usernames{}, chatType
    - lastMessage, lastMessageTimestamp
    - unreadFor[], typingStatus{}
    - messages/ (subcollection)
      {messageId}/
        - text, imageUrl, senderId
        - timestamp, isSeen, isDelivered
        - reactions{}, edited
        - replyToMessageId, replyToMessageText

notifications/
  {userId}/
    {notificationId}/
      - type, fromUserId, message
      - read, timestamp

friendRequestMessages/
  {fromUserId}_{toUserId}/
    - fromUserId, toUserId, message

presence/ (Firebase Realtime Database)
  {userId}/
    - presence, state, lastSeen, lastHeartbeat
```

## Build Configuration

### Android
- Min SDK: 21
- Target SDK: 34
- Firebase configuration in `google-services.json`
- ProGuard rules in `proguard-rules.pro`
- Foreground service for BLE

### iOS
- Deployment target: 12.0
- Info.plist configured for BLE/location
- Firebase configuration

## Testing
- Unit tests: `test/` directory
- Widget tests available
- Integration testing patterns

## Known Issues & Solutions

### Logout Black Screen
**Issue**: Screen goes black on logout
**Solution**: Proper disposal in MainScreenWrapper, returning empty Scaffold

### MIUI Bluetooth Issues
**Solution**: Foreground service, custom permission dialogs

### Duplicate uidShort
**Warning**: Firestore may have duplicate short IDs (data integrity issue)
**Mitigation**: UI shows warning, first match used

### Profile Sync Race Conditions
**Solution**: Retry logic with delays, Stream timeout handling

## Future Enhancements
- Enhanced gamification (removed, can be re-added)
- Story/feed posts (removed, can be re-added)
- Video calling
- Group chats
- Polls/surveys in chats
- Advanced matching algorithms
- Push-to-talk voice messages

## Development Notes
- Debug logging throughout for troubleshooting
- Conditional compilation with `kDebugMode`
- Graceful degradation on errors
- Offline-first architecture
- Professional UI/UX patterns
- Accessibility considerations
- Responsive design

