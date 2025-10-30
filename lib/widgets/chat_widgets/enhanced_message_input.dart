// lib/widgets/chat_widgets/enhanced_message_input.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/island_popup.dart';

/// Enhanced message input area with multi-line support and attachments
/// Improvement #22 - Implement enhanced message input area
class EnhancedMessageInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onLongPressSend;
  final VoidCallback onCamera;
  final VoidCallback? onGallery;
  final VoidCallback? onAttachment;
  final bool isUploading;
  final String? replyingTo;
  final VoidCallback? onCancelReply;

  const EnhancedMessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onLongPressSend,
    required this.onCamera,
    this.onGallery,
    this.onAttachment,
    this.isUploading = false,
    this.replyingTo,
    this.onCancelReply,
  });

  @override
  State<EnhancedMessageInput> createState() => _EnhancedMessageInputState();
}

class _EnhancedMessageInputState extends State<EnhancedMessageInput> {
  bool _hasText = false;
  bool _showAttachmentMenu = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply preview
            if (widget.replyingTo != null) _buildReplyPreview(),

            // Input row
            Padding(
              padding: EdgeInsets.all(DesignTokens.spaceSM),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attachment button
                  _buildAttachmentButton(),

                  SizedBox(width: DesignTokens.spaceSM),

                  // Text input
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                        maxHeight: 120, // 5 lines max
                      ),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusXL),
                        border: Border.all(
                          color: theme.dividerColor.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: widget.controller,
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: DesignTokens.fontSizeMD,
                                height: DesignTokens.lineHeightNormal,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.4),
                                  fontSize: DesignTokens.fontSizeMD,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: DesignTokens.spaceMD,
                                  vertical: DesignTokens.spaceSM,
                                ),
                              ),
                            ),
                          ),

                          // Emoji picker button (placeholder)
                          IconButton(
                            icon: Icon(
                              Icons.emoji_emotions_outlined,
                              color: theme.colorScheme.primary.withOpacity(0.6),
                              size: DesignTokens.iconLG,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              showIslandPopup(
                                context: context,
                                message: 'Emoji picker coming soon',
                                icon: Icons.info_outline,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(width: DesignTokens.spaceSM),

                  // Send button (morphs from voice)
                  _buildSendButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(DesignTokens.spaceMD),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 1,
          ),
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: DesignTokens.iconSM,
            color: theme.colorScheme.primary,
          ),
          SizedBox(width: DesignTokens.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeXS,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.replyingTo!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeSM,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: DesignTokens.iconSM,
              color: theme.colorScheme.primary.withOpacity(0.6),
            ),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentButton() {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _showAttachmentMenu = !_showAttachmentMenu);
          if (_showAttachmentMenu) {
            _showAttachmentOptions();
          }
        },
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
            boxShadow: DesignTokens.shadowLight,
          ),
          child: Icon(
            _showAttachmentMenu ? Icons.close : Icons.add,
            color: Colors.white,
            size: DesignTokens.iconLG,
          ),
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusXL),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(DesignTokens.spaceLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: DesignTokens.spaceMD),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _AttachmentOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onCamera();
                    },
                  ),
                  _AttachmentOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onGallery?.call();
                    },
                  ),
                  _AttachmentOption(
                    icon: Icons.attach_file,
                    label: 'File',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onAttachment?.call();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      setState(() => _showAttachmentMenu = false);
    });
  }

  Widget _buildSendButton() {
    final theme = Theme.of(context);

    if (widget.isUploading) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    // Always show send button for balanced look
    return GestureDetector(
      onTap: _hasText
          ? () {
              HapticFeedback.mediumImpact();
              widget.onSend();
            }
          : null,
      onLongPress: _hasText && widget.onLongPressSend != null
          ? () {
              HapticFeedback.heavyImpact();
              widget.onLongPressSend!();
            }
          : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _hasText
              ? theme.colorScheme.primary
              : theme.colorScheme.primary.withOpacity(0.3),
          borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
          boxShadow: _hasText ? DesignTokens.shadowLight : null,
        ),
        child: Icon(
          widget.onLongPressSend != null ? Icons.schedule_send : Icons.send,
          color: _hasText ? Colors.white : Colors.white.withOpacity(0.6),
          size: DesignTokens.iconMD,
        ),
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: DesignTokens.iconLG,
            ),
          ),
          SizedBox(height: DesignTokens.spaceXS),
          Text(
            label,
            style: TextStyle(
              fontSize: DesignTokens.fontSizeXS,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
