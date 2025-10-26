// lib/screens/nearby_chat_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/nearby_chat_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/nearby_message.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/nearby_chat_repository.dart';
import 'package:timeago/timeago.dart' as timeago;

class NearbyChatScreen extends StatelessWidget {
  final UserModel targetUser;
  final String deviceAddress;

  const NearbyChatScreen({
    super.key,
    required this.targetUser,
    required this.deviceAddress,
  });

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser!.uid;
    final ids = [myId, targetUser.id]..sort();
    final chatId = ids.join('_');

    return BlocProvider(
      create: (context) => NearbyChatBloc(
        nearbyChatRepository: locator<NearbyChatRepository>(),
        chatId: chatId,
        deviceAddress: deviceAddress,
      )..add(LoadMessages()),
      child: _NearbyChatView(targetUser: targetUser),
    );
  }
}

class _NearbyChatView extends StatefulWidget {
  final UserModel targetUser;
  const _NearbyChatView({required this.targetUser});

  @override
  State<_NearbyChatView> createState() => _NearbyChatViewState();
}

class _NearbyChatViewState extends State<_NearbyChatView> {
  final _messageController = TextEditingController();
  // final BluetoothService _bluetoothService = locator<BluetoothService>(); // No longer needed here

  @override
  void initState() {
    super.initState();
    // Chat connection logic is temporarily disabled.
    /*
    _bluetoothService.prepareForChat().then((success) {
        if (success && mounted) {
            final bloc = context.read<NearbyChatBloc>();
            _bluetoothService.connectForChat(bloc.deviceAddress);
        }
    });
    */
  }

  @override
  void dispose() {
    // Chat disconnection logic is temporarily disabled.
    /*
    final bloc = context.read<NearbyChatBloc>();
    _bluetoothService.disconnectFromChat(bloc.deviceAddress);
    */
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    // We prevent sending messages for now.
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chat functionality is temporarily disabled.")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<NearbyChatBloc, NearbyChatState>(
              builder: (context, state) {
                if (state is NearbyChatLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is NearbyChatLoaded) {
                  if (state.messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "Nearby Chat is temporarily disabled while we improve discovery. Saved messages are shown here.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }
                  final messages = state.messages;
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages.reversed.toList()[index];
                      final isMe = message.senderId == FirebaseAuth.instance.currentUser!.uid;
                      return _MessageBubble(message: message, isMe: isMe);
                    },
                  );
                }
                return const Center(child: Text("Could not load messages."));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Chat is disabled...',
                      filled: true,
                      fillColor: Theme.of(context).dividerColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20.0), borderSide: BorderSide.none),
                    ),
                    enabled: false, // Disabled
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.grey),
                  onPressed: null, // Disabled
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final NearbyMessage message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(message.text, style: TextStyle(color: isMe ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color)),
            const SizedBox(height: 4),
            Text(timeago.format(message.timestamp, locale: 'en_short'), style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}