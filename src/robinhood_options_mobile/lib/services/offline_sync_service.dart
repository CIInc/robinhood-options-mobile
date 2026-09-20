import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/services/offline_cache_service.dart';

/// Manages reactive connectivity state, offline indicators, and
/// intelligent background synchronization when connection is restored.
class OfflineSyncService extends ChangeNotifier {
  bool _isOffline = false;
  bool _isSyncing = false;
  bool _isShowingCachedData = false;
  DateTime? _lastSyncTime;
  String? _lastSyncError;
  bool _isOfflineSimulation = false;

  Timer? _connectivityPollTimer;
  final List<Future<void> Function()> _reconnectCallbacks = [];

  bool get isOffline => _isOfflineSimulation || _isOffline;
  bool get isSyncing => _isSyncing;
  bool get isShowingCachedData => _isShowingCachedData;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastSyncError => _lastSyncError;
  bool get isOfflineSimulation => _isOfflineSimulation;

  bool get isDataStale => OfflineCacheService.isDataStale(_lastSyncTime);
  String get freshnessLabel =>
      OfflineCacheService.formatRelativeTime(_lastSyncTime);
  String get syncDateTimeLabel =>
      OfflineCacheService.formatSyncDateTime(_lastSyncTime);

  OfflineSyncService() {
    _init();
  }

  Future<void> _init() async {
    final cached = await OfflineCacheService.getLastSyncTime();
    if (_lastSyncTime == null && cached != null) {
      _lastSyncTime = cached;
      notifyListeners();
    }
  }

  /// Start periodic background connectivity check if enabled
  void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    _connectivityPollTimer?.cancel();
    _connectivityPollTimer =
        Timer.periodic(interval, (_) => checkConnectivity());
  }

  /// Stop background connectivity monitoring
  void stopMonitoring() {
    _connectivityPollTimer?.cancel();
    _connectivityPollTimer = null;
  }

  /// Check connectivity using DNS lookup or reachability probe
  Future<bool> checkConnectivity() async {
    if (_isOfflineSimulation) {
      return false;
    }

    bool online = true;
    try {
      // In web or tests, InternetAddress.lookup might not be supported or mocked
      if (!kIsWeb) {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      }
    } catch (_) {
      online = false;
    }

    setOffline(!online);
    return online;
  }

  /// Explicitly set offline state (e.g. on network exception or successful request)
  void setOffline(bool offline, {String? reason}) {
    final wasOffline = isOffline;
    _isOffline = offline;
    if (reason != null) {
      _lastSyncError = reason;
    } else if (!offline) {
      _lastSyncError = null;
    }

    if (wasOffline && !isOffline) {
      debugPrint(
          'OfflineSyncService: Connection restored. Triggering reconnect sync callbacks.');
      _triggerReconnectSync();
    }

    notifyListeners();
  }

  /// Toggle manual simulation of offline mode (for testing and demoing)
  void setOfflineSimulation(bool simulate) {
    if (_isOfflineSimulation != simulate) {
      final wasOffline = isOffline;
      _isOfflineSimulation = simulate;
      notifyListeners();

      if (wasOffline && !isOffline) {
        _triggerReconnectSync();
      }
    }
  }

  /// Update whether the app is currently displaying cached offline data
  void setShowingCachedData(bool showingCached) {
    if (_isShowingCachedData != showingCached) {
      _isShowingCachedData = showingCached;
      notifyListeners();
    }
  }

  /// Update synchronization loading state
  void setSyncing(bool syncing) {
    if (_isSyncing != syncing) {
      _isSyncing = syncing;
      notifyListeners();
    }
  }

  /// Record a successful sync timestamp
  void recordSuccessfulSync([DateTime? timestamp]) {
    _lastSyncTime = timestamp ?? DateTime.now();
    _isOffline = false;
    _isShowingCachedData = false;
    _lastSyncError = null;
    notifyListeners();
  }

  /// Register a callback to be automatically invoked when connectivity is restored
  void registerReconnectCallback(Future<void> Function() callback) {
    if (!_reconnectCallbacks.contains(callback)) {
      _reconnectCallbacks.add(callback);
    }
  }

  /// Unregister a reconnect callback
  void unregisterReconnectCallback(Future<void> Function() callback) {
    _reconnectCallbacks.remove(callback);
  }

  /// Executes all registered reconnect callbacks in the background
  Future<void> _triggerReconnectSync() async {
    if (_reconnectCallbacks.isEmpty) return;
    setSyncing(true);
    try {
      for (final callback in List.of(_reconnectCallbacks)) {
        try {
          await callback();
        } catch (e) {
          debugPrint('OfflineSyncService: Error in reconnect callback: $e');
        }
      }
    } finally {
      setSyncing(false);
    }
  }

  /// Triggers a manual sync task with proper loading state management
  Future<void> triggerSync({Future<void> Function()? syncTask}) async {
    if (_isSyncing) return;
    setSyncing(true);
    try {
      if (syncTask != null) {
        await syncTask();
        recordSuccessfulSync();
      } else {
        await _triggerReconnectSync();
      }
    } catch (e) {
      _lastSyncError = e.toString();
      notifyListeners();
    } finally {
      setSyncing(false);
    }
  }

  @override
  void dispose() {
    _connectivityPollTimer?.cancel();
    _reconnectCallbacks.clear();
    super.dispose();
  }
}
