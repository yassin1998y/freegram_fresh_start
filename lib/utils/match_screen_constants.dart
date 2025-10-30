import 'package:flutter/material.dart';

/// Constants for Match Screen
///
/// Centralized configuration for all magic numbers, sizes, and timings
/// used in the match screen to improve maintainability and consistency.

class MatchScreenConstants {
  // Private constructor to prevent instantiation
  MatchScreenConstants._();

  // ========== ACTION BUTTON SIZES ==========
  static const double buttonSizeUndo = 50.0;
  static const double buttonSizePass = 60.0;
  static const double buttonSizeSuperLike = 70.0;
  static const double buttonSizeLike = 60.0;
  static const double buttonSizeInfo = 50.0;

  static const double iconSizeUndo = 22.0;
  static const double iconSizePass = 28.0;
  static const double iconSizeSuperLike = 34.0;
  static const double iconSizeLike = 28.0;
  static const double iconSizeInfo = 22.0;

  // ========== BUTTON SPACING & PADDING ==========
  static const double actionButtonRowPaddingHorizontal = 12.0;
  static const double actionButtonRowPaddingVertical = 8.0;
  static const double actionButtonRowPaddingBottom = 8.0;
  static const double actionButtonRowPaddingTop = 8.0;

  // ========== CARD STACK CONFIGURATION ==========
  static const int maxVisibleCards = 5;
  static const double cardStackVerticalOffset = 6.0;
  static const double cardStackScaleFactor = 0.03;
  static const double cardStackOpacityFactor = 0.15;
  static const double cardPaddingHorizontal = 12.0;
  static const double cardPaddingTop = 0.0;
  static const double cardPaddingBottom = 8.0;

  // ========== UNDO STACK CONFIGURATION ==========
  static const int maxUndoStackSize = 5;

  // ========== AD CONFIGURATION ==========
  static const int adFrequency = 5; // Show ad every N cards
  static const int adPreloadSwipeCount = 3; // Preload ad every N swipes
  static const int adCooldownSeconds = 300; // 5 minutes

  // ========== PROGRESS INDICATOR ==========
  static const double progressIndicatorPaddingHorizontal = 20.0;
  static const double progressIndicatorPaddingVertical = 12.0;
  static const double progressIndicatorHeight = 4.0;
  static const double progressIndicatorRadius = 10.0;
  static const double progressTextSpacing = 12.0;
  static const double progressTextFontSize = 13.0;

  // ========== ANIMATION DURATIONS ==========
  static const Duration buttonAnimationDuration = Duration(milliseconds: 150);
  static const Duration cardSwipeAnimationDuration =
      Duration(milliseconds: 300);
  static const Duration celebrationDuration = Duration(milliseconds: 600);
  static const Duration celebrationDisplayDuration =
      Duration(milliseconds: 1500);
  static const Duration snackBarDuration = Duration(seconds: 2);
  static const Duration undoSnackBarDuration = Duration(seconds: 1);

  // ========== HAPTIC FEEDBACK DELAYS ==========
  static const Duration hapticCelebrationDelay1 = Duration(milliseconds: 100);
  static const Duration hapticCelebrationDelay2 = Duration(milliseconds: 200);

  // ========== LOADING & ERROR STATES ==========
  static const double loadingSkeletonRadius = 20.0;
  static const double loadingIndicatorStrokeWidth = 3.0;
  static const double loadingTextFontSize = 16.0;
  static const double loadingTextSpacing = 24.0;

  static const double errorIconSize = 60.0;
  static const double errorIconPadding = 20.0;
  static const double errorTitleFontSize = 18.0;
  static const double errorMessageFontSize = 14.0;
  static const double errorSpacing = 24.0;
  static const double errorButtonPaddingHorizontal = 32.0;
  static const double errorButtonPaddingVertical = 16.0;
  static const double errorButtonRadius = 30.0;

  // ========== EMPTY STATE ==========
  static const double emptyStateIconSize = 80.0;
  static const double emptyStateIconPadding = 24.0;
  static const double emptyStateTitleFontSize = 22.0;
  static const double emptyStateMessageFontSize = 15.0;
  static const double emptyStateSpacing = 24.0;
  static const double emptyStateButtonPaddingHorizontal = 32.0;
  static const double emptyStateButtonPaddingVertical = 16.0;
  static const double emptyStateButtonRadius = 30.0;

  // ========== SKELETON LOADING ==========
  static const double skeletonButtonSize1 = 50.0;
  static const double skeletonButtonSize2 = 70.0;
  static const double skeletonButtonSize3 = 50.0;
  static const double skeletonSpacing = 24.0;

  // ========== AD LOADING INDICATOR ==========
  static const double adLoadingIndicatorTop = 50.0;
  static const double adLoadingIndicatorRight = 20.0;
  static const double adLoadingIndicatorPadding = 8.0;
  static const double adLoadingIndicatorRadius = 20.0;
  static const double adLoadingIndicatorSize = 12.0;
  static const double adLoadingIndicatorStrokeWidth = 2.0;
  static const double adLoadingTextSpacing = 6.0;
  static const double adLoadingTextFontSize = 11.0;

  // ========== SAFE AREA PADDING ==========
  static const double safeAreaPaddingWithBottom = 8.0;
  static const double safeAreaPaddingDefault = 16.0;

  // ========== CELEBRATION DIALOG ==========
  static const double celebrationDialogHorizontalMargin = 40.0;
  static const double celebrationDialogPadding = 32.0;
  static const double celebrationDialogRadius = 24.0;
  static const double celebrationIconPadding = 20.0;
  static const double celebrationIconSize = 60.0;
  static const double celebrationTitleFontSize = 28.0;
  static const double celebrationSubtitleFontSize = 20.0;
  static const double celebrationBadgePaddingHorizontal = 16.0;
  static const double celebrationBadgePaddingVertical = 8.0;
  static const double celebrationBadgeRadius = 20.0;
  static const double celebrationBadgeIconSize = 20.0;
  static const double celebrationBadgeFontSize = 14.0;

  // ========== REWARD SNACKBAR ==========
  static const double rewardSnackBarIconSize = 24.0;
  static const double rewardSnackBarIconSpacing = 12.0;
  static const double rewardSnackBarFontSize = 16.0;
  static const double rewardSnackBarRadius = 12.0;
  static const double rewardSnackBarMargin = 16.0;

  // ========== OUT OF SUPER LIKES DIALOG ==========
  static const double superLikesDialogRadius = 20.0;
  static const double superLikesDialogIconSize = 28.0;
  static const double superLikesDialogIconSpacing = 8.0;
  static const double superLikesDialogMessageFontSize = 15.0;
  static const double superLikesDialogAdContainerPadding = 12.0;
  static const double superLikesDialogAdContainerRadius = 12.0;
  static const double superLikesDialogAdIconSize = 28.0;
  static const double superLikesDialogAdIconSpacing = 12.0;
  static const double superLikesDialogAdFontSize = 13.0;
  static const double superLikesDialogButtonIconSize = 20.0;
  static const double superLikesDialogButtonRadius = 12.0;
  static const double superLikesDialogLoadingIndicatorSize = 16.0;
  static const double superLikesDialogLoadingIndicatorStrokeWidth = 2.0;

  // ========== DEBOUNCE DURATIONS ==========
  static const Duration buttonDebounceDuration = Duration(milliseconds: 500);
  static const Duration swipeDebounceDuration = Duration(milliseconds: 300);

  // ========== COLORS (Action Buttons) ==========
  // These complement the theme colors
  static const Color undoColor = Color(0xFFFF9800); // Orange
  static const Color passColor = Color(0xFFE91E63); // Pink/Red
  static const Color superLikeColor = Color(0xFF2196F3); // Blue
  static const Color likeColor = Color(0xFF4CAF50); // Green
  static const Color infoColor = Color(0xFF9C27B0); // Purple

  // ========== BUTTON LABELS ==========
  static const String labelUndo = 'Undo';
  static const String labelPass = 'Pass';
  static const String labelSuperLike = 'Super';
  static const String labelLike = 'Like';
  static const String labelInfo = 'Info';

  // ========== TOOLTIPS ==========
  static const String tooltipUndo = 'Undo last swipe';
  static const String tooltipPass = 'Pass';
  static const String tooltipSuperLike = 'Super Like';
  static const String tooltipLike = 'Like';
  static const String tooltipInfo = 'View profile details';
  static const String tooltipOutOfSuperLikes = 'Out of Super Likes';

  // ========== ACCESSIBILITY ==========
  static const double minTouchTargetSize = 56.0;
  static const String semanticLabelCardStack = 'Swipeable profile cards';
  static const String semanticLabelActionButtons = 'Match action buttons';
  static const String semanticHintSwipeLeft = 'Swipe left to pass';
  static const String semanticHintSwipeRight = 'Swipe right to like';
  static const String semanticHintSwipeUp = 'Swipe up to super like';
}
