// lib/utils/location_utils.dart

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility class for location-related calculations
class LocationUtils {
  /// Earth's radius in kilometers
  static const double earthRadiusKm = 6371.0;

  /// Calculate distance between two geographic points using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = (dLat / 2).sin() * (dLat / 2).sin() +
        _toRadians(lat1).cos() *
            _toRadians(lat2).cos() *
            (dLon / 2).sin() *
            (dLon / 2).sin();

    final c = 2 * a.sqrt().asin();
    return earthRadiusKm * c;
  }

  /// Calculate distance from user location to post location
  /// Returns distance in kilometers, or null if locations are invalid
  static double? calculateDistanceToPost(
    GeoPoint? userLocation,
    GeoPoint? postLocation,
  ) {
    if (userLocation == null || postLocation == null) {
      return null;
    }

    return calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      postLocation.latitude,
      postLocation.longitude,
    );
  }

  /// Format distance for display
  /// Returns formatted string like "1.2 km", "500 m", "0.5 km"
  static String formatDistance(double? distanceKm) {
    if (distanceKm == null) {
      return '';
    }

    if (distanceKm < 0.1) {
      // Less than 100 meters, show in meters
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    } else if (distanceKm < 1.0) {
      // Less than 1 km, show with 2 decimal places
      return '${(distanceKm * 1000).round()} m';
    } else if (distanceKm < 10) {
      // Less than 10 km, show with 1 decimal place
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      // 10 km or more, show as integer
      return '${distanceKm.round()} km';
    }
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * (3.141592653589793 / 180.0);
  }
}

/// Extension to add trigonometric functions to double
extension _Trigonometry on double {
  double sin() => math.sin(this);
  double cos() => math.cos(this);
  double asin() => math.asin(this);
  double sqrt() => math.sqrt(this);
}
