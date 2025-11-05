// lib/services/fcm_token_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Service to manage FCM tokens for push notifications
/// Professional implementation with multi-device support
class FcmTokenService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseMessaging _messaging;

  FcmTokenService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseMessaging? messaging,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _messaging = messaging ?? FirebaseMessaging.instance;

  bool _isInitialized = false;

  /// Initialize FCM token management
  /// Call this on app launch after user is authenticated
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          debugPrint('[FCM] No user logged in, skipping token setup');
        }
        return;
      }

      // Listen for token refresh (only set up once)
      _messaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          debugPrint('[FCM] Token refreshed: ${newToken.substring(0, 20)}...');
        }
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          _saveTokenToFirestore(newToken, currentUser.uid);
        }
      });

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('[FCM] Token service initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Error initializing token service: $e');
      }
    }
  }

  /// Get FCM token with retry logic
  Future<String?> _getToken() async {
    try {
      // Request notification permissions first
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        if (kDebugMode) {
          debugPrint('[FCM] Notification permission not granted');
        }
        return null;
      }

      // Get token
      final token = await _messaging.getToken();
      if (token != null && kDebugMode) {
        debugPrint('[FCM] Got token: ${token.substring(0, 20)}...');
      }
      return token;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Error getting token: $e');
      }
      return null;
    }
  }

  /// Save token to Firestore with device info
  /// Professional apps store multiple tokens per user for multi-device support
  Future<void> _saveTokenToFirestore(String token, [String? userId]) async {
    try {
      final uid = userId ?? _auth.currentUser?.uid;
      if (uid == null) return;

      final userRef = _firestore.collection('users').doc(uid);

      // Use regular timestamp instead of FieldValue.serverTimestamp()
      // because serverTimestamp can't be used inside arrayUnion
      final now = DateTime.now().toUtc().toIso8601String();

      // Store token in array for multi-device support
      // Also update the main fcmToken field for backward compatibility
      await userRef.set({
        'fcmToken': token, // Current device token (backward compatible)
        'fcmTokens': FieldValue.arrayUnion([
          {
            'token': token,
            'platform': defaultTargetPlatform.name,
            'lastUpdated': now,
            'userId': uid,
          }
        ]),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('[FCM] Token saved to Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Error saving token to Firestore: $e');
      }
    }
  }

  /// Update token when user logs in
  /// Call this after successful authentication
  /// Consolidates initialization and token update to prevent duplicate work
  Future<void> updateTokenOnLogin(String userId) async {
    try {
      // Ensure service is initialized
      if (!_isInitialized) {
        await initialize();
      }

      final token = await _getToken();
      if (token != null) {
        await _saveTokenToFirestore(token, userId);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Error updating token on login: $e');
      }
    }
  }

  /// Remove token when user logs out
  /// Important for privacy and preventing notifications to wrong device
  /// Accepts userId parameter to avoid race condition with Firebase signOut
  Future<void> removeTokenOnLogout(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      final userRef = _firestore.collection('users').doc(userId);

      // Get all tokens for this user and remove only the matching one
      final doc = await userRef.get();
      if (doc.exists) {
        final data = doc.data();
        final tokens = data?['fcmTokens'] as List?;

        if (tokens != null) {
          // Find and remove tokens with matching token string
          final tokensToRemove =
              tokens.where((t) => t is Map && t['token'] == token).toList();

          for (final tokenObj in tokensToRemove) {
            await userRef.update({
              'fcmTokens': FieldValue.arrayRemove([tokenObj]),
            });
          }
        }
      }

      // Optionally delete the FCM token from FCM service
      await _messaging.deleteToken();

      if (kDebugMode) {
        debugPrint('[FCM] Token removed on logout');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Error removing token on logout: $e');
      }
    }
  }

  /// Clean up expired or invalid tokens
  /// Reserved for future use - can be called periodically or when invalid tokens detected
  Future<void> cleanupInvalidTokens(
      String userId, List<String> invalidTokens) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      // Get current tokens
      final doc = await userRef.get();
      if (!doc.exists) return;

      final data = doc.data();
      final tokens = data?['fcmTokens'] as List?;

      if (tokens == null) return;

      // Find and remove tokens with matching token strings
      final batch = _firestore.batch();

      for (final token in invalidTokens) {
        final tokensToRemove =
            tokens.where((t) => t is Map && t['token'] == token).toList();

        for (final tokenObj in tokensToRemove) {
          batch.update(userRef, {
            'fcmTokens': FieldValue.arrayRemove([tokenObj]),
          });
        }
      }

      await batch.commit();

      if (kDebugMode) {
        debugPrint('[FCM] Cleaned up ${invalidTokens.length} invalid tokens');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Error cleaning up invalid tokens: $e');
      }
    }
  }

  /// Get current token (useful for debugging)
  Future<String?> getCurrentToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Error getting current token: $e');
      }
      return null;
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Error checking notification status: $e');
      }
      return false;
    }
  }
}
