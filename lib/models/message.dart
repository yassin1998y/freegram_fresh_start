import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// Enum to represent the status of a message for the Optimistic UI.
enum MessageStatus { sending, sent, delivered, seen, error }

/// A type-safe model representing a single chat message.
class Message {
  final String id;
  final String? text;
  final String? imageUrl;
  final String? audioUrl;
  final Duration? audioDuration;
  final List<double>? waveform;
  final String senderId;
  final Timestamp? timestamp;
  final bool isEdited;
  final Map<String, String> reactions;

  // Reply information
  final String? replyToMessageId;
  final String? replyToMessageText;
  final String? replyToImageUrl;
  final String? replyToSender;

  // Story reply context (Facebook-style private story replies)
  final String? storyReplyId;
  final String? storyThumbnailUrl;
  final String? storyMediaUrl;
  final String? storyMediaType; // 'image' | 'video'
  final String? storyAuthorId;
  final String? storyAuthorUsername;

  // Gift information
  final bool isGiftMessage;
  final String? giftId;

  // Client-side status for Optimistic UI
  final MessageStatus status;

  Message({
    required this.id,
    this.text,
    this.imageUrl,
    required this.senderId,
    this.audioUrl,
    this.audioDuration,
    this.waveform,
    this.timestamp,
    this.isEdited = false,
    this.reactions = const {},
    this.replyToMessageId,
    this.replyToMessageText,
    this.replyToImageUrl,
    this.replyToSender,
    this.storyReplyId,
    this.storyThumbnailUrl,
    this.storyMediaUrl,
    this.storyMediaType,
    this.storyAuthorId,
    this.storyAuthorUsername,
    this.isGiftMessage = false,
    this.giftId,
    this.status = MessageStatus.sent, // Default to sent
  });

  bool get isAudio => audioUrl != null && audioUrl!.isNotEmpty;

  /// Creates a Message object from a Firestore document snapshot.
  factory Message.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message.fromMap(doc.id, data);
  }

  /// Creates a Message object from a raw Firestore map.
  factory Message.fromMap(String id, Map<String, dynamic> data) {
    final bool isSeen = data['isSeen'] ?? false;
    final bool isDelivered = data['isDelivered'] ?? false;

    MessageStatus currentStatus;
    if (isSeen) {
      currentStatus = MessageStatus.seen;
    } else if (isDelivered) {
      currentStatus = MessageStatus.delivered;
    } else {
      currentStatus = MessageStatus.sent;
    }

    final waveformData = data['waveform'];
    final List<double>? waveform = waveformData is List
        ? waveformData
            .where((value) => value is num)
            .map((value) => (value as num).toDouble())
            .toList()
        : null;

    return Message(
      id: id,
      text: data['text'],
      imageUrl: data['imageUrl'],
      audioUrl: data['audioUrl'],
      audioDuration: data['audioDurationMs'] != null
          ? Duration(milliseconds: data['audioDurationMs'] as int)
          : null,
      waveform: waveform,
      senderId: data['senderId'] ?? '',
      timestamp: data['timestamp'] as Timestamp?,
      isEdited: data['edited'] ?? false,
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      replyToMessageId: data['replyToMessageId'],
      replyToMessageText: data['replyToMessageText'],
      replyToImageUrl: data['replyToImageUrl'],
      replyToSender: data['replyToSender'],
      storyReplyId: data['storyReplyId'],
      storyThumbnailUrl: data['storyThumbnailUrl'],
      storyMediaUrl: data['storyMediaUrl'],
      storyMediaType: data['storyMediaType'],
      storyAuthorId: data['storyAuthorId'],
      storyAuthorUsername: data['storyAuthorUsername'],
      isGiftMessage: data['isGiftMessage'] ?? false,
      giftId: data['giftId'],
      status: currentStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'audioDurationMs': audioDuration?.inMilliseconds,
      if (waveform != null) 'waveform': waveform,
      'senderId': senderId,
      'timestamp': timestamp,
      'edited': isEdited,
      'reactions': reactions,
      'replyToMessageId': replyToMessageId,
      'replyToMessageText': replyToMessageText,
      'replyToImageUrl': replyToImageUrl,
      'replyToSender': replyToSender,
      'storyReplyId': storyReplyId,
      'storyThumbnailUrl': storyThumbnailUrl,
      'storyMediaUrl': storyMediaUrl,
      'storyMediaType': storyMediaType,
      'storyAuthorId': storyAuthorId,
      'storyAuthorUsername': storyAuthorUsername,
      'isGiftMessage': isGiftMessage,
      'giftId': giftId,
      'status': status.name,
    };
  }

  /// Creates a temporary, client-side message for the Optimistic UI.
  factory Message.optimistic({
    required String senderId,
    String? text,
    String? imageUrl,
    String? audioUrl,
    Duration? audioDuration,
    List<double>? waveform,
    String? replyToMessageId,
    String? replyToMessageText,
    String? replyToImageUrl,
    String? replyToSender,
    String? storyReplyId,
    String? storyThumbnailUrl,
    String? storyMediaUrl,
    String? storyMediaType,
    String? storyAuthorId,
    String? storyAuthorUsername,
  }) {
    return Message(
      id: const Uuid().v4(), // Generate a unique temporary ID
      senderId: senderId,
      text: text,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      audioDuration: audioDuration,
      waveform: waveform,
      timestamp: Timestamp.now(),
      status: MessageStatus.sending, // Set status to 'sending'
      replyToMessageId: replyToMessageId,
      replyToMessageText: replyToMessageText,
      replyToImageUrl: replyToImageUrl,
      replyToSender: replyToSender,
      storyReplyId: storyReplyId,
      storyThumbnailUrl: storyThumbnailUrl,
      storyMediaUrl: storyMediaUrl,
      storyMediaType: storyMediaType,
      storyAuthorId: storyAuthorId,
      storyAuthorUsername: storyAuthorUsername,
    );
  }
}
