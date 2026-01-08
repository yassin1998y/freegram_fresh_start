import 'package:flutter/material.dart';
import 'package:freegram/models/user_inventory_model.dart';
import 'package:freegram/utils/haptic_helper.dart';

class UpgradeDialog extends StatelessWidget {
  final OwnedGift ownedGift;
  final int userCoins;
  final Function() onUpgrade;
  final bool isUpgrading;

  const UpgradeDialog({
    super.key,
    required this.ownedGift,
    required this.userCoins,
    required this.onUpgrade,
    this.isUpgrading = false,
  });

  @override
  Widget build(BuildContext context) {
    final nextLevel = ownedGift.upgradeLevel + 1;
    final upgradeCost = ownedGift.purchasePrice * nextLevel;
    final canAfford = userCoins >= upgradeCost;
    final isMaxLevel = ownedGift.upgradeLevel >= 5;

    return AlertDialog(
      title: const Text('Upgrade Gift'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMaxLevel)
            const Column(
              children: [
                Icon(Icons.stars, size: 64, color: Colors.amber),
                SizedBox(height: 16),
                Text(
                  'Maximum Level Reached!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildLevelBadge(ownedGift.upgradeLevel),
                const Icon(Icons.arrow_downward, color: Colors.grey),
                _buildLevelBadge(nextLevel),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Cost: ',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    Icon(Icons.monetization_on,
                        size: 16, color: Colors.amber.shade700),
                    Text(
                      ' $upgradeCost',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: canAfford ? Colors.black : Colors.red,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                if (!canAfford)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Need ${upgradeCost - userCoins} more coins',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isUpgrading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!isMaxLevel)
          ElevatedButton(
            onPressed: canAfford && !isUpgrading
                ? () {
                    HapticHelper.medium();
                    onUpgrade();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: isUpgrading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Upgrade'),
          ),
      ],
    );
  }

  Widget _buildLevelBadge(int level) {
    Color color;
    String label;

    switch (level) {
      case 0:
        color = Colors.brown;
        label = 'Bronze';
        break;
      case 1:
        color = Colors.grey;
        label = 'Silver';
        break;
      case 2:
        color = Colors.amber;
        label = 'Gold';
        break;
      case 3:
        color = Colors.cyan;
        label = 'Platinum';
        break;
      case 4:
        color = Colors.purple;
        label = 'Diamond';
        break;
      case 5:
        color = Colors.red;
        label = 'Legendary';
        break;
      default:
        color = Colors.black;
        label = 'Level $level';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
