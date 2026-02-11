import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WebRTCService {
  WebRTCService._internal();
  static final WebRTCService instance = WebRTCService._internal();

  // --- Socket & WebRTC ---
  IO.Socket? _socket;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  MediaStream? _localStream;

  // --- State Controllers (Reactive) ---
  final StreamController<RTCPeerConnectionState> _connectionStateController =
      StreamController<RTCPeerConnectionState>.broadcast();

  final StreamController<MediaStream?> _remoteStreamController =
      StreamController<MediaStream?>.broadcast();

  final StreamController<String> _messageStreamController =
      StreamController<String>.broadcast();

  // Mic & Camera State Streams
  final StreamController<bool> _micStateController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _cameraStateController =
      StreamController<bool>.broadcast();

  // Interaction Stream
  final StreamController<Map<String, dynamic>> _interactionController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Public Streams
  Stream<RTCPeerConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<MediaStream?> get remoteStreamStream => _remoteStreamController.stream;
  Stream<String> get messageStream => _messageStreamController.stream;
  Stream<bool> get micStateStream => _micStateController.stream;
  Stream<bool> get cameraStateStream => _cameraStateController.stream;
  Stream<Map<String, dynamic>> get interactionStream =>
      _interactionController.stream;

  // Local Stream Getter (Pre-warmed)
  MediaStream? get localStream => _localStream;

  // --- Session State ---
  String? _roomId;
  Timer? _watchdogTimer;
  bool _isDisposed = false;

  // Track partner for history
  String? _currentPartnerId;
  String? get currentPartnerId => _currentPartnerId;

  // Internal State Trackers (defaults)
  bool _isMicOn = true;
  bool _isCameraOn = true;

  // Safety
  final Set<String> _blockedUsers = {};
  static const String _kBlockedUsersKey = 'blocked_users';

  // --- Initialization ---

  Future<void> initialize() async {
    await _loadBlockedUsers();

    if (_socket != null && _socket!.connected) return;

    final url = dotenv.env['SIGNALING_SERVER_URL'];
    if (url == null || url.isEmpty) {
      debugPrint('❌ [WEBRTC_ERROR] SIGNALING_SERVER_URL missing in .env');
      return;
    }

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .setReconnectionAttempts(5)
          .build(),
    );

    _registerSocketListeners();
  }

  Future<void> initializeLocalStream() async {
    // Permission check
    if (!kIsWeb) {
      final status = await Permission.camera.request();
      await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('❌ [WEBRTC_ERROR] Camera permission denied');
        return;
      }
    }

    // Pre-warm check
    if (_localStream != null) {
      debugPrint(
          '📷 [WEBRTC_INFO] Local stream already initialized (Pre-warmed).');
      return;
    }

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': 640,
          'height': 480,
          'frameRate': 30,
        },
      });
      debugPrint('📷 [WEBRTC_INFO] Local stream initialized.');
      _updateTrackState();
    } catch (e) {
      debugPrint('❌ [WEBRTC_ERROR] Failed to get user media: $e');
      _messageStreamController.add("Failed to access camera: $e");
    }
  }

  // --- Match Logic ---

  void startRandomSearch() {
    _cleanupSession();

    if (_socket == null || !_socket!.connected) {
      debugPrint(
          '⚠️ [WEBRTC_WARN] Socket not connected, attempting to connect...');
      initialize();
    } else {
      debugPrint('🔍 [WEBRTC_STATE_CHANGE] Emitting find_random_match...');
      _socket!.emit('find_random_match');
    }
  }

  void nextMatch() {
    debugPrint('⏭️ [WEBRTC_ACTION] Skipping to next match...');
    startRandomSearch();
  }

  // --- Safety & Moderation ---

  Future<void> _loadBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? blocked = prefs.getStringList(_kBlockedUsersKey);
    if (blocked != null) {
      _blockedUsers.addAll(blocked);
    }
  }

  Future<void> blockUser(String userId) async {
    if (_blockedUsers.contains(userId)) return;

    _blockedUsers.add(userId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kBlockedUsersKey, _blockedUsers.toList());

    debugPrint('🛡️ [SAFETY] User $userId blocked locally.');
  }

  bool isUserBlocked(String userId) {
    return _blockedUsers.contains(userId);
  }

  // --- Interaction & Other Getters ---

  String? get currentUserId {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  void addFriend() {
    sendInteraction('FRIEND_REQUEST', {});
  }

  void sendInteraction(String type, Map<String, dynamic> payload) {
    if (_dataChannel != null) {
      // We skip exact state check due to Enum ambiguity in different versions,
      // relying on try-catch on send.
      try {
        final message = {
          'type': type,
          'payload': payload,
        };
        _dataChannel!.send(RTCDataChannelMessage(jsonEncode(message)));
      } catch (e) {
        debugPrint(
            '⚠️ [WEBRTC_WARN] Failed to send interaction via DataChannel: $e');
      }
    } else {
      debugPrint(
          '⚠️ [WEBRTC_WARN] DataChannel is null. Cannot send interaction.');
    }
  }

  // --- Socket Listeners ---

  void _registerSocketListeners() {
    _socket?.onConnect((_) {
      debugPrint('✅ [WEBRTC_STATE_CHANGE] Socket IO Connected');
    });

    _socket?.on('match_found', (data) {
      debugPrint('🤝 [WEBRTC_STATE_CHANGE] Match Found: $data');

      _roomId = data['roomId'];
      final role = data['role'];

      // If server provides partnerId in future:
      // _currentPartnerId = data['partnerId'];

      if (role == 'offer') {
        _startCall(isCaller: true);
      } else if (role == 'answer') {
        _startCall(isCaller: false);
      } else {
        debugPrint('❌ [WEBRTC_ERROR] Invalid role received: $role');
      }

      _startWatchdog();
    });

    _socket?.on('offer', (data) async {
      if (_peerConnection == null) return;
      try {
        final offerMap = data['offer'];
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(offerMap['sdp'], offerMap['type']),
        );

        RTCSessionDescription answer = await _peerConnection!.createAnswer();

        String mungedSdp = _ensureCodecPreference(answer.sdp!);
        answer = RTCSessionDescription(mungedSdp, answer.type);

        await _peerConnection!.setLocalDescription(answer);

        _socket!.emit('answer', {
          'roomId': _roomId,
          'answer': {'sdp': answer.sdp, 'type': answer.type},
        });
      } catch (e) {
        debugPrint('❌ [WEBRTC_ERROR] Handle Offer Failed: $e');
      }
    });

    _socket?.on('answer', (data) async {
      if (_peerConnection == null) return;
      try {
        final answerMap = data['answer'];
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(answerMap['sdp'], answerMap['type']),
        );
      } catch (e) {
        debugPrint('❌ [WEBRTC_ERROR] Handle Answer Failed: $e');
      }
    });

    _socket?.on('candidate', (data) async {
      if (_peerConnection == null) return;
      try {
        final candidateMap = data['candidate'];
        await _peerConnection!.addCandidate(
          RTCIceCandidate(
            candidateMap['candidate'],
            candidateMap['sdpMid'],
            candidateMap['sdpMLineIndex'],
          ),
        );
      } catch (e) {
        debugPrint('❌ [WEBRTC_ERROR] Handle Candidate Failed: $e');
      }
    });

    _socket?.on('peer_disconnected', (_) {
      debugPrint('🚫 [WEBRTC_STATE_CHANGE] Peer Disconnected');
      _connectionStateController
          .add(RTCPeerConnectionState.RTCPeerConnectionStateDisconnected);
      _cleanupSession();
    });
  }

  // --- WebRTC Logic ---

  Future<void> _startCall({required bool isCaller}) async {
    try {
      await _createPeerConnection();

      if (isCaller) {
        debugPrint('🚀 [WEBRTC_STATE_CHANGE] Starting Call as OFFERER');

        _dataChannel = await _peerConnection!
            .createDataChannel('chat', RTCDataChannelInit()..ordered = true);
        _setupDataChannelListeners(_dataChannel!);

        RTCSessionDescription offer = await _peerConnection!.createOffer();

        String mungedSdp = _ensureCodecPreference(offer.sdp!);
        offer = RTCSessionDescription(mungedSdp, offer.type);
        debugPrint('📝 [SDP_GENERATED] Created Offer with preferred codec');

        await _peerConnection!.setLocalDescription(offer);

        _socket!.emit('offer', {
          'roomId': _roomId,
          'offer': {'sdp': offer.sdp, 'type': offer.type},
        });
      } else {
        debugPrint('⏳ [WEBRTC_STATE_CHANGE] Waiting for Offer as ANSWERER');
      }
    } catch (e) {
      debugPrint("Error starting call: $e");
      _messageStreamController.add("Connection Error. Retrying...");
      nextMatch();
    }
  }

  Future<void> _createPeerConnection() async {
    // 🛑 STUN/TURN Audit
    final turnUser = dotenv.env['METERED_USERNAME'];
    final turnPass = dotenv.env['METERED_PASSWORD'];

    final List<Map<String, dynamic>> iceServers = [
      {'urls': 'stun:stun.l.google.com:19302'},
    ];

    if (turnUser != null && turnPass != null) {
      iceServers.add({
        'urls': 'turn:global.turn.metered.ca:80',
        'username': turnUser,
        'credential': turnPass,
      });
      debugPrint('✅ [WEBRTC_CONFIG] TURN servers configured.');
    } else {
      debugPrint(
          '⚠️ [PRODUCTION_ALERT] TURN servers not configured. Remote connections may fail on strict firewalls.');
    }

    final configuration = {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(configuration);

    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
      _updateTrackState();
    }

    _peerConnection!.onIceCandidate = (candidate) {
      if (_roomId != null && _socket != null) {
        _socket!.emit('candidate', {
          'roomId': _roomId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      }
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        debugPrint('📹 [WEBRTC_STATE_CHANGE] Remote Stream Received');
        _remoteStreamController.add(event.streams[0]);
      }
    };

    // Explicit DataChannel handler for Answerer
    _peerConnection!.onDataChannel = (channel) {
      _setupDataChannelListeners(channel);
    };

    _peerConnection!.onConnectionState = (state) {
      debugPrint('📶 [WEBRTC_STATE_CHANGE] Connection State: $state');
      _connectionStateController.add(state);

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _watchdogTimer?.cancel();
      }
    };
  }

  void _setupDataChannelListeners(RTCDataChannel channel) {
    _dataChannel = channel;
    _dataChannel!.onMessage = (data) {
      if (!data.isBinary) {
        try {
          final decoded = jsonDecode(data.text);
          if (decoded is Map<String, dynamic>) {
            _interactionController.add(decoded);
          }
        } catch (e) {
          debugPrint('Error parsing data channel message: $e');
        }
      }
    };
  }

  // --- Toggles ---

  void toggleMic() {
    _isMicOn = !_isMicOn;
    _updateTrackState();
    _micStateController.add(_isMicOn);
  }

  void toggleCamera() {
    _isCameraOn = !_isCameraOn;
    _updateTrackState();
    _cameraStateController.add(_isCameraOn);
  }

  void _updateTrackState() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        audioTracks[0].enabled = _isMicOn;
      }
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        videoTracks[0].enabled = _isCameraOn;
      }
    }
  }

  // --- Helper Methods ---

  String _ensureCodecPreference(String sdp) {
    try {
      final regExp = RegExp(r'a=rtpmap:(\d+) VP8/90000');
      final match = regExp.firstMatch(sdp);

      if (match != null) {
        final vp8Payload = match.group(1);
        if (vp8Payload != null) {
          final videoLineRegExp = RegExp(r'(m=video \d+ [A-Z/]+ )([0-9\s]+)');
          return sdp.replaceAllMapped(videoLineRegExp, (m) {
            final prefix = m.group(1)!;
            final payloads = m.group(2)!.trim().split(' ');
            payloads.remove(vp8Payload);
            payloads.insert(0, vp8Payload);
            return '$prefix${payloads.join(' ')}';
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ [WEBRTC_WARN] SDP munging failed: $e');
    }
    return sdp;
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('🐕 [WEBRTC_WATCHDOG] Watchdog timeout triggered');

      final currentState = _peerConnection?.connectionState;
      if (currentState !=
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        debugPrint('🐕 [WEBRTC_WATCHDOG] Connection not established. Retry.');
        _messageStreamController
            .add("Connection unstable. Finding a better match...");
        Future.delayed(const Duration(seconds: 1), () {
          nextMatch();
        });
      }
    });
  }

  void _cleanupSession() {
    debugPrint('🧹 [SESSION_CLEANUP] Cleaning up WebRTC session');

    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    _dataChannel?.close();
    _dataChannel = null;

    _peerConnection?.close();
    _peerConnection = null;

    _roomId = null;
    _remoteStreamController.add(null);
    _currentPartnerId = null;
  }

  void dispose() {
    _isDisposed = true;
    _cleanupSession();

    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;

    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    _connectionStateController.close();
    _remoteStreamController.close();
    _messageStreamController.close();
    _micStateController.close();
    _cameraStateController.close();
    _interactionController.close();
  }
}
