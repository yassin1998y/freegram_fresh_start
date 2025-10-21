import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/screens/reels_viewer_screen.dart';
import 'package:shimmer/shimmer.dart';

// FIX: The class name has been corrected from StoriesRailWidget to ReelsRailWidget
class ReelsRailWidget extends StatefulWidget {
  const ReelsRailWidget({super.key});

  @override
  State<ReelsRailWidget> createState() => _ReelsRailWidgetState();
}

class _ReelsRailWidgetState extends State<ReelsRailWidget> {
  List<DocumentSnapshot>? _reels;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndPrecacheReels();
  }

  Future<void> _fetchAndPrecacheReels() async {
    try {
      final querySnapshot = await locator<PostRepository>().getReelPosts(limit: 7);
      final reels = querySnapshot.docs;

      if (mounted) {
        setState(() {
          _reels = reels;
          _isLoading = false;
        });
        _precacheReels(reels);
      }
    } catch (e) {
      debugPrint("Error fetching reels for rail: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _precacheReels(List<DocumentSnapshot> reels) {
    for (var reelDoc in reels.take(3)) {
      final postData = reelDoc.data() as Map<String, dynamic>?;
      final videoUrl = postData?['imageUrl'];
      if (videoUrl != null && videoUrl is String && videoUrl.isNotEmpty) {
        DefaultCacheManager().downloadFile(videoUrl);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            "Recent Reels",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 180,
          child: _isLoading
              ? const _LoadingSkeleton()
              : (_reels == null || _reels!.isEmpty)
              ? const SizedBox.shrink()
              : ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: _reels!.length,
            itemBuilder: (context, index) {
              final reel = _reels![index];
              return _ReelThumbnail(post: reel);
            },
          ),
        ),
      ],
    );
  }
}

class _ReelThumbnail extends StatelessWidget {
  final DocumentSnapshot post;
  const _ReelThumbnail({required this.post});

  @override
  Widget build(BuildContext context) {
    final postData = post.data() as Map<String, dynamic>;
    final thumbnailUrl = postData['thumbnailUrl'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => ReelsViewerScreen(initialPost: post)),
        );
      },
      child: Hero(
        tag: post.id,
        child: Container(
          width: 110,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumbnailUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey[300]),
                    errorWidget: (context, url, error) =>
                    const Icon(Icons.error),
                  )
                else
                  Container(
                    color: Colors.blueGrey[900],
                    child: const Icon(Icons.video_collection,
                        color: Colors.white, size: 40),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.play_arrow, color: Colors.white),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Text(
                    postData['username'] ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
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

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            width: 110,
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      ),
    );
  }
}
