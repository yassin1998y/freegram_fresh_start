import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:freegram/utils/chat_presence_constants.dart';
import 'package:freegram/services/realtime_presence_service.dart';

/// Professional Presence Manager
///
/// **REFACTORED FOR COST OPTIMIZATION:**
/// - Uses RealtimePresenceService (RTDB) for real-time presence (no Firestore writes)
/// - Only writes to Firestore once per session (on connect/disconnect) for long-term storage
/// - Eliminates 30-second heartbeat loop that was causing expensive Firestore writes
/// - Maintains real-time accuracy via RTDB streams
///
/// Handles all user presence/online status logic with:
/// - Automatic lifecycle integration
/// - Multi-state presence (Active/Online/Away/Offline)
/// - Debouncing and retry logic
/// - Platform-specific optimizations
/// - Memory-efficient caching
class PresenceManager with WidgetsBindingObserver {
  static final PresenceManager _instance = PresenceManager._internal();
  factory PresenceManager() => _instance;
  PresenceManager._internal();

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RealtimePresenceService _realtimePresence = RealtimePresenceService();

  // State
  Timer? _debounceTimer;
  PresenceState _currentState = PresenceState.offline;
  bool _isInitialized = false;
  String? _currentUserId; // Track which user is currently initialized

  // Cache for other users' presence (reduces RTDB reads)
  final Map<String, _CachedPresence> _presenceCache = {};

  // Cache for broadcast streams (allows multiple listeners)
  final Map<String, Stream<PresenceData>> _streamCache = {};

  /// Initialize the presence manager
  /// Call this once during app initialization
  Future<void> initialize() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint(
          '[PresenceManager] No user logged in, skipping initialization');
      return;
    }

    // CRITICAL FIX: Check if user changed - if so, dispose old user first
    if (_isInitialized &&
        _currentUserId != null &&
        _currentUserId != user.uid) {
      debugPrint(
          '[PresenceManager] User changed from $_currentUserId to ${user.uid} - disposing old user');
      // Dispose old user's presence before initializing new user
      await _disposeForUser(_currentUserId!);
    }

    // If already initialized for this user, skip
    if (_isInitialized && _currentUserId == user.uid) {
      debugPrint('[PresenceManager] Already initialized for user: ${user.uid}');
      return;
    }

    debugPrint('[PresenceManager] Initializing for user: ${user.uid}');

    // Add lifecycle observer (safe to call multiple times)
    WidgetsBinding.instance.addObserver(this);

    // Connect to RTDB (this sets user online in RTDB)
    try {
      await _realtimePresence
          .connect(user.uid)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint(
          '[PresenceManager] Warning: RTDB connection timed out or failed: $e');
      // Continue initialization even if RTDB fails
    }

    // Write to Firestore ONCE for session start (long-term storage)
    try {
      await _updateFirestorePresence(user.uid, PresenceState.online)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint(
          '[PresenceManager] Warning: Firestore presence update timed out or failed: $e');
    }

    _currentState = PresenceState.online;
    _currentUserId = user.uid;
    _isInitialized = true;

    debugPrint(
        '[PresenceManager] Initialization complete (RTDB connected, Firestore updated once)');
  }

  /// Clean up resources
  /// CRITICAL FIX: Uses stored user ID instead of currentUser (which may be null on logout)
  Future<void> dispose() async {
    debugPrint('[PresenceManager] Disposing');

    // Use stored user ID if available, fallback to currentUser
    final userIdToDispose = _currentUserId ?? _auth.currentUser?.uid;

    if (userIdToDispose != null) {
      await _disposeForUser(userIdToDispose);
    } else {
      // No user to dispose, just clean up local state
      WidgetsBinding.instance.removeObserver(this);
      _debounceTimer?.cancel();
      _presenceCache.clear();
      _streamCache.clear();
      _isInitialized = false;
      _currentUserId = null;
      debugPrint('[PresenceManager] Cleanup complete (no user to dispose)');
    }
  }

  /// Internal method to dispose for a specific user
  /// This ensures we can dispose even if currentUser is already null
  Future<void> _disposeForUser(String userId) async {
    debugPrint('[PresenceManager] Disposing for user: $userId');

    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();

    // Write to Firestore ONCE for session end (long-term storage)
    await _updateFirestorePresence(userId, PresenceState.offline);

    // Disconnect from RTDB (onDisconnect handler will set offline automatically)
    await _realtimePresence.disconnect();

    _presenceCache.clear();
    _streamCache.clear();
    _isInitialized = false;
    _currentUserId = null;
    _currentState = PresenceState.offline;

    debugPrint(
        '[PresenceManager] Cleanup complete for user $userId (Firestore updated once, RTDB disconnected)');
  }

  // ========== LIFECYCLE HANDLING ==========

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[PresenceManager] AppLifecycleState changed to: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.inactive:
        _handleAppInactive();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        // New state in recent Flutter versions
        _handleAppPaused();
        break;
    }
  }

  void _handleAppResumed() {
    debugPrint('[PresenceManager] App resumed - setting Active');
    _updatePresenceState(PresenceState.active);
  }

  void _handleAppPaused() {
    debugPrint('[PresenceManager] App paused - setting Away');
    _updatePresenceState(PresenceState.away);
  }

  void _handleAppInactive() {
    debugPrint('[PresenceManager] App inactive - maintaining current state');
    // Don't change state on inactive (happens during transitions)
  }

  void _handleAppDetached() {
    debugPrint('[PresenceManager] App detached - setting Offline');
    _updatePresenceState(PresenceState.offline);
  }

  // ========== PRESENCE STATE UPDATES ==========

  /// Update user's presence state
  /// This only updates RTDB (lightweight) - NOT Firestore
  Future<void> _updatePresenceState(PresenceState newState) async {
    // CRITICAL FIX: Use stored user ID to prevent updates for wrong user
    final userId = _currentUserId ?? _auth.currentUser?.uid;
    if (userId == null) {
      debugPrint('[PresenceManager] Cannot update presence: No user logged in');
      return;
    }

    // CRITICAL FIX: Validate that current user matches initialized user
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.uid != userId) {
      debugPrint(
          '[PresenceManager] User mismatch: initialized for $userId but current user is ${currentUser.uid}. Skipping update.');
      return;
    }

    // Don't update if state hasn't changed
    if (_currentState == newState) {
      return;
    }

    _currentState = newState;
    debugPrint(
        '[PresenceManager] Updating presence state to: ${newState.name} for user: $userId (RTDB only)');

    // Update RTDB only (lightweight, real-time)
    await _realtimePresence.updateState(userId, newState);

    // NOTE: We do NOT update Firestore here to save costs
    // Firestore is only updated on session start/end
  }

  /// Update Firestore presence (called once per session)
  /// This is for long-term storage and querying, not real-time presence
  Future<void> _updateFirestorePresence(
    String userId,
    PresenceState state,
  ) async {
    try {
      final isOnline =
          state == PresenceState.active || state == PresenceState.online;

      final firestoreRef = _firestore
          .collection(ChatPresenceConstants.usersCollection)
          .doc(userId);

      await firestoreRef.update({
        ChatPresenceConstants.presenceField: isOnline,
        ChatPresenceConstants.presenceStateField: state.name,
        ChatPresenceConstants.lastSeenField: FieldValue.serverTimestamp(),
      });

      debugPrint(
          '[PresenceManager] Updated Firestore presence (once per session): ${state.name}');
    } catch (e) {
      debugPrint('[PresenceManager] Error updating Firestore presence: $e');
      // Don't rethrow - Firestore update is for long-term storage only
    }
  }

  // ========== PUBLIC API ==========

  /// Manually trigger presence update (e.g., when user sends message)
  Future<void> refreshPresence() async {
    debugPrint('[PresenceManager] Manual presence refresh requested');
    await _updatePresenceState(PresenceState.active);
  }

  /// Set user as active (called when user interacts with app)
  Future<void> setActive() async {
    await _updatePresenceState(PresenceState.active);
  }

  /// Set user as online (called when app is open but idle)
  Future<void> setOnline() async {
    await _updatePresenceState(PresenceState.online);
  }

  /// Set user as away (called when app is backgrounded)
  Future<void> setAway() async {
    await _updatePresenceState(PresenceState.away);
  }

  /// Set user as offline (called when logging out)
  /// CRITICAL FIX: This method now properly handles logout even if user is already signed out
  Future<void> setOffline() async {
    // Use stored user ID if available (user might already be signed out)
    final userId = _currentUserId ?? _auth.currentUser?.uid;
    if (userId == null) {
      debugPrint(
          '[PresenceManager] setOffline called but no user ID available');
      // Still clean up local state
      _currentState = PresenceState.offline;
      return;
    }

    debugPrint('[PresenceManager] Setting user offline: $userId');

    // Update state first
    _currentState = PresenceState.offline;

    // Update RTDB
    await _realtimePresence.updateState(userId, PresenceState.offline);

    // Update Firestore for logout
    await _updateFirestorePresence(userId, PresenceState.offline);

    // Disconnect from RTDB
    await _realtimePresence.disconnect();

    // Clear state
    _isInitialized = false;
    _currentUserId = null;

    debugPrint('[PresenceManager] User set offline and disconnected: $userId');
  }

  /// Get current user's presence state
  PresenceState get currentState => _currentState;

  /// Check if presence manager is initialized
  bool get isInitialized => _isInitialized;

  // ========== PRESENCE CACHE FOR OTHER USERS ==========

  /// Get another user's presence (with caching)
  /// Now streams from RTDB for real-time updates (not Firestore)
  /// Returns a broadcast stream that can be listened to multiple times
  Stream<PresenceData> getUserPresence(String userId) {
    // Return cached broadcast stream if it exists
    if (_streamCache.containsKey(userId)) {
      debugPrint(
          '[PresenceManager] Returning cached broadcast stream for: $userId');
      return _streamCache[userId]!;
    }

    // Create broadcast stream from RTDB (real-time, no Firestore reads)
    final broadcastStream =
        _realtimePresence.getUserPresenceStream(userId).map((rtdbData) {
      // Convert RealtimePresenceData to PresenceData for compatibility
      final presenceData = PresenceData(
        isOnline: rtdbData.isOnline,
        state: rtdbData.presenceState,
        lastSeen: rtdbData.lastChanged,
        lastHeartbeat: null, // RTDB doesn't track heartbeat separately
      );

      // Cache it
      _presenceCache[userId] = _CachedPresence(
        presenceData: presenceData,
        cachedAt: DateTime.now(),
      );

      // Clean old cache entries
      _cleanCache();

      return presenceData;
    }).asBroadcastStream(
      onListen: (subscription) {
        debugPrint('[PresenceManager] First listener added for: $userId');
      },
      onCancel: (subscription) {
        debugPrint('[PresenceManager] Last listener removed for: $userId');
        // Optionally clean up stream cache when no listeners
        // But keep it for a bit in case widget rebuilds quickly
      },
    );

    // Cache the broadcast stream
    _streamCache[userId] = broadcastStream;

    return broadcastStream;
  }

  void _cleanCache() {
    if (_presenceCache.length > ChatPresenceConstants.maxCachedPresenceStates) {
      // Remove oldest entries
      final entries = _presenceCache.entries.toList()
        ..sort((a, b) => a.value.cachedAt.compareTo(b.value.cachedAt));

      final toRemove = entries.take(_presenceCache.length -
          ChatPresenceConstants.maxCachedPresenceStates);

      for (final entry in toRemove) {
        _presenceCache.remove(entry.key);
      }

      debugPrint(
          '[PresenceManager] Cleaned cache, removed ${toRemove.length} entries');
    }
  }

  /// Invalidate cache for a specific user
  void invalidateCache(String userId) {
    _presenceCache.remove(userId);
    _streamCache.remove(userId);
  }

  /// Clear all cached presence data
  void clearCache() {
    _presenceCache.clear();
    _streamCache.clear();
  }
}

/// Presence data model
class PresenceData {
  final bool isOnline;
  final PresenceState state;
  final DateTime lastSeen;
  final DateTime? lastHeartbeat;

  const PresenceData({
    required this.isOnline,
    required this.state,
    required this.lastSeen,
    this.lastHeartbeat,
  });

  factory PresenceData.fromMap(Map<String, dynamic> data) {
    return PresenceData(
      isOnline: data[ChatPresenceConstants.presenceField] ?? false,
      state: PresenceState.fromString(
          data[ChatPresenceConstants.presenceStateField]),
      lastSeen: _parseTimestamp(data[ChatPresenceConstants.lastSeenField]),
      lastHeartbeat:
          _parseTimestamp(data[ChatPresenceConstants.lastHeartbeatField]),
    );
  }

  factory PresenceData.offline() {
    return PresenceData(
      isOnline: false,
      state: PresenceState.offline,
      lastSeen: DateTime.now(),
    );
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        timestamp > 1000000000000 ? timestamp : timestamp * 1000,
      );
    }
    return DateTime.now();
  }

  /// Is user truly active right now?
  bool get isActiveNow {
    if (!isOnline) return false;
    final timeSinceLastSeen = DateTime.now().difference(lastSeen);
    return timeSinceLastSeen < ChatPresenceConstants.activeNowThreshold;
  }

  /// Should we show "Active now"?
  bool get showActiveNow {
    return isOnline && isActiveNow;
  }

  /// Get display text for presence
  String getDisplayText({bool includePrefix = true}) {
    if (showActiveNow) {
      return ChatPresenceConstants.labelActiveNow;
    }

    final timeSince = DateTime.now().difference(lastSeen);
    final prefix =
        includePrefix ? '${ChatPresenceConstants.labelLastSeen} ' : '';

    if (timeSince < ChatPresenceConstants.displayMinutesThreshold) {
      final minutes = timeSince.inMinutes;
      if (minutes < 1) return ChatPresenceConstants.labelJustNow;
      return '$prefix${minutes}m ago';
    }

    if (timeSince < ChatPresenceConstants.displayHoursThreshold) {
      final hours = timeSince.inHours;
      return '$prefix${hours}h ago';
    }

    if (timeSince < ChatPresenceConstants.displayDaysThreshold) {
      final days = timeSince.inDays;
      return '$prefix${days}d ago';
    }

    // Show actual date for older
    return '$prefix${_formatDate(lastSeen)}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year) {
      return '${_monthName(date.month)} ${date.day}';
    }
    return '${_monthName(date.month)} ${date.day}, ${date.year}';
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  /// Get short display text for badges (chat list)
  String getShortDisplayText() {
    if (showActiveNow) return '';

    final timeSince = DateTime.now().difference(lastSeen);

    if (timeSince.inMinutes < 60) {
      final minutes = timeSince.inMinutes;
      if (minutes < 1) return '';
      return '${minutes}m';
    }

    if (timeSince.inHours < 24) {
      return '${timeSince.inHours}h';
    }

    if (timeSince.inDays < 7) {
      return '${timeSince.inDays}d';
    }

    return '${timeSince.inDays}d';
  }

  /// Get color for presence indicator
  Color get color => state.color;
}

/// Cached presence entry
class _CachedPresence {
  final PresenceData presenceData;
  final DateTime cachedAt;

  _CachedPresence({
    required this.presenceData,
    required this.cachedAt,
  });

  bool get isFresh {
    final age = DateTime.now().difference(cachedAt);
    return age < ChatPresenceConstants.presenceCacheDuration;
  }
}
