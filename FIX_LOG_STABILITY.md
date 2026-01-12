# Stability Fix Log

**Date:** 2026-01-12
**Status:** ✅ RESOLVED

## 1. Issue Description
**"Ghost Tasks" & Freezing:** The app was experiencing performance degradation and "freezes" caused by the `MainScreen` keeping heavy tabs (Random Chat Camera, Feed Videos) alive and active in the background using `IndexedStack` with `Visibility(maintainState: true)`.

## 2. Actions Taken

### A. Project Hygiene
*   **Deleted Junk Files:**
    *   `lib/routes.dart` (Deprecated)
    *   `lib/screens/feed/for_you_feed_tab.dart.backup`
    *   `lib/widgets/feed_widgets/post_card.dart.backup2`
    *   `lib/blocs/feed_bloc.dart.OLD`
*   **Import Verification:** Scanned for usage of `routes.dart` to ensure clean architecture.

### B. MainScreen Optimization
*   **Visibility Propagation:** Modified `MainScreen` to explicitly pass an `isVisible` boolean to its children (`FeedScreen`, `RandomChatScreen`).
*   **Logic:**
    *   `RandomChatScreen`: Pauses connection/searching when `isVisible` becomes `false`.
    *   `FeedScreen`: Propagates `isVisible` down the widget tree.

### C. Resource Management (Prop-Drilling)
To ensure video players pause correctly even when kept alive:
1.  **FeedScreen:** Accepts `isVisible` -> Passes to `ForYouFeedTab`.
2.  **ForYouFeedTab:** Accepts `isVisible` -> Passes to `PostCard`.
3.  **PostCard:** Accepts `isVisible` -> Passes to `PostMedia`.
4.  **PostMedia:** Accepts `isVisible` -> Passes to `PostVideoPlayer`.
5.  **PostVideoPlayer:** Monitors `isVisible`. If it becomes `false`, it immediately pauses the video controller.

### D. Build Fixes
*   **Resolved Variable Shadowing:** In `ForYouFeedTab`, a local variable named `widget` was preventing access to `state.widget.isVisible`. Renamed local variable to `contentWidget`.
*   **Fixed Duplications:** Removed accidental duplicate declaration of `_currentGift` in `RandomChatScreen`.
*   **Implemented Missing Logic:** Added missing `didUpdateWidget` override in `PostVideoPlayer`.

## 3. Result
*   **No Ghost Processes:** Camera and heavy video resources are now paused when switching tabs.
*   **Smoother UX:** Switching between Feed and other tabs no longer suffers from background resource contention.
