// lib/services/remote_command_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:freegram/utils/haptic_helper.dart';

/// Service that listens for remote commands (haptics, animations) sent from other users.
class RemoteCommandService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  StreamSubscription? _commandSubscription;
  VoidCallback? onSuccessAnimation;

  RemoteCommandService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  void init() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _startListening(user.uid);
      } else {
        _stopListening();
      }
    });
  }

  void _startListening(String userId) {
    _stopListening();

    debugPrint(
        'RemoteCommandService: Started listening for commands for user: $userId');

    _commandSubscription = _db
        .collection('users')
        .doc(userId)
        .collection('commands')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            _handleCommand(data, change.doc.reference);
          }
        }
      }
    });
  }

  void _handleCommand(Map<String, dynamic> data, DocumentReference ref) async {
    final command = data['command'] as String?;
    // final payload = data['payload'] as Map<String, dynamic>?;

    debugPrint('RemoteCommandService: Received command: $command');

    switch (command) {
      case 'haptic_reciprocity':
        HapticHelper.lightImpact();
        break;
      case 'success_animation':
        HapticHelper.success();
        onSuccessAnimation?.call();
        break;
      default:
        debugPrint('RemoteCommandService: Unknown command: $command');
    }

    // Delete the command after processing
    try {
      await ref.delete();
    } catch (e) {
      debugPrint('RemoteCommandService: Error deleting command doc: $e');
    }
  }

  void _stopListening() {
    _commandSubscription?.cancel();
    _commandSubscription = null;
  }

  void dispose() {
    _stopListening();
  }
}
