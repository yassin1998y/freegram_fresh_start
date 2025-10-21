import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/repositories/auth_repository.dart';
import 'package:meta/meta.dart';

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
    _authStateSubscription =
        _firebaseAuth.authStateChanges().listen((user) {
          // This stream is the single source of truth. When Firebase's auth
          // state changes (login, logout, token refresh), we re-check.
          add(CheckAuthentication());
        });

    on<CheckAuthentication>((event, emit) {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        emit(Authenticated(user));
      } else {
        emit(Unauthenticated());
      }
    });

    on<SignOut>((event, emit) async {
      await _authRepository.signOut();
    });

    on<SignInWithGoogle>((event, emit) async {
      try {
        await _authRepository.signInWithGoogle();
      } catch (e) {
        emit(AuthError(e.toString()));
        emit(Unauthenticated());
      }
    });

    on<SignInWithFacebook>((event, emit) async {
      try {
        await _authRepository.signInWithFacebook();
      } catch (e) {
        emit(AuthError(e.toString()));
        emit(Unauthenticated());
      }
    });

    // FIX: Added handler for the new sign-up event.
    on<SignUpRequested>((event, emit) async {
      try {
        // The BLoC now tells the repository to handle the entire flow.
        await _authRepository.signUp(
          email: event.email,
          password: event.password,
          username: event.username,
        );
        // We don't need to emit a new state here. The `authStateChanges`
        // stream will automatically detect the new user and trigger
        // a `CheckAuthentication` event, which will emit `Authenticated`.
      } catch (e) {
        emit(AuthError(e.toString()));
        emit(Unauthenticated());
      }
    });
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
