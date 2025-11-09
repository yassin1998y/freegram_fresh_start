// lib/widgets/feed_widgets/suggestion_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/models/page_model.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/services/analytics_service.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart';
import 'package:freegram/repositories/page_repository.dart';
import 'package:freegram/locator.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    
    // TODO: Calculate and show mutual friends count for friends suggestions

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceXS),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(DesignTokens.spaceSM),
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
            const SizedBox(height: DesignTokens.spaceSM),
            Text(
              name,
              style: theme.textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            // TODO: Show mutual friends count when available
            // if (mutualFriendsCount != null && mutualFriendsCount > 0) ...[
            //   const SizedBox(height: DesignTokens.spaceXS / 2),
            //   Text(
            //     MutualFriendsHelper.formatMutualFriendsText(mutualFriendsCount),
            //     style: theme.textTheme.bodySmall?.copyWith(
            //       color: theme.colorScheme.onSurface.withOpacity(0.6),
            //       fontSize: 10,
            //     ),
            //     maxLines: 1,
            //     overflow: TextOverflow.ellipsis,
            //     textAlign: TextAlign.center,
            //   ),
            // ],
            const SizedBox(height: DesignTokens.spaceXS),
            Semantics(
              label: isUser ? 'Add Friend $name' : 'Follow $name',
              button: true,
              child: ElevatedButton(
                onPressed: () => _handleAction(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMD,
                    vertical: DesignTokens.spaceXS,
                  ),
                  minimumSize: const Size(80, DesignTokens.chipHeight),
                ),
                child: Text(
                  isUser ? 'Add Friend' : 'Follow',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context) {
    final suggestionId = type == SuggestionType.friends
        ? (suggestion as UserModel).id
        : (suggestion as PageModel).pageId;
    final suggestionTypeStr = type == SuggestionType.friends ? 'user' : 'page';

    // Track action
    AnalyticsService().trackSuggestionFollow(suggestionId, suggestionTypeStr);
    debugPrint(
        '📊 Suggestion action tracked: ID=$suggestionId, Type=$suggestionTypeStr');

    if (type == SuggestionType.friends) {
      // Handle Add Friend - send friend request
      _handleAddFriend(context, suggestionId);
    } else {
      // Handle Follow Page
      _handleFollowPage(context, suggestionId);
    }
  }

  void _handleAddFriend(BuildContext context, String userId) {
    try {
      // Get FriendsBloc from context or create if not available
      final friendsBloc = context.read<FriendsBloc>();
      friendsBloc.add(SendFriendRequest(userId));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request sent!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send friend request: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleFollowPage(BuildContext context, String pageId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to follow pages')),
        );
        return;
      }

      final pageRepository = locator<PageRepository>();
      await pageRepository.followPage(pageId, currentUser.uid);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Page followed!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error following page: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to follow page: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
