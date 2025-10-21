import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/story_model.dart';
import 'package:freegram/repositories/story_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class CreateStoryScreen extends StatefulWidget {
  final XFile mediaFile;
  final MediaType mediaType;

  const CreateStoryScreen({
    super.key,
    required this.mediaFile,
    required this.mediaType,
  });

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == MediaType.video) {
      _initializeVideoPlayer();
    }
  }

  Future<void> _initializeVideoPlayer() async {
    _videoController = VideoPlayerController.file(File(widget.mediaFile.path));
    await _videoController!.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: true,
      showControls: false,
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _postStory() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final storyRepository = locator<StoryRepository>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await storyRepository.createStory(
        mediaFile: widget.mediaFile,
        mediaType: widget.mediaType,
      );
      messenger.showSnackBar(const SnackBar(
        content: Text('Story posted successfully!'),
        backgroundColor: Colors.green,
      ));
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Failed to post story: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildMediaPreview() {
    if (widget.mediaType == MediaType.image) {
      return Image.file(File(widget.mediaFile.path), fit: BoxFit.contain);
    } else {
      if (_chewieController != null && _videoController!.value.isInitialized) {
        return Chewie(controller: _chewieController!);
      }
      return const Center(child: CircularProgressIndicator());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Center(child: _buildMediaPreview()),
          Positioned(
            bottom: 30,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _postStory,
              icon: const Icon(Icons.arrow_upward),
              label: const Text('Post to Story'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text("Posting Story...", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

