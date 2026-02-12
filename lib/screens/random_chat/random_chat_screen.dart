import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/random_chat/random_chat_bloc.dart';
import 'package:freegram/blocs/random_chat/random_chat_event.dart';
import 'package:freegram/blocs/random_chat/random_chat_state.dart';
import 'package:freegram/blocs/interaction/interaction_bloc.dart';
import 'package:freegram/screens/random_chat/match_tab.dart';
import 'package:freegram/screens/random_chat/lounge_tab.dart';
import 'package:freegram/screens/random_chat/history_tab.dart';

class RandomChatScreen extends StatefulWidget {
  const RandomChatScreen({super.key});

  @override
  State<RandomChatScreen> createState() => _RandomChatScreenState();
}

class _RandomChatScreenState extends State<RandomChatScreen> {
  int _currentIndex = 1; // Default to 'Match' tab

  @override
  void initState() {
    super.initState();
    _enableSecureMode();
  }

  @override
  void dispose() {
    _disableSecureMode();
    super.dispose();
  }

  static const _windowChannel = MethodChannel('freegram/window_manager');
  static const int _flagSecure = 8192; // WindowManager.LayoutParams.FLAG_SECURE

  Future<void> _enableSecureMode() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _windowChannel.invokeMethod('addFlags', {'flags': _flagSecure});
    } catch (e) {
      debugPrint("Error enabling secure mode: $e");
    }
  }

  Future<void> _disableSecureMode() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _windowChannel.invokeMethod('clearFlags', {'flags': _flagSecure});
    } catch (e) {
      debugPrint("Error disabling secure mode: $e");
    }
  }

  void _showAdminDialog(BuildContext context) {
    final TextEditingController _passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title:
              const Text("Admin Access", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Enter Admin Password",
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.deepPurpleAccent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (_passwordController.text == "Morph1998@") {
                  context.read<RandomChatBloc>().add(InitializeGatedScreen());
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("✅ Access Granted. Welcome, Admin."),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("❌ Access Denied."),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text("Unlock"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RandomChatBloc(),
      child: BlocProvider(
        create: (context) => InteractionBloc(),
        child: Builder(builder: (context) {
          // Use BlocBuilder to conditionally render the entire screen content
          return BlocBuilder<RandomChatBloc, RandomChatState>(
            buildWhen: (p, c) => p.isGated != c.isGated,
            builder: (context, state) {
              if (state.isGated) {
                // If gated, return the full-screen placeholder (similar to Nearby Screen on Web)
                return _GatedPlaceholder(
                  onAdminTap: () => _showAdminDialog(context),
                );
              }

              // Normal UI when NOT gated
              return Scaffold(
                resizeToAvoidBottomInset: false,
                appBar: AppBar(
                  title: const Text('Random Chat'),
                  automaticallyImplyLeading: false,
                ),
                body: IndexedStack(
                  index: _currentIndex,
                  children: [
                    LoungeTab(onUserTap: () {
                      setState(() => _currentIndex = 1);
                    }),
                    const MatchTab(),
                    const HistoryTab(),
                  ],
                ),
                bottomNavigationBar: Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: Colors.black,
                  ),
                  child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    backgroundColor: Colors.black,
                    selectedItemColor: Colors.deepPurpleAccent,
                    unselectedItemColor: Colors.white54,
                    onTap: (index) {
                      setState(() => _currentIndex = index);
                    },
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.grid_view),
                        label: "Lounge",
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.video_chat),
                        label: "Match",
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.history),
                        label: "History",
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// Mimics _WebPlaceholder from nearby_screen.dart
class _GatedPlaceholder extends StatelessWidget {
  final VoidCallback onAdminTap;

  const _GatedPlaceholder({required this.onAdminTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // CRITICAL: Explicit background color to prevent black screen
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              const Text(
                'Feature Under Construction',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'We are building a secure and amazing random chat experience. Stay tuned!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: onAdminTap,
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text("Admin Access"),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
