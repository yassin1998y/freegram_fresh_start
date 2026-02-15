import 'package:flutter/material.dart';
import 'package:freegram/utils/chat_presence_constants.dart';
import 'package:lottie/lottie.dart';

/// Professional Typing Indicator Widget
///
/// Uses Lottie animation for a modern, fluid feel.
class ProfessionalTypingIndicator extends StatelessWidget {
  final Color? color;
  final double fontSize;

  const ProfessionalTypingIndicator({
    super.key,
    this.color,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 24,
                  child: Lottie.network(
                    'https://assets5.lottiefiles.com/packages/lf20_t9uon9ec.json',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to simple dots if network fails
                      return const _BouncingDots();
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  ChatPresenceConstants.labelTyping,
                  style: TextStyle(
                    color: color ?? Colors.grey[600],
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final val = (_controller.value + delay) % 1.0;
            final offset = -4 * (val < 0.5 ? val * 2 : (1 - val) * 2);

            return Transform.translate(
              offset: Offset(0, offset),
              child: Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
