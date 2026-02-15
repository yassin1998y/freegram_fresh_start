// lib/widgets/feed_widgets/suggestion_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/models/page_model.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/services/analytics_service.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/repositories/page_repository.dart';
import 'package:freegram/repositories/friend_repository.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/utils/mutual_friends_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SuggestionCardWidget extends StatefulWidget {
  final dynamic suggestion; // UserModel or PageModel
  final SuggestionType type;
  final List<String>? currentUserFriends; // For mutual friends calculation
  final List<String>?
      currentUserFriendRequestsSent; // For checking if request already sent
  final VoidCallback? onRequestSent; // Callback when friend request is sent

  const SuggestionCardWidget({
    Key? key,
    required this.suggestion,
    required this.type,
    this.currentUserFriends,
    this.currentUserFriendRequestsSent,
    this.onRequestSent,
  }) : super(key: key);

  @override
  State<SuggestionCardWidget> createState() => _SuggestionCardWidgetState();
}

class _SuggestionCardWidgetState extends State<SuggestionCardWidget> {
  // Track loading state for optimistic UI updates
  bool _isLoading = false;
  // Track locally sent requests (for immediate feedback before data syncs)
  final Set<String> _locallySentRequests = <String>{};

  // Check if request was sent (from data or local state)
  bool _isRequestSent(String? userId) {
    if (userId == null || widget.type != SuggestionType.friends) {
      return false;
    }
    // Check actual data first (source of truth) - this persists across scrolls
    final requestsSent = widget.currentUserFriendRequestsSent ?? [];
    if (requestsSent.contains(userId)) {
      return true;
    }
    // Then check local state (for immediate feedback during the same widget lifecycle)
    return _locallySentRequests.contains(userId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = widget.type == SuggestionType.friends;
    final user = isUser ? (widget.suggestion as UserModel) : null;
    final page = !isUser ? (widget.suggestion as PageModel) : null;
    final name = isUser ? user!.username : page!.pageName;
    final avatarUrl = isUser ? user!.photoUrl : page!.profileImageUrl;
    final userId = isUser ? user!.id : null;

    // Calculate mutual friends count for friends suggestions
    int? mutualFriendsCount;
    if (isUser && widget.currentUserFriends != null && user != null) {
      mutualFriendsCount = MutualFriendsHelper.getMutualFriendsCount(
        widget.currentUserFriends!,
        user.friends,
      );
    }

    return Container(
      width: 110,
      margin: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceXS),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          onTap: () => _navigateToProfile(userId),
          child: Container(
            padding: const EdgeInsets.all(DesignTokens.spaceSM),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: DesignTokens.elevation1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar with optional border
                GestureDetector(
                  onTap: () => _navigateToProfile(userId),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: AvatarSize.medium.radius,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      backgroundImage: avatarUrl.isNotEmpty
                          ? CachedNetworkImageProvider(avatarUrl)
                          : null,
                      child: avatarUrl.isEmpty
                          ? Icon(
                              Icons.person,
                              size: DesignTokens.iconMD,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: DesignTokens.opacityMedium,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceSM),
                // Username
                Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: DesignTokens.fontSizeSM,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                // Mutual friends count
                if (mutualFriendsCount != null && mutualFriendsCount > 0) ...[
                  const SizedBox(height: DesignTokens.spaceXS),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: DesignTokens.iconXS,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: DesignTokens.opacityMedium,
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spaceXS / 2),
                      Flexible(
                        child: Text(
                          MutualFriendsHelper.formatMutualFriendsText(
                              mutualFriendsCount),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: DesignTokens.opacityMedium,
                            ),
                            fontSize: DesignTokens.fontSizeXS,
                            height: DesignTokens.lineHeightTight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: DesignTokens.spaceSM),
                // Action button
                Semantics(
                  label: isUser
                      ? (_isRequestSent(userId)
                          ? 'Friend request sent to $name'
                          : 'Add Friend $name')
                      : 'Follow $name',
                  button: true,
                  child: _buildActionButton(theme, isUser, name, userId),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    ThemeData theme,
    bool isUser,
    String name,
    String? userId,
  ) {
    // Determine button state - check from data source, not just state
    final bool isRequestSentState = isUser && _isRequestSent(userId);
    final bool isDisabled = isRequestSentState || _isLoading;
    final String buttonText = _isLoading
        ? 'Sending...'
        : isUser
            ? (_isRequestSent(userId) ? 'Sent' : 'Add Friend')
            : 'Follow';

    // Use different styling for sent state - subtle success color
    final backgroundColor = isRequestSentState
        ? SonarPulseTheme.primaryAccent.withValues(alpha: 0.2)
        : (_isLoading
            ? SonarPulseTheme.primaryAccent.withValues(alpha: 0.7)
            : SonarPulseTheme.primaryAccent);

    final textColor =
        isRequestSentState ? SonarPulseTheme.primaryAccent : Colors.white;

    return SizedBox(
      width: double.infinity,
      height: DesignTokens.buttonHeight * 0.6, // Smaller button for card
      child: ElevatedButton(
        onPressed: isDisabled
            ? null
            : () {
                HapticFeedback.lightImpact();
                // Handle action without triggering card tap
                _handleAction(userId);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          disabledBackgroundColor: backgroundColor,
          disabledForegroundColor: textColor,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceSM,
            vertical: DesignTokens.spaceXS,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
            side: isRequestSentState
                ? BorderSide(
                    color: SonarPulseTheme.primaryAccent.withValues(alpha: 0.3),
                    width: 1,
                  )
                : BorderSide.none,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isRequestSent(userId) && isUser) ...[
                    Icon(
                      Icons.check_circle_outline,
                      size: DesignTokens.iconXS,
                      color: textColor,
                    ),
                    const SizedBox(width: DesignTokens.spaceXS / 2),
                  ],
                  Flexible(
                    child: Text(
                      buttonText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: DesignTokens.fontSizeXS,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _navigateToProfile(String? userId) {
    if (userId == null) return;

    HapticFeedback.lightImpact();
    locator<NavigationService>().navigateTo(
      ProfileScreen(userId: userId),
      transition: PageTransition.slide,
    );
  }

  void _handleAction(String? userId) {
    final suggestionId = widget.type == SuggestionType.friends
        ? (widget.suggestion as UserModel).id
        : (widget.suggestion as PageModel).pageId;
    final suggestionTypeStr =
        widget.type == SuggestionType.friends ? 'user' : 'page';

    // Track action
    AnalyticsService().trackSuggestionFollow(suggestionId, suggestionTypeStr);
    debugPrint(
        '📊 Suggestion action tracked: ID=$suggestionId, Type=$suggestionTypeStr');

    if (widget.type == SuggestionType.friends) {
      // Handle Add Friend - send friend request
      _handleAddFriend(suggestionId);
    } else {
      // Handle Follow Page
      _handleFollowPage(suggestionId);
    }
  }

  Future<void> _handleAddFriend(String userId) async {
    // Don't send if already sent (check both local and data state)
    if (_isRequestSent(userId)) {
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('You must be logged in to send friend requests'),
            backgroundColor: SonarPulseTheme.darkError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Optimistic update - add to local set immediately for instant feedback
    setState(() {
      _isLoading = true;
      _locallySentRequests.add(userId);
    });

    try {
      final friendRepository = locator<FriendRepository>();
      await friendRepository.sendFriendRequest(currentUser.uid, userId);

      // Success - clear loading, refresh user data to get updated friendRequestsSent
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Keep userId in _locallySentRequests for immediate UI feedback
          // The actual data will be refreshed from the parent
        });

        // Notify parent to refresh user data
        widget.onRequestSent?.call();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Friend request sent!'),
            backgroundColor: SonarPulseTheme.primaryAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      if (mounted) {
        // Remove from local set on error (unless it was already sent)
        final errorStr = e.toString().toLowerCase();
        final wasAlreadySent = errorStr.contains('request already sent') ||
            errorStr.contains('already sent');

        setState(() {
          _isLoading = false;
          // Only remove from local set if it wasn't already sent
          if (!wasAlreadySent) {
            _locallySentRequests.remove(userId);
          }
        });

        // Parse error message for user-friendly display
        String errorMessage = 'Failed to send friend request';
        if (errorStr.contains('already friends')) {
          errorMessage = 'You are already friends with this user';
        } else if (wasAlreadySent) {
          errorMessage = 'Friend request already sent';
          // Keep it in local set since it was actually sent
        } else if (errorStr.contains('blocked')) {
          errorMessage = 'Cannot send request to this user';
        } else if (errorStr.contains('not found')) {
          errorMessage = 'User not found';
        } else if (errorStr.contains('network') ||
            errorStr.contains('connection')) {
          errorMessage = 'Network error. Please try again';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: SonarPulseTheme.darkError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handleFollowPage(String pageId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('You must be logged in to follow pages'),
              backgroundColor: SonarPulseTheme.darkError,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final pageRepository = locator<PageRepository>();
      await pageRepository.followPage(pageId, currentUser.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Page followed!'),
            backgroundColor: SonarPulseTheme.primaryAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error following page: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to follow page: $e'),
            backgroundColor: SonarPulseTheme.darkError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
