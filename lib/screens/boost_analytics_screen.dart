// lib/screens/boost_analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:freegram/models/post_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:intl/intl.dart';

class BoostAnalyticsScreen extends StatelessWidget {
  final PostModel post;

  const BoostAnalyticsScreen({
    Key? key,
    required this.post,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 SCREEN: boost_analytics_screen.dart');
    final theme = Theme.of(context);
    final boostStats = post.boostStats ?? {};
    final impressions = boostStats['impressions'] as int? ?? 0;
    final clicks = boostStats['clicks'] as int? ?? 0;
    final reach = boostStats['reach'] as int? ?? 0;
    final engagement = boostStats['engagement'] as int? ?? 0;

    // Calculate engagement rate
    final engagementRate = impressions > 0
        ? ((engagement / impressions) * 100).toStringAsFixed(1)
        : '0.0';

    // Calculate CTR (Click-Through Rate)
    final ctr = impressions > 0
        ? ((clicks / impressions) * 100).toStringAsFixed(2)
        : '0.00';

    // Check if boost is still active
    final isActive = post.isBoosted &&
        post.boostEndTime != null &&
        post.boostEndTime!.toDate().isAfter(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Boost Analytics',
          style: theme.textTheme.titleLarge,
        ),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Boost Status Card
            Card(
              color: isActive
                  ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                  : theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMD),
                child: Row(
                  children: [
                    Icon(
                      isActive ? Icons.trending_up : Icons.trending_down,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(
                              DesignTokens.opacityMedium,
                            ),
                      size: DesignTokens.iconLG,
                    ),
                    const SizedBox(width: DesignTokens.spaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isActive ? 'Boost Active' : 'Boost Ended',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (post.boostEndTime != null)
                            Text(
                              isActive
                                  ? 'Ends: ${DateFormat('MMM d, y').add_jm().format(post.boostEndTime!.toDate())}'
                                  : 'Ended: ${DateFormat('MMM d, y').add_jm().format(post.boostEndTime!.toDate())}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  DesignTokens.opacityMedium,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLG),

            // Metrics Overview
            Text(
              'Performance Overview',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),

            // Metrics Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    theme,
                    'Impressions',
                    _formatNumber(impressions),
                    Icons.visibility,
                    theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceSM),
                Expanded(
                  child: _buildMetricCard(
                    theme,
                    'Reach',
                    _formatNumber(reach),
                    Icons.people,
                    SemanticColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceSM),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    theme,
                    'Clicks',
                    _formatNumber(clicks),
                    Icons.touch_app,
                    SemanticColors.warning,
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceSM),
                Expanded(
                  child: _buildMetricCard(
                    theme,
                    'Engagement',
                    _formatNumber(engagement),
                    Icons.favorite,
                    SemanticColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceLG),

            // Engagement Rate & CTR
            Text(
              'Engagement Metrics',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMD),
                child: Column(
                  children: [
                    _buildStatRow(
                      theme,
                      'Engagement Rate',
                      '$engagementRate%',
                      Icons.trending_up,
                    ),
                    Divider(
                      color: theme.colorScheme.onSurface.withOpacity(
                        DesignTokens.opacityMedium,
                      ),
                    ),
                    _buildStatRow(
                      theme,
                      'Click-Through Rate (CTR)',
                      '$ctr%',
                      Icons.mouse,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLG),

            // Breakdown Section
            Text(
              'Breakdown',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBreakdownRow(
                      theme,
                      'Total Impressions',
                      _formatNumber(impressions),
                      Icons.remove_red_eye,
                    ),
                    const SizedBox(height: DesignTokens.spaceMD),
                    _buildBreakdownRow(
                      theme,
                      'Unique Reach',
                      _formatNumber(reach),
                      Icons.person_outline,
                    ),
                    const SizedBox(height: DesignTokens.spaceMD),
                    _buildBreakdownRow(
                      theme,
                      'Total Clicks',
                      _formatNumber(clicks),
                      Icons.ads_click,
                    ),
                    const SizedBox(height: DesignTokens.spaceMD),
                    _buildBreakdownRow(
                      theme,
                      'Total Engagement',
                      _formatNumber(engagement),
                      Icons.favorite_border,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: DesignTokens.elevation2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: DesignTokens.iconXL,
            ),
            const SizedBox(height: DesignTokens.spaceSM),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceXS),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(
                  DesignTokens.opacityMedium,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: DesignTokens.iconMD,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: DesignTokens.spaceMD),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: DesignTokens.iconMD,
          color: theme.colorScheme.onSurface.withOpacity(
            DesignTokens.opacityMedium,
          ),
        ),
        const SizedBox(width: DesignTokens.spaceMD),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
