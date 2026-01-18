# Freegram - Project Master Document

## 1. Project Description

**Freegram** is a comprehensive social media platform built with Flutter (v3.2.6+) that combines traditional social networking features with innovative mechanics like virtual gifting, location-based discovery ("Sonar"), and rich multimedia content sharing (Reels, Stories).

*   **Platform:** Cross-platform (iOS, Android, Web, Desktop)
*   **Architecture:** Clean Architecture with BLoC Pattern
*   **Backend:** Firebase Ecosystem (Firestore, Auth, Storage, Functions, Realtime DB)
*   **State Management:** flutter_bloc
*   **Key Differentiator:** A gamified "Gifting Economy" and "Nearby Discovery" system.

---

## 2. Features

### Core Features (Implemented)
*   **Virtual Gifting System:**
    *   Virtual currency (Coins) and Marketplace.
    *   Animated gifts (Lottie) with rarity tiers (Common, Rare, Epic, Legendary).
    *   Gift sending in chat and on profiles.
    *   User inventory and gift history.
*   **Advanced Chat System:**
    *   Real-time 1-on-1 messaging (Firebase Realtime DB/Firestore).
    *   Rich media support (Images, Video, Audio, GIFs).
    *   "Random Chat" feature with "Azar-style" video discovery (swipe to skip).
    *   **3-State UI:** Searching, Connected, Peer Left states for seamless UX.
    *   **Safety Features:** Instant reporting (Nudity/Harassment/Spam) and blocking.
    *   **Monetization:** Filter locking (Gender/Region) behind a Paywall.
*   **Reels (Short-Form Video):**
    *   TikTok-style vertical feed.
    *   Video recording, basic trimming, and uploading.
    *   Engagement (Like, Comment, Share).
*   **Stories:**
    *   24-hour ephemeral content (Photo/Video/Text).
    *   Story tray with viewed/unviewed indicators.
*   **Social Networking:**
    *   Friend system (Request/Accept/Block).
    *   User Profiles with stats, posts, and gift showcases.
    *   Unified Feed with algorithmic ranking (basic implementation).
*   **Nearby Discovery:**
    *   Bluetooth Low Energy (BLE) & Geolocation based matching.
    *   "Sonar" radar visualization for nearby users.
*   **Pages (Business/Creator):**
    *   Separate entity for businesses/creators.
    *   Verification system with Admin approval (see Operations section).
*   **Gamification System (Expanded):**
    *   **Enhanced Store Catalog:** Expansion of coin packages, 20+ new animated gifts, and profile customization items. (Live)
    *   **Daily Rewards:** Login streak system with increasing rewards. (Implemented)
    *   **Achievements & Quests:** System for tracking user milestones (e.g., "Big Spender", "Social Butterfly") with rewards. (Implemented)
    *   **Referral System:** Unique codes, invite links, and dual-sided rewards. (Implemented)
    *   **Transaction History:** Detailed logs of all economy actions. (Implemented)

### Planned / In-Progress Features
*(Derived from `.plans/` directory)*

#### A. Phase 2: Unified Media Engine (Planned)
*   **Description:** Consolidate video compression, editing, and thumbnail generation into a single robust pipeline using Google-standard and LGPL-compliant tools.
*   **Target Stack:**
    *   **Playback:** `video_player` (Keep).
    *   **Engine:** `ffmpeg_kit_flutter_min` (LGPL version, replaces `video_compress`).
    *   **Editing UI:** `video_editor`.
*   **System Requirement:** Upgrade Android `minSdkVersion` to 24.

#### B. Reel Creation Improvements (Phase 2)
*   **Advanced Video Editing:** Precise timeline trimming, frame previews using `video_editor` package. (*Status: Planned*)
*   **Audio/Music Integration:** Music picker, audio mixing, and volume controls. (*Status: Planned*)
*   **Recording Enhancements:** Flash control, countdown timer, grid overlay, camera switching. (*Status: Planned*)
*   **Video Compression:** FFmpeg integration for optimized uploads (High/Medium/Low quality presets). (*Status: Planned*)

---

## 3. System Architecture

The project follows a modular **Clean Architecture** approach.

### Directory Structure
*   `lib/blocs`: Business Logic Components (State Management).
*   `lib/repositories`: Data abstraction layer (talking to Firebase/APIs).
*   `lib/services`: Feature-specific logic (e.g., `AudioService`, `BluetoothService`).
*   `lib/models`: Data models (Freezed/JSON Serializable).
*   `lib/screens`: UI screens grouped by feature.
*   `lib/widgets`: Reusable UI components.
*   `lib/utils`: Helpers and extensions.

### Key Technical Components
*   **State Management:** BLoC (Business Logic Component) is used strictly.
    *   Major BLoCs: `AuthBloc`, `ChatBloc`, `FeedBloc`, `ReelUploadBloc`.
*   **Dependency Injection:** `get_it` used in `lib/locator.dart` to manage singletons (Repositories, Services).
*   **Navigation:** Centralized `NavigationService` with named routes.
*   **Local Storage:** `Hive` (NoSQL) for heavy caching, `SharedPreferences` for flags.
*   **Media Handling:** Cloudinary (via `CloudinaryService`) for image optimization.

### Dependencies
*   **WebRTC:** `flutter_webrtc` for video calls (Random Chat).
*   **FFmpeg:** `ffmpeg_kit_flutter` (Note: Pending implementation for video editing).
*   **Firebase:** Heavily reliant on Firebase features.
*   **Socket.IO:** `socket_io_client` for real-time WebRTC signaling.

### WebRTC System Overhaul (2026-01-18)
The Random Chat system was completely rebuilt for stability.

**1. Signaling Server (`/signaling_server`):**
*   Node.js + Socket.IO server deployed on Google Cloud Run.
*   Handles `find_random_match` logic with queue management.
*   Supports Private Calls (`join_private_call`).

**2. WebRTC Service (`webrtc_service.dart`):**
*   **Codec Enforcement:** Forces VP8 codec to resolve one-way video issues.
*   **Race Guards:** Prevents duplicate offers/answers and signaling crashes (`InvalidStateError`).
*   **Watchdog Timer:** Auto-resets calls if connection hangs for >10s.
*   **Permissions:** Graceful handling of Cam/Mic denials.

**3. Random Chat UI (`random_chat_screen.dart`):**
*   **Smart Background:** Uses `AnimatedSwitcher` to transition between connection states.
*   **Visual Feedback:** "Pulse" avatar animation when searching or when remote video is off.
*   **Draggable Preview:** Local user video PiP is movable.
*   **Robust Image Handling:** Fallback components for 429 errors on avatar loading.

---

## 4. Deployment & Operations

### Page Verification System Setup
1.  **Cloud Functions:** Ensure `approvePageVerification` and `rejectPageVerification` are deployed.
2.  **SMTP Configuration:** Required for email notifications on verification status.
    *   Set Firebase Environment Variables: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`.
3.  **Admin Access:**
    *   Users must have `role: "admin"` or `isAdmin: true` in their Firestore `users/{uid}` document to approve requests.
    *   Action: Use Firestore Console or Admin SDK to promote users.

### Environment Variables
*   Managed via `.env` file (ensure this is not committed to public repos).

---

## 5. Diagnostic Summary (2026-01-12)

*   **Health:** The codebase is well-structured and follows consistent patterns.
*   **Recent Change Log / Stability Updates:**
    *   **Fixed:** Critical WebRTC Race Conditions & "Ghost" Offers (Signaling Guard implemented).
    *   **Fixed:** One-Way Video issues by enforcing VP8 Codec.
    *   **Fixed:** MainScreen "Ghost Task" freezing issue.
    *   **Overhaul:** Complete "Azar-style" Random Chat UI with 3-state logic (Searching/Connected/PeerLeft).
    *   **Added:** Safety Reporting & Filter Paywall in Random Chat.
    *   **Added:** Achievement Triggers (Post, Gift, Streak) & Profile Trophies UI.
    *   **Added:** Referral System Entry in Menu.
*   **Active Issues:**
    *   **FFmpeg Compatibility:** Planned Unified Media Engine will require careful configuration of `ffmpeg_kit_flutter` (LGPL) and bumping `minSdkVersion` to 24.
*   **Cleanup:** Redundant documentation files (`APP_OVERVIEW.md`, `.plans/*`) have been consolidated into this Master Document and removed.
