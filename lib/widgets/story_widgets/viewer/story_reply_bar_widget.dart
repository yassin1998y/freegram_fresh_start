// lib/widgets/story_widgets/viewer/story_reply_bar_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/blocs/story_viewer_cubit.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/story_repository.dart';
import 'package:freegram/widgets/common/keyboard_safe_area.dart';
import 'package:freegram/widgets/common/app_reaction_button.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

/// Reply bar widget for story viewer
/// Handles text input, reaction button, and send button
class StoryReplyBarWidget extends StatefulWidget {
  final String storyId;
  final int initialReactionCount;
  final StoryViewerCubit? cubit;

  const StoryReplyBarWidget({
    Key? key,
    required this.storyId,
    required this.initialReactionCount,
    this.cubit,
  }) : super(key: key);

  @override
  State<StoryReplyBarWidget> createState() => _StoryReplyBarWidgetState();
}

class _StoryReplyBarWidgetState extends State<StoryReplyBarWidget>
    with SingleTickerProviderStateMixin {
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  AnimationController? _sendButtonAnimation;
  bool _isLiked = false;
  int _reactionCount = 0;

  @override
  void initState() {
    super.initState();
    _reactionCount = widget.initialReactionCount;
    _replyController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _loadReactionState();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    _sendButtonAnimation?.dispose();
    super.dispose();
  }

  Future<void> _loadReactionState() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final storyRepository = locator<StoryRepository>();
      final reactions = await storyRepository.getStoryReactions(widget.storyId);

      if (mounted) {
        setState(() {
          _isLiked = reactions.containsKey(currentUser.uid);
          _reactionCount = reactions.length;
        });
      }
    } catch (e) {
      debugPrint('StoryReplyBarWidget: Error loading reaction state: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMD,
            vertical: DesignTokens.spaceSM,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              stops: const [
                DesignTokens.opacityFull,
                DesignTokens.opacityHigh,
                DesignTokens.opacityMedium,
              ],
              colors: [
                theme.colorScheme.surface.withOpacity(0.95),
                theme.colorScheme.surface.withOpacity(0.8),
                Colors.transparent,
              ],
            ),
          ),
          child: KeyboardAwareInput(
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.2),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusXL),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withOpacity(0.1),
                          width: DesignTokens.elevation1,
                        ),
                      ),
                      child: TextField(
                        controller: _replyController,
                        focusNode: _replyFocusNode,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: DesignTokens.fontSizeMD,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Send message...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withOpacity(DesignTokens.opacityMedium),
                            fontSize: DesignTokens.fontSizeMD,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.spaceMD,
                            vertical: DesignTokens.spaceSM,
                          ),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            widget.cubit
                                ?.sendReply(value.trim(), 'text')
                                .catchError((error) {
                              // Silently handle errors (e.g., replying to own story)
                              debugPrint(
                                  'StoryReplyBarWidget: Error sending reply: $error');
                            });
                            _replyController.clear();
                            _replyFocusNode.unfocus();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSM),
                  _buildHeartReactionButton(context),
                  const SizedBox(width: DesignTokens.spaceSM),
                  _buildSendButton(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeartReactionButton(BuildContext context) {
    const emoji = '💚';

    return AppReactionButton(
      isLiked: _isLiked,
      reactionCount: _reactionCount,
      isLoading: false,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (_isLiked) {
            _isLiked = false;
            _reactionCount =
                (_reactionCount - 1).clamp(0, double.infinity).toInt();
            locator<StoryRepository>()
                .removeStoryReaction(
              storyId: widget.storyId,
              userId: FirebaseAuth.instance.currentUser?.uid ?? '',
            )
                .catchError((e) {
              if (mounted) {
                setState(() {
                  _isLiked = true;
                  _reactionCount = widget.initialReactionCount;
                });
              }
            });
          } else {
            _isLiked = true;
            _reactionCount = _reactionCount + 1;
            locator<StoryRepository>()
                .addStoryReaction(
              storyId: widget.storyId,
              userId: FirebaseAuth.instance.currentUser?.uid ?? '',
              emoji: emoji,
            )
                .catchError((e) {
              if (mounted) {
                setState(() {
                  _isLiked = false;
                  _reactionCount = widget.initialReactionCount;
                });
              }
            });
          }
        });
        // Send emoji reply - cubit will handle errors gracefully
        widget.cubit?.sendReply(emoji, 'emoji').catchError((error) {
          // Silently handle errors (e.g., replying to own story)
          debugPrint('StoryReplyBarWidget: Error sending emoji reply: $error');
        });
      },
      showCount: false,
      size: DesignTokens.buttonHeight - DesignTokens.spaceXS * 2,
    );
  }

  Widget _buildSendButton(BuildContext context) {
    _sendButtonAnimation ??= AnimationController(
      vsync: this,
      duration: AnimationTokens.normal,
    );

    final controller = _sendButtonAnimation!;
    final scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
        parent: controller,
        curve: AnimationTokens.easeOutCubic,
      ),
    );
    final rotationAnimation = Tween<double>(begin: 0.0, end: 0.2).animate(
      CurvedAnimation(
        parent: controller,
        curve: AnimationTokens.easeOutCubic,
      ),
    );

    final hasText = _replyController.text.trim().isNotEmpty;
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.scale(
          scale: scaleAnimation.value,
          child: Transform.rotate(
            angle: rotationAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: hasText
                    ? SonarPulseTheme.primaryAccent
                    : SonarPulseTheme.primaryAccent
                        .withOpacity(DesignTokens.opacityMedium),
                shape: BoxShape.circle,
                boxShadow: controller.value > 0
                    ? [
                        BoxShadow(
                          color: SonarPulseTheme.primaryAccent.withOpacity(
                            0.5 * (1 - controller.value),
                          ),
                          blurRadius:
                              DesignTokens.spaceMD * (1 - controller.value),
                          spreadRadius:
                              DesignTokens.elevation1 * (1 - controller.value),
                        ),
                      ]
                    : null,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send,
                  color: theme.colorScheme.onPrimary,
                  size: DesignTokens.iconMD,
                ),
                onPressed: hasText
                    ? () {
                        if (!mounted) return;
                        HapticFeedback.mediumImpact();
                        controller.forward().then((_) {
                          controller.reverse();
                        });
                        final content = _replyController.text.trim();
                        if (content.isNotEmpty) {
                          widget.cubit
                              ?.sendReply(content, 'text')
                              .catchError((error) {
                            // Silently handle errors (e.g., replying to own story)
                            debugPrint(
                                'StoryReplyBarWidget: Error sending reply: $error');
                          });
                          _replyController.clear();
                          _replyFocusNode.unfocus();
                        }
                      }
                    : null,
                padding: const EdgeInsets.all(DesignTokens.spaceSM),
                constraints: const BoxConstraints(
                  minWidth:
                      DesignTokens.buttonHeight - DesignTokens.spaceXS * 2,
                  minHeight:
                      DesignTokens.buttonHeight - DesignTokens.spaceXS * 2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
