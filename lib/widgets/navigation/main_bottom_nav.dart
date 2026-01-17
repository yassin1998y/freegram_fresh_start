// lib/widgets/navigation/main_bottom_nav.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:freegram/widgets/core/user_avatar.dart';

/// Main bottom navigation bar component
///
/// Features:
/// - Uses SemanticColors for theme-aware styling
/// - Const widget where possible for performance
/// - Supports UserAvatar for profile tab
/// - Glassmorphic styling with blur effects
///
/// Usage:
/// ```dart
/// MainBottomNav(
///   selectedIndex: _selectedIndex,
///   onItemTapped: _onItemTapped,
///   userPhotoUrl: currentUser.photoUrl,
/// )
/// ```
class MainBottomNav extends StatelessWidget {
  /// Currently selected tab index
  final int selectedIndex;

  /// Callback when a tab is tapped
  final ValueChanged<int> onItemTapped;

  /// Optional: User photo URL for profile/menu tab (index 4)
  final String? userPhotoUrl;

  /// Optional: Showcase keys for guided overlay
  final Map<int, GlobalKey>? showcaseKeys;

  /// Optional: Enable blur effects (default: true)
  final bool enableBlurEffects;

  const MainBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.userPhotoUrl,
    this.showcaseKeys,
    this.enableBlurEffects = true,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final dividerColor = SemanticColors.surfaceDivider(context);
    final scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      padding: EdgeInsets.only(
        bottom: bottomPadding,
      ),
      constraints: const BoxConstraints(minHeight: 65),
      decoration: BoxDecoration(
        color:
            scaffoldBackgroundColor, // Match scaffold background to fill gaps
        border: Border(
          top: BorderSide(
            color: dividerColor.withOpacity(0.2),
            width: 0.5,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: enableBlurEffects
              ? ImageFilter.blur(sigmaX: 15, sigmaY: 15)
              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _BottomNavIcon(
                key: showcaseKeys?[1],
                icon: Icons.public,
                label: 'Feed',
                isSelected: selectedIndex == 1,
                onTap: () => onItemTapped(1),
              ),
              _BottomNavIcon(
                icon: Icons.whatshot_outlined,
                label: 'Match',
                isSelected: selectedIndex == 2,
                onTap: () => onItemTapped(2),
              ),
              _GlassmorphicCenterButton(
                key: showcaseKeys?[0],
                icon: Icons.radar,
                label: 'Nearby',
                isSelected: selectedIndex == 0,
                onTap: () => onItemTapped(0),
              ),
              _BottomNavIcon(
                key: showcaseKeys?[3],
                icon: Icons.people_outline,
                label: 'Friends',
                isSelected: selectedIndex == 3,
                onTap: () => onItemTapped(3),
              ),
              _BottomNavIcon(
                key: showcaseKeys?[4],
                icon: Icons.menu,
                label: 'Menu',
                isSelected: selectedIndex == 4,
                onTap: () => onItemTapped(4),
                // Use UserAvatar if photo URL is provided
                avatarUrl: userPhotoUrl,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom navigation icon item
class _BottomNavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? avatarUrl; // Optional: Use avatar instead of icon

  const _BottomNavIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final iconColor = isSelected
        ? primaryColor
        : SemanticColors.iconDefault(context)
            .withOpacity(DesignTokens.opacityHigh);

    final fontWeight = isSelected ? FontWeight.w600 : FontWeight.normal;

    return Expanded(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSM),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: AnimationTokens.normal,
                  curve: AnimationTokens.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceSM + DesignTokens.spaceXS,
                    vertical: DesignTokens.spaceSM - DesignTokens.spaceXS,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? UserAvatar(
                          url: avatarUrl,
                          size: AvatarSize.small,
                        )
                      : Icon(
                          icon,
                          size: DesignTokens.iconLG,
                          color: iconColor,
                        ),
                ),
                const SizedBox(height: DesignTokens.spaceXS),
                AnimatedDefaultTextStyle(
                  duration: AnimationTokens.normal,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSize11,
                    fontWeight: fontWeight,
                    color: iconColor,
                    height: DesignTokens.lineHeightTight,
                  ),
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
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

/// Glassmorphic center button for Nearby tab
class _GlassmorphicCenterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GlassmorphicCenterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    const accentColor = SonarPulseTheme.primaryAccent;

    return Expanded(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: DesignTokens.spaceSM - DesignTokens.spaceXS),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: AnimationTokens.normal,
                  curve: AnimationTokens.easeInOutCubic,
                  width: DesignTokens.avatarSize,
                  height: DesignTokens.avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accentColor.withOpacity(0.4),
                              primaryColor.withOpacity(0.3),
                            ],
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primaryColor.withOpacity(0.15),
                              primaryColor.withOpacity(0.08),
                            ],
                          ),
                    border: Border.all(
                      color: isSelected
                          ? accentColor.withOpacity(0.6)
                          : primaryColor.withOpacity(0.3),
                      width: isSelected ? 2 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: accentColor.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: DesignTokens.iconMD + 2,
                      color: isSelected
                          ? Colors.white
                          : primaryColor.withOpacity(0.9),
                    ),
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceXS),
                AnimatedDefaultTextStyle(
                  duration: AnimationTokens.normal,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSize11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? accentColor
                        : primaryColor.withOpacity(0.9),
                    height: DesignTokens.lineHeightTight,
                  ),
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
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
