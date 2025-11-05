// lib/widgets/feed_widgets/suggestion_card.dart

import 'package:flutter/material.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/models/page_model.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/services/analytics_service.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SuggestionCardWidget extends StatelessWidget {
  final dynamic suggestion; // UserModel or PageModel
  final SuggestionType type;

  const SuggestionCardWidget({
    Key? key,
    required this.suggestion,
    required this.type,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = type == SuggestionType.friends;
    final name = isUser
        ? (suggestion as UserModel).username
        : (suggestion as PageModel).pageName;
    final avatarUrl = isUser
        ? (suggestion as UserModel).photoUrl
        : (suggestion as PageModel).profileImageUrl;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: DesignTokens.spaceXS),
      child: Container(
        width: 100,
        padding: EdgeInsets.all(DesignTokens.spaceSM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: DesignTokens.avatarSize / 2,
              backgroundImage: avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? Icon(
                      Icons.person,
                      size: DesignTokens.iconMD,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    )
                  : null,
            ),
            SizedBox(height: DesignTokens.spaceSM),
            Text(
              name,
              style: theme.textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: DesignTokens.spaceXS),
            Semantics(
              label: 'Follow ${name}',
              button: true,
              child: ElevatedButton(
                onPressed: () => _handleFollow(context),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMD,
                    vertical: DesignTokens.spaceXS,
                  ),
                  minimumSize: Size(80, DesignTokens.chipHeight),
                ),
                child: Text(
                  'Follow',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleFollow(BuildContext context) {
    final suggestionId = type == SuggestionType.friends
        ? (suggestion as UserModel).id
        : (suggestion as PageModel).pageId;
    final suggestionTypeStr = type == SuggestionType.friends ? 'user' : 'page';

    // Track follow action
    AnalyticsService().trackSuggestionFollow(suggestionId, suggestionTypeStr);
    debugPrint(
        '📊 Suggestion follow tracked: ID=$suggestionId, Type=$suggestionTypeStr');

    // TODO: Implement follow logic when suggestion system is complete
    debugPrint('Follow button tapped for suggestion');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Follow feature coming soon')),
    );
  }
}
