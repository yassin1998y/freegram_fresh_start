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
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: Colors.deepPurple)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(8.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75, // Taller cards
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final user = _users[index];
                    return UserGridItem(
                      user: user,
                      onTap: widget.onUserTap,
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
