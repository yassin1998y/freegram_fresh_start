// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/navigation/app_routes.dart';
import 'package:freegram/widgets/common/keyboard_safe_area.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/theme/design_tokens.dart';
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
    debugPrint('📱 SCREEN: login_screen.dart');
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

  // PHASE 4: User-friendly error message mapping
  String _getUserFriendlyErrorMessage(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();
    if (lowerError.contains('user-not-found') ||
        lowerError.contains('wrong-password') ||
        lowerError.contains('invalid-credential')) {
      return 'Invalid email or password. Please check and try again.';
    } else if (lowerError.contains('network') ||
        lowerError.contains('connection') ||
        lowerError.contains('internet')) {
      return 'Network error. Please check your connection and try again.';
    } else if (lowerError.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    } else if (lowerError.contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    } else if (lowerError.contains('invalid-email')) {
      return 'Invalid email address. Please check and try again.';
    }
    return errorMessage;
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
          // PHASE 4: Improved error handling with user-friendly messages and retry
          final errorMessage = _getUserFriendlyErrorMessage(state.message);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.onError,
                    size: DesignTokens.iconMD,
                  ),
                  const SizedBox(width: DesignTokens.spaceSM),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onError,
                          ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Theme.of(context).colorScheme.onError,
                onPressed: () {
                  // Retry login if form is still valid
                  if (_formKey.currentState?.validate() ?? false) {
                    _login();
                  }
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        if (state is Authenticated && state.user.emailVerified == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Please verify your email address. Check your inbox.',
              ),
              backgroundColor: SemanticColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
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
          resizeToAvoidBottomInset: true,
          body: KeyboardSafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(DesignTokens.spaceXL),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Image.asset(
                        'assets/freegram_logo_no_bg.png',
                        height: 120,
                      ),
                      const SizedBox(height: DesignTokens.spaceXXL),
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
                      const SizedBox(height: DesignTokens.spaceMD),
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
                        validator: (value) =>
                            (value == null || value.length < 6)
                                ? 'Password must be at least 6 characters'
                                : null,
                      ),
                      const SizedBox(height: DesignTokens.spaceSM),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: isLoading ? null : _handlePasswordReset,
                          child: Text(
                            'Forgot Password?',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spaceMD),
                      ElevatedButton(
                        onPressed: isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: DesignTokens.buttonPaddingVertical,
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusMD),
                          ),
                        ),
                        child: isLoading
                            ? AppProgressIndicator(
                                size: DesignTokens.iconMD,
                                strokeWidth: 2.5,
                                color: Theme.of(context).colorScheme.onPrimary,
                              )
                            : Text(
                                'Log In',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      fontSize: DesignTokens.fontSizeLG,
                                    ),
                              ),
                      ),
                      const SizedBox(height: DesignTokens.spaceMD),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => locator<NavigationService>().navigateNamed(
                                  AppRoutes.signup,
                                ),
                        child: Text(
                          "Don't have an account? Sign Up",
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isLoading
                                        ? SemanticColors.textSecondary(context)
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spaceLG),
                      Row(
                        // OR Separator
                        children: [
                          Expanded(
                            child: Divider(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceSM,
                            ),
                            child: Text(
                              'OR',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DesignTokens.spaceLG),
                      _SocialLoginButton(
                        text: 'Sign in with Google',
                        assetName: 'assets/google_logo.png',
                        onPressed: isLoading
                            ? () {}
                            : () {
                                context
                                    .read<AuthBloc>()
                                    .add(SignInWithGoogle());
                              },
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        textColor: Theme.of(context).colorScheme.onSurface,
                        disabled: isLoading,
                        isLoading: false,
                      ),
                      const SizedBox(height: DesignTokens.spaceSM),
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
                        textColor: Theme.of(context)
                            .colorScheme
                            .onPrimary, // Facebook brand color
                        disabled: isLoading,
                        isLoading: false,
                      ),
                    ],
                  ),
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
        backgroundColor: disabled
            ? backgroundColor.withOpacity(DesignTokens.opacityDisabled)
            : backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSM),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          // Use divider color for border for subtle look
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        elevation: 0, // Flat design
      ),
      child: isLoading
          ? AppProgressIndicator(
              size: 24,
              strokeWidth: 2.5,
              color: textColor,
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (assetName != null)
                  Image.asset(assetName!,
                      height: DesignTokens.iconMD,
                      color: (disabled || isLoading)
                          ? SemanticColors.textSecondary(context)
                          : null) // Dim icon
                else if (icon != null)
                  Icon(icon,
                      color: (disabled || isLoading)
                          ? SemanticColors.textSecondary(context)
                          : textColor,
                      size: DesignTokens.iconMD), // Dim icon
                const SizedBox(width: DesignTokens.spaceSM),
                Text(
                  text,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        // Dim text
                        color: (disabled || isLoading)
                            ? SemanticColors.textSecondary(context)
                            : textColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
    );
  }
}
