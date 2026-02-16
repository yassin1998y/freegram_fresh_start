import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/lounge_user.dart';
import 'package:freegram/repositories/lounge_repository.dart';
import 'package:freegram/screens/random_chat/widgets/user_grid_item.dart';
import 'package:freegram/widgets/responsive_system.dart';
import 'package:freegram/theme/design_tokens.dart';
import 'package:freegram/theme/app_theme.dart';

class LoungeTab extends StatefulWidget {
  final VoidCallback onUserTap;

  const LoungeTab({super.key, required this.onUserTap});

  @override
  State<LoungeTab> createState() => _LoungeTabState();
}

class _LoungeTabState extends State<LoungeTab> {
  final LoungeRepository _repository = locator<LoungeRepository>();
  List<LoungeUser> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final users = await _repository.getLiveUsers();
    if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. App Bar / Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceLG),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(DesignTokens.spaceSM),
                    decoration: BoxDecoration(
                      color:
                          SonarPulseTheme.primaryAccent.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusSM),
                    ),
                    child: const Icon(
                      Icons.live_tv,
                      color: SonarPulseTheme.primaryAccent,
                      size: DesignTokens.iconSM,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSM),
                  Text(
                    "Discover Live",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: DesignTokens.letterSpacingTight,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.filter_list,
                        color: theme.colorScheme.onSurface,
                        size: DesignTokens.iconSM),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),

          // 2. Grid Content
          if (_isLoading)
            SliverFillRemaining(
              child: ProfessionalResponsiveGrid(
                padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceLG),
                children:
                    List.generate(6, (index) => const UserGridItemSkeleton()),
              ),
            )
          else
            SliverToBoxAdapter(
              child: ProfessionalResponsiveGrid(
                padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceLG),
                children: _users.map((user) {
                  return _StaggeredEntryItem(
                    index: _users.indexOf(user),
                    child: UserGridItem(
                      user: user,
                      onTap: widget.onUserTap,
                    ),
                  );
                }).toList(),
              ),
            ),

          // Bottom padding
          SliverPadding(
              padding: EdgeInsets.only(bottom: DesignTokens.spaceXXXL)),
        ],
      ),
    );
  }
}

class _StaggeredEntryItem extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggeredEntryItem({required this.index, required this.child});
  @override
  State<_StaggeredEntryItem> createState() => _StaggeredEntryItemState();
}

class _StaggeredEntryItemState extends State<_StaggeredEntryItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Staggered Delay (Cap for scrolling performance)
    int delay = (widget.index < 12 ? widget.index : 2) * 50;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
