import 'package:flutter/foundation.dart';
import 'package:freegram/screens/random_chat/models/match_partner_context.dart';
import 'package:freegram/models/match_history_model.dart';
import 'package:freegram/repositories/match_history_repository.dart';
import 'package:freegram/locator.dart';

class MatchMonitorService {
  MatchMonitorService._internal();
  static final MatchMonitorService instance = MatchMonitorService._internal();

  /// Records the end of a session if it lasted longer than a threshold.
  Future<void> recordSessionEnd({
    required MatchPartnerContext partner,
    required int durationSeconds,
  }) async {
    // Only save history for meaningful connections (e.g., > 5 seconds)
    if (durationSeconds > 5) {
      if (partner.id.isNotEmpty) {
        final match = MatchHistoryModel(
          id: partner.id,
          nickname: partner.name,
          avatarUrl: partner.avatarUrl.isNotEmpty ? partner.avatarUrl : "https://via.placeholder.com/150",
          timestamp: DateTime.now(),
          durationSeconds: durationSeconds,
        );

        try {
          await locator<MatchHistoryRepository>().saveMatch(match);
          debugPrint('✅ [HISTORY] Match saved: ${partner.name} ($durationSeconds s)');
        } catch (e) {
          debugPrint('❌ [HISTORY_ERROR] Failed to save match: $e');
        }
      }
    }
  }
}
