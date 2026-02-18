import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'dart:io' show Platform;

/// A professional helper class to manage loading and showing rewarded ads with enhanced error handling.
class AdHelper {
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  int _loadAttempts = 0;
  DateTime? _lastLoadAttempt;
  static const int maxLoadAttempts = 3;
  static const Duration loadRetryDelay = Duration(seconds: 30);

  // Native banner ads for feed integration
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  bool get isAdReady => _isAdLoaded && _rewardedAd != null;
  bool get isLoading => _isLoading;
  bool get isBannerReady => _isBannerLoaded && _bannerAd != null;
  BannerAd? get bannerAd => _bannerAd;

  // ============================================================================
  // AD CONFIGURATION - READS FROM .env FILE
  // ============================================================================
  //
  // Configuration is managed in the .env file at project root
  // To update ad IDs, edit the .env file (NOT this file!)
  //
  // HOW TO GET YOUR REAL AD UNIT IDs:
  // 1. Go to: https://apps.admob.google.com/
  // 2. Select your app (or create one if you haven't)
  // 3. Go to "Ad units" in the left sidebar
  // 4. Create 2 ad units:
  //    a) "Rewarded" ad unit (for free super likes)
  //    b) "Banner" ad unit with size "Banner (Adaptive)" (for feed ads - higher CPM!)
  // 5. Copy the ad unit IDs and paste them in .env file
  //
  // PRODUCTION RELEASE: Set USE_TEST_ADS=false in .env file!
  // ============================================================================

  // Read test mode from environment
  static bool get _useTestAds {
    final useTestAds = dotenv.env['USE_TEST_ADS']?.toLowerCase() ?? 'true';
    return useTestAds == 'true' || useTestAds == '1';
  }

  // Test ad unit IDs (Google's official test IDs)
  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIOS =
      'ca-app-pub-3940256099942544/1712485313';
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIOS = 'ca-app-pub-3940256099942544/2934735716';

  static String get rewardedAdUnitId {
    if (_useTestAds) {
      // TEST MODE - Using Google's test ad IDs
      debugPrint('📱 AdHelper: Using TEST rewarded ad');
      return (!kIsWeb && Platform.isAndroid)
          ? _testRewardedAndroid
          : _testRewardedIOS;
    } else {
      // PRODUCTION MODE - Using real ad IDs from .env
      final adId = (!kIsWeb && Platform.isAndroid)
          ? dotenv.env['ADMOB_REWARDED_ANDROID']
          : dotenv.env['ADMOB_REWARDED_IOS'];

      if (adId == null || adId.isEmpty || adId.contains('XXXXXXXX')) {
        debugPrint(
            '⚠️ WARNING: Production rewarded ad ID not configured in .env!');
        debugPrint('⚠️ Falling back to test ads. Please update .env file.');
        return (!kIsWeb && Platform.isAndroid)
            ? _testRewardedAndroid
            : _testRewardedIOS;
      }

      debugPrint('💰 AdHelper: Using PRODUCTION rewarded ad');
      return adId;
    }
  }

  static String get bannerAdUnitId {
    if (_useTestAds) {
      // TEST MODE - Using Google's test ad IDs
      debugPrint('📱 AdHelper: Using TEST banner ad');
      return (!kIsWeb && Platform.isAndroid)
          ? _testBannerAndroid
          : _testBannerIOS;
    } else {
      // PRODUCTION MODE - Using real ad IDs from .env
      final adId = (!kIsWeb && Platform.isAndroid)
          ? dotenv.env['ADMOB_BANNER_ANDROID']
          : dotenv.env['ADMOB_BANNER_IOS'];

      if (adId == null || adId.isEmpty || adId.contains('XXXXXXXX')) {
        debugPrint(
            '⚠️ WARNING: Production banner ad ID not configured in .env!');
        debugPrint('⚠️ Falling back to test ads. Please update .env file.');
        return (!kIsWeb && Platform.isAndroid)
            ? _testBannerAndroid
            : _testBannerIOS;
      }

      debugPrint('💰 AdHelper: Using PRODUCTION banner ad');
      return adId;
    }
  }

  /// Loads a rewarded ad with enhanced error handling and retry logic.
  void loadRewardedAd({
    VoidCallback? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
    bool forceReload = false,
  }) {
    // Prevent multiple simultaneous loads
    if (_isLoading && !forceReload) {
      debugPrint('Ad is already loading, skipping duplicate load request');
      return;
    }

    // Check if already loaded
    if (_isAdLoaded && _rewardedAd != null && !forceReload) {
      debugPrint('Ad already loaded and ready');
      onAdLoaded?.call();
      return;
    }

    // Implement retry delay to prevent rapid failed attempts
    if (_lastLoadAttempt != null && !forceReload) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastLoadAttempt!);
      if (timeSinceLastAttempt < loadRetryDelay &&
          _loadAttempts >= maxLoadAttempts) {
        debugPrint('Too many recent load attempts, waiting before retry');
        final remainingDelay = loadRetryDelay - timeSinceLastAttempt;
        Future.delayed(remainingDelay, () {
          _loadAttempts = 0;
          loadRewardedAd(
            onAdLoaded: onAdLoaded,
            onAdFailedToLoad: onAdFailedToLoad,
          );
        });
        return;
      }
    }

    _isLoading = true;
    _lastLoadAttempt = DateTime.now();
    _loadAttempts++;

    debugPrint(
        'Loading rewarded ad (attempt $_loadAttempts/$maxLoadAttempts)...');

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✓ Rewarded ad loaded successfully');
          _rewardedAd = ad;
          _isAdLoaded = true;
          _isLoading = false;
          _loadAttempts = 0; // Reset on success

          // Set up fullscreen callbacks immediately
          _setupAdCallbacks();

          onAdLoaded?.call();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint(
              '✗ Rewarded ad failed to load: ${error.message} (Code: ${error.code})');
          _isAdLoaded = false;
          _isLoading = false;

          onAdFailedToLoad?.call(error);

          // Automatic retry with exponential backoff
          if (_loadAttempts < maxLoadAttempts) {
            final retryDelay = Duration(seconds: _loadAttempts * 5);
            debugPrint('Retrying ad load in ${retryDelay.inSeconds}s...');
            Future.delayed(retryDelay, () {
              loadRewardedAd(
                onAdLoaded: onAdLoaded,
                onAdFailedToLoad: onAdFailedToLoad,
              );
            });
          } else {
            debugPrint('Max load attempts reached, will retry after delay');
          }
        },
      ),
    );
  }

  /// Sets up callbacks for fullscreen ad content
  void _setupAdCallbacks() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('Rewarded ad showed fullscreen content');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Rewarded ad dismissed');
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        // Preload next ad
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('✗ Rewarded ad failed to show: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        // Try loading a new ad
        loadRewardedAd();
      },
      onAdImpression: (ad) {
        debugPrint('Rewarded ad impression recorded');
      },
    );
  }

  /// Shows the loaded rewarded ad with enhanced error handling.
  Future<bool> showRewardedAd(Function() onReward) async {
    if (!_isAdLoaded || _rewardedAd == null) {
      debugPrint('✗ Rewarded ad is not ready to be shown');
      // Attempt to load if not already loading
      if (!_isLoading) {
        loadRewardedAd();
      }
      return false;
    }

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          debugPrint('✓ User earned reward: ${reward.amount} ${reward.type}');
          onReward();
        },
      );

      _rewardedAd = null;
      _isAdLoaded = false;
      return true;
    } catch (e) {
      debugPrint('✗ Error showing rewarded ad: $e');
      _rewardedAd?.dispose();
      _rewardedAd = null;
      _isAdLoaded = false;
      return false;
    }
  }

  /// Loads a banner ad for native feed integration
  void loadBannerAd({
    VoidCallback? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    if (_isBannerLoaded && _bannerAd != null) {
      debugPrint('Banner ad already loaded');
      onAdLoaded?.call();
      return;
    }

    debugPrint('Loading banner ad...');

    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.mediumRectangle, // 300x250 - good for card-like display
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✓ Banner ad loaded successfully');
          _isBannerLoaded = true;
          _bannerAd = ad as BannerAd;
          onAdLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('✗ Banner ad failed to load: ${error.message}');
          ad.dispose();
          _bannerAd = null;
          _isBannerLoaded = false;
          onAdFailedToLoad?.call(error);
        },
        onAdOpened: (ad) {
          debugPrint('Banner ad opened');
        },
        onAdClosed: (ad) {
          debugPrint('Banner ad closed');
        },
        onAdImpression: (ad) {
          debugPrint('Banner ad impression recorded');
        },
      ),
    );

    _bannerAd!.load();
  }

  /// Creates a new banner ad instance (for multiple ads in feed)
  /// Uses adaptive banners that scale to screen width for maximum revenue
  Future<BannerAd?> createBannerAd({required int width}) async {
    debugPrint('🎬 [AdHelper] createBannerAd() called with width: $width');
    debugPrint(
        '🔑 [AdHelper] Ad Unit ID: ${bannerAdUnitId.substring(0, 20)}...');

    // Get optimal adaptive banner size for this screen width
    final AdSize? adSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);

    if (adSize == null) {
      debugPrint(
          '⚠️ [AdHelper] Adaptive size unavailable, using MediumRectangle (300x250)');
      final completer = Completer<BannerAd?>();

      final bannerAd = BannerAd(
        adUnitId: bannerAdUnitId,
        size: AdSize.mediumRectangle,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            debugPrint(
                '✅ [AdHelper] MediumRectangle banner ad LOADED successfully');
            completer.complete(ad as BannerAd);
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint(
                '❌ [AdHelper] MediumRectangle ad FAILED: ${error.message} (Code: ${error.code})');
            debugPrint('💡 [AdHelper] Error domain: ${error.domain}');
            if (error.code == 3) {
              debugPrint(
                  '📝 [AdHelper] Code 3 = NO_FILL: No ad inventory available');
            }
            ad.dispose();
            completer.complete(null);
          },
        ),
      );

      debugPrint('🔄 [AdHelper] Calling bannerAd.load()...');
      bannerAd.load();
      return completer.future;
    }

    debugPrint(
        '📐 [AdHelper] Adaptive size obtained: ${adSize.width}x${adSize.height}');
    final completer = Completer<BannerAd?>();

    final bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint(
              '✅ [AdHelper] Adaptive banner ad LOADED successfully (${adSize.width}x${adSize.height})');
          completer.complete(ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
              '❌ [AdHelper] Adaptive ad FAILED: ${error.message} (Code: ${error.code})');
          debugPrint('💡 [AdHelper] Error domain: ${error.domain}');
          if (error.code == 3) {
            debugPrint(
                '📝 [AdHelper] Code 3 = NO_FILL: No ad inventory available');
            debugPrint(
                '💡 [AdHelper] Common causes: Test ads, new AdMob account, low eCPM region');
          }
          ad.dispose();
          completer.complete(null);
        },
      ),
    );

    debugPrint('🔄 [AdHelper] Calling bannerAd.load()...');
    bannerAd.load();
    return completer.future;
  }

  /// Disposes of the current ad and cleans up resources
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;
    _isLoading = false;

    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerLoaded = false;
  }

  /// Resets the ad helper state
  void reset() {
    dispose();
    _loadAttempts = 0;
    _lastLoadAttempt = null;
  }

  /// Dispose a specific banner ad
  void disposeBannerAd(BannerAd? ad) {
    ad?.dispose();
  }
}
