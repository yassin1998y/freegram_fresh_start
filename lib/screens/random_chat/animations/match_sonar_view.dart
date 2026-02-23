import 'package:flutter/material.dart';
import 'package:freegram/theme/app_theme.dart';

class MatchSonarView extends StatefulWidget {
  final double size;
  const MatchSonarView({super.key, this.size = 200});

  @override
  State<MatchSonarView> createState() => _MatchSonarViewState();
}

class _MatchSonarViewState extends State<MatchSonarView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildRing(0.0),
          _buildRing(0.33),
          _buildRing(0.66),
          // User Avatar Placeholder
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: SonarPulseTheme.primaryAccent.withValues(alpha: 0.5),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRing(double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double progress = (_controller.value + delay) % 1.0;
        double opacity = (1.0 - progress).clamp(0.0, 1.0);
        double scale = 0.5 + (progress * 1.5);

        return Opacity(
          opacity: opacity * 0.5,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: SonarPulseTheme.primaryAccent,
                  width: 2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
