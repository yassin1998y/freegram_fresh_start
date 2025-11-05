// lib/screens/feed/nearby_feed_tab.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Placeholder screen for Reels feature
/// This tab will be used for Reels content in the future
class NearbyFeedTab extends StatefulWidget {
  const NearbyFeedTab({Key? key}) : super(key: key);

  @override
  State<NearbyFeedTab> createState() => _NearbyFeedTabState();
}

class _NearbyFeedTabState extends State<NearbyFeedTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: DesignTokens.iconXXL * 2,
              color: theme.colorScheme.primary.withValues(
                alpha: DesignTokens.opacityMedium,
              ),
            ),
            SizedBox(height: DesignTokens.spaceLG),
            Text(
              'Reels Coming Soon',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: DesignTokens.spaceSM),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: DesignTokens.spaceXL),
              child: Text(
                'Short-form vertical videos will be available here soon.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: DesignTokens.opacityMedium,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
