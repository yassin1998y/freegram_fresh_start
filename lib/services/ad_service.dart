// lib/services/ad_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_helper.dart';

/// Service for loading and caching banner ads styled as native ads for feed integration
/// Note: Using BannerAd instead of NativeAd to avoid platform-specific factory requirements
class AdService {
  // Cache for loaded banner ads (used as native-style ads)
  final Map<String, BannerAd> _adCache = {};
  final Map<String, bool> _isLoading = {};
  final Map<String, Completer<BannerAd?>> _loadingCompleters = {};

  /// Load a banner ad styled as native ad with caching support
  /// Returns the BannerAd object on success, or null on failure
  Future<BannerAd?> loadNativeAd({
    String? cacheKey,
    VoidCallback? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) async {
    final key = cacheKey ?? 'default';

    // Check if already cached
    if (_adCache.containsKey(key) && _adCache[key] != null) {
      debugPrint('📦 AdService: Returning cached ad (key: $key)');
      onAdLoaded?.call();
      return _adCache[key];
    }

    // Check if already loading
    if (_isLoading[key] == true) {
      debugPrint('⏳ AdService: Ad already loading (key: $key), waiting...');
      final completer = Completer<BannerAd?>();
      _loadingCompleters[key] = completer;
      return completer.future;
    }

    _isLoading[key] = true;
    final completer = Completer<BannerAd?>();
    _loadingCompleters[key] = completer;

    debugPrint(
        '🔄 AdService: Loading banner ad (styled as native) (key: $key)...');

    final ad = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: AdSize.mediumRectangle, // 300x250 - good for card display
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ AdService: Ad loaded successfully (key: $key)');
          final bannerAd = ad as BannerAd;
          _adCache[key] = bannerAd;
          _isLoading[key] = false;

          // Complete all waiting completers
          completer.complete(bannerAd);
          for (final waitingCompleter in _loadingCompleters.values) {
            if (!waitingCompleter.isCompleted) {
              waitingCompleter.complete(bannerAd);
            }
          }
          _loadingCompleters.clear();

          onAdLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
              '❌ AdService: Ad failed to load (key: $key): ${error.message} (Code: ${error.code})');
          ad.dispose();
          _isLoading[key] = false;

          // Complete all waiting completers with null
          completer.complete(null);
          for (final waitingCompleter in _loadingCompleters.values) {
            if (!waitingCompleter.isCompleted) {
              waitingCompleter.complete(null);
            }
          }
          _loadingCompleters.clear();

          onAdFailedToLoad?.call(error);
        },
        onAdOpened: (ad) {
          debugPrint('📖 AdService: Ad opened');
        },
        onAdClosed: (ad) {
          debugPrint('🚪 AdService: Ad closed');
        },
        onAdImpression: (ad) {
          debugPrint('👁️ AdService: Ad impression recorded');
        },
      ),
    );

    ad.load();
    return completer.future;
  }

  /// Preload multiple ads for feed
  Future<List<BannerAd>> preloadAds({
    required int count,
    VoidCallback? onAllLoaded,
  }) async {
    debugPrint('🔄 AdService: Preloading $count ads...');
    final List<Future<BannerAd?>> futures = [];

    for (int i = 0; i < count; i++) {
      futures.add(loadNativeAd(cacheKey: 'ad_$i'));
    }

    final results = await Future.wait(futures);
    final loadedAds = results.whereType<BannerAd>().toList();

    debugPrint('✅ AdService: Preloaded ${loadedAds.length}/$count ads');
    onAllLoaded?.call();

    return loadedAds;
  }

  /// Get a cached ad or load a new one
  BannerAd? getCachedAd(String? cacheKey) {
    final key = cacheKey ?? 'default';
    return _adCache[key];
  }

  /// Dispose a specific ad
  void disposeAd(String? cacheKey) {
    final key = cacheKey ?? 'default';
    _adCache[key]?.dispose();
    _adCache.remove(key);
  }

  /// Dispose all cached ads
  void disposeAll() {
    debugPrint('🧹 AdService: Disposing all cached ads');
    for (final ad in _adCache.values) {
      ad.dispose();
    }
    _adCache.clear();
    _isLoading.clear();
    _loadingCompleters.clear();
  }

  /// Clear cache but keep ads loaded (useful for refresh)
  void clearCache() {
    _adCache.clear();
  }
}
