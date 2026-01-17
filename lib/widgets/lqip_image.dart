import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:freegram/services/cloudinary_service.dart';

/// A widget that displays an image with a Low-Quality Image Placeholder (LQIP)
/// It loads a tiny, blurry version first (from Cloudinary) and then
/// fades in the full-quality image over it.
class LQIPImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  const LQIPImage({
    Key? key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<LQIPImage> createState() => _LQIPImageState();
}

class _LQIPImageState extends State<LQIPImage> {
  // We don't use a simple boolean, but rather the 'key' of the
  // CachedNetworkImage provider to know when the full image is loaded.
  // This is a more reliable method.
  final ValueNotifier<bool> _isFullImageLoaded = ValueNotifier(false);
  
  // Track placeholder URL to use (starts with blur, falls back to non-blur)
  String? _placeholderUrl;
  String? _lastImageUrl; // Track image URL to reset state when it changes

  @override
  void dispose() {
    _isFullImageLoaded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions as fallback for infinity/NaN values
    final screenSize = MediaQuery.of(context).size;
    
    // Helper function to safely convert double to int, handling infinity/NaN
    int? safeToInt(double? value) {
      if (value == null) return null;
      if (!value.isFinite) return null; // Return null for infinity/NaN
      return value.toInt();
    }
    
    // Get valid width and height, using screen size as fallback for infinity
    final validWidth = (widget.width != null && widget.width!.isFinite) 
        ? widget.width 
        : (widget.width == double.infinity ? screenSize.width : null);
    final validHeight = (widget.height != null && widget.height!.isFinite) 
        ? widget.height 
        : (widget.height == double.infinity ? screenSize.height : null);
    
    // 1. Generate the LQIP URL using the centralized CloudinaryService
    // Low quality (60), 20px wide, with blur effect
    final lqipUrl = CloudinaryService.getOptimizedImageUrl(
      widget.imageUrl,
      quality: ImageQuality.thumbnail, // Low quality (60)
      width: 20, // 20px wide for tiny placeholder
    );

    // Add blur transformation if it's a Cloudinary URL
    String lqipUrlWithBlur = lqipUrl;
    if (lqipUrl.contains('res.cloudinary.com') && lqipUrl.contains('/upload/')) {
      try {
        // Cloudinary URL structure after getOptimizedImageUrl:
        // .../upload/f_auto,q_60,w_20/v1762455072/jpvebukkcrrkgo8cb16q.jpg
        // Or original: .../upload/v1762455072/jpvebukkcrrkgo8cb16q.jpg
        
        // Find /upload/ and the next / after it
        final uploadIndex = lqipUrl.indexOf('/upload/');
        if (uploadIndex != -1) {
          final afterUploadIndex = uploadIndex + 8; // Length of '/upload/'
          final nextSlashIndex = lqipUrl.indexOf('/', afterUploadIndex);
          
          if (nextSlashIndex != -1) {
            // Extract the part between /upload/ and next /
            final betweenUploadAndSlash = lqipUrl.substring(afterUploadIndex, nextSlashIndex);
            
            // Check if this is a version (starts with 'v') or transformations
            if (betweenUploadAndSlash.startsWith('v')) {
              // No transformations, insert blur before version
              lqipUrlWithBlur = '${lqipUrl.substring(0, afterUploadIndex)}e_blur:300/${lqipUrl.substring(afterUploadIndex)}';
            } else {
              // Has transformations (f_auto,q_60,w_20), append blur
              lqipUrlWithBlur = '${lqipUrl.substring(0, nextSlashIndex)},e_blur:300${lqipUrl.substring(nextSlashIndex)}';
            }
          } else {
            // No slash after /upload/, unlikely but handle it
            lqipUrlWithBlur = '$lqipUrl,e_blur:300';
          }
        }
      } catch (e) {
        // If URL parsing fails, use original URL without blur
        debugPrint('LQIPImage: Error adding blur transformation: $e');
        lqipUrlWithBlur = lqipUrl;
      }
    }

    // 2. Generate the full-quality URL using the centralized CloudinaryService
    // Pass through dimensions for optimization (safely handle infinity/NaN)
    final fullImageUrl = CloudinaryService.getOptimizedImageUrl(
      widget.imageUrl,
      width: safeToInt(validWidth),
      height: safeToInt(validHeight),
    );

    // Reset placeholder URL if image URL changed
    if (_lastImageUrl != widget.imageUrl) {
      _placeholderUrl = lqipUrlWithBlur;
      _lastImageUrl = widget.imageUrl;
      _isFullImageLoaded.value = false; // Reset full image loaded state
    }
    // Initialize placeholder URL on first build
    _placeholderUrl ??= lqipUrlWithBlur;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. The Blurry Placeholder
        // This image loads first and stays in the background.
        // Falls back to non-blur URL if blur fails
        CachedNetworkImage(
          imageUrl: _placeholderUrl!,
          fit: widget.fit,
          width: validWidth,
          height: validHeight,
          filterQuality: FilterQuality.low,
          errorWidget: (context, url, error) {
            // If blur URL failed and we haven't tried fallback yet, try non-blur
            if (_placeholderUrl == lqipUrlWithBlur && lqipUrlWithBlur != lqipUrl) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _placeholderUrl = lqipUrl;
                  });
                }
              });
              // Show loading state while switching to fallback
              return Container(
                color: Colors.grey[200],
                child: const SizedBox.shrink(),
              );
            }
            // Final fallback: colored placeholder
            return Container(
              color: Colors.grey[300],
              child: const SizedBox.shrink(),
            );
          },
          placeholder: (context, url) => Container(
            color: Colors.grey[200],
            child: const SizedBox.shrink(),
          ),
        ),

        // 2. The Full Quality Image (fades in)
        // This loads the *real* image. When it's done, it will
        // notify the ValueListenable, which fades it in.
        ValueListenableBuilder<bool>(
          valueListenable: _isFullImageLoaded,
          builder: (context, isLoaded, child) {
            return AnimatedOpacity(
              opacity: isLoaded ? 1.0 : 0.0, // Fade in when loaded
              duration: const Duration(milliseconds: 300),
              child: child,
            );
          },
          child: CachedNetworkImage(
            imageUrl: fullImageUrl,
            fit: widget.fit,
            width: validWidth,
            height: validHeight,
            // This is the key: we get a callback when the image is loaded
            // from the network or cache.
            imageBuilder: (context, imageProvider) {
              // Image is loaded! Notify the listener to fade in.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if(mounted) {
                  _isFullImageLoaded.value = true;
                }
              });
              return Image(
                image: imageProvider,
                fit: widget.fit,
              );
            },
            // Show nothing while it's loading (the placeholder is visible)
            placeholder: (context, url) => const SizedBox.shrink(),
            // If the full image fails, just keep showing the placeholder
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

