import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/story_model.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/story_repository.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<UserModel> usersWithStories;
  final UserModel initialUser;

  const StoryViewerScreen({
    super.key,
    required this.usersWithStories,
    required this.initialUser,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  VideoPlayerController? _videoController;

  int _currentUserIndex = 0;
  int _currentStoryIndex = 0;
  List<List<Story>> _allStories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUserIndex = widget.usersWithStories.indexWhere((u) => u.id == widget.initialUser.id);
    if (_currentUserIndex == -1) _currentUserIndex = 0;

    _pageController = PageController(initialPage: _currentUserIndex);
    _animationController = AnimationController(vsync: this)..addStatusListener((status) {
      if(status == AnimationStatus.completed) {
        _onAnimationCompleted();
      }
    });

    _fetchAllStories();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _fetchAllStories() async {
    final storyRepo = locator<StoryRepository>();
    List<List<Story>> storiesData = [];
    for (var user in widget.usersWithStories) {
      final userStories = await storyRepo.getUserStories(user.id);
      storiesData.add(userStories);
    }
    if(mounted) {
      setState(() {
        _allStories = storiesData;
        _isLoading = false;
      });
      _loadStory(story: _allStories[_currentUserIndex][_currentStoryIndex]);
    }
  }

  void _onPageChanged(int index) {
    _animationController.stop();
    _animationController.reset();
    _videoController?.dispose();
    _videoController = null;
    if(mounted) {
      setState(() {
        _currentUserIndex = index;
        _currentStoryIndex = 0;
      });
      _loadStory(story: _allStories[_currentUserIndex][_currentStoryIndex]);
    }
  }

  void _onTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    if (dx < screenWidth * 0.3) {
      _previousStory();
    } else if (dx > screenWidth * 0.7) {
      _nextStory();
    }
  }

  void _nextStory() {
    if (_currentStoryIndex + 1 < _allStories[_currentUserIndex].length) {
      if(mounted) setState(() => _currentStoryIndex++);
      _loadStory(story: _allStories[_currentUserIndex][_currentStoryIndex]);
    } else {
      _nextUser();
    }
  }

  void _previousStory() {
    if (_currentStoryIndex - 1 >= 0) {
      if(mounted) setState(() => _currentStoryIndex--);
      _loadStory(story: _allStories[_currentUserIndex][_currentStoryIndex]);
    } else {
      _previousUser();
    }
  }

  void _nextUser() {
    if (_currentUserIndex + 1 < widget.usersWithStories.length) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousUser() {
    if (_currentUserIndex - 1 >= 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onAnimationCompleted() {
    _nextStory();
  }

  void _loadStory({required Story story}) {
    locator<StoryRepository>().markStoryAsViewed(story.id);
    _animationController.stop();
    _animationController.reset();

    if (story.mediaType == MediaType.video) {
      _videoController?.dispose();
      _videoController = VideoPlayerController.networkUrl(Uri.parse(story.mediaUrl))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _animationController.duration = _videoController!.value.duration;
            _videoController!.play();
            _animationController.forward();
          }
        });
    } else {
      _animationController.duration = const Duration(seconds: 5);
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
        onTapDown: _onTapDown,
        onLongPress: () => _animationController.stop(),
        onLongPressUp: () => _animationController.forward(),
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: widget.usersWithStories.length,
          itemBuilder: (context, userIndex) {
            if (_allStories[userIndex].isEmpty) {
              return const Center(child: Text("No stories for this user.", style: TextStyle(color: Colors.white)));
            }
            final story = _allStories[userIndex][_currentStoryIndex];
            final user = widget.usersWithStories[userIndex];
            return Stack(
              fit: StackFit.expand,
              children: [
                _buildMediaDisplay(story),
                _buildOverlay(user, _allStories[userIndex]),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMediaDisplay(Story story) {
    if (story.mediaType == MediaType.image) {
      return CachedNetworkImage(
        imageUrl: story.mediaUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, color: Colors.white)),
      );
    } else {
      if (_videoController != null && _videoController!.value.isInitialized) {
        return FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildOverlay(UserModel user, List<Story> stories) {
    return Positioned(
      top: 40,
      left: 10,
      right: 10,
      child: Column(
        children: [
          Row(
            children: List.generate(stories.length, (index) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: StoryProgressBar(
                    animationController: _animationController,
                    isCurrent: index == _currentStoryIndex,
                    isViewed: index < _currentStoryIndex,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(user.photoUrl),
            ),
            title: Text(user.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              DateFormat('h:mm a').format(stories[_currentStoryIndex].timestamp),
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class StoryProgressBar extends StatelessWidget {
  final AnimationController animationController;
  final bool isCurrent;
  final bool isViewed;

  const StoryProgressBar({
    super.key,
    required this.animationController,
    required this.isCurrent,
    required this.isViewed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(2),
      ),
      child: isCurrent
          ? AnimatedBuilder(
        animation: animationController,
        builder: (context, child) {
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: animationController.value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        },
      )
          : (isViewed
          ? Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
        ),
      )
          : const SizedBox.shrink()),
    );
  }
}

