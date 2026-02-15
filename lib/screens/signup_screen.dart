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
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController =
      TextEditingController(); // NEW: Username controller
  final _formKey = GlobalKey<FormState>();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode(); // NEW: Username focus node

  // NEW: Image picker variables
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  bool _isSigningUp = false;
  bool _passwordVisible = false;
  double _passwordStrength = 0.0; // 0.0 weak -> 1.0 strong
  String _passwordStrengthLabel = '';
  bool _emailValidated = false;
  bool _passwordValidated = false;
  bool _usernameValidated = false; // NEW: Username validation

  static const _kSignupEmailKey = 'signup_draft_email';
  static const _kRememberEmailKey = 'remember_signup_email';

  late AnimationController _successAnimationController;
  late Animation<double> _successScaleAnimation;

  // OPTIMIZATION: Debounce timer for draft saving
  Timer? _draftSaveTimer;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: signup_screen.dart');
    // IMPROVEMENT #9: Auto-focus on first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _usernameFocusNode.requestFocus(); // Focus username first now
    });

    // IMPROVEMENT #17: Success animation setup
    _successAnimationController = AnimationController(
      vsync: this,
      duration: AnimationTokens.normal,
    );
    _successScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimationController,
        curve: AnimationTokens.elasticOut,
      ),
    );

    _restoreDrafts();
    // OPTIMIZATION: Debounced draft saving - saves 500ms after user stops typing
    _emailController.addListener(_saveDrafts);
    _passwordController
        .addListener(() => _onPasswordChanged(_passwordController.text));
    _emailController.addListener(_onEmailChanged);
    _usernameController.addListener(_onUsernameChanged); // NEW
  }

  @override
  void dispose() {
    // OPTIMIZATION: Cancel timer and perform final save
    _draftSaveTimer?.cancel();
    _performDraftSave();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose(); // NEW
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _usernameFocusNode.dispose(); // NEW
    _successAnimationController.dispose();
    super.dispose();
  }

  // NEW: Username change handler
  void _onUsernameChanged() {
    final username = _usernameController.text.trim();
    if (mounted) {
      setState(() {
        _usernameValidated = username.isNotEmpty && username.length >= 3;
      });
    }
  }

  // NEW: Image picker handler
  Future<void> _pickImage() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radiusXL),
          ),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin:
                    const EdgeInsets.symmetric(vertical: DesignTokens.spaceMD),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              const SizedBox(height: DesignTokens.spaceMD),
            ],
          ),
        ),
      );

      if (source != null) {
        final XFile? pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 70,
          maxWidth: 1024,
          maxHeight: 1024,
        );

        if (pickedFile != null) {
          setState(() {
            _imageFile = File(pickedFile.path);
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
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

  // UX IMPROVEMENT: User-friendly error messages
  String _getUserFriendlyErrorMessage(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();
    if (lowerError.contains('email-already-in-use') ||
        lowerError.contains('email already exists')) {
      return 'This email is already registered. Try logging in instead.';
    } else if (lowerError.contains('weak-password') ||
        lowerError.contains('password is too weak')) {
      return 'Password is too weak. Please use a stronger password.';
    } else if (lowerError.contains('network') ||
        lowerError.contains('connection') ||
        lowerError.contains('internet')) {
      return 'Network error. Please check your connection and try again.';
    } else if (lowerError.contains('invalid-email')) {
      return 'Invalid email address. Please check and try again.';
    } else if (lowerError.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return errorMessage;
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
            username: _usernameController.text.trim(), // NEW
            imageFile: _imageFile, // NEW
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

  // OPTIMIZATION: Debounced draft saving - saves 500ms after user stops typing
  void _saveDrafts() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _performDraftSave();
    });
  }

  // IMPROVEMENT #15: Form persistence (actual save operation)
  Future<void> _performDraftSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberEmail = prefs.getBool(_kRememberEmailKey) ?? true;

      if (rememberEmail) {
        await prefs.setString(_kSignupEmailKey, _emailController.text.trim());
      }
    } catch (e) {
      debugPrint('SignUpScreen: Error saving draft: $e');
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
        // OPTIMIZATION: Ensure mounted check before any state updates
        if (!mounted) return;

        if (state is AuthError) {
          if (_isSigningUp) {
            setState(() {
              _isSigningUp = false;
            });
          }
          // IMPROVEMENT #5: Better error messages with retry option
          final errorMessage = _getUserFriendlyErrorMessage(state.message);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.onError,
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
                  // Retry signup if form is still valid
                  if (_emailValidated &&
                      _passwordValidated &&
                      _usernameValidated) {
                    _signUp();
                  }
                },
              ),
              duration: const Duration(seconds: 5),
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
          setState(() {
            _isSigningUp = false;
          });
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
        final canSubmit = _emailValidated &&
            _passwordValidated &&
            _usernameValidated &&
            !isLoading;

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
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
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
                                  padding: const EdgeInsets.all(
                                      DesignTokens.spaceLG),
                                  decoration: const BoxDecoration(
                                    color: SemanticColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    size: DesignTokens.iconXXL,
                                  ),
                                ),
                              )
                            else
                              // NEW: Profile Picture Picker
                              Center(
                                child: GestureDetector(
                                  onTap: isLoading ? null : _pickImage,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          image: _imageFile != null
                                              ? DecorationImage(
                                                  image: FileImage(_imageFile!),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: _imageFile == null
                                            ? Icon(
                                                Icons.person_add_outlined,
                                                size: 40,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              )
                                            : null,
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .scaffoldBackgroundColor,
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.camera_alt,
                                            size: 16,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: DesignTokens.spaceLG),
                            Text(
                              'Create Account',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: DesignTokens.spaceSM),
                            // IMPROVEMENT #16: Help text
                            Text(
                              'Join Freegram to discover nearby users and connect',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color:
                                        SemanticColors.textSecondary(context),
                                    fontSize: DesignTokens.fontSizeMD,
                                  ),
                            ),
                            const SizedBox(height: DesignTokens.spaceXXL),

                            // NEW: Username Field
                            TextFormField(
                              controller: _usernameController,
                              focusNode: _usernameFocusNode,
                              textInputAction: TextInputAction.next,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              decoration: InputDecoration(
                                labelText: 'Username',
                                hintText: 'Choose a unique username',
                                prefixIcon: const Icon(Icons.person_outline),
                                suffixIcon: _usernameValidated &&
                                        _usernameController.text.isNotEmpty
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: SemanticColors.success,
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusMD),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusMD),
                                  borderSide: BorderSide(
                                    color: _usernameValidated
                                        ? SemanticColors.success
                                        : Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withValues(
                                                alpha:
                                                    DesignTokens.opacityMedium),
                                    width: _usernameValidated ? 2 : 1,
                                  ),
                                ),
                              ),
                              enabled: !isLoading,
                              onFieldSubmitted: (_) => WidgetsBinding.instance
                                  .addPostFrameCallback((_) {
                                if (mounted) _emailFocusNode.requestFocus();
                              }),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Username is required';
                                }
                                if (value.length < 3) {
                                  return 'Username must be at least 3 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: DesignTokens.spaceMD),

                            // IMPROVEMENT #2: Email field with validation feedback
                            TextFormField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
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
                                        color: SemanticColors.success,
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusMD),
                                ),
                                // IMPROVEMENT #2: Visual feedback
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusMD),
                                  borderSide: BorderSide(
                                    color: _emailValidated
                                        ? SemanticColors.success
                                        : Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withValues(
                                                alpha:
                                                    DesignTokens.opacityMedium),
                                    width: _emailValidated ? 2 : 1,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusMD),
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
                              onFieldSubmitted: (_) => WidgetsBinding.instance
                                  .addPostFrameCallback((_) {
                                if (mounted) _passwordFocusNode.requestFocus();
                              }),
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
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
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
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
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
                                  borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusMD),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusMD),
                                  borderSide: BorderSide(
                                    color: _passwordValidated &&
                                            _passwordController.text.isNotEmpty
                                        ? SemanticColors.success
                                        : Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withValues(
                                                alpha:
                                                    DesignTokens.opacityMedium),
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
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        color: _passwordStrength < 0.4
                                            ? SemanticColors.error
                                            : (_passwordStrength < 0.7
                                                ? SemanticColors.warning
                                                : SemanticColors.success),
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
                                          ? SemanticColors.error
                                          : (_passwordStrength < 0.7
                                              ? SemanticColors.warning
                                              : SemanticColors.success),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: DesignTokens.spaceSM),
                              // IMPROVEMENT #3: Password requirements checklist
                              ..._getPasswordRequirements(
                                      _passwordController.text)
                                  .map(
                                (req) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: DesignTokens.spaceXS),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _passwordController.text.isNotEmpty &&
                                                    (req.contains(
                                                            '6 characters') &&
                                                        _passwordController
                                                                .text.length >=
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
                                        color: _passwordController.text.isNotEmpty &&
                                                    (req.contains('6 characters') &&
                                                        _passwordController
                                                                .text.length >=
                                                            6) ||
                                                (req.contains('uppercase') &&
                                                    RegExp(r'[A-Z]').hasMatch(
                                                        _passwordController
                                                            .text)) ||
                                                (req.contains('number') &&
                                                    RegExp(r'[0-9]').hasMatch(
                                                        _passwordController
                                                            .text))
                                            ? SemanticColors.success
                                            : SemanticColors.textSecondary(context)
                                                .withValues(
                                                    alpha: DesignTokens.opacityMedium),
                                      ),
                                      const SizedBox(
                                          width: DesignTokens.spaceXS),
                                      Text(
                                        req,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontSize: DesignTokens.fontSizeSM,
                                              color:
                                                  SemanticColors.textSecondary(
                                                      context),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

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
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                  foregroundColor: canSubmit
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : SemanticColors.textSecondary(context),
                                  disabledBackgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  disabledForegroundColor:
                                      SemanticColors.textSecondary(context)
                                          .withValues(
                                              alpha:
                                                  DesignTokens.opacityDisabled),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        DesignTokens.radiusMD),
                                  ),
                                  elevation:
                                      canSubmit ? DesignTokens.elevation2 : 0,
                                ),
                                child: isLoading
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
