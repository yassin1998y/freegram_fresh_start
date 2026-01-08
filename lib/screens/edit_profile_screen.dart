// lib/screens/edit_profile_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/profile_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/main_screen.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/freegram_app_bar.dart';
import 'package:freegram/widgets/common/keyboard_safe_area.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/common/app_button.dart';
import 'package:freegram/widgets/island_popup.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// List of possible interests for user profile
const List<String> _possibleInterests = [
  'Photography',
  'Traveling',
  'Hiking',
  'Reading',
  'Gaming',
  'Cooking',
  'Movies',
  'Music',
  'Art',
  'Sports',
  'Yoga',
  'Coding',
  'Writing',
  'Dancing',
  'Gardening',
  'Fashion',
  'Fitness',
  'History',
];

/// Maximum number of interests a user can select
const int _maxInterests = 5;

/// Maximum character length for bio
const int _maxBioLength = 150;

/// Edit Profile Screen - Allows users to update their profile information
///
/// Features:
/// - Profile picture upload with progress tracking
/// - Required field validation (username, age, gender, country)
/// - Interest selection (max 5)
/// - Bio with character counter
/// - Nearby status customization
/// - Prevents back navigation when completing required profile
class EditProfileScreen extends StatelessWidget {
  final Map<String, dynamic> currentUserData;
  final bool isCompletingProfile;

  const EditProfileScreen({
    super.key,
    required this.currentUserData,
    this.isCompletingProfile = false,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 SCREEN: edit_profile_screen.dart');
    return BlocProvider(
      create: (context) => ProfileBloc(
        userRepository: locator<UserRepository>(),
      ),
      child: _EditProfileView(
        currentUserData: currentUserData,
        isCompletingProfile: isCompletingProfile,
      ),
    );
  }
}

class _EditProfileView extends StatefulWidget {
  final Map<String, dynamic> currentUserData;
  final bool isCompletingProfile;

  const _EditProfileView({
    required this.currentUserData,
    required this.isCompletingProfile,
  });

  @override
  State<_EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<_EditProfileView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _nearbyStatusController;
  late TextEditingController _nearbyStatusEmojiController;

  int? _selectedAge;
  String? _selectedCountry;
  String? _selectedGender;
  List<String> _selectedInterests = [];

  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<int> _ages = List<int>.generate(83, (i) => i + 18); // Ages 18-100

  @override
  void initState() {
    super.initState();
    debugPrint(
      "EditProfileScreen: Initializing for user ${widget.currentUserData['username']}",
    );

    // Initialize controllers with existing data
    _usernameController = TextEditingController(
      text: widget.currentUserData['username'] ?? '',
    );
    _bioController = TextEditingController(
      text: widget.currentUserData['bio'] ?? '',
    );
    _nearbyStatusController = TextEditingController(
      text: widget.currentUserData['nearbyStatusMessage'] ?? '',
    );
    _nearbyStatusEmojiController = TextEditingController(
      text: widget.currentUserData['nearbyStatusEmoji'] ?? '',
    );

    // Initialize dropdown/chip selections
    _selectedAge = widget.currentUserData['age'] == 0
        ? null
        : widget.currentUserData['age'];
    _selectedCountry = widget.currentUserData['country']?.isEmpty ?? true
        ? null
        : widget.currentUserData['country'];
    _selectedGender = widget.currentUserData['gender']?.isEmpty ?? true
        ? null
        : widget.currentUserData['gender'];
    _selectedInterests =
        List<String>.from(widget.currentUserData['interests'] ?? []);
  }

  @override
  void dispose() {
    // CRITICAL: Dispose all text controllers
    _usernameController.dispose();
    _bioController.dispose();
    _nearbyStatusController.dispose();
    _nearbyStatusEmojiController.dispose();
    // CRITICAL: Clear image file reference to free memory
    _imageFile = null;
    super.dispose();
  }

  /// Show image source selection bottom sheet
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
              // Drag handle
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
        // Check camera permission if needed
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
          imageQuality: 70, // Consistent with chat screen
          maxWidth: 1024, // Limit dimensions for performance
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
          // Validate file size (max 5 MB)
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

  /// Validate and submit profile update
  void _updateProfile() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validation for country when completing profile
    if (widget.isCompletingProfile && _selectedCountry == null) {
      showIslandPopup(
        context: context,
        message: 'Please select your country',
        icon: Icons.error_outline,
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      showIslandPopup(
        context: context,
        message: 'Error: You are not logged in',
        icon: Icons.error_outline,
      );
      return;
    }

    // Prepare update data
    final Map<String, dynamic> updatedData = {
      'username': _usernameController.text.trim(),
      'bio': _bioController.text.trim(),
      'age': _selectedAge,
      'country': _selectedCountry,
      'gender': _selectedGender,
      'interests': _selectedInterests,
      'nearbyStatusMessage': _nearbyStatusController.text.trim(),
      'nearbyStatusEmoji': _nearbyStatusEmojiController.text.trim(),
    };

    // Increment nearbyDataVersion if status or emoji changed
    if (updatedData['nearbyStatusMessage'] !=
            widget.currentUserData['nearbyStatusMessage'] ||
        updatedData['nearbyStatusEmoji'] !=
            widget.currentUserData['nearbyStatusEmoji']) {
      updatedData['nearbyDataVersion'] = FieldValue.increment(1);
    }

    // Dispatch update event
    context.read<ProfileBloc>().add(ProfileUpdateEvent(
          userId: currentUser.uid,
          updatedData: updatedData,
          imageFile: _imageFile,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent back navigation when completing required profile
      onWillPop: () async => !widget.isCompletingProfile,
      child: Scaffold(
        appBar: FreegramAppBar(
          title:
              widget.isCompletingProfile ? 'Complete Profile' : 'Edit Profile',
          showBackButton: true,
          // Custom leading to handle conditional back button
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: DesignTokens.iconSM),
            tooltip: widget.isCompletingProfile ? 'Disabled' : 'Back',
            onPressed: widget.isCompletingProfile
                ? null // Disabled when completing profile
                : () => Navigator.of(context).pop(),
          ),
          actions: [
            BlocBuilder<ProfileBloc, ProfileState>(
              builder: (context, state) {
                final isLoading =
                    state is ProfileLoading || state is ProfileImageUploading;

                if (isLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(DesignTokens.spaceMD),
                    child: AppProgressIndicator(
                      size: DesignTokens.iconSM,
                      strokeWidth: 2,
                    ),
                  );
                }

                return AppIconButton(
                  icon: Icons.check,
                  tooltip: 'Save Changes',
                  onPressed: _updateProfile,
                );
              },
            ),
          ],
        ),
        resizeToAvoidBottomInset: true,
        body: KeyboardSafeArea(
          child: BlocListener<ProfileBloc, ProfileState>(
            listener: (context, state) {
              if (state is ProfileImageUploading) {
                // Show upload progress
                final percentage = (state.progress * 100).toInt();
                if (percentage < 100) {
                  showIslandPopup(
                    context: context,
                    message: 'Uploading image... $percentage%',
                    icon: Icons.cloud_upload_outlined,
                  );
                }
              }

              if (state is ProfileUpdateSuccess) {
                showIslandPopup(
                  context: context,
                  message: 'Profile updated successfully!',
                  icon: Icons.check_circle_outline,
                );

                // Mark profile as complete for this user
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null && widget.isCompletingProfile) {
                  final settingsBox = Hive.box('settings');
                  final userProfileKey = 'profileComplete_${currentUser.uid}';
                  settingsBox.put(userProfileKey, true);
                  debugPrint(
                    "Profile marked as complete for user ${currentUser.uid}",
                  );
                }

                // Navigate based on context
                if (widget.isCompletingProfile) {
                  // Replace entire stack with MainScreen
                  locator<NavigationService>().navigateTo(
                    const MainScreen(),
                    clearStack: true,
                  );
                } else if (locator<NavigationService>().navigator?.canPop() ??
                    false) {
                  Navigator.of(context).pop();
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
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(DesignTokens.spaceXL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome message for new users
                    if (widget.isCompletingProfile) ...[
                      Text(
                        'Welcome! Please provide a few more details to get started.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.black54),
                      ),
                      const SizedBox(height: DesignTokens.spaceXL),
                    ],

                    // Profile picture
                    _buildProfilePicture(),
                    const SizedBox(height: DesignTokens.spaceXL),

                    // Public profile section
                    _buildPublicProfileSection(),
                    const SizedBox(height: DesignTokens.spaceXL),

                    // Interests section
                    _buildInterestsSection(),

                    const Divider(height: 48),

                    // Nearby profile section
                    _buildNearbyProfileSection(),

                    const SizedBox(height: DesignTokens.spaceXL),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build profile picture section with upload functionality
  Widget _buildProfilePicture() {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        final isUploading = state is ProfileImageUploading;

        return Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: isUploading ? null : _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _imageFile != null
                          ? (kIsWeb
                                  ? NetworkImage(_imageFile!.path)
                                  : FileImage(File(_imageFile!.path)))
                              as ImageProvider
                          : (widget.currentUserData['photoUrl'] != null &&
                                  widget.currentUserData['photoUrl'].isNotEmpty
                              ? NetworkImage(widget.currentUserData['photoUrl'])
                              : null),
                      child: _buildAvatarContent(isUploading, state),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spaceSM),
              Text(
                isUploading ? 'Uploading...' : 'Tap to change photo',
                style: TextStyle(
                  color: isUploading ? Colors.orange : Colors.blue,
                  fontWeight: isUploading ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build avatar content (icon or progress indicator)
  Widget? _buildAvatarContent(bool isUploading, ProfileState state) {
    if (isUploading) {
      // Show upload progress
      final progress = state is ProfileImageUploading ? state.progress : 0.0;
      return AppProgressIndicator(
        value: progress,
        strokeWidth: 3,
        backgroundColor: Colors.white.withOpacity(0.3),
        color: Colors.white,
      );
    }

    // Show camera icon if no image
    if (_imageFile == null &&
        (widget.currentUserData['photoUrl'] == null ||
            widget.currentUserData['photoUrl'].isEmpty)) {
      return Icon(Icons.camera_alt, size: 60, color: Colors.grey[400]);
    }

    return null;
  }

  /// Build public profile section
  Widget _buildPublicProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Public Profile",
          style: TextStyle(
              fontSize: DesignTokens.fontSizeLG, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: DesignTokens.spaceMD),

        // Username field
        TextFormField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'Username',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Please enter a username'
              : null,
        ),
        const SizedBox(height: DesignTokens.spaceMD),

        // Bio field with character counter
        TextFormField(
          controller: _bioController,
          decoration: const InputDecoration(
            labelText: 'Bio',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.info_outline),
            helperText: 'Tell others about yourself',
          ),
          maxLines: 3,
          maxLength: _maxBioLength,
        ),
        const SizedBox(height: DesignTokens.spaceMD),

        // Age dropdown
        DropdownButtonFormField<int>(
          initialValue: _selectedAge,
          decoration: const InputDecoration(
            labelText: 'Age',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.cake_outlined),
          ),
          items: _ages
              .map((int value) => DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString()),
                  ))
              .toList(),
          onChanged: (newValue) => setState(() => _selectedAge = newValue),
          validator: (value) => value == null ? 'Please select your age' : null,
        ),
        const SizedBox(height: DesignTokens.spaceMD),

        // Country picker
        InkWell(
          onTap: () {
            showCountryPicker(
              context: context,
              showPhoneCode: false,
              onSelect: (Country country) {
                setState(() {
                  _selectedCountry = country.name;
                });
              },
            );
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Country',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.public),
              suffixIcon: const Icon(Icons.arrow_drop_down),
              hintText: 'Tap to select your country',
              errorText: widget.isCompletingProfile && _selectedCountry == null
                  ? 'Please select your country'
                  : null,
            ),
            child: Text(
              _selectedCountry ?? 'Select your country',
              style: TextStyle(
                color: _selectedCountry == null ? Colors.grey : Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.spaceMD),

        // Gender dropdown
        DropdownButtonFormField<String>(
          initialValue: _selectedGender,
          decoration: const InputDecoration(
            labelText: 'Gender',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.wc_outlined),
          ),
          items: _genders
              .map((String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ))
              .toList(),
          onChanged: (newValue) => setState(() => _selectedGender = newValue),
          validator: (value) =>
              value == null ? 'Please select your gender' : null,
        ),
      ],
    );
  }

  /// Build interests selection section
  Widget _buildInterestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Your Interests",
              style: TextStyle(
                  fontSize: DesignTokens.fontSizeLG,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              '${_selectedInterests.length}/$_maxInterests',
              style: TextStyle(
                color: _selectedInterests.length >= _maxInterests
                    ? Colors.orange
                    : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spaceSM),
        Wrap(
          spacing: DesignTokens.spaceSM,
          runSpacing: DesignTokens.spaceSM,
          children: _possibleInterests.map((interest) {
            final isSelected = _selectedInterests.contains(interest);
            return FilterChip(
              label: Text(interest),
              selected: isSelected,
              selectedColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.2),
              checkmarkColor: Theme.of(context).colorScheme.primary,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    if (_selectedInterests.length >= _maxInterests) {
                      showIslandPopup(
                        context: context,
                        message: 'Maximum $_maxInterests interests allowed',
                        icon: Icons.info_outline,
                      );
                    } else {
                      _selectedInterests.add(interest);
                    }
                  } else {
                    _selectedInterests.remove(interest);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Build nearby profile section
  Widget _buildNearbyProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Nearby Profile",
          style: TextStyle(
              fontSize: DesignTokens.fontSizeLG, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: DesignTokens.spaceSM),
        const Text(
          "This is only shown to users you discover via Sonar.",
          style:
              TextStyle(color: Colors.grey, fontSize: DesignTokens.fontSizeSM),
        ),
        const SizedBox(height: DesignTokens.spaceMD),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _nearbyStatusController,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Status Message',
                  border: OutlineInputBorder(),
                  counterText: "",
                ),
              ),
            ),
            const SizedBox(width: DesignTokens.spaceSM),
            SizedBox(
              width: 80,
              child: TextFormField(
                controller: _nearbyStatusEmojiController,
                maxLength: 2,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Emoji',
                  border: OutlineInputBorder(),
                  counterText: "",
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
