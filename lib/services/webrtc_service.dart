import 'dart:async';
import 'dart:convert';
import 'dart:ui'; // Added for AppLifecycleState
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

  // Track partner for history
  String? _currentPartnerId;
  String? get currentPartnerId => _currentPartnerId;

  // Internal State Trackers (defaults)
  bool _isCallActive = false;
  bool _isMicOn = true;
  bool _isCameraOn = true;

  // Safety
  final Set<String> _blockedUsers = {};
  static const String _kBlockedUsersKey = 'blocked_users';

  // Queue for candidates arriving before remote description
  final List<RTCIceCandidate> _queuedRemoteCandidates = [];

  // Temporary storage for incomplete match data
  Map<String, dynamic>? _pendingMatchData;

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

  Future<void> initializeMedia() async {
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
      if (!_messageStreamController.isClosed) {
        _messageStreamController.add("Failed to access camera: $e");
      }
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

      // 1. Check if we already have an active call (PeerConnection Exists and is Connected/Connecting)
      // OR if we are locked in an active call setup.
      if (_isCallActive && _roomId == data['roomId']) {
        debugPrint(
            '🛡️ [SIGNALING] Shielded active session from duplicate match event.');
        return;
      }

      final existingState = _peerConnection?.connectionState;
      if (_peerConnection != null &&
          (existingState ==
                  RTCPeerConnectionState.RTCPeerConnectionStateConnected ||
              existingState ==
                  RTCPeerConnectionState.RTCPeerConnectionStateConnecting)) {
        debugPrint(
            '⚠️ [WEBRTC_WARN] Received match_found while already connected/connecting. Ignoring to preserve session.');
        return;
      }

      // 2. Aggregate Data (Merge incoming data into pendingMatchData)
      _pendingMatchData = {...?_pendingMatchData, ...data};

      _roomId = _pendingMatchData!['roomId'];

      // Look for role in 'role' or 'isOfferer' (from merged data)
      String? role = _pendingMatchData!['role'];
      if (role == null) {
        if (_pendingMatchData!['isOfferer'] == true) role = 'offer';
        if (_pendingMatchData!['isOfferer'] == false) role = 'answer';
      }

      // If server provides partnerId in future:
      // _currentPartnerId = data['partnerId'];

      if (_roomId != null && role != null) {
        // We have complete data, proceed!
        if (role == 'offer') {
          _startCall(isCaller: true);
        } else if (role == 'answer') {
          _startCall(isCaller: false);
        } else {
          debugPrint('❌ [WEBRTC_ERROR] Invalid role received: $role');
        }
        _startWatchdog();
        // Clear pending data as we have consumed it
        _pendingMatchData = null;
      } else {
        debugPrint(
            '⚠️ [WEBRTC_WARN] Incomplete match data. Merged: $_pendingMatchData');
      }
    });

    _socket?.on('offer', (data) async {
      debugPrint('📡 [SIGNALING] Received Remote Offer from: $_roomId');

      // Signaling Guard: Wait if not stable, but don't aggressively cleanup
      if (_peerConnection != null) {
        final state = _peerConnection!.signalingState;
        if (state != null &&
            state != RTCSignalingState.RTCSignalingStateStable) {
          debugPrint(
              '⚠️ [WEBRTC_WARN] Unstable signaling state $state during offer. Retrying in 500ms...');
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // Ensure peer connection exists
      if (_peerConnection == null) {
        await _createPeerConnection();
      }

      try {
        final offerMap = data['offer'];
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(offerMap['sdp'], offerMap['type']),
        );

        // Apply Queued Candidates
        debugPrint(
            '📥 [WEBRTC_INFO] Applying ${_queuedRemoteCandidates.length} queued candidates.');
        for (var candidate in _queuedRemoteCandidates) {
          await _peerConnection!.addCandidate(candidate);
        }
        _queuedRemoteCandidates.clear();

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

        // Apply Queued Candidates
        debugPrint(
            '📥 [WEBRTC_INFO] Applying ${_queuedRemoteCandidates.length} queued candidates after answer.');
        for (var candidate in _queuedRemoteCandidates) {
          await _peerConnection!.addCandidate(candidate);
        }
        _queuedRemoteCandidates.clear();
      } catch (e) {
        debugPrint('❌ [WEBRTC_ERROR] Handle Answer Failed: $e');
      }
    });

    _socket?.on('candidate', (data) async {
      debugPrint('❄️ [ICE] Received Candidate from Peer: $data');

      // Check if candidate belongs to current room or if we are not in an active room
      if (_roomId == null || data['roomId'] != _roomId) {
        debugPrint(
            '⚠️ [WEBRTC_WARN] Ignoring candidate. Expected $_roomId but got ${data['roomId']}');
        return;
      }

      // Handle both 'candidate' and raw wrapper formats if necessary
      // Assuming server sends { candidate: { candidate: ..., sdpMid: ..., ... }, roomId: ... }
      // OR direct candidate object? Server code says: socket.to(roomId).emit('candidate', { candidate, senderId: socket.id });
      // So data is the whole object, data['candidate'] is the RTCIceCandidateInit dict.

      final candidateMap = data['candidate'];
      if (candidateMap == null) {
        debugPrint('⚠️ [WEBRTC_WARN] Candidate map is null');
        return;
      }

      var candidateStr = candidateMap['candidate'];
      var sdpMid = candidateMap['sdpMid'];
      var sdpMLineIndex = candidateMap['sdpMLineIndex'];

      // Fallback if fields are at top level or named differently (common in some libs)
      if (candidateStr == null && data['candidate'] is String) {
        candidateStr = data['candidate'];
        sdpMid = data['sdpMid'];
        sdpMLineIndex = data['sdpMLineIndex'];
      }

      final candidate = RTCIceCandidate(
        candidateStr,
        sdpMid,
        sdpMLineIndex,
      );

      // If peer connection exists and is ready for candidates
      if (_peerConnection != null &&
          (await _peerConnection!.getRemoteDescription()) != null) {
        try {
          await _peerConnection!.addCandidate(candidate);
        } catch (e) {
          debugPrint('❌ [WEBRTC_ERROR] Handle Candidate Failed: $e');
        }
      } else {
        // Queue it
        debugPrint(
            '⏳ [WEBRTC_INFO] Queuing remote candidate (RemoteDescription not set).');
        _queuedRemoteCandidates.add(candidate);
      }
    });

    _socket?.on('peer_disconnected', (_) {
      debugPrint('🚫 [WEBRTC_STATE_CHANGE] Peer Disconnected');
      if (!_connectionStateController.isClosed) {
        _connectionStateController
            .add(RTCPeerConnectionState.RTCPeerConnectionStateDisconnected);
      }
      _cleanupSession();
    });
  }

  // --- WebRTC Logic ---

  Future<void> _startCall({required bool isCaller}) async {
    _isCallActive = true; // LOCK SESSION
    try {
      await _createPeerConnection();

      // Signaling Guard
      if (_peerConnection?.signalingState !=
              RTCSignalingState.RTCSignalingStateStable &&
          _peerConnection?.signalingState !=
              RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        // Technically, if we just created it, it should be stable.
        // But if we are re-using or something went wrong.
        debugPrint(
            '⚠️ [WEBRTC_CHECK] Signaling State at startCall: ${_peerConnection?.signalingState}');
      }

      if (isCaller) {
        debugPrint('🚀 [WEBRTC_STATE_CHANGE] Starting Call as OFFERER');

        if (_peerConnection == null) {
          debugPrint(
              '❌ [WEBRTC_ERROR] PeerConnection is null despite await create.');
          return;
        }

        debugPrint('🚦 Signaling State: ${_peerConnection!.signalingState}');

        _dataChannel = await _peerConnection!
            .createDataChannel('chat', RTCDataChannelInit()..ordered = true);
        _setupDataChannelListeners(_dataChannel!);

        RTCSessionDescription offer = await _peerConnection!.createOffer();

        String mungedSdp = _ensureCodecPreference(offer.sdp!);
        // Ensure strictly non-null before creating description
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
      if (!_messageStreamController.isClosed) {
        _messageStreamController.add("Connection Error. Retrying...");
      }
      nextMatch();
    }
  }

  Future<void> _createPeerConnection() async {
    // 1. Safely load credentials from your .env file
    final turnUser = dotenv.env['METERED_USERNAME'];
    final turnPass = dotenv.env['METERED_PASSWORD'];

    // 2. Setup STUN servers (Finds your public IP)
    final List<Map<String, dynamic>> iceServers = [
      {
        'urls': 'stun:stun.relay.metered.ca:80', // Metered STUN
      },
      {
        'urls': 'stun:stun.l.google.com:19302', // Google Backup STUN
      },
    ];

    // 3. Setup TURN servers (Bypasses Firewalls/Mobile Data blocks)
    if (turnUser != null && turnPass != null) {
      iceServers.addAll([
        {
          'urls': 'turn:global.relay.metered.ca:80',
          'username': turnUser,
          'credential': turnPass,
        },
        {
          'urls': 'turn:global.relay.metered.ca:80?transport=tcp',
          'username': turnUser,
          'credential': turnPass,
        },
        {
          'urls': 'turn:global.relay.metered.ca:443',
          'username': turnUser,
          'credential': turnPass,
        },
        {
          'urls':
              'turns:global.relay.metered.ca:443?transport=tcp', // Crucial TLS secure fallback
          'username': turnUser,
          'credential': turnPass,
        },
      ]);
      debugPrint('✅ [WEBRTC_CONFIG] Advanced Metered TURN servers configured.');
    } else {
      debugPrint('⚠️ [PRODUCTION_ALERT] TURN credentials missing from .env!');
    }

    // 4. Critical Configuration Fixes
    final configuration = {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
      'iceTransportPolicy': 'all', // FIXED: Allows both direct P2P and TURN
      'bundlePolicy': 'max-compat',
    };

    _peerConnection = await createPeerConnection(configuration);

    // Give native layer a moment to warm up
    await Future.delayed(const Duration(milliseconds: 200));

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
        final stream = event.streams[0];
        if (stream.getAudioTracks().isNotEmpty) {
          debugPrint(
              '💎 [STREAM_DEBUG] Remote Audio Track ID: ${stream.getAudioTracks().first.id}');
        }
        if (stream.getVideoTracks().isNotEmpty) {
          debugPrint(
              '💎 [STREAM_DEBUG] Remote Video Track ID: ${stream.getVideoTracks().first.id}');
        }

        if (!_remoteStreamController.isClosed) {
          _remoteStreamController.add(stream);
        }
      }
    };

    // Explicit DataChannel handler for Answerer
    _peerConnection!.onDataChannel = (channel) {
      _setupDataChannelListeners(channel);
    };

    _peerConnection!.onConnectionState = (state) {
      debugPrint('📶 [WEBRTC_STATE_CHANGE] Connection State: $state');
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(state);
      }

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
            if (!_interactionController.isClosed) {
              _interactionController.add(decoded);
            }
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
    if (!_micStateController.isClosed) {
      _micStateController.add(_isMicOn);
    }
  }

  void toggleCamera() {
    _isCameraOn = !_isCameraOn;
    _updateTrackState();
    if (!_cameraStateController.isClosed) {
      _cameraStateController.add(_isCameraOn);
    }
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
      final lines = sdp.split('\n');
      String? vp8Payload;

      // 1. Find VP8 Payload ID
      for (final line in lines) {
        if (line.startsWith('a=rtpmap:') && line.contains('VP8/90000')) {
          // Format: a=rtpmap:<payload> VP8/90000
          final parts = line.split(':');
          if (parts.length > 1) {
            final afterColon = parts[1];
            final spaceParts = afterColon.split(' ');
            if (spaceParts.isNotEmpty) {
              vp8Payload = spaceParts[0];
              break;
            }
          }
        }
      }

      if (vp8Payload == null) {
        return sdp; // VP8 not found, return original
      }

      // 2. Modify m=video line
      final newLines = <String>[];
      bool modified = false;

      for (var line in lines) {
        // Sanitize line (remove \r if present from split)
        var cleanLine = line.trimRight();

        if (!modified && cleanLine.startsWith('m=video')) {
          // Format: m=video <port> <proto> <payloads...>
          final parts = cleanLine.split(' ');
          if (parts.length > 3) {
            // The payloads start from index 3
            final prefix = parts.sublist(0, 3).join(' ');
            final payloads = parts.sublist(3).toList();

            if (payloads.contains(vp8Payload)) {
              payloads.remove(vp8Payload);
              payloads.insert(0, vp8Payload);
              newLines.add('$prefix ${payloads.join(' ')}');
              modified = true;
            } else {
              newLines.add(cleanLine);
            }
          } else {
            newLines.add(cleanLine);
          }
        } else {
          newLines.add(cleanLine);
        }
      }

      return newLines.join('\r\n'); // Re-join with proper CRLF
    } catch (e) {
      debugPrint('⚠️ [WEBRTC_WARN] SDP munging failed: $e');
      return sdp; // Return original on error
    }
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    // 20-second production-grade watchdog for mobile data
    _watchdogTimer = Timer(const Duration(seconds: 20), () {
      debugPrint('🐕 [WEBRTC_WATCHDOG] Watchdog timeout triggered');

      final currentState = _peerConnection?.connectionState;
      if (currentState !=
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        debugPrint(
            '🐕 [WEBRTC_WATCHDOG] Connection failed to reach connected state within 20s. Triggering recovery.');

        _cleanupSession();

        if (!_messageStreamController.isClosed) {
          _messageStreamController.add(
            "Network unstable, searching for a new match",
          );
        }

        // Auto-restart search after recovery
        Future.delayed(const Duration(seconds: 2), () {
          startRandomSearch();
        });
      }
    });
  }

  /// Task 1: Background Persistence Lifecycle Handler
  /// Pauses camera when app is inactive/paused to prevent hardware lock-up
  void handleAppLifecycleState(AppLifecycleState state) {
    if (_localStream == null) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      debugPrint(
          '📷 [WEBRTC_LIFECYCLE] Pausing camera for background state: $state');
      _localStream!.getVideoTracks().forEach((track) => track.enabled = false);
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('📷 [WEBRTC_LIFECYCLE] Resuming camera for foreground state');
      // Only resume if the user hadn't manually turned it off
      _localStream!
          .getVideoTracks()
          .forEach((track) => track.enabled = _isCameraOn);
    }
  }

  void _cleanupSession() {
    debugPrint('🧹 [SESSION_CLEANUP] Cleaning up WebRTC session');
    _isCallActive = false; // RELEASE LOCK

    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    _dataChannel?.close();
    _dataChannel = null;

    _peerConnection?.close();
    _peerConnection = null;

    _roomId = null;
    if (!_remoteStreamController.isClosed) {
      _remoteStreamController.add(null);
    }
    _currentPartnerId = null;
    _queuedRemoteCandidates.clear();
    _pendingMatchData = null; // Clear any partial match data
  }

  void dispose() {
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
