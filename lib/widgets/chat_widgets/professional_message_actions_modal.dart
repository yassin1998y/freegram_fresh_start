// lib/widgets/chat_widgets/professional_message_actions_modal.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/models/message.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/island_popup.dart';

/// Professional bottom sheet modal for message actions
/// Improvements: #1, #2, #3, #5, #6, #7, #8, #11, #12
class ProfessionalMessageActionsModal extends StatefulWidget {
  final Message message;
  final bool isMe;
  final String chatId;
  final String currentUserId;
  final Function(String emoji) onReaction;
  final VoidCallback onReply;
  final Function(String messageId, String newText)? onEdit;
  final Function(String messageId)? onDelete;
  final Function(String text)? onCopy;
  final Function(String messageId)? onPin;
  final Function(String messageId)? onForward;

  const ProfessionalMessageActionsModal({
    super.key,
    required this.message,
    required this.isMe,
    required this.chatId,
    required this.currentUserId,
    required this.onReaction,
    required this.onReply,
    this.onEdit,
    this.onDelete,
    this.onCopy,
    this.onPin,
    this.onForward,
  });

  @override
  State<ProfessionalMessageActionsModal> createState() =>
      _ProfessionalMessageActionsModalState();
}

class _ProfessionalMessageActionsModalState
    extends State<ProfessionalMessageActionsModal>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late List<Animation<double>> _staggerAnimations;

  final List<String> _quickReactions = ['👍', '💚', '😂', '😮', '😢', '🙏'];

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      duration: AnimationTokens.normal,
      vsync: this,
    );

    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: AnimationTokens.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: AnimationTokens.easeOut,
    ));

    // Create stagger animations for reactions and actions
    _staggerAnimations = List.generate(10, (index) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _staggerController,
        curve: Interval(
          index * 0.08,
          1.0,
          curve: Curves.elasticOut,
        ),
      ));
    });

    _entranceController.forward();
    _staggerController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  void _handleReaction(String emoji) {
    HapticFeedback.lightImpact();

    // Show success animation
    setState(() {
      // Trigger success feedback
    });

    widget.onReaction(emoji);

    // Delay closing to show animation
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        Navigator.of(context).pop();
        // Show island popup confirmation
        showIslandPopup(
          context: context,
          message: 'Reaction added!',
          icon: Icons.check_circle,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: DesignTokens.blurMedium,
        sigmaY: DesignTokens.blurMedium,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.5),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: DraggableScrollableSheet(
                initialChildSize: 0.5,
                minChildSize: 0.3,
                maxChildSize: 0.75,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(DesignTokens.radiusXXL),
                      ),
                      boxShadow: DesignTokens.shadowFloating,
                    ),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drag handle
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.symmetric(
                              vertical: DesignTokens.spaceMD,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          // Message preview
                          if (widget.message.text != null &&
                              widget.message.text!.isNotEmpty)
                            _buildMessagePreview(),

                          // Quick reactions
                          _buildQuickReactions(),

                          const Divider(height: 1),

                          // Action buttons
                          _buildActionButtons(),

                          const SizedBox(height: DesignTokens.spaceLG),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessagePreview() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceLG,
        vertical: DesignTokens.spaceMD,
      ),
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      ),
      child: Row(
        children: [
          Icon(
            widget.message.imageUrl != null
                ? Icons.image
                : Icons.chat_bubble_outline,
            color: Colors.grey[600],
            size: DesignTokens.iconMD,
          ),
          const SizedBox(width: DesignTokens.spaceMD),
          Expanded(
            child: Text(
              widget.message.text ?? 'Photo',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReactions() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceLG,
        vertical: DesignTokens.spaceMD,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _quickReactions.asMap().entries.map((entry) {
          final index = entry.key;
          final emoji = entry.value;

          return ScaleTransition(
            scale: _staggerAnimations[index],
            child: _ReactionButton(
              emoji: emoji,
              onTap: () => _handleReaction(emoji),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons() {
    final actions = _getAvailableActions();

    return Column(
      children: actions.asMap().entries.map((entry) {
        final index = entry.key;
        final action = entry.value;

        return FadeTransition(
          opacity: _staggerAnimations[6 + (index % 4)],
          child: action,
        );
      }).toList(),
    );
  }

  List<Widget> _getAvailableActions() {
    final actions = <Widget>[];

    // Reply (always available)
    actions.add(_ActionTile(
      icon: Icons.reply,
      label: 'Reply',
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop();
        widget.onReply();
      },
    ));

    // Copy text (for text messages)
    if (widget.message.text != null && widget.message.text!.isNotEmpty) {
      actions.add(_ActionTile(
        icon: Icons.copy,
        label: 'Copy Text',
        onTap: () {
          HapticFeedback.lightImpact();
          Clipboard.setData(ClipboardData(text: widget.message.text!));
          Navigator.of(context).pop();
          showIslandPopup(
            context: context,
            message: 'Text copied!',
            icon: Icons.check_circle,
          );
        },
      ));
    }

    // Edit (only for own text messages)
    if (widget.isMe &&
        widget.message.imageUrl == null &&
        widget.onEdit != null) {
      actions.add(_ActionTile(
        icon: Icons.edit,
        label: 'Edit',
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
          _showEditDialog();
        },
      ));
    }

    // Forward
    if (widget.onForward != null) {
      actions.add(_ActionTile(
        icon: Icons.forward,
        label: 'Forward',
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
          showIslandPopup(
            context: context,
            message: 'Forward feature coming soon',
            icon: Icons.info_outline,
          );
        },
      ));
    }

    // Pin
    if (widget.onPin != null) {
      actions.add(_ActionTile(
        icon: Icons.push_pin_outlined,
        label: 'Pin Message',
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
          showIslandPopup(
            context: context,
            message: 'Pin feature coming soon',
            icon: Icons.info_outline,
          );
        },
      ));
    }

    // Save image (for image messages)
    if (widget.message.imageUrl != null) {
      actions.add(_ActionTile(
        icon: Icons.download,
        label: 'Save Image',
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
          showIslandPopup(
            context: context,
            message: 'Save feature coming soon',
            icon: Icons.info_outline,
          );
        },
      ));
    }

    // Delete (only for own messages)
    if (widget.isMe && widget.onDelete != null) {
      actions.add(_ActionTile(
        icon: Icons.delete,
        label: 'Delete',
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.of(context).pop();
          _showDeleteConfirmation();
        },
        isDestructive: true,
      ));
    }

    return actions;
  }

  void _showEditDialog() {
    final editController = TextEditingController(text: widget.message.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: 'Enter new message',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                widget.onEdit?.call(
                  widget.message.id,
                  editController.text.trim(),
                );
                Navigator.of(context).pop();
                showIslandPopup(
                  context: context,
                  message: 'Message edited',
                  icon: Icons.check_circle,
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text(
            'Are you sure you want to delete this message? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onDelete?.call(widget.message.id);
              Navigator.of(context).pop();
              showIslandPopup(
                context: context,
                message: 'Message deleted',
                icon: Icons.check_circle,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.emoji,
    required this.onTap,
  });

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: AnimationTokens.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
            boxShadow: DesignTokens.shadowLight,
          ),
          child: Center(
            child: Text(
              widget.emoji,
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isDestructive ? Colors.red : Theme.of(context).iconTheme.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceLG,
            vertical: DesignTokens.spaceMD,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: DesignTokens.iconLG),
              const SizedBox(width: DesignTokens.spaceLG),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isDestructive ? Colors.red : null,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
