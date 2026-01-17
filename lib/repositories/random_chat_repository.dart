import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Nuclear Refactor: Socket.IO based WebRTC Repository
/// Handles Signaling (Socket.IO) + PeerConnection (WebRTC)
class RandomChatRepository {
  // Singleton pattern
  static final RandomChatRepository _instance =
      RandomChatRepository._internal();

  factory RandomChatRepository() {
    return _instance;
  }

  RandomChatRepository._internal();

  // --- Exposed State ---
  final ValueNotifier<MediaStream?> localStream = ValueNotifier(null);
  final ValueNotifier<MediaStream?> remoteStream = ValueNotifier(null);
  final ValueNotifier<String> connectionState = ValueNotifier('Disconnected');

  // --- Internals ---
  io.Socket? _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStreamInstance;
  bool _isDisposing = false;
  bool _isPolite = false; // "Polite Peer" pattern to prevent collisions

  // Configuration
  // Default to localhost if not found (Signaling Server URL)
  final String _signalingUrl =
      dotenv.env['SIGNALING_URL'] ?? 'http://localhost:3000';

  Map<String, dynamic> get _rtcConfiguration {
    final String username = dotenv.env['METERED_USERNAME'] ?? '';
    final String password = dotenv.env['METERED_PASSWORD'] ?? '';

    return {
      'iceServers': [
        // 1. Metered STUN
        {
          'urls': 'stun:stun.relay.metered.ca:80',
        },
        // 2. Metered TURN (UDP - Standard)
        {
          'urls': 'turn:global.relay.metered.ca:80',
          'username': username,
          'credential': password,
        },
        // 3. Metered TURN (TCP - Fallback if UDP blocked)
        {
          'urls': 'turn:global.relay.metered.ca:80?transport=tcp',
          'username': username,
          'credential': password,
        },
        // 4. Metered TURN (443 - Firewall Bypass)
        {
          'urls': 'turn:global.relay.metered.ca:443',
          'username': username,
          'credential': password,
        },
        // 5. Metered TURNS (Secure TCP)
        {
          'urls': 'turns:global.relay.metered.ca:443?transport=tcp',
          'username': username,
          'credential': password,
        },
      ],
      // DEADLOCK KILLER 1: Unified Plan
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'iceCandidatePoolSize': 0,
    };
  }

  // --- Initialization ---

  Future<void> initialize() async {
    _isDisposing = false;
    connectionState.value = 'Initializing';
    await _initLocalStream();
    _connectSocket();
  }

  Future<void> _initLocalStream() async {
    if (_localStreamInstance != null) {
      localStream.value = _localStreamInstance;
      return;
    }

    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
          'frameRate': {'ideal': 24},
        },
      });
      _localStreamInstance = stream;
      localStream.value = stream;
      debugPrint('📷 [RandomChat] Local stream initialized');
    } catch (e) {
      debugPrint('❌ [RandomChat] Failed to get local stream: $e');
      connectionState.value = 'Camera Error';
    }
  }

  void _connectSocket() {
    if (_socket != null && _socket!.connected) return;

    debugPrint('🔌 [RandomChat] Connecting to Socket.IO at $_signalingUrl');

    _socket = io.io(
      _signalingUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('✅ [RandomChat] Socket connected: ${_socket!.id}');
      connectionState.value = 'Ready';
    });

    _socket!.onDisconnect((_) {
      debugPrint('⚠️ [RandomChat] Socket disconnected');
      if (!_isDisposing) connectionState.value = 'Disconnected';
    });

    // --- Signaling Events ---

    // 1. Found a Match (Start Signaling)
    _socket!.on('match_found', (data) async {
      debugPrint('🎯 [RandomChat] Match found! Role: ${data['role']}');
      final isOfferer = data['role'] == 'offerer';
      _isPolite = !isOfferer; // Offerer is impolite, Answerer is polite

      connectionState.value = 'Connecting';
      await _createPeerConnection();

      if (isOfferer) {
        // Caller: Create Offer
        // DEADLOCK KILLER 2: Mandatory Constraints
        RTCSessionDescription offer = await _peerConnection!.createOffer({
          'mandatory': {
            'OfferToReceiveAudio': true,
            'OfferToReceiveVideo': true,
          },
        });
        await _peerConnection!.setLocalDescription(offer);
        _socket!.emit('offer', {'sdp': offer.sdp, 'type': offer.type});
      }
    });

    // 2. Receive Offer (Answerer)
    _socket!.on('offer', (data) async {
      debugPrint('📩 [RandomChat] Received Offer');
      if (_peerConnection == null) await _createPeerConnection();

      // Handle race conditions/glare if both try to offer (Polite Peer logic simplified)
      final signalingState = _peerConnection!.signalingState;
      if (signalingState != RTCSignalingState.RTCSignalingStateStable) {
        // If we are polite, we accept the new offer and rollback our collision
        if (!_isPolite) return; // Impolite ignores collision

        final currentLocal = await _peerConnection!.getLocalDescription();
        if (currentLocal != null) {
          await Future.wait([
            _peerConnection!.setLocalDescription(
                RTCSessionDescription(currentLocal.sdp, 'rollback')),
            _peerConnection!.setRemoteDescription(
                RTCSessionDescription(data['sdp'], data['type']))
          ]);
        } else {
          // If local description is null, we can't rollback, just set remote
          await _peerConnection!.setRemoteDescription(
              RTCSessionDescription(data['sdp'], data['type']));
        }
      } else {
        await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(data['sdp'], data['type']));
      }

      RTCSessionDescription answer = await _peerConnection!.createAnswer({
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': true,
        },
      });
      await _peerConnection!.setLocalDescription(answer);
      _socket!.emit('answer', {'sdp': answer.sdp, 'type': answer.type});
    });

    // 3. Receive Answer (Offerer)
    _socket!.on('answer', (data) async {
      debugPrint('📩 [RandomChat] Received Answer');
      if (_peerConnection != null) {
        await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(data['sdp'], data['type']));
      }
    });

    // 4. ICE Condidate
    _socket!.on('candidate', (data) async {
      if (_peerConnection != null) {
        final candidate = RTCIceCandidate(
            data['candidate'], data['sdpMid'], data['sdpMLineIndex']);
        await _peerConnection!.addCandidate(candidate);
      }
    });

    _socket!.on('partner_left', (_) {
      debugPrint('🛑 [RandomChat] Partner left');
      _restartSession(); // Auto-search or show UI?
    });
  }

  // --- WebRTC Logic ---

  Future<void> _createPeerConnection() async {
    if (_peerConnection != null) return;

    debugPrint('🛠️ [RandomChat] Creating PeerConnection');
    _peerConnection = await createPeerConnection(_rtcConfiguration);

    // Add local tracks
    if (_localStreamInstance != null) {
      _localStreamInstance!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStreamInstance!);
      });
    }

    // Handle ICE Candidates
    _peerConnection!.onIceCandidate = (candidate) {
      _socket?.emit('candidate', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    // Handle Connection State
    _peerConnection!.onConnectionState = (state) {
      debugPrint('🕸️ [RandomChat] Connection State: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        connectionState.value = 'Connected';
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        connectionState.value = 'Failed';
        _restartSession();
      }
    };

    // Handle Remote Stream (Add Track)
    _peerConnection!.onTrack = (event) {
      debugPrint('📺 [RandomChat] Remote Track Received');
      if (event.streams.isNotEmpty) {
        remoteStream.value = event.streams.first;
      }
    };
  }

  // --- Public Actions ---

  void findRoom() {
    if (_socket == null || !_socket!.connected) _connectSocket();
    connectionState.value = 'Searching';
    // User might want to pass filters (gender, etc) here
    _socket!.emit('find_room', {});

    // Clean up old connection if any
    _closePeerConnection();
  }

  void nextMatch() {
    // Disconnect current, find new
    _socket?.emit('leave_room');
    _closePeerConnection();
    findRoom();
  }

  void toggleAudio(bool enabled) {
    if (_localStreamInstance != null) {
      _localStreamInstance!.getAudioTracks().forEach((track) {
        track.enabled = enabled;
      });
    }
  }

  void toggleVideo(bool enabled) {
    if (_localStreamInstance != null) {
      _localStreamInstance!.getVideoTracks().forEach((track) {
        track.enabled = enabled;
      });
    }
  }

  // --- Cleanup ---

  Future<void> _closePeerConnection() async {
    remoteStream.value = null; // Clear UI
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }
  }

  void _restartSession() {
    connectionState.value = 'Partner Left';
    _closePeerConnection();
    // Optionally auto-search:
    // findRoom();
  }

  Future<void> dispose() async {
    debugPrint('🗑️ [RandomChat] Disposing Repository');
    _isDisposing = true;

    // Kill WebRTC
    await _closePeerConnection();

    // Kill Socket
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    // Kill Local Stream
    if (_localStreamInstance != null) {
      _localStreamInstance!.getTracks().forEach((track) => track.stop());
      await _localStreamInstance!.dispose();
      _localStreamInstance = null;
      localStream.value = null;
    }
  }
}
