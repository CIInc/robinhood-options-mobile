import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:robinhood_options_mobile/model/live_activity_models.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';

/// Service managing iOS ActivityKit Live Activities and Dynamic Island widgets
/// for real-time option positions and 0DTE trailing stops.
class LiveActivityService {
  static const MethodChannel _channel =
      MethodChannel('com.realizealpha.live_activity');

  static final LiveActivityService instance = LiveActivityService._internal();
  factory LiveActivityService() => instance;

  LiveActivityService._internal();

  /// Visible for testing to inject mock channel or test state
  @visibleForTesting
  LiveActivityService.withChannel(MethodChannel channel) {
    // testing constructor
  }

  final Map<String, OptionLiveActivitySession> _activeSessions = {};

  final ValueNotifier<Map<String, OptionLiveActivitySession>>
      activeSessionsNotifier =
      ValueNotifier<Map<String, OptionLiveActivitySession>>({});

  /// Checks if iOS Live Activities are supported and enabled on the current device.
  Future<bool> isSupported() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    try {
      final bool? enabled =
          await _channel.invokeMethod<bool>('areActivitiesEnabled');
      return enabled ?? false;
    } on PlatformException catch (e) {
      debugPrint('LiveActivityService: areActivitiesEnabled error: $e');
      return false;
    } catch (e) {
      debugPrint('LiveActivityService: unexpected error checking support: $e');
      return false;
    }
  }

  /// Checks if an option position is currently tracked by an active Live Activity.
  bool isPositionTracked(String positionId) {
    return _activeSessions.containsKey(positionId);
  }

  /// Returns the active tracking session for a position if one exists.
  OptionLiveActivitySession? getSession(String positionId) {
    return _activeSessions[positionId];
  }

  /// Returns a list of all current tracking sessions.
  List<OptionLiveActivitySession> getAllSessions() {
    return _activeSessions.values.toList();
  }

  /// Starts a Live Activity for the specified option position.
  Future<OptionLiveActivitySession?> startOptionPositionActivity(
    OptionAggregatePosition position, {
    double trailingStopPercent = 10.0,
    double? initialPeakPrice,
  }) async {
    try {
      OptionLiveActivitySession session =
          OptionLiveActivitySession.fromPosition(
        position,
        trailingStopPercent: trailingStopPercent,
        customInitialPeakPrice: initialPeakPrice,
      );

      String? activityId;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final payload = session.toChannelPayload();
        activityId =
            await _channel.invokeMethod<String>('startLiveActivity', payload);
      } else {
        // Mock activity ID for non-iOS platforms (e.g. testing / demo / mac)
        activityId = 'mock_activity_${position.id}';
      }

      if (activityId != null) {
        session = session.copyWithActivityId(activityId);
      }

      _activeSessions[position.id] = session;
      _notifyListeners();
      debugPrint(
          'LiveActivityService: Started activity for ${position.symbol} (ID: $activityId)');
      return session;
    } on PlatformException catch (e) {
      debugPrint('LiveActivityService: Failed to start Live Activity: $e');
      return null;
    } catch (e) {
      debugPrint('LiveActivityService: Unexpected error starting activity: $e');
      return null;
    }
  }

  /// Updates an active Live Activity session with refreshed quote/market data.
  Future<OptionLiveActivitySession?> updateOptionPositionActivity(
    String positionId,
    OptionAggregatePosition position,
  ) async {
    final existingSession = _activeSessions[positionId];
    if (existingSession == null) return null;

    try {
      final updatedSession = existingSession.copyWithUpdatedPosition(position);

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _channel.invokeMethod<void>(
          'updateLiveActivity',
          updatedSession.toChannelPayload(),
        );
      }

      _activeSessions[positionId] = updatedSession;
      _notifyListeners();
      return updatedSession;
    } on PlatformException catch (e) {
      debugPrint('LiveActivityService: Failed to update Live Activity: $e');
      return existingSession;
    } catch (e) {
      debugPrint('LiveActivityService: Unexpected error updating activity: $e');
      return existingSession;
    }
  }

  /// Updates trailing stop percentage for an existing active session.
  Future<OptionLiveActivitySession?> updateTrailingStopPercent(
    String positionId,
    double newPercent,
  ) async {
    final existingSession = _activeSessions[positionId];
    if (existingSession == null) return null;

    try {
      final updatedSession =
          existingSession.copyWithTrailingStopPercent(newPercent);

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _channel.invokeMethod<void>(
          'updateLiveActivity',
          updatedSession.toChannelPayload(),
        );
      }

      _activeSessions[positionId] = updatedSession;
      _notifyListeners();
      return updatedSession;
    } on PlatformException catch (e) {
      debugPrint('LiveActivityService: Failed to update stop percent: $e');
      return existingSession;
    } catch (e) {
      debugPrint('LiveActivityService: Unexpected error: $e');
      return existingSession;
    }
  }

  /// Ends a Live Activity session for an option position.
  Future<bool> endOptionPositionActivity(String positionId) async {
    final existingSession = _activeSessions[positionId];
    if (existingSession == null) return false;

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _channel.invokeMethod<void>('endLiveActivity', {
          'positionId': positionId,
          'activityId': existingSession.activityId,
        });
      }

      _activeSessions.remove(positionId);
      _notifyListeners();
      debugPrint(
          'LiveActivityService: Ended activity for position: $positionId');
      return true;
    } on PlatformException catch (e) {
      debugPrint('LiveActivityService: Failed to end Live Activity: $e');
      _activeSessions.remove(positionId);
      _notifyListeners();
      return false;
    } catch (e) {
      debugPrint('LiveActivityService: Unexpected error ending activity: $e');
      _activeSessions.remove(positionId);
      _notifyListeners();
      return false;
    }
  }

  /// Ends all active Live Activities.
  Future<void> endAllActivities() async {
    final positionIds = _activeSessions.keys.toList();
    for (final id in positionIds) {
      await endOptionPositionActivity(id);
    }
  }

  void _notifyListeners() {
    activeSessionsNotifier.value = Map.unmodifiable(_activeSessions);
  }

  @visibleForTesting
  void clearInternalState() {
    _activeSessions.clear();
    _notifyListeners();
  }
}
