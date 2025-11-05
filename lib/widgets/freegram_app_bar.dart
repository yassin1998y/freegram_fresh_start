// lib/widgets/freegram_app_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Consistent Freegram branded AppBar for all screens
/// Uses system theme (light/dark mode) and design tokens
class FreegramAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool centerTitle;
  final double elevation;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const FreegramAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
    this.centerTitle = false,
    this.elevation = 0,
    this.leading,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // System theme colors
    final backgroundColor = theme.scaffoldBackgroundColor;
    final foregroundColor = theme.colorScheme.onSurface;
    final primaryColor = theme.colorScheme.primary;

    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      scrolledUnderElevation: 1,
      centerTitle: centerTitle,
      leading: leading ??
          (showBackButton
              ? IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                  ),
                  tooltip: 'Back',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (onBackPressed != null) {
                      onBackPressed!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                )
              : null),
      title: titleWidget ??
          (title != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Full "Freegram" branding (consistent with main screen)
                    Text(
                      'Freegram',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      width: 2,
                      height: 20,
                      decoration: BoxDecoration(
                        color: foregroundColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        title!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: foregroundColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Freegram',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: -0.5,
                  ),
                )),
      actions: actions != null
          ? [
              ...actions!,
              SizedBox(width: 4), // Right padding
            ]
          : null,
      bottom: bottom,
    );
  }
}

/// Professional action button for AppBar
class AppBarActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;
  final bool showBadge;
  final String? badgeText;

  const AppBarActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.showBadge = false,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = color ?? theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onPressed();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: buttonColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: buttonColor,
                ),
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: badgeText != null ? 6 : 8,
                  vertical: badgeText != null ? 2 : 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  shape:
                      badgeText != null ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius:
                      badgeText != null ? BorderRadius.circular(10) : null,
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: badgeText != null
                    ? Text(
                        badgeText!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
