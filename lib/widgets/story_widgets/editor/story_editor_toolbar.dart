// lib/widgets/story_widgets/editor/story_editor_toolbar.dart

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

/// Editor toolbar for story creation
/// Shows tool buttons (Text, Draw, Stickers) with glassmorphic design
class StoryEditorToolbar extends StatelessWidget {
  final String activeTool;
  final Function(String) onToolChanged;

  const StoryEditorToolbar({
    Key? key,
    required this.activeTool,
    required this.onToolChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final safeAreaTop = MediaQuery.of(context).padding.top;

    return Positioned(
      top: safeAreaTop + DesignTokens.spaceSM,
      right: DesignTokens.spaceSM,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: DesignTokens.blurMedium,
            sigmaY: DesignTokens.blurMedium,
          ),
          child: Container(
            padding: const EdgeInsets.all(DesignTokens.spaceXS),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.1),
                width: DesignTokens.elevation1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToolButton(
                  context: context,
                  icon: Icons.text_fields,
                  tool: 'text',
                  onTap: () {
                    final newTool = activeTool == 'text' ? 'none' : 'text';
                    onToolChanged(newTool);
                  },
                ),
                const SizedBox(width: DesignTokens.spaceSM),
                _buildToolButton(
                  context: context,
                  icon: Icons.edit,
                  tool: 'draw',
                  onTap: () {
                    final newTool = activeTool == 'draw' ? 'none' : 'draw';
                    onToolChanged(newTool);
                  },
                ),
                const SizedBox(width: DesignTokens.spaceSM),
                _buildToolButton(
                  context: context,
                  icon: Icons.emoji_emotions,
                  tool: 'stickers',
                  onTap: () {
                    final newTool =
                        activeTool == 'stickers' ? 'none' : 'stickers';
                    onToolChanged(newTool);
                  },
                ),
                _buildToolButton(
                  context: context,
                  icon: Icons.download,
                  tool: 'save',
                  onTap: () {
                    onToolChanged('save');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required BuildContext context,
    required IconData icon,
    required String tool,
    required VoidCallback onTap,
  }) {
    final isActive = activeTool == tool;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
        child: Container(
          width: DesignTokens.buttonHeight,
          height: DesignTokens.buttonHeight,
          decoration: BoxDecoration(
            color: isActive
                ? SonarPulseTheme.primaryAccent.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
            border: isActive
                ? Border.all(
                    color: SonarPulseTheme.primaryAccent,
                    width: 1.0,
                  )
                : Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.1),
                    width: 1.0,
                  ),
          ),
          child: Icon(
            icon,
            color: isActive
                ? SonarPulseTheme.primaryAccent
                : Theme.of(context).colorScheme.onSurface,
            size: DesignTokens.iconLG,
          ),
        ),
      ),
    );
  }
}
