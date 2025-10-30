// lib/screens/login_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/screens/signup_screen.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/locator.dart';
// import 'package:freegram/widgets/gradient_button.dart'; // Removed
import 'package:flutter/foundation.dart'; // Import for debugPrint

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false; // Tracks loading state for email/password login

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return; // Prevent multiple clicks

    debugPrint(
        "LoginScreen: Login button pressed for email: ${_emailController.text}");

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint("LoginScreen: Attempting Firebase sign in...");
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // On success, AuthWrapper will handle navigation.
      debugPrint(
          "LoginScreen: Firebase signIn successful. WAITING FOR AuthWrapper navigation...");
    } on FirebaseAuthException catch (e) {
      debugPrint("LoginScreen: Firebase sign in failed: ${e.message}");
      // Show error message only if login fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                e.message ?? 'Login failed. Please check your credentials.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() {
          _isLoading = false; // Reset loading state on error
        });
      }
    } catch (e) {
      // Handle other unexpected errors
      debugPrint("LoginScreen: Unexpected error during login: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false; // Reset loading state on error
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for AuthBloc errors (e.g., from social sign-in)
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          // If an error occurs during social sign-in (handled by Bloc),
          // ensure the loading indicator is turned off if it was active.
          // Note: Email/password errors are handled within _login() directly.
          if (_isLoading) {
            debugPrint(
                "LoginScreen: BlocListener received AuthError while _isLoading=true. Resetting.");
            setState(() => _isLoading = false);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        // No need to handle Authenticated state here, AuthWrapper does that.
        debugPrint(
            "LoginScreen: BlocListener received state: ${state.runtimeType}");
      },
      child: Scaffold(
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
                    // App Title
                    'Freegram',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 48.0),
                  TextFormField(
                    // Email Field
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      // Consider adding prefix icon: prefixIcon: Icon(Icons.email_outlined),
                    ),
                    enabled: !_isLoading, // Disable when loading
                    validator: (value) =>
                        (value == null || !value.contains('@'))
                            ? 'Please enter a valid email'
                            : null,
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    // Password Field
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      // Consider adding prefix icon: prefixIcon: Icon(Icons.lock_outline),
                    ),
                    enabled: !_isLoading, // Disable when loading
                    validator: (value) => (value == null || value.length < 6)
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 24.0),
                  // Replace GradientButton with ElevatedButton
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            // Standard loading indicator
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
                    // Sign Up Button
                    onPressed: _isLoading
                        ? null
                        : () => locator<NavigationService>().navigateTo(
                              const SignUpScreen(),
                              transition: PageTransition.slide,
                            ),
                    child: Text(
                      "Don't have an account? Sign Up",
                      // Dim text when loading
                      style: TextStyle(
                          color: _isLoading
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
                  // Social Login Buttons (Keep structure)
                  _SocialLoginButton(
                    text: 'Sign in with Google',
                    assetName: 'assets/google_logo.png',
                    onPressed: _isLoading
                        ? () {}
                        : () =>
                            context.read<AuthBloc>().add(SignInWithGoogle()),
                    // Use theme colors for consistency
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    textColor: Theme.of(context).colorScheme.onSurface,
                    disabled: _isLoading,
                  ),
                  const SizedBox(height: 12.0),
                  _SocialLoginButton(
                    text: 'Sign in with Facebook',
                    icon: Icons.facebook,
                    onPressed: _isLoading
                        ? () {}
                        : () =>
                            context.read<AuthBloc>().add(SignInWithFacebook()),
                    backgroundColor: const Color(0xFF1877F2), // Facebook blue
                    textColor: Colors.white,
                    disabled: _isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

  const _SocialLoginButton({
    required this.text,
    this.assetName,
    this.icon,
    required this.onPressed,
    required this.backgroundColor,
    required this.textColor,
    this.disabled = false,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (assetName != null)
            Image.asset(assetName!,
                height: 24.0, color: disabled ? Colors.grey : null) // Dim icon
          else if (icon != null)
            Icon(icon,
                color: disabled ? Colors.grey : textColor,
                size: 24.0), // Dim icon
          const SizedBox(width: 12),
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  // Dim text
                  color: disabled ? Colors.grey : textColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
