import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum MediaType { image, video }

class Story extends Equatable {
  final String id;
  final String userId;
  final String mediaUrl;
  final MediaType mediaType;
  final DateTime timestamp;
  final List<String> viewers;

  const Story({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.mediaType,
    required this.timestamp,
    required this.viewers,
  });

  factory Story.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Story(
      id: doc.id,
      userId: data['userId'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      mediaType: MediaType.values.byName(data['mediaType'] ?? 'image'),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      viewers: List<String>.from(data['viewers'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'viewers': viewers,
    };
  }

  @override
  List<Object?> get props => [id, userId, mediaUrl, mediaType, timestamp, viewers];
}