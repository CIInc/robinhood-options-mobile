import 'package:cloud_firestore/cloud_firestore.dart';

/// Strategy determining how a price threshold is evaluated for dividend reinvestment.
enum DripThresholdMode {
  /// Reinvest only when current market price is at or below the position's average cost basis.
  belowCostBasis,

  /// Reinvest only when market price is at or below a user-specified dollar price.
  belowFixedPrice,

  /// Reinvest only when current market price is at least X% below cost basis.
  discountFromCostBasis,
}

/// Custom rule for a specific symbol/instrument.
class InstrumentDripRule {
  String symbol;
  bool enabled;
  DripThresholdMode thresholdMode;
  double? targetPrice;
  double? discountPercent;
  bool reinvestFullDividend;
  String orderType; // 'market' or 'limit'
  String? notes;

  InstrumentDripRule({
    required this.symbol,
    this.enabled = true,
    this.thresholdMode = DripThresholdMode.belowCostBasis,
    this.targetPrice,
    this.discountPercent = 5.0,
    this.reinvestFullDividend = true,
    this.orderType = 'market',
    this.notes,
  });

  InstrumentDripRule copyWith({
    String? symbol,
    bool? enabled,
    DripThresholdMode? thresholdMode,
    double? targetPrice,
    double? discountPercent,
    bool? reinvestFullDividend,
    String? orderType,
    String? notes,
  }) {
    return InstrumentDripRule(
      symbol: symbol ?? this.symbol,
      enabled: enabled ?? this.enabled,
      thresholdMode: thresholdMode ?? this.thresholdMode,
      targetPrice: targetPrice ?? this.targetPrice,
      discountPercent: discountPercent ?? this.discountPercent,
      reinvestFullDividend: reinvestFullDividend ?? this.reinvestFullDividend,
      orderType: orderType ?? this.orderType,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'enabled': enabled,
        'thresholdMode': thresholdMode.name,
        'targetPrice': targetPrice,
        'discountPercent': discountPercent,
        'reinvestFullDividend': reinvestFullDividend,
        'orderType': orderType,
        'notes': notes,
      };

  factory InstrumentDripRule.fromJson(Map<String, dynamic> json) {
    return InstrumentDripRule(
      symbol: json['symbol'] as String,
      enabled: (json['enabled'] as bool?) ?? true,
      thresholdMode: DripThresholdMode.values.firstWhere(
        (e) => e.name == json['thresholdMode'],
        orElse: () => DripThresholdMode.belowCostBasis,
      ),
      targetPrice: (json['targetPrice'] as num?)?.toDouble(),
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 5.0,
      reinvestFullDividend: (json['reinvestFullDividend'] as bool?) ?? true,
      orderType: (json['orderType'] as String?) ?? 'market',
      notes: json['notes'] as String?,
    );
  }
}

/// Record of an automated DRIP evaluation or executed reinvestment transaction.
class DripTransaction {
  final String id;
  final DateTime timestamp;
  final String symbol;
  final String? instrumentName;
  final double dividendAmount;
  final double executionPrice;
  final double? thresholdPrice;
  final double sharesPurchased;
  final String status; // 'executed', 'threshold_unmet', 'skipped', 'failed'
  final String? orderId;
  final String? notes;

  const DripTransaction({
    required this.id,
    required this.timestamp,
    required this.symbol,
    this.instrumentName,
    required this.dividendAmount,
    required this.executionPrice,
    this.thresholdPrice,
    required this.sharesPurchased,
    required this.status,
    this.orderId,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'symbol': symbol,
        'instrumentName': instrumentName,
        'dividendAmount': dividendAmount,
        'executionPrice': executionPrice,
        'thresholdPrice': thresholdPrice,
        'sharesPurchased': sharesPurchased,
        'status': status,
        'orderId': orderId,
        'notes': notes,
      };

  factory DripTransaction.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    final rawDate = json['timestamp'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return DripTransaction(
      id: json['id']?.toString() ?? '',
      timestamp: parsedDate,
      symbol: (json['symbol'] ?? '').toString(),
      instrumentName: json['instrumentName']?.toString(),
      dividendAmount: (json['dividendAmount'] as num?)?.toDouble() ?? 0.0,
      executionPrice: (json['executionPrice'] as num?)?.toDouble() ?? 0.0,
      thresholdPrice: (json['thresholdPrice'] as num?)?.toDouble(),
      sharesPurchased: (json['sharesPurchased'] as num?)?.toDouble() ?? 0.0,
      status: (json['status'] ?? 'executed').toString(),
      orderId: json['orderId']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

/// Overall configuration for Automated DRIP with Price Thresholds.
class AutomatedDripConfig {
  /// Master toggle for automated DRIP execution
  bool enabled;

  /// Default threshold mode when an instrument does not have an explicit rule
  DripThresholdMode defaultMode;

  /// Default percentage discount below cost basis if mode is discountFromCostBasis
  double defaultDiscountPercent;

  /// Default order execution type: 'market' or 'limit'
  String defaultOrderType;

  /// Per-symbol customized threshold rules
  Map<String, InstrumentDripRule> instrumentRules;

  /// Audit log of DRIP transactions and evaluations
  List<DripTransaction> transactions;

  AutomatedDripConfig({
    this.enabled = false,
    this.defaultMode = DripThresholdMode.belowCostBasis,
    this.defaultDiscountPercent = 5.0,
    this.defaultOrderType = 'market',
    Map<String, InstrumentDripRule>? instrumentRules,
    List<DripTransaction>? transactions,
  })  : instrumentRules = instrumentRules ?? {},
        transactions = transactions ?? [];

  AutomatedDripConfig copyWith({
    bool? enabled,
    DripThresholdMode? defaultMode,
    double? defaultDiscountPercent,
    String? defaultOrderType,
    Map<String, InstrumentDripRule>? instrumentRules,
    List<DripTransaction>? transactions,
  }) {
    return AutomatedDripConfig(
      enabled: enabled ?? this.enabled,
      defaultMode: defaultMode ?? this.defaultMode,
      defaultDiscountPercent:
          defaultDiscountPercent ?? this.defaultDiscountPercent,
      defaultOrderType: defaultOrderType ?? this.defaultOrderType,
      instrumentRules: instrumentRules != null
          ? Map.from(instrumentRules)
          : Map.from(this.instrumentRules),
      transactions: transactions != null
          ? List.from(transactions)
          : List.from(this.transactions),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'defaultMode': defaultMode.name,
        'defaultDiscountPercent': defaultDiscountPercent,
        'defaultOrderType': defaultOrderType,
        'instrumentRules':
            instrumentRules.map((k, v) => MapEntry(k, v.toJson())),
        'transactions': transactions.map((t) => t.toJson()).toList(),
      };

  factory AutomatedDripConfig.fromJson(Map<String, dynamic> json) {
    final rulesMap = <String, InstrumentDripRule>{};
    if (json['instrumentRules'] is Map) {
      (json['instrumentRules'] as Map).forEach((k, v) {
        if (v is Map) {
          rulesMap[k.toString()] =
              InstrumentDripRule.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }

    final txList = <DripTransaction>[];
    if (json['transactions'] is List) {
      for (final t in json['transactions'] as List) {
        if (t is Map) {
          txList.add(DripTransaction.fromJson(Map<String, dynamic>.from(t)));
        }
      }
    }

    return AutomatedDripConfig(
      enabled: (json['enabled'] as bool?) ?? false,
      defaultMode: DripThresholdMode.values.firstWhere(
        (e) => e.name == json['defaultMode'],
        orElse: () => DripThresholdMode.belowCostBasis,
      ),
      defaultDiscountPercent:
          (json['defaultDiscountPercent'] as num?)?.toDouble() ?? 5.0,
      defaultOrderType: (json['defaultOrderType'] as String?) ?? 'market',
      instrumentRules: rulesMap,
      transactions: txList,
    );
  }

  /// Helper to get or create an effective rule for a symbol
  InstrumentDripRule getRuleForSymbol(String symbol, {double? costBasis}) {
    final upper = symbol.toUpperCase();
    if (instrumentRules.containsKey(upper)) {
      return instrumentRules[upper]!;
    }
    return InstrumentDripRule(
      symbol: upper,
      enabled: enabled,
      thresholdMode: defaultMode,
      discountPercent: defaultDiscountPercent,
      orderType: defaultOrderType,
    );
  }
}
