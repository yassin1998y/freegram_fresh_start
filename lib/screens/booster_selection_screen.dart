import 'package:flutter/material.dart';
import 'package:freegram/models/game_session.dart';
import 'package:freegram/screens/matchmaking_screen.dart';

class BoosterSelectionScreen extends StatefulWidget {
  const BoosterSelectionScreen({super.key});

  @override
  State<BoosterSelectionScreen> createState() => _BoosterSelectionScreenState();
}

class _BoosterSelectionScreenState extends State<BoosterSelectionScreen> {
  BoosterType? _selectedBooster = BoosterType.bomb;
  final List<PerkType> _selectedPerks = [];

  final List<BoosterType> _availableBoosters = BoosterType.values;
  final List<PerkType> _availablePerks = PerkType.values;

  void _onPerkSelected(PerkType perk) {
    setState(() {
      if (_selectedPerks.contains(perk)) {
        _selectedPerks.remove(perk);
      } else if (_selectedPerks.length < 2) {
        _selectedPerks.add(perk);
      }
    });
  }

  void _findMatch() {
    if (_selectedBooster != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MatchmakingScreen(
          selectedBooster: _selectedBooster!,
          selectedPerks: _selectedPerks,
        ),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a booster to continue.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Loadout')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Select Your Booster',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _buildBoosterGrid(),
            const SizedBox(height: 24),
            Text('Select Up to Two Perks',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _buildPerkGrid(),
            const Spacer(),
            ElevatedButton(
              onPressed: _findMatch,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('Find Match'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoosterGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _availableBoosters.length,
      itemBuilder: (context, index) {
        final booster = _availableBoosters[index];
        final isSelected = _selectedBooster == booster;
        return GestureDetector(
          onTap: () => setState(() => _selectedBooster = booster),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
                  : null,
            ),
            child: Icon(_getIconForBooster(booster),
                size: 40,
                color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).iconTheme.color),
          ),
        );
      },
    );
  }

  Widget _buildPerkGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _availablePerks.length,
      itemBuilder: (context, index) {
        final perk = _availablePerks[index];
        final isSelected = _selectedPerks.contains(perk);
        return GestureDetector(
          onTap: () => _onPerkSelected(perk),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
                  : null,
            ),
            child: Icon(_getIconForPerk(perk),
                size: 40,
                color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).iconTheme.color),
          ),
        );
      },
    );
  }

  IconData _getIconForBooster(BoosterType type) {
    switch (type) {
      case BoosterType.bomb:
        return Icons.brightness_7;
      case BoosterType.arrow:
        return Icons.open_with;
      case BoosterType.hammer:
        return Icons.gavel;
      case BoosterType.shuffle:
        return Icons.shuffle;
    }
  }

  IconData _getIconForPerk(PerkType type) {
    switch (type) {
      case PerkType.extraMove:
        return Icons.add_circle_outline;
      case PerkType.colorSplash:
        return Icons.color_lens_outlined;
    }
  }
}