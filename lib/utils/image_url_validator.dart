// lib/utils/image_url_validator.dart

/// Utility class for validating and normalizing image URLs
class ImageUrlValidator {
  /// Validates if a URL string is a valid HTTP/HTTPS URL
  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty || url.trim().isEmpty) {
      return false;
    }

    final trimmedUrl = url.trim();
    return trimmedUrl.startsWith('http://') ||
        trimmedUrl.startsWith('https://');
  }

  /// Returns a valid URL or empty string if invalid
  /// This ensures we never pass invalid URLs to NetworkImage
  static String normalizeUrl(String? url) {
    if (isValidUrl(url)) {
      return url!.trim();
    }
    return '';
  }

  /// Returns true if the URL should be used for NetworkImage
  /// Use this before setting backgroundImage in CircleAvatar
  static bool shouldUseAsImage(String? url) {
    return isValidUrl(url);
  }
}
