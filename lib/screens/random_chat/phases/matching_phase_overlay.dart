import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

class MatchingPhaseOverlay extends StatelessWidget {
  const MatchingPhaseOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // Interaction Guard: Block taps to widgets behind
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // 1. Solid dark background for matching transition
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black87,
              ),
            ),
          ),

          // 2. Central Shimmer Lock & Handshake UI
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Lock Icon with Shimmer
                Shimmer.fromColors(
                  baseColor: SonarPulseTheme.primaryAccent,
                  highlightColor: Colors.white70,
                  period: const Duration(milliseconds: 1500),
                  child: Container(
                    padding: const EdgeInsets.all(DesignTokens.spaceXL),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: SonarPulseTheme.primaryAccent,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: DesignTokens.spaceXL),

                // Connection Message
                Text(
                  'Securing Connection...',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                ),

                const SizedBox(height: DesignTokens.spaceMD),

                // Scanning Progress bar (Shimmering)
                SizedBox(
                  width: 200,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Shimmer.fromColors(
                      baseColor: Colors.white10,
                      highlightColor:
                          SonarPulseTheme.primaryAccent.withValues(alpha: 0.5),
                      child: Container(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: DesignTokens.spaceLG),

                Text(
                  'Connecting to partner via end-to-end encryption',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
