// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/widgets/freegram_app_bar.dart';
import 'package:freegram/widgets/common/keyboard_safe_area.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isSigningUp = false;
  bool _passwordVisible = false;
  double _passwordStrength = 0.0; // 0.0 weak -> 1.0 strong
  String _passwordStrengthLabel = '';
  bool _emailValidated = false;
  bool _passwordValidated = false;

  static const _kSignupEmailKey = 'signup_draft_email';
  static const _kRememberEmailKey = 'remember_signup_email';

  late AnimationController _successAnimationController;
  late Animation<double> _successScaleAnimation;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: signup_screen.dart');
    // IMPROVEMENT #9: Auto-focus on first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emailFocusNode.requestFocus();
    });

    // IMPROVEMENT #17: Success animation setup
    _successAnimationController = AnimationController(
      vsync: this,
      duration: DesignTokens.durationNormal,
    );
    _successScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimationController,
        curve: DesignTokens.curveElasticOut,
      ),
    );

    _restoreDrafts();
    _emailController.addListener(_saveDrafts);
    _passwordController
        .addListener(() => _onPasswordChanged(_passwordController.text));
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _saveDrafts();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _successAnimationController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    // IMPROVEMENT #2: Real-time email validation
    final email = _emailController.text.trim();
    final isValid = _isValidEmail(email);
    if (mounted) {
      setState(() {
        _emailValidated = email.isNotEmpty && isValid;
      });
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _signUp() {
    if (!_formKey.currentState!.validate()) return;
    if (_isSigningUp) return;

    if (kDebugMode) {
      debugPrint(
          "SignUpScreen: SignUp button pressed for email: ${_emailController.text}");
    }

    // IMPROVEMENT #11: Hide keyboard on submit
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isSigningUp = true;
    });

    context.read<AuthBloc>().add(
          SignUpRequested(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            username: '', // Username will be collected in onboarding
          ),
        );
    if (kDebugMode) {
      debugPrint(
          "SignUpScreen: Dispatched SignUpRequested event. WAITING FOR AuthWrapper navigation...");
    }
  }

  void _onPasswordChanged(String value) {
    // IMPROVEMENT #1: Enhanced password strength calculation
    int score = 0;

    if (value.length >= 6) score++;
    if (value.length >= 10) score++;

    if (RegExp(r'[a-z]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'[A-Z]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) {
      score++;
    }

    final strength = (score / 6).clamp(0.0, 1.0);
    String label = '';

    if (value.isEmpty) {
      label = '';
    } else if (strength < 0.33) {
      label = 'Weak';
    } else if (strength < 0.67) {
      label = 'Medium';
    } else {
      label = 'Strong';
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthLabel = label;
      _passwordValidated = value.length >= 6;
    });
  }

  Future<void> _restoreDrafts() async {
    // IMPROVEMENT #15: Form persistence
    final prefs = await SharedPreferences.getInstance();
    final rememberEmail = prefs.getBool(_kRememberEmailKey) ?? true;

    if (rememberEmail) {
      final email = prefs.getString(_kSignupEmailKey) ?? '';
      if (email.isNotEmpty) _emailController.text = email;
    }
  }

  Future<void> _saveDrafts() async {
    // IMPROVEMENT #15: Form persistence
    final prefs = await SharedPreferences.getInstance();
    final rememberEmail = prefs.getBool(_kRememberEmailKey) ?? true;

    if (rememberEmail) {
      await prefs.setString(_kSignupEmailKey, _emailController.text.trim());
    }
  }

  List<String> _getPasswordRequirements(String password) {
    // IMPROVEMENT #3: Smart password requirements checklist
    final requirements = <String>[];

    if (password.length >= 6) {
      requirements.add('At least 6 characters');
    } else {
      requirements.add('At least 6 characters');
    }

    if (RegExp(r'[A-Z]').hasMatch(password)) {
      requirements.add('One uppercase letter');
    } else {
      requirements.add('One uppercase letter');
    }

    if (RegExp(r'[0-9]').hasMatch(password)) {
      requirements.add('One number');
    } else {
      requirements.add('One number');
    }

    return requirements;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (kDebugMode) {
          debugPrint(
              "SignUpScreen: BlocListener received state: ${state.runtimeType}");
        }
        if (state is AuthError) {
          if (mounted && _isSigningUp) {
            setState(() {
              _isSigningUp = false;
            });
          }
          // IMPROVEMENT #5: Better error messages
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: DesignTokens.spaceSM),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
        if (state is Authenticated && _isSigningUp) {
          // IMPROVEMENT #12: Success animation feedback
          _successAnimationController.forward();

          if (kDebugMode) {
            debugPrint(
                "SignUpScreen: BlocListener received Authenticated state WHILE signing up. Popping screen.");
          }
          if (mounted) {
            setState(() {
              _isSigningUp = false;
            });
          }
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        }
        if (state is AuthLoading && !_isSigningUp) {
          setState(() {
            _isSigningUp = true;
          });
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading || _isSigningUp;
        final canSubmit = _emailValidated && _passwordValidated && !isLoading;

        return Scaffold(
          // CRITICAL: Explicit background color to prevent black screen during transitions
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          resizeToAvoidBottomInset: true,
          appBar: const FreegramAppBar(
            showBackButton: true,
          ),
          body: KeyboardSafeArea(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(DesignTokens.spaceXL),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // IMPROVEMENT #12: Success animation
                        if (_successAnimationController.isAnimating)
                          ScaleTransition(
                            scale: _successScaleAnimation,
                            child: Container(
                              padding:
                                  const EdgeInsets.all(DesignTokens.spaceLG),
                              decoration: const BoxDecoration(
                                color: DesignTokens.successColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: DesignTokens.iconXXL,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.person_add_outlined,
                            size: DesignTokens.iconXXL * 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        const SizedBox(height: DesignTokens.spaceLG),
                        Text(
                          'Create Account',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: DesignTokens.spaceSM),
                        // IMPROVEMENT #16: Help text
                        Text(
                          'Join Freegram to discover nearby users and connect',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        const SizedBox(height: DesignTokens.spaceXXL),

                        // IMPROVEMENT #2: Email field with validation feedback
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          // IMPROVEMENT #4: Input formatting
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'\s')),
                            LowerCaseTextFormatter(),
                          ],
                          // IMPROVEMENT #14: Accessibility
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'you@example.com',
                            prefixIcon: const Icon(Icons.email_outlined),
                            suffixIcon: _emailValidated &&
                                    _emailController.text.isNotEmpty
                                ? const Icon(
                                    Icons.check_circle,
                                    color: DesignTokens.successColor,
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusMD),
                            ),
                            // IMPROVEMENT #2: Visual feedback
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusMD),
                              borderSide: BorderSide(
                                color: _emailValidated
                                    ? DesignTokens.successColor
                                    : Colors.grey[300]!,
                                width: _emailValidated ? 2 : 1,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusMD),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.error,
                                width: 2,
                              ),
                            ),
                            helperText: _emailController.text.isNotEmpty &&
                                    !_emailValidated
                                ? 'Please enter a valid email address'
                                : null,
                          ),
                          enabled: !isLoading,
                          // IMPROVEMENT #11: Validation on blur
                          onFieldSubmitted: (_) =>
                              _passwordFocusNode.requestFocus(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Email is required';
                            }
                            if (!_isValidEmail(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: DesignTokens.spaceMD),

                        // IMPROVEMENT #1: Enhanced password field
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: !_passwordVisible,
                          textInputAction: TextInputAction.done,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          // IMPROVEMENT #13: Keyboard type optimization
                          keyboardType: TextInputType.visiblePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Create a strong password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // IMPROVEMENT #10: Better password visibility toggle
                                if (_passwordController.text.isNotEmpty)
                                  IconButton(
                                    icon: Icon(
                                      _passwordVisible
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    onPressed: isLoading
                                        ? null
                                        : () => setState(() =>
                                            _passwordVisible =
                                                !_passwordVisible),
                                    tooltip: _passwordVisible
                                        ? 'Hide password'
                                        : 'Show password',
                                  ),
                              ],
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusMD),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusMD),
                              borderSide: BorderSide(
                                color: _passwordValidated &&
                                        _passwordController.text.isNotEmpty
                                    ? DesignTokens.successColor
                                    : Colors.grey[300]!,
                                width: _passwordValidated &&
                                        _passwordController.text.isNotEmpty
                                    ? 2
                                    : 1,
                              ),
                            ),
                          ),
                          enabled: !isLoading,
                          onChanged: _onPasswordChanged,
                          onFieldSubmitted: (_) {
                            if (canSubmit) _signUp();
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: DesignTokens.spaceSM),

                        // IMPROVEMENT #1: Enhanced password strength indicator
                        if (_passwordController.text.isNotEmpty) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusXS),
                                  child: AppLinearProgressIndicator(
                                    value: _passwordStrength,
                                    minHeight: 8,
                                    backgroundColor: Colors.grey[200],
                                    color: _passwordStrength < 0.4
                                        ? DesignTokens.errorColor
                                        : (_passwordStrength < 0.7
                                            ? DesignTokens.warningColor
                                            : DesignTokens.successColor),
                                  ),
                                ),
                              ),
                              const SizedBox(width: DesignTokens.spaceSM),
                              Text(
                                _passwordStrengthLabel,
                                style: TextStyle(
                                  fontSize: DesignTokens.fontSizeSM,
                                  fontWeight: FontWeight.w600,
                                  color: _passwordStrength < 0.4
                                      ? DesignTokens.errorColor
                                      : (_passwordStrength < 0.7
                                          ? DesignTokens.warningColor
                                          : DesignTokens.successColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: DesignTokens.spaceSM),
                          // IMPROVEMENT #3: Password requirements checklist
                          ..._getPasswordRequirements(_passwordController.text)
                              .map((req) => Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: DesignTokens.spaceXS),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _passwordController.text.isNotEmpty &&
                                                      (req.contains(
                                                              '6 characters') &&
                                                          _passwordController
                                                                  .text
                                                                  .length >=
                                                              6) ||
                                                  (req.contains('uppercase') &&
                                                      RegExp(r'[A-Z]').hasMatch(
                                                          _passwordController
                                                              .text)) ||
                                                  (req.contains('number') &&
                                                      RegExp(r'[0-9]').hasMatch(
                                                          _passwordController
                                                              .text))
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          size: DesignTokens.iconSM,
                                          color: _passwordController
                                                          .text.isNotEmpty &&
                                                      (req.contains(
                                                              '6 characters') &&
                                                          _passwordController
                                                                  .text
                                                                  .length >=
                                                              6) ||
                                                  (req.contains('uppercase') &&
                                                      RegExp(r'[A-Z]').hasMatch(
                                                          _passwordController
                                                              .text)) ||
                                                  (req.contains('number') &&
                                                      RegExp(r'[0-9]').hasMatch(
                                                          _passwordController
                                                              .text))
                                              ? DesignTokens.successColor
                                              : Colors.grey[400],
                                        ),
                                        const SizedBox(
                                            width: DesignTokens.spaceXS),
                                        Text(
                                          req,
                                          style: TextStyle(
                                            fontSize: DesignTokens.fontSizeSM,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                          const SizedBox(height: DesignTokens.spaceMD),
                        ],

                        // IMPROVEMENT #8: Terms & Privacy link
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: DesignTokens.spaceSM),
                          child: Text(
                            'By signing up, you agree to our Terms of Service and Privacy Policy',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: DesignTokens.fontSizeSM,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),

                        const SizedBox(height: DesignTokens.spaceLG),

                        // IMPROVEMENT #6: Enhanced button with loading state
                        SizedBox(
                          height: DesignTokens.buttonHeight,
                          child: ElevatedButton(
                            onPressed: canSubmit ? _signUp : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: DesignTokens.spaceMD),
                              backgroundColor: canSubmit
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[300],
                              foregroundColor: canSubmit
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Colors.grey[600],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    DesignTokens.radiusMD),
                              ),
                              elevation:
                                  canSubmit ? DesignTokens.elevation2 : 0,
                            ),
                            child: isLoading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AppProgressIndicator(
                                        size: DesignTokens.iconMD,
                                        strokeWidth: 2.5,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                      ),
                                      const SizedBox(
                                          width: DesignTokens.spaceSM),
                                      const Text('Creating account...'),
                                    ],
                                  )
                                : const Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      fontSize: DesignTokens.fontSizeLG,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
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

// IMPROVEMENT #4: Lowercase text formatter
class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
    );
  }
}
