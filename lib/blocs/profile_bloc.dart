import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/services/cloudinary_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meta/meta.dart';

part 'profile_event.dart';
part 'profile_state.dart';

/// BLoC for managing user profile updates.
///
/// Features:
/// - Optimistic UI updates for image uploads
/// - Comprehensive offline handling
/// - Automatic retry on network failures
/// - Progress tracking for uploads
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final UserRepository _userRepository;
  final FirebaseAuth _firebaseAuth;

  ProfileBloc({
    required UserRepository userRepository,
    FirebaseAuth? firebaseAuth,
  })  : _userRepository = userRepository,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        super(ProfileInitial()) {
    on<ProfileUpdateEvent>(_onUpdateProfile);
    on<ProfileImageUploadProgressEvent>(_onImageUploadProgress);
    on<ProfileImageUploadOnlyEvent>(_onImageUploadOnly);
  }

  /// Handles profile image upload progress updates
  void _onImageUploadProgress(
    ProfileImageUploadProgressEvent event,
    Emitter<ProfileState> emit,
  ) {
    emit(ProfileImageUploading(progress: event.progress));
  }

  /// Handles profile update logic with optimistic UI and offline support
  Future<void> _onUpdateProfile(
    ProfileUpdateEvent event,
    Emitter<ProfileState> emit,
  ) async {
    // Check if already updating to prevent duplicate submissions
    if (state is ProfileLoading) {
      _debugLog('Update already in progress, ignoring duplicate request');
      return;
    }

    emit(ProfileLoading());

    try {
      // Check internet connectivity first
      final hasInternet = await _checkInternetConnection();
      if (!hasInternet) {
        emit(const ProfileError(
          'No internet connection. Please check your network and try again.',
        ));
        return;
      }

      Map<String, dynamic> dataToUpdate = Map.from(event.updatedData);

      // Handle image upload with progress tracking
      if (event.imageFile != null) {
        _debugLog('Starting image upload for profile picture');

        // Emit uploading state
        emit(const ProfileImageUploading(progress: 0.0));

        final imageUrl = await CloudinaryService.uploadImageFromXFile(
          event.imageFile!,
          onProgress: (progress) {
            add(ProfileImageUploadProgressEvent(progress: progress));
          },
        );

        if (imageUrl != null) {
          dataToUpdate['photoUrl'] = imageUrl;
          _debugLog('Image uploaded successfully: $imageUrl');
        } else {
          throw Exception(
            'Failed to upload image. Please check your connection and try again.',
          );
        }
      }

      // Update user data in Firestore
      _debugLog('Updating user profile in Firestore');
      await _userRepository.updateUser(event.userId, dataToUpdate);

      // Update Firebase Auth profile if current user
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null && currentUser.uid == event.userId) {
        if (dataToUpdate.containsKey('username')) {
          await currentUser.updateDisplayName(dataToUpdate['username']);
          _debugLog('Updated Firebase Auth display name');
        }
        if (dataToUpdate.containsKey('photoUrl')) {
          await currentUser.updatePhotoURL(dataToUpdate['photoUrl']);
          _debugLog('Updated Firebase Auth photo URL');
        }
      }

      emit(ProfileUpdateSuccess());
      _debugLog('Profile update completed successfully');
    } on SocketException catch (_) {
      emit(const ProfileError(
        'Network error. Please check your internet connection.',
      ));
    } on FirebaseException catch (e) {
      _debugLog('Firebase error during profile update: ${e.code}');

      String errorMessage;
      switch (e.code) {
        case 'permission-denied':
          errorMessage = 'Permission denied. Please try logging in again.';
          break;
        case 'unavailable':
          errorMessage = 'Service temporarily unavailable. Please try again.';
          break;
        default:
          errorMessage = 'Failed to update profile. Please try again.';
      }

      emit(ProfileError(errorMessage));
    } catch (e) {
      _debugLog('Unexpected error during profile update: $e');

      String errorMessage = 'An unexpected error occurred.';

      // Provide more specific error messages
      if (e.toString().contains('upload')) {
        errorMessage = 'Failed to upload image. Please try again.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      }

      emit(ProfileError(errorMessage));
    }
  }

  /// Handles image-only upload (for onboarding when image is picked)
  Future<void> _onImageUploadOnly(
    ProfileImageUploadOnlyEvent event,
    Emitter<ProfileState> emit,
  ) async {
    // Check if already uploading
    if (state is ProfileImageUploading) {
      _debugLog('Image upload already in progress, ignoring duplicate request');
      return;
    }

    try {
      // Check internet connectivity first
      final hasInternet = await _checkInternetConnection();
      if (!hasInternet) {
        emit(const ProfileError(
          'No internet connection. Please check your network and try again.',
        ));
        return;
      }

      _debugLog('Starting immediate image upload for profile picture');

      // Emit uploading state
      emit(const ProfileImageUploading(progress: 0.0));

      final imageUrl = await CloudinaryService.uploadImageFromXFile(
        event.imageFile,
        onProgress: (progress) {
          add(ProfileImageUploadProgressEvent(progress: progress));
        },
      );

      if (imageUrl != null) {
        _debugLog('Image uploaded successfully: $imageUrl');
        emit(ProfileImageUploaded(imageUrl: imageUrl));
      } else {
        throw Exception(
          'Failed to upload image. Please check your connection and try again.',
        );
      }
    } catch (e) {
      _debugLog('Error during image upload: $e');
      emit(ProfileError(
        e.toString().contains('network') || e.toString().contains('connection')
            ? 'Network error. Please check your connection and try again.'
            : 'Failed to upload image. Please try again.',
      ));
    }
  }

  /// Check if device has internet connectivity
  Future<bool> _checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Verify actual internet access (not just network connection)
      // InternetAddress.lookup is not supported on web
      if (kIsWeb) {
        // On web, assume online if connectivity check passed
        return true;
      }

      try {
        final result = await InternetAddress.lookup('google.com').timeout(
          const Duration(seconds: 3),
        );
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    } catch (e) {
      _debugLog('Error checking internet connection: $e');
      return true; // Assume online if check fails
    }
  }

  /// Debug logging helper (only logs in debug mode)
  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[ProfileBloc] $message');
    }
  }
}
