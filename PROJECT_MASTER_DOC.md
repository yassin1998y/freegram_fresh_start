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
    *   "Random Chat" feature with WebRTC video calling (currently being debugged/refactored).
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

### Planned / In-Progress Features
*(Derived from `.plans/` directory)*

#### A. Gamification System Expansion (High Priority)
*   **Enhanced Store Catalog:** Expansion of coin packages, 20+ new animated gifts, and profile customization items (borders/badges). (*Status: Planned*)
*   **Daily Rewards:** Login streak system with increasing rewards (Coins, Super Likes, Gifts). (*Status: Planned*)
*   **Achievements & Quests:** System for tracking user milestones (e.g., "Big Spender", "Social Butterfly") with rewards. (*Status: Planned*)
*   **Referral System:** Unique codes, invite links, and dual-sided rewards. (*Status: Planned*)
*   **Transaction History:** Detailed logs of all economy actions. (*Status: Planned*)

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
*   **Active Issues:**
    *   **WebRTC/Random Chat:** Currently undergoing debugging for "Black Screen" connection issues. Recent fixes were applied to `RandomChatRepository` and `RandomChatScreen` lifecycle management.
    *   **FFmpeg Compatibility:** Note that extensive video editing features are planned but rely on `ffmpeg_kit_flutter`, which can significantly increase app size and requires careful configuration.
*   **Cleanup:** Redundant documentation files (`APP_OVERVIEW.md`, `.plans/*`) have been consolidated into this Master Document and removed.
