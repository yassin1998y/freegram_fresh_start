import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_inventory_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Gift history screen showing sent and received gifts
class GiftHistoryScreen extends StatefulWidget {
  const GiftHistoryScreen({super.key});

  @override
  State<GiftHistoryScreen> createState() => _GiftHistoryScreenState();
}

class _GiftHistoryScreenState extends State<GiftHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _dateFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gift History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Received', icon: Icon(Icons.inbox, size: 20)),
            Tab(text: 'Sent', icon: Icon(Icons.send, size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search and filter bar
          _buildSearchBar(),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildReceivedTab(),
                _buildSentTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search gifts...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),

          const SizedBox(width: 12),

          // Date filter button
          IconButton(
            icon: Icon(
              _dateFilter != null
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
              color: _dateFilter != null ? Colors.purple : null,
            ),
            onPressed: _showDateFilter,
            tooltip: 'Filter by date',
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedTab() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please log in'));
    }

    final giftRepo = locator<GiftRepository>();

    return StreamBuilder<List<OwnedGift>>(
      stream: giftRepo.getReceivedGifts(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final gifts = snapshot.data ?? [];
        final filteredGifts = _applyFilters(gifts);

        if (filteredGifts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No received gifts',
            subtitle: gifts.isEmpty
                ? 'Gifts you receive will appear here'
                : 'No gifts match your filters',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredGifts.length,
          itemBuilder: (context, index) {
            return _GiftHistoryCard(
              gift: filteredGifts[index],
              isReceived: true,
            );
          },
        );
      },
    );
  }

  Widget _buildSentTab() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please log in'));
    }

    final giftRepo = locator<GiftRepository>();

    return StreamBuilder<List<OwnedGift>>(
      stream: giftRepo.getSentGifts(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final gifts = snapshot.data ?? [];
        final filteredGifts = _applyFilters(gifts);

        if (filteredGifts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.send_outlined,
            title: 'No sent gifts',
            subtitle: gifts.isEmpty
                ? 'Gifts you send will appear here'
                : 'No gifts match your filters',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredGifts.length,
          itemBuilder: (context, index) {
            return _GiftHistoryCard(
              gift: filteredGifts[index],
              isReceived: false,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<OwnedGift> _applyFilters(List<OwnedGift> gifts) {
    var filtered = gifts;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((gift) {
        final message = gift.giftMessage?.toLowerCase() ?? '';
        final from = gift.receivedFrom?.toLowerCase() ?? '';
        return message.contains(_searchQuery) || from.contains(_searchQuery);
      }).toList();
    }

    // Apply date filter
    if (_dateFilter != null) {
      filtered = filtered.where((gift) {
        final date = gift.receivedAt;
        return date.isAfter(_dateFilter!.start) &&
            date.isBefore(_dateFilter!.end.add(const Duration(days: 1)));
      }).toList();
    }

    return filtered;
  }

  Future<void> _showDateFilter() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateFilter,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.purple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      HapticHelper.light();
      setState(() => _dateFilter = picked);
    }
  }
}

/// Gift history card widget
class _GiftHistoryCard extends StatelessWidget {
  final OwnedGift gift;
  final bool isReceived;

  const _GiftHistoryCard({
    required this.gift,
    required this.isReceived,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.purple.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.card_giftcard,
            color: Colors.purple,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                gift.giftId,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (gift.isDisplayed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility,
                        size: 12, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Displayed',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (gift.receivedFrom != null &&
                gift.receivedFrom != 'daily_reward')
              Text(
                isReceived
                    ? 'From: ${gift.receivedFrom}'
                    : 'To: ${gift.ownerId}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            if (gift.giftMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                gift.giftMessage!,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  timeago.format(gift.receivedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${gift.currentMarketValue} coins',
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
        onTap: () {
          HapticHelper.light();
          _showGiftDetails(context);
        },
      ),
    );
  }

  void _showGiftDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.card_giftcard,
                      size: 50,
                      color: Colors.purple,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _DetailRow(label: 'Gift ID', value: gift.giftId),
                _DetailRow(
                  label: 'Received',
                  value:
                      '${gift.receivedAt.day}/${gift.receivedAt.month}/${gift.receivedAt.year}',
                ),
                if (gift.receivedFrom != null)
                  _DetailRow(
                    label: isReceived ? 'From' : 'To',
                    value: gift.receivedFrom!,
                  ),
                if (gift.giftMessage != null)
                  _DetailRow(label: 'Message', value: gift.giftMessage!),
                _DetailRow(
                  label: 'Value',
                  value: '${gift.currentMarketValue} coins',
                ),
                _DetailRow(
                  label: 'Status',
                  value: gift.isDisplayed
                      ? 'Displayed on profile'
                      : 'In inventory',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
