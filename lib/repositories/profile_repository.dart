import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/models/profile_item_model.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/utils/level_calculator.dart';

class ProfileRepository {
  final FirebaseFirestore _db;

  ProfileRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Get all available profile items
  Stream<List<ProfileItemModel>> getProfileItems({
    ProfileItemType? type,
    bool limitedOnly = false,
  }) {
    Query query = _db.collection('profileItems');

    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }
    if (limitedOnly) {
      query = query.where('isLimited', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => ProfileItemModel.fromDoc(doc)).toList());
  }

  /// Purchase a profile item
  Future<void> purchaseProfileItem(String userId, String itemId) async {
    return await _db.runTransaction((transaction) async {
      // 1. Get item details
      final itemDoc =
          await transaction.get(_db.collection('profileItems').doc(itemId));
      if (!itemDoc.exists) throw Exception('Item not found');
      final item = ProfileItemModel.fromDoc(itemDoc);

      // 2. Get user
      final userDoc =
          await transaction.get(_db.collection('users').doc(userId));
      if (!userDoc.exists) throw Exception('User not found');
      final user = UserModel.fromDoc(userDoc);

      // 3. Validate balance
      if (user.coins < item.priceInCoins) {
        throw Exception('Insufficient coins');
      }

      // 4. Validate requirements (level)
      if (user.userLevel < item.levelRequired) {
        throw Exception('Level ${item.levelRequired} required');
      }

      // 5. Check if already owned
      final ownershipDoc = await transaction.get(_db
          .collection('users')
          .doc(userId)
          .collection('profileInventory')
          .doc(itemId));

      if (ownershipDoc.exists) {
        throw Exception('Item already owned');
      }

      // 6. Update user (deduct coins)
      final int newLifetimeSpent = user.lifetimeCoinsSpent + item.priceInCoins;
      final int newLevel = LevelCalculator.calculateLevel(newLifetimeSpent);

      transaction.update(userDoc.reference, {
        'coins': FieldValue.increment(-item.priceInCoins),
        'lifetimeCoinsSpent': FieldValue.increment(item.priceInCoins),
        'userLevel': newLevel,
      });

      // 7. Add to inventory
      transaction.set(ownershipDoc.reference, {
        'itemId': itemId,
        'type': item.type.name,
        'acquiredAt': FieldValue.serverTimestamp(),
        'isEquipped': false,
      });

      // 8. Log transaction
      final transactionRef = _db.collection('coinTransactions').doc();
      transaction.set(transactionRef, {
        'userId': userId,
        'type': 'spend',
        'amount': -item.priceInCoins,
        'description': 'Purchased profile item: ${item.name}',
        'category': 'profile_item',
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {'itemId': itemId},
      });
    });
  }

  /// Equip a profile item
  Future<void> equipProfileItem(
      String userId, String itemId, ProfileItemType type) async {
    final batch = _db.batch();
    final userRef = _db.collection('users').doc(userId);

    // Update user profile
    if (type == ProfileItemType.border) {
      batch.update(userRef, {'equippedBorderId': itemId});
    } else if (type == ProfileItemType.badge) {
      batch.update(userRef, {'equippedBadgeId': itemId});
    }

    // Update inventory status (optional, if we want to track 'isEquipped' in subcollection)
    // This is complex because we'd need to unequip others.
    // For now, the source of truth is the user document fields.

    await batch.commit();
  }

  /// Unequip a profile item
  Future<void> unequipProfileItem(String userId, ProfileItemType type) async {
    final userRef = _db.collection('users').doc(userId);

    if (type == ProfileItemType.border) {
      await userRef.update({'equippedBorderId': null});
    } else if (type == ProfileItemType.badge) {
      await userRef.update({'equippedBadgeId': null});
    }
  }

  /// Get user's owned profile items
  Stream<List<String>> getUserOwnedItemIds(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('profileInventory')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  /// Seed initial profile items if catalog is empty
  Future<void> seedProfileItems() async {
    final snapshot = await _db.collection('profileItems').limit(1).get();
    if (snapshot.docs.isNotEmpty) return;

    final batch = _db.batch();
    for (final item in initialProfileItems) {
      final docRef = _db.collection('profileItems').doc(item.id);
      batch.set(docRef, item.toMap());
    }
    await batch.commit();
  }

  static final List<ProfileItemModel> initialProfileItems = [
    // Borders - Basic
    const ProfileItemModel(
      id: 'border_basic_blue',
      type: ProfileItemType.border,
      name: 'Basic Blue',
      description: 'A simple blue border.',
      assetUrl: '', // Placeholder
      priceInCoins: 100,
      rarity: ItemRarity.common,
      config: {'color': 0xFF2196F3},
    ),
    const ProfileItemModel(
      id: 'border_basic_red',
      type: ProfileItemType.border,
      name: 'Basic Red',
      description: 'A simple red border.',
      assetUrl: '', // Placeholder
      priceInCoins: 100,
      rarity: ItemRarity.common,
      config: {'color': 0xFFF44336},
    ),
    const ProfileItemModel(
      id: 'border_basic_green',
      type: ProfileItemType.border,
      name: 'Basic Green',
      description: 'A simple green border.',
      assetUrl: '', // Placeholder
      priceInCoins: 100,
      rarity: ItemRarity.common,
      config: {'color': 0xFF4CAF50},
    ),

    // Borders - Neon
    const ProfileItemModel(
      id: 'border_neon_blue',
      type: ProfileItemType.border,
      name: 'Neon Blue',
      description: 'Glowing blue energy.',
      assetUrl: '', // Placeholder
      priceInCoins: 250,
      rarity: ItemRarity.rare,
      config: {'color': 0xFF00BFFF, 'glow': true},
    ),
    const ProfileItemModel(
      id: 'border_neon_pink',
      type: ProfileItemType.border,
      name: 'Neon Pink',
      description: 'Vibrant pink glow.',
      assetUrl: '', // Placeholder
      priceInCoins: 250,
      rarity: ItemRarity.rare,
      config: {'color': 0xFFFF1493, 'glow': true},
    ),
    const ProfileItemModel(
      id: 'border_neon_green',
      type: ProfileItemType.border,
      name: 'Neon Green',
      description: 'Radioactive green.',
      assetUrl: '', // Placeholder
      priceInCoins: 250,
      rarity: ItemRarity.rare,
      config: {'color': 0xFF39FF14, 'glow': true},
    ),

    // Borders - Special
    const ProfileItemModel(
      id: 'border_gold',
      type: ProfileItemType.border,
      name: 'Gold Frame',
      description: 'Pure luxury.',
      assetUrl: '', // Placeholder
      priceInCoins: 1000,
      rarity: ItemRarity.legendary,
      config: {
        'gradient': [0xFFFFD700, 0xFFFFA500]
      },
    ),
    const ProfileItemModel(
      id: 'border_silver',
      type: ProfileItemType.border,
      name: 'Silver Frame',
      description: 'Sleek and shiny.',
      assetUrl: '', // Placeholder
      priceInCoins: 500,
      rarity: ItemRarity.epic,
      config: {
        'gradient': [0xFFC0C0C0, 0xFFE0E0E0]
      },
    ),
    const ProfileItemModel(
      id: 'border_bronze',
      type: ProfileItemType.border,
      name: 'Bronze Frame',
      description: 'Ancient durability.',
      assetUrl: '', // Placeholder
      priceInCoins: 250,
      rarity: ItemRarity.rare,
      config: {
        'gradient': [0xFFCD7F32, 0xFFA0522D]
      },
    ),
    const ProfileItemModel(
      id: 'border_rainbow',
      type: ProfileItemType.border,
      name: 'Rainbow',
      description: 'All the colors!',
      assetUrl: '', // Placeholder
      priceInCoins: 750,
      rarity: ItemRarity.epic,
      config: {'rainbow': true},
    ),
    const ProfileItemModel(
      id: 'border_fire',
      type: ProfileItemType.border,
      name: 'Fire',
      description: 'Hot stuff.',
      assetUrl: '', // Placeholder
      priceInCoins: 800,
      rarity: ItemRarity.epic,
      config: {'animation': 'fire'},
    ),
    const ProfileItemModel(
      id: 'border_ice',
      type: ProfileItemType.border,
      name: 'Ice',
      description: 'Stay cool.',
      assetUrl: '', // Placeholder
      priceInCoins: 800,
      rarity: ItemRarity.epic,
      config: {'animation': 'ice'},
    ),
    const ProfileItemModel(
      id: 'border_galaxy',
      type: ProfileItemType.border,
      name: 'Galaxy',
      description: 'Out of this world.',
      assetUrl: '', // Placeholder
      priceInCoins: 1200,
      rarity: ItemRarity.legendary,
      config: {'animation': 'galaxy'},
    ),
    const ProfileItemModel(
      id: 'border_nature',
      type: ProfileItemType.border,
      name: 'Nature',
      description: 'One with the earth.',
      assetUrl: '', // Placeholder
      priceInCoins: 600,
      rarity: ItemRarity.rare,
      config: {'animation': 'leaves'},
    ),
    const ProfileItemModel(
      id: 'border_cyber',
      type: ProfileItemType.border,
      name: 'Cyberpunk',
      description: 'High tech, low life.',
      assetUrl: '', // Placeholder
      priceInCoins: 900,
      rarity: ItemRarity.epic,
      config: {'animation': 'glitch'},
    ),

    // Badges - Spending
    const ProfileItemModel(
      id: 'badge_spender',
      type: ProfileItemType.badge,
      name: 'Big Spender',
      description: 'Supports the community.',
      assetUrl: '', // Placeholder
      priceInCoins: 1000,
      rarity: ItemRarity.rare,
    ),
    const ProfileItemModel(
      id: 'badge_whale',
      type: ProfileItemType.badge,
      name: 'Whale',
      description: 'A true patron.',
      assetUrl: '', // Placeholder
      priceInCoins: 5000,
      rarity: ItemRarity.legendary,
    ),
    const ProfileItemModel(
      id: 'badge_investor',
      type: ProfileItemType.badge,
      name: 'Investor',
      description: 'Building the future.',
      assetUrl: '', // Placeholder
      priceInCoins: 2500,
      rarity: ItemRarity.epic,
    ),

    // Badges - Social
    const ProfileItemModel(
      id: 'badge_friendly',
      type: ProfileItemType.badge,
      name: 'Friendly',
      description: 'Always says hello.',
      assetUrl: '', // Placeholder
      priceInCoins: 100,
      rarity: ItemRarity.common,
    ),
    const ProfileItemModel(
      id: 'badge_popular',
      type: ProfileItemType.badge,
      name: 'Popular',
      description: 'Everyone knows you.',
      assetUrl: '', // Placeholder
      priceInCoins: 500,
      rarity: ItemRarity.rare,
    ),
    const ProfileItemModel(
      id: 'badge_influencer',
      type: ProfileItemType.badge,
      name: 'Influencer',
      description: 'Trendsetter.',
      assetUrl: '', // Placeholder
      priceInCoins: 1000,
      rarity: ItemRarity.epic,
    ),
    const ProfileItemModel(
      id: 'badge_gifter',
      type: ProfileItemType.badge,
      name: 'Gift Giver',
      description: 'Generosity personified.',
      assetUrl: '', // Placeholder
      priceInCoins: 250,
      rarity: ItemRarity.rare,
    ),

    // Badges - Engagement
    const ProfileItemModel(
      id: 'badge_nightowl',
      type: ProfileItemType.badge,
      name: 'Night Owl',
      description: 'Up all night.',
      assetUrl: '', // Placeholder
      priceInCoins: 100,
      rarity: ItemRarity.common,
    ),
    const ProfileItemModel(
      id: 'badge_streak',
      type: ProfileItemType.badge,
      name: 'Daily Streaker',
      description: 'Consistent.',
      assetUrl: '', // Placeholder
      priceInCoins: 200,
      rarity: ItemRarity.rare,
    ),
    const ProfileItemModel(
      id: 'badge_veteran',
      type: ProfileItemType.badge,
      name: 'Veteran',
      description: 'Seen it all.',
      assetUrl: '', // Placeholder
      priceInCoins: 500,
      rarity: ItemRarity.epic,
    ),

    // Badges - Fun
    const ProfileItemModel(
      id: 'badge_gamer',
      type: ProfileItemType.badge,
      name: 'Gamer',
      description: 'Level up!',
      assetUrl: '', // Placeholder
      priceInCoins: 150,
      rarity: ItemRarity.common,
    ),
    const ProfileItemModel(
      id: 'badge_artist',
      type: ProfileItemType.badge,
      name: 'Artist',
      description: 'Creative soul.',
      assetUrl: '', // Placeholder
      priceInCoins: 150,
      rarity: ItemRarity.common,
    ),
    const ProfileItemModel(
      id: 'badge_musician',
      type: ProfileItemType.badge,
      name: 'Musician',
      description: 'Feel the beat.',
      assetUrl: '', // Placeholder
      priceInCoins: 150,
      rarity: ItemRarity.common,
    ),
    const ProfileItemModel(
      id: 'badge_traveler',
      type: ProfileItemType.badge,
      name: 'Traveler',
      description: 'Wanderlust.',
      assetUrl: '', // Placeholder
      priceInCoins: 150,
      rarity: ItemRarity.common,
    ),
    const ProfileItemModel(
      id: 'badge_foodie',
      type: ProfileItemType.badge,
      name: 'Foodie',
      description: 'Yum!',
      assetUrl: '', // Placeholder
      priceInCoins: 150,
      rarity: ItemRarity.common,
    ),
  ];
}
