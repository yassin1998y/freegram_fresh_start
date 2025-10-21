import 'package:flutter/material.dart';
import 'package:freegram/models/user_model.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freegram/screens/profile_screen.dart';

class LocalLeaderboardScreen extends StatelessWidget {
  const LocalLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final contactsBox = Hive.box('nearby_contacts');
    final profilesBox = Hive.box('user_profiles');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Rankings'),
      ),
      body: ValueListenableBuilder<Box>(
        valueListenable: contactsBox.listenable(),
        builder: (context, box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text(
                'No users discovered nearby yet.\nUse the Sonar to find people!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final List<UserModel> users = [];
          for (var key in box.keys) {
            final profileData = profilesBox.get(key);
            if (profileData != null) {
              users.add(UserModel.fromMap(key, Map<String, dynamic>.from(profileData)));
            }
          }

          // Sort users by level in descending order
          users.sort((a, b) => b.level.compareTo(a.level));

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: SizedBox(
                    width: 40,
                    child: Center(
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: user.photoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(user.photoUrl)
                            : null,
                        child: user.photoUrl.isEmpty
                            ? Text(user.username.isNotEmpty ? user.username[0] : '?')
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  trailing: Text(
                    'Level ${user.level}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.id)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}