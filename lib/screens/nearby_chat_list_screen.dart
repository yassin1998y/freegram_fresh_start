import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:freegram/models/nearby_message.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/screens/nearby_chat_screen.dart';
import 'package:freegram/widgets/freegram_app_bar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class NearbyChatListScreen extends StatelessWidget {
  const NearbyChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 SCREEN: nearby_chat_list_screen.dart');
    final myId = FirebaseAuth.instance.currentUser?.uid;
    if (myId == null) {
      return const Scaffold(
        body: Center(child: Text("Authentication error.")),
      );
    }

    final chatBox = Hive.box<List<dynamic>>('nearby_chats');
    final profileBox = Hive.box('user_profiles');

    return Scaffold(
      appBar: const FreegramAppBar(
        title: 'Nearby Chats',
        showBackButton: true,
      ),
      body: ValueListenableBuilder<Box<List<dynamic>>>(
        valueListenable: chatBox.listenable(),
        builder: (context, box, _) {
          final chatKeys = box.keys.toList();

          if (chatKeys.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "No Local Chats",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Start a conversation with a user you find nearby.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: chatKeys.length,
            itemBuilder: (context, index) {
              final chatId = chatKeys[index] as String;
              final messages =
                  box.get(chatId)?.cast<NearbyMessage>().toList() ?? [];
              if (messages.isEmpty) {
                return const SizedBox.shrink();
              }

              final lastMessage = messages.last;
              final otherUserId =
                  chatId.replaceAll(myId, '').replaceAll('_', '');

              final profileData = profileBox.get(otherUserId);
              if (profileData == null) {
                // Skip rendering if the user profile isn't cached yet.
                return const SizedBox.shrink();
              }

              final otherUser = UserModel.fromMap(
                  otherUserId, Map<String, dynamic>.from(profileData));

              return ListTile(
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage: otherUser.photoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(otherUser.photoUrl)
                      : null,
                  child: otherUser.photoUrl.isEmpty
                      ? Text(otherUser.username.isNotEmpty
                          ? otherUser.username[0].toUpperCase()
                          : '?')
                      : null,
                ),
                title: Text(otherUser.username,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  lastMessage.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  timeago.format(lastMessage.timestamp, locale: 'en_short'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () {
                  final contactsBox = Hive.box('nearby_contacts');
                  final contactData = contactsBox.get(otherUserId) as Map?;
                  final deviceAddress = contactData?['address'] as String?;

                  if (deviceAddress != null) {
                    locator<NavigationService>().navigateTo(
                      NearbyChatScreen(
                        targetUser: otherUser,
                        deviceAddress:
                            deviceAddress, // Pass the required address here
                      ),
                      transition: PageTransition.slide,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            "Error: Could not find device address. Please re-discover the user.")));
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
