import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_bloc.dart';
import 'package:freegram/screens/random_chat/logic/random_chat_event.dart';

/// Global RouteObserver for Random Chat lifecycle management.
/// MUST be registered in main.dart's MaterialApp navigatorObservers.
final RouteObserver<PageRoute> randomChatRouteObserver =
    RouteObserver<PageRoute>();

class RandomChatLifecycleHandler extends StatefulWidget {
  final Widget child;

  const RandomChatLifecycleHandler({super.key, required this.child});

  @override
  State<RandomChatLifecycleHandler> createState() =>
      _RandomChatLifecycleHandlerState();
}

class _RandomChatLifecycleHandlerState extends State<RandomChatLifecycleHandler>
    with WidgetsBindingObserver, RouteAware {
  @override
  void initState() {
    super.initState();
    // Register App Lifecycle Observer
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to Route Tracking
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      randomChatRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    // Strict Cleanup: Remove observers to prevent memory leaks and zombie calls
    WidgetsBinding.instance.removeObserver(this);
    randomChatRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final bloc = context.read<RandomChatBloc>();

      // Stop background processing to save battery/data
      bloc.add(const RandomChatAppBackgrounded());

      // Ensure user is removed from matchmaking queue
      bloc.add(const RandomChatStopSearching());
    }
  }

  @override
  void didPushNext() {
    // Fires when another screen covers the current chat screen
    context.read<RandomChatBloc>().add(const RandomChatRoutePushed());
  }

  @override
  void didPopNext() {
    // Fires when the user returns to the chat screen (top screen was popped)
    context.read<RandomChatBloc>().add(const RandomChatRoutePopped());
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
