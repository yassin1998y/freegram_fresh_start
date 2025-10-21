import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/story_model.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/story_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/screens/create_story_screen.dart';
import 'package:freegram/screens/story_viewer_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';

class StoriesRailWidget extends StatefulWidget {
  const StoriesRailWidget({super.key});

  @override
  State<StoriesRailWidget> createState() => _StoriesRailWidgetState();
}

class _StoriesRailWidgetState extends State<StoriesRailWidget> {
  List<UserModel>? _friendsWithStories;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFriendsWithStories();
  }

  Future<void> _fetchFriendsWithStories() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final userRepo = locator<UserRepository>();
      final storyRepo = locator<StoryRepository>();

      final user = await userRepo.getUser(currentUser.uid);
      final friends = user.friends;

      final activeStories = await storyRepo.getFriendsWithActiveStories(friends);

      if (mounted) {
        setState(() {
          _friendsWithStories = activeStories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching stories rail: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    String? currentUserPhotoUrl = firebaseUser?.photoURL;

    if (_isLoading) {
      return const _LoadingSkeleton();
    }

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1.0),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        itemCount: (_friendsWithStories?.length ?? 0) + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _AddStoryButton(photoUrl: currentUserPhotoUrl);
          }

          final user = _friendsWithStories![index - 1];
          return _StoryAvatar(
            user: user,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StoryViewerScreen(
                    usersWithStories: _friendsWithStories!,
                    initialUser: user,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AddStoryButton extends StatelessWidget {
  final String? photoUrl;
  const _AddStoryButton({this.photoUrl});

  Future<void> _onAddStory(BuildContext context) async {
    final navigator = Navigator.of(context);

    final mediaType = await showModalBottomSheet<MediaType>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image Story'),
              onTap: () => Navigator.of(ctx).pop(MediaType.image),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video Story'),
              onTap: () => Navigator.of(ctx).pop(MediaType.video),
            ),
          ],
        ),
      ),
    );

    if (mediaType == null) return;

    final picker = ImagePicker();
    final XFile? mediaFile;
    if (mediaType == MediaType.image) {
      mediaFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    } else {
      mediaFile = await picker.pickVideo(source: ImageSource.gallery);
    }

    if (mediaFile == null) return;

    await navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreateStoryScreen(
          mediaFile: mediaFile!,
          mediaType: mediaType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onAddStory(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: SizedBox(
          width: 70,
          child: Column(
            children: [
              SizedBox(
                height: 70,
                width: 70,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(photoUrl!)
                          : null,
                      child: photoUrl == null || photoUrl!.isEmpty
                          ? const Icon(Icons.person, size: 30, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add_circle, color: Theme.of(context).primaryColor, size: 24),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text("Your Story", style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const _StoryAvatar({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: SizedBox(
          width: 70,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Theme.of(context).colorScheme.secondary, Colors.orange],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: user.photoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(user.photoUrl)
                        : null,
                    child: user.photoUrl.isEmpty
                        ? Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : '?')
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.username,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
      child: Container(
        height: 110,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          itemCount: 7,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: SizedBox(
                width: 70,
                child: Column(
                  children: [
                    const CircleAvatar(radius: 35),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 50,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

