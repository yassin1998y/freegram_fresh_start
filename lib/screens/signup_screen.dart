// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/widgets/freegram_app_bar.dart';
import 'package:flutter/foundation.dart';

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

    debugPrint(
        "SignUpScreen: SignUp button pressed for email: ${_emailController.text}");
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
    debugPrint(
        "SignUpScreen: Dispatched SignUpRequested event. WAITING FOR AuthWrapper navigation...");
    // Let the BlocListener handle navigation and state changes
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        debugPrint(
            "SignUpScreen: BlocListener received state: ${state.runtimeType}");
        if (state is AuthError) {
          // Only reset loading state if it was triggered by this screen
          if (mounted && _isSigningUp) {
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
        // If authenticated state occurs WHILE this screen initiated the signup,
        // it means success. AuthWrapper will handle navigation, but we might pop
        // this screen off the stack if desired (or let AuthWrapper replace it).
        // Popping here makes sense as the signup flow is done.
        if (state is Authenticated && _isSigningUp) {
          debugPrint(
              "SignUpScreen: BlocListener received Authenticated state WHILE signing up. Popping screen.");
          // Reset the flag *before* popping
          if (mounted) {
            setState(() {
              _isSigningUp = false;
            });
          }
          // Pop the SignUpScreen - AuthWrapper will then likely build EditProfileScreen
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: FreegramAppBar(
          showBackButton: true,
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
                    enabled: !_isSigningUp, // Disable when loading
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
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
                    enabled: !_isSigningUp, // Disable when loading
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
                    enabled: !_isSigningUp, // Disable when loading
                    validator: (value) => (value == null || value.length < 6)
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 24.0),
                  // Replace GradientButton with ElevatedButton
                  ElevatedButton(
                    onPressed: _isSigningUp ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      // Use theme's primary color
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: _isSigningUp
                        ? const SizedBox(
                            // Use standard CircularProgressIndicator
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white, // Spinner color
                            ),
                          )
                        : const Text('Sign Up'),
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
