// lib/screens/multi_step_onboarding_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/auth_bloc.dart';
import 'package:freegram/blocs/profile_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/island_popup.dart';
import 'package:freegram/widgets/common/keyboard_safe_area.dart';
import 'package:freegram/widgets/freegram_app_bar.dart';
import 'package:freegram/utils/auth_constants.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

/// Animated input field that moves above keyboard with blur effect
class AnimatedInputField extends StatefulWidget {
  final Widget child;
  final GlobalKey? fieldKey;

  const AnimatedInputField({
    super.key,
    required this.child,
    this.fieldKey,
  });

  @override
  State<AnimatedInputField> createState() => _AnimatedInputFieldState();
}

class _AnimatedInputFieldState extends State<AnimatedInputField>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _blurAnimation;
  OverlayEntry? _blurOverlay;
  bool _isFocused = false;
  final GlobalKey _fieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.2), // Move up when focused
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInBack,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02, // Slight scale up for pop effect
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInBack,
    ));

    _blurAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  void _showBlur() {
    if (_blurOverlay != null) return;

    final overlay = Overlay.of(context);

    _blurOverlay = OverlayEntry(
      maintainState: false,
      builder: (context) {
        return Stack(
          children: [
            // Full screen blur
            Positioned.fill(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: AnimatedBuilder(
                  animation: _blurAnimation,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _blurAnimation.value * 0.4,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: 10 * _blurAnimation.value,
                            sigmaY: 10 * _blurAnimation.value,
                          ),
                          child: Container(
                            color: Theme.of(context)
                                .scaffoldBackgroundColor
                                .withOpacity(0.2 * _blurAnimation.value),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_blurOverlay!);

    // Force overlay to update when field position changes
    _blurOverlay!.markNeedsBuild();
  }

  void _hideBlur() {
    _blurOverlay?.remove();
    _blurOverlay = null;
  }

  void _handleFocusChange(bool hasFocus) {
    setState(() {
      _isFocused = hasFocus;
    });

    if (hasFocus) {
      // Start animation first
      _animationController.forward();
      // Then show blur after field starts moving
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isFocused) {
          _showBlur();
          // Update blur position continuously while focused
          _animationController.addListener(_updateBlurPosition);
        }
      });
    } else {
      _animationController.removeListener(_updateBlurPosition);
      _animationController.reverse().then((_) {
        if (mounted) {
          _hideBlur();
        }
      });
    }
  }

  void _updateBlurPosition() {
    // Update blur overlay to follow field position
    if (_blurOverlay != null && _isFocused) {
      _blurOverlay!.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _hideBlur();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: _handleFocusChange,
      child: Container(
        key: _fieldKey,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: SlideTransition(
                position: _slideAnimation,
                child: Material(
                  type: MaterialType.transparency,
                  elevation: _isFocused ? 24 : 0,
                  shadowColor: _isFocused
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
                      : Colors.transparent,
                  child: widget.child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Multi-step onboarding screen (WhatsApp-style)
/// Step 1: Name + Profile Picture
/// Step 2: Date of Birth + Gender
/// Step 3: Bio + Nearby Info
class MultiStepOnboardingScreen extends StatefulWidget {
  final UserModel? currentUserData;

  const MultiStepOnboardingScreen({
    super.key,
    this.currentUserData,
  });

  @override
  State<MultiStepOnboardingScreen> createState() =>
      _MultiStepOnboardingScreenState();
}

class _MultiStepOnboardingScreenState extends State<MultiStepOnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 3;

  // Keyboard-aware scrolling controllers
  final Map<int, ScrollController> _stepScrollControllers = {};
  final Map<GlobalKey, FocusNode> _fieldFocusNodes = {};

  // IMPROVEMENT #21: Animation controllers for step completion and celebration
  late AnimationController _stepAnimationController;
  late AnimationController _celebrationAnimationController;
  late Animation<double> _stepScaleAnimation;
  late Animation<double> _celebrationRotationAnimation;

  // Step 1: Name + Photo
  final TextEditingController _nameController = TextEditingController();
  XFile? _imageFile;
  String? _uploadedImageUrl; // Store uploaded image URL
  final ImagePicker _picker = ImagePicker();

  // Step 2: DOB + Gender + Location/Country
  DateTime? _selectedDateOfBirth;
  String? _selectedGender;
  String? _selectedCountry;
  GeoPoint? _userLocation; // Store user's location coordinates
  bool _locationDetecting = false; // Track if location detection is in progress
  final List<String> _genders = ['Male', 'Female', 'Other'];
  // IMPROVEMENT #31: Gender icons
  final Map<String, IconData> _genderIcons = {
    'Male': Icons.male,
    'Female': Icons.female,
    'Other': Icons.transgender,
  };

  // Step 3: Bio + Nearby Info
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _nearbyStatusController = TextEditingController();
  final TextEditingController _nearbyStatusEmojiController =
      TextEditingController();

  // IMPROVEMENT #35: Auto-save draft key
  static const String _onboardingDraftKey = 'onboarding_draft';

  // IMPROVEMENT #40: Success screen flag
  bool _showSuccessScreen = false;

  // IMPROVEMENT #38: Field validation states
  bool _nameValidated = false;
  bool _dobValidated = false;
  bool _genderValidated = false;
  bool _countryValidated = false;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: multi_step_onboarding_screen.dart');

    // Initialize scroll controllers for keyboard-aware scrolling
    for (int i = 0; i < _totalSteps; i++) {
      _stepScrollControllers[i] = ScrollController();
    }

    // IMPROVEMENT #21: Initialize animation controllers
    _stepAnimationController = AnimationController(
      vsync: this,
      duration: DesignTokens.durationNormal,
    );
    _celebrationAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _stepScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _stepAnimationController,
        curve: DesignTokens.curveElasticOut,
      ),
    );
    _celebrationRotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _celebrationAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    // IMPROVEMENT #22: Smart field auto-fill from social login (existing logic)
    // IMPROVEMENT #35: Restore auto-saved draft
    _restoreDraft();

    if (widget.currentUserData != null) {
      _nameController.text = widget.currentUserData!.username;
      _nameValidated = widget.currentUserData!.username.isNotEmpty;

      if (widget.currentUserData!.bio.isNotEmpty) {
        _bioController.text = widget.currentUserData!.bio;
      }
      if (widget.currentUserData!.gender.isNotEmpty) {
        _selectedGender = widget.currentUserData!.gender;
        _genderValidated = true;
      }
      if (widget.currentUserData!.country.isNotEmpty) {
        _selectedCountry = widget.currentUserData!.country;
        _countryValidated = true;
      }
      if (widget.currentUserData!.age > 0) {
        // Calculate DOB from age (approximate)
        final now = DateTime.now();
        _selectedDateOfBirth = DateTime(
          now.year - widget.currentUserData!.age,
          now.month,
          now.day,
        );
        _dobValidated = true;
      }
      if (widget.currentUserData!.nearbyStatusMessage.isNotEmpty) {
        _nearbyStatusController.text =
            widget.currentUserData!.nearbyStatusMessage;
      }
      if (widget.currentUserData!.nearbyStatusEmoji.isNotEmpty) {
        _nearbyStatusEmojiController.text =
            widget.currentUserData!.nearbyStatusEmoji;
      }
    }

    // IMPROVEMENT #38: Add listeners for field validation
    _nameController.addListener(() {
      setState(() {
        _nameValidated = _nameController.text.trim().isNotEmpty;
      });
      _saveDraft();
    });

    _bioController.addListener(_saveDraft);
    _nearbyStatusController.addListener(_saveDraft);
    _nearbyStatusEmojiController.addListener(_saveDraft);
  }

  // IMPROVEMENT #24: Age calculation helper
  int? _calculateAge() {
    if (_selectedDateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - _selectedDateOfBirth!.year;
    if (now.month < _selectedDateOfBirth!.month ||
        (now.month == _selectedDateOfBirth!.month &&
            now.day < _selectedDateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  // IMPROVEMENT #35: Save draft progress
  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_onboardingDraftKey, _serializeDraft());
    } catch (e) {
      debugPrint('Error saving onboarding draft: $e');
    }
  }

  // IMPROVEMENT #35: Restore draft progress
  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftJson = prefs.getString(_onboardingDraftKey);
      if (draftJson != null && draftJson.isNotEmpty) {
        _deserializeDraft(draftJson);
      }
    } catch (e) {
      debugPrint('Error restoring onboarding draft: $e');
    }
  }

  String _serializeDraft() {
    // Simple JSON-like serialization
    return '${_nameController.text}|$_selectedDateOfBirth?.millisecondsSinceEpoch|$_selectedGender|$_selectedCountry|${_bioController.text}|${_nearbyStatusController.text}|${_nearbyStatusEmojiController.text}';
  }

  void _deserializeDraft(String draft) {
    final parts = draft.split('|');
    if (parts.length >= 7) {
      _nameController.text = parts[0];
      if (parts[1] != 'null' && parts[1].isNotEmpty) {
        final timestamp = int.tryParse(parts[1]);
        if (timestamp != null) {
          _selectedDateOfBirth = DateTime.fromMillisecondsSinceEpoch(timestamp);
          _dobValidated = true;
        }
      }
      _selectedGender = parts[2] != 'null' ? parts[2] : null;
      _genderValidated = _selectedGender != null;
      _selectedCountry = parts[3] != 'null' ? parts[3] : null;
      _countryValidated = _selectedCountry != null;
      _bioController.text = parts[4];
      _nearbyStatusController.text = parts[5];
      _nearbyStatusEmojiController.text = parts[6];
      _nameValidated = _nameController.text.isNotEmpty;
    }
  }

  // IMPROVEMENT #35: Clear draft on completion
  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingDraftKey);
    } catch (e) {
      debugPrint('Error clearing onboarding draft: $e');
    }
  }

  /// Detect user's current location and get country from coordinates
  Future<void> _detectLocationAndCountry() async {
    if (!mounted) return;

    setState(() {
      _locationDetecting = true;
    });

    try {
      // Step 1: Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          showIslandPopup(
            context: context,
            message:
                'Location services are disabled. Please enable them in your device settings.',
            icon: Icons.location_off,
          );
        }
        setState(() {
          _locationDetecting = false;
        });
        return;
      }

      // Step 2: Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            showIslandPopup(
              context: context,
              message:
                  'Location permission is required to detect your country. Please grant permission in settings.',
              icon: Icons.location_off,
            );
          }
          setState(() {
            _locationDetecting = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showIslandPopup(
            context: context,
            message:
                'Location permission is permanently denied. Please enable it in app settings.',
            icon: Icons.settings,
          );
        }
        setState(() {
          _locationDetecting = false;
        });
        return;
      }

      // Step 3: Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Step 4: Reverse geocode to get country
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final country = place.country ?? place.isoCountryCode;

        if (country != null && country.isNotEmpty) {
          setState(() {
            _selectedCountry = country;
            _userLocation = GeoPoint(position.latitude, position.longitude);
            _countryValidated = true;
            _locationDetecting = false;
          });
          _saveDraft();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Location detected: $country'),
                backgroundColor: DesignTokens.successColor,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            showIslandPopup(
              context: context,
              message:
                  'Could not determine country from location. Please try again.',
              icon: Icons.error_outline,
            );
          }
          setState(() {
            _locationDetecting = false;
          });
        }
      } else {
        if (mounted) {
          showIslandPopup(
            context: context,
            message: 'Could not get location information. Please try again.',
            icon: Icons.error_outline,
          );
        }
        setState(() {
          _locationDetecting = false;
        });
      }
    } catch (e) {
      debugPrint('Error detecting location: $e');
      if (mounted) {
        showIslandPopup(
          context: context,
          message: 'Error detecting location: ${e.toString()}',
          icon: Icons.error_outline,
        );
      }
      setState(() {
        _locationDetecting = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stepAnimationController.dispose();
    _celebrationAnimationController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _nearbyStatusController.dispose();
    _nearbyStatusEmojiController.dispose();
    // Dispose scroll controllers
    for (var controller in _stepScrollControllers.values) {
      controller.dispose();
    }
    // Dispose focus nodes
    for (var focusNode in _fieldFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  // IMPROVEMENT #32: Emoji picker for nearby status
  Future<void> _showEmojiPicker() async {
    final popularEmojis = [
      '😊',
      '😎',
      '🔥',
      '💯',
      '❤️',
      '⭐',
      '🎉',
      '🚀',
      '💪',
      '🌟'
    ];

    final selectedEmoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusXL)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(DesignTokens.spaceLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose an emoji',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: DesignTokens.spaceLG),
            Wrap(
              spacing: DesignTokens.spaceMD,
              runSpacing: DesignTokens.spaceMD,
              children: popularEmojis.map((emoji) {
                return GestureDetector(
                  onTap: () => Navigator.pop(context, emoji),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMD),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: DesignTokens.spaceLG),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    if (selectedEmoji != null) {
      setState(() {
        _nearbyStatusEmojiController.text = selectedEmoji;
      });
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        // IMPROVEMENT #28: Step validation hints
        if (_nameController.text.trim().isEmpty) {
          showIslandPopup(
            context: context,
            message: 'Please enter your name to continue',
            icon: Icons.error_outline,
          );
          return false;
        }
        if (_nameController.text.trim().length < 2) {
          showIslandPopup(
            context: context,
            message: 'Name must be at least 2 characters',
            icon: Icons.error_outline,
          );
          return false;
        }
        return true;
      case 1:
        // IMPROVEMENT #28: Step validation hints with specific messages
        if (_selectedDateOfBirth == null) {
          showIslandPopup(
            context: context,
            message: 'Please select your date of birth',
            icon: Icons.calendar_today_outlined,
          );
          return false;
        }
        final age = _calculateAge();
        if (age != null && age < 13) {
          showIslandPopup(
            context: context,
            message: 'You must be at least 13 years old to use this app',
            icon: Icons.error_outline,
          );
          return false;
        }
        if (_selectedGender == null) {
          showIslandPopup(
            context: context,
            message: 'Please select your gender',
            icon: Icons.person_outline,
          );
          return false;
        }
        if (_selectedCountry == null) {
          showIslandPopup(
            context: context,
            message: 'Please select your country',
            icon: Icons.public_outlined,
          );
          return false;
        }
        return true;
      case 2:
        // Step 3: Optional fields, always valid
        return true;
      default:
        return false;
    }
  }

  void _nextStep(BuildContext blocContext) {
    // IMPROVEMENT #34: Close keyboard when Next is pressed
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_validateCurrentStep()) return;

    if (_currentStep < _totalSteps - 1) {
      // IMPROVEMENT #21: Step completion animation
      _stepAnimationController.forward().then((_) {
        _stepAnimationController.reset();
      });

      _pageController.nextPage(
        duration: DesignTokens.durationNormal,
        curve: DesignTokens.curveEaseInOut,
      );
      setState(() {
        _currentStep++;
        _saveDraft(); // IMPROVEMENT #35: Save progress
      });
    } else {
      // Final step - complete onboarding
      _completeOnboarding(blocContext);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _completeOnboarding(BuildContext blocContext) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      showIslandPopup(
        context: context,
        message: 'Error: You are not logged in',
        icon: Icons.error_outline,
      );
      return;
    }

    // IMPROVEMENT #36: Celebration animation
    _celebrationAnimationController.forward();

    // IMPROVEMENT #40: Show success screen before navigation
    setState(() {
      _showSuccessScreen = true;
    });

    // Wait for celebration animation
    await Future.delayed(const Duration(milliseconds: 1500));

    // IMPROVEMENT #24: Use accurate age calculation
    final age = _calculateAge() ?? 0;

    // Prepare update data
    final Map<String, dynamic> updatedData = {
      'username': _nameController.text.trim(),
      'age': age,
      'gender': _selectedGender ?? '',
      'country': _selectedCountry ?? '',
      'location': _userLocation,
      'bio': _bioController.text.trim(),
      'nearbyStatusMessage': _nearbyStatusController.text.trim(),
      'nearbyStatusEmoji': _nearbyStatusEmojiController.text.trim(),
      'nearbyDataVersion': FieldValue.increment(1),
    };

    // Use uploaded image URL if available, otherwise upload now
    if (_uploadedImageUrl != null) {
      updatedData['photoUrl'] = _uploadedImageUrl;
    }

    // IMPROVEMENT #35: Clear draft on completion
    await _clearDraft();

    // Dispatch update event using the blocContext that has access to ProfileBloc
    blocContext.read<ProfileBloc>().add(ProfileUpdateEvent(
          userId: currentUser.uid,
          updatedData: updatedData,
          imageFile: _uploadedImageUrl == null
              ? _imageFile
              : null, // Only upload if not already uploaded
        ));
  }

  Future<void> _pickImage(BuildContext blocContext) async {
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
                margin: const EdgeInsets.symmetric(vertical: DesignTokens.spaceMD),
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
        if (source == ImageSource.camera) {
          final permissionStatus = await Permission.camera.status;
          if (!permissionStatus.isGranted) {
            final permission = await Permission.camera.request();
            if (!permission.isGranted) {
              if (mounted) {
                showIslandPopup(
                  context: context,
                  message: 'Camera permission required',
                  icon: Icons.camera_alt_outlined,
                );
              }
              return;
            }
          }
        }

        final XFile? pickedFile = await _picker
            .pickImage(
          source: source,
          imageQuality: 70,
          maxWidth: 1024,
          maxHeight: 1024,
        )
            .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint('Image picker timed out');
            return null;
          },
        );

        if (pickedFile != null) {
          final fileSize = await pickedFile.length();
          if (fileSize > 5 * 1024 * 1024) {
            if (mounted) {
              showIslandPopup(
                context: context,
                message: 'Image too large. Please choose an image under 5 MB.',
                icon: Icons.error_outline,
              );
            }
            return;
          }

          if (mounted) {
            setState(() {
              _imageFile = pickedFile;
            });

            // Immediately start uploading the image
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null && mounted) {
              blocContext.read<ProfileBloc>().add(
                    ProfileImageUploadOnlyEvent(
                      userId: currentUser.uid,
                      imageFile: pickedFile,
                    ),
                  );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        showIslandPopup(
          context: context,
          message: 'Failed to pick image',
          icon: Icons.error_outline,
        );
      }
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate =
        _selectedDateOfBirth ?? DateTime(now.year - 18, now.month, now.day);

    // Initialize selected values
    int selectedDay = initialDate.day;
    int selectedMonth = initialDate.month;
    int selectedYear = initialDate.year;

    // Get valid ranges
    final int minYear = now.year - 100;
    final int maxYear = now.year - 13;

    // Generate lists for pickers
    final List<int> days = List.generate(31, (i) => i + 1);
    final List<int> months = List.generate(12, (i) => i + 1);
    final List<int> years =
        List.generate(maxYear - minYear + 1, (i) => maxYear - i);

    // Adjust day if needed for selected month/year
    int daysInMonth(DateTime date) {
      return DateTime(date.year, date.month + 1, 0).day;
    }

    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radiusXL),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(DesignTokens.spaceLG),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: DesignTokens.fontSizeMD,
                      ),
                    ),
                  ),
                  Text(
                    'Date of Birth',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  TextButton(
                    onPressed: () {
                      final age = now.year - selectedYear;
                      if (age >= 13 && age <= 100) {
                        // Adjust day if it exceeds days in selected month
                        final daysInSelectedMonth = daysInMonth(
                          DateTime(selectedYear, selectedMonth, 1),
                        );
                        if (selectedDay > daysInSelectedMonth) {
                          selectedDay = daysInSelectedMonth;
                        }
                        Navigator.of(context).pop(
                          DateTime(selectedYear, selectedMonth, selectedDay),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              age < 13
                                  ? 'You must be at least 13 years old'
                                  : 'Invalid age range',
                            ),
                            backgroundColor: DesignTokens.errorColor,
                          ),
                        );
                      }
                    },
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: DesignTokens.fontSizeMD,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // iOS-style triple vertical slider
            Expanded(
              child: Row(
                children: [
                  // Day picker
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: selectedDay - 1,
                      ),
                      itemExtent: 50,
                      onSelectedItemChanged: (index) {
                        selectedDay = days[index];
                      },
                      children: days.map((day) {
                        return Center(
                          child: Text(
                            day.toString().padLeft(2, '0'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Month picker
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: selectedMonth - 1,
                      ),
                      itemExtent: 50,
                      onSelectedItemChanged: (index) {
                        selectedMonth = months[index];
                        // Adjust day if it exceeds days in selected month
                        final daysInSelectedMonth = daysInMonth(
                          DateTime(selectedYear, selectedMonth, 1),
                        );
                        if (selectedDay > daysInSelectedMonth) {
                          selectedDay = daysInSelectedMonth;
                        }
                      },
                      children: [
                        'Jan',
                        'Feb',
                        'Mar',
                        'Apr',
                        'May',
                        'Jun',
                        'Jul',
                        'Aug',
                        'Sep',
                        'Oct',
                        'Nov',
                        'Dec'
                      ].map((month) {
                        return Center(
                          child: Text(
                            month,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Year picker
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: years.indexOf(selectedYear),
                      ),
                      itemExtent: 50,
                      onSelectedItemChanged: (index) {
                        selectedYear = years[index];
                        // Adjust day if it exceeds days in selected month
                        final daysInSelectedMonth = daysInMonth(
                          DateTime(selectedYear, selectedMonth, 1),
                        );
                        if (selectedDay > daysInSelectedMonth) {
                          selectedDay = daysInSelectedMonth;
                        }
                      },
                      children: years.map((year) {
                        final age = now.year - year;
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                year.toString(),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                'Age: $age',
                                style: TextStyle(
                                  fontSize: DesignTokens.fontSizeXS,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dobValidated = true;
        _saveDraft();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileBloc(
        userRepository: locator<UserRepository>(),
      ),
      child: BlocListener<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileImageUploading) {
            final percentage = (state.progress * 100).toInt();
            // Always show progress, even at 0%
            showIslandPopup(
              context: context,
              message: 'Uploading image... $percentage%',
              icon: Icons.cloud_upload_outlined,
            );
          }

          if (state is ProfileImageUploaded) {
            // Image uploaded successfully - store the URL
            setState(() {
              _uploadedImageUrl = state.imageUrl;
            });
            showIslandPopup(
              context: context,
              message: 'Image uploaded successfully!',
              icon: Icons.check_circle_outline,
            );
          }

          if (state is ProfileUpdateSuccess) {
            // Mark onboarding as complete
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null && mounted) {
              final settingsBox = Hive.box('settings');
              // Use AuthConstants.getOnboardingKey for consistency with AuthWrapper
              final onboardingKey =
                  AuthConstants.getOnboardingKey(currentUser.uid);
              settingsBox.put(onboardingKey, true);
              debugPrint(
                "Onboarding marked as complete for user ${currentUser.uid}",
              );

              // CRITICAL FIX: Ensure AuthWrapper rebuilds after profile update
              // The AuthWrapper listens to the user stream and will automatically
              // switch from MultiStepOnboardingScreen to MainScreen when it detects
              // that onboarding is complete and profile is complete.
              //
              // The ProfileUpdateSuccess event already updated Firestore, which will
              // trigger the user stream to emit a new value, causing AuthWrapper to rebuild.
              // However, there might be a slight delay. We add a small delay to ensure
              // Firestore has propagated the update, then force a check.
              //
              // As a fallback, if navigation doesn't happen within 3 seconds, we'll
              // try to manually trigger a stream refresh by checking the user data again.
              debugPrint(
                'Onboarding complete - AuthWrapper will handle navigation when user stream updates',
              );

              // Wait for Firestore to propagate the update, then verify navigation happens
              // The StreamBuilder in AuthWrapper should automatically rebuild when the stream emits
              // Add a delay to ensure Firestore has time to propagate the update
              Future.delayed(const Duration(milliseconds: 500), () async {
                if (!mounted) return;

                // Verify the update was successful by checking Firestore
                try {
                  final userRepository = locator<UserRepository>();
                  final updatedUser =
                      await userRepository.getUser(currentUser.uid);
                  final isProfileComplete = updatedUser.age > 0 &&
                      updatedUser.country.isNotEmpty &&
                      updatedUser.gender.isNotEmpty &&
                      updatedUser.username.isNotEmpty &&
                      updatedUser.username != 'User';

                  if (isProfileComplete && mounted) {
                    debugPrint(
                      'MultiStepOnboardingScreen: Profile update confirmed in Firestore. '
                      'Profile data: age=${updatedUser.age}, country=${updatedUser.country}, '
                      'gender=${updatedUser.gender}, username=${updatedUser.username}',
                    );

                    // The StreamBuilder in AuthWrapper should automatically detect the Firestore update
                    // However, Firestore streams can have delays. If the stream doesn't update within
                    // 1.5 seconds, we'll trigger a manual refresh by writing a dummy field to Firestore
                    // and immediately removing it. This forces the stream to emit a new value.
                    Future.delayed(const Duration(milliseconds: 1500), () async {
                      if (!mounted || !_showSuccessScreen) return;
                      
                      debugPrint(
                        'MultiStepOnboardingScreen: Stream update delay detected. '
                        'Attempting to force stream refresh...',
                      );
                      
                      try {
                        // Force the Firestore stream to emit by updating a timestamp field
                        // This is a common technique to force stream updates when the stream
                        // doesn't detect changes immediately after an update
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser.uid)
                            .update({
                          'lastProfileUpdate': DateTime.now().toIso8601String(),
                        });
                        debugPrint(
                          'MultiStepOnboardingScreen: Triggered stream refresh update. '
                          'AuthWrapper should rebuild shortly.',
                        );
                      } catch (e) {
                        debugPrint(
                          'MultiStepOnboardingScreen: Error forcing stream refresh: $e',
                        );
                      }
                    });
                  } else {
                    debugPrint(
                      'MultiStepOnboardingScreen: Profile update incomplete. '
                      'age=${updatedUser.age}, country=${updatedUser.country}, '
                      'gender=${updatedUser.gender}, username=${updatedUser.username}',
                    );
                  }
                } catch (e) {
                  debugPrint(
                    'MultiStepOnboardingScreen: Error verifying profile update: $e',
                  );
                }
              });
            }
          }

          if (state is ProfileError) {
            showIslandPopup(
              context: context,
              message: state.message,
              icon: Icons.error_outline,
            );
          }
        },
        child: Builder(
          builder: (blocContext) => WillPopScope(
            onWillPop: () async {
              // Show confirmation dialog when user tries to go back
              final shouldExit = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cancel Onboarding?'),
                  content: const Text(
                    'Are you sure you want to cancel? You will be signed out and need to complete this setup to use the app.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Continue'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );

              if (shouldExit == true) {
                // User confirmed - sign out
                context.read<AuthBloc>().add(SignOut());
                return true;
              }
              return false; // Prevent back navigation
            },
            child: _showSuccessScreen
                ? _buildSuccessScreen()
                : Scaffold(
                    // CRITICAL: Explicit background color to prevent black screen during transitions
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    resizeToAvoidBottomInset: true,
                    // IMPROVEMENT #34: Better keyboard handling
                    appBar: FreegramAppBar(
                      title: 'Register',
                      showBackButton: true,
                      onBackPressed: () async {
                        // Same logic as WillPopScope
                        final shouldExit = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Cancel Onboarding?'),
                            content: const Text(
                              'Are you sure you want to cancel? You will be signed out and need to complete this setup to use the app.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Continue'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      Theme.of(context).colorScheme.error,
                                ),
                                child: const Text('Sign Out'),
                              ),
                            ],
                          ),
                        );

                        if (shouldExit == true) {
                          // User confirmed - sign out
                          context.read<AuthBloc>().add(SignOut());
                        }
                      },
                    ),
                    body: SafeArea(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Get keyboard height
                          final keyboardHeight =
                              MediaQuery.of(context).viewInsets.bottom;
                          final isKeyboardVisible = keyboardHeight > 0;

                          return Column(
                            children: [
                              // IMPROVEMENT #21 & #33: Enhanced progress indicator with percentage
                              Padding(
                                padding:
                                    const EdgeInsets.all(DesignTokens.spaceLG),
                                child: Column(
                                  children: [
                                    Row(
                                      children: List.generate(
                                        _totalSteps,
                                        (index) => Expanded(
                                          child: AnimatedContainer(
                                            duration:
                                                DesignTokens.durationNormal,
                                            curve: DesignTokens.curveEaseInOut,
                                            height: 6,
                                            margin: EdgeInsets.only(
                                              right: index < _totalSteps - 1
                                                  ? DesignTokens.spaceSM
                                                  : 0,
                                            ),
                                            decoration: BoxDecoration(
                                              color: index <= _currentStep
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Colors.grey[300],
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      DesignTokens.radiusXS),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                        height: DesignTokens.spaceMD),
                                    // IMPROVEMENT #33: Progress percentage display
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Step ${_currentStep + 1} of $_totalSteps',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        Text(
                                          '${((_currentStep + 1) / _totalSteps * 100).toInt()}% Complete',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Page content - adjust height when keyboard is visible
                              Expanded(
                                child: KeyboardSafeArea(
                                  child: PageView(
                                    controller: _pageController,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    children: [
                                      _buildStep1(),
                                      _buildStep2(),
                                      _buildStep3(),
                                    ],
                                  ),
                                ),
                              ),

                              // Navigation buttons - hide when keyboard is visible
                              AnimatedSize(
                                duration: const Duration(milliseconds: 100),
                                child: isKeyboardVisible
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            if (_currentStep > 0)
                                              TextButton.icon(
                                                onPressed: _previousStep,
                                                icon: const Icon(
                                                    Icons.arrow_back),
                                                label: const Text('Back'),
                                              )
                                            else
                                              const SizedBox.shrink(),
                                            ElevatedButton.icon(
                                              onPressed: () =>
                                                  _nextStep(blocContext),
                                              style: ElevatedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal:
                                                      DesignTokens.spaceXL,
                                                  vertical:
                                                      DesignTokens.spaceMD,
                                                ),
                                                backgroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                foregroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .onPrimary,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    DesignTokens.radiusMD,
                                                  ),
                                                ),
                                              ),
                                              icon: Icon(
                                                _currentStep == _totalSteps - 1
                                                    ? Icons.check_circle
                                                    : Icons.arrow_forward,
                                              ),
                                              label: Text(
                                                _currentStep == _totalSteps - 1
                                                    ? 'Complete'
                                                    : 'Next',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize:
                                                      DesignTokens.fontSizeLG,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    final scrollController = _stepScrollControllers[0]!;

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(DesignTokens.spaceLG),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: DesignTokens.spaceXL),
          // IMPROVEMENT #21: Step completion animation wrapper
          ScaleTransition(
            scale: _stepScaleAnimation,
            child: Column(
              children: [
                Text(
                  'Add your name and photo',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.spaceMD),
                Text(
                  'This is how other users will see you',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXXL),
          // IMPROVEMENT #27: Enhanced profile picture preview
          Builder(
            builder: (blocContext) => GestureDetector(
              onTap: () => _pickImage(blocContext),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _uploadedImageUrl != null || _imageFile != null
                            ? DesignTokens.successColor
                            : Colors.grey[300]!,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 70,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _uploadedImageUrl != null
                          ? NetworkImage(_uploadedImageUrl!)
                          : (_imageFile != null
                              ? (kIsWeb
                                      ? NetworkImage(_imageFile!.path)
                                      : FileImage(File(_imageFile!.path)))
                                  as ImageProvider
                              : (widget.currentUserData?.photoUrl != null &&
                                      widget
                                          .currentUserData!.photoUrl.isNotEmpty
                                  ? NetworkImage(
                                      widget.currentUserData!.photoUrl)
                                  : null)),
                      child: _imageFile == null &&
                              (widget.currentUserData?.photoUrl == null ||
                                  widget.currentUserData!.photoUrl.isEmpty)
                          ? Icon(Icons.camera_alt,
                              size: 70, color: Colors.grey[400])
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(DesignTokens.spaceSM),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: DesignTokens.shadowMedium,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: DesignTokens.iconMD,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_imageFile != null || _uploadedImageUrl != null) ...[
            const SizedBox(height: DesignTokens.spaceSM),
            const Text(
              'Photo selected ✓',
              style: TextStyle(
                color: DesignTokens.successColor,
                fontSize: DesignTokens.fontSizeSM,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: DesignTokens.spaceXXL),
          // IMPROVEMENT #37 & #38: Field with tooltip and validation feedback
          // IMPROVEMENT: Animated input field that moves above keyboard with blur
          AnimatedInputField(
            child: Tooltip(
              message: 'Enter your display name (2-50 characters)',
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter your name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                  ),
                  prefixIcon: const Icon(Icons.person_outline),
                  suffixIcon: _nameValidated
                      ? const Icon(
                          Icons.check_circle,
                          color: DesignTokens.successColor,
                        )
                      : null,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                    borderSide: BorderSide(
                      color: _nameValidated
                          ? DesignTokens.successColor
                          : Colors.grey[300]!,
                      width: _nameValidated ? 2 : 1,
                    ),
                  ),
                  helperText: _nameController.text.isEmpty
                      ? 'This will be shown to other users'
                      : null,
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 50,
                buildCounter: (context,
                    {required currentLength, required isFocused, maxLength}) {
                  return _nameController.text.isEmpty
                      ? const SizedBox.shrink()
                      : Text('$currentLength/$maxLength');
                },
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLG),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final calculatedAge = _calculateAge();
    final scrollController = _stepScrollControllers[1]!;

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(DesignTokens.spaceLG),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: DesignTokens.spaceXL),
          Text(
            'Tell us about yourself',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.spaceMD),
          Text(
            'Your age, gender, and country help others discover you',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.spaceXXL),

          // IMPROVEMENT #24 & #30: Date of Birth with iOS-style picker
          Tooltip(
            message: 'You must be at least 13 years old',
            child: InkWell(
              onTap: () {
                // Dismiss keyboard before showing date picker
                FocusScope.of(context).unfocus();
                _selectDateOfBirth();
              },
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date of Birth',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                    borderSide: BorderSide(
                      color: _dobValidated
                          ? DesignTokens.successColor
                          : Colors.grey[300]!,
                      width: _dobValidated ? 2 : 1,
                    ),
                  ),
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: _dobValidated
                      ? const Icon(
                          Icons.check_circle,
                          color: DesignTokens.successColor,
                        )
                      : const Icon(Icons.arrow_drop_down),
                  helperText: calculatedAge != null
                      ? 'Age: $calculatedAge years old'
                      : 'Select your date of birth',
                ),
                child: Text(
                  _selectedDateOfBirth != null
                      ? '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}'
                      : 'Select your date of birth',
                  style: TextStyle(
                    color: _selectedDateOfBirth == null
                        ? Colors.grey
                        : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLG),

          // IMPROVEMENT #31: Gender selection with icons
          Tooltip(
            message: 'Select your gender identity',
            child: DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                  borderSide: BorderSide(
                    color: _genderValidated
                        ? DesignTokens.successColor
                        : Colors.grey[300]!,
                    width: _genderValidated ? 2 : 1,
                  ),
                ),
                prefixIcon: const Icon(Icons.person_outline),
                suffixIcon: _genderValidated
                    ? const Icon(
                        Icons.check_circle,
                        color: DesignTokens.successColor,
                      )
                    : const Icon(Icons.arrow_drop_down),
              ),
              items: _genders
                  .map((String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Row(
                          children: [
                            Icon(
                              _genderIcons[value] ?? Icons.person,
                              size: DesignTokens.iconMD,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: DesignTokens.spaceSM),
                            Text(value),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedGender = newValue;
                  _genderValidated = newValue != null;
                  _saveDraft();
                });
              },
              hint: const Text('Select your gender'),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLG),

          // Location detection button to automatically get country
          Tooltip(
            message: 'Detect your country from current location',
            child: OutlinedButton.icon(
              onPressed: _locationDetecting ? null : _detectLocationAndCountry,
              icon: _locationDetecting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: AppProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Icon(
                      _countryValidated
                          ? Icons.location_on
                          : Icons.location_searching,
                      color: _countryValidated
                          ? DesignTokens.successColor
                          : Theme.of(context).colorScheme.primary,
                    ),
              label: Text(
                _countryValidated
                    ? (_selectedCountry ?? 'Location detected')
                    : 'Detect My Location',
                style: TextStyle(
                  color: _countryValidated
                      ? DesignTokens.successColor
                      : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceLG,
                  vertical: DesignTokens.spaceMD,
                ),
                side: BorderSide(
                  color: _countryValidated
                      ? DesignTokens.successColor
                      : Theme.of(context).colorScheme.primary,
                  width: _countryValidated ? 2 : 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                ),
              ),
            ),
          ),
          if (_countryValidated && _selectedCountry != null) ...[
            const SizedBox(height: DesignTokens.spaceSM),
            Container(
              padding: const EdgeInsets.all(DesignTokens.spaceMD),
              decoration: BoxDecoration(
                color: DesignTokens.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                border: Border.all(
                  color: DesignTokens.successColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: DesignTokens.successColor,
                    size: 20,
                  ),
                  const SizedBox(width: DesignTokens.spaceSM),
                  Expanded(
                    child: Text(
                      'Country: $_selectedCountry',
                      style: const TextStyle(
                        color: DesignTokens.successColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: DesignTokens.spaceLG),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    final bioLength = _bioController.text.length;
    final remainingChars = 150 - bioLength;
    final scrollController = _stepScrollControllers[2]!;

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(DesignTokens.spaceLG),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: DesignTokens.spaceXL),
          Text(
            'Complete your profile',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.spaceMD),
          Text(
            'Optional: Add a bio and status to help others discover you',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.spaceXXL),

          // IMPROVEMENT #26: Bio with enhanced character counter and suggestions
          AnimatedInputField(
            child: Tooltip(
              message: 'Tell others about yourself (optional)',
              child: TextField(
                controller: _bioController,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Tell others about yourself...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                  ),
                  prefixIcon: const Icon(Icons.info_outline),
                  helperText: bioLength == 0
                      ? 'Optional - helps others learn about you'
                      : remainingChars <= 20
                          ? '$remainingChars characters remaining'
                          : null,
                  helperMaxLines: 2,
                ),
                maxLines: 4,
                maxLength: 150,
                buildCounter: (context,
                    {required currentLength, required isFocused, maxLength}) {
                  final remaining = (maxLength ?? 150) - currentLength;
                  return Padding(
                    padding: const EdgeInsets.only(top: DesignTokens.spaceXS),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (remaining <= 20 && remaining > 0)
                          Text(
                            '$remaining left',
                            style: TextStyle(
                              color: remaining <= 10
                                  ? DesignTokens.errorColor
                                  : DesignTokens.warningColor,
                              fontSize: DesignTokens.fontSizeSM,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        Text(
                          '$currentLength/${maxLength ?? 150}',
                          style: TextStyle(
                            color: remaining <= 10
                                ? DesignTokens.errorColor
                                : Colors.grey[600],
                            fontSize: DesignTokens.fontSizeSM,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLG),
          const Divider(),
          const SizedBox(height: DesignTokens.spaceLG),

          // IMPROVEMENT #29: Mark optional fields clearly
          Row(
            children: [
              Text(
                'Nearby Status',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: DesignTokens.spaceSM),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceSM,
                  vertical: DesignTokens.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                ),
                child: Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeXS,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceSM),
          Text(
            'Only visible to users you discover nearby',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: DesignTokens.spaceMD),
          Row(
            children: [
              Expanded(
                child: AnimatedInputField(
                  child: Tooltip(
                    message: 'Enter a short status message',
                    child: TextField(
                      controller: _nearbyStatusController,
                      decoration: InputDecoration(
                        labelText: 'Status Message',
                        hintText: 'e.g., Looking for friends',
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusMD),
                        ),
                      ),
                      maxLength: 50,
                      buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) {
                        return Text('$currentLength/$maxLength');
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spaceMD),
              // IMPROVEMENT #32: Emoji picker button
              Tooltip(
                message: 'Tap to choose an emoji',
                child: InkWell(
                  onTap: _showEmojiPicker,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                  child: Container(
                    width: 80,
                    height: 56,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMD),
                    ),
                    child: Center(
                      child: _nearbyStatusEmojiController.text.isNotEmpty
                          ? Text(
                              _nearbyStatusEmojiController.text,
                              style: const TextStyle(fontSize: 28),
                            )
                          : const Icon(Icons.emoji_emotions_outlined),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceLG),
        ],
      ),
    );
  }

  // IMPROVEMENT #40: Professional success screen before navigation
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceXXL,
              vertical: DesignTokens.spaceXL,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Professional success indicator with subtle animation
                ScaleTransition(
                  scale: _celebrationRotationAnimation,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          DesignTokens.successColor,
                          DesignTokens.successColor.withOpacity(0.8),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: DesignTokens.successColor.withOpacity(0.25),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceXXL),
                // Professional typography
                Text(
                  'Profile Setup Complete',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.spaceMD),
                Text(
                  'Your profile has been successfully created.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[700],
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.spaceSM),
                Text(
                  'You can now discover and connect with nearby users.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(
                    height: DesignTokens.spaceXXL + DesignTokens.spaceMD),
                // Professional loading indicator
                SizedBox(
                  width: 36,
                  height: 36,
                  child: AppProgressIndicator(
                    strokeWidth: 3,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceMD),
                Text(
                  'Redirecting...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
