// lib/screens/login_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/screens/signup_screen.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/gradient_button.dart';
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
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    debugPrint("LoginScreen: Login button pressed for email: ${_emailController.text}");

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint("LoginScreen: Attempting Firebase sign in...");
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // *** ADDED LOG ***
      debugPrint("LoginScreen: Firebase signIn successful. WAITING FOR AuthWrapper navigation...");
      // *** END LOG ***
      // DO NOT set isLoading = false here.
    } on FirebaseAuthException catch (e) {
      debugPrint("LoginScreen: Firebase sign in failed: ${e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Login failed'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("LoginScreen: Unexpected error during login: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
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
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          if (_isLoading) {
            debugPrint("LoginScreen: BlocListener received AuthError while _isLoading=true. Resetting.");
            setState(() => _isLoading = false);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        debugPrint("LoginScreen: BlocListener received state: ${state.runtimeType}");
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
                    validator: (value) => (value == null || !value.contains('@'))
                        ? 'Please enter a valid email'
                        : null,
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                    ),
                    validator: (value) => (value == null || value.length < 6)
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 24.0),
                  GradientButton(
                    onPressed: _isLoading ? null : _login,
                    text: 'Log In',
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16.0),
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) => const SignUpScreen())),
                    child: Text("Don't have an account? Sign Up",
                        style: TextStyle(color: _isLoading ? Colors.grey : Theme.of(context).colorScheme.primary)),
                  ),
                  const SizedBox(height: 24.0),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('OR',
                            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24.0),
                  _SocialLoginButton(
                    text: 'Sign in with Google',
                    assetName: 'assets/google_logo.png',
                    onPressed: _isLoading ? (){} : () =>
                        context.read<AuthBloc>().add(SignInWithGoogle()),
                    backgroundColor: SonarPulseTheme.lightSurface,
                    textColor: SonarPulseTheme.lightTextPrimary,
                    disabled: _isLoading,
                  ),
                  const SizedBox(height: 12.0),
                  _SocialLoginButton(
                    text: 'Sign in with Facebook',
                    icon: Icons.facebook,
                    onPressed: _isLoading ? (){} : () =>
                        context.read<AuthBloc>().add(SignInWithFacebook()),
                    backgroundColor: const Color(0xFF1877F2),
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
        backgroundColor: disabled ? backgroundColor.withOpacity(0.5) : backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (assetName != null)
            Image.asset(assetName!, height: 24.0, color: disabled ? Colors.grey : null)
          else if (icon != null)
            Icon(icon, color: disabled ? Colors.grey : textColor, size: 24.0),
          const SizedBox(width: 12),
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: disabled ? Colors.grey : textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}