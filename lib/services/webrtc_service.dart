import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class WebRTCService {
  // Singleton pattern
  WebRTCService._internal();
  static final WebRTCService instance = WebRTCService._internal();

  // Socket and WebRTC objects
  IO.Socket? _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  // Configuration
  String? _roomId;
  bool _isWaitingToSearch = false; // Flag for race condition fix

  // Notifiers for UI updates
  final ValueNotifier<String> connectionState = ValueNotifier('disconnected');
  final ValueNotifier<MediaStream?> localStream = ValueNotifier(null);
  final ValueNotifier<MediaStream?> remoteStream = ValueNotifier(null);

  // Initialize the service: Connect to Socket.IO
  Future<void> initialize() async {
    final url = dotenv.env['SIGNALING_SERVER_URL'];
    if (url == null || url.isEmpty) {
      debugPrint('Error: SIGNALING_SERVER_URL not found in .env');
      return;
    }

    // Connect only if not already connected
    if (_socket != null && _socket!.connected) {
      // If we were waiting to search and we are already connected, trigger it now.
      if (_isWaitingToSearch) {
        debugPrint('🚀 Emitting find_random_match (already connected)');
        _socket!.emit('find_random_match');
        _isWaitingToSearch = false;
      }
      return;
    }

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();
    connectionState.value = 'connecting';

    _socket!.onConnect((_) {
      debugPrint('Socket Connected: ${_socket?.id}');
      connectionState.value = 'connected';

      // Fix Race Condition: Check if we were waiting to search
      if (_isWaitingToSearch) {
        debugPrint('🚀 Emitting find_random_match (onConnect)');
        _socket!.emit('find_random_match');
        _isWaitingToSearch = false;
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('Socket Disconnected');
      connectionState.value = 'disconnected';
    });

    // --- Random Matching Events ---
    _socket!.on('match_found', (data) {
      debugPrint('Match found: $data');
      _roomId = data['roomId'];
      // 'role' might be 'offer' or 'answer'
      final role = data['role'];
      if (role == 'offer') {
        _startCall(isCaller: true);
      } else {
        _startCall(isCaller: false);
      }
    });

    _socket!.on('waiting_for_match', (_) {
      debugPrint('Waiting for match...');
      connectionState.value = 'searching';
    });

    // --- Private Call Events ---
    _socket!.on('user_joined', (data) {
      debugPrint('User joined private room: $data');
      // If someone joins our room, we initiate the call?
      // Or we wait for them? Protocol: Existing user initiates offer when new user joins.
      _startCall(isCaller: true);
    });

    // --- WebRTC Signaling Events ---
    _socket!.on('offer', (data) async {
      debugPrint('Received offer');
      final offerMap = data['offer'];
      if (_peerConnection == null) {
        await _createPeerConnection();
      }
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offerMap['sdp'], offerMap['type']),
      );

      // Create Answer with VP8 Check
      RTCSessionDescription answer = await _peerConnection!.createAnswer();

      // Munge SDP to prefer VP8
      String mungedSDP = _mungeSDP(answer.sdp!);
      answer = RTCSessionDescription(mungedSDP, answer.type);

      await _peerConnection!.setLocalDescription(answer);

      _socket!.emit('answer', {
        'roomId': _roomId,
        'answer': {'sdp': answer.sdp, 'type': answer.type},
      });
    });

    _socket!.on('answer', (data) async {
      debugPrint('Received answer');
      final answerMap = data['answer'];
      if (_peerConnection != null) {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(answerMap['sdp'], answerMap['type']),
        );
      }
    });

    _socket!.on('candidate', (data) async {
      debugPrint('Received candidate');
      final candidateMap = data['candidate'];
      if (_peerConnection != null) {
        await _peerConnection!.addCandidate(
          RTCIceCandidate(
            candidateMap['candidate'],
            candidateMap['sdpMid'],
            candidateMap['sdpMLineIndex'],
          ),
        );
      }
    });

    _socket!.on('peer_disconnected', (_) {
      debugPrint('Peer disconnected');
      endCall(); // Clean up but maybe keep socket alive
      connectionState.value =
          'connected'; // Back to connected state, ready for next
    });
  }

  // --- Public Methods ---

  void startRandomSearch() {
    if (_socket != null && _socket!.connected) {
      debugPrint('🚀 Emitting find_random_match');
      _socket!.emit('find_random_match');
    } else {
      debugPrint('Socket not connected yet, queueing search...');
      _isWaitingToSearch = true;
      initialize();
    }
  }

  void startPrivateCall(String roomId) {
    if (_socket == null || !_socket!.connected) return;
    _roomId = roomId;
    _socket!.emit('join_private_call', {'roomId': roomId});
    // We join and wait for 'user_joined' or if needed we can start call immediately if we know peer is there.
    // For this simple impl, we wait for 'user_joined' to trigger offer, OR if we are the second one joining,
    // the existing user will trigger offer. So simply joining is enough.
  }

  void endCall() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
    localStream.value = null;

    remoteStream.value = null;

    _peerConnection?.close();
    _peerConnection = null;

    _roomId = null;
    _isWaitingToSearch = false;

    // If we were searching/in-call, we are effectively just 'connected' to socket now
    // unless we want to fully disconnect socket? Usually keeping socket open is better.
    // The prompt says "resets state".
    if (_socket != null && _socket!.connected) {
      connectionState.value = 'connected';
    } else {
      connectionState.value = 'disconnected';
    }
  }

  // --- Internal Helpers ---

  // SDP Munging to Prefer VP8
  String _mungeSDP(String sdp) {
    // Basic logic to move VP8 payload type map to the front of m=video
    /*
      Example SDP lines:
      m=video 9 UDP/TLS/RTP/SAVPF 96 97 98 99 100 101
      a=rtpmap:96 VP8/90000
    */

    // 1. Find the payload type for VP8
    final RegExp vp8MapRegex = RegExp(r"a=rtpmap:(\d+) VP8/90000");
    final match = vp8MapRegex.firstMatch(sdp);

    if (match == null) {
      debugPrint('Warning: VP8 not found in SDP');
      return sdp;
    }

    final String vp8PayloadType = match.group(1)!;

    // 2. Find the m=video line and move the type to the front
    final RegExp mVideoRegex = RegExp(r"m=video (\d+) ([A-Z/]+) ([0-9 ]+)");

    return sdp.replaceAllMapped(mVideoRegex, (Match m) {
      final String port = m.group(1)!;
      final String protocol = m.group(2)!;
      final String payloads = m.group(3)!;

      final List<String> types = payloads.split(' ');

      // Remove VP8 type if present and add it to the front
      types.remove(vp8PayloadType);
      types.insert(0, vp8PayloadType);

      final String newPayloads = types.join(' ');

      debugPrint(
          'Munged SDP: Moving VP8 ($vp8PayloadType) to front: $newPayloads');

      return "m=video $port $protocol $newPayloads";
    });
  }

  Future<void> _createPeerConnection() async {
    final meteredUser = dotenv.env['METERED_USERNAME'];
    final meteredPass = dotenv.env['METERED_PASSWORD'];

    final Map<String, dynamic> configuration = {
      'iceServers': [
        {
          'urls': 'stun:stun.l.google.com:19302',
        },
        if (meteredUser != null && meteredPass != null) ...[
          {
            'urls': 'turn:global.turn.metered.ca:80?transport=udp',
            'username': meteredUser,
            'credential': meteredPass,
          },
          {
            'urls': 'turn:global.turn.metered.ca:80?transport=tcp',
            'username': meteredUser,
            'credential': meteredPass,
          },
          {
            'urls': 'turn:global.turn.metered.ca:443?transport=tcp',
            'username': meteredUser,
            'credential': meteredPass,
          },
        ]
      ],
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(configuration);

    _registerPeerConnectionListeners();

    // Get local user media
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': 'user',
      },
    });

    _localStream = stream;
    localStream.value = stream;

    stream.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, stream);
    });
  }

  void _registerPeerConnectionListeners() {
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      if (_roomId != null) {
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

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStream.value = event.streams[0];
      }
    };

    _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('Connection state change: $state');
      // Map WebRTC stats to our simple connectionState if needed
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        // We are in a call
      }
    };
  }

  Future<void> _startCall({required bool isCaller}) async {
    if (_peerConnection == null) {
      await _createPeerConnection();
    }

    if (isCaller) {
      RTCSessionDescription offer = await _peerConnection!.createOffer();

      // Munge SDP to prefer VP8
      String mungedSDP = _mungeSDP(offer.sdp!);
      offer = RTCSessionDescription(mungedSDP, offer.type);

      await _peerConnection!.setLocalDescription(offer);

      _socket!.emit('offer', {
        'roomId': _roomId,
        'offer': {'sdp': offer.sdp, 'type': offer.type},
      });
    }
  }
}
