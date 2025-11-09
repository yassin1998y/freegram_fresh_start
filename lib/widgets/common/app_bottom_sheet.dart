// lib/widgets/common/app_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:freegram/theme/design_tokens.dart';

/// Unified bottom sheet widget for the app
///
/// This widget standardizes bottom sheet patterns across the app:
/// - DraggableScrollableSheet or fixed-height modal
/// - Consistent styling (border radius, background, drag handle)
/// - Optional title and close button
/// - SafeArea handling
/// - Keyboard-aware sizing
class AppBottomSheet extends StatelessWidget {
  /// Content to display in the bottom sheet
  final Widget child;

  /// Optional title widget (appears at the top)
  final Widget? title;

  /// Whether to show a drag handle at the top
  final bool showDragHandle;

  /// Whether to show a close button
  final bool showCloseButton;

  /// Close button callback (defaults to Navigator.pop)
  final VoidCallback? onClose;

  /// Background color (defaults to scaffoldBackgroundColor)
  final Color? backgroundColor;

  /// Border radius (defaults to DesignTokens.radiusXL)
  final double? borderRadius;

  /// Padding around the content (defaults to EdgeInsets.zero)
  final EdgeInsetsGeometry? padding;

  /// Whether to use DraggableScrollableSheet (true) or fixed height (false)
  final bool isDraggable;

  /// Initial child size for DraggableScrollableSheet (0.0 to 1.0)
  final double initialChildSize;

  /// Minimum child size for DraggableScrollableSheet (0.0 to 1.0)
  final double minChildSize;

  /// Maximum child size for DraggableScrollableSheet (0.0 to 1.0)
  final double maxChildSize;

  /// Fixed height for non-draggable sheets (only used if isDraggable is false)
  final double? fixedHeight;

  /// Whether to adjust size based on keyboard visibility
  final bool adjustForKeyboard;

  /// Optional header widget (replaces title + close button if provided)
  final Widget? header;

  /// Optional footer widget (appears at the bottom, e.g., input fields)
  final Widget? footer;

  /// Whether the child is already wrapped in Column with Expanded (for complex layouts)
  final bool isComplexLayout;

  /// Builder function that receives the scroll controller (for complex layouts)
  /// If provided, this is used instead of child when isComplexLayout is true
  final Widget Function(ScrollController? scrollController)? childBuilder;

  const AppBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showDragHandle = true,
    this.showCloseButton = false,
    this.onClose,
    this.backgroundColor,
    this.borderRadius,
    this.padding,
    this.isDraggable = true,
    this.initialChildSize = 0.9,
    this.minChildSize = 0.5,
    this.maxChildSize = 0.95,
    this.fixedHeight,
    this.adjustForKeyboard = true,
    this.header,
    this.footer,
    this.isComplexLayout = false,
    this.childBuilder,
  });

  /// Show as a modal bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    Widget? title,
    bool showDragHandle = true,
    bool showCloseButton = false,
    VoidCallback? onClose,
    Color? backgroundColor,
    double? borderRadius,
    EdgeInsetsGeometry? padding,
    bool isDraggable = true,
    double initialChildSize = 0.9,
    double minChildSize = 0.5,
    double maxChildSize = 0.95,
    double? fixedHeight,
    bool adjustForKeyboard = true,
    Widget? header,
    Widget? footer,
    bool isComplexLayout = false,
    Widget Function(ScrollController? scrollController)? childBuilder,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      builder: (context) => AppBottomSheet(
        title: title,
        showDragHandle: showDragHandle,
        showCloseButton: showCloseButton,
        onClose: onClose,
        backgroundColor: backgroundColor,
        borderRadius: borderRadius,
        padding: padding,
        isDraggable: isDraggable,
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        fixedHeight: fixedHeight,
        adjustForKeyboard: adjustForKeyboard,
        header: header,
        footer: footer,
        isComplexLayout: isComplexLayout,
        childBuilder: childBuilder,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = adjustForKeyboard ? mediaQuery.viewInsets.bottom : 0;
    final effectiveBackgroundColor =
        backgroundColor ?? theme.scaffoldBackgroundColor;
    final effectiveBorderRadius =
        borderRadius ?? DesignTokens.radiusXL.toDouble();
    final effectivePadding = padding ?? EdgeInsets.zero;

    // Build the content wrapper
    Widget buildContent(ScrollController? scrollController) {
      return Container(
        decoration: BoxDecoration(
          color: effectiveBackgroundColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(effectiveBorderRadius),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              if (showDragHandle) _buildDragHandle(context, theme),

              // Header (custom or title + close button)
              if (header != null)
                header!
              else if (title != null || showCloseButton)
                _buildHeader(context, theme, title, showCloseButton, onClose),

              // Content
              if (isComplexLayout)
                // For complex layouts (Column with Expanded, etc.), use the child or childBuilder
                Expanded(
                  child: childBuilder != null
                      ? childBuilder!(scrollController)
                      : child,
                )
              else
                // For simple content, wrap in scrollable
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: effectivePadding,
                      child: child,
                    ),
                  ),
                ),

              // Footer (if provided)
              if (footer != null) footer!,
            ],
          ),
        ),
      );
    }

    // Wrap in DraggableScrollableSheet if needed
    if (isDraggable) {
      final adjustedMaxSize = adjustForKeyboard && keyboardHeight > 0
          ? (maxChildSize * 1.05).clamp(0.0, 0.98)
          : maxChildSize;

      return DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: adjustedMaxSize,
        builder: (context, scrollController) {
          return buildContent(scrollController);
        },
      );
    } else {
      // Fixed height
      final height = fixedHeight ??
          (mediaQuery.size.height * initialChildSize) - keyboardHeight;
      return SizedBox(
        height: height,
        child: buildContent(null),
      );
    }
  }

  Widget _buildDragHandle(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSM),
      width: DesignTokens.spaceXL,
      height: DesignTokens.spaceXS,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(
          DesignTokens.opacityMedium,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    Widget? title,
    bool showCloseButton,
    VoidCallback? onClose,
  ) {
    if (title == null && !showCloseButton) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMD,
        vertical: DesignTokens.spaceSM,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title
          if (title != null)
            Expanded(
              child: DefaultTextStyle(
                style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ) ??
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                child: title,
              ),
            )
          else
            const Spacer(),

          // Close button
          if (showCloseButton)
            IconButton(
              icon: Icon(
                Icons.close,
                color: theme.colorScheme.onSurface,
              ),
              onPressed: onClose ?? () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

/// Convenience widget for simple list-style bottom sheets
class AppListBottomSheet extends StatelessWidget {
  /// Title for the bottom sheet
  final String? title;

  /// List of items to display
  final List<Widget> items;

  /// Whether to show drag handle
  final bool showDragHandle;

  /// Whether to show close button
  final bool showCloseButton;

  /// Callback when an item is tapped
  final Function(int)? onItemTap;

  const AppListBottomSheet({
    super.key,
    this.title,
    required this.items,
    this.showDragHandle = true,
    this.showCloseButton = false,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: title != null ? Text(title!) : null,
      showDragHandle: showDragHandle,
      showCloseButton: showCloseButton,
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceMD),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (onItemTap != null) {
            return InkWell(
              onTap: () => onItemTap!(index),
              child: item,
            );
          }
          return item;
        },
      ),
    );
  }
}

