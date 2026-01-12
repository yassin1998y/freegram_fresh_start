import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class RandomChatRepository {
  final FirebaseFirestore _db;

  // WebRTC
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Callbacks
  Function(MediaStream stream)? onLocalStream;
  Function(MediaStream stream)? onRemoteStream;
  Function()? onConnected;
  Function()? onDisconnected;
  Function(String error)? onError;
  Function(Map<String, dynamic> giftData)? onGiftReceived;
  Function(String status)? onStatusChanged;

  // Subscriptions
  StreamSubscription? _roomSubscription;
  StreamSubscription? _candidatesSubscription;
  StreamSubscription? _giftSubscription;
  Timer? _heartbeatTimer;

  // State
  String? _currentRoomId;
  String? _remoteUserId;
  String? get currentRemoteUserId => _remoteUserId;

  // Debug State
  String _lastStatus = "";
  String _rtcState = "New";
  String _iceState = "New";

  // ICE Queue
  final List<RTCIceCandidate> _candidateQueue = [];
  bool _remoteDescriptionSet = false;
  bool _isDisposing = false;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ]
  };

  RandomChatRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Future<void> initialize() async {
    await initLocalStream();
  }

  Future<void> initLocalStream() async {
    if (_localStream != null) return;
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 480},
          'height': {'ideal': 360},
          'frameRate': {'ideal': 15, 'max': 15},
        }
      });
      onLocalStream?.call(_localStream!);
      _updateStatus("Camera ready");
    } catch (e) {
      debugPrint("❌ [RandomChat] Error initializing local stream: $e");
      onError?.call("Camera init failed: $e");
    }
  }

  void _updateStatus(String status) {
    if (_isDisposing) return;
    _lastStatus = status;
    onStatusChanged?.call(status);
    debugPrint("ℹ️ [RandomChat Status] $status");
  }

  void toggleVideo(bool enabled) {
    if (_localStream != null) {
      _localStream!.getVideoTracks().forEach((track) {
        track.enabled = enabled;
      });
    }
  }

  void toggleAudio(bool enabled) {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = enabled;
      });
    }
  }

  Map<String, String> getDebugInfo() {
    return {
      "Room ID": _currentRoomId ?? "None",
      "Role": _isCaller ? "Caller" : "Callee",
      "Remote User": _remoteUserId ?? "Waiting...",
      "Status": _lastStatus,
      "RTC State": _rtcState,
      "ICE State": _iceState,
    };
  }

  // --- Queue System ---

  Future<void> enterQueue(String userId) async {
    _updateStatus("Entering queue...");
    debugPrint('🚀 [RandomChat] Entering queue/search for user: $userId');
    await stopConnection(); // Ensure clean state

    // 1. Search for available rooms
    final cutoff = DateTime.now().subtract(const Duration(seconds: 45));
    try {
      _updateStatus("Searching for partners...");
      final querySnapshot = await _db
          .collection('random_chat_rooms')
          .where('status', isEqualTo: 'waiting')
          .where('lastHeartbeat', isGreaterThan: Timestamp.fromDate(cutoff))
          .orderBy('lastHeartbeat', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final roomDoc = querySnapshot.docs.first;
        final roomId = roomDoc.id;
        final callerId = roomDoc.data()['callerId'];

        // Prevent joining own room (edge case)
        if (callerId == userId) {
          debugPrint('⚠️ [RandomChat] Found own room $roomId, re-listening');
          _currentRoomId = roomId;
          _remoteUserId = null;
          _isCaller = true;
          _startHeartbeat(roomId);
          _listenToRoom(roomId, userId, true);
          _updateStatus("Re-joined own waiting room");
          return;
        }

        debugPrint('🎯 [RandomChat] Found room $roomId, attempting to join...');
        _updateStatus("Found match, joining...");
        bool joined = await _joinRoom(roomId, userId);
        if (!joined) {
          debugPrint('⚠️ [RandomChat] Join failed (room taken), retrying...');
          _updateStatus("Match taken, retrying...");
          // Recursive retry - delay slightly to avoid hammering
          await Future.delayed(const Duration(milliseconds: 500));
          await enterQueue(userId);
        }
      } else {
        debugPrint('🆕 [RandomChat] No room found, creating new room...');
        _updateStatus("No match found, creating room...");
        await _createRoom(userId);
      }
    } catch (e) {
      debugPrint('❌ [RandomChat] Error entering queue: $e');
      onError?.call('Failed to connect: $e');
      _updateStatus("Error: Failed to connect");
    }
  }

  /// ATOMIC ROOM CREATION
  Future<void> _createRoom(String userId) async {
    try {
      _isCaller = true;
      _updateStatus("Initializing signaling...");

      // 1. Init PeerConnection FIRST
      await _initializePeerConnection(userId);

      // 2. Create Offer
      _updateStatus("Creating offer...");
      final roomRef = _db.collection('random_chat_rooms').doc();
      _currentRoomId = roomRef.id;
      _remoteUserId = null;

      RTCSessionDescription offer = await _peerConnection!.createOffer({
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': true,
        },
      });
      await _peerConnection!.setLocalDescription(offer);

      // 3. Atomic Write: Status + Offer + Heartbeat
      _updateStatus("Publishing room...");
      await roomRef.set({
        'callerId': userId,
        'status': 'waiting',
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'lastHeartbeat': FieldValue.serverTimestamp(),
      });

      debugPrint(
          '✅ [RandomChat] Room created ${_currentRoomId} waiting for callee');
      _updateStatus("Waiting for partner...");
      _startHeartbeat(_currentRoomId!);
      _listenToRoom(_currentRoomId!, userId, true);
    } catch (e) {
      debugPrint('❌ [RandomChat] Create room failed: $e');
      onError?.call('Failed to create room: $e');
      stopConnection();
    }
  }

  /// TRANSACTIONAL JOIN
  Future<bool> _joinRoom(String roomId, String userId) async {
    _currentRoomId = roomId;
    _isCaller = false;

    // 1. Transaction to claim result
    // We do NOT init PeerConnection yet to save resources if claim fails

    bool claimed = false;
    RTCSessionDescription? offerData;

    try {
      await _db.runTransaction((transaction) async {
        final docSnapshot = await transaction
            .get(_db.collection('random_chat_rooms').doc(roomId));
        if (!docSnapshot.exists) throw Exception("Room closed");

        final data = docSnapshot.data()!;
        if (data['status'] != 'waiting') {
          throw Exception(
              "Room already taken"); // Will trigger catch and return false
        }

        // Claim it!
        transaction.update(docSnapshot.reference, {
          'calleeId': userId,
          'status': 'matched_pending', // Intermediate status
          'lastHeartbeat': FieldValue.serverTimestamp(),
        });

        final offerMap = data['offer'];
        offerData = RTCSessionDescription(offerMap['sdp'], offerMap['type']);
        _remoteUserId = data['callerId'];
        claimed = true;
      });
    } catch (e) {
      debugPrint("⚠️ [RandomChat] Failed to claim room: $e");
      return false; // Retry queue
    }

    if (!claimed || offerData == null) return false;

    // 2. Room claimed, now init WebRTC
    try {
      debugPrint("✅ [RandomChat] Room claimed, initializing connection...");
      _updateStatus("Connecting to partner...");
      await _initializePeerConnection(userId);

      // 3. Set Remote Description (Atomic from Step 1)
      await _peerConnection!.setRemoteDescription(offerData!);
      _remoteDescriptionSet = true;

      // Flush candidates if any queued (unlikely this early but good practice)
      for (var c in _candidateQueue) {
        await _peerConnection!.addCandidate(c);
      }
      _candidateQueue.clear();

      // 4. Create Answer
      _updateStatus("Sending answer...");
      RTCSessionDescription answer = await _peerConnection!.createAnswer({
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': true,
        },
      });
      await _peerConnection!.setLocalDescription(answer);

      // 5. Update Room with Answer & Final Status
      await _db.collection('random_chat_rooms').doc(roomId).update({
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
        'status': 'matched',
      });

      _startHeartbeat(roomId);
      _listenToRoom(roomId, userId, false);
      return true;
    } catch (e) {
      debugPrint("❌ [RandomChat] Error during join handshake: $e");
      stopConnection();
      return false; // This triggers retry
    }
  }

  // --- Signaling & Listeners ---

  void _listenToRoom(String roomId, String userId, bool isCaller) {
    // Prevent duplicate listeners
    _roomSubscription?.cancel();
    _candidatesSubscription?.cancel();
    _giftSubscription?.cancel(); // Cancel old gift sub

    debugPrint(
        "👂 [RandomChat] Listening to room $roomId as $userId (isCaller: $isCaller)");
    if (isCaller) {
      _updateStatus("Waiting for Answer...");
    } else {
      _updateStatus("Exchanging candidates...");
    }

    // Set up Candidate Listener
    _setupCandidateListener(roomId, isCaller);

    // Listen to Room Changes (Answer / Remote ID)
    _roomSubscription = _db
        .collection('random_chat_rooms')
        .doc(roomId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) {
        debugPrint("⚠️ [RandomChat] Room deleted remotely");
        stopConnection();
        onDisconnected?.call();
        _updateStatus("Disconnected (Remote hung up)");
        return;
      }

      final data = snapshot.data();
      if (data == null) return;

      // Handle explicit disconnection signal
      if (data['status'] == 'ended' || data['status'] == 'disconnected') {
        debugPrint("ℹ️ [RandomChat] Partner left (Status: ${data['status']})");
        stopConnection();
        onDisconnected?.call();
        _updateStatus("Partner Disconnected");
        return;
      }

      // Update Remote ID if needed
      if (_remoteUserId == null) {
        if (data['callerId'] == userId) {
          _remoteUserId = data['calleeId'];
        } else {
          _remoteUserId = data['callerId'];
        }
        if (_remoteUserId != null) {
          _updateStatus("Partner found: ${_remoteUserId!.substring(0, 4)}...");
        }
      }

      // Handle Answer (For Caller)
      if (isCaller) {
        final answer = data['answer'];
        if (answer != null &&
            _peerConnection != null &&
            _peerConnection!.getRemoteDescription() == null) {
          debugPrint("📩 [RandomChat] Received ANSWER from callee");
          _updateStatus("Received answer, connecting...");
          try {
            await _peerConnection!.setRemoteDescription(
                RTCSessionDescription(answer['sdp'], answer['type']));
            _remoteDescriptionSet = true;

            // Flush queue
            for (var c in _candidateQueue) {
              await _peerConnection!.addCandidate(c);
            }
            _candidateQueue.clear();
          } catch (e) {
            debugPrint("❌ [RandomChat] Error setting remote description: $e");
          }
        }
      }
    }, onError: (e) {
      debugPrint("❌ [RandomChat] Room listener error: $e");
    });

    _listenToGifts(roomId, userId);
  }

  void _setupCandidateListener(String roomId, bool isCaller) {
    _candidatesSubscription?.cancel();

    final targetCollection = isCaller ? 'calleeCandidates' : 'callerCandidates';
    debugPrint(
        "👂 [RandomChat] Listening for ICE candidates in $targetCollection");

    _candidatesSubscription = _db
        .collection('random_chat_rooms')
        .doc(roomId)
        .collection(targetCollection)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final candidate = RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            );
            _addCandidate(candidate);
          }
        }
      }
    });
  }

  // --- WebRTC Internals ---

  Future<void> _initializePeerConnection(String userId) async {
    // 0. Safety: Close existing PC if any
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    if (_localStream == null) {
      await initLocalStream();
    } else {
      // Ensure we re-emit local stream if view reloaded
      onLocalStream?.call(_localStream!);
    }

    _peerConnection = await createPeerConnection(_configuration);
    _remoteDescriptionSet = false;
    _candidateQueue.clear();
    _rtcState = "Initializing";
    _iceState = "New";

    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
    }

    // ICE Candidate Callback
    _peerConnection!.onIceCandidate = (candidate) async {
      if (_currentRoomId == null) return;

      String collection;
      if (_isCaller) {
        collection = 'callerCandidates';
      } else {
        collection = 'calleeCandidates';
      }

      // Retry persistence
      try {
        await _db
            .collection('random_chat_rooms')
            .doc(_currentRoomId)
            .collection(collection)
            .add(candidate.toMap());
      } catch (e) {
        debugPrint("❌ Failed to send ICE candidate: $e");
      }
    };

    _peerConnection!.onTrack = (event) {
      // Guard: Only fire once per stream
      if (!_connectedOnce && event.streams.isNotEmpty) {
        debugPrint("📺 [RandomChat] Received REMOTE TRACK (First time)");
        _connectedOnce = true;
        _remoteStream = event.streams[0];
        onRemoteStream?.call(_remoteStream!);
        onConnected?.call();
        _updateStatus("Stream Connected!");
      }
    };

    _peerConnection!.onConnectionState = (state) {
      debugPrint("🔌 [RandomChat] WebRTC State Check: $state");
      _rtcState = state.toString();
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _updateStatus("Connected (Waiting for stream...)");
        // REMOVED: Do NOT trigger onConnected here. Wait for onTrack.
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        if (!_isDisposing) {
          onDisconnected?.call();
          _updateStatus("Disconnected: $state");
        }
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      _iceState = state.toString();
      debugPrint("🧊 [RandomChat] ICE State: $state");
    };
  }

  // Helper State
  bool _isCaller = false;
  bool _connectedOnce = false; // Guard for onTrack

  Future<void> _addCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection == null) return;
    try {
      if (_remoteDescriptionSet &&
          _peerConnection!.signalingState !=
              RTCSignalingState.RTCSignalingStateStable) {
        await _peerConnection!.addCandidate(candidate);
        debugPrint("✅ [RandomChat] Added ICE candidate (Unstable)");
      } else if (_remoteDescriptionSet) {
        await _peerConnection!.addCandidate(candidate);
        debugPrint("✅ [RandomChat] Added ICE candidate");
      } else {
        _candidateQueue.add(candidate);
        debugPrint("⏳ [RandomChat] Queued ICE candidate (No remote desc)");
      }
    } catch (e) {
      debugPrint("⚠️ Error adding candidate: $e");
    }
  }

  // --- Utility ---

  void _startHeartbeat(String roomId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentRoomId == roomId) {
        _db.collection('random_chat_rooms').doc(roomId).update({
          'lastHeartbeat': FieldValue.serverTimestamp(),
        }).catchError((e) {
          debugPrint("⚠️ Heartbeat missed: $e");
          timer.cancel(); // Stop if doc gone
        });
      } else {
        timer.cancel();
      }
    });
  }

  /// Stops current PeerConnection and Room logic but KEEPS LocalStream (Camera) alive.
  /// Use this when switching matches.
  Future<void> stopConnection() async {
    debugPrint("🛑 [RandomChat] Stopping connection (keeping camera)...");
    _updateStatus("Disconnected");
    _heartbeatTimer?.cancel();
    _roomSubscription?.cancel();
    _candidatesSubscription?.cancel();
    _giftSubscription?.cancel();

    _remoteUserId = null;
    _remoteDescriptionSet = false;
    _connectedOnce = false; // Reset guard
    _candidateQueue.clear();

    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }
    // Also clear remote stream reference
    _remoteStream = null;

    _rtcState = "Closed";
    _iceState = "Closed";

    // Clean up room if needed
    final roomIdToCheck = _currentRoomId;
    _currentRoomId = null;

    if (roomIdToCheck != null) {
      if (_isCaller) {
        try {
          await _db.collection('random_chat_rooms').doc(roomIdToCheck).delete();
        } catch (e) {
          // Ignore delete errors
        }
      } else {
        try {
          // Notify caller we left
          await _db.collection('random_chat_rooms').doc(roomIdToCheck).update({
            'status': 'ended' // or 'disconnected'
          });
        } catch (e) {}
      }
    }
  }

  /// Full dispose: Stops connection AND Camera/Mic resources.
  /// Use this when leaving the screen.
  Future<void> dispose() async {
    _isDisposing = true;
    await stopConnection();

    if (_localStream != null) {
      debugPrint("🎥 [RandomChat] Disposing Local Stream & Tracks...");
      _localStream!.getTracks().forEach((track) {
        track.stop();
      });
      await _localStream!.dispose();
      _localStream = null;
    }
    _isDisposing = false;
  }

  // --- Feature Methods ---

  Future<void> reportUser(
      {required String myId,
      required String remoteId,
      required String reason}) async {
    await _db.collection('reports').add({
      'reporterId': myId,
      'reportedId': remoteId,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> blockUser(
      {required String myId, required String remoteId}) async {
    await _db
        .collection('users')
        .doc(myId)
        .collection('blocked')
        .doc(remoteId)
        .set({
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Send Friend Request
  Future<void> sendFriendRequest(
      {required String myId, required String remoteId}) async {
    // Check dupes
    final existing = await _db
        .collection('users')
        .doc(remoteId)
        .collection('friend_requests')
        .where('fromId', isEqualTo: myId)
        .get();
    if (existing.docs.isNotEmpty) return;

    await _db
        .collection('users')
        .doc(remoteId)
        .collection('friend_requests')
        .add({
      'fromId': myId,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
      'source': 'random_chat',
    });
  }

  // --- Gifting ---
  Future<void> sendGift({
    required String senderId,
    required String giftId,
    required String name,
    required String animationUrl,
    required String thumbnailUrl,
  }) async {
    if (_currentRoomId == null) return;
    await _db
        .collection('random_chat_rooms')
        .doc(_currentRoomId)
        .collection('gifts')
        .add({
      'senderId': senderId,
      'giftId': giftId,
      'name': name,
      'animationUrl': animationUrl,
      'thumbnailUrl': thumbnailUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _listenToGifts(String roomId, String myUserId) {
    _giftSubscription?.cancel();
    _giftSubscription = _db
        .collection('random_chat_rooms')
        .doc(roomId)
        .collection('gifts')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        if (data['timestamp'] != null) {
          onGiftReceived?.call(data);
        }
      }
    });
  }
}
