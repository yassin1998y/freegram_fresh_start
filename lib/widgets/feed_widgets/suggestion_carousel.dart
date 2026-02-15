// lib/widgets/feed_widgets/suggestion_carousel.dart

import 'package:flutter/material.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/models/page_model.dart';
import 'package:freegram/services/analytics_service.dart';
import 'package:freegram/widgets/feed_widgets/suggestion_card.dart';
import 'package:freegram/theme/design_tokens.dart';

class SuggestionCarouselWidget extends StatelessWidget {
  final SuggestionType type; // friends or pages
  final List<dynamic> suggestions; // List<UserModel> or List<PageModel>
  final VoidCallback? onDismiss;
  final List<String>? currentUserFriends; // For mutual friends calculation
  final List<String>? currentUserFriendRequestsSent; // For button state
  final VoidCallback? onRequestSent; // Callback when friend request is sent

  const SuggestionCarouselWidget({
    Key? key,
    required this.type,
    required this.suggestions,
    this.onDismiss,
    this.currentUserFriends,
    this.currentUserFriendRequestsSent,
    this.onRequestSent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Return empty widget if no suggestions
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: DesignTokens.spaceMD),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and dismiss button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMD,
              vertical: DesignTokens.spaceXS,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    type == SuggestionType.friends
                        ? 'People You May Know'
                        : 'Pages You Might Like',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: DesignTokens.iconMD,
                      color: theme.colorScheme.onSurface.withValues(alpha: 
                        DesignTokens.opacityMedium,
                      ),
                    ),
                    onPressed: () {
                      // Track dismissal
                      final suggestionTypeStr =
                          type == SuggestionType.friends ? 'friends' : 'pages';
                      AnalyticsService()
                          .trackSuggestionCarouselDismiss(suggestionTypeStr);
                      debugPrint(
                          '📊 Suggestion carousel dismissed: $suggestionTypeStr');
                      onDismiss?.call();
                    },
                    tooltip: 'Dismiss',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          // Horizontal list with improved spacing
          SizedBox(
            height: 160, // Increased height to accommodate mutual friends text
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceMD,
                vertical: DesignTokens.spaceSM,
              ),
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                return SuggestionCardWidget(
                  key: ValueKey(
                      '${type}_${suggestions[index] is UserModel ? (suggestions[index] as UserModel).id : (suggestions[index] as PageModel).pageId}'),
                  suggestion: suggestions[index],
                  type: type,
                  currentUserFriends: currentUserFriends,
                  currentUserFriendRequestsSent: currentUserFriendRequestsSent,
                  onRequestSent: onRequestSent,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
