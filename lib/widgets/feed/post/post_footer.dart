// lib/widgets/feed/post/post_footer.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/theme/design_tokens.dart';
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
  final bool isTextOnly; // Whether the post is text-only
  final VoidCallback? onBoostTap; // Boost button callback
  final VoidCallback? onInsightsTap; // Insights button callback

  const PostFooter({
    super.key,
    required this.post,
    required this.reactionCount,
    this.showCaption = true, // Default to true for backward compatibility
    this.isTextOnly = false,
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
            'Analytics',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
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
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      }
    }

    // Simplified layout for text-only (only boost button if owner)
    if (widget.isTextOnly) {
      if (boostButton != null) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [boostButton],
        );
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meta-actions row (Boost button on right if exists)
        if (boostButton != null)
          Align(
            alignment: Alignment.centerRight,
            child: boostButton,
          ),

        // Caption section (only if showCaption is true)
        if (widget.showCaption && widget.post.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: DesignTokens.spaceXS),
            child: _buildCaption(context),
          ),

        // Hashtags section
        if (widget.post.hashtags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: DesignTokens.spaceSM),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
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
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusSM),
                    ),
                    child: Text(
                      '#$normalizedTag',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
    final secondaryTextColor = SemanticColors.textSecondary(context);

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
              padding: const EdgeInsets.only(top: DesignTokens.spaceXS),
              child: Text(
                'more',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: secondaryTextColor,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
