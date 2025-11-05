// lib/models/media_item_model.dart

class MediaItem {
  final String url;
  final String? caption;
  final String type; // 'image' or 'video'

  MediaItem({
    required this.url,
    this.caption,
    required this.type,
  });

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      url: map['url'] ?? '',
      caption: map['caption'] as String?,
      type: map['type'] ?? 'image',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'caption': caption,
      'type': type,
    };
  }

  MediaItem copyWith({
    String? url,
    String? caption,
    String? type,
  }) {
    return MediaItem(
      url: url ?? this.url,
      caption: caption ?? this.caption,
      type: type ?? this.type,
    );
  }
}
