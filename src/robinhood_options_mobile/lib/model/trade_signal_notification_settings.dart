/// Trade Signal Notification Settings Model
///
/// Stores user preferences for receiving push notifications when
/// trade signals are generated or updated.
class TradeSignalNotificationSettings {
  /// Whether trade signal notifications are enabled
  bool enabled;

  /// Which signal types to notify for (BUY, SELL, or both)
  /// If empty, notifies for both BUY and SELL
  List<String> signalTypes;

  /// Specific symbols to get notifications for
  /// If empty, notifies for all symbols
  List<String> symbols;

  /// Specific intervals to get notifications for (1d, 1h, 30m, 15m)
  /// If empty, notifies for all intervals
  List<String> intervals;

  /// Whether to include HOLD signals in notifications
  bool includeHold;

  /// Minimum confidence threshold (0.0 to 1.0)
  /// Only notify if signal confidence is above this threshold
  /// If null, no filtering by confidence
  double? minConfidence;

  TradeSignalNotificationSettings({
    this.enabled = true,
    this.signalTypes = const ['BUY', 'SELL'],
    this.symbols = const [],
    this.intervals = const [],
    this.includeHold = false,
    this.minConfidence,
  });

  TradeSignalNotificationSettings.fromJson(Map<String, dynamic> json)
      : enabled = json['enabled'] as bool? ?? true,
        signalTypes = (json['signalTypes'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            ['BUY', 'SELL'],
        symbols = (json['symbols'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        intervals = (json['intervals'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        includeHold = json['includeHold'] as bool? ?? false,
        minConfidence = json['minConfidence'] != null
            ? (json['minConfidence'] as num).toDouble()
            : null;

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'signalTypes': signalTypes,
      'symbols': symbols,
      'intervals': intervals,
      'includeHold': includeHold,
      'minConfidence': minConfidence,
    };
  }

  /// Create a copy with modified fields
  TradeSignalNotificationSettings copyWith({
    bool? enabled,
    List<String>? signalTypes,
    List<String>? symbols,
    List<String>? intervals,
    bool? includeHold,
    double? minConfidence,
  }) {
    return TradeSignalNotificationSettings(
      enabled: enabled ?? this.enabled,
      signalTypes: signalTypes ?? this.signalTypes,
      symbols: symbols ?? this.symbols,
      intervals: intervals ?? this.intervals,
      includeHold: includeHold ?? this.includeHold,
      minConfidence: minConfidence ?? this.minConfidence,
    );
  }
}
