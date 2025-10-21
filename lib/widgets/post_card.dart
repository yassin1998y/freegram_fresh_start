import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/post_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/chat_screen.dart'; // Contains FullScreenImageScreen
import 'package:freegram/screens/comments_screen.dart';
import 'package:freegram/screens/post_detail_screen.dart';
import 'package:freegram/screens/profile_screen.dart';
import 'package:freegram/screens/reels_viewer_screen.dart';
import 'package:freegram/theme/app_theme.dart';

class PostCard extends StatefulWidget {
  final DocumentSnapshot post;
  final bool isDetailView;

  const PostCard({
    super.key,
    required this.post,
    this.isDetailView = false,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with TickerProviderStateMixin {
  bool _isHeartAnimating = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isTextExpanded = false;

  final PostRepository _postRepository = locator<PostRepository>();
  final UserRepository _userRepository = locator<UserRepository>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLike() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Trigger heart animation
    setState(() => _isHeartAnimating = true);
    _animationController.forward().then((_) {
      _animationController.reverse().then((_) {
        if (mounted) setState(() => _isHeartAnimating = false);
      });
    });

    final user = await _userRepository.getUser(currentUser.uid);
    await _postRepository.togglePostLike(
      postId: widget.post.id,
      userId: currentUser.uid,
      postOwnerId: widget.post['userId'],
      postImageUrl: widget.post['imageUrl'],
      currentUserData: user.toMap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final postData = widget.post.data() as Map<String, dynamic>;
    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isReel = postData['postType'] == 'reel';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostHeader(postData: postData),
          if (postData['caption'] != null &&
              (postData['caption'] as String).isNotEmpty)
            _PostCaption(
              caption: postData['caption'],
              isExpanded: _isTextExpanded,
              onToggle: () => setState(() => _isTextExpanded = !_isTextExpanded),
            ),
          GestureDetector(
            onDoubleTap: _handleLike,
            onTap: () {
              if (isReel && !widget.isDetailView) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ReelsViewerScreen(initialPost: widget.post)));
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                _PostMedia(
                  imageUrl: postData['imageUrl'],
                  isReel: isReel,
                  isDetailView: widget.isDetailView,
                ),
                if (_isHeartAnimating)
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 100,
                      shadows: [Shadow(blurRadius: 20, color: Colors.black54)],
                    ),
                  ),
              ],
            ),
          ),
          _PostStats(
            postId: widget.post.id,
            onCommentTap: () {
              if (widget.isDetailView) return;
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PostDetailScreen(postSnapshot: widget.post)));
            },
          ),
          const Divider(height: 1),
          _PostActions(
            onLike: _handleLike,
            onComment: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CommentsScreen(postId: widget.post.id))),
            onShare: () {},
            postId: widget.post.id,
            currentUser: currentUser,
          ),
        ],
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  final Map<String, dynamic> postData;
  const _PostHeader({required this.postData});

  @override
  Widget build(BuildContext context) {
    final timestamp = postData['timestamp'] as Timestamp?;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: FutureBuilder<UserModel>(
        future: locator<UserRepository>().getUser(postData['userId']),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Row(children: [
              CircleAvatar(radius: 18, backgroundColor: Theme.of(context).dividerColor),
              const SizedBox(width: 12),
              Container(height: 16, width: 100, color: Theme.of(context).dividerColor),
            ]);
          }
          final user = snapshot.data!;
          return Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: user.id))),
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: user.photoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(user.photoUrl)
                      : null,
                  child: user.photoUrl.isEmpty ? Text(user.username[0]) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.username, style: Theme.of(context).textTheme.titleMedium),
                    if (timestamp != null)
                      Text(
                        timeago.format(timestamp.toDate()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () {},
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PostCaption extends StatelessWidget {
  final String caption;
  final bool isExpanded;
  final VoidCallback onToggle;
  const _PostCaption({required this.caption, required this.isExpanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: GestureDetector(
        onTap: onToggle,
        child: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              TextSpan(
                text: caption,
                style: const TextStyle(fontWeight: FontWeight.normal),
              ),
            ],
          ),
          maxLines: isExpanded ? 100 : 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}


class _PostMedia extends StatelessWidget {
  final String imageUrl;
  final bool isReel;
  final bool isDetailView;

  const _PostMedia({required this.imageUrl, required this.isReel, required this.isDetailView});

  @override
  Widget build(BuildContext context) {
    if (isReel && !isDetailView) {
      return Stack(
        alignment: Alignment.center,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            height: 400,
            width: double.infinity,
          ),
          Container(
            height: 400,
            width: double.infinity,
            color: Colors.black.withOpacity(0.3),
          ),
          const Icon(Icons.play_arrow, color: Colors.white, size: 60),
        ],
      );
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FullScreenImageScreen(imageUrl: imageUrl))),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 300,
          color: Theme.of(context).dividerColor,
        ),
      ),
    );
  }
}

class _PostStats extends StatelessWidget {
  final String postId;
  final VoidCallback onCommentTap;

  const _PostStats({required this.postId, required this.onCommentTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: locator<PostRepository>().getPostLikesStream(postId),
      builder: (context, likesSnapshot) {
        final likesCount = likesSnapshot.data?.docs.length ?? 0;
        return StreamBuilder<QuerySnapshot>(
            stream: locator<PostRepository>().getPostCommentsStream(postId, limit: 1),
            builder: (context, commentsSnapshot) {
              final commentsCount = commentsSnapshot.data?.docs.length ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    if (likesCount > 0)
                      Text(
                        '$likesCount J\'aime${likesCount > 1 ? 's' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    const Spacer(),
                    if (commentsCount > 0)
                      GestureDetector(
                        onTap: onCommentTap,
                        child: Text(
                          '$commentsCount Commentaire${commentsCount > 1 ? 's' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              );
            });
      },
    );
  }
}


class _PostActions extends StatelessWidget {
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final String postId;
  final User? currentUser;

  const _PostActions({
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.postId,
    this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: locator<PostRepository>().getPostLikesStream(postId),
      builder: (context, snapshot) {
        final userHasLiked = snapshot.data?.docs.any((doc) => doc.id == currentUser?.uid) ?? false;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ActionButton(
              icon: userHasLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
              label: 'J\'aime',
              color: userHasLiked ? SonarPulseTheme.primaryAccent : Theme.of(context).iconTheme.color,
              onPressed: onLike,
            ),
            _ActionButton(
              icon: Icons.chat_bubble_outline,
              label: 'Commenter',
              onPressed: onComment,
            ),
            _ActionButton(
              icon: Icons.share_outlined,
              label: 'Partager',
              onPressed: onShare,
            ),
          ],
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).iconTheme.color;
    return Expanded(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: effectiveColor, size: 20),
        label: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: effectiveColor)),
        style: TextButton.styleFrom(
            foregroundColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 12.0)
        ),
      ),
    );
  }
}