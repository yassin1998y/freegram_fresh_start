import 'package:flutter/material.dart';
import 'package:freegram/utils/haptic_helper.dart';
import 'package:freegram/theme/app_theme.dart';
import 'dart:async';

class RecipientGiftOverlay extends StatefulWidget {
  final String giftId;
  final String giftName;
  final String senderName;
  final VoidCallback onFinished;

  const RecipientGiftOverlay({
    super.key,
    required this.giftId,
    required this.giftName,
    required this.senderName,
    required this.onFinished,
  });

  @override
  State<RecipientGiftOverlay> createState() => _RecipientGiftOverlayState();
}

class _RecipientGiftOverlayState extends State<RecipientGiftOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    _controller.forward();

    // Trigger heavy impact on show
    HapticHelper.heavyImpact();

    // Auto-dismiss after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onFinished());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getGifAsset() {
    final gid = widget.giftId.toLowerCase();
    final gname = widget.giftName.toLowerCase();

    if (gid.contains('teddy') || gname.contains('teddy')) {
      return 'assets/seed_data/teddy_bear.gif';
    } else if (gid.contains('rose') || gname.contains('rose')) {
      return 'assets/seed_data/red_rose_animation.gif';
    } else if (gid.contains('ring') || gname.contains('ring')) {
      return 'assets/seed_data/diamond_ring.gif';
    } else if (gid.contains('balloon') || gname.contains('balloon')) {
      return 'assets/seed_data/heart_balloon.gif';
    } else if (gid.contains('party') || gname.contains('party')) {
      return 'assets/seed_data/party_popper.gif';
    }
    return 'assets/seed_data/teddy_bear.gif'; // Fallback
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.8),
      child: Stack(
        children: [
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The Gift Asset
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: SonarPulseTheme.primaryAccent
                                .withValues(alpha: 0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        _getGifAsset(),
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // High-Intensity Label
                    Text(
                      "NEW GIFT FROM",
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white70,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.senderName.toUpperCase(),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: SonarPulseTheme.primaryAccent,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24, width: 1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.giftName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
