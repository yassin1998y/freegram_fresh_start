import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Professional Responsive Grid System
/// Handles different screen sizes with proper spacing and aspect ratios
class ProfessionalResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double? childAspectRatio;
  final EdgeInsets? padding;
  final double? crossAxisSpacing;
  final double? mainAxisSpacing;

  const ProfessionalResponsiveGrid({
    super.key,
    required this.children,
    this.childAspectRatio,
    this.padding,
    this.crossAxisSpacing,
    this.mainAxisSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // Responsive breakpoints
        final isMobile = screenWidth < DesignTokens.breakpointTablet;
        final isTablet = screenWidth >= DesignTokens.breakpointTablet &&
            screenWidth < DesignTokens.breakpointDesktop;

        // Calculate grid parameters based on screen size
        int crossAxisCount;
        double spacing;
        double aspectRatio;
        EdgeInsets gridPadding;

        if (isMobile) {
          crossAxisCount = 2;
          spacing = DesignTokens.spaceMD;
          aspectRatio = childAspectRatio ?? 0.75;
          gridPadding = padding ?? const EdgeInsets.all(DesignTokens.spaceLG);
        } else if (isTablet) {
          crossAxisCount = 3;
          spacing = DesignTokens.spaceLG;
          aspectRatio = childAspectRatio ?? 0.8;
          gridPadding = padding ?? const EdgeInsets.all(DesignTokens.spaceXL);
        } else {
          crossAxisCount = 4;
          spacing = DesignTokens.spaceXL;
          aspectRatio = childAspectRatio ?? 0.85;
          gridPadding = padding ?? const EdgeInsets.all(DesignTokens.spaceXXL);
        }

        return Container(
          padding: gridPadding,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: crossAxisSpacing ?? spacing,
              mainAxisSpacing: mainAxisSpacing ?? spacing,
              childAspectRatio: aspectRatio,
            ),
            itemCount: children.length,
            itemBuilder: (context, index) {
              return RepaintBoundary(
                child: children[index],
              );
            },
          ),
        );
      },
    );
  }
}

/// Professional Glassmorphic Container
/// Enhanced glassmorphism with proper blur effects and gradients
class ProfessionalGlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? borderRadius;
  final double? blurIntensity;
  final List<Color>? gradientColors;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const ProfessionalGlassmorphicContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blurIntensity,
    this.gradientColors,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(borderRadius ?? DesignTokens.radiusLG),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurIntensity ?? DesignTokens.blurMedium,
            sigmaY: blurIntensity ?? DesignTokens.blurMedium,
          ),
          child: Container(
            padding: padding ?? const EdgeInsets.all(DesignTokens.spaceLG),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(borderRadius ?? DesignTokens.radiusLG),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors ??
                    [
                      Colors.white.withValues(alpha: 0.25),
                      Colors.white.withValues(alpha: 0.1)
                    ],
              ),
              border: border ??
                  Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
              boxShadow: boxShadow ?? DesignTokens.shadowMedium,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Professional Loading Skeleton
/// Provides skeleton loading states for better perceived performance
class ProfessionalLoadingSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const ProfessionalLoadingSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ProfessionalLoadingSkeleton> createState() =>
      _ProfessionalLoadingSkeletonState();
}

class _ProfessionalLoadingSkeletonState
    extends State<ProfessionalLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor =
        widget.baseColor ?? theme.colorScheme.surface.withValues(alpha: 0.3);
    final highlightColor = widget.highlightColor ??
        theme.colorScheme.surface.withValues(alpha: 0.6);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
                widget.borderRadius ?? DesignTokens.radiusMD),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
            ),
          ),
        );
      },
    );
  }
}

/// Professional Empty State
/// Provides consistent empty states with illustrations and CTAs
class ProfessionalEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const ProfessionalEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with gradient background
            Container(
              width: DesignTokens.spaceXXXL * 2,
              height: DesignTokens.spaceXXXL * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (iconColor ?? theme.colorScheme.primary)
                        .withValues(alpha: 0.1),
                    (iconColor ?? theme.colorScheme.primary)
                        .withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Icon(
                icon,
                size: DesignTokens.iconXXL,
                color: iconColor ??
                    theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),

            const SizedBox(height: DesignTokens.spaceXL),

            // Title
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                fontSize: DesignTokens.fontSizeXXL,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: DesignTokens.spaceMD),

            // Subtitle
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface
                    .withValues(alpha: DesignTokens.opacityMedium),
                fontSize: DesignTokens.fontSizeMD,
                height: DesignTokens.lineHeightNormal,
              ),
              textAlign: TextAlign.center,
            ),

            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: DesignTokens.spaceXL),

              // Action Button
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceXL,
                    vertical: DesignTokens.spaceMD,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                  ),
                  elevation: DesignTokens.elevation2,
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: DesignTokens.fontSizeMD,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
