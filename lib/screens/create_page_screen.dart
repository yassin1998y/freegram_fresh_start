// lib/screens/create_page_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/page_repository.dart';
import 'package:freegram/models/page_model.dart';
import 'package:freegram/services/cloudinary_service.dart';
import 'package:freegram/widgets/common/keyboard_safe_area.dart';
import 'package:freegram/screens/page_profile_screen.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';

class CreatePageScreen extends StatefulWidget {
  const CreatePageScreen({Key? key}) : super(key: key);

  @override
  State<CreatePageScreen> createState() => _CreatePageScreenState();
}

class _CreatePageScreenState extends State<CreatePageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _handleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _websiteController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  final PageRepository _pageRepository = locator<PageRepository>();
  final ImagePicker _imagePicker = ImagePicker();

  PageType _selectedPageType = PageType.community;
  XFile? _profileImage;
  XFile? _coverImage;
  bool _isCreating = false;
  bool _isCheckingHandle = false;
  String? _handleError;

  final List<String> _categories = [
    'Business',
    'Community',
    'Entertainment',
    'Education',
    'Sports',
    'Technology',
    'Health',
    'Food',
    'Travel',
    'Fashion',
    'Music',
    'Art',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _websiteController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _checkHandleAvailability() async {
    final handle = _handleController.text.trim().toLowerCase();
    if (handle.isEmpty) {
      setState(() => _handleError = null);
      return;
    }

    // Validate format
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(handle)) {
      setState(() {
        _handleError =
            'Handle can only contain lowercase letters, numbers, underscores, or hyphens';
      });
      return;
    }

    setState(() => _isCheckingHandle = true);

    try {
      final existingPage = await _pageRepository.getPageByHandle(handle);
      setState(() {
        _isCheckingHandle = false;
        _handleError =
            existingPage != null ? 'This handle is already taken' : null;
      });
    } catch (e) {
      setState(() {
        _isCheckingHandle = false;
        _handleError = 'Error checking handle availability';
      });
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _profileImage = image);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _coverImage = image);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _createPage() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_handleError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_handleError!)),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create a page')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Upload images
      String profileImageUrl = '';
      String? coverImageUrl;

      if (_profileImage != null) {
        final url =
            await CloudinaryService.uploadImageFromXFile(_profileImage!);
        if (url != null) {
          profileImageUrl = url;
        }
      }

      if (_coverImage != null) {
        final url = await CloudinaryService.uploadImageFromXFile(_coverImage!);
        if (url != null) {
          coverImageUrl = url;
        }
      }

      // Generate handle from name if not provided
      String handle = _handleController.text.trim().toLowerCase();
      if (handle.isEmpty) {
        handle = _nameController.text
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '')
            .substring(
                0,
                _nameController.text.length > 20
                    ? 20
                    : _nameController.text.length);
      }

      // Create page
      final pageId = await _pageRepository.createPage(
        ownerId: currentUser.uid,
        pageName: _nameController.text.trim(),
        pageHandle: handle.startsWith('@') ? handle.substring(1) : handle,
        pageType: _selectedPageType,
        category: _categoryController.text.trim(),
        description: _descriptionController.text.trim(),
        profileImageUrl: profileImageUrl,
        coverImageUrl: coverImageUrl,
        website: _websiteController.text.trim().isNotEmpty
            ? _websiteController.text.trim()
            : null,
        contactEmail: _contactEmailController.text.trim().isNotEmpty
            ? _contactEmailController.text.trim()
            : null,
        contactPhone: _contactPhoneController.text.trim().isNotEmpty
            ? _contactPhoneController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Page created successfully!'),
          ),
        );

        // Navigate to the new page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PageProfileScreen(pageId: pageId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Error creating page: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 SCREEN: create_page_screen.dart');
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Create Page'),
      ),
      body: _isCreating
          ? const Center(child: AppProgressIndicator())
          : KeyboardSafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile and Cover Images
                      Row(
                        children: [
                          // Profile Image
                          GestureDetector(
                            onTap: _pickProfileImage,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[300],
                                border:
                                    Border.all(color: Colors.grey, width: 2),
                              ),
                              child: _profileImage != null
                                  ? ClipOval(
                                      child: Image.file(
                                        File(_profileImage!.path),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return const Icon(Icons.person,
                                              size: 50);
                                        },
                                      ),
                                    )
                                  : const Icon(Icons.add_photo_alternate,
                                      size: 40),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Cover Image
                          Expanded(
                            child: GestureDetector(
                              onTap: _pickCoverImage,
                              child: Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.grey, width: 2),
                                ),
                                child: _coverImage != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(_coverImage!.path),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return const Center(
                                              child: Icon(
                                                  Icons.add_photo_alternate,
                                                  size: 40),
                                            );
                                          },
                                        ),
                                      )
                                    : const Center(
                                        child: Icon(Icons.add_photo_alternate,
                                            size: 40),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Page Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Page Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a page name';
                          }
                          if (value.length < 3) {
                            return 'Page name must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Page Handle
                      TextFormField(
                        controller: _handleController,
                        decoration: InputDecoration(
                          labelText: 'Page Handle (@handle)',
                          hintText: 'my-page',
                          border: const OutlineInputBorder(),
                          prefixText: '@',
                          suffixIcon: _isCheckingHandle
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: AppProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : null,
                          errorText: _handleError,
                        ),
                        onChanged: (_) {
                          // Debounce handle checking
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (mounted) {
                              _checkHandleAvailability();
                            }
                          });
                        },
                        textCapitalization: TextCapitalization.none,
                      ),
                      const SizedBox(height: 16),

                      // Page Type
                      DropdownButtonFormField<PageType>(
                        initialValue: _selectedPageType,
                        decoration: const InputDecoration(
                          labelText: 'Page Type *',
                          border: OutlineInputBorder(),
                        ),
                        items: PageType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                                type.toString().split('.').last.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedPageType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category
                      DropdownButtonFormField<String>(
                        initialValue: _categoryController.text.isEmpty
                            ? null
                            : _categoryController.text,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _categoryController.text = value;
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),

                      // Website
                      TextFormField(
                        controller: _websiteController,
                        decoration: const InputDecoration(
                          labelText: 'Website',
                          border: OutlineInputBorder(),
                          hintText: 'https://example.com',
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 16),

                      // Contact Email
                      TextFormField(
                        controller: _contactEmailController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Email',
                          border: OutlineInputBorder(),
                          hintText: 'contact@example.com',
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      // Contact Phone
                      TextFormField(
                        controller: _contactPhoneController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Phone',
                          border: OutlineInputBorder(),
                          hintText: '+1234567890',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 32),

                      // Create Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isCreating ? null : _createPage,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Create Page'),
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
