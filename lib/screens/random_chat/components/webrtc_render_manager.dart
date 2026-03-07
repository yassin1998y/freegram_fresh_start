import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCRenderManager extends StatefulWidget {
  final MediaStream? stream;
  final bool isLocal;
  final VoidCallback? onFirstFrameRendered;

  const WebRTCRenderManager({
    super.key,
    this.stream,
    this.isLocal = false,
    this.onFirstFrameRendered,
  });

  @override
  State<WebRTCRenderManager> createState() => _WebRTCRenderManagerState();
}

class _WebRTCRenderManagerState extends State<WebRTCRenderManager> {
  late final RTCVideoRenderer _renderer;
  bool _initialized = false;
  bool _firstFrameReported = false;

  @override
  void initState() {
    super.initState();
    // Instantiate the renderer
    _renderer = RTCVideoRenderer();
    _renderer.addListener(_onRendererStateChanged);
    _initializeAsync();
  }

  void _onRendererStateChanged() {
    if (_firstFrameReported) return;

    // Check if the renderer has received valid video frames
    // Some drivers report 0x0 until the first buffer is pushed to texture
    if (_renderer.value.renderVideo &&
        _renderer.videoWidth > 0 &&
        _renderer.videoHeight > 0) {
      debugPrint(
          '[WebRTCRenderManager] First Frame Detected: ${_renderer.videoWidth}x${_renderer.videoHeight}');
      _firstFrameReported = true;
      widget.onFirstFrameRendered?.call();
    }
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
      debugPrint(
          '[WebRTCRenderManager] Stream changed - cleaning up old texture');

      // Proactively clear the source before assigning new one to prevent native memory bloating
      _renderer.srcObject = null;

      // Reset first frame detection if stream changes
      _firstFrameReported = false;

      // Ensure the native side has a chance to release the buffer before the new one is assigned
      Future.microtask(() {
        if (mounted) {
          _renderer.srcObject = widget.stream;
        }
      });
    }
  }

  @override
  void dispose() {
    // CRITICAL: Strict disposal to prevent native side memory leaks
    _renderer.removeListener(_onRendererStateChanged);
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
