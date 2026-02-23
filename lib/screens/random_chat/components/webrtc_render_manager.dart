import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCRenderManager extends StatefulWidget {
  final MediaStream? stream;
  final bool isLocal;

  const WebRTCRenderManager({
    super.key,
    this.stream,
    this.isLocal = false,
  });

  @override
  State<WebRTCRenderManager> createState() => _WebRTCRenderManagerState();
}

class _WebRTCRenderManagerState extends State<WebRTCRenderManager> {
  late final RTCVideoRenderer _renderer;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Instantiate the renderer
    _renderer = RTCVideoRenderer();
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    try {
      // Initialize internal OS-level resources for WebRTC
      await _renderer.initialize();
      if (mounted) {
        setState(() {
          _renderer.srcObject = widget.stream;
          _initialized = true;
        });
      }
    } catch (e) {
      debugPrint('[WebRTCRenderManager] RTC initialization error: $e');
    }
  }

  @override
  void didUpdateWidget(WebRTCRenderManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update stream dynamically if it changes in the BLoC
    if (oldWidget.stream != widget.stream) {
      _renderer.srcObject = widget.stream;
    }
  }

  @override
  void dispose() {
    // CRITICAL: Strict disposal to prevent native side memory leaks
    _renderer.srcObject = null;
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fallback UI when stream is unavailable or renderer is warming up
    if (widget.stream == null || !_initialized) {
      return const SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.black),
        ),
      );
    }

    return RTCVideoView(
      _renderer,
      mirror: widget.isLocal,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}
