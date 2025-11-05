// lib/screens/page_analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:freegram/services/page_analytics_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class PageAnalyticsScreen extends StatefulWidget {
  final String pageId;

  const PageAnalyticsScreen({
    Key? key,
    required this.pageId,
  }) : super(key: key);

  @override
  State<PageAnalyticsScreen> createState() => _PageAnalyticsScreenState();
}

class _PageAnalyticsScreenState extends State<PageAnalyticsScreen> {
  final PageAnalyticsService _analyticsService = PageAnalyticsService();
  PageAnalytics? _analytics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final analytics = await _analyticsService.getPageAnalytics(widget.pageId);
      setState(() {
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Analytics'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analytics == null
              ? const Center(child: Text('No analytics data available'))
              : RefreshIndicator(
                  onRefresh: _loadAnalytics,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Overview Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                context,
                                'Followers',
                                '${_analytics!.followerCount}',
                                Icons.people,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildMetricCard(
                                context,
                                'Posts',
                                '${_analytics!.postCount}',
                                Icons.post_add,
                                Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                context,
                                'Total Reach',
                                '${_analytics!.totalReach}',
                                Icons.visibility,
                                Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildMetricCard(
                                context,
                                'Profile Views',
                                '${_analytics!.profileViews}',
                                Icons.person_outline,
                                Colors.purple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Engagement Metrics
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Engagement Metrics',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                _buildMetricRow(
                                  context,
                                  'Total Reactions',
                                  '${_analytics!.totalReactions}',
                                  Icons.favorite,
                                ),
                                _buildMetricRow(
                                  context,
                                  'Total Comments',
                                  '${_analytics!.totalComments}',
                                  Icons.comment,
                                ),
                                _buildMetricRow(
                                  context,
                                  'Engagement Rate',
                                  '${_analytics!.engagementRate.toStringAsFixed(2)}%',
                                  Icons.trending_up,
                                ),
                                _buildMetricRow(
                                  context,
                                  'Avg Engagement/Post',
                                  '${_analytics!.averageEngagementPerPost.toStringAsFixed(1)}',
                                  Icons.bar_chart,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Top Posts
                        if (_analytics!.topPosts.isNotEmpty) ...[
                          Text(
                            'Top Performing Posts',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          ..._analytics!.topPosts.map((post) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text('${post.totalEngagement}'),
                                ),
                                title: Text(
                                  post.content.length > 50
                                      ? '${post.content.substring(0, 50)}...'
                                      : post.content,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  DateFormat('MMM d, y').format(post.timestamp),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.favorite,
                                            size: 16, color: Colors.red),
                                        Text('${post.reactions}'),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.comment,
                                            size: 16, color: Colors.blue),
                                        Text('${post.comments}'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 24),
                        ],

                        // Follower Growth Chart (Last 7 Days)
                        if (_analytics!.followerGrowth.isNotEmpty) ...[
                          Text(
                            'Follower Growth (Last 7 Days)',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: SizedBox(
                                height: 200,
                                child: _buildFollowerGrowthChart(),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Engagement History Chart (Last 7 Days)
                        if (_analytics!.engagementHistory.isNotEmpty) ...[
                          Text(
                            'Engagement History (Last 7 Days)',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: SizedBox(
                                height: 200,
                                child: _buildEngagementChart(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowerGrowthChart() {
    if (_analytics == null || _analytics!.followerGrowth.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final sortedEntries = _analytics!.followerGrowth.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final last7Days = sortedEntries.take(7).toList();
    final maxFollowers = _analytics!.followerCount > 0
        ? _analytics!.followerCount
        : (last7Days.map((e) => e.value).fold(0, (a, b) => a > b ? a : b) + 1);

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < last7Days.length) {
                  return Text(
                    DateFormat('MMM d').format(last7Days[value.toInt()].key),
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: last7Days.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.value.toDouble());
            }).toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        minY: 0,
        maxY: maxFollowers.toDouble(),
      ),
    );
  }

  Widget _buildEngagementChart() {
    if (_analytics == null || _analytics!.engagementHistory.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final sortedEntries = _analytics!.engagementHistory.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final last7Days = sortedEntries.take(7).toList();
    final maxEngagement =
        last7Days.map((e) => e.value).fold(0, (a, b) => a > b ? a : b) + 10;

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < last7Days.length) {
                  return Text(
                    DateFormat('MMM d').format(last7Days[value.toInt()].key),
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: true),
        barGroups: last7Days.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value.toDouble(),
                color: Colors.green,
                width: 16,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        maxY: maxEngagement.toDouble(),
      ),
    );
  }
}
