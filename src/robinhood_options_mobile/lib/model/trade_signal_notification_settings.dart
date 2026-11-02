/// Trade Signal & Multi-Channel Alert Notification Settings Model
///
/// Stores user preferences for receiving notifications across multiple
/// delivery channels (Push, In-App, Email, SMS, Webhook), custom alert sounds,
/// priority notification channels, quiet hours, and granular per-signal triggers.
class TradeSignalNotificationSettings {
  static const List<String> availableChannels = [
    'push',
    'in_app',
    'email',
    'sms',
    'webhook',
  ];

  static const List<String> availablePriorities = [
    'critical',
    'high',
    'standard',
    'low',
  ];

  static const List<String> availableSounds = [
    'default',
    'chime',
    'bell',
    'pulse',
    'radar',
    'silent',
  ];

  static const List<String> availableIndicators = [
    'priceMovement',
    'momentum',
    'marketDirection',
    'volume',
    'macd',
    'bollingerBands',
    'stochastic',
    'atr',
    'obv',
    'vwap',
    'adx',
    'williamsR',
    'gex',
  ];

  static const Map<String, String> indicatorDisplayNames = {
    'priceMovement': 'Price Movement',
    'momentum': 'RSI / Momentum',
    'marketDirection': 'Market Direction',
    'volume': 'Volume',
    'macd': 'MACD',
    'bollingerBands': 'Bollinger Bands',
    'stochastic': 'Stochastic',
    'atr': 'ATR Volatility',
    'obv': 'On-Balance Volume (OBV)',
    'vwap': 'VWAP',
    'adx': 'ADX Trend',
    'williamsR': 'Williams %R',
    'gex': 'GEX Regime',
  };

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

  /// Whether to notify for Macro Assessment regime shifts
  bool macroAlerts;

  /// Active delivery channels: 'push', 'in_app', 'email', 'sms', 'webhook'
  List<String> deliveryChannels;

  /// Optional destination email address for email channel alerts
  String? emailAddress;

  /// Optional destination phone number (E.164 or local) for SMS alerts
  String? phoneNumber;

  /// Optional webhook URL for automated external routing (Discord, Slack, custom bot)
  String? webhookUrl;

  /// When true, Email/SMS/Webhook channels only fire for critical priority or
  /// high-conviction (>= 80% confidence) signals to prevent alert fatigue.
  bool criticalOnlyExternalChannels;

  /// Default priority channel: 'critical', 'high', 'standard', 'low'
  String priorityChannel;

  /// Default alert sound preset: 'default', 'chime', 'bell', 'pulse', 'radar', 'silent'
  String alertSound;

  /// Whether device vibration is enabled for notifications
  bool vibrate;

  /// Per-signal/category sound overrides (keys: 'BUY', 'SELL', 'GEX', 'FLOW')
  Map<String, String> signalSoundOverrides;

  /// Whether Quiet Hours (Do Not Disturb) window is enabled
  bool quietHoursEnabled;

  /// Quiet Hours start hour in 24h format (0-23, default 22 = 10:00 PM)
  int quietHoursStartHour;

  /// Quiet Hours end hour in 24h format (0-23, default 7 = 7:00 AM)
  int quietHoursEndHour;

  /// Whether critical priority alerts bypass Quiet Hours suppression
  bool bypassQuietHoursForCritical;

  /// Granular indicator triggers that must align with the signal to notify
  /// (empty means any indicator combination can notify)
  List<String> requiredIndicators;

  /// Category toggle for price & technical breakout alerts
  bool priceTriggerEnabled;

  /// Category toggle for Gamma Exposure (GEX wall/flip/squeeze) alerts
  bool gexTriggerEnabled;

  /// Category toggle for institutional Options Flow alerts
  bool optionsFlowTriggerEnabled;

  TradeSignalNotificationSettings({
    this.enabled = true,
    this.signalTypes = const ['BUY', 'SELL'],
    this.symbols = const [],
    this.intervals = const [],
    this.includeHold = false,
    this.minConfidence,
    this.macroAlerts = true,
    this.deliveryChannels = const ['push', 'in_app'],
    this.emailAddress,
    this.phoneNumber,
    this.webhookUrl,
    this.criticalOnlyExternalChannels = true,
    this.priorityChannel = 'high',
    this.alertSound = 'default',
    this.vibrate = true,
    this.signalSoundOverrides = const {},
    this.quietHoursEnabled = false,
    this.quietHoursStartHour = 22,
    this.quietHoursEndHour = 7,
    this.bypassQuietHoursForCritical = true,
    this.requiredIndicators = const [],
    this.priceTriggerEnabled = true,
    this.gexTriggerEnabled = true,
    this.optionsFlowTriggerEnabled = true,
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
            : null,
        macroAlerts = json['macroAlerts'] as bool? ?? true,
        deliveryChannels = (json['deliveryChannels'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            ['push', 'in_app'],
        emailAddress = json['emailAddress'] as String?,
        phoneNumber = json['phoneNumber'] as String?,
        webhookUrl = json['webhookUrl'] as String?,
        criticalOnlyExternalChannels =
            json['criticalOnlyExternalChannels'] as bool? ?? true,
        priorityChannel = json['priorityChannel'] as String? ?? 'high',
        alertSound = json['alertSound'] as String? ?? 'default',
        vibrate = json['vibrate'] as bool? ?? true,
        signalSoundOverrides = (json['signalSoundOverrides'] is Map)
            ? Map<String, String>.from(
                (json['signalSoundOverrides'] as Map).map(
                  (k, v) => MapEntry(k.toString(), v.toString()),
                ),
              )
            : {},
        quietHoursEnabled = json['quietHoursEnabled'] as bool? ?? false,
        quietHoursStartHour =
            (json['quietHoursStartHour'] as num?)?.toInt() ?? 22,
        quietHoursEndHour = (json['quietHoursEndHour'] as num?)?.toInt() ?? 7,
        bypassQuietHoursForCritical =
            json['bypassQuietHoursForCritical'] as bool? ?? true,
        requiredIndicators = (json['requiredIndicators'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        priceTriggerEnabled = json['priceTriggerEnabled'] as bool? ?? true,
        gexTriggerEnabled = json['gexTriggerEnabled'] as bool? ?? true,
        optionsFlowTriggerEnabled =
            json['optionsFlowTriggerEnabled'] as bool? ?? true;

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'signalTypes': signalTypes,
      'symbols': symbols,
      'intervals': intervals,
      'includeHold': includeHold,
      'minConfidence': minConfidence,
      'macroAlerts': macroAlerts,
      'deliveryChannels': deliveryChannels,
      'emailAddress': emailAddress,
      'phoneNumber': phoneNumber,
      'webhookUrl': webhookUrl,
      'criticalOnlyExternalChannels': criticalOnlyExternalChannels,
      'priorityChannel': priorityChannel,
      'alertSound': alertSound,
      'vibrate': vibrate,
      'signalSoundOverrides': signalSoundOverrides,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStartHour': quietHoursStartHour,
      'quietHoursEndHour': quietHoursEndHour,
      'bypassQuietHoursForCritical': bypassQuietHoursForCritical,
      'requiredIndicators': requiredIndicators,
      'priceTriggerEnabled': priceTriggerEnabled,
      'gexTriggerEnabled': gexTriggerEnabled,
      'optionsFlowTriggerEnabled': optionsFlowTriggerEnabled,
    };
  }

  /// Resolves the effective sound for a given signal/alert category
  String soundForCategory(String category) {
    final override = signalSoundOverrides[category.toUpperCase()];
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return alertSound;
  }

  /// Resolves the Android notification channel ID for the configured priority
  String get androidChannelId {
    if (alertSound == 'silent' || priorityChannel == 'low') {
      return 'silent_digest';
    }
    if (priorityChannel == 'critical') {
      return 'critical_alerts';
    }
    return 'trade_signals';
  }

  static const Object _unset = Object();

  /// Create a copy with modified fields
  TradeSignalNotificationSettings copyWith({
    bool? enabled,
    List<String>? signalTypes,
    List<String>? symbols,
    List<String>? intervals,
    bool? includeHold,
    Object? minConfidence = _unset,
    bool? macroAlerts,
    List<String>? deliveryChannels,
    Object? emailAddress = _unset,
    Object? phoneNumber = _unset,
    Object? webhookUrl = _unset,
    bool? criticalOnlyExternalChannels,
    String? priorityChannel,
    String? alertSound,
    bool? vibrate,
    Map<String, String>? signalSoundOverrides,
    bool? quietHoursEnabled,
    int? quietHoursStartHour,
    int? quietHoursEndHour,
    bool? bypassQuietHoursForCritical,
    List<String>? requiredIndicators,
    bool? priceTriggerEnabled,
    bool? gexTriggerEnabled,
    bool? optionsFlowTriggerEnabled,
  }) {
    return TradeSignalNotificationSettings(
      enabled: enabled ?? this.enabled,
      signalTypes: signalTypes ?? this.signalTypes,
      symbols: symbols ?? this.symbols,
      intervals: intervals ?? this.intervals,
      includeHold: includeHold ?? this.includeHold,
      minConfidence: identical(minConfidence, _unset)
          ? this.minConfidence
          : minConfidence as double?,
      macroAlerts: macroAlerts ?? this.macroAlerts,
      deliveryChannels: deliveryChannels ?? this.deliveryChannels,
      emailAddress: identical(emailAddress, _unset)
          ? this.emailAddress
          : emailAddress as String?,
      phoneNumber: identical(phoneNumber, _unset)
          ? this.phoneNumber
          : phoneNumber as String?,
      webhookUrl: identical(webhookUrl, _unset)
          ? this.webhookUrl
          : webhookUrl as String?,
      criticalOnlyExternalChannels:
          criticalOnlyExternalChannels ?? this.criticalOnlyExternalChannels,
      priorityChannel: priorityChannel ?? this.priorityChannel,
      alertSound: alertSound ?? this.alertSound,
      vibrate: vibrate ?? this.vibrate,
      signalSoundOverrides: signalSoundOverrides ?? this.signalSoundOverrides,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStartHour: quietHoursStartHour ?? this.quietHoursStartHour,
      quietHoursEndHour: quietHoursEndHour ?? this.quietHoursEndHour,
      bypassQuietHoursForCritical:
          bypassQuietHoursForCritical ?? this.bypassQuietHoursForCritical,
      requiredIndicators: requiredIndicators ?? this.requiredIndicators,
      priceTriggerEnabled: priceTriggerEnabled ?? this.priceTriggerEnabled,
      gexTriggerEnabled: gexTriggerEnabled ?? this.gexTriggerEnabled,
      optionsFlowTriggerEnabled:
          optionsFlowTriggerEnabled ?? this.optionsFlowTriggerEnabled,
    );
  }
}
