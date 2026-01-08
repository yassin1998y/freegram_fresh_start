import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:freegram/models/user_inventory_model.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/utils/haptic_helper.dart';

/// Gift sharing service
class GiftSharingService {
  /// Share gift to social media
  static Future<void> shareGift({
    required BuildContext context,
    required OwnedGift gift,
    GiftModel? giftDetails,
  }) async {
    HapticHelper.light();

    final shareText = _generateShareText(gift, giftDetails);
    final shareUrl = _generateShareUrl(gift.id);

    try {
      final result = await Share.shareWithResult(
        '$shareText\n\n$shareUrl',
        subject: 'Check out my gift!',
      );

      if (result.status == ShareResultStatus.success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gift shared successfully! 🎉'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Share gift to stories (Instagram/Facebook)
  static Future<void> shareToStory({
    required BuildContext context,
    required OwnedGift gift,
    String? imageUrl,
  }) async {
    HapticHelper.medium();

    // TODO: Implement story sharing with image
    // This would require platform-specific code for Instagram/Facebook stories

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story sharing coming soon! 📸'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  /// Generate share text
  static String _generateShareText(OwnedGift gift, GiftModel? giftDetails) {
    final giftName = giftDetails?.name ?? 'a special gift';
    final value = gift.currentMarketValue;

    if (gift.receivedFrom != null && gift.receivedFrom != 'daily_reward') {
      return '🎁 I just received $giftName worth $value coins from ${gift.receivedFrom} on Freegram!';
    } else if (gift.receivedFrom == 'daily_reward') {
      return '🎁 I claimed my daily free gift on Freegram! Got $giftName worth $value coins!';
    } else {
      return '🎁 Check out my $giftName on Freegram! Worth $value coins!';
    }
  }

  /// Generate share URL (deep link)
  static String _generateShareUrl(String giftId) {
    // TODO: Replace with actual deep link domain
    return 'https://freegram.app/gift/$giftId';
  }

  /// Show share options bottom sheet
  static Future<void> showShareOptions({
    required BuildContext context,
    required OwnedGift gift,
    GiftModel? giftDetails,
  }) async {
    HapticHelper.light();

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ShareOptionsSheet(
        gift: gift,
        giftDetails: giftDetails,
      ),
    );
  }
}

/// Share options bottom sheet
class ShareOptionsSheet extends StatelessWidget {
  final OwnedGift gift;
  final GiftModel? giftDetails;

  const ShareOptionsSheet({
    super.key,
    required this.gift,
    this.giftDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Text(
            'Share Gift',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 24),

          // Share options
          _ShareOption(
            icon: Icons.share,
            title: 'Share Link',
            subtitle: 'Share via any app',
            color: Colors.blue,
            onTap: () {
              Navigator.pop(context);
              GiftSharingService.shareGift(
                context: context,
                gift: gift,
                giftDetails: giftDetails,
              );
            },
          ),

          const SizedBox(height: 12),

          _ShareOption(
            icon: Icons.camera_alt,
            title: 'Share to Story',
            subtitle: 'Instagram, Facebook, etc.',
            color: Colors.purple,
            onTap: () {
              Navigator.pop(context);
              GiftSharingService.shareToStory(
                context: context,
                gift: gift,
              );
            },
          ),

          const SizedBox(height: 12),

          _ShareOption(
            icon: Icons.link,
            title: 'Copy Link',
            subtitle: 'Copy to clipboard',
            color: Colors.green,
            onTap: () {
              Navigator.pop(context);
              _copyLink(context);
            },
          ),

          const SizedBox(height: 12),

          // Cancel button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  void _copyLink(BuildContext context) {
    HapticHelper.success();
    final url = GiftSharingService._generateShareUrl(gift.id);

    // TODO: Copy to clipboard
    // Clipboard.setData(ClipboardData(text: url));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard! 📋'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// Share option item
class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticHelper.light();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

/// Gift preview card for sharing
class GiftPreviewCard extends StatelessWidget {
  final OwnedGift gift;
  final GiftModel? giftDetails;

  const GiftPreviewCard({
    super.key,
    required this.gift,
    this.giftDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gift icon
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_giftcard,
              size: 50,
              color: Colors.purple,
            ),
          ),

          const SizedBox(height: 16),

          // Gift name
          Text(
            giftDetails?.name ?? 'Special Gift',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 8),

          // Value
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${gift.currentMarketValue} coins',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),

          if (gift.giftMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              gift.giftMessage!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 16),

          // Freegram branding
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.card_giftcard, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text(
                'Freegram',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
