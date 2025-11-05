// lib/models/text_overlay_model.dart

import 'package:equatable/equatable.dart';

/// Model for text overlay on stories
class TextOverlay extends Equatable {
  final String text;
  final double x; // 0-1 normalized position
  final double y; // 0-1 normalized position
  final double fontSize;
  final String color; // Hex color string
  final String style; // 'bold' | 'outline' | 'neon'
  final double rotation; // Rotation angle in degrees

  const TextOverlay({
    required this.text,
    required this.x,
    required this.y,
    required this.fontSize,
    required this.color,
    required this.style,
    this.rotation = 0.0,
  });

  factory TextOverlay.fromMap(Map<String, dynamic> map) {
    return TextOverlay(
      text: map['text'] ?? '',
      x: (map['x'] ?? 0.5).toDouble(),
      y: (map['y'] ?? 0.5).toDouble(),
      fontSize: (map['fontSize'] ?? 24.0).toDouble(),
      color: map['color'] ?? '#FFFFFF',
      style: map['style'] ?? 'bold',
      rotation: (map['rotation'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'x': x,
      'y': y,
      'fontSize': fontSize,
      'color': color,
      'style': style,
      'rotation': rotation,
    };
  }

  TextOverlay copyWith({
    String? text,
    double? x,
    double? y,
    double? fontSize,
    String? color,
    String? style,
    double? rotation,
  }) {
    return TextOverlay(
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      style: style ?? this.style,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  List<Object?> get props => [text, x, y, fontSize, color, style, rotation];
}
