import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/repositories/store_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/repositories/match_repository.dart';
import 'package:freegram/screens/store_screen.dart';
import 'package:freegram/services/ad_helper.dart';
import 'package:freegram/utils/match_screen_constants.dart';
import 'package:freegram/widgets/draggable_card.dart';
import 'package:freegram/widgets/common/app_button.dart';
import 'package:freegram/widgets/match_action_button.dart' show Debouncer;
import 'package:freegram/widgets/offline_overlay.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/theme/design_tokens.dart';

import 'match_animation_screen.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

// Card Item Model - can be either a user or an ad
class CardItem {
  final DocumentSnapshot? userDoc;
  final BannerAd? bannerAd;
  final bool isAd;
  final String id;

  CardItem.user(this.userDoc)
      : bannerAd = null,
        isAd = false,
        id = userDoc!.id;

  CardItem.ad(this.bannerAd)
      : userDoc = null,
        isAd = true,
        id = 'ad_${DateTime.now().millisecondsSinceEpoch}';
}

class _MatchScreenState extends State<MatchScreen>
    with TickerProviderStateMixin {
  final ValueNotifier<List<CardItem>> _cardItems = ValueNotifier([]);
  final ValueNotifier<int> _superLikesCount = ValueNotifier(0);
  bool _isLoading = true;
  String? _errorMessage;
  final GlobalKey<DraggableCardState> _cardKey =
      GlobalKey<DraggableCardState>();

  AdHelper? _adHelper;
  bool _isAdReady = false;
  bool _isFirstTime = true;
  final List<CardItem> _undoStack = [];
  int _swipeCount = 0;
  DateTime? _lastAdTime;
  int _adCooldownSeconds = 0;
  final List<BannerAd> _activeBannerAds = [];

  // Debouncer for button actions
  late final Debouncer _buttonDebouncer;

  // Stream subscription for super likes
  StreamSubscription<DocumentSnapshot>? _superLikesSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: match_screen.dart');
    _buttonDebouncer = Debouncer(
      delay: MatchScreenConstants.buttonDebounceDuration,
    );

    if (!kIsWeb) {
      _adHelper = AdHelper();
      _adHelper!.loadRewardedAd(
        onAdLoaded: () {
          if (mounted) setState(() => _isAdReady = true);
        },
        onAdFailedToLoad: (error) {
          debugPrint('Ad failed to load: $error');
        },
      );
    }

    _fetchPotentialMatches();
    _startAdCooldownTimer();
    _initializeSuperLikesStream();
  }

  @override
  void dispose() {
    _cardItems.dispose();
    _superLikesCount.dispose();
    _buttonDebouncer.dispose();
    _superLikesSubscription?.cancel();

    // Dispose all active banner ads
    for (var ad in _activeBannerAds) {
      ad.dispose();
    }
    _activeBannerAds.clear();
    super.dispose();
  }

  /// Initialize real-time stream for super likes count
  /// This prevents multiple StreamBuilders and improves performance
  void _initializeSuperLikesStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _superLikesSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        _superLikesCount.value = data?['superLikes'] ?? 0;
      }
    }, onError: (error) {
      debugPrint('Error listening to super likes: $error');
    });
  }

  void _startAdCooldownTimer() {
    if (_lastAdTime != null) {
      final elapsed = DateTime.now().difference(_lastAdTime!).inSeconds;
      final remaining = 300 - elapsed; // 5 minute cooldown
      if (remaining > 0) {
        setState(() => _adCooldownSeconds = remaining);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && _adCooldownSeconds > 0) {
            setState(() => _adCooldownSeconds--);
            _startAdCooldownTimer();
          }
        });
      }
    }
  }

  Future<void> _fetchPotentialMatches() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final currentUser = FirebaseAuth.instance.currentUser!;
    try {
      final matches =
          await locator<MatchRepository>().getPotentialMatches(currentUser.uid);
      if (mounted) {
        // Convert to CardItems and inject ads
        final cardItems = <CardItem>[];
        int adAttempts = 0;
        int adSuccesses = 0;

        debugPrint(
            '📦 Starting card injection: ${matches.length} potential matches');

        for (int i = 0; i < matches.length; i++) {
          cardItems.add(CardItem.user(matches[i]));

          // Inject banner ad every N cards (Instagram-style)
          if ((i + 1) % MatchScreenConstants.adFrequency == 0 &&
              !kIsWeb &&
              _adHelper != null) {
            adAttempts++;
            debugPrint(
                '📢 Ad injection point reached at card ${i + 1} (attempt #$adAttempts)');
            try {
              final screenWidth = MediaQuery.of(context).size.width.toInt();
              debugPrint('📱 Requesting banner ad with width: $screenWidth px');

              final bannerAd =
                  await _adHelper!.createBannerAd(width: screenWidth).timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  debugPrint('⏱️ Ad request timed out after 10 seconds');
                  return null;
                },
              );

              if (bannerAd != null && mounted) {
                adSuccesses++;
                _activeBannerAds.add(bannerAd);
                cardItems.add(CardItem.ad(bannerAd));
                debugPrint(
                    '✅ SUCCESS: Ad #$adSuccesses injected at position ${cardItems.length}');
              } else {
                debugPrint('❌ FAILED: Ad returned null (No fill or timeout)');
              }
            } catch (e) {
              debugPrint('❌ EXCEPTION while loading ad: $e');
            }
          }
        }

        debugPrint(
            '📊 SUMMARY: ${cardItems.length} total cards (${matches.length} users + $adSuccesses ads)');
        debugPrint('📊 Ad success rate: $adSuccesses/$adAttempts attempts');

        _cardItems.value = cardItems;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Could not load matches. Please try again.";
        });
      }
      debugPrint("Error fetching potential matches: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // UX IMPROVEMENT: User-friendly error messages
  String _getUserFriendlyErrorMessage(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();
    if (lowerError.contains('network') ||
        lowerError.contains('connection') ||
        lowerError.contains('internet')) {
      return 'Network error. Please check your connection and try again.';
    } else if (lowerError.contains('permission') ||
        lowerError.contains('denied')) {
      return 'Permission denied. Please check your settings.';
    } else if (lowerError.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (lowerError.contains('super likes')) {
      return 'You have no Super Likes left.';
    }
    return 'An error occurred. Please try again.';
  }

  Future<void> _onSwipe(String action, String otherUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final userRepository = locator<UserRepository>();
    final matchRepository = locator<MatchRepository>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await matchRepository.recordSwipe(currentUser.uid, otherUserId, action);

      if (action == 'super_like') {
        messenger.showSnackBar(
          SnackBar(
            content: const Text("Super Like Sent!"),
            backgroundColor: SemanticColors.info,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      if (action == 'smash' || action == 'super_like') {
        final isMatch =
            await matchRepository.checkForMatch(currentUser.uid, otherUserId);
        if (isMatch && mounted) {
          final currentUserModel =
              await userRepository.getUser(currentUser.uid);
          final otherUserModel = await userRepository.getUser(otherUserId);

          await matchRepository.createMatch(currentUser.uid, otherUserId);

          // Use NavigationService with fade transition for match animation
          // Opaque: false is handled by NavigationService's fade transition
          locator<NavigationService>().navigateToFade(
            MatchAnimationScreen(
              currentUser: currentUserModel,
              matchedUser: otherUserModel,
            ),
          );
        }
      }
    } catch (e) {
      if (e.toString().contains("You have no Super Likes left.") && mounted) {
        _showOutOfSuperLikesDialog();
      } else {
        final errorMessage = _getUserFriendlyErrorMessage(e.toString());
        messenger.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            ),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Theme.of(context).colorScheme.onError,
              onPressed: () => _fetchPotentialMatches(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _removeTopCard(SwipeDirection direction) async {
    if (_cardItems.value.isEmpty) return;

    final cardItem = _cardItems.value.first;

    // If it's an ad card, just remove it without any action
    if (cardItem.isAd) {
      debugPrint('Ad card swiped ${direction.name}');
      if (mounted) {
        setState(() {
          _cardItems.value = List.from(_cardItems.value)..removeAt(0);
        });
      }
      // Dispose the ad after removal
      cardItem.bannerAd?.dispose();
      _activeBannerAds.remove(cardItem.bannerAd);
      return;
    }

    final userDoc = cardItem.userDoc!;
    final otherUserId = userDoc.id;
    String action;

    switch (direction) {
      case SwipeDirection.left:
        action = 'pass';
        break;
      case SwipeDirection.right:
        action = 'smash';
        break;
      case SwipeDirection.up:
        action = 'super_like';
        // OPTIMIZATION: Use cached super likes count from stream instead of Firestore read
        if (_superLikesCount.value == 0) {
          // Trigger wiggle animation - don't advance card
          _cardKey.currentState?.triggerWiggle();
          HapticFeedback.heavyImpact();
          _showOutOfSuperLikesDialog();
          return; // Don't proceed with swipe
        }
        break;
      default:
        return;
    }

    // Add to undo stack
    _undoStack.add(cardItem);
    if (_undoStack.length > MatchScreenConstants.maxUndoStackSize) {
      _undoStack.removeAt(0);
    }

    // Increment swipe count and preload ad
    _swipeCount++;
    if (!kIsWeb &&
        _swipeCount % MatchScreenConstants.adPreloadSwipeCount == 0 &&
        _adHelper != null &&
        !_isAdReady) {
      _adHelper!.loadRewardedAd(
        onAdLoaded: () {
          if (mounted) setState(() => _isAdReady = true);
        },
        onAdFailedToLoad: (error) {
          debugPrint('Predictive ad load failed: $error');
        },
      );
    }

    _onSwipe(action, otherUserId);

    if (mounted) {
      setState(() {
        _cardItems.value = List.from(_cardItems.value)..removeAt(0);
      });
    }
  }

  void _undoLastSwipe() {
    if (_undoStack.isEmpty) return;

    final lastCard = _undoStack.removeLast();

    if (mounted) {
      setState(() {
        _cardItems.value = [lastCard, ..._cardItems.value];
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lastCard.isAd ? 'Ad restored' : 'Swipe undone'),
        duration: MatchScreenConstants.undoSnackBarDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            DesignTokens.radiusMD,
          ),
        ),
      ),
    );
  }

  void _showOutOfSuperLikesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canWatchAd = _adCooldownSeconds == 0;
            final cooldownDisplay = _adCooldownSeconds > 0
                ? '${(_adCooldownSeconds / 60).floor()}:${(_adCooldownSeconds % 60).toString().padLeft(2, '0')}'
                : null;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.star,
                    color: SemanticColors.info,
                    size: DesignTokens.iconXL,
                  ),
                  const SizedBox(width: DesignTokens.spaceSM),
                  Text(
                    "Out of Super Likes!",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Get more Super Likes to increase your match chances!",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: DesignTokens.fontSizeMD,
                        ),
                  ),
                  const SizedBox(height: DesignTokens.spaceMD),
                  if (_adHelper != null) ...[
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.spaceMD),
                      decoration: BoxDecoration(
                        color: SemanticColors.success.withOpacity(
                          DesignTokens.opacityMedium,
                        ),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusMD),
                        border: Border.all(
                          color: SemanticColors.success.withOpacity(
                            DesignTokens.opacityMedium,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            color: SemanticColors.success,
                            size: DesignTokens.iconXL,
                          ),
                          const SizedBox(width: DesignTokens.spaceMD),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Watch 30s video",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: SemanticColors.success,
                                      ),
                                ),
                                Text(
                                  "Get 1 Super Like FREE",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontSize: DesignTokens.fontSizeSM,
                                        color: SemanticColors.success,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceSM),
                  ],
                  Container(
                    padding: const EdgeInsets.all(DesignTokens.spaceMD),
                    decoration: BoxDecoration(
                      color: SemanticColors.info.withOpacity(
                        DesignTokens.opacityMedium,
                      ),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMD),
                      border: Border.all(
                        color: SemanticColors.info.withOpacity(
                          DesignTokens.opacityMedium,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          color: SemanticColors.info,
                          size: DesignTokens.iconXL,
                        ),
                        const SizedBox(width: DesignTokens.spaceMD),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Store",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: SemanticColors.info,
                                    ),
                              ),
                              Text(
                                "Buy 10 for \$4.99",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontSize: DesignTokens.fontSizeSM,
                                      color: SemanticColors.info,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                if (_adHelper != null)
                  ElevatedButton.icon(
                    onPressed: !_isAdReady || !canWatchAd
                        ? null
                        : () {
                            _adHelper!.showRewardedAd(() {
                              final currentUser =
                                  FirebaseAuth.instance.currentUser!;
                              locator<StoreRepository>()
                                  .grantAdReward(currentUser.uid);
                              setState(() {
                                _lastAdTime = DateTime.now();
                                _adCooldownSeconds = 300;
                              });
                              _startAdCooldownTimer();

                              // Close dialog and show celebration
                              Navigator.of(context).pop();

                              // Delay to ensure dialog is closed before showing celebration
                              Future.delayed(const Duration(milliseconds: 300),
                                  () {
                                // CRITICAL: Validate widget is still mounted before navigation
                                if (!mounted) return;

                                try {
                                  _showRewardCelebration();
                                } catch (e) {
                                  debugPrint('Error showing celebration: $e');
                                }
                              });
                            });
                            setDialogState(() => _isAdReady = false);
                            _adHelper!.loadRewardedAd(onAdLoaded: () {
                              if (mounted) {
                                setDialogState(() => _isAdReady = true);
                              }
                            });
                          },
                    icon: _isAdReady && canWatchAd
                        ? Icon(
                            Icons.play_arrow,
                            size: DesignTokens.iconMD,
                          )
                        : AppProgressIndicator(
                            size: DesignTokens.iconSM,
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SemanticColors.success,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusMD),
                      ),
                    ),
                    label: Text(
                      !canWatchAd && cooldownDisplay != null
                          ? 'Next in $cooldownDisplay'
                          : !_isAdReady
                              ? 'Loading...'
                              : 'Watch Free',
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () {
                    locator<NavigationService>().goBack();
                    locator<NavigationService>().navigateTo(
                      const StoreScreen(),
                      transition: PageTransition.slide,
                    );
                  },
                  icon: Icon(
                    Icons.shopping_bag,
                    size: DesignTokens.iconMD,
                  ),
                  label: const Text("Store"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SemanticColors.info,
                    side: BorderSide(
                      color: SemanticColors.info.withOpacity(0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMD),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRewardCelebration() {
    // Triple haptic for celebration
    HapticFeedback.heavyImpact();
    Future.delayed(MatchScreenConstants.hapticCelebrationDelay1, () {
      HapticFeedback.mediumImpact();
    });
    Future.delayed(MatchScreenConstants.hapticCelebrationDelay2, () {
      HapticFeedback.lightImpact();
    });

    // Show animated celebration dialog
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Theme.of(context).colorScheme.scrim.withOpacity(0.54),
      builder: (context) => const _RewardCelebrationDialog(),
    ).then((_) {
      // Show snackbar after dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MatchScreenConstants.likeColor,
            content: Row(
              children: [
                Icon(
                  Icons.star,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: DesignTokens.iconLG,
                ),
                const SizedBox(
                  width: DesignTokens.spaceMD,
                ),
                Expanded(
                  child: Text(
                    "You got +1 Super Like!",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: DesignTokens.fontSizeLG,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                DesignTokens.radiusMD,
              ),
            ),
            duration: MatchScreenConstants.snackBarDuration,
            margin: const EdgeInsets.all(
              DesignTokens.spaceMD,
            ),
          ),
        );
      }
    });
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(DesignTokens.spaceLG),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off,
                color: Theme.of(context).colorScheme.error,
                size: DesignTokens.iconXXL * 1.5,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLG),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: DesignTokens.fontSizeXL,
                    fontWeight: FontWeight.w600,
                    color: SemanticColors.textPrimary(context),
                  ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            Text(
              'Please check your connection and try again',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: DesignTokens.fontSizeMD,
                    color: SemanticColors.textSecondary(context),
                  ),
            ),
            const SizedBox(height: DesignTokens.spaceLG),
            ElevatedButton.icon(
              onPressed: _fetchPotentialMatches,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceXL,
                  vertical: DesignTokens.spaceMD,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: SemanticColors.gray300(context),
                borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppProgressIndicator(
                      strokeWidth: 3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: DesignTokens.spaceLG),
                    Text(
                      'Finding perfect matches...',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: DesignTokens.fontSizeMD,
                            color: SemanticColors.textSecondary(context),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLG),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSkeletonButton(50),
              _buildSkeletonButton(70),
              _buildSkeletonButton(50),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceLG),
        ],
      ),
    );
  }

  Widget _buildSkeletonButton(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SemanticColors.gray300(context),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(DesignTokens.spaceLG),
              decoration: BoxDecoration(
                color: SemanticColors.info.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.explore_off,
                size: DesignTokens.iconXXL * 2,
                color: SemanticColors.info,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLG),
            Text(
              'No new profiles nearby',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: DesignTokens.fontSizeXXL,
                    fontWeight: FontWeight.bold,
                    color: SemanticColors.textPrimary(context),
                  ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            Text(
              'Check back later or expand your search radius in settings',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: DesignTokens.fontSizeMD,
                    color: SemanticColors.textSecondary(context),
                  ),
            ),
            const SizedBox(height: DesignTokens.spaceXL),
            ElevatedButton.icon(
              onPressed: _fetchPotentialMatches,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceXL,
                  vertical: DesignTokens.spaceMD,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // CRITICAL: Explicit background color to prevent black screen during transitions
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocBuilder<ConnectivityBloc, ConnectivityState>(
        builder: (context, connectivityState) {
          return Stack(
            children: [
              if (_isLoading)
                _buildLoadingSkeleton()
              else if (_errorMessage != null)
                _buildErrorState()
              else
                ValueListenableBuilder<List<CardItem>>(
                  valueListenable: _cardItems,
                  builder: (context, cardItems, child) {
                    if (cardItems.isEmpty) {
                      return _buildEmptyState();
                    }
                    return Column(
                      children: [
                        // Progress indicator
                        if (cardItems.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceMD,
                              vertical: DesignTokens.spaceMD,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusMD,
                                    ),
                                    child: AppLinearProgressIndicator(
                                      value: _swipeCount /
                                          (_swipeCount + cardItems.length),
                                      backgroundColor: Colors.grey[300],
                                      color: Theme.of(context).primaryColor,
                                      minHeight: 4.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: DesignTokens.spaceMD),
                                Text(
                                  '${cardItems.length} left',
                                  style: TextStyle(
                                    fontSize: DesignTokens.fontSizeSM,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Card stack with proper padding
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              DesignTokens.spaceMD,
                              DesignTokens.spaceXS,
                              DesignTokens.spaceMD,
                              DesignTokens.spaceSM,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ...List.generate(
                                  min(cardItems.length,
                                      MatchScreenConstants.maxVisibleCards),
                                  (index) {
                                    final cardItem = cardItems[index];
                                    final isTopCard = index == 0;

                                    final card = isTopCard
                                        ? DraggableCard(
                                            key: _cardKey,
                                            onSwipe: (direction) {
                                              _removeTopCard(direction);
                                              if (_isFirstTime) {
                                                setState(
                                                    () => _isFirstTime = false);
                                              }
                                            },
                                            showTutorial:
                                                _isFirstTime && !cardItem.isAd,
                                            child: cardItem.isAd
                                                ? AdCard(
                                                    bannerAd:
                                                        cardItem.bannerAd!)
                                                : MatchCard(
                                                    userDoc: cardItem.userDoc!,
                                                    onInfoTap: () =>
                                                        _showProfileDetails(
                                                            cardItem.userDoc!),
                                                  ),
                                          )
                                        : Transform.translate(
                                            offset: Offset(
                                                0,
                                                MatchScreenConstants
                                                        .cardStackVerticalOffset *
                                                    index),
                                            child: Transform.scale(
                                              scale: 1 -
                                                  (MatchScreenConstants
                                                          .cardStackScaleFactor *
                                                      index),
                                              child: Opacity(
                                                opacity: 1 -
                                                    (MatchScreenConstants
                                                            .cardStackOpacityFactor *
                                                        index),
                                                child: cardItem.isAd
                                                    ? AdCard(
                                                        bannerAd:
                                                            cardItem.bannerAd!,
                                                        isBackground: true,
                                                      )
                                                    : MatchCard(
                                                        userDoc:
                                                            cardItem.userDoc!,
                                                        isBackground: true,
                                                      ),
                                              ),
                                            ),
                                          );

                                    return card;
                                  },
                                ).reversed.toList(),
                              ],
                            ),
                          ),
                        ),
                        _buildActionButtons(),
                        // Safe area for bottom nav bar
                        SizedBox(
                            height: MediaQuery.of(context).padding.bottom > 0
                                ? MediaQuery.of(context).padding.bottom + 8
                                : 16),
                      ],
                    );
                  },
                ),
              if (connectivityState is Offline) const OfflineOverlay(),
              // Ad loading indicator
              if (!kIsWeb && _adHelper != null && !_isAdReady)
                Positioned(
                  top: 50,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(DesignTokens.spaceSM),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.scrim.withOpacity(0.54),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusXL),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppProgressIndicator(
                          size: DesignTokens.iconXS,
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        const SizedBox(width: DesignTokens.spaceXS),
                        Text(
                          'Loading ad',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: DesignTokens.fontSizeSM,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showProfileDetails(DocumentSnapshot userDoc) {
    final userData = userDoc.data() as Map<String, dynamic>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileDetailSheet(userData: userData),
    );
  }

  Widget _buildActionButtons() {
    return Semantics(
      label: MatchScreenConstants.semanticLabelActionButtons,
      child: Padding(
        padding: const EdgeInsets.only(
          left: DesignTokens.spaceMD,
          right: DesignTokens.spaceMD,
          bottom: DesignTokens.spaceSM,
          top: DesignTokens.spaceSM,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Undo button
            AppActionButton(
              icon: Icons.replay,
              color: MatchScreenConstants.undoColor,
              label: MatchScreenConstants.labelUndo,
              tooltip: MatchScreenConstants.tooltipUndo,
              size: MatchScreenConstants.buttonSizeUndo,
              iconSize: MatchScreenConstants.iconSizeUndo,
              onPressed: _undoStack.isEmpty ? null : _handleUndoPress,
              hapticType: AppButtonHapticType.medium,
              animationDuration: MatchScreenConstants.buttonAnimationDuration,
            ),

            // Pass button
            AppActionButton(
              icon: Icons.close,
              color: MatchScreenConstants.passColor,
              label: MatchScreenConstants.labelPass,
              tooltip: MatchScreenConstants.tooltipPass,
              size: MatchScreenConstants.buttonSizePass,
              iconSize: MatchScreenConstants.iconSizePass,
              onPressed: _handlePassPress,
              hapticType: AppButtonHapticType.selection,
              animationDuration: MatchScreenConstants.buttonAnimationDuration,
            ),

            // Super Like button with reactive count
            ValueListenableBuilder<int>(
              valueListenable: _superLikesCount,
              builder: (context, superLikes, _) {
                return AppActionButton(
                  icon: Icons.star,
                  color: MatchScreenConstants.superLikeColor,
                  label: MatchScreenConstants.labelSuperLike,
                  tooltip: superLikes == 0
                      ? MatchScreenConstants.tooltipOutOfSuperLikes
                      : MatchScreenConstants.tooltipSuperLike,
                  size: MatchScreenConstants.buttonSizeSuperLike,
                  iconSize: MatchScreenConstants.iconSizeSuperLike,
                  onPressed: superLikes > 0 ? _handleSuperLikePress : null,
                  badge: superLikes > 0 ? '$superLikes' : null,
                  isDisabled: superLikes == 0,
                  isPrimary: true,
                  hapticType: AppButtonHapticType.heavy,
                  animationDuration:
                      MatchScreenConstants.buttonAnimationDuration,
                );
              },
            ),

            // Like button
            AppActionButton(
              icon: Icons.favorite,
              color: MatchScreenConstants.likeColor,
              label: MatchScreenConstants.labelLike,
              tooltip: MatchScreenConstants.tooltipLike,
              size: MatchScreenConstants.buttonSizeLike,
              iconSize: MatchScreenConstants.iconSizeLike,
              onPressed: _handleLikePress,
              hapticType: AppButtonHapticType.selection,
              animationDuration: MatchScreenConstants.buttonAnimationDuration,
            ),

            // Info button
            AppActionButton(
              icon: Icons.info_outline,
              color: MatchScreenConstants.infoColor,
              label: MatchScreenConstants.labelInfo,
              tooltip: MatchScreenConstants.tooltipInfo,
              size: MatchScreenConstants.buttonSizeInfo,
              iconSize: MatchScreenConstants.iconSizeInfo,
              onPressed: _handleInfoPress,
              hapticType: AppButtonHapticType.light,
              animationDuration: MatchScreenConstants.buttonAnimationDuration,
            ),
          ],
        ),
      ),
    );
  }

  // ========== Button Action Handlers ==========
  // Separated for better code organization and testability

  void _handleUndoPress() {
    _buttonDebouncer.call(() {
      if (_undoStack.isNotEmpty) {
        _undoLastSwipe();
      }
    });
  }

  void _handlePassPress() {
    _buttonDebouncer.call(() {
      _cardKey.currentState?.triggerSwipe(SwipeDirection.left);
    });
  }

  void _handleSuperLikePress() {
    _buttonDebouncer.call(() {
      if (_superLikesCount.value == 0) {
        // Show dialog and wiggle animation
        _cardKey.currentState?.triggerWiggle();
        _showOutOfSuperLikesDialog();
      } else {
        _cardKey.currentState?.triggerSwipe(SwipeDirection.up);
      }
    });
  }

  void _handleLikePress() {
    _buttonDebouncer.call(() {
      _cardKey.currentState?.triggerSwipe(SwipeDirection.right);
    });
  }

  void _handleInfoPress() {
    _buttonDebouncer.call(() {
      if (_cardItems.value.isNotEmpty) {
        final firstCard = _cardItems.value.first;
        if (!firstCard.isAd) {
          _showProfileDetails(firstCard.userDoc!);
        } else {
          // Show feedback for ad cards
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Swipe to continue'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  DesignTokens.radiusMD,
                ),
              ),
            ),
          );
        }
      }
    });
  }
}

// Reward Celebration Dialog
class _RewardCelebrationDialog extends StatefulWidget {
  const _RewardCelebrationDialog({Key? key}) : super(key: key);

  @override
  State<_RewardCelebrationDialog> createState() =>
      _RewardCelebrationDialogState();
}

class _RewardCelebrationDialogState extends State<_RewardCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MatchScreenConstants.celebrationDuration,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.forward();

    // Auto-dismiss after animation
    Future.delayed(MatchScreenConstants.celebrationDisplayDuration, () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value,
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceXL,
                ),
                padding: const EdgeInsets.all(DesignTokens.spaceXL),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    DesignTokens.radiusXXL,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MatchScreenConstants.likeColor.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.spaceMD),
                      decoration: BoxDecoration(
                        color: MatchScreenConstants.superLikeColor
                            .withOpacity(DesignTokens.opacityMedium),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star,
                        size: DesignTokens.iconXXL,
                        color: MatchScreenConstants.superLikeColor,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceMD),
                    const Text(
                      'Awesome!',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeXXXL,
                        fontWeight: FontWeight.bold,
                        color: MatchScreenConstants.likeColor,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceSM),
                    Text(
                      '+1 Super Like',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeXXL,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceMD),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spaceMD,
                        vertical: DesignTokens.spaceSM,
                      ),
                      decoration: BoxDecoration(
                        color: MatchScreenConstants.likeColor.withOpacity(
                          DesignTokens.opacityMedium,
                        ),
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusXL,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.celebration,
                            color: MatchScreenConstants.likeColor,
                            size: DesignTokens.iconMD,
                          ),
                          SizedBox(width: DesignTokens.spaceSM),
                          Text(
                            'Reward Unlocked!',
                            style: TextStyle(
                              color: MatchScreenConstants.likeColor,
                              fontWeight: FontWeight.w600,
                              fontSize: DesignTokens.fontSizeSM,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MatchCard extends StatefulWidget {
  final DocumentSnapshot userDoc;
  final VoidCallback? onInfoTap;
  final bool isBackground;

  const MatchCard({
    super.key,
    required this.userDoc,
    this.onInfoTap,
    this.isBackground = false,
  });

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  int _currentPhotoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userData = widget.userDoc.data() as Map<String, dynamic>;
    final photoUrl = userData['photoUrl'] ?? '';
    final username = userData['username'] ?? 'User';
    final age = userData['age'] ?? 0;
    final interests = List<String>.from(userData['interests'] ?? []);
    final bio = userData['bio'] ?? '';
    final isVerified = userData['isVerified'] ?? false;
    final occupation = userData['occupation'] ?? '';
    final distance = userData['distance'] ?? 0;
    final lastActive = userData['lastActive'];

    // Placeholder: Multiple photos (will be implemented later)
    final photos = [photoUrl];

    return Card(
      elevation: widget.isBackground ? 4 : 12,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXL)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo with gesture detection for carousel
          GestureDetector(
            onTapUp: !widget.isBackground && photos.length > 1
                ? (details) {
                    final width = context.size?.width ?? 0;
                    if (details.localPosition.dx > width / 2) {
                      setState(() {
                        _currentPhotoIndex =
                            (_currentPhotoIndex + 1) % photos.length;
                      });
                    } else {
                      setState(() {
                        _currentPhotoIndex =
                            (_currentPhotoIndex - 1 + photos.length) %
                                photos.length;
                      });
                    }
                  }
                : null,
            child: photoUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    maxHeightDiskCache: 800,
                    maxWidthDiskCache: 600,
                    memCacheHeight: 400,
                    memCacheWidth: 300,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Loading...',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.person,
                          size: 80, color: Colors.grey),
                    ),
                  )
                : Container(
                    color: Colors.grey[200],
                    child:
                        const Icon(Icons.person, size: 80, color: Colors.grey),
                  ),
          ),

          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.4, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.85),
                ],
              ),
            ),
          ),

          // Photo indicators (placeholder for multiple photos)
          if (!widget.isBackground && photos.length > 1)
            Positioned(
              top: DesignTokens.spaceMD,
              left: DesignTokens.spaceMD,
              right: DesignTokens.spaceMD,
              child: Row(
                children: List.generate(
                  photos.length,
                  (index) => Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index == _currentPhotoIndex
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Top info bar
          if (!widget.isBackground)
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                children: [
                  if (_getActiveStatus(lastActive) != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getActiveStatus(lastActive)!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: DesignTokens.fontSizeXS,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // Bottom info section
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                '$username, $age',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                        blurRadius: 10.0, color: Colors.black54)
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!widget.isBackground && widget.onInfoTap != null)
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          onPressed: widget.onInfoTap,
                        ),
                    ],
                  ),
                  if (occupation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.work_outline,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            occupation,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: DesignTokens.fontSizeMD,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (distance > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${distance.toStringAsFixed(1)} km away',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: DesignTokens.fontSizeSM,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (interests.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: interests.take(4).map((interest) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            interest,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: DesignTokens.fontSizeSM,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (bio.isNotEmpty && !widget.isBackground) ...[
                    const SizedBox(height: 12),
                    Text(
                      bio,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: DesignTokens.fontSizeSM,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _getActiveStatus(dynamic lastActive) {
    if (lastActive == null) return null;

    DateTime lastActiveTime;
    if (lastActive is Timestamp) {
      lastActiveTime = lastActive.toDate();
    } else if (lastActive is DateTime) {
      lastActiveTime = lastActive;
    } else {
      return null;
    }

    final difference = DateTime.now().difference(lastActiveTime);

    if (difference.inMinutes < 5) return 'Active now';
    if (difference.inHours < 1) return 'Active ${difference.inMinutes}m ago';
    if (difference.inHours < 24) return 'Active ${difference.inHours}h ago';

    return null;
  }
}

// Profile Detail Sheet Widget
class ProfileDetailSheet extends StatelessWidget {
  final Map<String, dynamic> userData;

  const ProfileDetailSheet({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final username = userData['username'] ?? 'User';
    final age = userData['age'] ?? 0;
    final bio = userData['bio'] ?? 'No bio available';
    final interests = List<String>.from(userData['interests'] ?? []);
    final occupation = userData['occupation'] ?? '';
    final education = userData['education'] ?? '';
    final distance = userData['distance'] ?? 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(DesignTokens.radiusXL)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      '$username, $age',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (distance > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              color: Colors.grey[600], size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${distance.toStringAsFixed(1)} km away',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 15),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bio,
                      style: TextStyle(
                          color: Colors.grey[800], fontSize: 15, height: 1.5),
                    ),
                    if (occupation.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Work',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.work_outline, color: Colors.grey[600]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              occupation,
                              style: TextStyle(
                                  color: Colors.grey[800], fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (education.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.school_outlined, color: Colors.grey[600]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              education,
                              style: TextStyle(
                                  color: Colors.grey[800], fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (interests.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Interests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: interests.map((interest) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              interest,
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 32),
                    Text(
                      '📸 Photo carousel feature coming soon!',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Ad Card Widget - Instagram-style native banner ad
class AdCard extends StatelessWidget {
  final BannerAd bannerAd;
  final bool isBackground;

  const AdCard({
    super.key,
    required this.bannerAd,
    this.isBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isBackground ? 4 : 12,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXL)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand, // Match MatchCard behavior
        children: [
          // Background
          Container(
            color: Colors.grey[50],
          ),

          // Content
          Column(
            children: [
              // "Sponsored" label
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white,
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Sponsored',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeXS,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Adaptive Banner Ad Content (Full Width)
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  child: Center(
                    child: SizedBox(
                      width: bannerAd.size.width.toDouble(),
                      height: bannerAd.size.height.toDouble(),
                      child: AdWidget(ad: bannerAd),
                    ),
                  ),
                ),
              ),

              // Swipe hint at bottom
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swipe, size: 18, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                    Text(
                      'Swipe to continue',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
