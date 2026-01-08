import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/models/recent_recipient_model.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Recent recipients widget for quick gift sending
class RecentRecipientsWidget extends StatelessWidget {
  final List<RecentRecipient> recipients;
  final Function(RecentRecipient) onRecipientSelected;
  final bool horizontal;

  const RecentRecipientsWidget({
    super.key,
    required this.recipients,
    required this.onRecipientSelected,
    this.horizontal = true,
  });

  @override
  Widget build(BuildContext context) {
    if (recipients.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.history, size: 18),
              const SizedBox(width: 8),
              Text(
                'Recent Recipients',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        horizontal ? _buildHorizontalList() : _buildVerticalList(),
      ],
    );
  }

  Widget _buildHorizontalList() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: recipients.length,
        itemBuilder: (context, index) {
          return _RecipientCard(
            recipient: recipients[index],
            onTap: () {
              HapticHelper.light();
              onRecipientSelected(recipients[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildVerticalList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: recipients.length,
      itemBuilder: (context, index) {
        return _RecipientListTile(
          recipient: recipients[index],
          onTap: () {
            HapticHelper.light();
            onRecipientSelected(recipients[index]);
          },
        );
      },
    );
  }
}

/// Horizontal recipient card
class _RecipientCard extends StatelessWidget {
  final RecentRecipient recipient;
  final VoidCallback onTap;

  const _RecipientCard({
    required this.recipient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: recipient.photoUrl != null
                      ? CachedNetworkImageProvider(recipient.photoUrl!)
                      : null,
                  child: recipient.photoUrl == null
                      ? Text(
                          recipient.username[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                // Gift count badge
                if (recipient.giftCount > 1)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.purple,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${recipient.giftCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Username
            Text(
              recipient.username,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            // Last sent time
            Text(
              timeago.format(recipient.lastSentAt, locale: 'en_short'),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vertical recipient list tile
class _RecipientListTile extends StatelessWidget {
  final RecentRecipient recipient;
  final VoidCallback onTap;

  const _RecipientListTile({
    required this.recipient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundImage: recipient.photoUrl != null
                  ? CachedNetworkImageProvider(recipient.photoUrl!)
                  : null,
              child: recipient.photoUrl == null
                  ? Text(recipient.username[0].toUpperCase())
                  : null,
            ),
            if (recipient.giftCount > 1)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.purple,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${recipient.giftCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(recipient.username),
        subtitle: Text(
          'Last sent ${timeago.format(recipient.lastSentAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.send, size: 20),
        onTap: onTap,
      ),
    );
  }
}
