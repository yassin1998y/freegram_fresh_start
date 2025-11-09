// lib/utils/screen_debug_helper.dart
import 'package:flutter/foundation.dart';

/// Helper function to log screen entry with emoji
/// Call this in build() method for StatelessWidget or initState() for StatefulWidget
void debugScreenEntry(String screenFileName) {
  if (kDebugMode) {
    // Extract just the filename without path
    final fileName = screenFileName.split('/').last.replaceAll('.dart', '');
    debugPrint('📱 SCREEN: $fileName');
  }
}
