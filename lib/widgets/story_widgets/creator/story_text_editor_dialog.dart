// lib/widgets/story_widgets/creator/story_text_editor_dialog.dart

import 'package:flutter/material.dart';
import 'package:freegram/models/text_overlay_model.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

/// Text editor dialog for story creator
/// Allows editing text, color, and style for text overlays
class StoryTextEditorDialog extends StatefulWidget {
  final TextOverlay initialOverlay;

  const StoryTextEditorDialog({
    Key? key,
    required this.initialOverlay,
  }) : super(key: key);

  static Future<TextOverlay?> show(
    BuildContext context, {
    required TextOverlay initialOverlay,
  }) async {
    return await showDialog<TextOverlay>(
      context: context,
      builder: (context) =>
          StoryTextEditorDialog(initialOverlay: initialOverlay),
    );
  }

  @override
  State<StoryTextEditorDialog> createState() => _StoryTextEditorDialogState();
}

class _StoryTextEditorDialogState extends State<StoryTextEditorDialog> {
  late TextEditingController _textController;
  late String _selectedColor;
  late String _selectedStyle;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialOverlay.text);
    _selectedColor = widget.initialOverlay.color;
    _selectedStyle = widget.initialOverlay.style;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
      ),
      title: Text(
        'Edit Text',
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              autofocus: true,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Enter text',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(
                    DesignTokens.opacityMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            // Color picker
            Text(
              'Color:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(
                  DesignTokens.opacityHigh,
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceSM),
            _ColorPicker(
              selectedColor: _selectedColor,
              onColorSelected: (color) {
                setState(() {
                  _selectedColor = color;
                });
              },
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            // Style picker
            Text(
              'Style:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(
                  DesignTokens.opacityHigh,
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceSM),
            _StylePicker(
              selectedStyle: _selectedStyle,
              onStyleSelected: (style) {
                setState(() {
                  _selectedStyle = style;
                });
              },
              theme: theme,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(
                DesignTokens.opacityHigh,
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            final text = _textController.text.trim();
            if (text.isNotEmpty) {
              Navigator.of(context).pop(
                widget.initialOverlay.copyWith(
                  text: text,
                  color: _selectedColor,
                  style: _selectedStyle,
                ),
              );
            } else {
              Navigator.of(context).pop();
            }
          },
          child: Text(
            'Done',
            style: TextStyle(
              color: SonarPulseTheme.primaryAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// Color picker widget for text editor
class _ColorPicker extends StatelessWidget {
  final String selectedColor;
  final ValueChanged<String> onColorSelected;

  const _ColorPicker({
    required this.selectedColor,
    required this.onColorSelected,
  });

  static const List<Color> _colors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: DesignTokens.spaceSM,
      runSpacing: DesignTokens.spaceSM,
      children: _colors.map((color) {
        final hexColor =
            '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
        final isSelected = hexColor == selectedColor;

        return GestureDetector(
          onTap: () => onColorSelected(hexColor),
          child: Container(
            width: DesignTokens.spaceXL,
            height: DesignTokens.spaceXL,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.onSurface
                    : Colors.transparent,
                width: isSelected ? DesignTokens.elevation1 : 0,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Style picker widget for text editor
class _StylePicker extends StatelessWidget {
  final String selectedStyle;
  final ValueChanged<String> onStyleSelected;
  final ThemeData theme;

  const _StylePicker({
    required this.selectedStyle,
    required this.onStyleSelected,
    required this.theme,
  });

  static const List<String> _styles = ['bold', 'outline', 'neon'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _styles.map((style) {
          final isSelected = style == selectedStyle;

          return GestureDetector(
            onTap: () => onStyleSelected(style),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceMD,
                vertical: DesignTokens.spaceSM,
              ),
              margin:
                  const EdgeInsets.symmetric(horizontal: DesignTokens.spaceXS),
              decoration: BoxDecoration(
                color: isSelected
                    ? SonarPulseTheme.primaryAccent
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                border: Border.all(
                  color: isSelected
                      ? SonarPulseTheme.primaryAccent
                      : theme.colorScheme.onSurface.withOpacity(
                          DesignTokens.opacityMedium,
                        ),
                  width: DesignTokens.elevation1,
                ),
              ),
              child: Text(
                style.toUpperCase(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
