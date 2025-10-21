part of 'auth_bloc.dart';

@immutable
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

/// Event to check the current authentication status.
class CheckAuthentication extends AuthEvent {}

/// Event to sign the user out.
class SignOut extends AuthEvent {}

/// Event to initiate sign-in with Google.
class SignInWithGoogle extends AuthEvent {}

/// Event to initiate sign-in with Facebook.
class SignInWithFacebook extends AuthEvent {}

/// FIX: Event to handle the entire user sign-up flow.
class SignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String username;

  const SignUpRequested({
    required this.email,
    required this.password,
    required this.username,
  });

  @override
  List<Object> get props => [email, password, username];
}

