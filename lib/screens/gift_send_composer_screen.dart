import 'package:flutter/material.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:freegram/utils/rarity_helper.dart';
import 'package:freegram/utils/gift_extensions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/widgets/gifting/message_template_selector.dart';
import 'package:freegram/widgets/gifting/gift_sent_banner.dart';
import 'package:confetti/confetti.dart';

/// Message composer screen for gift sending
class GiftSendComposerScreen extends StatefulWidget {
  final UserModel recipient;
  final GiftModel gift;
  final bool isOwned;
  final String? ownedGiftId;

  const GiftSendComposerScreen({
    super.key,
    required this.recipient,
    required this.gift,
    this.isOwned = false,
    this.ownedGiftId,
  });

  @override
  State<GiftSendComposerScreen> createState() => _GiftSendComposerScreenState();
}

class _GiftSendComposerScreenState extends State<GiftSendComposerScreen> {
  late ConfettiController _confettiController;
  final _messageController = TextEditingController();
  static const int _maxCharacters = 200;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 1500));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Message'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview card
            _buildPreviewCard(),

            const SizedBox(height: 24),

            // Message templates
            _buildTemplateSection(),

            const SizedBox(height: 24),

            // Custom message input
            _buildMessageInput(),

            const SizedBox(height: 24),

            // Edit options
            _buildEditOptions(),

            const SizedBox(height: 100), // Space for button
          ],
        ),
      ),
      bottomNavigationBar: _buildSendButton(),
      floatingActionButton: Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [
            Colors.green,
            Colors.blue,
            Colors.pink,
            Colors.orange,
            Colors.purple
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final rarityColor = RarityHelper.getColor(widget.gift.rarity);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.pink.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Recipient info
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: (widget.recipient.photoUrl.isNotEmpty)
                    ? NetworkImage(widget.recipient.photoUrl)
                    : null,
                child: widget.recipient.photoUrl == null
                    ? Text(widget.recipient.username[0].toUpperCase())
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sending to',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      widget.recipient.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Gift preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: rarityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.card_giftcard,
                    size: 32,
                    color: rarityColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.gift.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: rarityColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.gift.rarity.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.monetization_on,
                              size: 14, color: Colors.amber.shade700),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.gift.priceInCoins}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Message preview
          if (_messageController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _messageController.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTemplateSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Message Templates',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          MessageTemplateSelector(
            onTemplateSelected: (template) {
              HapticHelper.light();
              setState(() {
                _messageController.text = template;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Custom Message',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '${_messageController.text.length}/$_maxCharacters',
                style: TextStyle(
                  fontSize: 12,
                  color: _messageController.text.length > _maxCharacters
                      ? Colors.red
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLength: _maxCharacters,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Write your own message... (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              counterText: '',
            ),
            onChanged: (value) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildEditOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                HapticHelper.light();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Change Gift'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                HapticHelper.light();
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              icon: const Icon(Icons.person),
              label: const Text('Change Recipient'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              if (_messageController.text.length > _maxCharacters) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message is too long!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              HapticHelper.medium();
              _showConfirmation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.send, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.isOwned
                      ? 'Send from Inventory'
                      : 'Send Gift (${widget.gift.priceInCoins} coins)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showConfirmation() {
    showDialog(
      context: context,
      builder: (context) => SendConfirmationDialog(
        recipient: widget.recipient,
        gift: widget.gift,
        message:
            _messageController.text.isEmpty ? null : _messageController.text,
        isOwned: widget.isOwned,
        ownedGiftId: widget.ownedGiftId,
        onSuccess: _showSuccessAnimation,
      ),
    );
  }

  void _showSuccessAnimation() {
    // Capture messenger and overlay before popping
    final overlay = Overlay.of(context);

    // Create confetti controller for overlay
    final confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Create overlay entry with confetti and banner
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Confetti Layer (IgnorePointer so it doesn't block touches)
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Colors.red,
                  Colors.yellow,
                ],
                numberOfParticles: 30,
                gravity: 0.3,
              ),
            ),
          ),

          // Banner Layer (IgnorePointer so it doesn't block touches on underlying UI)
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(
                    top: 60), // Adjust top padding as needed
                child: GiftSentBanner(
                  gift: widget.gift,
                  timestamp: DateTime.now(),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Insert overlay
    overlay.insert(overlayEntry);

    // Play confetti
    confettiController.play();

    // Navigate back immediately
    if (mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }

    // Remove overlay after animation completes
    Future.delayed(const Duration(seconds: 4), () {
      // Increased duration slightly for banner readability
      confettiController.stop();
      overlayEntry.remove();
      confettiController.dispose();
    });
  }
}

/// Send confirmation dialog
class SendConfirmationDialog extends StatefulWidget {
  final UserModel recipient;
  final GiftModel gift;
  final String? message;
  final bool isOwned;
  final String? ownedGiftId;
  final VoidCallback onSuccess;

  const SendConfirmationDialog({
    super.key,
    required this.recipient,
    required this.gift,
    this.message,
    this.isOwned = false,
    this.ownedGiftId,
    required this.onSuccess,
  });

  @override
  State<SendConfirmationDialog> createState() => _SendConfirmationDialogState();
}

class _SendConfirmationDialogState extends State<SendConfirmationDialog> {
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Confirm Send'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.isOwned
              ? 'Send this gift from inventory?'
              : 'Buy and send this gift?'),
          const SizedBox(height: 16),
          _buildSummary(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _sendGift,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Send'),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRow('To:', widget.recipient.username),
          const Divider(),
          _buildRow('Gift:', widget.gift.name),
          const Divider(),
          _buildRow(
              'Cost:',
              widget.isOwned
                  ? 'From Inventory'
                  : '${widget.gift.priceInCoins} coins'),
          if (widget.message != null) ...[
            const Divider(),
            _buildRow('Message:', widget.message!),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  Future<void> _sendGift() async {
    setState(() => _isSending = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      if (widget.isOwned) {
        if (widget.ownedGiftId == null) {
          throw Exception('Owned gift ID is missing');
        }
        await locator<GiftRepository>().sendOwnedGift(
          senderId: currentUser.uid,
          recipientId: widget.recipient.id,
          ownedGiftId: widget.ownedGiftId!,
          message: widget.message,
        );
      } else {
        await locator<GiftRepository>().buyAndSendGift(
          senderId: currentUser.uid,
          recipientId: widget.recipient.id,
          giftId: widget.gift.id,
          message: widget.message,
        );
      }

      if (mounted) {
        Navigator.pop(context); // Close dialog
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
