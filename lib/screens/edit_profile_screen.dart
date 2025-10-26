// lib/screens/edit_profile_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart'; // Keep for FieldValue
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/profile_bloc.dart'; // Keep ProfileBloc
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/user_repository.dart'; // Keep UserRepository
import 'package:freegram/screens/main_screen.dart'; // Keep for navigation on completion
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

// Possible interests list remains the same
const List<String> _possibleInterests = [
  'Photography', 'Traveling', 'Hiking', 'Reading', 'Gaming', 'Cooking',
  'Movies', 'Music', 'Art', 'Sports', 'Yoga', 'Coding', 'Writing',
  'Dancing', 'Gardening', 'Fashion', 'Fitness', 'History',
];

// Keep StatelessWidget wrapper for BlocProvider
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
    return BlocProvider(
      create: (context) => ProfileBloc(
        userRepository: locator<UserRepository>(), // Provide repository
      ),
      child: _EditProfileView( // Use the StatefulWidget
        currentUserData: currentUserData,
        isCompletingProfile: isCompletingProfile,
      ),
    );
  }
}

// Keep StatefulWidget for managing form state
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

  // Keep gender and age lists
  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<int> _ages = List<int>.generate(83, (i) => i + 18); // Ages 18 to 100

  @override
  void initState() {
    super.initState();
    debugPrint("EditProfileScreen: initState CALLED for user: ${widget.currentUserData['username']}");

    // Initialize controllers with existing data
    _usernameController = TextEditingController(text: widget.currentUserData['username'] ?? '');
    _bioController = TextEditingController(text: widget.currentUserData['bio'] ?? '');
    _nearbyStatusController = TextEditingController(text: widget.currentUserData['nearbyStatusMessage'] ?? '');
    _nearbyStatusEmojiController = TextEditingController(text: widget.currentUserData['nearbyStatusEmoji'] ?? '');

    // Initialize dropdown/chip selections
    _selectedAge = widget.currentUserData['age'] == 0 ? null : widget.currentUserData['age'];
    _selectedCountry = widget.currentUserData['country']?.isEmpty ?? true ? null : widget.currentUserData['country'];
    _selectedGender = widget.currentUserData['gender']?.isEmpty ?? true ? null : widget.currentUserData['gender'];
    _selectedInterests = List<String>.from(widget.currentUserData['interests'] ?? []);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _nearbyStatusController.dispose();
    _nearbyStatusEmojiController.dispose();
    super.dispose();
  }

  // _pickImage with proper error handling
  Future<void> _pickImage() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
            ],
          ),
        ),
      );

      if (source != null) {
        // Check permissions before picking image
        if (source == ImageSource.camera) {
          // Check if camera permission is already granted to avoid unnecessary requests
          final permissionStatus = await Permission.camera.status;
          if (!permissionStatus.isGranted) {
            final permission = await Permission.camera.request();
            if (!permission.isGranted) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Camera permission is required to take photos'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              return;
            }
          }
        }

        final XFile? pickedFile = await _picker.pickImage(
          source: source, 
          imageQuality: 80,
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint('Image picker timed out');
            return null;
          },
        );
        
        if (pickedFile != null && mounted) {
          setState(() {
            _imageFile = pickedFile;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  // _updateProfile remains largely the same, but ensures deleted fields aren't included
  void _updateProfile() {
    if (!_formKey.currentState!.validate()) {
      return; // Validation failed
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: You are not logged in.')));
      return;
    }

    // Prepare data map with only valid fields
    final Map<String, dynamic> updatedData = {
      'username': _usernameController.text.trim(),
      'bio': _bioController.text.trim(),
      'age': _selectedAge, // Nullable int
      'country': _selectedCountry, // Nullable String
      'gender': _selectedGender, // Nullable String
      'interests': _selectedInterests, // List<String>
      'nearbyStatusMessage': _nearbyStatusController.text.trim(),
      'nearbyStatusEmoji': _nearbyStatusEmojiController.text.trim(),
    };

    // Increment nearbyDataVersion if status or emoji changed
    if (updatedData['nearbyStatusMessage'] != widget.currentUserData['nearbyStatusMessage'] ||
        updatedData['nearbyStatusEmoji'] != widget.currentUserData['nearbyStatusEmoji']) {
      updatedData['nearbyDataVersion'] = FieldValue.increment(1);
    }

    // Remove null values before sending to Firestore if desired,
    // though updateUser in repository should handle it.
    // updatedData.removeWhere((key, value) => value == null);

    // Dispatch event to ProfileBloc
    context.read<ProfileBloc>().add(ProfileUpdateEvent(
      userId: currentUser.uid,
      updatedData: updatedData,
      imageFile: _imageFile, // Pass image file if selected
    ));
  }


  @override
  Widget build(BuildContext context) {
    debugPrint("EditProfileScreen: build CALLED for user: ${widget.currentUserData['username']}");
    return Scaffold(
      // Listen for Bloc state changes (success/error)
      body: BlocListener<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileUpdateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
            );
            // Navigate differently based on context
            if (widget.isCompletingProfile) {
              // Replace entire stack with MainScreen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MainScreen()),
                    (Route<dynamic> route) => false, // Remove all previous routes
              );
            } else if (Navigator.canPop(context)) {
              Navigator.of(context).pop(); // Just pop if editing existing profile
            }
          }
          if (state is ProfileError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${state.message}'), backgroundColor: Colors.red),
            );
          }
        },
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.isCompletingProfile ? 'Complete Your Profile' : 'Edit Profile',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  BlocBuilder<ProfileBloc, ProfileState>(
                    builder: (context, state) {
                      if (state is ProfileLoading) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                          ),
                        );
                      }
                      return IconButton(
                        icon: const Icon(Icons.check, color: Colors.blue),
                        onPressed: _updateProfile,
                        tooltip: 'Save Changes',
                      );
                    },
                  ),
                ],
              ),
            ),
            // Form content
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                // Welcome message if completing profile
                if (widget.isCompletingProfile)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Text(
                      'Welcome! Please provide a few more details to get started.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black54),
                    ),
                  ),

                // Profile Picture Picker
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _imageFile != null
                          ? (kIsWeb ? NetworkImage(_imageFile!.path) : FileImage(File(_imageFile!.path))) as ImageProvider
                          : (widget.currentUserData['photoUrl'] != null && widget.currentUserData['photoUrl'].isNotEmpty
                          ? NetworkImage(widget.currentUserData['photoUrl'])
                          : null),
                      child: (_imageFile == null && (widget.currentUserData['photoUrl'] == null || widget.currentUserData['photoUrl'].isEmpty))
                          ? Icon(Icons.camera_alt, size: 60, color: Colors.grey[400])
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(child: Text("Tap to change photo", style: TextStyle(color: Colors.blue))),
                const SizedBox(height: 24),

                // Public Profile Section
                const Text("Public Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a username' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bioController,
                  decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedAge,
                  decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                  items: _ages.map((int value) => DropdownMenuItem<int>(value: value, child: Text(value.toString()))).toList(),
                  onChanged: (newValue) => setState(() => _selectedAge = newValue),
                  validator: (value) => value == null ? 'Please select your age' : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    showCountryPicker(
                      context: context,
                      showPhoneCode: false, // Don't show phone code
                      onSelect: (Country country) {
                        setState(() { _selectedCountry = country.name; });
                      },
                    );
                  },
                  child: InputDecorator( // Use InputDecorator for consistent styling
                    decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
                    child: Text(_selectedCountry ?? 'Select your country'),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                  items: _genders.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                  onChanged: (newValue) => setState(() => _selectedGender = newValue),
                  validator: (value) => value == null ? 'Please select your gender' : null,
                ),
                const SizedBox(height: 24),

                // Interests Section
                const Text("Your Interests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0, runSpacing: 4.0,
                  children: _possibleInterests.map((interest) {
                    final isSelected = _selectedInterests.contains(interest);
                    return FilterChip(
                      label: Text(interest),
                      selected: isSelected,
                      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2), // Use theme color
                      checkmarkColor: Theme.of(context).colorScheme.primary, // Use theme color
                      onSelected: (selected) {
                        setState(() {
                          if (selected) { _selectedInterests.add(interest); }
                          else { _selectedInterests.remove(interest); }
                        });
                      },
                    );
                  }).toList(),
                ),
                const Divider(height: 48),

                // Nearby Profile Section
                const Text("Nearby Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text("This is only shown to users you discover via Sonar.", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nearbyStatusController,
                        maxLength: 50, // Limit status length
                        decoration: const InputDecoration(
                          labelText: 'Status Message',
                          border: OutlineInputBorder(),
                          counterText: "", // Hide default counter
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: _nearbyStatusEmojiController,
                        maxLength: 2, // Allow for compound emojis like flags
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'Emoji',
                          border: OutlineInputBorder(),
                          counterText: "", // Hide default counter
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32), // Add padding at the bottom
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}