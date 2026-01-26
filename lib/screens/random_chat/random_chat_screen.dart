import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb and defaultTargetPlatform
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/random_chat/random_chat_bloc.dart';
import 'package:freegram/blocs/random_chat/random_chat_bloc.dart';
// import 'package:freegram/blocs/random_chat/random_chat_event.dart'; // Unused
import 'package:freegram/blocs/interaction/interaction_bloc.dart'; // Interaction
import 'package:freegram/screens/random_chat/match_tab.dart';
import 'package:freegram/screens/random_chat/lounge_tab.dart'; // Import LoungeTab
import 'package:freegram/screens/random_chat/history_tab.dart'; // Import HistoryTab
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

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

  Future<void> _enableSecureMode() async {
    // Skip on Web and non-Android platforms
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (e) {
      debugPrint("Error enabling secure mode: $e");
    }
  }

  Future<void> _disableSecureMode() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (e) {
      debugPrint("Error disabling secure mode: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Provide the Bloc here so it persists across tab switches (if we keep pages alive)
    return BlocProvider(
        create: (context) => RandomChatBloc(),
        child: BlocProvider(
          create: (context) => InteractionBloc(),
          child: Scaffold(
            body: IndexedStack(
              index: _currentIndex,
              children: [
                // Tab 0: Lounge
                LoungeTab(onUserTap: () {
                  // When a user is tapped in Lounge, switch to Match tab (Index 1)
                  // and potentially trigger a "direct match" event in Bloc if supported later.
                  // For now, just navigation to start matching flow.
                  setState(() => _currentIndex = 1);
                }),

                // Tab 1: Match (Core)
                const MatchTab(),

                // Tab 2: History
                const HistoryTab(),
              ],
            ),
            bottomNavigationBar: Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Colors.black, // Dark theme for chat
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                backgroundColor: Colors.black,
                selectedItemColor: Colors.deepPurpleAccent,
                unselectedItemColor: Colors.white54,
                onTap: (index) {
                  setState(() => _currentIndex = index);
                  if (index != 1) {
                    // If leaving Match tab, we might want to signal suspension
                    // But effectively MatchTab is still in IndexedStack.
                    // For true pause, we'd need to send event to Bloc.
                  }
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
          ),
        ));
  }
}
