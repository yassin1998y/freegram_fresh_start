// lib/screens/feed_screen.dart

import 'package:flutter/material.dart';
import 'package:freegram/screens/feed/for_you_feed_tab.dart'
    show ForYouFeedTab, kForYouFeedTabKey;
import 'package:freegram/screens/feed/nearby_feed_tab.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/blocs/unified_feed_bloc.dart';
import 'package:freegram/blocs/nearby_feed_bloc.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/services/ad_service.dart';
import 'package:freegram/utils/enums.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      initialIndex: 0, // For You tab selected by default
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Column(
          children: [
            TabBar(
              tabs: const [
                Tab(text: 'For You'),
                Tab(text: 'Reels'),
              ],
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
              labelStyle: theme.textTheme.labelLarge,
            ),
            Expanded(
              child: TabBarView(
                physics: const ClampingScrollPhysics(),
                children: [
                  // For You Tab - Using Unified Feed BLoC
                  BlocProvider(
                    create: (context) => UnifiedFeedBloc(
                      postRepository: locator<PostRepository>(),
                      userRepository: locator<UserRepository>(),
                      adService: locator<AdService>(),
                    )..add(LoadUnifiedFeedEvent(
                        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                        refresh: true,
                        timeFilter: TimeFilter.allTime,
                      )),
                    child: ForYouFeedTab(key: kForYouFeedTabKey),
                  ),
                  // Nearby Tab
                  BlocProvider(
                    create: (context) => NearbyFeedBloc(
                      postRepository: locator<PostRepository>(),
                    )..add(
                        LoadNearbyFeedEvent(
                          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                          refresh: true,
                        ),
                      ),
                    child: const NearbyFeedTab(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
