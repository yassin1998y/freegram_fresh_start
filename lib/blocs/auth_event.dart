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

/// Event to signal that the user has completed the onboarding process.
class AuthOnboarded extends AuthEvent {
  final String userId;
  const AuthOnboarded({required this.userId});

  @override
  List<Object> get props => [userId];
}

/// Event to initiate sign-in with Google.
class SignInWithGoogle extends AuthEvent {}

/// Event to initiate sign-in with Facebook.
class SignInWithFacebook extends AuthEvent {}

/// Event to initiate sign-in with email and password.
class SignInWithEmailPassword extends AuthEvent {
  final String email;
  final String password;

  const SignInWithEmailPassword({
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [email, password];
}

/// Event to send password reset email.
class SendPasswordResetEmail extends AuthEvent {
  final String email;

  const SendPasswordResetEmail({required this.email});

  @override
  List<Object> get props => [email];
}

/// FIX: Event to handle the entire user sign-up flow.
class SignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String? username;
  final File? imageFile;

  const SignUpRequested({
    required this.email,
    required this.password,
    this.username,
    this.imageFile,
  });

  @override
  List<Object> get props => [email, password, username ?? '', imageFile ?? ''];
}
