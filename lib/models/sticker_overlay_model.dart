// lib/models/sticker_overlay_model.dart

import 'package:equatable/equatable.dart';

/// Model for sticker overlay on stories
class StickerOverlay extends Equatable {
  final String stickerId;
  final double x; // 0-1 normalized position
  final double y; // 0-1 normalized position
  final double scale; // Scale factor (default 1.0)
  final double rotation; // Rotation angle in degrees

  const StickerOverlay({
    required this.stickerId,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  factory StickerOverlay.fromMap(Map<String, dynamic> map) {
    return StickerOverlay(
      stickerId: map['stickerId'] ?? '',
      x: (map['x'] ?? 0.5).toDouble(),
      y: (map['y'] ?? 0.5).toDouble(),
      scale: (map['scale'] ?? 1.0).toDouble(),
      rotation: (map['rotation'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stickerId': stickerId,
      'x': x,
      'y': y,
      'scale': scale,
      'rotation': rotation,
    };
  }

  StickerOverlay copyWith({
    String? stickerId,
    double? x,
    double? y,
    double? scale,
    double? rotation,
  }) {
    return StickerOverlay(
      stickerId: stickerId ?? this.stickerId,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  List<Object?> get props => [stickerId, x, y, scale, rotation];
}
