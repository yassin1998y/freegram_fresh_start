import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/comments_screen.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:video_player/video_player.dart';

class ReelPlayerWidget extends StatefulWidget {
  final DocumentSnapshot post;

  const ReelPlayerWidget({super.key, required this.post});

  @override
  State<ReelPlayerWidget> createState() => _ReelPlayerWidgetState();
}

class _ReelPlayerWidgetState extends State<ReelPlayerWidget>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _isHeartAnimating = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final PostRepository _postRepository = locator<PostRepository>();
  final UserRepository _userRepository = locator<UserRepository>();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // FIX: This method now plays videos from the cache.
  Future<void> _initializePlayer() async {
    final postData = widget.post.data() as Map<String, dynamic>;
    final videoUrl = postData['imageUrl'];

    if (videoUrl == null || videoUrl.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Get the video file from the cache.
      // If not cached, it will be downloaded automatically.
      final fileInfo = await DefaultCacheManager().getFileFromCache(videoUrl);

      if (fileInfo != null && mounted) {
        // If the file exists in the cache, play it from the local file.
        _videoPlayerController = VideoPlayerController.file(fileInfo.file);
      } else {
        // As a fallback, stream from the network and cache it simultaneously.
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      }

      await _videoPlayerController.initialize();

      if (mounted) {
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController,
            autoPlay: true,
            looping: true,
            showControls: false,
            aspectRatio: _videoPlayerController.value.aspectRatio,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error initializing video player: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike({bool forceLike = false}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final postData = widget.post.data() as Map<String, dynamic>;

    if (forceLike) {
      final likesSnapshot =
      await _postRepository.getPostLikesStream(widget.post.id).first;
      final userHasLiked =
      likesSnapshot.docs.any((doc) => doc.id == currentUser.uid);
      if (userHasLiked) return;
    }

    try {
      await _postRepository.togglePostLike(
        postId: widget.post.id,
        userId: currentUser.uid,
        postOwnerId: postData['userId'],
        postImageUrl: postData['imageUrl'],
        currentUserData: {
          'displayName': currentUser.displayName,
          'photoURL': currentUser.photoURL,
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    }
  }

  Future<void> _onDoubleTap() async {
    setState(() => _isHeartAnimating = true);
    _animationController.forward();
    await _toggleLike(forceLike: true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      _animationController.reverse();
      setState(() => _isHeartAnimating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chewieController == null) {
      return const Center(
          child: Text("Could not load video.",
              style: TextStyle(color: Colors.white)));
    }

    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Chewie(controller: _chewieController!),
          _buildOverlay(),
          Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isHeartAnimating ? 1 : 0,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 100,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    final postData = widget.post.data() as Map<String, dynamic>;
    final String username = postData['username'] ?? 'Anonymous';
    final String userId = postData['userId'] ?? '';
    final String caption = postData['caption'] ?? '';
    final currentUser = FirebaseAuth.instance.currentUser;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.transparent,
                Colors.black.withOpacity(0.7)
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
        Positioned(
          top: 40,
          left: 16,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ProfileScreen(userId: userId))),
                          child: Row(
                            children: [
                              StreamBuilder<UserModel>(
                                stream: _userRepository.getUserStream(userId),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Colors.grey);
                                  }
                                  final user = snapshot.data!;
                                  return CircleAvatar(
                                    radius: 20,
                                    backgroundImage: user.photoUrl.isNotEmpty
                                        ? CachedNetworkImageProvider(
                                        user.photoUrl)
                                        : null,
                                    child: user.photoUrl.isEmpty
                                        ? Text(username.isNotEmpty
                                        ? username[0].toUpperCase()
                                        : 'A')
                                        : null,
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              Text(
                                username,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (caption.isNotEmpty)
                          Text(
                            caption,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream:
                        _postRepository.getPostLikesStream(widget.post.id),
                        builder: (context, snapshot) {
                          final likesCount = snapshot.data?.docs.length ?? 0;
                          final userHasLiked = snapshot.data?.docs.any(
                                  (doc) => doc.id == currentUser?.uid) ??
                              false;
                          return _ReelActionButton(
                            icon: userHasLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            label: likesCount.toString(),
                            color: userHasLiked ? Colors.red : Colors.white,
                            onTap: () => _toggleLike(),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      StreamBuilder<QuerySnapshot>(
                        stream: _postRepository
                            .getPostCommentsStream(widget.post.id),
                        builder: (context, snapshot) {
                          final commentsCount =
                              snapshot.data?.docs.length ?? 0;
                          return _ReelActionButton(
                            icon: Icons.chat_bubble_outline,
                            label: commentsCount.toString(),
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      CommentsScreen(postId: widget.post.id)));
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _ReelActionButton(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Share feature coming soon!')),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _ReelActionButton(
                        icon: Icons.more_horiz,
                        label: '',
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReelActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ReelActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: [
                  const Shadow(blurRadius: 2, color: Colors.black87)
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}

