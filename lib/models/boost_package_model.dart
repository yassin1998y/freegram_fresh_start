// lib/models/boost_package_model.dart

import 'package:equatable/equatable.dart';

/// Model for boost packages that users can purchase
class BoostPackageModel extends Equatable {
  final String packageId;
  final String name;
  final int duration; // Duration in days
  final int targetReach; // Estimated reach (e.g., 1000, 5000, 10000)
  final int price; // Price in coins

  const BoostPackageModel({
    required this.packageId,
    required this.name,
    required this.duration,
    required this.targetReach,
    required this.price,
  });

  factory BoostPackageModel.fromMap(Map<String, dynamic> map) {
    return BoostPackageModel(
      packageId: map['packageId'] ?? '',
      name: map['name'] ?? '',
      duration: map['duration'] ?? 0,
      targetReach: map['targetReach'] ?? 0,
      price: map['price'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageId': packageId,
      'name': name,
      'duration': duration,
      'targetReach': targetReach,
      'price': price,
    };
  }

  @override
  List<Object> get props => [packageId, name, duration, targetReach, price];

  /// Predefined boost packages
  static List<BoostPackageModel> getDefaultPackages() {
    return [
      const BoostPackageModel(
        packageId: 'boost_1day',
        name: '1 Day Boost',
        duration: 1,
        targetReach: 1000,
        price: 500,
      ),
      const BoostPackageModel(
        packageId: 'boost_3day',
        name: '3 Day Boost',
        duration: 3,
        targetReach: 3000,
        price: 1200,
      ),
      const BoostPackageModel(
        packageId: 'boost_7day',
        name: '7 Day Boost',
        duration: 7,
        targetReach: 10000,
        price: 2500,
      ),
    ];
  }
}

