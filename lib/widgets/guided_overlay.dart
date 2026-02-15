import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';

class GuideStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final Alignment fallbackAlignment;

  GuideStep({
    required this.targetKey,
    this.title = '',
    required this.description,
    this.fallbackAlignment = Alignment.center,
  });
}

class GuidedOverlay extends StatefulWidget {
  final List<GuideStep> steps;
  final VoidCallback onFinish;

  const GuidedOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
  });

  @override
  State<GuidedOverlay> createState() => _GuidedOverlayState();
}

class _GuidedOverlayState extends State<GuidedOverlay>
    with TickerProviderStateMixin {
  int _currentStepIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Rect? _targetRect;
  bool _isVisible = false;

  // Task 3: Focus Scope Management
  late FocusNode _buttonFocusNode;
  late FocusScopeNode _scopeNode;

  @override
  void initState() {
    super.initState();
    _buttonFocusNode = FocusNode();
    _scopeNode = FocusScopeNode();

    _animationController = AnimationController(
      vsync: this,
      duration: AnimationTokens.normal,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTargetRect();
      if (mounted) {
        setState(() => _isVisible = true);
        _animationController.forward();

        // Task 2: Request focus in next frame to ensure UI is ready
        _buttonFocusNode.requestFocus();
      }
    });
  }

  void _updateTargetRect() {
    final step = widget.steps[_currentStepIndex];
    final context = step.targetKey.currentContext;
    if (context != null) {
      final renderBox = context.findRenderObject() as RenderBox;
      final size = renderBox.size;
      final offset = renderBox.localToGlobal(Offset.zero);
      setState(() {
        _targetRect =
            Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
      });
    } else {
      setState(() {
        _targetRect = null;
      });
    }
  }

  void _nextStep() {
    if (_currentStepIndex < widget.steps.length - 1) {
      _animationController.reverse().then((_) {
        setState(() {
          _currentStepIndex++;
        });
        _updateTargetRect();
        _animationController.forward();

        // Task 2: Re-request focus when transitioning steps
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _buttonFocusNode.requestFocus();
        });
      });
    } else {
      _animationController.reverse().then((_) {
        widget.onFinish();
      });
    }
  }

  @override
  void dispose() {
    // Task 3: Ensure focus is cleared and nodes are disposed
    _buttonFocusNode.unfocus();
    _buttonFocusNode.dispose();
    _scopeNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || _targetRect == null) return const SizedBox.shrink();

    final step = widget.steps[_currentStepIndex];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: FocusScope(
        node: _scopeNode,
        autofocus: true,
        child: Stack(
          children: [
            // Spotlight Background
            Positioned.fill(
              child: GestureDetector(
                onTap: _nextStep,
                child: CustomPaint(
                  painter: SpotlightPainter(
                    targetRect: _targetRect!,
                    overlayColor: Colors.black.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),

            // Content Overlay
            _buildStepContent(step),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(GuideStep step) {
    // Calculate position for the tooltip
    final screenHeight = MediaQuery.of(context).size.height;
    final targetCenterY = _targetRect!.center.dy;

    // Position tooltip above or below the spotlight
    final isAbove = targetCenterY > screenHeight / 2;
    final topPadding = isAbove ? null : _targetRect!.bottom + 20;
    final bottomPadding =
        isAbove ? (screenHeight - _targetRect!.top) + 20 : null;

    return Positioned(
      left: 20,
      right: 20,
      top: topPadding,
      bottom: bottomPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Ensure overlay content is centered on wide screens
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Task 2: Ensure the parent has a maxWidth defined
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(DesignTokens.spaceLG),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (step.title.isNotEmpty) ...[
                        Text(
                          step.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: DesignTokens.spaceXS),
                      ],
                      Text(
                        step.description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.4,
                            ),
                      ),
                      const SizedBox(height: DesignTokens.spaceLG),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_currentStepIndex + 1} / ${widget.steps.length}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // Task 1 & 3: Resolve Button Constraints and Styling
                          // Using SizedBox and minimumSize to prevent infinite width/height issues
                          SizedBox(
                            height: 52, // 52.0 height constant as requested
                            child: ElevatedButton(
                              focusNode: _buttonFocusNode,
                              onPressed: _nextStep,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SonarPulseTheme.primaryAccent,
                                foregroundColor: Colors.white,
                                // Task 3: Explicit minimumSize and fixed height
                                minimumSize: const Size(120, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusMD),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DesignTokens.spaceXL,
                                ),
                                elevation: 0,
                              ).copyWith(
                                // Ensure standard behavior and prevent unexpected expansion
                                maximumSize: WidgetStateProperty.all(
                                    const Size(double.infinity, 52)),
                              ),
                              child: Text(
                                _currentStepIndex == widget.steps.length - 1
                                    ? 'Got it'
                                    : 'Next',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final Color overlayColor;

  SpotlightPainter({
    required this.targetRect,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;

    // Create a path for the whole screen
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create a path for the spotlight (hole)
    // Using a rounded rect for a smoother look
    final spotlightPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        targetRect.inflate(8), // Add some padding around the widget
        const Radius.circular(16),
      ));

    // Subtract the spotlight from the background
    final finalPath =
        Path.combine(PathOperation.difference, backgroundPath, spotlightPath);

    canvas.drawPath(finalPath, paint);

    // Optional: Draw a glowing border around the spotlight
    final borderPaint = Paint()
      ..color = SonarPulseTheme.primaryAccent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        targetRect.inflate(8),
        const Radius.circular(16),
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.overlayColor != overlayColor;
  }
}
