import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:freegram/utils/rarity_helper.dart';
import 'package:freegram/utils/gift_extensions.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

/// Category browse screen
class CategoryBrowseScreen extends StatefulWidget {
  final GiftCategory category;

  const CategoryBrowseScreen({
    super.key,
    required this.category,
  });

  @override
  State<CategoryBrowseScreen> createState() => _CategoryBrowseScreenState();
}

class _CategoryBrowseScreenState extends State<CategoryBrowseScreen> {
  final _giftRepo = locator<GiftRepository>();

  _SortOption _sortOption = _SortOption.priceAsc;
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<GiftModel>>(
        stream: _giftRepo.getAvailableGifts(category: widget.category),
        builder: (context, snapshot) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text('${widget.category.displayName} Gifts'),
                centerTitle: true,
                pinned: true,
                floating: true,
                actions: [
                  // View toggle
                  IconButton(
                    icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                    onPressed: () {
                      HapticHelper.light();
                      setState(() => _isGridView = !_isGridView);
                    },
                  ),
                  // Sort menu
                  PopupMenuButton<_SortOption>(
                    icon: const Icon(Icons.sort),
                    onSelected: (option) {
                      HapticHelper.light();
                      setState(() => _sortOption = option);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _SortOption.priceAsc,
                        child: Text('Price: Low to High'),
                      ),
                      const PopupMenuItem(
                        value: _SortOption.priceDesc,
                        child: Text('Price: High to Low'),
                      ),
                      const PopupMenuItem(
                        value: _SortOption.rarityDesc,
                        child: Text('Rarity: High to Low'),
                      ),
                      const PopupMenuItem(
                        value: _SortOption.popularityDesc,
                        child: Text('Most Popular'),
                      ),
                    ],
                  ),
                ],
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  child: Center(child: AppProgressIndicator()),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(
                  child: Center(child: Text('Error: ${snapshot.error}')),
                )
              else if (!snapshot.hasData || snapshot.data!.isEmpty)
                SliverFillRemaining(child: _buildEmptyState())
              else ...[
                _buildContentSliver(_sortGifts(snapshot.data!)),
              ],
            ],
          );
        },
      ),
    );
  }

  List<GiftModel> _sortGifts(List<GiftModel> gifts) {
    switch (_sortOption) {
      case _SortOption.priceAsc:
        gifts.sort((a, b) => a.priceInCoins.compareTo(b.priceInCoins));
        break;
      case _SortOption.priceDesc:
        gifts.sort((a, b) => b.priceInCoins.compareTo(a.priceInCoins));
        break;
      case _SortOption.rarityDesc:
        gifts.sort((a, b) => b.rarity.index.compareTo(a.rarity.index));
        break;
      case _SortOption.popularityDesc:
        gifts.sort((a, b) => b.soldCount.compareTo(a.soldCount));
        break;
    }
    return gifts;
  }

  Widget _buildContentSliver(List<GiftModel> gifts) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: _isGridView ? _buildSliverGrid(gifts) : _buildSliverList(gifts),
    );
  }

  Widget _buildSliverGrid(List<GiftModel> gifts) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildGiftGridCard(gifts[index]),
        childCount: gifts.length,
      ),
    );
  }

  Widget _buildSliverList(List<GiftModel> gifts) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildGiftListCard(gifts[index]),
        childCount: gifts.length,
      ),
    );
  }

  Widget _buildGiftGridCard(GiftModel gift) {
    final rarityColor = RarityHelper.getColor(gift.rarity);

    return GestureDetector(
      onTap: () {
        HapticHelper.light();
        Navigator.pushNamed(context, '/gift-detail', arguments: gift);
      },
      child: Container(
        decoration: Containers.glassCard(context).copyWith(
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: rarityColor.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.card_giftcard,
                          size: 64,
                          color: rarityColor,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: rarityColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          gift.rarity.displayName,
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gift.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.monetization_on,
                          size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Text(
                        '${gift.priceInCoins}',
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
    );
  }

  Widget _buildGiftListCard(GiftModel gift) {
    final rarityColor = RarityHelper.getColor(gift.rarity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: Containers.glassCard(context).copyWith(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: rarityColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: rarityColor.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(Icons.card_giftcard, color: rarityColor, size: 32),
        ),
        title: Text(
          gift.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              gift.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                    gift.rarity.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(Icons.monetization_on, size: 16, color: Colors.amber.shade700),
            Text(
              '${gift.priceInCoins}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade700,
              ),
            ),
          ],
        ),
        onTap: () {
          HapticHelper.light();
          Navigator.pushNamed(context, '/gift-detail', arguments: gift);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_giftcard, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No gifts in this category',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new gifts',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

enum _SortOption {
  priceAsc,
  priceDesc,
  rarityDesc,
  popularityDesc,
}
