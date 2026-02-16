import 'package:flutter/material.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/services/session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Splash screen that displays during app initialization
/// Task 4: Upgraded with FadeTransition and Cyber-Violet pulse
class SplashScreen extends StatefulWidget {
  final Future<dynamic> Function()? onInitializationComplete;
  final Widget Function(dynamic)? onComplete;

  const SplashScreen({
    super.key,
    this.onInitializationComplete,
    this.onComplete,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

enum LoadingPhase {
  appInitialization,
  sessionPreparation,
  complete,
  error,
  timeout,
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  String _currentStep = 'Initializing...';
  int _currentStepIndex = 0;
  LoadingPhase _phase = LoadingPhase.appInitialization;

  bool _appInitComplete = false;
  dynamic _initializationResult;

  String? _errorMessage;
  bool _showTimeout = false;

  final List<String> _initializationSteps = [
    'Initializing Firebase...',
    'Setting up database...',
    'Loading user data...',
    'Preparing services...',
    'Almost ready...',
    'Preparing your session...',
  ];

  @override
  void initState() {
    super.initState();

    // Task 4: Fade animation for logo reveal
    _fadeController = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this);
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    // Task 4: Cyber-Violet Pulse (Visual Polish)
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
    _startUnifiedLoadingSequence();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Warm-up cache for next screen assets
    precacheImage(const AssetImage('assets/freegram_logo_no_bg.png'), context);
    // Add other critical assets here if they are images
  }

  void _startUnifiedLoadingSequence() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool hasSeenSplash = prefs.getBool('has_seen_splash') ?? false;

      // Start the actual background initialization immediately
      _runAppInitialization();

      if (!hasSeenSplash) {
        // FIRST TIME INSTALL: Brand impact mode
        await _animateInitialSteps();
        await prefs.setBool('has_seen_splash', true);
      } else {
        // RETURNING USER: Instant skip
        // Still need to wait for minimal app init sync
        int waitTime = 0;
        while (!_appInitComplete && mounted && waitTime < 5000) {
          await Future.delayed(const Duration(milliseconds: 50));
          waitTime += 50;
        }
      }

      if (!mounted) return;
      setState(() {
        _phase = LoadingPhase.sessionPreparation;
        _currentStep = _initializationSteps[5];
        _currentStepIndex = 5;
      });

      await _runSessionInitialization();

      if (!mounted) return;
      setState(() {
        _phase = LoadingPhase.complete;
        _currentStep = 'Ready!';
      });

      if (hasSeenSplash) {
        // Instant transition for returning users
        _navigateToNext(instant: true);
      } else {
        // Task 4: Modern Cyber-Violet Pulse Transition for first-timers
        await Future.delayed(const Duration(milliseconds: 800));
        _navigateToNext(instant: false);
      }
    } catch (e) {
      debugPrint('Loading sequence error: $e');
      if (mounted) {
        setState(() {
          _phase = LoadingPhase.error;
          _errorMessage = e.toString();
          _currentStep = 'Initialization failed';
        });
      }
    }
  }

  void _navigateToNext({bool instant = false}) {
    if (mounted && widget.onComplete != null) {
      final appWidget = widget.onComplete!(_initializationResult);
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => appWidget,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (instant) return child;
            return FadeTransition(
              opacity: animation,
              child: Container(
                color: const Color(0xFF1A0B2E)
                    .withValues(alpha: 1.0 - animation.value),
                child: child,
              ),
            );
          },
          transitionDuration:
              instant ? Duration.zero : const Duration(milliseconds: 800),
        ),
      );
    }
  }

  void _runAppInitialization() {
    if (widget.onInitializationComplete != null) {
      widget.onInitializationComplete!().then((result) {
        _appInitComplete = true;
        _initializationResult = result;
      }).catchError((error) {
        debugPrint('App initialization error: $error');
        if (mounted) {
          setState(() {
            _phase = LoadingPhase.error;
            _errorMessage = 'Failed to initialize app: ${error.toString()}';
            _currentStep = 'Initialization failed';
          });
        }
      });
    }
  }

  Future<void> _animateInitialSteps() async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() {
      _currentStep = _initializationSteps[0];
      _currentStepIndex = 0;
    });

    for (int i = 1; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 1200));

      if (!mounted) return;
      setState(() {
        _currentStepIndex = i;
        _currentStep = _initializationSteps[i];
      });
    }

    int waitTime = 0;
    while (!_appInitComplete && mounted && waitTime < 10000) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitTime += 100;
    }

    if (!_appInitComplete && mounted) {
      setState(() {
        _showTimeout = true;
      });
    }
  }

  Future<void> _runSessionInitialization() async {
    try {
      final sessionManager = SessionManager();
      await sessionManager.initialize();
      sessionManager.checkOnboardingAndStartServices();
    } catch (e) {
      debugPrint('Session initialization error: $e');
      if (mounted) {
        setState(() {
          _phase = LoadingPhase.error;
          _errorMessage = 'Failed to prepare session: ${e.toString()}';
          _currentStep = 'Session preparation failed';
        });
      }
      rethrow;
    }
  }

  void _retry() {
    setState(() {
      _phase = LoadingPhase.appInitialization;
      _currentStep = 'Initializing...';
      _currentStepIndex = 0;
      _appInitComplete = false;
      _errorMessage = null;
      _showTimeout = false;
    });
    _startUnifiedLoadingSequence();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_phase == LoadingPhase.error) {
      return Scaffold(
        backgroundColor: isDark
            ? SonarPulseTheme.darkBackground
            : SonarPulseTheme.lightBackground,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceLG),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: DesignTokens.spaceLG),
                  Text(
                    'Initialization Error',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceMD),
                  Text(
                    _errorMessage ?? 'An unexpected error occurred',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? SonarPulseTheme.darkTextSecondary
                          : SonarPulseTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceXL),
                  ElevatedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SonarPulseTheme.primaryAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spaceLG,
                        vertical: DesignTokens.spaceMD,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? SonarPulseTheme.darkBackground
          : SonarPulseTheme.lightBackground,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Task 4: FadeTransition for logo reveal
              FadeTransition(
                opacity: _fadeAnimation,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Image.asset(
                        'assets/freegram_logo_no_bg.png',
                        width: 180,
                        height: 180,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: DesignTokens.spaceXXL),

              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    SonarPulseTheme.primaryAccent,
                  ),
                ),
              ),

              const SizedBox(height: DesignTokens.spaceXL),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _currentStep,
                  key: ValueKey(_currentStep),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? SonarPulseTheme.darkTextSecondary
                        : SonarPulseTheme.lightTextSecondary,
                    fontSize: DesignTokens.fontSizeMD,
                  ),
                ),
              ),

              const SizedBox(height: DesignTokens.spaceLG),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _initializationSteps.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index <= _currentStepIndex
                          ? SonarPulseTheme.primaryAccent
                          : (isDark
                              ? SonarPulseTheme.darkDivider
                              : SonarPulseTheme.lightDivider),
                    ),
                  ),
                ),
              ),

              if (_showTimeout) ...[
                const SizedBox(height: DesignTokens.spaceXL),
                Text(
                  'Taking longer than usual...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
