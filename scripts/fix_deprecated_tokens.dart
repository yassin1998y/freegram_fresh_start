// scripts/fix_deprecated_tokens.dart
// Script to fix deprecated DesignTokens usage
// Run with: dart run scripts/fix_deprecated_tokens.dart

import 'dart:io';

void main() async {
  print('🔧 Fixing deprecated DesignTokens...\n');

  // List of files to fix (from lint errors)
  final filesToFix = [
    'lib/screens/improved_chat_screen.dart',
    'lib/screens/multi_step_onboarding_screen.dart',
    'lib/screens/nearby_screen.dart',
    'lib/screens/page_profile_screen.dart',
    'lib/screens/signup_screen.dart',
    'lib/widgets/chat_widgets/chat_date_separator.dart',
    'lib/widgets/chat_widgets/professional_chat_list_item.dart',
    'lib/widgets/chat_widgets/professional_message_actions_modal.dart',
    'lib/widgets/chat_widgets/professional_message_bubble.dart',
    'lib/widgets/common/app_reaction_button.dart',
    'lib/widgets/feed_widgets/create_post_widget.dart',
    'lib/widgets/professional_components.dart',
    'lib/widgets/story_widgets/feed/story_feed_card.dart',
    'lib/widgets/story_widgets/shared/story_upload_border.dart',
    'lib/widgets/story_widgets/viewer/story_progress_segments.dart',
    'lib/widgets/story_widgets/viewer/story_user_header.dart',
  ];

  // Replacement map
  final replacements = {
    // Animation Durations
    'DesignTokens.durationNormal': 'AnimationTokens.normal',
    'DesignTokens.durationFast': 'AnimationTokens.fast',
    'DesignTokens.durationSlow': 'AnimationTokens.slow',
    'DesignTokens.durationVerySlow': 'AnimationTokens.verySlow',

    // Animation Curves
    'DesignTokens.curveEaseOut': 'AnimationTokens.easeOut',
    'DesignTokens.curveEaseInOut': 'AnimationTokens.easeInOut',
    'DesignTokens.curveElasticOut': 'AnimationTokens.elasticOut',
    'DesignTokens.curveEaseIn': 'AnimationTokens.easeIn',
    'DesignTokens.curveFastOutSlowIn': 'AnimationTokens.fastOutSlowIn',

    // Colors (already fixed in boost screens, but keep for others)
    'DesignTokens.successColor': 'SemanticColors.success',
    'DesignTokens.errorColor': 'SemanticColors.error',
    'DesignTokens.warningColor': 'SemanticColors.warning',
  };

  int totalFixed = 0;

  for (final filePath in filesToFix) {
    final file = File(filePath);
    if (!await file.exists()) {
      print('⚠️  File not found: $filePath');
      continue;
    }

    String content = await file.readAsString();
    String originalContent = content;
    int fileFixed = 0;

    // Apply replacements
    replacements.forEach((old, new_) {
      final count = old.allMatches(content).length;
      if (count > 0) {
        content = content.replaceAll(old, new_);
        fileFixed += count;
        print('  ✓ $filePath: $count × "$old" → "$new_"');
      }
    });

    // Add imports if needed
    if (fileFixed > 0 &&
        !content.contains('AnimationTokens') &&
        content.contains('AnimationTokens.')) {
      // Add import after design_tokens import
      if (content
          .contains("import 'package:freegram/theme/design_tokens.dart';")) {
        content = content.replaceAll(
          "import 'package:freegram/theme/design_tokens.dart';",
          "import 'package:freegram/theme/design_tokens.dart';",
        );
        // AnimationTokens is in the same file, no extra import needed
      }
    }

    if (fileFixed > 0) {
      await file.writeAsString(content);
      totalFixed += fileFixed;
      print('  ✅ Fixed $fileFixed issues in $filePath\n');
    }
  }

  print('✨ Total fixes: $totalFixed');
  print(
      '\n📝 Note: Some files may need manual review for constant value errors.');
}
