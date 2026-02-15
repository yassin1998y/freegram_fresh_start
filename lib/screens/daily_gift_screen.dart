import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_inventory_model.dart';
import 'package:freegram/repositories/gift_repository.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:confetti/confetti.dart';

/// Daily free gift claim screen
class DailyGiftScreen extends StatefulWidget {
  const DailyGiftScreen({super.key});

  @override
  State<DailyGiftScreen> createState() => _DailyGiftScreenState();
}

class _DailyGiftScreenState extends State<DailyGiftScreen>
    with SingleTickerProviderStateMixin {
  final _giftRepo = locator<GiftRepository>();
  late ConfettiController _confettiController;
  late AnimationController _claimAnimationController;
  late Animation<double> _scaleAnimation;

  Timer? _countdownTimer;
  Map<String, dynamic>? _giftStatus;
  bool _isLoading = true;
  bool _isClaiming = false;
  OwnedGift? _claimedGift;
  Duration _timeUntilNext = Duration.zero;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _claimAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _claimAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    _loadGiftStatus();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _claimAnimationController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadGiftStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final status = await _giftRepo.getDailyGiftStatus(currentUser.uid);
      setState(() {
        _giftStatus = status;
        _isLoading = false;
      });

      if (status['canClaim'] == false && status['nextClaimAt'] != null) {
        _startCountdown(DateTime.parse(status['nextClaimAt']));
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading gift status: $e')),
        );
      }
    }
  }

  void _startCountdown(DateTime nextClaimTime) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final difference = nextClaimTime.difference(now);

      if (difference.isNegative) {
        timer.cancel();
        _loadGiftStatus(); // Refresh status
      } else {
        setState(() {
          _timeUntilNext = difference;
        });
      }
    });
  }

  Future<void> _claimGift() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isClaiming = true);
    HapticHelper.medium();

    try {
      final gift = await _giftRepo.claimDailyGift(currentUser.uid);

      setState(() {
        _claimedGift = gift;
        _isClaiming = false;
      });

      // Start animations
      _claimAnimationController.forward();
      _confettiController.play();
      HapticHelper.success();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      Text('Daily gift claimed! 🎁\n${gift.giftMessage ?? ""}'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Reload status after a delay
      await Future.delayed(const Duration(seconds: 3));
      _loadGiftStatus();
    } catch (e) {
      setState(() => _isClaiming = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error claiming gift: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Free Gift'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _buildContent(),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.1,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: AppProgressIndicator());
    }

    if (_claimedGift != null) {
      return _buildClaimedState();
    }

    final canClaim = _giftStatus?['canClaim'] ?? false;
    final streak = _giftStatus?['streak'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Gift icon
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.pink.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.card_giftcard,
              size: 80,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 32),

          // Title
          Text(
            'Daily Free Gift',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 8),

          Text(
            'Claim your free gift every day!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 32),

          // Streak display
          _buildStreakCard(streak),

          const SizedBox(height: 32),

          // Claim button or countdown
          if (canClaim) _buildClaimButton() else _buildCountdown(),

          const SizedBox(height: 24),

          // Info card
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildStreakCard(int streak) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade100, Colors.amber.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_fire_department,
              color: Colors.orange.shade700, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Streak',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$streak ${streak == 1 ? "day" : "days"}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClaimButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isClaiming ? null : _claimGift,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: _isClaiming
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_giftcard, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Claim Your Free Gift',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCountdown() {
    final hours = _timeUntilNext.inHours;
    final minutes = _timeUntilNext.inMinutes.remainder(60);
    final seconds = _timeUntilNext.inSeconds.remainder(60);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(
            'Next gift available in:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimeUnit(hours.toString().padLeft(2, '0'), 'Hours'),
              const SizedBox(width: 8),
              Text(':',
                  style: TextStyle(fontSize: 32, color: Colors.grey.shade700)),
              const SizedBox(width: 8),
              _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'Minutes'),
              const SizedBox(width: 8),
              Text(':',
                  style: TextStyle(fontSize: 32, color: Colors.grey.shade700)),
              const SizedBox(width: 8),
              _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'Seconds'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'How it works',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem('Claim one free gift every 24 hours'),
          _buildInfoItem('Build your streak by claiming daily'),
          _buildInfoItem('Random common gift each time'),
          _buildInfoItem('Don\'t miss a day to keep your streak!'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimedState() {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.teal.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Gift Claimed!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
              ),
              const SizedBox(height: 16),
              if (_claimedGift?.giftMessage != null)
                Text(
                  _claimedGift!.giftMessage!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go to Inventory'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
