import 'package:freegram/models/match_history_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

class MatchHistoryRepository {
  static const String _boxName = 'match_history_box';

  Future<void> init() async {
    // Adapter registration should happen in main.dart usually,
    // but ensuring box is open here.
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<MatchHistoryModel>(_boxName);
    }
  }

  Future<void> saveMatch(MatchHistoryModel match) async {
    final box = Hive.box<MatchHistoryModel>(_boxName);
    await box.add(match);
  }

  List<MatchHistoryModel> getHistory() {
    final box = Hive.box<MatchHistoryModel>(_boxName);
    // Return reversed list to show newest first
    return box.values.toList().reversed.toList();
  }

  Future<void> clearHistory() async {
    final box = Hive.box<MatchHistoryModel>(_boxName);
    await box.clear();
  }
}
