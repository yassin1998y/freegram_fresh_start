// lib/widgets/feed_widgets/create_story_card.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CreateStoryCard extends StatelessWidget {
  final bool hasStory;
  final VoidCallback? onTap;

  const CreateStoryCard({
    Key? key,
    this.hasStory = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 90,
            height: 120,
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: (theme.cardTheme.shape as RoundedRectangleBorder?)
                      ?.borderRadius ??
                  BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top half: User avatar
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.1),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Avatar
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.surface,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: (user?.photoURL != null &&
                                  user!.photoURL!.isNotEmpty &&
                                  user.photoURL!.trim().isNotEmpty &&
                                  (user.photoURL!.startsWith('http://') ||
                                      user.photoURL!.startsWith('https://')))
                              ? CircleAvatar(
                                  backgroundImage: CachedNetworkImageProvider(
                                      user.photoURL!),
                                  backgroundColor: theme.colorScheme.surface,
                                )
                              : Icon(
                                  Icons.person,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom half: Text and button
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Create Story',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary,
                        ),
                        child: Icon(
                          Icons.add,
                          size: 16,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
