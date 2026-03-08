import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_event.dart';
import 'package:freegram/theme/design_tokens.dart';

class SwipeToSkipDetector extends StatefulWidget {
  final Widget child;
  final bool isEnabled;

  const SwipeToSkipDetector({super.key, required this.child, this.isEnabled = true});

  @override
  State<SwipeToSkipDetector> createState() => _SwipeToSkipDetectorState();
}

class _SwipeToSkipDetectorState extends State<SwipeToSkipDetector> with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _thresholdCrossedHapticTriggered = false;

  late AnimationController _animationController;
  Animation<double>? _currentAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animationController.addListener(() {
      if (_currentAnimation != null) {
        setState(() {
          _dragOffset = _currentAnimation!.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.isEnabled || _animationController.isAnimating) return;
    _animationController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.isEnabled || _animationController.isAnimating) return;
    
    setState(() {
      _dragOffset += details.primaryDelta ?? 0;
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final swipeThreshold = screenWidth * 0.25;

    // Trigger haptic physical validation exactly when threshold is crossed
    if (_dragOffset.abs() > swipeThreshold && !_thresholdCrossedHapticTriggered) {
      HapticFeedback.mediumImpact();
      _thresholdCrossedHapticTriggered = true;
    } else if (_dragOffset.abs() <= swipeThreshold) {
      _thresholdCrossedHapticTriggered = false;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isEnabled) {
      _dragOffset = 0;
      _thresholdCrossedHapticTriggered = false;
      return;
    }
    
    final screenWidth = MediaQuery.of(context).size.width;
    final swipeThreshold = screenWidth * 0.25;
    final velocity = details.primaryVelocity ?? 0;

    // Swipe must be deliberate: exceed threshold OR have sufficient velocity
    if (_dragOffset.abs() > swipeThreshold || velocity.abs() > 500.0) {
      // Animate off screen
      final direction = _dragOffset >= 0 ? 1.0 : -1.0;
      final targetOffset = screenWidth * direction;
      
      _animateTo(targetOffset, onComplete: () {
        context.read<RandomChatBloc>().add(const RandomChatSwipeNext());
        if (mounted) {
          setState(() {
            _dragOffset = 0;
            _thresholdCrossedHapticTriggered = false;
          });
        }
      });
    } else {
      // Animate back to center
      _animateTo(0, onComplete: () {
        if (mounted) {
          _thresholdCrossedHapticTriggered = false;
        }
      });
    }
  }

  void _animateTo(double targetOffset, {required VoidCallback onComplete}) {
    _currentAnimation = Tween<double>(begin: _dragOffset, end: targetOffset).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    _animationController.forward(from: 0.0).then((_) {
      onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background layer: Revealed when swiping
        if (_dragOffset != 0)
          Positioned.fill(
             child: Container(
               color: Colors.black,
               child: Stack(
                 alignment: Alignment.center,
                 children: [
                   // "Skip" Hint styling
                   Row(
                     mainAxisAlignment: _dragOffset > 0 
                         ? MainAxisAlignment.start 
                         : MainAxisAlignment.end,
                     children: [
                       Padding(
                         padding: EdgeInsets.symmetric(
                           horizontal: MediaQuery.of(context).size.width * 0.1,
                         ),
                         child: Opacity(
                           opacity: (_dragOffset.abs() / (MediaQuery.of(context).size.width * 0.25)).clamp(0.0, 1.0),
                           child: Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               if (_dragOffset < 0) ...[
                                 const Text(
                                   "Next",
                                   style: TextStyle(
                                     color: Colors.white70,
                                     fontSize: DesignTokens.fontSizeMD,
                                     fontWeight: FontWeight.bold,
                                   ),
                                 ),
                                 const SizedBox(width: DesignTokens.spaceSM),
                               ],
                               Container(
                                 padding: const EdgeInsets.all(DesignTokens.spaceMD),
                                 decoration: BoxDecoration(
                                   color: Colors.white.withValues(alpha: 0.1),
                                   shape: BoxShape.circle,
                                 ),
                                 child: const Icon(
                                   Icons.fast_forward_rounded,
                                   color: Colors.white,
                                   size: DesignTokens.iconLG,
                                 ),
                               ),
                               if (_dragOffset > 0) ...[
                                 const SizedBox(width: DesignTokens.spaceSM),
                                 const Text(
                                   "Next",
                                   style: TextStyle(
                                     color: Colors.white70,
                                     fontSize: DesignTokens.fontSizeMD,
                                     fontWeight: FontWeight.bold,
                                   ),
                                 ),
                               ],
                             ],
                           ),
                         ),
                       ),
                     ],
                   ),
                 ]
               ),
             ),
          ),
          
        // Foreground layer (The UI sliding)
        GestureDetector(
          onHorizontalDragStart: _onPanStart,
          onHorizontalDragUpdate: _onPanUpdate,
          onHorizontalDragEnd: _onPanEnd,
          behavior: HitTestBehavior.translucent,
          child: Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
