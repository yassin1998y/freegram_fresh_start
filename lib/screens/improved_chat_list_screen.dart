// lib/screens/improved_chat_list_screen.dart
// Professional Chat List Screen with Search, Filters, and Shimmer Loading

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/repositories/chat_repository.dart';
import 'package:freegram/repositories/user_discovery_repository.dart';
import 'package:freegram/screens/improved_chat_screen.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/widgets/chat_widgets/professional_chat_list_item.dart';
import 'package:freegram/widgets/chat_widgets/shimmer_chat_skeleton.dart';
import 'package:freegram/widgets/island_popup.dart';
import 'package:freegram/widgets/freegram_app_bar.dart';
import 'package:freegram/utils/app_constants.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/common/app_button.dart';
import 'package:freegram/widgets/common/empty_state_widget.dart';

class ImprovedChatListScreen extends StatefulWidget {
  const ImprovedChatListScreen({super.key});

  @override
  State<ImprovedChatListScreen> createState() => _ImprovedChatListScreenState();
}

class _ImprovedChatListScreenState extends State<ImprovedChatListScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // Search filters
  bool _showUnreadOnly = false;
  String _sortBy = 'recent'; // recent, name, unread

  // Memoization cache for filtered/sorted chat list
  List<QueryDocumentSnapshot>? _cachedChats;
  String? _cacheKey;

  /// Extracts the other user's ID from chat data.
  ///
  /// Returns the user ID that is not the current user's ID.
  /// Returns empty string if not found.
  String _getOtherUserId(Map<String, dynamic> chatData, String currentUserId) {
    final users = chatData['users'] as List?;
    if (users == null) return '';
    final otherId = users.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    return otherId.isEmpty ? currentUserId : otherId;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 SCREEN: improved_chat_list_screen.dart');
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    // CRITICAL: Clear memoization cache to prevent memory leaks
    _cachedChats = null;
    _cacheKey = null;
    // Note: StreamBuilder automatically cancels subscriptions when disposed
    super.dispose();
  }

  void _onSearchChanged() {
    // Debounce search to reduce queries
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      // CRITICAL: Explicit background color to prevent black screen during transitions
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: FreegramAppBar(
        title: 'Chats',
        showBackButton: false,
        actions: [
          AppIconButton(
            icon: Icons.search_rounded,
            tooltip: 'Search chats',
            onPressed: () {
              // Focus search
              setState(() {
                // Search is always visible, could add focus logic here
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Enhanced search bar
            _buildSearchHeader(),

            // Filter chips
            if (_searchQuery.isNotEmpty || _showUnreadOnly) _buildFilterChips(),

            // Chat list or search results
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: theme.colorScheme.primary,
                child: _searchQuery.isEmpty
                    ? _buildChatList()
                    : _buildSearchResults(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMD,
        vertical: DesignTokens.spaceSM,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
      ),
      child: TextField(
        controller: _searchController,
        cursorColor: theme.colorScheme.primary,
        decoration: InputDecoration(
          hintText: 'Search chats...',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.primary,
            size: DesignTokens.iconLG,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _searchController.clear();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Icon(
                    Icons.cancel_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    size: 20,
                  ),
                )
              : IconButton(
                  icon: Icon(
                    _showUnreadOnly
                        ? Icons.filter_list
                        : Icons.filter_list_outlined,
                    color: _showUnreadOnly
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    size: DesignTokens.iconLG,
                  ),
                  tooltip: 'Filter',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _showUnreadOnly = !_showUnreadOnly;
                    });
                  },
                ),
          filled: true,
          fillColor: theme.colorScheme.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            borderSide: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.1),
              width: 1.0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.0,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMD,
            vertical: 12,
          ),
        ),
        style: theme.textTheme.bodyLarge,
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMD,
        vertical: DesignTokens.spaceSM,
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_showUnreadOnly)
            _buildFilterChip(
              label: 'Unread Only',
              icon: Icons.mark_email_unread,
              isActive: true,
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _showUnreadOnly = false);
              },
            ),
          const SizedBox(width: DesignTokens.spaceSM),
          _buildFilterChip(
            label: 'Recent',
            icon: Icons.access_time,
            isActive: _sortBy == 'recent',
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _sortBy = 'recent');
            },
          ),
          const SizedBox(width: DesignTokens.spaceSM),
          _buildFilterChip(
            label: 'Name',
            icon: Icons.sort_by_alpha,
            isActive: _sortBy == 'name',
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _sortBy = 'name');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: isActive
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMD,
            vertical: DesignTokens.spaceXS,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
            border: Border.all(
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.1),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive
                    ? theme.colorScheme.primary
                    : SemanticColors.textSecondary(context),
              ),
              const SizedBox(width: DesignTokens.spaceXS),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isActive
                      ? theme.colorScheme.primary
                      : SemanticColors.textSecondary(context),
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final chatRepository = locator<ChatRepository>();

    return StreamBuilder<QuerySnapshot>(
      stream: chatRepository.getChatsStream(currentUser.uid),
      builder: (context, chatSnapshot) {
        if (chatSnapshot.connectionState == ConnectionState.waiting) {
          return const ShimmerChatSkeleton();
        }

        if (chatSnapshot.hasError) {
          return _buildErrorState('Error loading chats');
        }

        if (!chatSnapshot.hasData || chatSnapshot.data!.docs.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.chat_bubble_outline,
            title: 'No Messages Yet',
            subtitle: 'Start a conversation with a friend!',
            actionLabel: 'Find Friends',
          );
        }

        var chats = chatSnapshot.data!.docs;
        final chatsType = chats; // Preserve type for memoization

        // Memoization: Check if we can reuse cached filtered/sorted results
        final cacheKey = '${_showUnreadOnly}_${_sortBy}_${chats.length}';
        if (cacheKey == _cacheKey &&
            _cachedChats != null &&
            _cachedChats!.length == chats.length) {
          chats = _cachedChats!;
        } else {
          // Preserve original type for processing
          chats = chatsType;
          // Optimized: Cache chat data to avoid repeated Map parsing
          final chatDataCache = <DocumentSnapshot, Map<String, dynamic>>{};
          for (var chat in chats) {
            chatDataCache[chat] = chat.data() as Map<String, dynamic>;
          }

          // Apply filters
          // Optimized: Use cached data instead of calling chat.data() multiple times
          if (_showUnreadOnly) {
            chats = chats.where((chat) {
              final data = chatDataCache[chat]!;
              final unreadFor = data['unreadFor'] as List? ?? [];
              return unreadFor.contains(currentUser.uid);
            }).toList();
          }

          // Apply sorting
          // Optimized: Pre-compute sort keys to avoid O(n²) complexity
          if (_sortBy == 'name') {
            // Pre-compute other user IDs and names once for all chats
            final chatSortData = chats.map((chat) {
              final data = chatDataCache[chat]!;
              final otherUserId = _getOtherUserId(data, currentUser.uid);
              final usernames =
                  data['usernames'] as Map<String, dynamic>? ?? {};
              final otherUserName = usernames[otherUserId] ?? '';
              return (chat: chat, sortKey: otherUserName);
            }).toList();

            // Sort using pre-computed keys
            chatSortData.sort((a, b) => a.sortKey.compareTo(b.sortKey));

            // Extract sorted chats
            chats = chatSortData.map((entry) => entry.chat).toList();
          }

          // Update cache
          _cachedChats = chats;
          _cacheKey = cacheKey;
        }

        if (chats.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.mark_chat_unread_outlined,
            title: 'No Unread Chats',
            subtitle: 'All caught up! You have no unread messages.',
          );
        }

        return ListView.builder(
          itemCount: chats.length +
              (chats.length >= AppConstants.chatListLoadMoreThreshold
                  ? 1
                  : 0), // Add 1 for "load more" indicator
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            // Show "Load More" message if at end and there might be more chats
            if (index == chats.length &&
                chats.length >= AppConstants.chatListLoadMoreThreshold) {
              return Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMD),
                child: Center(
                  child: Column(
                    children: [
                      const Divider(),
                      const SizedBox(height: DesignTokens.spaceSM),
                      Text(
                        'Showing ${chats.length} most recent chats',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: SemanticColors.textSecondary(context),
                              fontSize: DesignTokens.fontSizeMD,
                            ),
                      ),
                      const SizedBox(height: DesignTokens.spaceXS),
                      Text(
                        'Scroll up to see older chats as needed',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: SemanticColors.textSecondary(context),
                              fontSize: DesignTokens.fontSizeSM,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RepaintBoundary(
              child: ProfessionalChatListItem(
                chat: chats[index],
                currentUserId: currentUser.uid,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    final userDiscoveryRepository = locator<UserDiscoveryRepository>();
    final chatRepository = locator<ChatRepository>();
    final currentUser = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<QuerySnapshot>(
      stream: userDiscoveryRepository.searchUsers(_searchQuery),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppProgressIndicator(strokeWidth: 2));
        }

        if (!userSnapshot.hasData || userSnapshot.data!.docs.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.search_off,
            title: 'No Users Found',
            subtitle: 'Try searching with a different username.',
          );
        }

        final users = userSnapshot.data!.docs
            .where((doc) => doc.id != currentUser.uid)
            .toList();

        if (users.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.search_off,
            title: 'No Users Found',
            subtitle: 'Try searching with a different username.',
          );
        }

        return ListView.builder(
          itemCount: users.length,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final userDoc = users[index];
            final user = UserModel.fromDoc(userDoc);

            return _buildSearchResultTile(user, chatRepository);
          },
        );
      },
    );
  }

  Widget _buildSearchResultTile(UserModel user, ChatRepository chatRepository) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          HapticFeedback.lightImpact();

          // Show loading
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: AppProgressIndicator(),
            ),
          );

          try {
            final chatId = await chatRepository.startOrGetChat(
              user.id,
              user.username,
            );

            if (mounted) {
              locator<NavigationService>().goBack(); // Close loading
              locator<NavigationService>().navigateTo(
                ImprovedChatScreen(
                  chatId: chatId,
                  otherUsername: user.username,
                ),
                transition: PageTransition.slide,
              );
            }
          } catch (e) {
            if (mounted) {
              Navigator.of(context).pop(); // Close loading
              showIslandPopup(
                context: context,
                message: 'Failed to open chat: $e',
                icon: Icons.error_outline,
              );
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMD,
            vertical: DesignTokens.spaceSM,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                width: DesignTokens.borderWidthHairline,
              ),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: AvatarSize.medium.radius,
                backgroundImage: user.photoUrl.isNotEmpty
                    ? NetworkImage(user.photoUrl)
                    : null,
                child: user.photoUrl.isEmpty
                    ? Text(
                        user.username.isNotEmpty
                            ? user.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: DesignTokens.fontSizeLG,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: DesignTokens.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: DesignTokens.spaceXS / 2),
                    Text(
                      'Tap to message',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: SemanticColors.textSecondary(context),
                            fontSize: DesignTokens.fontSizeSM,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: SemanticColors.iconDefault(context),
                size: DesignTokens.iconLG,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: DesignTokens.iconXXL * 1.6,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: DesignTokens.spaceMD),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: SemanticColors.textSecondary(context),
                  fontSize: DesignTokens.fontSizeLG,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();

    // Show feedback
    showIslandPopup(
      context: context,
      message: 'Refreshed!',
      icon: Icons.check_circle,
    );

    // Wait a bit for visual feedback
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
