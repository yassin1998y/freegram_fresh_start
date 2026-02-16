// lib/widgets/chat_widgets/professional_message_bubble.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/message.dart';
import 'package:freegram/services/cloudinary_service.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/utils/image_save_util.dart';
import 'package:freegram/widgets/chat_widgets/message_reaction_display.dart';
import 'package:freegram/widgets/chat_widgets/voice_message_bubble.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/island_popup.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Professional Message Bubble with gradients, clustering, and animations
/// Improvements: #3, #17, #33, #34
class ProfessionalMessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;
  final Message? previousMessage;
  final Message? nextMessage;
  final bool isFirstUnread;
  final String otherUsername;
  final VoidCallback? onReplyTap;
  final bool shouldHighlight;

  const ProfessionalMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.onLongPress,
    this.onTap,
    this.previousMessage,
    this.nextMessage,
    this.isFirstUnread = false,
    required this.otherUsername,
    this.onReplyTap,
    this.shouldHighlight = false,
  });

  @override
  State<ProfessionalMessageBubble> createState() =>
      _ProfessionalMessageBubbleState();
}

class _ProfessionalMessageBubbleState extends State<ProfessionalMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _highlightController;
  late Animation<Color?> _highlightAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      duration: AnimationTokens.slow,
      vsync: this,
    );

    // Use a fixed color for highlight that feels theme-aware
    _highlightAnimation = ColorTween(
      begin: Colors.transparent,
      end: widget.isMe
          ? Colors.teal.withValues(alpha: 0.2)
          : Colors.grey.withValues(alpha: 0.1),
    ).animate(CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeInOut,
    ));

    if (widget.shouldHighlight) {
      _triggerHighlight();
    }
  }

  @override
  void didUpdateWidget(ProfessionalMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldHighlight && !oldWidget.shouldHighlight) {
      _triggerHighlight();
    }
  }

  void _triggerHighlight() {
    _highlightController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _highlightController.reverse();
      });
    });
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  void _showTimestamp(BuildContext context) {
    if (widget.message.timestamp == null) return;

    final date = widget.message.timestamp!.toDate();
    final formattedDate = DateFormat('MMM d, y').format(date);
    final formattedTime = DateFormat('h:mm a').format(date);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formattedDate,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: DesignTokens.spaceXS),
            Text(
              formattedTime,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Message clustering logic
  bool get _isFirstInCluster {
    if (widget.previousMessage == null) return true;
    if (widget.previousMessage!.senderId != widget.message.senderId) {
      return true;
    }

    final timeDiff = widget.message.timestamp != null &&
            widget.previousMessage!.timestamp != null
        ? widget.message.timestamp!
            .toDate()
            .difference(widget.previousMessage!.timestamp!.toDate())
        : const Duration(hours: 1);

    return timeDiff.inMinutes > 5;
  }

  bool get _isLastInCluster {
    if (widget.nextMessage == null) return true;
    if (widget.nextMessage!.senderId != widget.message.senderId) return true;

    final timeDiff = widget.nextMessage!.timestamp != null &&
            widget.message.timestamp != null
        ? widget.nextMessage!.timestamp!
            .toDate()
            .difference(widget.message.timestamp!.toDate())
        : const Duration(hours: 1);

    return timeDiff.inMinutes > 5;
  }

  BorderRadius _getBubbleBorderRadius() {
    const double radiusStandard = DesignTokens.radiusLG; // 16px
    const double radiusFlat = 4.0; // Flatter corners for grouping

    if (widget.isMe) {
      // Sent messages - right aligned
      // Flatten corners on the joined side (right)
      return BorderRadius.only(
        topLeft: const Radius.circular(radiusStandard),
        topRight:
            Radius.circular(_isFirstInCluster ? radiusStandard : radiusFlat),
        bottomLeft: const Radius.circular(radiusStandard),
        bottomRight:
            Radius.circular(_isLastInCluster ? radiusStandard : radiusFlat),
      );
    } else {
      // Received messages - left aligned
      // Flatten corners on the joined side (left)
      return BorderRadius.only(
        topLeft:
            Radius.circular(_isFirstInCluster ? radiusStandard : radiusFlat),
        topRight: const Radius.circular(radiusStandard),
        bottomLeft:
            Radius.circular(_isLastInCluster ? radiusStandard : radiusFlat),
        bottomRight: const Radius.circular(radiusStandard),
      );
    }
  }

  double get _topPadding {
    return _isFirstInCluster ? DesignTokens.spaceMD : DesignTokens.spaceXS;
  }

  double _swipeOffset = 0.0;
  bool _isSwiping = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _highlightAnimation,
        builder: (context, child) {
          return GestureDetector(
            onHorizontalDragStart: (_) {
              setState(() {
                _isSwiping = true;
              });
            },
            onHorizontalDragUpdate: (details) {
              if (!_isSwiping) return;

              // Only allow swipe right for reply, swipe left for delete (own messages)
              if (details.delta.dx > 0 && !widget.isMe) {
                // Swipe right to reply (received messages)
                setState(() {
                  _swipeOffset =
                      (_swipeOffset + details.delta.dx).clamp(0.0, 100.0);
                });
              } else if (details.delta.dx < 0 && widget.isMe) {
                // Swipe left to delete (own messages)
                setState(() {
                  _swipeOffset =
                      (_swipeOffset + details.delta.dx).clamp(-100.0, 0.0);
                });
              }
            },
            onHorizontalDragEnd: (details) {
              if (!_isSwiping) return;

              setState(() {
                _isSwiping = false;
              });

              // Trigger action if swiped enough
              if (_swipeOffset > 50 && !widget.isMe) {
                // Swipe right to reply
                HapticFeedback.mediumImpact();
                widget
                    .onLongPress(); // Use long press handler to show actions, which includes reply
                _swipeOffset = 0.0;
              } else if (_swipeOffset < -50 && widget.isMe) {
                // Swipe left to delete
                HapticFeedback.mediumImpact();
                widget.onLongPress(); // Show delete option in actions
                _swipeOffset = 0.0;
              } else {
                // Reset position
                _swipeOffset = 0.0;
              }
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              widget.onLongPress();
            },
            onTap: () {
              // If there's a custom onTap handler, use it
              // Otherwise, show timestamp on tap
              if (widget.onTap != null) {
                widget.onTap?.call();
              } else if (widget.message.timestamp != null) {
                _showTimestamp(context);
              }
            },
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            child: Transform.translate(
              offset: Offset(_swipeOffset, 0),
              child: Container(
                color: _highlightAnimation.value,
                padding: EdgeInsets.only(
                  top: _topPadding,
                  left: DesignTokens.spaceSM,
                  right: DesignTokens.spaceSM,
                  bottom: DesignTokens.spaceXS,
                ),
                child: Align(
                  alignment: widget.isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: widget.isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      // Show sender name for first message in cluster (group chats)
                      if (_isFirstInCluster && !widget.isMe)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: DesignTokens.spaceMD,
                            bottom: DesignTokens.spaceXS,
                          ),
                          child: Text(
                            widget.otherUsername,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: DesignTokens.fontSizeXS,
                            ),
                          ),
                        ),

                      // Message bubble
                      AnimatedScale(
                        scale: _isPressed ? 0.98 : 1.0,
                        duration: AnimationTokens.fast,
                        child: widget.message.status == MessageStatus.sending
                            ? Shimmer.fromColors(
                                baseColor: widget.isMe
                                    ? SonarPulseTheme.primaryAccent
                                        .withValues(alpha: 0.7)
                                    : Colors.grey.withValues(alpha: 0.1),
                                highlightColor: widget.isMe
                                    ? SonarPulseTheme.primaryAccent
                                        .withValues(alpha: 0.4)
                                    : Colors.grey.withValues(alpha: 0.05),
                                child: _buildMessageContent(context),
                              )
                            : _buildMessageContent(context),
                      ),

                      // Timestamp and status (shown on last message in cluster)
                      if (_isLastInCluster)
                        Padding(
                          padding: EdgeInsets.only(
                            top: DesignTokens.spaceXS,
                            left: widget.isMe ? 0 : DesignTokens.spaceMD,
                            right: widget.isMe ? DesignTokens.spaceMD : 0,
                          ),
                          child: _buildMessageStatus(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main bubble container
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: widget.message.imageUrl != null
              ? const EdgeInsets.all(DesignTokens.spaceXS)
              : const EdgeInsets.symmetric(
                  vertical: DesignTokens.spaceSM,
                  horizontal: DesignTokens.spaceMD,
                ),
          decoration: BoxDecoration(
            gradient: widget.isMe
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      SonarPulseTheme.primaryAccent,
                      SonarPulseTheme.primaryAccent.withValues(alpha: 0.85),
                    ],
                  )
                : null,
            color: widget.isMe
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : theme.colorScheme.surface,
            borderRadius: _getBubbleBorderRadius(),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.1),
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Story reply preview (Facebook-style)
              if (widget.message.storyReplyId != null)
                _buildStoryReplyPreview(context),

              // Reply preview
              if (widget.message.replyToMessageId != null)
                _buildReplyPreview(context),

              // Message content
              _buildContent(context),

              // Edited indicator
              if (widget.message.isEdited)
                Padding(
                  padding: const EdgeInsets.only(top: DesignTokens.spaceXS),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit,
                        size: DesignTokens.iconXS,
                        color: widget.isMe
                            ? Colors.white70
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Edited',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeXS,
                          color: widget.isMe
                              ? Colors.white70
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Reactions display
        if (widget.message.reactions.isNotEmpty)
          Positioned(
            bottom: -12,
            right: widget.isMe ? DesignTokens.spaceSM : null,
            left: widget.isMe ? null : DesignTokens.spaceSM,
            child: MessageReactionDisplay(
              reactions: widget.message.reactions,
              isMe: widget.isMe,
            ),
          ),
      ],
    );
  }

  Widget _buildStoryReplyPreview(BuildContext context) {
    final theme = Theme.of(context);
    final storyThumbnail =
        widget.message.storyThumbnailUrl ?? widget.message.storyMediaUrl;
    final isVideo = widget.message.storyMediaType == 'video';

    return GestureDetector(
      onTap: () {
        // Navigate to story viewer if needed
        // TODO: Implement story viewer navigation
        HapticFeedback.lightImpact();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: DesignTokens.spaceSM),
        padding: const EdgeInsets.all(DesignTokens.spaceSM),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.2)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
          border: Border.all(
            color: widget.isMe
                ? Colors.white.withValues(alpha: 0.3)
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Story thumbnail
            if (storyThumbnail != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: storyThumbnail,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[300],
                        child: const Center(
                          child: AppProgressIndicator(
                            size: 20,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.auto_stories,
                          size: 24,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    // Video play icon overlay
                    if (isVideo)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusXS),
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                ),
                child: Icon(
                  Icons.auto_stories,
                  size: 24,
                  color: Colors.grey[600],
                ),
              ),
            const SizedBox(width: DesignTokens.spaceSM),
            // Story info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_stories,
                        size: DesignTokens.iconXS,
                        color: widget.isMe
                            ? Colors.white70
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Story',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeXS,
                          fontWeight: FontWeight.bold,
                          color: widget.isMe
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (widget.message.storyAuthorUsername != null)
                    Text(
                      widget.message.storyAuthorUsername!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeXS,
                        color: widget.isMe
                            ? Colors.white70
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    return GestureDetector(
      onTap: widget.onReplyTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: DesignTokens.spaceXS),
        padding: const EdgeInsets.all(DesignTokens.spaceSM),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
          border: Border(
            left: BorderSide(
              color: widget.isMe
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.primary,
              width: 2.0,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message.replyToSender ?? 'Unknown',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: DesignTokens.fontSizeXS,
                color: widget.isMe
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            if (widget.message.replyToImageUrl != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo,
                    size: DesignTokens.iconSM,
                    color: widget.isMe
                        ? Colors.white70
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: DesignTokens.spaceXS),
                  Text(
                    'Photo',
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeSM,
                      color: widget.isMe
                          ? Colors.white70
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              )
            else
              Text(
                widget.message.replyToMessageText ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeSM,
                  color: widget.isMe
                      ? Colors.white70
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.message.isAudio && widget.message.audioUrl != null) {
      return VoiceMessageBubble(
        message: widget.message,
        isMe: widget.isMe,
      );
    }

    if (widget.message.imageUrl != null) {
      return GestureDetector(
        onTap: () {
          // Navigate to image viewer
          locator<NavigationService>().navigateTo(
            _EnhancedImageViewer(
              imageUrl: widget.message.imageUrl!,
              heroTag: 'message_image_${widget.message.id}',
            ),
            transition: PageTransition.fade,
          );
        },
        child: Hero(
          tag: 'message_image_${widget.message.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            child: CachedNetworkImage(
              imageUrl: CloudinaryService.getOptimizedImageUrl(
                widget.message.imageUrl!,
                width: 800, // Max width for chat images
                quality: ImageQuality.medium,
              ),
              fit: BoxFit.cover,
              maxHeightDiskCache: 800,
              maxWidthDiskCache: 800,
              memCacheHeight: 400,
              memCacheWidth: 400,
              placeholder: (context, url) => Container(
                height: 200,
                color: Colors.grey[200],
                child: const Center(
                  child: AppProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 200,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 48),
              ),
            ),
          ),
        ),
      );
    }

    return Text(
      widget.message.text ?? '',
      style: TextStyle(
        color: widget.isMe
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.onSurface,
        fontSize: DesignTokens.fontSizeMD,
        height: DesignTokens.lineHeightNormal,
      ),
    );
  }

  Widget _buildMessageStatus() {
    Widget statusWidget;

    if (widget.isMe) {
      switch (widget.message.status) {
        case MessageStatus.sending:
          statusWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sending...',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeXS,
                  color: Colors.grey[600],
                ),
              ),
            ],
          );
          break;
        case MessageStatus.sent:
        case MessageStatus.delivered:
          // Task 1: Sent (Full opacity, single Teal check)
          statusWidget = const Icon(
            Icons.done,
            size: 16,
            color: SonarPulseTheme.primaryAccent,
          );
          break;
        case MessageStatus.seen:
          // Task 1: Read (Double Cyber-Violet checks)
          statusWidget = const Icon(
            Icons.done_all,
            size: 16,
            color: SonarPulseTheme.primaryAccent,
          );
          break;
        case MessageStatus.error:
          statusWidget = const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 16, color: Colors.red),
              SizedBox(width: 4),
              Text(
                'Failed',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeXS,
                  color: Colors.red,
                ),
              ),
            ],
          );
          break;
      }
    } else {
      statusWidget = const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.message.timestamp != null)
          Text(
            timeago.format(
              widget.message.timestamp!.toDate(),
              locale: 'en_short',
            ),
            style: TextStyle(
              fontSize: DesignTokens.fontSizeXS,
              color: widget.isMe
                  ? Colors.white70
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
            ),
          ),
        if (widget.isMe && widget.message.timestamp != null)
          const SizedBox(width: 4),
        if (widget.isMe) statusWidget,
      ],
    );
  }
}

// Enhanced Image Viewer (Improvement #35)
class _EnhancedImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const _EnhancedImageViewer({
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              HapticFeedback.lightImpact();
              final saved = await ImageSaveUtil.saveImageToDevice(imageUrl);
              if (context.mounted) {
                if (saved != null) {
                  showIslandPopup(
                    context: context,
                    message: 'Image saved successfully!',
                    icon: Icons.check_circle,
                  );
                } else {
                  showIslandPopup(
                    context: context,
                    message: 'Failed to save image. Please check permissions.',
                    icon: Icons.error_outline,
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              HapticFeedback.lightImpact();
              final shared = await ImageSaveUtil.shareImage(imageUrl);
              if (context.mounted && !shared) {
                showIslandPopup(
                  context: context,
                  message: 'Failed to share image',
                  icon: Icons.error_outline,
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              placeholder: (context, url) => const AppProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(
                Icons.error,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
