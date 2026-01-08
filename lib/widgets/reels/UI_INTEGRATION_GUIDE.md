# UI Integration Guide

This guide shows how to add watch time tracking and feedback controls to the existing reels player.

## 1. Add Watch Time Tracking to ReelsPlayerWidget

### Step 1: Add tracker instance to state
```dart
// In _ReelsPlayerWidgetState class
ReelWatchTimeTracker? _watchTimeTracker;
```

### Step 2: Initialize tracker in initState
```dart
@override
void initState() {
  super.initState();
  // ... existing code ...
  
  // Initialize watch time tracker
  _watchTimeTracker = ReelWatchTimeTracker(
    reelId: widget.reel.reelId,
    duration: widget.reel.duration.toDouble(),
    onWatchTimeUpdate: (watchTime, watchPercentage) {
      // Record watch time periodically
      context.read<ReelsFeedBloc>().add(RecordWatchTime(
        reelId: widget.reel.reelId,
        watchTime: watchTime,
        watchPercentage: watchPercentage,
      ));
    },
    onCompleted: () {
      // Mark reel as completed
      context.read<ReelsFeedBloc>().add(MarkReelCompleted(widget.reel.reelId));
    },
    onSkipped: () {
      // Mark reel as skipped
      context.read<ReelsFeedBloc>().add(MarkReelSkipped(widget.reel.reelId));
    },
  );
  _watchTimeTracker?.start();
}
```

### Step 3: Update tracker position in _videoListener
```dart
void _videoListener() {
  // ... existing code ...
  
  // Update watch time tracker with current position
  if (_videoController != null && _videoController!.value.isInitialized) {
    final position = _videoController!.value.position.inSeconds.toDouble();
    _watchTimeTracker?.updatePosition(position);
  }
}
```

### Step 4: Dispose tracker
```dart
@override
void dispose() {
  _watchTimeTracker?.dispose();
  // ... existing code ...
  super.dispose();
}
```

## 2. Add "Not Interested" Button to ReelsVideoUIOverlay

### Step 1: Add menu button to overlay
```dart
// In ReelsVideoUIOverlay widget, add to the action buttons column:
IconButton(
  icon: const Icon(Icons.more_vert),
  color: Colors.white,
  onPressed: () => _showFeedbackMenu(context),
),
```

### Step 2: Implement feedback menu
```dart
void _showFeedbackMenu(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.not_interested, color: Colors.white),
            title: const Text('Not Interested', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              ReelsUIHelpers.showFeedbackDialog(
                context: context,
                reelId: reel.reelId,
                creatorId: reel.uploaderId,
                creatorName: reel.uploaderUsername,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.report, color: Colors.white),
            title: const Text('Report', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              // Handle report
            },
          ),
        ],
      ),
    ),
  );
}
```

## 3. Alternative: Quick "Not Interested" Button

For a simpler implementation, add a swipe-down gesture or long-press:

```dart
// In ReelsPlayerWidget, wrap the video player with GestureDetector:
GestureDetector(
  onLongPress: () {
    ReelsUIHelpers.showFeedbackDialog(
      context: context,
      reelId: widget.reel.reelId,
      creatorId: widget.reel.uploaderId,
      creatorName: widget.reel.uploaderUsername,
    );
  },
  child: VideoPlayer(_videoController!),
)
```

## 4. Show Recommendation Reasons (Optional)

Add a small indicator showing why this reel was recommended:

```dart
// In ReelsVideoUIOverlay, add near the bottom:
Positioned(
  bottom: 100,
  left: 16,
  child: ReelsUIHelpers.buildRecommendationReason(
    reason: 'Based on your interests',
    icon: Icons.star,
  ),
)
```

## Summary

These integrations are **optional** but will significantly improve the user experience:

- **Watch Time Tracking**: Provides valuable engagement data for the algorithm
- **Not Interested Button**: Allows users to filter out unwanted content
- **Recommendation Reasons**: Increases transparency and trust

All the helper methods and dialogs are already implemented and ready to use!
