import 'package:intl/intl.dart';

/// Represents a single trade action for an automated trade proposal.
enum AutomatedTradeAction {
  buy,
  sell;

  static AutomatedTradeAction fromString(String? value) {
    if (value == null) return AutomatedTradeAction.buy;
    final normalized = value.trim().toLowerCase();
    if (normalized == 'sell') return AutomatedTradeAction.sell;
    return AutomatedTradeAction.buy;
  }

  String toDisplayString() => name.toUpperCase();
}

/// Represents the GEX / agentic qualification state.
enum ProposalQualification {
  confirmed,
  pending,
  blocked,
  unknown;

  static ProposalQualification fromString(String? value) {
    if (value == null) return ProposalQualification.unknown;
    final normalized = value.trim().toUpperCase();
    switch (normalized) {
      case 'CONFIRMED':
        return ProposalQualification.confirmed;
      case 'PENDING':
        return ProposalQualification.pending;
      case 'BLOCKED':
        return ProposalQualification.blocked;
      default:
        return ProposalQualification.unknown;
    }
  }

  String toDisplayString() {
    switch (this) {
      case ProposalQualification.confirmed:
        return 'CONFIRMED';
      case ProposalQualification.pending:
        return 'PENDING';
      case ProposalQualification.blocked:
        return 'BLOCKED';
      case ProposalQualification.unknown:
        return 'UNKNOWN';
    }
  }
}

/// Strongly typed domain model representing an automated trade proposal
/// requiring manual review and approval before broker or paper execution.
class AutomatedTradeProposal {
  final String id;
  final String? firestoreId;
  final DateTime timestamp;
  final String symbol;
  final AutomatedTradeAction action;
  final int quantity;
  final double price;
  final String? reason;
  final num? confidence;
  final ProposalQualification qualification;
  final double? rewardRiskRatio;
  final String? interval;
  final Map<String, dynamic>? gexData;
  final Map<String, dynamic>? macroAssessment;
  final Map<String, dynamic>? metrics;
  final Map<String, dynamic>? signal;
  final Map<String, dynamic>? proposal;
  final Map<String, dynamic>? assessment;
  final dynamic instrument;
  final String status;
  final Map<String, dynamic> rawMap;

  const AutomatedTradeProposal({
    required this.id,
    this.firestoreId,
    required this.timestamp,
    required this.symbol,
    required this.action,
    required this.quantity,
    required this.price,
    this.reason,
    this.confidence,
    this.qualification = ProposalQualification.unknown,
    this.rewardRiskRatio,
    this.interval,
    this.gexData,
    this.macroAssessment,
    this.metrics,
    this.signal,
    this.proposal,
    this.assessment,
    this.instrument,
    this.status = 'pending',
    this.rawMap = const {},
  });

  /// Total capital required for this order (price * quantity).
  double get estimatedCost => (price * quantity).toDouble();

  bool get isBuy => action == AutomatedTradeAction.buy;
  bool get isSell => action == AutomatedTradeAction.sell;

  bool get isConfirmed => qualification == ProposalQualification.confirmed;
  bool get isPendingQualification =>
      qualification == ProposalQualification.pending;
  bool get isBlocked => qualification == ProposalQualification.blocked;

  /// Formatted relative or short time string.
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }

  /// Extracts the gamma flip price from GEX data if present.
  double? get gammaFlipPrice {
    final flip = gexData?['gammaFlip'] ?? gexData?['flip'];
    if (flip is num) return flip.toDouble();
    return null;
  }

  /// Extracts the positive transition level (pTrans) from GEX data.
  double? get pTransPrice {
    final pTrans = gexData?['pTrans'];
    if (pTrans is num) return pTrans.toDouble();
    return null;
  }

  /// Extracts the negative transition level (nTrans) from GEX data.
  double? get nTransPrice {
    final nTrans = gexData?['nTrans'];
    if (nTrans is num) return nTrans.toDouble();
    return null;
  }

  /// Macro regime status string (e.g. "BULLISH", "BEARISH", "NEUTRAL").
  String? get macroStatus {
    return macroAssessment?['status']?.toString();
  }

  /// Macro regime reasoning statement.
  String? get macroReason {
    return macroAssessment?['reason']?.toString();
  }

  /// Deserializes a pending order map from Firestore or local provider state.
  factory AutomatedTradeProposal.fromMap(Map<String, dynamic> map) {
    DateTime parsedTime;
    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is String) {
      parsedTime = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else if (rawTimestamp is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    } else {
      parsedTime = DateTime.now();
    }

    final rawProposal = map['proposal'] is Map
        ? Map<String, dynamic>.from(map['proposal'] as Map)
        : null;
    final rawAssessment = map['assessment'] is Map
        ? Map<String, dynamic>.from(map['assessment'] as Map)
        : null;
    final rawGex = rawProposal?['gexData'] is Map
        ? Map<String, dynamic>.from(rawProposal!['gexData'] as Map)
        : null;
    final rawMacro = rawProposal?['macroAssessment'] is Map
        ? Map<String, dynamic>.from(rawProposal!['macroAssessment'] as Map)
        : null;
    final rawMetrics = rawAssessment?['metrics'] is Map
        ? Map<String, dynamic>.from(rawAssessment!['metrics'] as Map)
        : null;
    final rawSignal = map['signal'] is Map
        ? Map<String, dynamic>.from(map['signal'] as Map)
        : null;

    final qualStr = rawProposal?['qualification']?.toString() ??
        map['qualification']?.toString();
    final qualification = ProposalQualification.fromString(qualStr);

    final rr =
        (rawProposal?['rewardRiskRatio'] ?? map['rewardRiskRatio']) as num?;
    final interval = rawProposal?['interval']?.toString() ??
        map['interval']?.toString() ??
        rawSignal?['interval']?.toString();

    final symbol = (map['symbol'] as String?)?.toUpperCase() ?? 'UNKNOWN';
    final action = AutomatedTradeAction.fromString(map['action'] as String?);
    final quantity = (map['quantity'] as num?)?.toInt() ?? 0;
    final price = (map['price'] as num?)?.toDouble() ?? 0.0;
    final reason = (map['reason'] ?? rawProposal?['reason']) as String?;
    final confidence = (map['confidence'] ?? map['score']) as num?;

    return AutomatedTradeProposal(
      id: map['id']?.toString() ??
          map['firestoreId']?.toString() ??
          '${symbol}_${parsedTime.millisecondsSinceEpoch}',
      firestoreId: map['firestoreId']?.toString(),
      timestamp: parsedTime,
      symbol: symbol,
      action: action,
      quantity: quantity,
      price: price,
      reason: reason,
      confidence: confidence,
      qualification: qualification,
      rewardRiskRatio: rr?.toDouble(),
      interval: interval,
      gexData: rawGex,
      macroAssessment: rawMacro,
      metrics: rawMetrics,
      signal: rawSignal,
      proposal: rawProposal,
      assessment: rawAssessment,
      instrument: map['instrument'],
      status: map['status']?.toString() ?? 'pending',
      rawMap: map,
    );
  }

  /// Converts the model back into a Map compatible with Firestore pending_orders.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (firestoreId != null) 'firestoreId': firestoreId,
      'timestamp': timestamp.toIso8601String(),
      'symbol': symbol,
      'action': action.name.toUpperCase(),
      'quantity': quantity,
      'price': price,
      if (reason != null) 'reason': reason,
      if (confidence != null) 'confidence': confidence,
      if (rewardRiskRatio != null) 'rewardRiskRatio': rewardRiskRatio,
      if (interval != null) 'interval': interval,
      if (gexData != null) 'gexData': gexData,
      if (macroAssessment != null) 'macroAssessment': macroAssessment,
      if (metrics != null) 'metrics': metrics,
      if (signal != null) 'signal': signal,
      if (proposal != null) 'proposal': proposal,
      if (assessment != null) 'assessment': assessment,
      if (instrument != null) 'instrument': instrument,
      'status': status,
    };
  }

  AutomatedTradeProposal copyWith({
    String? id,
    String? firestoreId,
    DateTime? timestamp,
    String? symbol,
    AutomatedTradeAction? action,
    int? quantity,
    double? price,
    String? reason,
    num? confidence,
    ProposalQualification? qualification,
    double? rewardRiskRatio,
    String? interval,
    Map<String, dynamic>? gexData,
    Map<String, dynamic>? macroAssessment,
    Map<String, dynamic>? metrics,
    Map<String, dynamic>? signal,
    Map<String, dynamic>? proposal,
    Map<String, dynamic>? assessment,
    dynamic instrument,
    String? status,
    Map<String, dynamic>? rawMap,
  }) {
    return AutomatedTradeProposal(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      timestamp: timestamp ?? this.timestamp,
      symbol: symbol ?? this.symbol,
      action: action ?? this.action,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      reason: reason ?? this.reason,
      confidence: confidence ?? this.confidence,
      qualification: qualification ?? this.qualification,
      rewardRiskRatio: rewardRiskRatio ?? this.rewardRiskRatio,
      interval: interval ?? this.interval,
      gexData: gexData ?? this.gexData,
      macroAssessment: macroAssessment ?? this.macroAssessment,
      metrics: metrics ?? this.metrics,
      signal: signal ?? this.signal,
      proposal: proposal ?? this.proposal,
      assessment: assessment ?? this.assessment,
      instrument: instrument ?? this.instrument,
      status: status ?? this.status,
      rawMap: rawMap ?? this.rawMap,
    );
  }
}
