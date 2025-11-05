// lib/widgets/story_widgets/story_creator_type_screen.dart

import 'package:flutter/material.dart';
import 'package:freegram/screens/story_creator_screen.dart';
import 'package:freegram/screens/text_story_creator_screen.dart';

class StoryCreatorTypeScreen extends StatelessWidget {
  const StoryCreatorTypeScreen({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const StoryCreatorTypeScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Create Story',
                style: theme.textTheme.titleLarge,
              ),
            ),
            const Divider(),
            // Options - List view for better scrolling
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Text Story option
                    _buildOptionCard(
                      context: context,
                      theme: theme,
                      icon: Icons.text_fields,
                      label: 'Text Story',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const TextStoryCreatorScreen(),
                          ),
                        );
                      },
                    ),
                    // Music Story option (placeholder)
                    _buildOptionCard(
                      context: context,
                      theme: theme,
                      icon: Icons.music_note,
                      label: 'Music Story',
                      onTap: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Music Story coming soon!')),
                        );
                      },
                    ),
                    // Camera option
                    _buildOptionCard(
                      context: context,
                      theme: theme,
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StoryCreatorScreen(),
                          ),
                        );
                      },
                    ),
                    // Recent Gallery Photos section
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Gallery Photos',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: 10, // Placeholder count
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    // TODO: Open StoryCreatorScreen with selected photo
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const StoryCreatorScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 80,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: theme.colorScheme.outline
                                            .withOpacity(0.2),
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.photo,
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.5),
                                        size: 32,
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
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.cardTheme.color,
      shape: theme.cardTheme.shape,
      elevation: theme.cardTheme.elevation,
      child: InkWell(
        onTap: onTap,
        borderRadius: (theme.cardTheme.shape is RoundedRectangleBorder)
            ? (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius
                as BorderRadius
            : BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                icon,
                color: theme.iconTheme.color,
                size: 28,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                color: theme.iconTheme.color?.withOpacity(0.5),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
