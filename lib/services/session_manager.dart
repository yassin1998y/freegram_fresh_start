import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/presence_manager.dart';
import 'package:freegram/services/sonar/bluetooth_service.dart';
import 'package:freegram/services/sonar/sonar_controller.dart';
import 'package:freegram/services/sync_manager.dart';
import 'package:freegram/services/loading_overlay_service.dart';

/// Manages the lifecycle of user-scoped services (Sonar, Sync, Presence)
/// This service is responsible for initializing and disposing services that depend on a logged-in user.
class SessionManager {
  // Private constructor
  SessionManager._();

  static final SessionManager _instance = SessionManager._();
  factory SessionManager() => _instance;

  SonarController? _sonarController;
  SyncManager? _syncManager;
  PresenceManager? _presenceManager;
  bool _isInitialized = false;
  bool _sonarShouldBeRunning = false;

  bool get isInitialized => _isInitialized;

  /// Initialize user session services
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🔄 SessionManager: Initializing session services...');

    try {
      if (!kIsWeb) {
        _sonarController = locator<SonarController>();
        _syncManager = locator<SyncManager>();
      }
      _presenceManager = locator<PresenceManager>();

      // Initialize presence manager
      await _presenceManager?.initialize();

      // Initialize Sonar user data
      if (!kIsWeb) {
        await _sonarController?.initializeUser();
      }

      _isInitialized = true;
      debugPrint('✅ SessionManager: Session services initialized');
    } catch (e) {
      debugPrint('❌ SessionManager: Initialization failed: $e');
      rethrow;
    }
  }

  /// Handle app lifecycle changes (Resume/Pause)
  void handleLifecycleChange(
      AppLifecycleState state, ConnectivityBloc connectivityBloc) {
    if (!_isInitialized || kIsWeb) return;

    debugPrint("🔄 SessionManager: AppLifecycleState changed to $state");

    if (state == AppLifecycleState.resumed) {
      _handleResume(connectivityBloc);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _handlePause();
    }
  }

  void _handleResume(ConnectivityBloc connectivityBloc) {
    // Trigger sync if online
    if (connectivityBloc.state is Online) {
      debugPrint(
          "🔄 SessionManager: App Resumed and Online - Triggering SyncManager");
      _syncManager?.processQueue();
    }

    // Restart Sonar if it was running
    if (_sonarShouldBeRunning) {
      debugPrint("🔄 SessionManager: App Resumed - Restarting Sonar...");
      _sonarController?.startSonar();
    }
  }

  void _handlePause() {
    // Stop Sonar and save state
    final currentStatus = BluetoothStatusService().currentStatus;
    if (currentStatus == NearbyStatus.scanning ||
        currentStatus == NearbyStatus.userFound) {
      debugPrint(
          "🔄 SessionManager: App Paused - Stopping Sonar (will restart on resume)");
      _sonarController?.stopSonar();
      _sonarShouldBeRunning = true;
    } else {
      _sonarShouldBeRunning = false;
    }
  }

  /// Check onboarding status and start background services if appropriate
  Future<void> checkOnboardingAndStartServices() async {
    if (!_isInitialized || kIsWeb) return;

    // Start Sonar automatically if appropriate
    // This logic was moved from MainScreenWrapper
    debugPrint("🔄 SessionManager: Checking to start Sonar...");

    // We assume user is initialized from initialize() call
    // Attempt to start Sonar
    await _sonarController?.startSonar();

    final currentStatus = BluetoothStatusService().currentStatus;
    if (currentStatus == NearbyStatus.scanning ||
        currentStatus == NearbyStatus.userFound) {
      _sonarShouldBeRunning = true;
      debugPrint("✅ SessionManager: Sonar started successfully");
    } else {
      _sonarShouldBeRunning = false;
      debugPrint(
          "ℹ️ SessionManager: Sonar did not start (Status: $currentStatus)");
    }
  }

  /// Dispose session services
  Future<void> dispose() async {
    debugPrint("🔄 SessionManager: Disposing session services...");

    // Hide loading overlay if showing
    try {
      final loadingOverlay = locator<LoadingOverlayService>();
      if (loadingOverlay.isShowing) {
        loadingOverlay.hide();
      }
    } catch (e) {
      // Ignore
    }

    // Stop Sonar (fire and forget)
    _sonarController?.stopSonar().catchError((e) {
      debugPrint("❌ SessionManager: Error stopping sonar: $e");
    });

    // Dispose PresenceManager (fire and forget)
    _presenceManager?.dispose().catchError((e) {
      debugPrint("❌ SessionManager: Error disposing PresenceManager: $e");
    });

    _isInitialized = false;
    _sonarController = null;
    _syncManager = null;
    _presenceManager = null;

    debugPrint("✅ SessionManager: Disposed");
  }
}
