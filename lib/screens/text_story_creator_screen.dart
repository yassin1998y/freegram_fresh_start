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

class TextStoryCreatorScreen extends StatefulWidget {
  const TextStoryCreatorScreen({Key? key}) : super(key: key);

  @override
  State<TextStoryCreatorScreen> createState() => _TextStoryCreatorScreenState();
}

class _TextStoryCreatorScreenState extends State<TextStoryCreatorScreen> {
  final TextEditingController _textController = TextEditingController();
  final StoryRepository _storyRepository = locator<StoryRepository>();

  Color _textColor = Colors.white;
  Color _backgroundColor = Colors.blue;
  bool _isUploading = false;

  final List<Color> _textColorOptions = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
  ];

  final List<Color> _backgroundColors = [
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story shared successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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

    // Screen dimensions (typical story size)
    const width = 1080.0;
    const height = 1920.0;

    // Draw background
    final backgroundPaint = Paint()..color = _backgroundColor;
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), backgroundPaint);

    // Draw text
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _textColor,
          fontSize: 72,
          fontWeight: FontWeight.bold,
          fontFamily: 'OpenSans',
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: width - 160);
    textPainter.paint(
      canvas,
      Offset(width / 2 - textPainter.width / 2,
          height / 2 - textPainter.height / 2),
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
          icon: Icon(Icons.close, color: theme.colorScheme.onPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: AppProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: FilledButton(
                onPressed: _shareStory,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child: Text(
                  'Share',
                  style: theme.textTheme.labelLarge,
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
                    padding: const EdgeInsets.all(32.0),
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tap to type...',
                        hintStyle: TextStyle(
                          color: _textColor.withOpacity(0.5),
                          fontSize: 48,
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Text color picker
                    Text(
                      'Text Color',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _textColorOptions.length,
                        itemBuilder: (context, index) {
                          final color = _textColorOptions[index];
                          final isSelected = color == _textColor;
                          return GestureDetector(
                            onTap: () => setState(() => _textColor = color),
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Background color picker
                    Text(
                      'Background',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
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
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 3,
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
