import 'package:flutter/material.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/lounge_user.dart';
import 'package:freegram/repositories/lounge_repository.dart';
import 'package:freegram/screens/random_chat/widgets/user_grid_item.dart';

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
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. App Bar
          SliverAppBar(
            floating: true,
            backgroundColor: Colors.black,
            title: const Text(
              "Discover Live",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.white),
                onPressed: () {
                  // TODO: Filter logic
                },
              ),
            ],
          ),

          // 2. Grid Content
          if (_isLoading)
            SliverPadding(
              padding: const EdgeInsets.all(8.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const UserGridItemSkeleton(),
                  childCount: 6,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(8.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final user = _users[index];
                    return _StaggeredEntryItem(
                      index: index,
                      child: UserGridItem(
                        user: user,
                        onTap: widget.onUserTap,
                      ),
                    );
                  },
                  childCount: _users.length,
                ),
              ),
            ),
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
