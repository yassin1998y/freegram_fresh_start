import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/interaction/interaction_bloc.dart';
import 'package:freegram/blocs/interaction/interaction_state.dart';
import 'package:lottie/lottie.dart';

class LottieOverlayWidget extends StatefulWidget {
  const LottieOverlayWidget({super.key});

  @override
  State<LottieOverlayWidget> createState() => _LottieOverlayWidgetState();
}

class _LottieOverlayWidgetState extends State<LottieOverlayWidget>
    with TickerProviderStateMixin {
  String? _currentAnimationAsset;
  bool _isPlaying = false;
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _playAnimation(String assetUrl) {
    setState(() {
      _currentAnimationAsset = assetUrl;
      _isPlaying = true;
    });

    // Reset controller
    _controller?.duration = const Duration(seconds: 3); // Default fallback
    _controller?.forward(from: 0).whenComplete(() {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InteractionBloc, InteractionState>(
      listener: (context, state) {
        if (state is GiftReceivedState) {
          // Play animation
          // state.gift.animationUrl should be a valid lottie asset path
          if (state.gift.animationUrl.isNotEmpty) {
            _playAnimation(state.gift.animationUrl);
          }
        }
      },
      child: _isPlaying && _currentAnimationAsset != null
          ? Center(
              child: Lottie.asset(
                _currentAnimationAsset!,
                controller: _controller,
                onLoaded: (composition) {
                  _controller?.duration = composition.duration;
                  _controller?.forward(from: 0);
                },
                height: 300,
                width: 300,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
