// lib/blocs/auth_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/repositories/auth_repository.dart';
import 'package:freegram/services/fcm_token_service.dart';
import 'package:freegram/locator.dart';
import 'package:meta/meta.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _firebaseAuth;
  final AuthRepository _authRepository;
  StreamSubscription<User?>? _authStateSubscription;

  AuthBloc({
    required AuthRepository authRepository,
    FirebaseAuth? firebaseAuth,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _authRepository = authRepository,
        super(AuthInitial()) {
    _authStateSubscription = _firebaseAuth.authStateChanges().listen((user) {
      // --- DEBUG ---
      debugPrint(
          "AuthBloc: authStateChanges listener fired. User: ${user?.uid ?? 'null'}");
      // --- END DEBUG ---
      add(CheckAuthentication());
    });

    on<CheckAuthentication>((event, emit) async {
      final user = _firebaseAuth.currentUser;
      // --- DEBUG ---
      debugPrint(
          "AuthBloc: Handling CheckAuthentication. Current Firebase User: ${user?.uid ?? 'null'}");
      // --- END DEBUG ---
      if (user != null) {
        emit(Authenticated(user));

        // Initialize FCM token for push notifications
        try {
          final fcmService = locator<FcmTokenService>();
          await fcmService.initialize();
          await fcmService.updateTokenOnLogin();
          debugPrint("AuthBloc: FCM token initialized successfully");
        } catch (e) {
          debugPrint("AuthBloc: Error initializing FCM token: $e");
          // Don't fail authentication if FCM fails
        }
      } else {
        emit(Unauthenticated());
      }
    });

    on<SignOut>((event, emit) async {
      debugPrint("AuthBloc: Handling SignOut event."); // --- DEBUG ---

      // Remove FCM token before logging out
      try {
        final fcmService = locator<FcmTokenService>();
        await fcmService.removeTokenOnLogout();
        debugPrint("AuthBloc: FCM token removed successfully");
      } catch (e) {
        debugPrint("AuthBloc: Error removing FCM token: $e");
        // Don't fail logout if FCM cleanup fails
      }

      // Emit Unauthenticated immediately to show "Signing out..." spinner
      emit(Unauthenticated());

      // Add minimum display time for better UX (user sees the spinner)
      final signOutFuture = _authRepository.signOut();
      final minimumDisplayFuture =
          Future.delayed(const Duration(milliseconds: 800));

      try {
        // Wait for both signout AND minimum display time
        await Future.wait([signOutFuture, minimumDisplayFuture]);
        debugPrint("AuthBloc: Sign out successful.");
        // authStateChanges listener will also trigger Unauthenticated state
      } catch (e) {
        debugPrint("AuthBloc: Error during sign out: $e");
        emit(AuthError("Sign out failed: $e"));
        // Still ensure Unauthenticated state
        emit(Unauthenticated());
      }
    });

    on<SignInWithGoogle>((event, emit) async {
      debugPrint("AuthBloc: Handling SignInWithGoogle event."); // --- DEBUG ---
      try {
        await _authRepository.signInWithGoogle();
        // authStateChanges listener will trigger Authenticated state
      } catch (e) {
        debugPrint(
            "AuthBloc: Error during SignInWithGoogle: $e"); // --- DEBUG ---
        emit(AuthError(e.toString()));
        emit(Unauthenticated()); // Ensure state is Unauthenticated on error
      }
    });

    on<SignInWithFacebook>((event, emit) async {
      debugPrint(
          "AuthBloc: Handling SignInWithFacebook event."); // --- DEBUG ---
      try {
        await _authRepository.signInWithFacebook();
        // authStateChanges listener will trigger Authenticated state
      } catch (e) {
        debugPrint(
            "AuthBloc: Error during SignInWithFacebook: $e"); // --- DEBUG ---
        emit(AuthError(e.toString()));
        emit(Unauthenticated()); // Ensure state is Unauthenticated on error
      }
    });

    on<SignUpRequested>((event, emit) async {
      debugPrint(
          "AuthBloc: Handling SignUpRequested event for email: ${event.email}"); // --- DEBUG ---
      // ** ADDED: Emit a loading state maybe? (Optional) **
      // emit(AuthLoading()); // You'd need to define AuthLoading state
      try {
        await _authRepository.signUp(
          email: event.email,
          password: event.password,
          username: event.username,
        );
        debugPrint(
            "AuthBloc: SignUpRequested - AuthRepository.signUp completed."); // --- DEBUG ---
        // authStateChanges listener will trigger Authenticated state
      } catch (e) {
        // --- DEBUG: Log the specific error during sign up ---
        debugPrint("AuthBloc: Error during SignUpRequested: $e");
        // --- END DEBUG ---
        emit(AuthError(e.toString()));
        emit(Unauthenticated()); // Ensure state is Unauthenticated on error
      }
    });
  }

  @override
  Future<void> close() {
    debugPrint("AuthBloc: Closing."); // --- DEBUG ---
    _authStateSubscription?.cancel();
    return super.close();
  }
}
