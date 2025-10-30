// lib/repositories/auth_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode and debugPrint
import 'package:freegram/models/user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart'; // For clearing user-specific data on logout
import 'dart:convert';
import 'package:crypto/crypto.dart';

String _uidShortFromFullAuth(String fullId) {
  if (fullId.isEmpty) return '';
  final bytes = utf8.encode(fullId);
  final digest = sha256.convert(bytes);
  return digest.toString().substring(0, 8);
}

// Conditional debug logging
void _debugLog(String message) {
  if (kDebugMode) {
    debugPrint('AuthRepository: $message');
  }
}

class AuthRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '',
              scopes: ['email', 'profile'],
            );

  Future<void> createUser({
    required String uid,
    required String username,
    required String email,
    String? photoUrl,
  }) {
    final now = DateTime.now();
    final newUser = UserModel(
      id: uid,
      username: username,
      email: email,
      photoUrl: photoUrl ?? '',
      lastSeen: now,
      createdAt: now,
      lastFreeSuperLike: now.subtract(const Duration(days: 1)),
      lastNearbyDiscoveryDate: DateTime.fromMillisecondsSinceEpoch(0),
    );
    final userMap = newUser.toMap();
    _debugLog("Creating user document for UID: $uid");
    return _db.collection('users').doc(uid).set(userMap);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    User? user;
    try {
      _debugLog("Creating Auth user for $email");
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = userCredential.user;
      if (user == null) {
        throw Exception('Firebase Auth user creation returned null.');
      }
      _debugLog("Auth user created successfully. UID: ${user.uid}");

      await user.updateDisplayName(username);
      _debugLog("Display name updated for ${user.uid}");

      await createUser(
        uid: user.uid,
        username: username,
        email: email,
      );
      _debugLog("Firestore document created successfully for ${user.uid}");
    } catch (e) {
      if (user == null) {
        _debugLog("Error during Firebase Auth user creation: $e");
      } else {
        final docExists =
            (await _db.collection('users').doc(user.uid).get()).exists;
        if (!docExists) {
          _debugLog(
              "Error during Firestore document creation for ${user.uid}: $e");
        } else {
          _debugLog("Error during sign up: $e");
        }
      }
      rethrow;
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    _debugLog("Attempting Google Sign In");

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _debugLog("Google Sign In aborted by user");
        throw FirebaseAuthException(
            code: 'ERROR_ABORTED_BY_USER', message: 'Sign in aborted by user');
      }

      _debugLog("Google Sign In successful, getting auth");
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        _debugLog("Missing access token or ID token from Google");
        throw FirebaseAuthException(
            code: 'ERROR_MISSING_TOKENS',
            message: 'Failed to get authentication tokens from Google');
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      _debugLog("Signing in with Firebase credential");
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        _debugLog("Firebase sign in successful. UID: ${user.uid}");

        // Check if email already exists with different provider
        await _handleDuplicateEmail(user.email);

        final userDoc = await _db.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          _debugLog("Creating new Firestore doc for ${user.uid}");
          await createUser(
            uid: user.uid,
            username: user.displayName ?? 'Google User',
            email: user.email ?? '',
            photoUrl: user.photoURL,
          );

          // Properly wait for document to be created
          await _waitForDocumentCreation(user.uid);
        } else {
          _debugLog("Firestore doc found for ${user.uid}");
          // Ensure uidShort exists
          if (!userDoc.data()!.containsKey('uidShort')) {
            final calculatedShortId = _uidShortFromFullAuth(user.uid);
            await _db
                .collection('users')
                .doc(user.uid)
                .update({'uidShort': calculatedShortId});
            _debugLog("Added missing uidShort for existing user");
          }
        }
      } else {
        _debugLog("Firebase sign in returned null user");
      }
      return userCredential;
    } catch (e) {
      _debugLog("Error during Google Sign In: $e");
      if (e is FirebaseAuthException) {
        rethrow;
      } else {
        throw FirebaseAuthException(
          code: 'ERROR_GOOGLE_SIGNIN_FAILED',
          message: 'Google Sign-In failed: ${e.toString()}',
        );
      }
    }
  }

  // Helper method to wait for document creation (replaces artificial delay)
  Future<void> _waitForDocumentCreation(String uid,
      {int maxRetries = 10}) async {
    for (int i = 0; i < maxRetries; i++) {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        _debugLog("Document confirmed to exist after ${i + 1} attempts");
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _debugLog(
        "Warning: Document creation could not be confirmed after $maxRetries attempts");
  }

  // Helper method to detect duplicate accounts by email
  Future<void> _handleDuplicateEmail(String? email) async {
    if (email == null || email.isEmpty) return;

    try {
      final existingUsers = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        _debugLog("Found existing account with email $email");
        // Could link accounts here or throw error
        // For now, we'll allow it (Firebase handles multiple providers)
      }
    } catch (e) {
      _debugLog("Error checking for duplicate email: $e");
    }
  }

  Future<UserCredential> signInWithFacebook() async {
    _debugLog("Attempting Facebook Sign In");

    // Request email permission explicitly
    final LoginResult result = await FacebookAuth.instance.login(
      permissions: ['email', 'public_profile'],
    );

    if (result.status == LoginStatus.success) {
      _debugLog("Facebook login successful, getting credential");
      final AccessToken accessToken = result.accessToken!;
      final AuthCredential credential =
          FacebookAuthProvider.credential(accessToken.token);

      _debugLog("Signing in with Firebase credential");
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        _debugLog("Firebase sign in successful. UID: ${user.uid}");

        // Check for duplicate email
        await _handleDuplicateEmail(user.email);

        final userDoc = await _db.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          _debugLog("Fetching Facebook user data and creating Firestore doc");
          final userData = await FacebookAuth.instance.getUserData();

          // Validate email was granted
          final email = userData['email'] ?? user.email ?? '';
          if (email.isEmpty) {
            _debugLog("Warning: Email permission not granted by user");
          }

          await createUser(
            uid: user.uid,
            username: userData['name'] ?? user.displayName ?? 'Facebook User',
            email: email,
            photoUrl: userData['picture']?['data']?['url'] ?? user.photoURL,
          );

          // Wait for document creation
          await _waitForDocumentCreation(user.uid);
        } else {
          _debugLog("Firestore doc found for ${user.uid}");
          // Ensure uidShort exists
          if (!userDoc.data()!.containsKey('uidShort')) {
            final calculatedShortId = _uidShortFromFullAuth(user.uid);
            await _db
                .collection('users')
                .doc(user.uid)
                .update({'uidShort': calculatedShortId});
            _debugLog("Added missing uidShort for existing user");
          }
        }
      } else {
        _debugLog("Firebase sign in returned null user");
      }
      return userCredential;
    } else {
      _debugLog("Facebook login failed: ${result.message}");
      throw FirebaseAuthException(
        code: 'ERROR_FACEBOOK_LOGIN_FAILED',
        message: result.message ?? 'Facebook login was not successful',
      );
    }
  }

  Future<void> signOut() async {
    _debugLog("Signing out");

    // Clear all user-specific Hive data before signing out
    try {
      final settingsBox = await Hive.openBox('settings');

      // Clear all profile-related flags
      await settingsBox.delete('hasCheckedProfileCompleteness');
      await settingsBox.delete('hasSeenOnboarding');

      // Clear any user-specific keys (iterate and remove user-specific ones)
      final keysToDelete = <dynamic>[];
      for (var key in settingsBox.keys) {
        final keyStr = key.toString();
        if (keyStr.startsWith('profileComplete_') ||
            keyStr.startsWith('hasChecked_') ||
            keyStr.startsWith('user_')) {
          keysToDelete.add(key);
        }
      }

      for (var key in keysToDelete) {
        await settingsBox.delete(key);
      }

      _debugLog(
          "Cleared ${keysToDelete.length + 2} user-specific Hive settings");
    } catch (e) {
      _debugLog("Error clearing Hive data on logout: $e");
      // Don't fail logout if Hive cleanup fails
    }

    try {
      await _googleSignIn.signOut();
      _debugLog("Google sign out successful");
    } catch (e) {
      _debugLog("Error signing out from Google: $e");
    }
    try {
      await FacebookAuth.instance.logOut();
      _debugLog("Facebook sign out successful");
    } catch (e) {
      _debugLog("Error signing out from Facebook: $e");
    }
    await _auth.signOut();
    _debugLog("Firebase sign out successful");
  }
}
