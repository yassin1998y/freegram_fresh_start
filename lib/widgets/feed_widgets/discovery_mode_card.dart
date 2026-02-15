// lib/widgets/feed_widgets/discovery_mode_card.dart
import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/screens/search_screen.dart';

class DiscoveryModeCard extends StatelessWidget {
  const DiscoveryModeCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMD,
        vertical: DesignTokens.spaceXL,
      ),
      padding: const EdgeInsets.all(DesignTokens.spaceXL),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(DesignTokens.spaceMD),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.explore,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLG),
          const Text(
            'Your Feed is Quiet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceSM),
          Text(
            'Follow people and pages to see what\'s happening in the world.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXL),
          ElevatedButton(
            onPressed: () {
              // Task 4: Context-free navigation
              locator<NavigationService>().navigateTo(const SearchScreen());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceXL,
                vertical: DesignTokens.spaceMD,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Explore Now',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
