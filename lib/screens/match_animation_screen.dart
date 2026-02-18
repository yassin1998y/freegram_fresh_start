import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/chat_repository.dart';
import 'package:freegram/screens/improved_chat_screen.dart';

class MatchAnimationScreen extends StatefulWidget {
  final UserModel currentUser;
  final UserModel matchedUser;

  const MatchAnimationScreen({
    super.key,
    required this.currentUser,
    required this.matchedUser,
  });

  @override
  State<MatchAnimationScreen> createState() => _MatchAnimationScreenState();
}

class _MatchAnimationScreenState extends State<MatchAnimationScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _confettiController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _buttonSlideAnimation;
  final List<ConfettiParticle> _confettiParticles = [];

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: match_animation_screen.dart');

    // Haptic celebration
    HapticFeedback.heavyImpact();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 150.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    _buttonSlideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutBack),
      ),
    );

    // Generate confetti particles
    final random = Random();
    for (int i = 0; i < 100; i++) {
      _confettiParticles.add(
        ConfettiParticle(
          x: random.nextDouble(),
          y: -0.1 - (random.nextDouble() * 0.3),
          color: [
            const Color(0xFF00BFA5), // Brand Green
            const Color(0xFF00E5FF), // Cyan Accent
            const Color(0xFF1DE9B6), // Teal Accent
            Colors.white,
            const Color(0xFF69F0AE), // Green Accent
            Colors.lightBlueAccent,
          ][random.nextInt(6)],
          size: 4.0 + random.nextDouble() * 6,
          rotation: random.nextDouble() * 2 * pi,
          velocity: 0.3 + random.nextDouble() * 0.4,
        ),
      );
    }

    _controller.forward();
    _confettiController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mutualInterests = _getMutualInterests();

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      body: Stack(
        children: [
          // Confetti layer
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, child) {
              return CustomPaint(
                painter: ConfettiPainter(
                  particles: _confettiParticles,
                  progress: _confettiController.value,
                ),
                size: Size.infinite,
              );
            },
          ),
          // Main content
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _slideAnimation.value),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildProfileAvatar(widget.currentUser),
                            const SizedBox(width: 20),
                            _buildProfileAvatar(widget.matchedUser),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: const [
                                const Color(0xFF00BFA5),
                                const Color(0xFF00E5FF),
                                Colors.white,
                                const Color(0xFF00BFA5),
                              ],
                              stops: [
                                0.0,
                                _shimmerController.value - 0.3,
                                _shimmerController.value,
                                1.0,
                              ],
                            ).createShader(bounds);
                          },
                          child: const Text(
                            "It's a Match!",
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 20.0,
                                  color: Color(0xFF00BFA5),
                                ),
                                Shadow(
                                  blurRadius: 30.0,
                                  color: Color(0xFF00E5FF),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        "You and ${widget.matchedUser.username} have liked each other!",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  if (mutualInterests.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                const Color(0xFF00BFA5).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.favorite,
                                    color: Color(0xFF00BFA5), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'You both love',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              mutualInterests.take(3).join(' • '),
                              style: const TextStyle(
                                color: const Color(0xFF00BFA5),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 50),
                  AnimatedBuilder(
                    animation: _buttonSlideAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _buttonSlideAnimation.value),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    HapticFeedback.lightImpact();
                                    final chatId =
                                        await locator<ChatRepository>()
                                            .startOrGetChat(
                                      widget.matchedUser.id,
                                      widget.matchedUser.username,
                                    );
                                    if (mounted) {
                                      Navigator.of(context).pop();
                                      Navigator.of(context)
                                          .push(MaterialPageRoute(
                                        builder: (_) => ImprovedChatScreen(
                                          chatId: chatId,
                                          otherUsername:
                                              widget.matchedUser.username,
                                        ),
                                      ));
                                    }
                                  },
                                  icon: const Icon(Icons.send, size: 22),
                                  label: const Text(
                                    "Send a Message",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00BFA5),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 8,
                                    shadowColor: const Color(0xFF00BFA5)
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.of(context).pop();
                                  },
                                  icon: const Icon(Icons.explore, size: 22),
                                  label: const Text(
                                    "Keep Swiping",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                        color: Colors.white70, width: 2),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getMutualInterests() {
    final currentInterests = widget.currentUser.interests.toSet();
    final matchedInterests = widget.matchedUser.interests.toSet();
    return currentInterests.intersection(matchedInterests).toList();
  }

  Widget _buildProfileAvatar(UserModel user) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BFA5).withValues(
                      alpha: 0.5 + (_shimmerController.value * 0.3)),
                  blurRadius: 20 + (_shimmerController.value * 10),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFF00BFA5),
              child: CircleAvatar(
                radius: 56,
                backgroundImage: user.photoUrl.isNotEmpty
                    ? NetworkImage(user.photoUrl)
                    : null,
                child: user.photoUrl.isEmpty
                    ? Text(
                        user.username.isNotEmpty
                            ? user.username[0].toUpperCase()
                            : '?',
                        style:
                            const TextStyle(fontSize: 50, color: Colors.white),
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

// Confetti Particle Model
class ConfettiParticle {
  final double x;
  final double y;
  final Color color;
  final double size;
  final double rotation;
  final double velocity;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.rotation,
    required this.velocity,
  });
}

// Confetti Painter
class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;

  ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withValues(alpha: 1.0 - (progress * 0.7))
        ..style = PaintingStyle.fill;

      final currentY = particle.y + (progress * particle.velocity * 1.2);
      final currentX = particle.x + (sin(progress * pi * 2) * 0.1);

      if (currentY < 1.2) {
        canvas.save();
        canvas.translate(
          currentX * size.width,
          currentY * size.height,
        );
        canvas.rotate(particle.rotation + (progress * pi * 4));

        // Draw heart shape for some particles
        if (particle.size > 7) {
          _drawHeart(canvas, paint, particle.size);
        } else {
          canvas.drawCircle(Offset.zero, particle.size, paint);
        }

        canvas.restore();
      }
    }
  }

  void _drawHeart(Canvas canvas, Paint paint, double size) {
    final path = Path();
    final heartSize = size * 0.8;

    path.moveTo(0, heartSize * 0.3);

    path.cubicTo(
      -heartSize,
      -heartSize * 0.5,
      -heartSize * 0.5,
      -heartSize,
      0,
      -heartSize * 0.3,
    );

    path.cubicTo(
      heartSize * 0.5,
      -heartSize,
      heartSize,
      -heartSize * 0.5,
      0,
      heartSize * 0.3,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) => true;
}
