import 'package:flutter/material.dart';
import 'package:freegram/services/daily_reward_service.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class DailyRewardDialog extends StatefulWidget {
  final String userId;
  final int currentStreak;

  const DailyRewardDialog({
    Key? key,
    required this.userId,
    required this.currentStreak,
  }) : super(key: key);

  @override
  State<DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends State<DailyRewardDialog> {
  late DailyRewardService _dailyRewardService;
  bool _isLoading = false;
  DailyReward? _claimedReward;

  @override
  void initState() {
    super.initState();
    _dailyRewardService = locator<DailyRewardService>();
  }

  Future<void> _claimReward() async {
    if (_isLoading) return; // Prevent double-clicking

    setState(() => _isLoading = true);
    try {
      final reward = await _dailyRewardService.claimReward(widget.userId);
      if (mounted) {
        setState(() {
          _claimedReward = reward;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);

        String errorMessage = "Failed to claim reward";
        if (e.toString().contains('already claimed')) {
          errorMessage = "You've already claimed today's reward!";
        } else if (e.toString().contains('User not found')) {
          errorMessage = "Account error. Please try again.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
        // Close dialog on error
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Daily Reward",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Login Streak: ${widget.currentStreak} Days",
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 24),
            _buildDaysGrid(),
            const SizedBox(height: 24),
            if (_claimedReward != null)
              Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    "You received ${_claimedReward!.coins} coins!",
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Awesome!"),
                  ),
                ],
              )
            else
              _isLoading
                  ? const AppProgressIndicator()
                  : ElevatedButton(
                      onPressed: _claimReward,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text(
                        "Claim Reward",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: List.generate(7, (index) {
        final day = index + 1;
        final reward = _dailyRewardService.getRewardForDay(day);
        // If user hasn't claimed today, their streak is effectively "pending increment".
        // Let's assume passed streak is what they have *completed*.
        // So the day to claim is streak + 1.

        final dayToClaim = (widget.currentStreak % 7) + 1;
        final isCompleted = day < dayToClaim;
        final isCurrent = day == dayToClaim;

        return _DayCard(
          day: day,
          coins: reward.coins,
          isBigReward: reward.isBigReward,
          state: isCompleted
              ? _DayState.completed
              : isCurrent
                  ? _DayState.current
                  : _DayState.locked,
        );
      }),
    );
  }
}

enum _DayState { locked, current, completed }

class _DayCard extends StatelessWidget {
  final int day;
  final int coins;
  final bool isBigReward;
  final _DayState state;

  const _DayCard({
    required this.day,
    required this.coins,
    required this.isBigReward,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    Color textColor;

    switch (state) {
      case _DayState.completed:
        bgColor = Colors.green.withOpacity(0.2);
        borderColor = Colors.green;
        textColor = Colors.green;
        break;
      case _DayState.current:
        bgColor = Colors.amber.withOpacity(0.2);
        borderColor = Colors.amber;
        textColor = Colors.black87;
        break;
      case _DayState.locked:
        bgColor = Colors.grey.withOpacity(0.1);
        borderColor = Colors.grey.withOpacity(0.3);
        textColor = Colors.grey;
        break;
    }

    return Container(
      width: 60,
      height: 80,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Day $day",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Icon(
            Icons.monetization_on,
            size: 20,
            color: state == _DayState.locked ? Colors.grey : Colors.amber,
          ),
          const SizedBox(height: 4),
          Text(
            "$coins",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
