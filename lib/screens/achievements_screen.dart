import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/achievement_model.dart';
import 'package:freegram/repositories/achievement_repository.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

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
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view achievements")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Achievements"),
      ),
      body: StreamBuilder<List<AchievementModel>>(
        stream: _achievementRepo.getAchievements(),
        builder: (context, achievementsSnapshot) {
          if (achievementsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AppProgressIndicator());
          }

          if (achievementsSnapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    "Failed to load achievements",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry"),
                  ),
                ],
              ),
            );
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

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatsCard(progressMap, achievements),
                  const SizedBox(height: 16),
                  ...grouped.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _getCategoryName(entry.key),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        ...entry.value.map((achievement) {
                          final progress = progressMap[achievement.id];
                          return _AchievementCard(
                            achievement: achievement,
                            progress: progress,
                            onClaim: () =>
                                _claimReward(currentUser.uid, achievement.id),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatsCard(
    Map<String, UserAchievementProgress> progressMap,
    List<AchievementModel> achievements,
  ) {
    final completed = progressMap.values.where((p) => p.isCompleted).length;
    final total = achievements.length;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.emoji_events,
              label: "Completed",
              value: "$completed/$total",
              color: Colors.amber,
            ),
            _StatItem(
              icon: Icons.trending_up,
              label: "Progress",
              value: "${((completed / total) * 100).toStringAsFixed(0)}%",
              color: Colors.blue,
            ),
          ],
        ),
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
      await _achievementRepo.claimReward(userId, achievementId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Reward claimed successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to claim reward: $e")),
        );
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
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600]),
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
    final currentValue = progress?.currentValue ?? 0;
    final progressPercent =
        progress?.getProgress(achievement.targetValue) ?? 0.0;
    final isCompleted = progress?.isCompleted ?? false;
    final rewardClaimed = progress?.rewardClaimed ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildTierIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievement.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achievement.description,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (isCompleted && !rewardClaimed)
                  ElevatedButton(
                    onPressed: onClaim,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("Claim"),
                  )
                else if (rewardClaimed)
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? Colors.green : Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "$currentValue/${achievement.targetValue}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.monetization_on,
                    size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  "${achievement.rewardCoins} coins",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (achievement.rewardBadgeId != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.badge, size: 16, color: Colors.purple),
                  const SizedBox(width: 4),
                  const Text("+ Badge"),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierIcon() {
    Color color;
    IconData icon = Icons.emoji_events;

    switch (achievement.tier) {
      case AchievementTier.bronze:
        color = Colors.brown;
        break;
      case AchievementTier.silver:
        color = Colors.grey;
        break;
      case AchievementTier.gold:
        color = Colors.amber;
        break;
      case AchievementTier.platinum:
        color = Colors.cyan;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 32),
    );
  }
}
