import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/gift_model.dart';
import 'package:freegram/repositories/analytics_repository.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/utils/rarity_helper.dart';
import 'package:freegram/theme/design_tokens.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final _analyticsRepo = locator<AnalyticsRepository>();
  final _userId = FirebaseAuth.instance.currentUser?.uid;

  late Future<Map<String, dynamic>> _giftingStatsFuture;
  late Future<List<GiftModel>> _popularGiftsFuture;
  late Future<List<Map<String, dynamic>>> _liveReachFuture;

  @override
  void initState() {
    super.initState();
    if (_userId != null) {
      _giftingStatsFuture = _analyticsRepo.getUserGiftingStats(_userId);
      _popularGiftsFuture = _analyticsRepo.getPopularGifts();
      // Preload Live Reach graph
      _liveReachFuture = _analyticsRepo.getLiveBoostReach(_userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view analytics')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLiveReachSection(),
            const SizedBox(height: 24),
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

  Widget _buildLiveReachSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _liveReachFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); // Hide if no active boost/data
        }

        final dataPoints = snapshot.data!;
        // Simple aggregation: Count reach per interval if needed, or just plot cumulative
        // For zero latency demo, we'll plot a simple rising curve based on count

        return Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: Containers.glassCard(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.show_chart, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Live Reach (Active Boost)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(dataPoints.length, (index) {
                          return FlSpot(
                              index.toDouble(), (index + 1).toDouble());
                        }), // Cumulative count
                        isCurved: true,
                        color: Colors.green,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.green.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewCards() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _giftingStatsFuture,
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
                    const Color(0xFF00BFA5), // Brand Green
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
                    const Color(0xFF00BFA5), // Brand Green
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
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: Containers.glassCard(context).copyWith(
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularGifts() {
    return FutureBuilder<List<GiftModel>>(
      future: _popularGiftsFuture,
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

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: gifts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final gift = gifts[index];
            return Container(
              decoration: Containers.glassCard(context),
              child: ListTile(
                onTap: () => HapticFeedback.lightImpact(),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: RarityHelper.getColor(gift.rarity)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.card_giftcard,
                    color: RarityHelper.getColor(gift.rarity),
                  ),
                ),
                title: Text(
                  gift.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${gift.soldCount} purchases'),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
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
