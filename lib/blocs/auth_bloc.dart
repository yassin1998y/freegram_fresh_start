// lib/blocs/auth_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/repositories/auth_repository.dart';
import 'package:freegram/services/fcm_token_service.dart';
import 'package:freegram/utils/auth_error_mapper.dart';
import 'package:freegram/locator.dart';
import 'package:flutter/foundation.dart';

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
      if (kDebugMode) {
        debugPrint(
            "AuthBloc: Handling CheckAuthentication. Current Firebase User: ${user?.uid ?? 'null'}");
      }
      if (user != null) {
        emit(Authenticated(user));

        // Initialize FCM token (consolidated - updateTokenOnLogin handles initialization)
        try {
          final fcmService = locator<FcmTokenService>();
          await fcmService.updateTokenOnLogin(user.uid);
          if (kDebugMode) {
            debugPrint("AuthBloc: FCM token initialized successfully");
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint("AuthBloc: Error initializing FCM token: $e");
          }
        }
      } else {
        emit(Unauthenticated());
      }
    });

    on<SignOut>((event, emit) async {
      debugPrint("AuthBloc: Handling SignOut event."); // --- DEBUG ---

      // CRITICAL: Capture state BEFORE any async operations
      // If authStateChanges fires during async work, it might change state
      final stateBeforeSignOut = state;
      debugPrint(
          "AuthBloc: SignOut started. Current state: ${stateBeforeSignOut.runtimeType}");

      // Remove FCM token before logging out
      try {
        final fcmService = locator<FcmTokenService>();
        await fcmService
            .removeTokenOnLogout(_firebaseAuth.currentUser?.uid ?? '');
        debugPrint("AuthBloc: FCM token removed successfully");
      } catch (e) {
        debugPrint("AuthBloc: Error removing FCM token: $e");
        // Don't fail logout if FCM cleanup fails
      }

      // CRITICAL: Emit Unauthenticated if we were Authenticated before sign-out started
      // This ensures LoginScreen shows immediately, even if authStateChanges already fired
      if (stateBeforeSignOut is Authenticated) {
        // Emit Unauthenticated immediately to show LoginScreen
        emit(Unauthenticated());
        debugPrint(
            "AuthBloc: Emitted Unauthenticated state for sign-out (was: Authenticated)");
      } else {
        debugPrint(
            "AuthBloc: State was already ${stateBeforeSignOut.runtimeType} before sign-out. authStateChanges should have handled it.");
        // Still emit to ensure state is Unauthenticated (in case authStateChanges hasn't fired yet)
        emit(Unauthenticated());
      }

      // Sign out from repository (this triggers authStateChanges)
      final signOutFuture = _authRepository.signOut();
      final minimumDisplayFuture =
          Future.delayed(const Duration(milliseconds: 800));

      try {
        // Wait for both signout AND minimum display time
        await Future.wait([signOutFuture, minimumDisplayFuture]);
        debugPrint("AuthBloc: Sign out successful.");
        // authStateChanges listener will trigger CheckAuthentication which emits Unauthenticated
        // This is redundant but harmless - ensures state is definitely Unauthenticated
      } catch (e) {
        debugPrint("AuthBloc: Error during sign out: $e");
        emit(AuthError("Sign out failed: $e"));
        // Still ensure Unauthenticated state
        emit(Unauthenticated());
      }
    });

    // Common sign-in handler - reduces code duplication
    // All sign-in methods follow the same pattern: emit loading, call repository, handle errors
    Future<void> handleSignIn(
      String methodName,
      Future<void> Function() signInMethod,
      Emitter<AuthState> emit,
    ) async {
      emit(AuthLoading());
      if (kDebugMode) {
        debugPrint("AuthBloc: Handling $methodName event.");
      }
      try {
        await signInMethod();
      } catch (e) {
        if (kDebugMode) {
          debugPrint("AuthBloc: Error during $methodName: $e");
        }
        emit(AuthError(AuthErrorMapper.mapGenericError(e)));
        emit(Unauthenticated());
      }
    }

    on<SignInWithEmailPassword>((event, emit) async {
      await handleSignIn(
        'SignInWithEmailPassword',
        () => _authRepository.signInWithEmailPassword(
          email: event.email,
          password: event.password,
        ),
        emit,
      );
    });

    on<SignInWithGoogle>((event, emit) async {
      await handleSignIn(
        'SignInWithGoogle',
        () => _authRepository.signInWithGoogle(),
        emit,
      );
    });

    on<SignInWithFacebook>((event, emit) async {
      await handleSignIn(
        'SignInWithFacebook',
        () => _authRepository.signInWithFacebook(),
        emit,
      );
    });

    on<SendPasswordResetEmail>((event, emit) async {
      emit(AuthLoading());
      if (kDebugMode) {
        debugPrint("AuthBloc: Handling SendPasswordResetEmail event.");
      }
      try {
        await _authRepository.sendPasswordResetEmail(event.email);
        emit(Unauthenticated());
        if (kDebugMode) {
          debugPrint("AuthBloc: Password reset email sent successfully");
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint("AuthBloc: Error sending password reset email: $e");
        }
        emit(AuthError(AuthErrorMapper.mapGenericError(e)));
        emit(Unauthenticated());
      }
    });

    on<SignUpRequested>((event, emit) async {
      emit(AuthLoading());
      if (kDebugMode) {
        debugPrint(
            "AuthBloc: Handling SignUpRequested event for email: ${event.email}");
      }
      try {
        await _authRepository.signUp(
          email: event.email,
          password: event.password,
          username: event.username,
        );
        if (kDebugMode) {
          debugPrint(
              "AuthBloc: SignUpRequested - AuthRepository.signUp completed.");
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint("AuthBloc: Error during SignUpRequested: $e");
        }
        emit(AuthError(AuthErrorMapper.mapGenericError(e)));
        emit(Unauthenticated());
      }
    });
  }

  @override
  Future<void> close() {
    if (kDebugMode) {
      debugPrint("AuthBloc: Closing.");
    }
    _authStateSubscription?.cancel();
    return super.close();
  }
}
