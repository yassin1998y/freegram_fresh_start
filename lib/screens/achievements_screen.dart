import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/achievement_model.dart';
import 'package:freegram/repositories/achievement_repository.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/island_popup.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/achievement/achievement_bloc.dart';
import 'package:freegram/blocs/achievement/achievement_event.dart';
import 'package:freegram/blocs/achievement/achievement_state.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:freegram/services/user_stream_provider.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/widgets/achievements/achievement_progress_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _achievementRepo = locator<AchievementRepository>();
  final _userRepo = locator<UserRepository>();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _notifiedAchievements = {};

  @override
  void initState() {
    super.initState();
    _achievementRepo.seedAchievements();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // This will be handled inside the BlocBuilder to access state
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

    return StreamBuilder<UserModel>(
      stream: UserStreamProvider().getUserStream(currentUser.uid),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: BlocConsumer<AchievementBloc, AchievementState>(
            listener: (context, state) {
              if (state is AchievementClaimSuccess) {
                HapticHelper.heavyImpact();
                showIslandPopup(
                  context: context,
                  message: "Reward claimed! 🎉",
                  icon: Icons.celebration,
                );
              }
              if (state is AchievementLoaded && state.newlyCompleted != null) {
                HapticHelper.heavyImpact();
                showIslandPopup(
                  context: context,
                  message: "Achievement: ${state.newlyCompleted!.name}! 🏆",
                  icon: Icons.emoji_events,
                );
                context
                    .read<AchievementBloc>()
                    .add(ConsumeAchievementCelebration());
              }
              if (state is AchievementError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message)),
                );
              }
            },
            builder: (context, state) {
              if (state is AchievementInitial || state is AchievementLoading) {
                return const Center(child: AppProgressIndicator());
              }

              if (state is AchievementError) {
                return _buildErrorState();
              }

              if (state is AchievementLoaded) {
                final achievements = state.allAchievements;
                final progressMap = {
                  for (var p in state.userProgress) p.achievementId: p
                };

                // Group by category
                final grouped = <AchievementCategory, List<AchievementModel>>{};
                for (final achievement in achievements) {
                  grouped
                      .putIfAbsent(achievement.category, () => [])
                      .add(achievement);
                }

                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    _checkHapticThresholds(state);
                    return false;
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
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
                          child:
                              _buildStatsDashboard(progressMap, achievements),
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
                                    final progress =
                                        progressMap[achievement.id];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: DesignTokens.spaceMD),
                                      child: _AchievementCard(
                                        achievement: achievement,
                                        progress: progress,
                                        nextTierAchievement: _getNextTier(
                                            achievement, entry.value),
                                        equippedBadgeId:
                                            userData?.equippedBadgeId,
                                        onClaim: () => _claimReward(
                                            currentUser.uid, achievement.id),
                                        onEquip: (badgeId, badgeUrl) =>
                                            _onBadgeToggle(
                                                currentUser.uid,
                                                badgeId,
                                                badgeUrl,
                                                userData?.equippedBadgeId),
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
                          padding:
                              EdgeInsets.only(bottom: DesignTokens.spaceXXXL)),
                    ],
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        );
      },
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

  void _claimReward(String userId, String achievementId) {
    context.read<AchievementBloc>().add(
          ClaimAchievementReward(userId: userId, achievementId: achievementId),
        );
  }

  void _onBadgeToggle(
      String userId, String badgeId, String badgeUrl, String? currentBadgeId) {
    HapticHelper.mediumImpact();
    if (badgeId == currentBadgeId) {
      _unequipBadge(userId);
    } else {
      _equipBadge(userId, badgeId, badgeUrl);
    }
  }

  void _equipBadge(String userId, String badgeId, String badgeUrl) {
    _userRepo.updateUserBadge(userId, badgeId, badgeUrl);
    showIslandPopup(
      context: context,
      message: "Badge Equipped! 🏆",
      icon: Icons.check_circle,
    );
  }

  void _unequipBadge(String userId) {
    _userRepo.clearUserBadge(userId);
    showIslandPopup(
      context: context,
      message: "Badge Unequipped",
      icon: Icons.remove_circle_outline,
    );
  }

  AchievementModel? _getNextTier(
      AchievementModel current, List<AchievementModel> categoryAchievements) {
    // Find the current index and return the next one if it exists
    final index = categoryAchievements.indexWhere((a) => a.id == current.id);
    if (index != -1 && index < categoryAchievements.length - 1) {
      return categoryAchievements[index + 1];
    }
    return null;
  }

  void _checkHapticThresholds(AchievementLoaded state) {
    // Simple logic: if a card is visible and progress > 90%, trigger haptic once
    // For a real implementation, we'd need to track scroll offset vs card positions
    // but here we'll trigger it when the state updates and progress crosses threshold
    for (var p in state.userProgress) {
      if (p.currentValue > 0 &&
          !p.isCompleted &&
          !_notifiedAchievements.contains(p.achievementId)) {
        final achievement =
            state.allAchievements.firstWhere((a) => a.id == p.achievementId);
        if (p.getProgress(achievement.targetValue) >= 0.9) {
          HapticHelper.mediumImpact();
          _notifiedAchievements.add(p.achievementId);
        }
      }
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

class _AchievementCard extends StatefulWidget {
  final AchievementModel achievement;
  final UserAchievementProgress? progress;
  final AchievementModel? nextTierAchievement;
  final String? equippedBadgeId;
  final VoidCallback onClaim;
  final Function(String, String) onEquip;

  const _AchievementCard({
    required this.achievement,
    required this.progress,
    this.nextTierAchievement,
    this.equippedBadgeId,
    required this.onClaim,
    required this.onEquip,
  });

  @override
  State<_AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<_AchievementCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _borderPulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _borderPulse = Tween<double>(begin: 0.1, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _updateAnimation();
  }

  @override
  void didUpdateWidget(_AchievementCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimation();
  }

  void _updateAnimation() {
    final progress =
        widget.progress?.getProgress(widget.achievement.targetValue) ?? 0.0;
    final isCompleted = widget.progress?.isCompleted ?? false;

    if (progress >= 0.9 && !isCompleted) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentValue = widget.progress?.currentValue ?? 0;
    final progressPercent =
        widget.progress?.getProgress(widget.achievement.targetValue) ?? 0.0;
    final isCompleted = widget.progress?.isCompleted ?? false;
    final rewardClaimed = widget.progress?.rewardClaimed ?? false;

    final isLocked = !isCompleted;
    final isUnlocked = isCompleted &&
        rewardClaimed &&
        widget.achievement.rewardBadgeId != null;
    final isEquipped = isUnlocked &&
        widget.equippedBadgeId == widget.achievement.rewardBadgeId;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(DesignTokens.spaceLG),
            decoration: Containers.glassCard(context).copyWith(
              border: Border.all(
                color: isEquipped
                    ? SonarPulseTheme.primaryAccent
                    : (isCompleted
                        ? SonarPulseTheme.primaryAccent.withValues(alpha: 0.3)
                        : (progressPercent >= 0.9 && !isCompleted)
                            ? SonarPulseTheme.primaryAccent
                                .withValues(alpha: _borderPulse.value)
                            : theme.dividerColor.withValues(alpha: 0.1)),
                width: 1.0,
              ),
              boxShadow: isEquipped
                  ? [
                      BoxShadow(
                        color: SonarPulseTheme.primaryAccent
                            .withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ]
                  : (isCompleted && !rewardClaimed
                      ? [
                          BoxShadow(
                            color: SonarPulseTheme.primaryAccent
                                .withValues(alpha: 0.05),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ]
                      : null),
            ),
            child: child,
          );
        },
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
                        widget.achievement.name,
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
                        widget.achievement.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: SemanticColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCompleted && !rewardClaimed)
                  Expanded(child: _buildClaimButton())
                else if (rewardClaimed)
                  const Icon(
                    Icons.check_circle,
                    color: SonarPulseTheme.primaryAccent,
                    size: DesignTokens.iconMD,
                  ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceLG),

            // Progression Roadmap
            AchievementProgressBar(
              progress: progressPercent,
              isCompleted: isCompleted,
              trailing: widget.nextTierAchievement != null && !isCompleted
                  ? Opacity(
                      opacity: 0.3, // Ghost State
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: widget.nextTierAchievement!.iconUrl,
                            fit: BoxFit.contain,
                            errorWidget: (context, url, error) => const Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),

            const SizedBox(height: DesignTokens.spaceSM),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCompleted
                      ? "Completed!"
                      : "Road to ${widget.achievement.targetValue}",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "$currentValue / ${widget.achievement.targetValue}",
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLocked
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: DesignTokens.spaceMD),
            _buildRewardSection(theme, isUnlocked, isEquipped),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimButton() {
    return ElevatedButton(
      onPressed: widget.onClaim,
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

  Widget _buildRewardSection(
      ThemeData theme, bool isUnlocked, bool isEquipped) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.monetization_on, size: 14, color: Colors.amber.shade700),
            const SizedBox(width: 4),
            Text(
              "${widget.achievement.rewardCoins} coins",
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            if (widget.achievement.rewardBadgeId != null && !isUnlocked) ...[
              const SizedBox(width: 16),
              const Icon(Icons.shield_outlined,
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
        ),
        if (isUnlocked)
          isEquipped ? _buildEquippedLabel(theme) : _buildEquipButton(theme),
      ],
    );
  }

  Widget _buildEquipButton(ThemeData theme) {
    return TextButton(
      onPressed: () => widget.onEquip(
          widget.achievement.rewardBadgeId!, widget.achievement.iconUrl),
      style: TextButton.styleFrom(
        foregroundColor: SonarPulseTheme.primaryAccent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        "Equip",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildEquippedLabel(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle,
            color: SonarPulseTheme.primaryAccent, size: 14),
        const SizedBox(width: 4),
        Text(
          "Equipped",
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: SonarPulseTheme.primaryAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildTierIcon(BuildContext context, bool isLocked) {
    Color color;
    IconData icon = Icons.emoji_events_rounded;

    switch (widget.achievement.tier) {
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
