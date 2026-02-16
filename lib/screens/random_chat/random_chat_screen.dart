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
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/utils/memory_manager.dart';
import 'package:freegram/theme/design_tokens.dart';

class RandomChatScreen extends StatefulWidget {
  final bool isVisible;
  const RandomChatScreen({super.key, this.isVisible = true});

  @override
  State<RandomChatScreen> createState() => _RandomChatScreenState();
}

class _RandomChatScreenState extends State<RandomChatScreen>
    with GlobalMemoryManager {
  int _currentIndex = 1; // Default to 'Match' tab

  @override
  void initState() {
    super.initState();
    if (widget.isVisible) {
      _enableSecureMode();
    }
  }

  @override
  void didUpdateWidget(RandomChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _enableSecureMode();
      } else {
        _disableSecureMode();
      }
    }
  }

  @override
  void dispose() {
    evictResources();
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
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text("Admin Access",
              style: TextStyle(color: theme.colorScheme.onSurface)),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: "Enter Admin Password",
              hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.54)),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.54))),
              focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: SonarPulseTheme.primaryAccent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (passwordController.text == "Morph1998@") {
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
              final theme = Theme.of(context);
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
                    MatchTab(isVisible: widget.isVisible && _currentIndex == 1),
                    const HistoryTab(),
                  ],
                ),
                bottomNavigationBar: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  backgroundColor: theme.colorScheme.surface,
                  selectedItemColor: SonarPulseTheme.primaryAccent,
                  unselectedItemColor:
                      theme.colorScheme.onSurface.withValues(alpha: 0.54),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceXXL),
          child: Container(
            padding: const EdgeInsets.all(DesignTokens.spaceXXXL),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                width: 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(DesignTokens.spaceXL),
                  decoration: BoxDecoration(
                    color: SonarPulseTheme.primaryAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_person_outlined,
                    size: DesignTokens.iconXXL,
                    color: SonarPulseTheme.primaryAccent,
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceXL),
                Text(
                  'Exclusive Access',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: DesignTokens.fontSizeXXL,
                        letterSpacing: DesignTokens.letterSpacingTight,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.spaceMD),
                Text(
                  'Random Match is currently in private beta for selected regions. Join the waitlist for early access.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: DesignTokens.fontSizeMD,
                        height: DesignTokens.lineHeightNormal,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.spaceXXL),
                TextButton.icon(
                  onPressed: onAdminTap,
                  icon: const Icon(Icons.admin_panel_settings_outlined,
                      size: DesignTokens.iconSM),
                  label: const Text("Admin Access"),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).textTheme.bodySmall?.color,
                    textStyle: const TextStyle(
                      fontSize: DesignTokens.fontSizeSM,
                      fontWeight: FontWeight.w500,
                    ),
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
