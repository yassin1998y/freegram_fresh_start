// lib/widgets/feed_widgets/suggestion_carousel.dart

import 'package:flutter/material.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/services/analytics_service.dart';
import 'package:freegram/widgets/feed_widgets/suggestion_card.dart';
import 'package:freegram/theme/design_tokens.dart';

class SuggestionCarouselWidget extends StatelessWidget {
  final SuggestionType type; // friends or pages
  final List<dynamic> suggestions; // List<UserModel> or List<PageModel>
  final VoidCallback? onDismiss;

  const SuggestionCarouselWidget({
    Key? key,
    required this.type,
    required this.suggestions,
    this.onDismiss,
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
            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    type == SuggestionType.friends
                        ? 'People You May Know'
                        : 'Pages You Might Like',
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: DesignTokens.iconSM,
                      color: theme.iconTheme.color,
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
                  ),
              ],
            ),
          ),
          // Horizontal list
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceSM),
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                return SuggestionCardWidget(
                  suggestion: suggestions[index],
                  type: type,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
