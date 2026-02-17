// lib/models/drawing_path_model.dart

import 'package:equatable/equatable.dart';

/// Model for drawing path on stories
class DrawingPath extends Equatable {
  final List<OffsetPoint> points;
  final String color; // Hex color string
  final double strokeWidth;

  const DrawingPath({
    required this.points,
    required this.color,
    this.strokeWidth = 5.0,
  });

  factory DrawingPath.fromMap(Map<String, dynamic> map) {
    final pointsList = map['points'] as List? ?? [];
    return DrawingPath(
      points: pointsList
          .map((p) => OffsetPoint.fromMap(p as Map<String, dynamic>))
          .toList(),
      color: map['color'] ?? '#FFFFFF',
      strokeWidth: (map['strokeWidth'] ?? 5.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'points': points.map((p) => p.toMap()).toList(),
      'color': color,
      'strokeWidth': strokeWidth,
    };
  }

  /// NEW: Optimized serialization for Hive/Drafts
  List<double> toCompressedList() {
    final list = <double>[];
    for (final point in points) {
      list.add(point.x);
      list.add(point.y);
    }
    return list;
  }

  factory DrawingPath.fromCompressed(
      List<double> compressed, String color, double strokeWidth) {
    final points = <OffsetPoint>[];
    for (int i = 0; i < compressed.length; i += 2) {
      if (i + 1 < compressed.length) {
        points.add(OffsetPoint(x: compressed[i], y: compressed[i + 1]));
      }
    }
    return DrawingPath(
      points: points,
      color: color,
      strokeWidth: strokeWidth,
    );
  }

  DrawingPath copyWith({
    List<OffsetPoint>? points,
    String? color,
    double? strokeWidth,
  }) {
    return DrawingPath(
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
    );
  }

  @override
  List<Object?> get props => [points, color, strokeWidth];
}

/// Model for a point in a drawing path
class OffsetPoint extends Equatable {
  final double x;
  final double y;

  const OffsetPoint({
    required this.x,
    required this.y,
  });

  factory OffsetPoint.fromMap(Map<String, dynamic> map) {
    return OffsetPoint(
      x: (map['x'] ?? 0.0).toDouble(),
      y: (map['y'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
    };
  }

  @override
  List<Object?> get props => [x, y];
}
