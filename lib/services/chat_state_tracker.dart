// lib/services/chat_state_tracker.dart
import 'package:flutter/foundation.dart';

/// Tracks which chat screen the user is currently viewing
/// This prevents notifications from showing when user is already in that chat
/// (Professional app behavior like WhatsApp, Messenger)
class ChatStateTracker {
  static final ChatStateTracker _instance = ChatStateTracker._internal();
  factory ChatStateTracker() => _instance;
  ChatStateTracker._internal();

  // Currently active chat ID (null if no chat is open)
  String? _currentChatId;

  // Currently viewing user ID (for friend requests, profiles, etc.)
  String? _currentViewingUserId;

  /// Register that user is currently viewing a specific chat
  void enterChat(String chatId) {
    _currentChatId = chatId;
    if (kDebugMode) {
      debugPrint('[ChatStateTracker] Entered chat: $chatId');
    }
  }

  /// User left the chat screen
  void exitChat(String chatId) {
    if (_currentChatId == chatId) {
      _currentChatId = null;
      if (kDebugMode) {
        debugPrint('[ChatStateTracker] Exited chat: $chatId');
      }
    }
  }

  /// Check if user is currently viewing a specific chat
  bool isInChat(String chatId) {
    return _currentChatId == chatId;
  }

  /// Register that user is viewing a specific user's profile
  void viewingProfile(String userId) {
    _currentViewingUserId = userId;
    if (kDebugMode) {
      debugPrint('[ChatStateTracker] Viewing profile: $userId');
    }
  }

  /// User left the profile screen
  void exitProfile(String userId) {
    if (_currentViewingUserId == userId) {
      _currentViewingUserId = null;
      if (kDebugMode) {
        debugPrint('[ChatStateTracker] Exited profile: $userId');
      }
    }
  }

  /// Check if user is currently viewing a specific user's profile
  bool isViewingProfile(String userId) {
    return _currentViewingUserId == userId;
  }

  /// Get current chat ID (null if no chat is open)
  String? get currentChatId => _currentChatId;

  /// Check if user is in any chat
  bool get isInAnyChat => _currentChatId != null;

  /// Reset all tracking (e.g., on logout)
  void reset() {
    _currentChatId = null;
    _currentViewingUserId = null;
    if (kDebugMode) {
      debugPrint('[ChatStateTracker] Reset all tracking');
    }
  }
}
