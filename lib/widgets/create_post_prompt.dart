import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:freegram/models/user_model.dart';

class CreatePostPrompt extends StatelessWidget {
  final UserModel user;
  final VoidCallback onPromptTapped;

  const CreatePostPrompt({
    super.key,
    required this.user,
    required this.onPromptTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 0),
      color: Theme.of(context).cardTheme.color,
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: user.photoUrl.isNotEmpty
                    ? CachedNetworkImageProvider(user.photoUrl)
                    : null,
                child: user.photoUrl.isEmpty
                    ? Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : '?')
                    : null,
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: GestureDetector(
                  onTap: onPromptTapped,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30.0),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Text('What\'s on your mind?', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color)),
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
          SizedBox(
            height: 40.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _PromptButton(
                  icon: Icons.videocam,
                  color: Colors.red,
                  label: 'Reel',
                  onPressed: onPromptTapped,
                ),
                const VerticalDivider(width: 8.0),
                _PromptButton(
                  icon: Icons.photo_library,
                  color: Colors.green,
                  label: 'Photo',
                  onPressed: onPromptTapped,
                ),
                const VerticalDivider(width: 8.0),
                _PromptButton(
                  icon: Icons.video_call,
                  color: Colors.purple,
                  label: 'Room',
                  onPressed: onPromptTapped,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _PromptButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onPressed;

  const _PromptButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      label: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}