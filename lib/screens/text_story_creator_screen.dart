// lib/screens/text_story_creator_screen.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/widgets/common/keyboard_safe_area.dart';
import 'package:freegram/repositories/story_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/utils/story_constants.dart';

class TextStoryCreatorScreen extends StatefulWidget {
  const TextStoryCreatorScreen({Key? key}) : super(key: key);

  @override
  State<TextStoryCreatorScreen> createState() => _TextStoryCreatorScreenState();
}

class _TextStoryCreatorScreenState extends State<TextStoryCreatorScreen> {
  final TextEditingController _textController = TextEditingController();
  final StoryRepository _storyRepository = locator<StoryRepository>();

  Color _textColor = Colors.white; // User-selectable, white is common for text
  Color _backgroundColor = Colors.blue; // User-selectable
  bool _isUploading = false;

  static const List<Color> _textColorOptions = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
  ];

  static const List<Color> _backgroundColors = [
    Colors.blue,
    Colors.purple,
    Colors.pink,
    Colors.orange,
    Colors.green,
    Colors.red,
    Colors.teal,
    Colors.indigo,
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _shareStory() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to share a story')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Generate image from text
      final imageFile = await _generateImageFromText(text);

      // Upload story
      await _storyRepository.createStory(
        userId: currentUser.uid,
        mediaFile: imageFile,
        mediaType: 'image',
        caption: text,
      );

      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Story shared successfully!'),
            backgroundColor: theme.colorScheme.primary,
            duration: AnimationTokens.normal,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error sharing text story: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing story: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<File> _generateImageFromText(String text) async {
    // Create a picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Story dimensions (9:16 aspect ratio)
    const width = StoryConstants.storyWidth;
    const height = StoryConstants.storyHeight;

    // Draw background
    final backgroundPaint = Paint()..color = _backgroundColor;
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), backgroundPaint);

    // Draw text
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _textColor,
          fontSize: StoryConstants.textStoryFontSize,
          fontWeight: FontWeight.bold,
          fontFamily: 'OpenSans',
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: width - StoryConstants.textStoryPadding);
    textPainter.paint(
      canvas,
      Offset(
        width / 2 - textPainter.width / 2,
        height / 2 - textPainter.height / 2,
      ),
    );

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    // Save to temporary file
    final tempDir = await getTemporaryDirectory();
    final file = File(
      path.join(
        tempDir.path,
        'text_story_${DateTime.now().millisecondsSinceEpoch}.png',
      ),
    );
    await file.writeAsBytes(bytes);

    return file;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 SCREEN: text_story_creator_screen.dart');
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: _textColor, // Use text color for visibility on background
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceMD),
              child: Center(
                child: SizedBox(
                  width: DesignTokens.iconLG,
                  height: DesignTokens.iconLG,
                  child: AppProgressIndicator(
                    strokeWidth: DesignTokens.elevation1,
                    color: _textColor, // Use text color for visibility
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceSM,
                vertical: DesignTokens.spaceSM,
              ),
              child: FilledButton(
                onPressed: _shareStory,
                style: FilledButton.styleFrom(
                  backgroundColor: SonarPulseTheme.primaryAccent,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMD,
                    vertical: DesignTokens.spaceSM,
                  ),
                ),
                child: Text(
                  'Share',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: KeyboardSafeArea(
        child: SafeArea(
          child: Column(
            children: [
              // Text input area (center)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DesignTokens.spaceXL),
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textColor,
                        fontSize: DesignTokens.fontSizeDisplay,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tap to type...',
                        hintStyle: TextStyle(
                          color: _textColor
                              .withValues(alpha: DesignTokens.opacityMedium),
                          fontSize: DesignTokens.fontSizeDisplay,
                          fontWeight: FontWeight.bold,
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ),
              // Controls at bottom
              Container(
                padding: const EdgeInsets.all(DesignTokens.spaceMD),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface
                      .withValues(alpha: DesignTokens.opacityMedium),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(DesignTokens.radiusXL),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Text color picker
                    Text(
                      'Text Color',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceSM),
                    SizedBox(
                      height: DesignTokens.spaceXXXL - DesignTokens.spaceSM,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _textColorOptions.length,
                        itemBuilder: (context, index) {
                          final color = _textColorOptions[index];
                          final isSelected = color == _textColor;
                          return GestureDetector(
                            onTap: () => setState(() => _textColor = color),
                            child: Container(
                              width: DesignTokens.spaceXL,
                              height: DesignTokens.spaceXL,
                              margin: const EdgeInsets.symmetric(
                                horizontal: DesignTokens.spaceXS,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.onSurface
                                      : Colors.transparent,
                                  width:
                                      isSelected ? DesignTokens.elevation1 : 0,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceMD),
                    // Background color picker
                    Text(
                      'Background',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceSM),
                    SizedBox(
                      height: DesignTokens.spaceXXXL - DesignTokens.spaceSM,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _backgroundColors.length,
                        itemBuilder: (context, index) {
                          final color = _backgroundColors[index];
                          final isSelected = color == _backgroundColor;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _backgroundColor = color),
                            child: Container(
                              width: DesignTokens.spaceXL,
                              height: DesignTokens.spaceXL,
                              margin: const EdgeInsets.symmetric(
                                horizontal: DesignTokens.spaceXS,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.onSurface
                                      : Colors.transparent,
                                  width:
                                      isSelected ? DesignTokens.elevation1 : 0,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
