import 'package:flutter/material.dart';
import 'package:freegram/models/achievement_model.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/achievement_repository.dart';
import 'package:freegram/repositories/analytics_repository.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// The "Badge Insight" system that bridges UserAvatar with Achievements.
void showBadgeInsight(BuildContext context,
    {String? badgeId, String? badgeUrl}) async {
  if ((badgeId == null || badgeId.isEmpty) &&
      (badgeUrl == null || badgeUrl.isEmpty)) {
    return;
  }

  // 1. Haptic Standard: Signify "discovery"
  HapticHelper.lightImpact();

  // 2. Analytics Hook: Track popularity
  locator<AnalyticsRepository>()
      .trackBadgeClick(badgeId ?? badgeUrl ?? 'unknown');

  // 3. Fetch achievement info that grants this badge
  final AchievementModel? achievement;
  if (badgeId != null && badgeId.isNotEmpty) {
    achievement =
        await locator<AchievementRepository>().getAchievementByBadgeId(badgeId);
  } else {
    achievement = await locator<AchievementRepository>()
        .getAchievementByBadgeUrl(badgeUrl!);
  }

  if (achievement == null) return;

  final model = achievement;

  if (!context.mounted) return;

  // 4. Show Sleek Modal (Pure Styled Dialog)
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
          border: Border.all(
            color: SonarPulseTheme.primaryAccent,
            width: 1.0, // 1px Border Rule
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button at top right
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close,
                  size: 20,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spaceXL,
                0,
                DesignTokens.spaceXL,
                DesignTokens.spaceXL,
              ),
              child: Column(
                children: [
                  // Large Badge Icon with Pure styling
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          SonarPulseTheme.primaryAccent.withValues(alpha: 0.05),
                      border: Border.all(
                        color: SonarPulseTheme.primaryAccent.withValues(
                          alpha: 0.3,
                        ),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: SonarPulseTheme.primaryAccent
                              .withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(DesignTokens.spaceMD),
                      child: CachedNetworkImage(
                        imageUrl: model.iconUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) =>
                            const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SonarPulseTheme.primaryAccent,
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.emoji_events_outlined,
                          color: SonarPulseTheme.primaryAccent,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceLG),

                  // Title: [Badge Name]
                  Text(
                    model.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: DesignTokens.spaceSM),

                  // Subtitle: "Earned by [Requirement text]"
                  Text(
                    "Earned by ${model.description}",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: DesignTokens.opacityHigh),
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: DesignTokens.spaceXL),

                  // Tier indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceMD,
                      vertical: DesignTokens.spaceXS,
                    ),
                    decoration: BoxDecoration(
                      color:
                          SonarPulseTheme.primaryAccent.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusLG),
                      border: Border.all(
                        color: SonarPulseTheme.primaryAccent
                            .withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      model.tier.name.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: SonarPulseTheme.primaryAccent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
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
  );
}
