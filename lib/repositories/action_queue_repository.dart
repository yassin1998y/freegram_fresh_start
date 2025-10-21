import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class ActionQueueRepository {
  late final Box _queueBox;

  ActionQueueRepository() {
    // This assumes the box is already opened in main.dart
    _queueBox = Hive.box('action_queue');
  }

  /// Adds a new action to the offline queue.
  Future<void> addAction({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final String actionId = const Uuid().v4();
    await _queueBox.put(actionId, {
      'id': actionId,
      'type': type,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Retrieves all actions from the queue.
  List<Map<dynamic, dynamic>> getQueuedActions() {
    return _queueBox.values.toList().cast<Map<dynamic, dynamic>>();
  }

  /// Removes a successfully synced action from the queue.
  Future<void> removeAction(String actionId) async {
    await _queueBox.delete(actionId);
  }

  /// Clears the entire action queue.
  Future<void> clearQueue() async {
    await _queueBox.clear();
  }
}