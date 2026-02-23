import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_event.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

class IdlePhaseOverlay extends StatelessWidget {
  const IdlePhaseOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Cinematic Vignette
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    Colors.transparent,
                    Colors.black45, // 0.4 opacity black at edges
                  ],
                  stops: [0.6, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 2. Top Bar
        Positioned(
          top: MediaQuery.of(context).padding.top + DesignTokens.spaceSM,
          left: DesignTokens.spaceMD,
          right: DesignTokens.spaceMD,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Coin Balance
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMD,
                  vertical: DesignTokens.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXXL),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars,
                        color: Colors.amber, size: DesignTokens.iconSM),
                    const SizedBox(width: DesignTokens.spaceXS),
                    Text(
                      '1,250', // Replace with real balance if available
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),

              // Exit Button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close,
                    color: Colors.white, size: DesignTokens.iconLG),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black26,
                  padding: const EdgeInsets.all(DesignTokens.spaceSM),
                ),
              ),
            ],
          ),
        ),

        // 3. Floating Side Buttons
        Positioned(
          right: DesignTokens.spaceMD,
          top: MediaQuery.of(context).size.height * 0.3,
          child: Column(
            children: [
              _SleekSideButton(
                icon: Icons.meeting_room_outlined,
                label: 'Lounge',
                onPressed: () {
                  // Navigate to Lounge
                },
              ),
              const SizedBox(height: DesignTokens.spaceLG),
              _SleekSideButton(
                icon: Icons.history_outlined,
                label: 'History',
                onPressed: () {
                  // Navigate to History
                },
              ),
            ],
          ),
        ),

        // 4. Bottom Center Action Area
        Positioned(
          bottom:
              MediaQuery.of(context).padding.bottom + DesignTokens.spaceXXXL,
          left: 0,
          right: 0,
          child: Column(
            children: [
              // Pulsing Start Button
              const _PulsingStartButton(),
              const SizedBox(height: DesignTokens.spaceXL),

              // Filters Action
              IconButton(
                onPressed: () {
                  // Open Filters Sheet
                },
                icon: const Icon(Icons.tune,
                    color: Colors.white, size: DesignTokens.iconLG),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white10,
                  padding: const EdgeInsets.all(DesignTokens.spaceMD),
                  side: const BorderSide(color: Colors.white24, width: 0.5),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceSM),
              Text(
                'Filters',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SleekSideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _SleekSideButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: DesignTokens.iconLG),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white10,
            padding: const EdgeInsets.all(DesignTokens.spaceMD),
            side: const BorderSide(color: Colors.white24, width: 0.5),
          ),
        ),
        const SizedBox(height: DesignTokens.spaceXS),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontSize: DesignTokens.fontSizeXS,
              ),
        ),
      ],
    );
  }
}

class _PulsingStartButton extends StatefulWidget {
  const _PulsingStartButton();

  @override
  State<_PulsingStartButton> createState() => _PulsingStartButtonState();
}

class _PulsingStartButtonState extends State<_PulsingStartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: SonarPulseTheme.primaryAccent.withValues(alpha: 0.3),
                  blurRadius: _glowAnimation.value,
                  spreadRadius: _glowAnimation.value / 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact(); // Task 3: Start Searching Haptic
            context.read<RandomChatBloc>().add(const RandomChatStartSearching());
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  SonarPulseTheme.primaryAccent,
                  Color(0xFF009688),
                ],
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
