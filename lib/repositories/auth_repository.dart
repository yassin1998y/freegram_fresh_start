// lib/repositories/auth_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // Keep for debugPrint
import 'package:freegram/models/user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

String _uidShortFromFullAuth(String fullId) {
  if (fullId.isEmpty) return '';
  final bytes = utf8.encode(fullId);
  final digest = sha256.convert(bytes);
  return digest.toString().substring(0, 8);
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
        _googleSignIn = googleSignIn ?? GoogleSignIn(
          serverClientId: '60183775527-mifomgjm2uvpt3esk1so8580asto7vk6.apps.googleusercontent.com', // Web client ID
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
    debugPrint("AuthRepository: Creating user document for UID: $uid with data: $userMap"); // Log data being saved
    return _db.collection('users').doc(uid).set(userMap);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    User? user; // Declare user variable outside try block
    try {
      debugPrint("AuthRepository: Attempting to create Auth user for $email..."); // --- DEBUG ---
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = userCredential.user; // Assign user here
      if (user == null) {
        throw Exception('Firebase Auth user creation returned null.');
      }
      debugPrint("AuthRepository: Auth user created successfully. UID: ${user.uid}"); // --- DEBUG ---

      debugPrint("AuthRepository: Attempting to update display name for ${user.uid}..."); // --- DEBUG ---
      await user.updateDisplayName(username);
      debugPrint("AuthRepository: Display name updated."); // --- DEBUG ---

      debugPrint("AuthRepository: Attempting to create Firestore document for ${user.uid}..."); // --- DEBUG ---
      await createUser(
        uid: user.uid,
        username: username,
        email: email,
      );
      debugPrint("AuthRepository: Firestore document created successfully for ${user.uid}."); // --- DEBUG ---

    } catch (e) {
      // --- DEBUG: Log specific error point ---
      if (user == null) {
        debugPrint("AuthRepository: Error during Firebase Auth user creation: $e");
      } else if (!(await _db.collection('users').doc(user.uid).get()).exists) {
        debugPrint("AuthRepository: Error after Auth user creation, during Firestore document creation for ${user.uid}: $e");
      } else {
        debugPrint("AuthRepository: Error during sign up (unknown point): $e");
      }
      // --- END DEBUG ---
      rethrow; // Re-throw the error for the BLoC to catch
    }
  }


  Future<UserCredential> signInWithGoogle() async {
    debugPrint("AuthRepository: Attempting Google Sign In..."); // --- DEBUG ---
    
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint("AuthRepository: Google Sign In aborted by user."); // --- DEBUG ---
        throw FirebaseAuthException(
            code: 'ERROR_ABORTED_BY_USER', message: 'Sign in aborted by user');
      }
      
      debugPrint("AuthRepository: Google Sign In successful, getting auth..."); // --- DEBUG ---
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint("AuthRepository: Missing access token or ID token from Google");
        throw FirebaseAuthException(
            code: 'ERROR_MISSING_TOKENS', 
            message: 'Failed to get authentication tokens from Google');
      }
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      debugPrint("AuthRepository: Signing in with Firebase credential..."); // --- DEBUG ---
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

    if (user != null) {
      debugPrint("AuthRepository: Firebase sign in successful. UID: ${user.uid}. Checking Firestore doc..."); // --- DEBUG ---
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        debugPrint("AuthRepository: Firestore doc not found for ${user.uid}. Creating..."); // --- DEBUG ---
        await createUser(
          uid: user.uid,
          username: user.displayName ?? 'Google User',
          email: user.email ?? '',
          photoUrl: user.photoURL,
        );
        debugPrint("AuthRepository: Firestore doc created for ${user.uid}."); // --- DEBUG ---
        
        // Wait a moment to ensure the document is fully written
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint("AuthRepository: Waiting for Firestore document to be fully written...");
      } else {
        debugPrint("AuthRepository: Firestore doc found for ${user.uid}. Checking uidShort..."); // --- DEBUG ---
        if (!userDoc.data()!.containsKey('uidShort')) {
          final calculatedShortId = _uidShortFromFullAuth(user.uid);
          await _db.collection('users').doc(user.uid).update({'uidShort': calculatedShortId});
          debugPrint("AuthRepository: Added missing uidShort for existing user ${user.uid}");
        }
      }
    } else {
      debugPrint("AuthRepository: Firebase sign in returned null user."); // --- DEBUG ---
    }
    return userCredential;
    
    } catch (e) {
      debugPrint("AuthRepository: Error during Google Sign In: $e");
      if (e is FirebaseAuthException) {
        rethrow; // Re-throw Firebase auth exceptions as-is
      } else {
        // Wrap other exceptions in FirebaseAuthException
        throw FirebaseAuthException(
          code: 'ERROR_GOOGLE_SIGNIN_FAILED',
          message: 'Google Sign-In failed: ${e.toString()}',
        );
      }
    }
  }

  Future<UserCredential> signInWithFacebook() async {
    debugPrint("AuthRepository: Attempting Facebook Sign In..."); // --- DEBUG ---
    final LoginResult result = await FacebookAuth.instance.login();
    if (result.status == LoginStatus.success) {
      debugPrint("AuthRepository: Facebook login successful, getting credential..."); // --- DEBUG ---
      final AccessToken accessToken = result.accessToken!;
      final AuthCredential credential =
      FacebookAuthProvider.credential(accessToken.token);
      debugPrint("AuthRepository: Signing in with Firebase credential..."); // --- DEBUG ---
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        debugPrint("AuthRepository: Firebase sign in successful. UID: ${user.uid}. Checking Firestore doc..."); // --- DEBUG ---
        final userDoc = await _db.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          debugPrint("AuthRepository: Firestore doc not found for ${user.uid}. Fetching FB data & Creating..."); // --- DEBUG ---
          final userData = await FacebookAuth.instance.getUserData();
          await createUser(
            uid: user.uid,
            username: userData['name'] ?? 'Facebook User',
            email: userData['email'] ?? '',
            photoUrl: userData['picture']?['data']?['url'],
          );
          debugPrint("AuthRepository: Firestore doc created for ${user.uid}."); // --- DEBUG ---
        } else {
          debugPrint("AuthRepository: Firestore doc found for ${user.uid}. Checking uidShort..."); // --- DEBUG ---
          if (!userDoc.data()!.containsKey('uidShort')) {
            final calculatedShortId = _uidShortFromFullAuth(user.uid);
            await _db.collection('users').doc(user.uid).update({'uidShort': calculatedShortId});
            debugPrint("AuthRepository: Added missing uidShort for existing user ${user.uid}");
          }
        }
      } else {
        debugPrint("AuthRepository: Firebase sign in returned null user."); // --- DEBUG ---
      }
      return userCredential;
    } else {
      debugPrint("AuthRepository: Facebook login failed: ${result.message}"); // --- DEBUG ---
      throw FirebaseAuthException(
        code: 'ERROR_FACEBOOK_LOGIN_FAILED',
        message: result.message,
      );
    }
  }

  Future<void> signOut() async {
    debugPrint("AuthRepository: Signing out..."); // --- DEBUG ---
    try {
      await _googleSignIn.signOut();
      debugPrint("AuthRepository: Google sign out successful."); // --- DEBUG ---
    } catch (e) {
      debugPrint("AuthRepository: Error signing out from Google: $e");
    }
    try {
      await FacebookAuth.instance.logOut();
      debugPrint("AuthRepository: Facebook sign out successful."); // --- DEBUG ---
    } catch (e) {
      debugPrint("AuthRepository: Error signing out from Facebook: $e");
    }
    await _auth.signOut();
    debugPrint("AuthRepository: Firebase sign out successful."); // --- DEBUG ---
  }
}