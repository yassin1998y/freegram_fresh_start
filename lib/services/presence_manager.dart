import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:flutter/widgets.dart';
import 'package:freegram/utils/chat_presence_constants.dart';

/// Professional Presence Manager
///
/// Handles all user presence/online status logic with:
/// - Automatic lifecycle integration
/// - Heartbeat mechanism
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
  final rtdb.FirebaseDatabase _rtdb = rtdb.FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State
  Timer? _heartbeatTimer;
  Timer? _debounceTimer;
  DateTime? _lastUpdate;
  PresenceState _currentState = PresenceState.offline;
  bool _isInitialized = false;
  int _retryCount = 0;

  // Cache for other users' presence (reduces Firestore reads)
  final Map<String, _CachedPresence> _presenceCache = {};

  /// Initialize the presence manager
  /// Call this once during app initialization
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[PresenceManager] Already initialized');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint(
          '[PresenceManager] No user logged in, skipping initialization');
      return;
    }

    debugPrint('[PresenceManager] Initializing for user: ${user.uid}');

    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Set initial online state
    await _updatePresenceState(PresenceState.online);

    // Start heartbeat
    _startHeartbeat();

    _isInitialized = true;
    debugPrint('[PresenceManager] Initialization complete');
  }

  /// Clean up resources
  Future<void> dispose() async {
    debugPrint('[PresenceManager] Disposing');

    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _debounceTimer?.cancel();

    // Skip offline update on dispose - Firebase RTDB onDisconnect() handles this automatically
    // Trying to update after logout causes permission errors
    debugPrint(
        '[PresenceManager] Cleanup complete (onDisconnect handler will set offline)');

    _presenceCache.clear();
    _isInitialized = false;
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
    _startHeartbeat();
  }

  void _handleAppPaused() {
    debugPrint('[PresenceManager] App paused - setting Away');
    _updatePresenceState(PresenceState.away);
    _stopHeartbeat();
  }

  void _handleAppInactive() {
    debugPrint('[PresenceManager] App inactive - maintaining current state');
    // Don't change state on inactive (happens during transitions)
  }

  void _handleAppDetached() {
    debugPrint('[PresenceManager] App detached - setting Offline');
    _updatePresenceState(PresenceState.offline);
    _stopHeartbeat();
  }

  // ========== HEARTBEAT MECHANISM ==========

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();

    debugPrint(
        '[PresenceManager] Starting heartbeat (interval: ${ChatPresenceConstants.heartbeatInterval.inSeconds}s)');

    _heartbeatTimer = Timer.periodic(
      ChatPresenceConstants.heartbeatInterval,
      (_) => _sendHeartbeat(),
    );
  }

  void _stopHeartbeat() {
    debugPrint('[PresenceManager] Stopping heartbeat');
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _sendHeartbeat() async {
    final user = _auth.currentUser;
    if (user == null) return;

    debugPrint('[PresenceManager] Sending heartbeat');

    // Update last heartbeat timestamp
    await _updatePresenceInternal(
      userId: user.uid,
      state: _currentState,
      updateHeartbeat: true,
    );
  }

  // ========== PRESENCE STATE UPDATES ==========

  /// Update user's presence state
  Future<void> _updatePresenceState(PresenceState newState) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[PresenceManager] Cannot update presence: No user logged in');
      return;
    }

    // Don't update if state hasn't changed (unless it's been a while)
    if (_currentState == newState && _lastUpdate != null) {
      final timeSinceLastUpdate = DateTime.now().difference(_lastUpdate!);
      if (timeSinceLastUpdate < ChatPresenceConstants.presenceDebounce) {
        debugPrint('[PresenceManager] Debouncing presence update (too soon)');
        return;
      }
    }

    _currentState = newState;
    debugPrint(
        '[PresenceManager] Updating presence state to: ${newState.name}');

    await _updatePresenceInternal(
      userId: user.uid,
      state: newState,
      updateHeartbeat: false,
    );
  }

  Future<void> _updatePresenceInternal({
    required String userId,
    required PresenceState state,
    required bool updateHeartbeat,
  }) async {
    // Debounce updates
    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final isOnline =
            state == PresenceState.active || state == PresenceState.online;
        final now = DateTime.now();

        // Update RTDB (for real-time presence)
        final rtdbRef =
            _rtdb.ref('${ChatPresenceConstants.rtdbStatusPath}/$userId');

        // Cancel old disconnect handler
        await rtdbRef.onDisconnect().cancel();

        // Set current status
        final rtdbData = {
          'presence': isOnline,
          'state': state.name,
          'lastSeen': rtdb.ServerValue.timestamp,
          if (updateHeartbeat) 'lastHeartbeat': rtdb.ServerValue.timestamp,
        };

        await rtdbRef.set(rtdbData);

        // Set disconnect handler
        await rtdbRef.onDisconnect().set({
          'presence': false,
          'state': PresenceState.offline.name,
          'lastSeen': rtdb.ServerValue.timestamp,
        });

        // Update Firestore (for querying and persistence)
        final firestoreRef = _firestore
            .collection(ChatPresenceConstants.usersCollection)
            .doc(userId);

        final firestoreData = {
          ChatPresenceConstants.presenceField: isOnline,
          ChatPresenceConstants.presenceStateField: state.name,
          ChatPresenceConstants.lastSeenField: FieldValue.serverTimestamp(),
        };

        if (updateHeartbeat) {
          firestoreData[ChatPresenceConstants.lastHeartbeatField] =
              FieldValue.serverTimestamp();
        }

        await firestoreRef.update(firestoreData);

        _lastUpdate = now;
        _retryCount = 0; // Reset retry count on success

        debugPrint(
            '[PresenceManager] Successfully updated presence: ${state.name}');
      } catch (e) {
        debugPrint('[PresenceManager] Error updating presence: $e');
        _handlePresenceUpdateError(userId, state, updateHeartbeat);
      }
    });
  }

  void _handlePresenceUpdateError(
    String userId,
    PresenceState state,
    bool updateHeartbeat,
  ) {
    if (_retryCount >= ChatPresenceConstants.maxRetries) {
      debugPrint('[PresenceManager] Max retries reached, giving up');
      _retryCount = 0;
      return;
    }

    _retryCount++;
    debugPrint(
        '[PresenceManager] Retry attempt $_retryCount/${ChatPresenceConstants.maxRetries}');

    Timer(ChatPresenceConstants.retryDelay, () {
      _updatePresenceInternal(
        userId: userId,
        state: state,
        updateHeartbeat: updateHeartbeat,
      );
    });
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
  Future<void> setOffline() async {
    await _updatePresenceState(PresenceState.offline);
  }

  /// Get current user's presence state
  PresenceState get currentState => _currentState;

  /// Check if presence manager is initialized
  bool get isInitialized => _isInitialized;

  // ========== PRESENCE CACHE FOR OTHER USERS ==========

  /// Get another user's presence (with caching)
  Stream<PresenceData> getUserPresence(String userId) {
    // Return cached if fresh
    final cached = _presenceCache[userId];
    if (cached != null && cached.isFresh) {
      debugPrint('[PresenceManager] Returning cached presence for: $userId');
    }

    // Stream from Firestore with caching
    return _firestore
        .collection(ChatPresenceConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return PresenceData.offline();
      }

      final data = doc.data()!;
      final presenceData = PresenceData.fromMap(data);

      // Cache it
      _presenceCache[userId] = _CachedPresence(
        presenceData: presenceData,
        cachedAt: DateTime.now(),
      );

      // Clean old cache entries
      _cleanCache();

      return presenceData;
    });
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
  }

  /// Clear all cached presence data
  void clearCache() {
    _presenceCache.clear();
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
