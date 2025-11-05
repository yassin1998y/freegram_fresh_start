// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/navigation/app_routes.dart';
import 'package:flutter/foundation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();

  // Debug method to log when LoginScreen is built
  static void debugLogBuild(String reason) {
    debugPrint("LoginScreen: Built after sign out. Reason: $reason");
  }
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint(
              "LoginScreen: initState completed. Screen is now visible.");
          LoginScreen.debugLogBuild("Screen initialized and mounted");
        }
      });
    }
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
          SignInWithEmailPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          ),
        );
  }

  void _handlePasswordReset() {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your email address first'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text(
            'A password reset email will be sent to ${_emailController.text.trim()}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthBloc>().add(
                    SendPasswordResetEmail(
                      email: _emailController.text.trim(),
                    ),
                  );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        if (state is Authenticated && state.user.emailVerified == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Please verify your email address. Check your inbox.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        if (kDebugMode) {
          debugPrint(
              "LoginScreen: BlocListener received state: ${state.runtimeType}");
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return Scaffold(
          // CRITICAL: Explicit background color to prevent black screen during logout transition
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Freegram',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 48.0),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                      ),
                      enabled: !isLoading,
                      validator: (value) =>
                          (value == null || !value.contains('@'))
                              ? 'Please enter a valid email'
                              : null,
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(_passwordVisible
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: isLoading
                              ? null
                              : () => setState(
                                  () => _passwordVisible = !_passwordVisible),
                        ),
                      ),
                      enabled: !isLoading,
                      validator: (value) => (value == null || value.length < 6)
                          ? 'Password must be at least 6 characters'
                          : null,
                    ),
                    const SizedBox(height: 8.0),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoading ? null : _handlePasswordReset,
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton(
                      onPressed: isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Log In'),
                    ),
                    const SizedBox(height: 16.0),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => locator<NavigationService>().navigateNamed(
                                AppRoutes.signup,
                              ),
                      child: Text(
                        "Don't have an account? Sign Up",
                        style: TextStyle(
                            color: isLoading
                                ? Colors.grey
                                : Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    Row(
                      // OR Separator
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('OR',
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24.0),
                    _SocialLoginButton(
                      text: 'Sign in with Google',
                      assetName: 'assets/google_logo.png',
                      onPressed: isLoading
                          ? () {}
                          : () {
                              context.read<AuthBloc>().add(SignInWithGoogle());
                            },
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      textColor: Theme.of(context).colorScheme.onSurface,
                      disabled: isLoading,
                      isLoading: false,
                    ),
                    const SizedBox(height: 12.0),
                    _SocialLoginButton(
                      text: 'Sign in with Facebook',
                      icon: Icons.facebook,
                      onPressed: isLoading
                          ? () {}
                          : () {
                              context
                                  .read<AuthBloc>()
                                  .add(SignInWithFacebook());
                            },
                      backgroundColor: const Color(0xFF1877F2),
                      textColor: Colors.white,
                      disabled: isLoading,
                      isLoading: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// _SocialLoginButton remains the same helper widget
class _SocialLoginButton extends StatelessWidget {
  final String text;
  final String? assetName;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color textColor;
  final bool disabled;
  final bool isLoading;

  const _SocialLoginButton({
    required this.text,
    this.assetName,
    this.icon,
    required this.onPressed,
    required this.backgroundColor,
    required this.textColor,
    this.disabled = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: disabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        // Dim background when disabled
        backgroundColor:
            disabled ? backgroundColor.withOpacity(0.5) : backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          // Use divider color for border for subtle look
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        elevation: 0, // Flat design
      ),
      child: isLoading
          ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: textColor,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (assetName != null)
                  Image.asset(assetName!,
                      height: 24.0,
                      color: (disabled || isLoading)
                          ? Colors.grey
                          : null) // Dim icon
                else if (icon != null)
                  Icon(icon,
                      color: (disabled || isLoading) ? Colors.grey : textColor,
                      size: 24.0), // Dim icon
                const SizedBox(width: 12),
                Text(
                  text,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        // Dim text
                        color:
                            (disabled || isLoading) ? Colors.grey : textColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
    );
  }
}
