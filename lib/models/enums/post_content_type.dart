// lib/models/enums/post_content_type.dart

/// Content type classification for posts
/// Used to determine contentWeight in the ranking algorithm
enum PostContentType {
  text, // contentWeight = 1.0
  image, // contentWeight = 1.2
  video, // contentWeight = 1.5
  link, // contentWeight = 1.3
  poll, // contentWeight = 1.1
  mixed, // contentWeight = 1.4 (image + video)
}
