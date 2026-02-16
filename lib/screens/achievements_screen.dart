import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/achievement_model.dart';
import 'package:freegram/repositories/achievement_repository.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/island_popup.dart';
import 'package:flutter/services.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _achievementRepo = locator<AchievementRepository>();

  @override
  void initState() {
    super.initState();
    _achievementRepo.seedAchievements();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: Text("Please log in to view achievements")),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: StreamBuilder<List<AchievementModel>>(
        stream: _achievementRepo.getAchievements(),
        builder: (context, achievementsSnapshot) {
          if (achievementsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AppProgressIndicator());
          }

          if (achievementsSnapshot.hasError) {
            return _buildErrorState();
          }

          if (!achievementsSnapshot.hasData ||
              achievementsSnapshot.data!.isEmpty) {
            return const Center(child: Text("No achievements available"));
          }

          final achievements = achievementsSnapshot.data!;

          return StreamBuilder<List<UserAchievementProgress>>(
            stream: _achievementRepo.getUserProgress(currentUser.uid),
            builder: (context, progressSnapshot) {
              final progressMap = <String, UserAchievementProgress>{};
              if (progressSnapshot.hasData) {
                for (final progress in progressSnapshot.data!) {
                  progressMap[progress.achievementId] = progress;
                }
              }

              // Group by category
              final grouped = <AchievementCategory, List<AchievementModel>>{};
              for (final achievement in achievements) {
                grouped
                    .putIfAbsent(achievement.category, () => [])
                    .add(achievement);
              }

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Header / AppBar
                  SliverAppBar(
                    floating: true,
                    pinned: true,
                    backgroundColor: theme.scaffoldBackgroundColor,
                    elevation: 0,
                    title: Text(
                      "Achievements",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: DesignTokens.letterSpacingTight,
                      ),
                    ),
                  ),

                  // Stats Dashboard
                  SliverPadding(
                    padding: const EdgeInsets.all(DesignTokens.spaceLG),
                    sliver: SliverToBoxAdapter(
                      child: _buildStatsDashboard(progressMap, achievements),
                    ),
                  ),

                  // Achievement Categories
                  ...grouped.entries.map((entry) {
                    return SliverMainAxisGroup(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            DesignTokens.spaceLG,
                            DesignTokens.spaceLG,
                            DesignTokens.spaceLG,
                            DesignTokens.spaceMD,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: Text(
                              _getCategoryName(entry.key).toUpperCase(),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceLG),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final achievement = entry.value[index];
                                final progress = progressMap[achievement.id];
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: DesignTokens.spaceMD),
                                  child: _AchievementCard(
                                    achievement: achievement,
                                    progress: progress,
                                    onClaim: () => _claimReward(
                                        currentUser.uid, achievement.id),
                                  ),
                                );
                              },
                              childCount: entry.value.length,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),

                  const SliverPadding(
                      padding: EdgeInsets.only(bottom: DesignTokens.spaceXXXL)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text("Failed to load achievements",
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
            style: ElevatedButton.styleFrom(
              backgroundColor: SonarPulseTheme.primaryAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsDashboard(
    Map<String, UserAchievementProgress> progressMap,
    List<AchievementModel> achievements,
  ) {
    final theme = Theme.of(context);
    final completed = progressMap.values.where((p) => p.isCompleted).length;
    final total = achievements.length;
    final progressVal = total > 0 ? (completed / total) : 0.0;

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceLG),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total Progress",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    "$completed completed",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMD,
                  vertical: DesignTokens.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: SonarPulseTheme.primaryAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                ),
                child: Text(
                  "${(progressVal * 100).toStringAsFixed(0)}%",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: SonarPulseTheme.primaryAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceLG),
          ClipRRect(
            borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
            child: LinearProgressIndicator(
              value: progressVal,
              minHeight: 8,
              backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  SonarPulseTheme.primaryAccent),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLG),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                icon: Icons.emoji_events_outlined,
                label: "Unlocked",
                value: "$completed",
                color: SonarPulseTheme.primaryAccent,
              ),
              _StatItem(
                icon: Icons.auto_awesome_outlined,
                label: "Remaining",
                value: "${total - completed}",
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCategoryName(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.social:
        return "🤝 Social";
      case AchievementCategory.spending:
        return "💰 Spending";
      case AchievementCategory.collection:
        return "🎁 Collection";
      case AchievementCategory.engagement:
        return "🔥 Engagement";
      case AchievementCategory.content:
        return "📱 Content";
    }
  }

  Future<void> _claimReward(String userId, String achievementId) async {
    try {
      HapticFeedback.mediumImpact();
      await _achievementRepo.claimReward(userId, achievementId);
      if (!mounted) return;

      showIslandPopup(
        context: context,
        message: "Reward claimed! 🎉",
        icon: Icons.celebration,
      );
    } catch (e) {
      if (!mounted) return;
      showIslandPopup(
        context: context,
        message: "Error: $e",
        icon: Icons.error_outline,
      );
    }
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: DesignTokens.iconLG, color: color),
        const SizedBox(height: DesignTokens.spaceXS),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
        ),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final AchievementModel achievement;
  final UserAchievementProgress? progress;
  final VoidCallback onClaim;

  const _AchievementCard({
    required this.achievement,
    required this.progress,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentValue = progress?.currentValue ?? 0;
    final progressPercent =
        progress?.getProgress(achievement.targetValue) ?? 0.0;
    final isCompleted = progress?.isCompleted ?? false;
    final rewardClaimed = progress?.rewardClaimed ?? false;

    final isLocked = !isCompleted;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spaceLG),
        decoration: Containers.glassCard(context).copyWith(
          border: Border.all(
            color: isCompleted
                ? SonarPulseTheme.primaryAccent.withValues(alpha: 0.3)
                : theme.dividerColor.withValues(alpha: 0.1),
            width: 1.0,
          ),
          boxShadow: isCompleted && !rewardClaimed
              ? [
                  BoxShadow(
                    color:
                        SonarPulseTheme.primaryAccent.withValues(alpha: 0.05),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildTierIcon(context, isLocked),
                const SizedBox(width: DesignTokens.spaceLG),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievement.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isLocked
                              ? SemanticColors.textPrimary(context)
                                  .withValues(alpha: 0.6)
                              : SemanticColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        achievement.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: SemanticColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCompleted && !rewardClaimed)
                  _buildClaimButton()
                else if (rewardClaimed)
                  const Icon(
                    Icons.check_circle,
                    color: SonarPulseTheme.primaryAccent,
                    size: DesignTokens.iconMD,
                  ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceLG),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                    child: LinearProgressIndicator(
                      value: progressPercent,
                      minHeight: 6,
                      backgroundColor:
                          theme.dividerColor.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCompleted
                            ? SonarPulseTheme.primaryAccent
                            : SonarPulseTheme.primaryAccent
                                .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceLG),
                Text(
                  "$currentValue/${achievement.targetValue}",
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLocked
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            _buildRewardSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimButton() {
    return ElevatedButton(
      onPressed: onClaim,
      style: ElevatedButton.styleFrom(
        backgroundColor: SonarPulseTheme.primaryAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
        ),
      ),
      child: const Text(
        "Claim",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildRewardSection(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.monetization_on, size: 14, color: Colors.amber.shade700),
        const SizedBox(width: 4),
        Text(
          "${achievement.rewardCoins} coins",
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        if (achievement.rewardBadgeId != null) ...[
          const SizedBox(width: 16),
          Icon(Icons.shield_outlined,
              size: 14, color: SonarPulseTheme.primaryAccent),
          const SizedBox(width: 4),
          Text(
            "Badge Unlocked",
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: SonarPulseTheme.primaryAccent,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTierIcon(BuildContext context, bool isLocked) {
    Color color;
    IconData icon = Icons.emoji_events_rounded;

    switch (achievement.tier) {
      case AchievementTier.bronze:
        color = const Color(0xFFCD7F32);
        break;
      case AchievementTier.silver:
        color = const Color(0xFFC0C0C0);
        break;
      case AchievementTier.gold:
        color = const Color(0xFFFFD700);
        break;
      case AchievementTier.platinum:
        color = const Color(0xFFE5E4E2);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      decoration: BoxDecoration(
        color: (isLocked ? Colors.grey : color).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: isLocked ? Colors.grey.withValues(alpha: 0.4) : color,
        size: DesignTokens.iconLG,
      ),
    );
  }
}
