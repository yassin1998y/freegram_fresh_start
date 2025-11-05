// lib/models/ad_placeholder.dart

import 'package:equatable/equatable.dart';

/// Placeholder class to represent ad positions in the feed
/// This is used in the FeedBloc to mark positions where ads should be inserted
class AdPlaceholder extends Equatable {
  final String id;
  final int position; // Position in the feed (after N posts)

  const AdPlaceholder({
    required this.id,
    required this.position,
  });

  @override
  List<Object?> get props => [id, position];
}

