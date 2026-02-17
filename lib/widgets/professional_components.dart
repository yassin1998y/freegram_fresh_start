import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/models/user_model.dart';
import 'package:freegram/blocs/friends_bloc/friends_bloc.dart';
import 'package:freegram/blocs/connectivity_bloc.dart';
import 'package:freegram/services/sonar/local_cache_service.dart';
import 'package:freegram/services/sonar/sonar_controller.dart';
import 'package:freegram/repositories/chat_repository.dart';
import 'package:freegram/services/navigation_service.dart';
import 'package:freegram/navigation/app_routes.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/widgets/island_popup.dart';
import 'package:freegram/widgets/common/app_progress_indicator.dart';
import 'package:freegram/widgets/common/app_button.dart';

/// Professional Status Chip Component
/// Displays status with glassmorphic design and animations
class ProfessionalStatusChip extends StatefulWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final bool isActive;
  final VoidCallback? onTap;

  const ProfessionalStatusChip({
    super.key,
    required this.label,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.isActive = false,
    this.onTap,
  });

  @override
  State<ProfessionalStatusChip> createState() => _ProfessionalStatusChipState();
}

class _ProfessionalStatusChipState extends State<ProfessionalStatusChip>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AnimationTokens.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AnimationTokens.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _handleTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceMD,
                vertical: DesignTokens.spaceSM,
              ),
              decoration: BoxDecoration(
                color: widget.backgroundColor ??
                    (widget.isActive
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
                border: Border.all(
                  color: widget.isActive
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: DesignTokens.elevation1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: DesignTokens.iconSM,
                      color: widget.textColor ?? Colors.white,
                    ),
                    const SizedBox(width: DesignTokens.spaceXS),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: widget.textColor ?? Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: DesignTokens.fontSizeSM,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Professional User Card Component
/// Optimized with proper aspect ratio, animations, and accessibility
class ProfessionalUserCard extends StatefulWidget {
  final String username;
  final String? photoUrl;
  final String? statusMessage;
  final int genderValue;
  final bool isNew;
  final bool isRecentlyActive;
  final bool isProfileSynced;
  final int rssi;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final UserModel? userModel;
  final String? badgeUrl;

  const ProfessionalUserCard({
    super.key,
    required this.username,
    this.photoUrl,
    this.statusMessage,
    required this.genderValue,
    this.isNew = false,
    this.isRecentlyActive = false,
    this.isProfileSynced = true,
    required this.rssi,
    this.onTap,
    this.onDelete,
    this.userModel,
    this.badgeUrl,
  });

  @override
  State<ProfessionalUserCard> createState() => _ProfessionalUserCardState();
}

class _ProfessionalUserCardState extends State<ProfessionalUserCard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _waveAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _waveAnimation;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AnimationTokens.fast,
      vsync: this,
    );
    _waveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AnimationTokens.easeInOut,
    ));

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _waveAnimationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _handleTapCancel() {
    _animationController.reverse();
  }

  void _triggerWaveAnimation() {
    _waveAnimationController.forward().then((_) {
      _waveAnimationController.reverse();
    });
  }

  void _showUserActions(BuildContext context) {
    if (widget.userModel == null) {
      widget.onTap?.call();
      return;
    }

    final friendsBloc = context.read<FriendsBloc>();
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scaffoldColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => BlocProvider.value(
        value: friendsBloc,
        child: _UserActionsModal(
          user: widget.userModel!,
          onTap: widget.onTap ?? () {},
          modalContext: modalContext,
          onWaveAnimation: _triggerWaveAnimation,
        ),
      ),
    );
  }

  Widget _buildGenderPlaceholder() {
    IconData iconData = Icons.person_outline;
    Color iconColor = Colors.grey.shade600;
    Color backgroundColor = Colors.grey.shade200;

    if (widget.genderValue == 1) {
      iconData = Icons.male;
      iconColor = Colors.blue.shade600;
      backgroundColor = Colors.blue.shade50;
    } else if (widget.genderValue == 2) {
      iconData = Icons.female;
      iconColor = Colors.pink.shade600;
      backgroundColor = Colors.pink.shade50;
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLG),
      ),
      child: Center(
        child: Icon(
          iconData,
          size: DesignTokens.iconXXL,
          color: iconColor,
        ),
      ),
    );
  }

  int _getProximityBars(int rssi) {
    if (rssi >= -50) return 4; // Excellent - 4 bars
    if (rssi >= -60) return 3; // Good - 3 bars
    if (rssi >= -70) return 2; // Fair - 2 bars
    if (rssi >= -80) return 1; // Poor - 1 bar
    return 0; // Very poor - 0 bars
  }

  Color _getSignalColor(int rssi) {
    if (rssi >= -50) return SemanticColors.success; // Green
    if (rssi >= -60) return const Color(0xFF10B981); // Light green
    if (rssi >= -70) return SemanticColors.warning; // Orange
    if (rssi >= -80) return const Color(0xFFF59E0B); // Light orange
    return SemanticColors.error; // Red
  }

  Widget _buildConnectionQuality() {
    final bars = _getProximityBars(widget.rssi);
    final signalColor = _getSignalColor(widget.rssi);

    return Positioned(
      top: DesignTokens.spaceSM,
      left: DesignTokens.spaceSM,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceSM,
          vertical: DesignTokens.spaceXS,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (index) {
            final isActive = index < bars;
            final barHeight =
                (index + 1) * 3.0; // Progressive heights: 3, 6, 9, 12

            return Padding(
              padding:
                  EdgeInsets.only(right: index < 3 ? DesignTokens.spaceXS : 0),
              child: AnimatedContainer(
                duration: AnimationTokens.fast,
                curve: AnimationTokens.easeInOut,
                width: 3,
                height: barHeight,
                decoration: BoxDecoration(
                  color: isActive
                      ? signalColor
                      : Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (!widget.isNew && !widget.isRecentlyActive) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: DesignTokens.spaceSM,
      right: DesignTokens.spaceSM,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceSM,
          vertical: DesignTokens.spaceXS,
        ),
        decoration: BoxDecoration(
          color: widget.isNew ? SemanticColors.success : SemanticColors.warning,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: DesignTokens.elevation1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.isNew ? Icons.new_releases : Icons.access_time,
              color: Colors.white,
              size: DesignTokens.iconXS,
            ),
            const SizedBox(width: DesignTokens.spaceXS),
            Text(
              widget.isNew ? 'NEW' : 'ACTIVE',
              style: const TextStyle(
                color: Colors.white,
                fontSize: DesignTokens.fontSizeXS,
                fontWeight: FontWeight.w700,
                letterSpacing: DesignTokens.letterSpacingWide,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncIndicator() {
    if (widget.isProfileSynced) return const SizedBox.shrink();

    return Positioned(
      bottom: DesignTokens.spaceSM,
      left: DesignTokens.spaceSM,
      child: AnimatedContainer(
        duration: AnimationTokens.fast,
        curve: AnimationTokens.easeInOut,
        padding: const EdgeInsets.all(DesignTokens.spaceXS),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: DesignTokens.elevation1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Icon(
          Icons.cloud_download_outlined,
          color: Colors.white70,
          size: DesignTokens.iconSM,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Focus(
            onFocusChange: (hasFocus) {
              setState(() => _hasFocus = hasFocus);
            },
            child: Semantics(
              label: 'User profile card for ${widget.username}',
              hint: 'Double tap to view actions and profile details',
              button: true,
              child: GestureDetector(
                onTapDown: _handleTapDown,
                onTapUp: _handleTapUp,
                onTapCancel: _handleTapCancel,
                onTap: () => _showUserActions(context),
                child: AnimatedContainer(
                  duration: AnimationTokens.fast,
                  curve: AnimationTokens.easeInOut,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                    border: Border.all(
                      color: _hasFocus
                          ? theme.colorScheme.primary.withValues(alpha: 0.5)
                          : theme.dividerColor.withValues(alpha: 0.1),
                      width: _hasFocus ? 2.0 : 1.0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusMD - 1),
                    child: AspectRatio(
                      aspectRatio: 0.75,
                      child: Stack(
                        children: [
                          // Main Content
                          Positioned.fill(
                            child: widget.photoUrl != null &&
                                    widget.photoUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: widget.photoUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        _buildGenderPlaceholder(),
                                    errorWidget: (context, url, error) =>
                                        _buildGenderPlaceholder(),
                                  )
                                : _buildGenderPlaceholder(),
                          ),

                          // Connection Quality Indicator
                          _buildConnectionQuality(),

                          // Status Indicator
                          _buildStatusIndicator(),

                          // Sync Indicator
                          _buildSyncIndicator(),

                          // Delete Button
                          if (widget.onDelete != null)
                            Positioned(
                              bottom: DesignTokens.spaceSM,
                              right: DesignTokens.spaceSM,
                              child: GestureDetector(
                                onTap: widget.onDelete,
                                child: Container(
                                  padding: const EdgeInsets.all(
                                      DesignTokens.spaceXS),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: DesignTokens.iconSM,
                                  ),
                                ),
                              ),
                            ),

                          // Username and Status Message
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(DesignTokens.spaceMD),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.username,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: DesignTokens.fontSizeMD,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.5),
                                          offset: const Offset(0, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.statusMessage != null &&
                                      widget.statusMessage!.isNotEmpty) ...[
                                    const SizedBox(
                                        height: DesignTokens.spaceXS),
                                    Text(
                                      widget.statusMessage!,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                        fontSize: DesignTokens.fontSizeXS,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.5),
                                            offset: const Offset(0, 1),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // Wave Animation Overlay
                          if (_waveAnimation.value > 0)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusLG),
                                  color: SemanticColors.success.withValues(
                                      alpha: 0.2 * _waveAnimation.value),
                                ),
                                child: Center(
                                  child: Transform.scale(
                                    scale: _waveAnimation.value,
                                    child: Icon(
                                      Icons.waving_hand,
                                      color: Colors.white.withValues(
                                          alpha: _waveAnimation.value),
                                      size: DesignTokens.iconXXL,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Global Badge Overlay
                          if (widget.badgeUrl != null &&
                              widget.badgeUrl!.isNotEmpty)
                            Positioned(
                              top: DesignTokens.spaceXL,
                              left: DesignTokens.spaceSM,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: widget.badgeUrl!,
                                    fit: BoxFit.contain,
                                    errorWidget: (context, url, error) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Professional User Actions Modal
class _UserActionsModal extends StatefulWidget {
  final UserModel user;
  final VoidCallback onTap;
  final BuildContext modalContext;
  final VoidCallback onWaveAnimation;

  const _UserActionsModal({
    required this.user,
    required this.onTap,
    required this.modalContext,
    required this.onWaveAnimation,
  });

  @override
  State<_UserActionsModal> createState() => _UserActionsModalState();
}

class _UserActionsModalState extends State<_UserActionsModal>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late List<Animation<double>> _staggerAnimations;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: AnimationTokens.slow,
      vsync: this,
    );
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: AnimationTokens.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: AnimationTokens.easeOut,
    ));

    // Stagger animations for content elements
    _staggerAnimations = List.generate(6, (index) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _staggerController,
        curve: Interval(
          index * 0.1,
          1.0,
          curve: AnimationTokens.easeOut,
        ),
      ));
    });

    _entranceController.forward();
    _staggerController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FriendsBloc, FriendsState>(
      builder: (context, friendsState) {
        if (friendsState is! FriendsLoaded) {
          return _buildLoadingState(context);
        }

        final currentUser = friendsState.user;
        final sharedInterests = widget.user.interests
            .where((i) => currentUser.interests
                .any((ci) => ci.toLowerCase() == i.toLowerCase()))
            .toList();
        final mutualFriends = widget.user.friends
            .where((friendId) => currentUser.friends.contains(friendId))
            .toList();
        final isProfileSynced = widget.user.id.length > 8;

        return RepaintBoundary(
          child: DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            expand: false,
            builder: (_, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).scaffoldBackgroundColor,
                      Theme.of(context)
                          .scaffoldBackgroundColor
                          .withValues(alpha: 0.95),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(DesignTokens.radiusXXL),
                    topRight: Radius.circular(DesignTokens.radiusXXL),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Drag Handle
                    Positioned(
                      top: DesignTokens.spaceMD,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // Main Content
                    Positioned(
                      top: DesignTokens.spaceXL,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: SingleChildScrollView(
                            controller: scrollController,
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(DesignTokens.spaceLG)
                                      .copyWith(bottom: DesignTokens.spaceXXXL),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Profile Picture with Animation
                                  FadeTransition(
                                    opacity: _staggerAnimations[0],
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.2),
                                        end: Offset.zero,
                                      ).animate(_staggerAnimations[0]),
                                      child: _buildProfileSection(context),
                                    ),
                                  ),

                                  const SizedBox(height: DesignTokens.spaceLG),

                                  // Username with Animation
                                  FadeTransition(
                                    opacity: _staggerAnimations[1],
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.2),
                                        end: Offset.zero,
                                      ).animate(_staggerAnimations[1]),
                                      child: _buildUsernameSection(context),
                                    ),
                                  ),

                                  const SizedBox(height: DesignTokens.spaceMD),

                                  // Status Message with Animation
                                  if (widget
                                      .user.nearbyStatusMessage.isNotEmpty)
                                    FadeTransition(
                                      opacity: _staggerAnimations[2],
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.2),
                                          end: Offset.zero,
                                        ).animate(_staggerAnimations[2]),
                                        child:
                                            _buildStatusMessageSection(context),
                                      ),
                                    ),

                                  // Shared Info Sections with Animation
                                  if (mutualFriends.isNotEmpty)
                                    FadeTransition(
                                      opacity: _staggerAnimations[3],
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.2),
                                          end: Offset.zero,
                                        ).animate(_staggerAnimations[3]),
                                        child: _buildMutualFriendsSection(
                                            context, mutualFriends),
                                      ),
                                    ),

                                  if (sharedInterests.isNotEmpty)
                                    FadeTransition(
                                      opacity: _staggerAnimations[4],
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.2),
                                          end: Offset.zero,
                                        ).animate(_staggerAnimations[4]),
                                        child: _buildSharedInterestsSection(
                                            context, sharedInterests),
                                      ),
                                    ),

                                  const SizedBox(height: DesignTokens.spaceLG),

                                  // Action Buttons with Animation
                                  FadeTransition(
                                    opacity: _staggerAnimations[5],
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.2),
                                        end: Offset.zero,
                                      ).animate(_staggerAnimations[5]),
                                      child: _ProfessionalActionButtons(
                                        currentUser: currentUser,
                                        targetUser: widget.user,
                                        isProfileSynced: isProfileSynced,
                                        modalContext: widget.modalContext,
                                        onWaveAnimation: widget.onWaveAnimation,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: DesignTokens.spaceLG),

                                  // View Full Profile Button with Animation
                                  FadeTransition(
                                    opacity: _staggerAnimations[5],
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.2),
                                        end: Offset.zero,
                                      ).animate(_staggerAnimations[5]),
                                      child: _buildViewProfileButton(
                                          context, isProfileSynced),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Close Button
                    Positioned(
                      top: DesignTokens.spaceMD,
                      right: DesignTokens.spaceMD,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(widget.modalContext);
                          },
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusSM),
                          child: Container(
                            padding: const EdgeInsets.all(DesignTokens.spaceSM),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .scaffoldBackgroundColor
                                  .withValues(alpha: 0.8),
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusSM),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                                width: 0.5,
                              ),
                            ),
                            child: Icon(
                              Icons.close,
                              size: DesignTokens.iconMD,
                              color: Theme.of(context).iconTheme.color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).scaffoldBackgroundColor,
            Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(DesignTokens.radiusXXL),
          topRight: Radius.circular(DesignTokens.radiusXXL),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            Text(
              'Loading profile...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: CircleAvatar(
        radius: DesignTokens.spaceXXXL,
        backgroundImage: widget.user.photoUrl.isNotEmpty
            ? CachedNetworkImageProvider(widget.user.photoUrl)
            : null,
        backgroundColor: widget.user.photoUrl.isEmpty
            ? (widget.user.genderValue == 1
                ? Colors.blue.shade50
                : Colors.pink.shade50)
            : null,
        child: widget.user.photoUrl.isEmpty
            ? Icon(
                widget.user.genderValue == 1 ? Icons.male : Icons.female,
                size: DesignTokens.iconXXL,
                color: widget.user.genderValue == 1
                    ? Colors.blue.shade600
                    : Colors.pink.shade600,
              )
            : null,
      ),
    );
  }

  Widget _buildUsernameSection(BuildContext context) {
    return Column(
      children: [
        Text(
          widget.user.username,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: DesignTokens.fontSizeXXL,
                letterSpacing: DesignTokens.letterSpacingTight,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DesignTokens.spaceXS),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMD,
            vertical: DesignTokens.spaceXS,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Text(
            'Nearby User',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: DesignTokens.fontSizeXS,
                  letterSpacing: DesignTokens.letterSpacingWide,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusMessageSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: DesignTokens.iconSM,
            color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.6),
          ),
          const SizedBox(width: DesignTokens.spaceSM),
          Expanded(
            child: Text(
              '"${widget.user.nearbyStatusMessage}" ${widget.user.nearbyStatusEmoji}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontStyle: FontStyle.italic,
                    fontSize: DesignTokens.fontSizeMD,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMutualFriendsSection(
      BuildContext context, List<String> mutualFriends) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.people_outline,
            size: DesignTokens.iconSM,
            color: SemanticColors.success,
          ),
          const SizedBox(width: DesignTokens.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Friend${mutualFriends.length > 1 ? 's' : ''} in Common',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: DesignTokens.fontSizeSM,
                      ),
                ),
                const SizedBox(height: DesignTokens.spaceXS),
                Text(
                  'You both know ${mutualFriends.length} ${mutualFriends.length > 1 ? 'people' : 'person'}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedInterestsSection(
      BuildContext context, List<String> sharedInterests) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.favorite_border,
                size: DesignTokens.iconSM,
                color: SemanticColors.error,
              ),
              const SizedBox(width: DesignTokens.spaceSM),
              Text(
                'Shared Interests',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: DesignTokens.fontSizeSM,
                    ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceSM),
          Wrap(
            spacing: DesignTokens.spaceSM,
            runSpacing: DesignTokens.spaceSM,
            children: sharedInterests
                .map((interest) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spaceSM,
                        vertical: DesignTokens.spaceXS,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusSM),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        interest,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: DesignTokens.fontSizeXS,
                            ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildViewProfileButton(BuildContext context, bool isProfileSynced) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceLG,
            vertical: DesignTokens.spaceMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          ),
          elevation: DesignTokens.elevation2,
        ),
        onPressed: !isProfileSynced
            ? null
            : () {
                HapticFeedback.lightImpact();
                Navigator.pop(widget.modalContext);
                widget.onTap();
              },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_outline,
              size: DesignTokens.iconSM,
            ),
            const SizedBox(width: DesignTokens.spaceSM),
            Text(
              isProfileSynced ? 'View Full Profile' : 'Profile Syncing...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: DesignTokens.fontSizeMD,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// Professional Action buttons widget
class _ProfessionalActionButtons extends StatefulWidget {
  final UserModel currentUser;
  final UserModel targetUser;
  final bool isProfileSynced;
  final BuildContext modalContext;
  final VoidCallback onWaveAnimation;

  const _ProfessionalActionButtons({
    required this.currentUser,
    required this.targetUser,
    required this.isProfileSynced,
    required this.modalContext,
    required this.onWaveAnimation,
  });

  @override
  State<_ProfessionalActionButtons> createState() =>
      _ProfessionalActionButtonsState();
}

class _ProfessionalActionButtonsState extends State<_ProfessionalActionButtons>
    with TickerProviderStateMixin {
  bool _isLoadingWave = false;
  bool _isLoadingFriend = false;
  late AnimationController _buttonAnimationController;
  late List<Animation<double>> _buttonAnimations;

  @override
  void initState() {
    super.initState();
    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _buttonAnimations = List.generate(4, (index) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Interval(
          index * 0.1,
          1.0,
          curve: AnimationTokens.easeOut,
        ),
      ));
    });

    _buttonAnimationController.forward();
  }

  @override
  void dispose() {
    _buttonAnimationController.dispose();
    super.dispose();
  }

  String? _getTargetUidShort() {
    if (widget.isProfileSynced) {
      final nearbyUser = locator<LocalCacheService>()
          .getNearbyUserByProfileId(widget.targetUser.id);

      // CRITICAL FIX: Log the mapping to detect wrong targets
      debugPrint(
          "🎯 [WAVE TARGET] Looking up uidShort for profileId: ${widget.targetUser.id}");
      if (nearbyUser != null) {
        debugPrint(
            "   ✅ Found: uidShort='${nearbyUser.uidShort}' (gender=${nearbyUser.gender}, lastSeen=${nearbyUser.lastSeen})");
      } else {
        debugPrint(
            "   ❌ NOT FOUND! No nearby user has profileId='${widget.targetUser.id}'");
      }

      return nearbyUser?.uidShort;
    } else {
      debugPrint(
          "🎯 [WAVE TARGET] Profile not synced, using short ID directly: ${widget.targetUser.id}");
      return widget.targetUser.id.length == 8 ? widget.targetUser.id : null;
    }
  }

  Future<void> _handleWave() async {
    if (_isLoadingWave) return;
    setState(() => _isLoadingWave = true);
    HapticFeedback.lightImpact();

    final targetUidShort = _getTargetUidShort();
    if (targetUidShort == null) {
      if (!mounted) return;
      setState(() => _isLoadingWave = false);
      showIslandPopup(
          context: context,
          message: "Cannot wave (user info missing).",
          icon: Icons.error_outline);
      return;
    }

    try {
      final sonarController = locator<SonarController>();

      // CRITICAL FIX: Log full wave context
      debugPrint("👋 [SEND WAVE] Sending wave to:");
      debugPrint("   Target uidShort: $targetUidShort");
      debugPrint("   Display name: ${widget.targetUser.username}");
      debugPrint("   Display ID: ${widget.targetUser.id}");
      debugPrint("   Is synced: ${widget.isProfileSynced}");

      await sonarController.sendWave(targetUidShort);

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onWaveAnimation();
      showIslandPopup(
          context: context, message: "Wave sent!", icon: Icons.waving_hand);
    } catch (e) {
      if (!mounted) return;
      showIslandPopup(
          context: context,
          message: "Failed to send wave: $e",
          icon: Icons.error_outline);
    } finally {
      if (mounted) {
        setState(() => _isLoadingWave = false);
      }
    }
  }

  Future<void> _handleAddFriend() async {
    if (_isLoadingFriend) return;
    setState(() => _isLoadingFriend = true);
    HapticFeedback.lightImpact();

    try {
      if (!widget.isProfileSynced) {
        final localCache = locator<LocalCacheService>();
        await localCache.queueFriendRequest(
          fromUserId: widget.currentUser.id,
          toUserId: widget.targetUser.id,
        );

        if (!mounted) return;
        Navigator.of(context).pop();
        showIslandPopup(
            context: context,
            message: "Friend request queued for sync!",
            icon: Icons.hourglass_top);
        return;
      }

      context.read<FriendsBloc>().add(SendFriendRequest(widget.targetUser.id));

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      Navigator.of(context).pop();
      showIslandPopup(
          context: context,
          message: "Friend request sent!",
          icon: Icons.person_add_alt_1);
    } catch (e) {
      if (!mounted) return;
      showIslandPopup(
          context: context,
          message: "Failed to send request: $e",
          icon: Icons.error_outline);
      setState(() => _isLoadingFriend = false);
    }
  }

  void _handleInvite() {
    HapticFeedback.lightImpact();
    Navigator.pop(widget.modalContext);
    showIslandPopup(context: context, message: "Game invites coming soon!");
  }

  void _handleChat() {
    HapticFeedback.lightImpact();
    Navigator.pop(widget.modalContext);

    // Navigate to regular chat screen using ChatRepository
    final chatRepository = locator<ChatRepository>();
    chatRepository
        .startOrGetChat(
      widget.targetUser.id,
      widget.targetUser.username,
    )
        .then((chatId) {
      // CRITICAL: Check mounted before navigation
      if (!mounted) return;

      locator<NavigationService>().navigateNamed(
        AppRoutes.chat,
        arguments: {
          'chatId': chatId,
          'otherUserId': widget.targetUser.id,
        },
      );
    }).catchError((e) {
      if (mounted) {
        showIslandPopup(
          context: context,
          message: "Failed to open chat: $e",
          icon: Icons.error_outline,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FriendsBloc, FriendsState>(
      builder: (context, friendsBlocState) {
        if (friendsBlocState is! FriendsLoaded) {
          return const Center(child: AppProgressIndicator());
        }

        final currentUserData = friendsBlocState.user;
        final isFriend = currentUserData.friends.contains(widget.targetUser.id);
        final requestSent =
            currentUserData.friendRequestsSent.contains(widget.targetUser.id);
        final requestReceived = currentUserData.friendRequestsReceived
            .contains(widget.targetUser.id);

        return BlocBuilder<ConnectivityBloc, ConnectivityState>(
          builder: (context, connectivityState) {
            final isOnline = connectivityState is Online;

            return Column(
              children: [
                Text(
                  'Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: DesignTokens.fontSizeLG,
                      ),
                ),
                const SizedBox(height: DesignTokens.spaceMD),
                Wrap(
                  spacing: DesignTokens.spaceMD,
                  runSpacing: DesignTokens.spaceMD,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildActionButton(
                      context,
                      icon: Icons.waving_hand_outlined,
                      label: 'Wave',
                      isLoading: _isLoadingWave,
                      onTap: _handleWave,
                      animation: _buttonAnimations[0],
                    ),
                    _buildChatButton(context, isOnline),
                    _buildActionButton(
                      context,
                      icon: _getFriendButtonIcon(
                          isFriend, requestSent, requestReceived),
                      label: _getFriendButtonLabel(
                          isFriend, requestSent, requestReceived),
                      isLoading: _isLoadingFriend,
                      onTap: _getFriendButtonAction(
                          isFriend, requestSent, requestReceived),
                      animation: _buttonAnimations[2],
                    ),
                    _buildActionButton(
                      context,
                      icon: Icons.sports_esports_outlined,
                      label: 'Invite',
                      onTap: _handleInvite,
                      animation: _buttonAnimations[3],
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildChatButton(BuildContext context, bool isOnline) {
    return FadeTransition(
      opacity: _buttonAnimations[1],
      child: ScaleTransition(
        scale: _buttonAnimations[1],
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isOnline ? _handleChat : null,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            child: Container(
              width: 80,
              padding: const EdgeInsets.all(DesignTokens.spaceMD),
              decoration: BoxDecoration(
                color: isOnline
                    ? Theme.of(context).cardColor
                    : Theme.of(context).dividerColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  width: 1.0,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1)
                          : Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: isOnline
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[500],
                          size: DesignTokens.iconLG,
                        ),
                        if (!isOnline)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.grey[600],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).cardColor,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.wifi_off,
                                color: Colors.white,
                                size: 6,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceSM),
                  Text(
                    'Chat',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isOnline ? null : Colors.grey[500],
                          fontWeight: FontWeight.w600,
                          fontSize: DesignTokens.fontSizeXS,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Animation<double> animation,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    final isDisabled = onTap == null;
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: animation,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading || isDisabled ? null : onTap,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
            child: Container(
              width: 80,
              padding: const EdgeInsets.all(DesignTokens.spaceMD),
              decoration: BoxDecoration(
                color: isDisabled
                    ? theme.dividerColor.withValues(alpha: 0.3)
                    : theme.cardColor,
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                border: Border.all(
                  color: isDisabled
                      ? theme.dividerColor.withValues(alpha: 0.3)
                      : theme.dividerColor,
                  width: 0.5,
                ),
                boxShadow: isDisabled
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: DesignTokens.elevation1,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Use AppActionButton but extract just the button part
                  // We'll customize it to match the card design
                  AppActionButton(
                    icon: icon,
                    label: label,
                    onPressed: isLoading || isDisabled ? null : onTap,
                    isLoading: isLoading,
                    isDisabled: isDisabled,
                    size: 48,
                    iconSize: DesignTokens.iconLG,
                    showLabel:
                        false, // We'll add the label separately to match original layout
                    backgroundColor: isDisabled
                        ? theme.dividerColor.withValues(alpha: 0.3)
                        : theme.colorScheme.primary.withValues(alpha: 0.1),
                    color: isDisabled
                        ? Colors.grey[500]
                        : theme.colorScheme.primary,
                    hapticType: AppButtonHapticType.light,
                    animationDuration: const Duration(milliseconds: 150),
                  ),
                  const SizedBox(height: DesignTokens.spaceSM),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDisabled ? Colors.grey[500] : null,
                      fontWeight: FontWeight.w600,
                      fontSize: DesignTokens.fontSizeXS,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFriendButtonIcon(
      bool isFriend, bool requestSent, bool requestReceived) {
    if (isFriend) return Icons.check_circle_outline;
    if (requestSent) return Icons.hourglass_top_rounded;
    if (requestReceived) return Icons.mark_email_read_outlined;
    return Icons.person_add_alt_1;
  }

  String _getFriendButtonLabel(
      bool isFriend, bool requestSent, bool requestReceived) {
    if (isFriend) return 'Friend';
    if (requestSent) return 'Requested';
    if (requestReceived) return 'Accept';
    return 'Add Friend';
  }

  VoidCallback? _getFriendButtonAction(
      bool isFriend, bool requestSent, bool requestReceived) {
    if (isFriend) return null;
    if (requestSent) return null;
    if (requestReceived) {
      return !widget.isProfileSynced
          ? null
          : () async {
              setState(() => _isLoadingFriend = true);
              final friendsBloc = context.read<FriendsBloc>();
              friendsBloc.add(AcceptFriendRequest(widget.targetUser.id));
              await Future.delayed(const Duration(milliseconds: 500));
              if (!mounted) return;
              Navigator.pop(widget.modalContext);
            };
    }
    return _handleAddFriend;
  }
}
