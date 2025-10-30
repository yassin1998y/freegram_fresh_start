// lib/services/network_quality_service.dart
// Network Quality Detection Service for Adaptive Loading
// Improvement #33 - Add network-aware loading

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum NetworkQuality {
  excellent, // WiFi or fast mobile
  good, // 4G
  fair, // 3G
  poor, // 2G or slow
  offline, // No connection
}

class NetworkQualityService {
  static final NetworkQualityService _instance =
      NetworkQualityService._internal();
  factory NetworkQualityService() => _instance;
  NetworkQualityService._internal();

  final _connectivity = Connectivity();
  final _qualityController = StreamController<NetworkQuality>.broadcast();
  NetworkQuality _currentQuality = NetworkQuality.good;
  StreamSubscription? _connectivitySubscription;

  Stream<NetworkQuality> get qualityStream => _qualityController.stream;
  NetworkQuality get currentQuality => _currentQuality;

  Future<void> init() async {
    await _checkConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (_) => _checkConnectivity(),
    );
  }

  Future<void> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();

    NetworkQuality quality;

    switch (result) {
      case ConnectivityResult.wifi:
        quality = NetworkQuality.excellent;
        break;
      case ConnectivityResult.ethernet:
        quality = NetworkQuality.excellent;
        break;
      case ConnectivityResult.mobile:
        // In a real app, you'd check the mobile data type (4G, 3G, etc.)
        // For now, assume 4G for mobile
        quality = NetworkQuality.good;
        break;
      case ConnectivityResult.none:
        quality = NetworkQuality.offline;
        break;
      default:
        quality = NetworkQuality.fair;
    }

    if (_currentQuality != quality) {
      _currentQuality = quality;
      _qualityController.add(quality);
      debugPrint('Network quality changed to: $quality');
    }
  }

  // Get recommended image quality based on network
  int getRecommendedImageQuality() {
    switch (_currentQuality) {
      case NetworkQuality.excellent:
        return 90;
      case NetworkQuality.good:
        return 75;
      case NetworkQuality.fair:
        return 60;
      case NetworkQuality.poor:
        return 40;
      case NetworkQuality.offline:
        return 40; // For cached images
    }
  }

  // Get recommended cache dimensions
  (int width, int height) getRecommendedCacheDimensions() {
    switch (_currentQuality) {
      case NetworkQuality.excellent:
        return (1200, 1200);
      case NetworkQuality.good:
        return (800, 800);
      case NetworkQuality.fair:
        return (600, 600);
      case NetworkQuality.poor:
        return (400, 400);
      case NetworkQuality.offline:
        return (400, 400);
    }
  }

  // Should prefetch images?
  bool shouldPrefetchImages() {
    return _currentQuality == NetworkQuality.excellent;
  }

  // Should auto-download media?
  bool shouldAutoDownloadMedia() {
    return _currentQuality == NetworkQuality.excellent ||
        _currentQuality == NetworkQuality.good;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _qualityController.close();
  }
}









