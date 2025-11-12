// lib/screens/page_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/repositories/page_repository.dart';
import 'package:freegram/repositories/user_repository.dart';
import 'package:freegram/models/page_model.dart';
import 'package:freegram/widgets/feed_widgets/post_card.dart';
import 'package:freegram/models/feed_item_model.dart';
import 'package:freegram/screens/page_settings_screen.dart';
import 'package:freegram/services/page_analytics_service.dart';
import 'package:freegram/services/cloudinary_service.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class PageProfileScreen extends StatefulWidget {
  final String pageId;

  const PageProfileScreen({
    Key? key,
    required this.pageId,
  }) : super(key: key);

  @override
  State<PageProfileScreen> createState() => _PageProfileScreenState();
}

class _PageProfileScreenState extends State<PageProfileScreen>
    with SingleTickerProviderStateMixin {
  final PageRepository _pageRepository = locator<PageRepository>();
  final UserRepository _userRepository = locator<UserRepository>();
  final _auth = FirebaseAuth.instance;

  PageModel? _page;
  bool _isLoading = true;
  bool _isLoadingFollow = false;
  bool _isUploadingImage = false;
  late TabController _tabController;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: page_profile_screen.dart');
    _tabController = TabController(length: 4, vsync: this);
    _loadPage();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    setState(() => _isLoading = true);

    try {
      final page = await _pageRepository.getPage(widget.pageId);
      if (page == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Page not found'),
              backgroundColor: SemanticColors.error,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      final currentUser = _auth.currentUser;

      // Track profile view (analytics)
      if (currentUser != null) {
        final analyticsService = locator<PageAnalyticsService>();
        analyticsService.trackProfileView(widget.pageId, currentUser.uid);
      }

      setState(() {
        _page = page;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading page: $e'),
            backgroundColor: SemanticColors.error,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow(bool currentState) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || _page == null) return;

    setState(() => _isLoadingFollow = true);

    try {
      if (currentState) {
        await _pageRepository.unfollowPage(widget.pageId, currentUser.uid);
      } else {
        await _pageRepository.followPage(widget.pageId, currentUser.uid);
      }

      // Refresh page data to get updated follower count
      final updatedPage = await _pageRepository.getPage(widget.pageId);
      if (updatedPage != null && mounted) {
        setState(() {
          _page = updatedPage;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: SemanticColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFollow = false);
      }
    }
  }

  bool _isUserAdmin() {
    final currentUser = _auth.currentUser;
    if (currentUser == null || _page == null) return false;
    return _page!.isAdmin(currentUser.uid);
  }

  Future<void> _pickCoverImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      await _uploadCoverImage(image);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: SemanticColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      await _uploadProfileImage(image);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: SemanticColors.error,
          ),
        );
      }
    }
  }

  Future<void> _uploadCoverImage(XFile imageFile) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || _page == null) return;

    setState(() => _isUploadingImage = true);

    try {
      // Show uploading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                AppProgressIndicator(
                  size: DesignTokens.iconMD,
                  strokeWidth: 2,
                  color: Colors.white,
                ),
                SizedBox(width: DesignTokens.spaceMD),
                Text('Uploading cover image...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Upload image
      final imageUrl = await CloudinaryService.uploadImageFromXFile(
        imageFile,
        onProgress: (progress) {
          // You could show progress here if needed
        },
      );

      if (imageUrl == null) {
        throw Exception('Failed to upload image');
      }

      // Update page
      await _pageRepository.updatePage(
        pageId: widget.pageId,
        userId: currentUser.uid,
        coverImageUrl: imageUrl,
      );

      // Reload page
      await _loadPage();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cover image updated successfully!'),
            backgroundColor: SemanticColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading cover image: $e'),
            backgroundColor: SemanticColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _uploadProfileImage(XFile imageFile) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || _page == null) return;

    setState(() => _isUploadingImage = true);

    try {
      // Show uploading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                AppProgressIndicator(
                  size: DesignTokens.iconMD,
                  strokeWidth: 2,
                  color: Colors.white,
                ),
                SizedBox(width: DesignTokens.spaceMD),
                Text('Uploading profile picture...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Upload image
      final imageUrl = await CloudinaryService.uploadImageFromXFile(
        imageFile,
        onProgress: (progress) {
          // You could show progress here if needed
        },
      );

      if (imageUrl == null) {
        throw Exception('Failed to upload image');
      }

      // Update page
      await _pageRepository.updatePage(
        pageId: widget.pageId,
        userId: currentUser.uid,
        profileImageUrl: imageUrl,
      );

      // Reload page
      await _loadPage();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: SemanticColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading profile picture: $e'),
            backgroundColor: SemanticColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Page',
            style: theme.textTheme.titleLarge,
          ),
        ),
        body: Center(
          child: AppProgressIndicator(
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    if (_page == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Page',
            style: theme.textTheme.titleLarge,
          ),
        ),
        body: Center(
          child: Text(
            'Page not found',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: SemanticColors.error,
            ),
          ),
        ),
      );
    }

    final isAdmin = _isUserAdmin();
    final currentUser = _auth.currentUser;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Header Section (SliverAppBar with cover image)
            SliverAppBar(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              backgroundColor: theme.colorScheme.surface,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover Image
                    _page!.coverImageUrl != null &&
                            _page!.coverImageUrl!.isNotEmpty
                        ? Image.network(
                            _page!.coverImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: theme.colorScheme.surface,
                              );
                            },
                          )
                        : Container(
                            color: theme.colorScheme.surface,
                          ),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                    // Edit Cover Button (admin only) - positioned at bottom-right
                    if (isAdmin)
                      Positioned(
                        bottom: DesignTokens.spaceMD,
                        right: DesignTokens.spaceMD,
                        child: Material(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radiusMD,
                          ),
                          child: InkWell(
                            onTap: _isUploadingImage ? null : _pickCoverImage,
                            borderRadius: BorderRadius.circular(
                              DesignTokens.radiusMD,
                            ),
                            child: Container(
                              padding:
                                  const EdgeInsets.all(DesignTokens.spaceSM),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: DesignTokens.iconMD,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                if (isAdmin)
                  IconButton(
                    icon: Icon(
                      Icons.settings,
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PageSettingsScreen(pageId: widget.pageId),
                        ),
                      );
                      // Reload page if settings were updated
                      if (result == true) {
                        _loadPage();
                      }
                    },
                  ),
              ],
            ),
          ];
        },
        body: Column(
          children: [
            // Info Block Section
            Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Avatar positioned above content (not in SliverAppBar)
                  Row(
                    children: [
                      // Profile Avatar
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: DesignTokens.avatarSizeLarge / 2,
                            backgroundColor: theme.colorScheme.surface,
                            child: CircleAvatar(
                              radius: (DesignTokens.avatarSizeLarge / 2) - 2,
                              backgroundImage: _page!.profileImageUrl.isNotEmpty
                                  ? NetworkImage(_page!.profileImageUrl)
                                  : null,
                              child: _page!.profileImageUrl.isEmpty
                                  ? Icon(
                                      Icons.business,
                                      size: DesignTokens.avatarSizeLarge / 2,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(
                                              DesignTokens.opacityMedium),
                                    )
                                  : null,
                            ),
                          ),
                          // Edit Profile Picture Button (admin only)
                          if (isAdmin)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Material(
                                color: theme.colorScheme.primary,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  onTap: _isUploadingImage
                                      ? null
                                      : _pickProfileImage,
                                  customBorder: const CircleBorder(),
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                        DesignTokens.spaceXS),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: theme.colorScheme.onPrimary,
                                      size: DesignTokens.iconSM,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: DesignTokens.spaceMD),
                      // Page Name and Handle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _page!.pageName,
                                    style: theme.textTheme.headlineSmall,
                                  ),
                                ),
                                if (_page!.verificationStatus ==
                                    VerificationStatus.verified) ...[
                                  const SizedBox(width: DesignTokens.spaceSM),
                                  Icon(
                                    Icons.verified,
                                    color: theme.colorScheme.primary,
                                    size: DesignTokens.iconLG,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: DesignTokens.spaceXS),
                            Text(
                              '@${_page!.pageHandle}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(DesignTokens.opacityMedium),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.spaceMD),
                  // Follower Count
                  Text(
                    '${_page!.followerCount} followers',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withOpacity(DesignTokens.opacityMedium),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceMD),
                  // Action Buttons Row
                  Row(
                    children: [
                      // Follow/Following Button (FutureBuilder)
                      if (currentUser != null && !isAdmin)
                        FutureBuilder<bool>(
                          future: _userRepository.isFollowingPage(
                            currentUser.uid,
                            widget.pageId,
                          ),
                          builder: (context, snapshot) {
                            final isFollowing = snapshot.data ?? false;

                            if (_isLoadingFollow) {
                              return SizedBox(
                                width: 100,
                                height: DesignTokens.buttonHeight,
                                child: Center(
                                  child: AppProgressIndicator(
                                    size: DesignTokens.iconMD,
                                    strokeWidth: 2,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              );
                            }

                            if (isFollowing) {
                              // Following Button (OutlinedButton)
                              return Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _toggleFollow(true),
                                  icon: const Icon(
                                    Icons.check,
                                    size: DesignTokens.iconSM,
                                  ),
                                  label: Text(
                                    'Following',
                                    style: theme.textTheme.labelLarge,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        theme.colorScheme.onSurface,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: DesignTokens.spaceMD,
                                      vertical: DesignTokens.spaceSM,
                                    ),
                                    minimumSize: const Size(
                                      0,
                                      DesignTokens.buttonHeight,
                                    ),
                                    side: BorderSide(
                                      color: theme.colorScheme.outline,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        DesignTokens.radiusMD,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              // Follow Button (FilledButton)
                              return Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _toggleFollow(false),
                                  icon: const Icon(
                                    Icons.add,
                                    size: DesignTokens.iconSM,
                                  ),
                                  label: Text(
                                    'Follow',
                                    style: theme.textTheme.labelLarge,
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor:
                                        theme.colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: DesignTokens.spaceMD,
                                      vertical: DesignTokens.spaceSM,
                                    ),
                                    minimumSize: const Size(
                                      0,
                                      DesignTokens.buttonHeight,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        DesignTokens.radiusMD,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      const SizedBox(width: DesignTokens.spaceSM),
                      // Message Button (IconButton)
                      if (currentUser != null && !isAdmin)
                        IconButton(
                          icon: const Icon(
                            Icons.message_outlined,
                            size: DesignTokens.iconMD,
                          ),
                          onPressed: () {
                            // TODO: Navigate to page message screen
                          },
                          style: IconButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurface,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // TabBar
            TabBar(
              controller: _tabController,
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(
                DesignTokens.opacityMedium,
              ),
              tabs: const [
                Tab(
                  icon: Icon(
                    Icons.article_outlined,
                    size: DesignTokens.iconMD,
                  ),
                  text: 'Posts',
                ),
                Tab(
                  icon: Icon(
                    Icons.info_outline,
                    size: DesignTokens.iconMD,
                  ),
                  text: 'About',
                ),
                Tab(
                  icon: Icon(
                    Icons.storefront_outlined,
                    size: DesignTokens.iconMD,
                  ),
                  text: 'Shop',
                ),
                Tab(
                  icon: Icon(
                    Icons.event_outlined,
                    size: DesignTokens.iconMD,
                  ),
                  text: 'Events',
                ),
              ],
            ),
            // TabBarView
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPostsTab(),
                  _buildAboutTab(),
                  _buildShopTab(),
                  _buildEventsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsTab() {
    final theme = Theme.of(context);

    return FutureBuilder(
      future: _pageRepository.getPagePosts(pageId: widget.pageId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: AppProgressIndicator(
              color: theme.colorScheme.primary,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: DesignTokens.iconXXL,
                  color: SemanticColors.error,
                ),
                const SizedBox(height: DesignTokens.spaceMD),
                Text(
                  'Error: ${snapshot.error}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: SemanticColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.post_add,
                  size: DesignTokens.iconXXL,
                  color: theme.colorScheme.onSurface.withOpacity(
                    DesignTokens.opacityMedium,
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceMD),
                Text(
                  'No posts yet',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(
                      DesignTokens.opacityMedium,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return PostCard(
              item: PostFeedItem(
                post: posts[index],
                displayType: PostDisplayType.page,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAboutTab() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_page!.description.isNotEmpty) ...[
            Text(
              'About',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            Text(
              _page!.description,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: DesignTokens.spaceLG),
          ],
          if (_page!.category.isNotEmpty) ...[
            Text(
              'Category',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            Chip(
              label: Text(_page!.category),
              avatar: Icon(
                _page!.pageType == PageType.business
                    ? Icons.business
                    : _page!.pageType == PageType.creator
                        ? Icons.person
                        : Icons.group,
                size: DesignTokens.iconSM,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLG),
          ],
          if (_page!.website != null && _page!.website!.isNotEmpty) ...[
            Text(
              'Website',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            InkWell(
              onTap: () async {
                final uri = Uri.parse(_page!.website!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not open ${_page!.website}'),
                        backgroundColor: SemanticColors.error,
                      ),
                    );
                  }
                }
              },
              child: Row(
                children: [
                  Icon(
                    Icons.link,
                    size: DesignTokens.iconSM,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: DesignTokens.spaceSM),
                  Expanded(
                    child: Text(
                      _page!.website!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLG),
          ],
          if (_page!.contactEmail != null &&
              _page!.contactEmail!.isNotEmpty) ...[
            Text(
              'Contact Email',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            Row(
              children: [
                Icon(
                  Icons.email_outlined,
                  size: DesignTokens.iconSM,
                  color: theme.colorScheme.onSurface.withOpacity(
                    DesignTokens.opacityMedium,
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceSM),
                Expanded(
                  child: Text(
                    _page!.contactEmail!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceLG),
          ],
          if (_page!.contactPhone != null &&
              _page!.contactPhone!.isNotEmpty) ...[
            Text(
              'Contact Phone',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            Row(
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: DesignTokens.iconSM,
                  color: theme.colorScheme.onSurface.withOpacity(
                    DesignTokens.opacityMedium,
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceSM),
                Expanded(
                  child: Text(
                    _page!.contactPhone!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceLG),
          ],
        ],
      ),
    );
  }

  Widget _buildShopTab() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: DesignTokens.iconXXL,
            color: theme.colorScheme.onSurface.withOpacity(
              DesignTokens.opacityMedium,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMD),
          Text(
            'Shop Coming Soon',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(
                DesignTokens.opacityMedium,
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceSM),
          Text(
            'This feature will be available soon!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(
                DesignTokens.opacityMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_outlined,
            size: DesignTokens.iconXXL,
            color: theme.colorScheme.onSurface.withOpacity(
              DesignTokens.opacityMedium,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMD),
          Text(
            'Events Coming Soon',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(
                DesignTokens.opacityMedium,
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceSM),
          Text(
            'This feature will be available soon!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(
                DesignTokens.opacityMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
