import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/wishlist_item_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:share_plus/share_plus.dart';

/// Wishlist screen showing user's desired gifts
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final _giftRepo = locator<GiftRepository>();

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wishlist'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareWishlist(currentUser.uid),
            tooltip: 'Share Wishlist',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToAddGift(),
            tooltip: 'Add Gift',
          ),
        ],
      ),
      body: StreamBuilder<List<WishlistItem>>(
        stream: _giftRepo.getWishlist(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AppProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _buildWishlistCard(items[index], currentUser.uid);
            },
          );
        },
      ),
    );
  }

  Widget _buildWishlistCard(WishlistItem item, String userId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: Containers.glassCard(context),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 60,
              height: 60,
              decoration: Containers.glassCard(context),
              child: Icon(
                Icons.card_giftcard,
                color: _getPriorityColor(item.priority),
                size: 32,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.giftName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration:
                          item.isReceived ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (item.isReceived)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Received',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.monetization_on,
                        size: 14, color: Colors.amber.shade700),
                    const SizedBox(width: 4),
                    Text(
                      '${item.giftPrice} coins',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildPriorityChip(item.priority),
                  ],
                ),
                if (item.note != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.note!,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(value, item, userId),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'mark',
                  child: Row(
                    children: [
                      Icon(
                        item.isReceived ? Icons.undo : Icons.check,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(item.isReceived
                          ? 'Mark as Not Received'
                          : 'Mark as Received'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Remove', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(int priority) {
    final color = _getPriorityColor(priority);
    final label = _getPriorityLabel(priority);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.blue;
      case 4:
        return Colors.green;
      case 5:
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 1:
        return 'Highest';
      case 2:
        return 'High';
      case 3:
        return 'Medium';
      case 4:
        return 'Low';
      case 5:
        return 'Lowest';
      default:
        return 'Medium';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_giftcard_outlined,
              size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 24),
          Text(
            'Your wishlist is empty',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add gifts you\'d like to receive',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToAddGift,
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Gift'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, WishlistItem item, String userId) {
    switch (action) {
      case 'edit':
        _showEditDialog(item, userId);
        break;
      case 'mark':
        _toggleReceived(item, userId);
        break;
      case 'delete':
        _confirmDelete(item, userId);
        break;
    }
  }

  void _showEditDialog(WishlistItem item, String userId) {
    final noteController = TextEditingController(text: item.note);
    int selectedPriority = item.priority;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Edit Wishlist Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.giftName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Priority:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(5, (index) {
                  final priority = index + 1;
                  return ChoiceChip(
                    label: Text(_getPriorityLabel(priority)),
                    selected: selectedPriority == priority,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => selectedPriority = priority);
                      }
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _giftRepo.updateWishlistItem(
                  userId: userId,
                  wishlistItemId: item.id,
                  priority: selectedPriority,
                  note:
                      noteController.text.isEmpty ? null : noteController.text,
                );
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Updated!')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleReceived(WishlistItem item, String userId) async {
    await _giftRepo.updateWishlistItem(
      userId: userId,
      wishlistItemId: item.id,
      isReceived: !item.isReceived,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item.isReceived
                ? 'Marked as not received'
                : 'Marked as received! 🎁',
          ),
        ),
      );
    }
  }

  void _confirmDelete(WishlistItem item, String userId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from Wishlist?'),
        content: Text('Remove "${item.giftName}" from your wishlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _giftRepo.removeFromWishlist(userId, item.id);
              if (mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Removed from wishlist')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _shareWishlist(String userId) {
    final link = _giftRepo.getWishlistShareLink(userId);
    Share.share(
      'Check out my gift wishlist! $link',
      subject: 'My Gift Wishlist',
    );
    HapticHelper.medium();
  }

  void _navigateToAddGift() {
    // TODO: Navigate to marketplace to add gifts
    Navigator.pushNamed(context, '/marketplace');
  }
}
