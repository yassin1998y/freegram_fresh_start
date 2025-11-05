// lib/widgets/feed_widgets/ad_card.dart

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:freegram/services/ad_service.dart';
import 'package:shimmer/shimmer.dart';

/// Widget to display native ads in the feed, styled to match PostCard
class AdCard extends StatefulWidget {
  final String? adCacheKey;

  const AdCard({
    Key? key,
    this.adCacheKey,
  }) : super(key: key);

  @override
  State<AdCard> createState() => _AdCardState();
}

class _AdCardState extends State<AdCard> {
  BannerAd? _bannerAd;
  bool _isLoading = true;
  bool _isLoaded = false;
  final AdService _adService = AdService();

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    setState(() {
      _isLoading = true;
      _isLoaded = false;
    });

    try {
      final ad = await _adService.loadNativeAd(
        cacheKey: widget.adCacheKey,
        onAdLoaded: () {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdCard: Failed to load ad: ${error.message}');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isLoaded = false;
            });
          }
        },
      );

      if (ad != null && mounted) {
        setState(() {
          _bannerAd = ad;
          _isLoading = false;
          _isLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('AdCard: Error loading ad: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoaded = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Note: We don't dispose the ad here if it's cached
    // The AdService will handle disposal when clearing cache
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show shimmer/skeleton while loading
    if (_isLoading) {
      return _buildLoadingSkeleton();
    }

    // Show error state or empty if failed to load
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink(); // Hide failed ads
    }

    // Show the ad
    return _buildAdCard();
  }

  Widget _buildLoadingSkeleton() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 20, backgroundColor: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 16,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 12,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 14,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 14,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with "Sponsored" label
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Sponsored',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          // Ad content (BannerAd styled as native)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: SizedBox(
              height: 250, // Medium rectangle size
              width: double.infinity,
              child: AdWidget(ad: _bannerAd!),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
