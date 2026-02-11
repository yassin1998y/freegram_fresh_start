import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/repositories/analytics_repository.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/utils/rarity_helper.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final _analyticsRepo = locator<AnalyticsRepository>();
  final _userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view analytics')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gifting Analytics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCards(),
            const SizedBox(height: 24),
            Text(
              'Global Trends',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildPopularGifts(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _analyticsRepo.getUserGiftingStats(_userId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final stats = snapshot.data ?? {};

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Gifts Sent',
                    '${stats['totalSent'] ?? 0}',
                    Icons.outbound,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Gifts Received',
                    '${stats['totalReceived'] ?? 0}',
                    Icons.inbox,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Unique Collected',
                    '${stats['uniqueCollected'] ?? 0}',
                    Icons.collections,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Coins Spent',
                    '${stats['coinsSpent'] ?? 0}',
                    Icons.monetization_on,
                    Colors.amber,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity( 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity( 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularGifts() {
    return FutureBuilder<List<GiftModel>>(
      future: _analyticsRepo.getPopularGifts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final gifts = snapshot.data ?? [];

        if (gifts.isEmpty) {
          return const Center(child: Text('No data available'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: gifts.length,
          itemBuilder: (context, index) {
            final gift = gifts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: RarityHelper.getColor(gift.rarity)
                        .withOpacity( 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.card_giftcard,
                    color: RarityHelper.getColor(gift.rarity),
                  ),
                ),
                title: Text(gift.name),
                subtitle: Text('${gift.soldCount} purchases'),
                trailing: Text(
                  '#${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
