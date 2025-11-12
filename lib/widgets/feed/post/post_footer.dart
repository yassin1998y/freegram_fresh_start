// lib/widgets/feed/post/post_footer.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/feed_widgets/liked_by_list.dart';
import 'package:freegram/services/mention_service.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/hashtag_explore_screen.dart';
import 'package:freegram/screens/profile_screen.dart';

/// Post footer component (engagement stats and caption)
///
/// Features:
/// - Likes and comments count
/// - Expandable caption with mentions and hashtags
/// - Uses DesignTokens for spacing
class PostFooter extends StatefulWidget {
  final PostModel post;
  final int reactionCount; // Use local count for optimistic updates
  final bool showCaption; // Whether to show caption (moved to top in PostCard)
  final VoidCallback? onBoostTap; // Boost button callback
  final VoidCallback? onInsightsTap; // Insights button callback

  const PostFooter({
    super.key,
    required this.post,
    required this.reactionCount,
    this.showCaption = true, // Default to true for backward compatibility
    this.onBoostTap,
    this.onInsightsTap,
  });

  @override
  State<PostFooter> createState() => _PostFooterState();
}

class _PostFooterState extends State<PostFooter> {
  bool _isCaptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEngagement =
        widget.reactionCount > 0 || widget.post.commentCount > 0;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUserId == widget.post.authorId;

    // Build boost/insights button for post owner
    Widget? boostButton;
    if (isOwner) {
      final isBoosted = widget.post.isBoosted &&
          widget.post.boostEndTime != null &&
          widget.post.boostEndTime!.toDate().isAfter(DateTime.now());

      if (isBoosted) {
        boostButton = TextButton.icon(
          onPressed: widget.onInsightsTap,
          icon: Icon(
            Icons.insights,
            size: DesignTokens.iconSM,
            color: theme.colorScheme.primary,
          ),
          label: Text(
            'View Insights',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            padding: EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceSM,
              vertical: DesignTokens.spaceXS,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      } else {
        boostButton = TextButton.icon(
          onPressed: widget.onBoostTap,
          icon: Icon(
            Icons.trending_up,
            size: DesignTokens.iconSM,
            color: theme.colorScheme.primary,
          ),
          label: Text(
            'Boost',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            padding: EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceSM,
              vertical: DesignTokens.spaceXS,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Engagement section (Likes count, comments) with Boost button on right
        if (hasEngagement || boostButton != null)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMD,
              vertical: DesignTokens.spaceXS,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side: Likes and comments
                if (hasEngagement)
                  Row(
                    children: [
                      if (widget.reactionCount > 0)
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => LikedByList(
                                postId: widget.post.id,
                                totalLikes: widget.reactionCount,
                              ),
                            );
                          },
                          child: Text(
                            '${widget.reactionCount} ${widget.reactionCount == 1 ? 'like' : 'likes'}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                DesignTokens.opacityMedium,
                              ),
                            ),
                          ),
                        ),
                      if (widget.reactionCount > 0 &&
                          widget.post.commentCount > 0)
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceSM),
                          child: Text(
                            '•',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                DesignTokens.opacityMedium,
                              ),
                            ),
                          ),
                        ),
                      if (widget.post.commentCount > 0)
                        Text(
                          '${widget.post.commentCount} ${widget.post.commentCount == 1 ? 'comment' : 'comments'}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(
                              DesignTokens.opacityMedium,
                            ),
                          ),
                        ),
                    ],
                  ),
                // Right side: Boost/Insights button (opposite to likes/comments)
                if (boostButton != null) boostButton,
              ],
            ),
          ),

        // Caption section (only if showCaption is true)
        if (widget.showCaption && widget.post.content.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
            child: _buildCaption(context),
          ),

        // Hashtags section
        if (widget.post.hashtags.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMD,
              vertical: DesignTokens.spaceSM,
            ),
            child: Wrap(
              spacing: DesignTokens.spaceSM,
              children: widget.post.hashtags.map((tag) {
                final normalizedTag =
                    tag.startsWith('#') ? tag.substring(1) : tag;
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HashtagExploreScreen(
                          hashtag: normalizedTag,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
                  child: Chip(
                    label: Text(
                      '#$normalizedTag',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCaption(BuildContext context) {
    final theme = Theme.of(context);
    final mentionService = locator<MentionService>();

    final spans = mentionService.formatTextWithMentionsAndHashtags(
      widget.post.content,
      defaultStyle: theme.textTheme.bodyMedium?.copyWith(
        height: 1.4,
      ),
      mentionStyle: theme.textTheme.bodyMedium?.copyWith(
        height: 1.4,
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w500,
      ),
      hashtagStyle: theme.textTheme.bodyMedium?.copyWith(
        height: 1.4,
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w500,
      ),
      onHashtagTap: (hashtag) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HashtagExploreScreen(hashtag: hashtag),
          ),
        );
      },
      onMentionTap: (username) async {
        final userRepository = locator<UserRepository>();
        final user = await userRepository.getUserByUsername(username);
        if (user != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: user.id),
            ),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User @$username not found')),
          );
        }
      },
    );

    // Check if caption needs expansion
    final textPainter = TextPainter(
      text: TextSpan(
        text: widget.post.content,
        style: theme.textTheme.bodyMedium,
      ),
      maxLines: 2,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: MediaQuery.of(context).size.width - 32);
    final needsExpansion = textPainter.didExceedMaxLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(children: spans),
          maxLines: _isCaptionExpanded ? null : 2,
          overflow:
              _isCaptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (needsExpansion && !_isCaptionExpanded)
          GestureDetector(
            onTap: () {
              setState(() => _isCaptionExpanded = true);
            },
            child: Padding(
              padding: EdgeInsets.only(top: DesignTokens.spaceXS),
              child: Text(
                'more',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(
                    DesignTokens.opacityMedium,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
