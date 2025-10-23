// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/widgets/gradient_button.dart';
import 'package:freegram/widgets/gradient_spinner.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSigningUp = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _signUp() {
    if (!_formKey.currentState!.validate()) return;
    if (_isSigningUp) return;

    debugPrint("SignUpScreen: SignUp button pressed for email: ${_emailController.text}");
    setState(() {
      _isSigningUp = true;
    });

    context.read<AuthBloc>().add(
      SignUpRequested(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        username: _usernameController.text.trim(),
      ),
    );
    debugPrint("SignUpScreen: Dispatched SignUpRequested event. WAITING FOR AuthWrapper navigation...");
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        debugPrint("SignUpScreen: BlocListener received state: ${state.runtimeType}");
        if (state is AuthError) {
          if (mounted) {
            setState(() {
              _isSigningUp = false; // Reset loading on error
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        // --- MODIFICATION START ---
        // If authenticated AND we were the ones signing up, pop this screen
        if (state is Authenticated && _isSigningUp) {
          debugPrint("SignUpScreen: BlocListener received Authenticated state WHILE signing up. Popping screen.");
          // Reset the flag *before* popping
          if (mounted) {
            setState(() {
              _isSigningUp = false;
            });
          }
          // Pop the SignUpScreen - AuthWrapper will then build EditProfileScreen
          Navigator.of(context).pop();
        }
        // --- MODIFICATION END ---
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          // Ensure back button works correctly even if AppBar is transparent
          leading: BackButton(color: Theme.of(context).iconTheme.color),
        ),
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
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 48.0),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                    ),
                    enabled: !_isSigningUp,
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Please enter a username'
                        : null,
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                    ),
                    enabled: !_isSigningUp,
                    validator: (value) =>
                    (value == null || !value.contains('@'))
                        ? 'Please enter a valid email'
                        : null,
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                    ),
                    enabled: !_isSigningUp,
                    validator: (value) => (value == null || value.length < 6)
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 24.0),
                  GradientButton(
                    onPressed: _isSigningUp ? null : _signUp,
                    text: 'Sign Up',
                    isLoading: _isSigningUp,
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