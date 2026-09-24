import 'package:flutter/foundation.dart';

/// Represents the response payload from Schwab Trader API:
/// `POST /trader/v1/accounts/{accountNumber}/previewOrder`
@immutable
class SchwabOrderPreview {
  final String? orderId;
  final SchwabOrderStrategy? orderStrategy;
  final SchwabOrderValidationResult? orderValidationResult;
  final SchwabCommissionAndFee? commissionAndFee;
  final SchwabOrderBalance? rootOrderBalance;

  const SchwabOrderPreview({
    this.orderId,
    this.orderStrategy,
    this.orderValidationResult,
    this.commissionAndFee,
    this.rootOrderBalance,
  });

  factory SchwabOrderPreview.fromJson(Map<String, dynamic> json) {
    return SchwabOrderPreview(
      orderId: json['orderId']?.toString(),
      orderStrategy: json['orderStrategy'] != null
          ? SchwabOrderStrategy.fromJson(
              json['orderStrategy'] as Map<String, dynamic>)
          : null,
      orderValidationResult: json['orderValidationResult'] != null
          ? SchwabOrderValidationResult.fromJson(
              json['orderValidationResult'] as Map<String, dynamic>)
          : null,
      commissionAndFee: json['commissionAndFee'] != null
          ? SchwabCommissionAndFee.fromJson(
              json['commissionAndFee'] as Map<String, dynamic>)
          : null,
      rootOrderBalance: json['orderBalance'] != null
          ? SchwabOrderBalance.fromJson(
              json['orderBalance'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (orderId != null) 'orderId': orderId,
      if (orderStrategy != null) 'orderStrategy': orderStrategy!.toJson(),
      if (orderValidationResult != null)
        'orderValidationResult': orderValidationResult!.toJson(),
      if (commissionAndFee != null)
        'commissionAndFee': commissionAndFee!.toJson(),
      if (rootOrderBalance != null)
        'orderBalance': rootOrderBalance!.toJson(),
    };
  }

  /// Whether the order preview passed validation without hard rejections.
  bool get isValid =>
      orderValidationResult == null ||
      (orderValidationResult!.rejects.isEmpty &&
          orderValidationResult!.reviews.isEmpty);

  /// Whether the preview received blocking rejection messages.
  bool get hasRejections =>
      orderValidationResult != null &&
      orderValidationResult!.rejects.isNotEmpty;

  /// Whether the preview received non-blocking warnings or alerts.
  bool get hasWarnings =>
      orderValidationResult != null &&
      (orderValidationResult!.warns.isNotEmpty ||
          orderValidationResult!.alerts.isNotEmpty);

  /// Detailed human-readable rejection messages.
  List<String> get rejectMessages =>
      orderValidationResult?.rejects.map((e) => e.displayMessage).toList() ??
      [];

  /// Detailed human-readable warning messages.
  List<String> get warningMessages =>
      orderValidationResult?.warns.map((e) => e.displayMessage).toList() ??
      [];

  /// Detailed human-readable alert messages.
  List<String> get alertMessages =>
      orderValidationResult?.alerts.map((e) => e.displayMessage).toList() ??
      [];

  /// Estimated broker commission.
  double get estimatedCommission =>
      commissionAndFee?.totalCommission ??
      orderStrategy?.orderBalance?.projectedCommission ??
      0.0;

  /// Estimated transaction & regulatory fees (SEC, TAF, Opt Reg).
  double get estimatedFees => commissionAndFee?.totalFee ?? 0.0;

  /// Combined commission and fee cost.
  double get totalEstimatedFeesAndCommissions =>
      estimatedCommission + estimatedFees;

  /// Total order value or estimated cash required.
  double? get orderValue =>
      orderStrategy?.orderValue ?? orderBalance?.orderValue;

  /// Post-trade projected buying power.
  double? get projectedBuyingPower =>
      orderBalance?.projectedBuyingPower;

  /// Post-trade projected available funds.
  double? get projectedAvailableFunds =>
      orderBalance?.projectedAvailableFund;

  /// Estimated margin requirement impact.
  double? get marginRequirement =>
      orderBalance?.orderValue;

  /// Underlying order balance summary (from root or orderStrategy).
  SchwabOrderBalance? get orderBalance =>
      rootOrderBalance ?? orderStrategy?.orderBalance;

  /// Buying power effect from the previewed order balance.
  double? get buyingPowerEffect =>
      orderBalance?.buyingPowerEffect;

  /// Combined commission and fees if present.
  double? get totalCommissionAndFee =>
      commissionAndFee != null ? totalEstimatedFeesAndCommissions : null;

  /// Order legs list convenience accessor.
  List<SchwabOrderLeg> get legs => orderStrategy?.orderLegs ?? [];
}

@immutable
class SchwabOrderStrategy {
  final String? accountNumber;
  final String? orderStrategyType;
  final String? orderType;
  final String? duration;
  final String? session;
  final String? status;
  final double? price;
  final double? quantity;
  final double? filledQuantity;
  final double? remainingQuantity;
  final double? orderValue;
  final SchwabOrderBalance? orderBalance;
  final List<SchwabOrderLeg> orderLegs;
  final DateTime? enteredTime;
  final DateTime? closeTime;

  const SchwabOrderStrategy({
    this.accountNumber,
    this.orderStrategyType,
    this.orderType,
    this.duration,
    this.session,
    this.status,
    this.price,
    this.quantity,
    this.filledQuantity,
    this.remainingQuantity,
    this.orderValue,
    this.orderBalance,
    this.orderLegs = const [],
    this.enteredTime,
    this.closeTime,
  });

  factory SchwabOrderStrategy.fromJson(Map<String, dynamic> json) {
    return SchwabOrderStrategy(
      accountNumber: json['accountNumber']?.toString(),
      orderStrategyType: json['orderStrategyType']?.toString(),
      orderType: json['orderType']?.toString(),
      duration: json['duration']?.toString(),
      session: json['session']?.toString(),
      status: json['status']?.toString(),
      price: (json['price'] as num?)?.toDouble(),
      quantity: (json['quantity'] as num?)?.toDouble(),
      filledQuantity: (json['filledQuantity'] as num?)?.toDouble(),
      remainingQuantity: (json['remainingQuantity'] as num?)?.toDouble(),
      orderValue: (json['orderValue'] as num?)?.toDouble(),
      orderBalance: json['orderBalance'] != null
          ? SchwabOrderBalance.fromJson(
              json['orderBalance'] as Map<String, dynamic>)
          : null,
      orderLegs: ((json['orderLegCollection'] ?? json['orderLegs'])
                  as List<dynamic>?)
              ?.map((e) => SchwabOrderLeg.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      enteredTime: json['enteredTime'] != null
          ? DateTime.tryParse(json['enteredTime'].toString())
          : null,
      closeTime: json['closeTime'] != null
          ? DateTime.tryParse(json['closeTime'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (accountNumber != null) 'accountNumber': accountNumber,
      if (orderStrategyType != null) 'orderStrategyType': orderStrategyType,
      if (orderType != null) 'orderType': orderType,
      if (duration != null) 'duration': duration,
      if (session != null) 'session': session,
      if (status != null) 'status': status,
      if (price != null) 'price': price,
      if (quantity != null) 'quantity': quantity,
      if (filledQuantity != null) 'filledQuantity': filledQuantity,
      if (remainingQuantity != null) 'remainingQuantity': remainingQuantity,
      if (orderValue != null) 'orderValue': orderValue,
      if (orderBalance != null) 'orderBalance': orderBalance!.toJson(),
      'orderLegs': orderLegs.map((e) => e.toJson()).toList(),
      if (enteredTime != null) 'enteredTime': enteredTime!.toIso8601String(),
      if (closeTime != null) 'closeTime': closeTime!.toIso8601String(),
    };
  }

  /// Convenience alias for orderLegs.
  List<SchwabOrderLeg> get legs => orderLegs;
}

@immutable
class SchwabOrderBalance {
  final double? orderValue;
  final double? projectedAvailableFund;
  final double? projectedBuyingPower;
  final double? projectedCommission;
  final double? buyingPowerEffect;
  final double? projectedAvailableFundEffect;
  final double? projectedCashBalance;
  final double? projectedMarginBalance;

  const SchwabOrderBalance({
    this.orderValue,
    this.projectedAvailableFund,
    this.projectedBuyingPower,
    this.projectedCommission,
    this.buyingPowerEffect,
    this.projectedAvailableFundEffect,
    this.projectedCashBalance,
    this.projectedMarginBalance,
  });

  factory SchwabOrderBalance.fromJson(Map<String, dynamic> json) {
    return SchwabOrderBalance(
      orderValue: (json['orderValue'] as num?)?.toDouble(),
      projectedAvailableFund:
          (json['projectedAvailableFund'] as num?)?.toDouble(),
      projectedBuyingPower:
          (json['projectedBuyingPower'] as num?)?.toDouble(),
      projectedCommission:
          (json['projectedCommission'] as num?)?.toDouble(),
      buyingPowerEffect: (json['buyingPowerEffect'] as num?)?.toDouble() ??
          (json['projectedBuyingPowerEffect'] as num?)?.toDouble(),
      projectedAvailableFundEffect:
          (json['projectedAvailableFundEffect'] as num?)?.toDouble(),
      projectedCashBalance:
          (json['projectedCashBalance'] as num?)?.toDouble(),
      projectedMarginBalance:
          (json['projectedMarginBalance'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (orderValue != null) 'orderValue': orderValue,
      if (projectedAvailableFund != null)
        'projectedAvailableFund': projectedAvailableFund,
      if (projectedBuyingPower != null)
        'projectedBuyingPower': projectedBuyingPower,
      if (projectedCommission != null)
        'projectedCommission': projectedCommission,
      if (buyingPowerEffect != null) 'buyingPowerEffect': buyingPowerEffect,
      if (projectedAvailableFundEffect != null)
        'projectedAvailableFundEffect': projectedAvailableFundEffect,
      if (projectedCashBalance != null)
        'projectedCashBalance': projectedCashBalance,
      if (projectedMarginBalance != null)
        'projectedMarginBalance': projectedMarginBalance,
    };
  }
}

@immutable
class SchwabOrderLeg {
  final int? legId;
  final String? assetType;
  final String? instruction;
  final String? finalSymbol;
  final double? quantity;
  final double? price;
  final double? askPrice;
  final double? bidPrice;
  final double? lastPrice;
  final double? markPrice;
  final double? projectedCommission;

  const SchwabOrderLeg({
    this.legId,
    this.assetType,
    this.instruction,
    this.finalSymbol,
    this.quantity,
    this.price,
    this.askPrice,
    this.bidPrice,
    this.lastPrice,
    this.markPrice,
    this.projectedCommission,
  });

  factory SchwabOrderLeg.fromJson(Map<String, dynamic> json) {
    return SchwabOrderLeg(
      legId: (json['legId'] as num?)?.toInt(),
      assetType: json['assetType']?.toString() ??
          (json['instrument'] is Map
              ? json['instrument']['assetType']?.toString()
              : null),
      instruction: json['instruction']?.toString(),
      finalSymbol: json['finalSymbol']?.toString() ??
          (json['instrument'] is Map
              ? json['instrument']['symbol']?.toString()
              : null),
      quantity: (json['quantity'] as num?)?.toDouble(),
      price: (json['price'] as num?)?.toDouble(),
      askPrice: (json['askPrice'] as num?)?.toDouble(),
      bidPrice: (json['bidPrice'] as num?)?.toDouble(),
      lastPrice: (json['lastPrice'] as num?)?.toDouble(),
      markPrice: (json['markPrice'] as num?)?.toDouble(),
      projectedCommission:
          (json['projectedCommission'] as num?)?.toDouble(),
    );
  }

  /// Convenience accessor for symbol.
  String? get symbol => finalSymbol;

  Map<String, dynamic> toJson() {
    return {
      if (legId != null) 'legId': legId,
      if (assetType != null) 'assetType': assetType,
      if (instruction != null) 'instruction': instruction,
      if (finalSymbol != null) 'finalSymbol': finalSymbol,
      if (quantity != null) 'quantity': quantity,
      if (price != null) 'price': price,
      if (askPrice != null) 'askPrice': askPrice,
      if (bidPrice != null) 'bidPrice': bidPrice,
      if (lastPrice != null) 'lastPrice': lastPrice,
      if (markPrice != null) 'markPrice': markPrice,
      if (projectedCommission != null)
        'projectedCommission': projectedCommission,
    };
  }
}

@immutable
class SchwabOrderValidationResult {
  final List<SchwabOrderValidationDetail> alerts;
  final List<SchwabOrderValidationDetail> accepts;
  final List<SchwabOrderValidationDetail> rejects;
  final List<SchwabOrderValidationDetail> reviews;
  final List<SchwabOrderValidationDetail> warns;

  const SchwabOrderValidationResult({
    this.alerts = const [],
    this.accepts = const [],
    this.rejects = const [],
    this.reviews = const [],
    this.warns = const [],
  });

  factory SchwabOrderValidationResult.fromJson(Map<String, dynamic> json) {
    List<SchwabOrderValidationDetail> parseDetails(String key) {
      final list = json[key] as List<dynamic>?;
      if (list == null) return const [];
      return list
          .map((e) =>
              SchwabOrderValidationDetail.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return SchwabOrderValidationResult(
      alerts: parseDetails('alerts'),
      accepts: parseDetails('accepts'),
      rejects: parseDetails('rejects'),
      reviews: parseDetails('reviews'),
      warns: parseDetails('warns'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alerts': alerts.map((e) => e.toJson()).toList(),
      'accepts': accepts.map((e) => e.toJson()).toList(),
      'rejects': rejects.map((e) => e.toJson()).toList(),
      'reviews': reviews.map((e) => e.toJson()).toList(),
      'warns': warns.map((e) => e.toJson()).toList(),
    };
  }
}

@immutable
class SchwabOrderValidationDetail {
  final String? validationRuleName;
  final String? message;
  final String? activityMessage;
  final String? originalSeverity;
  final String? overrideName;
  final String? overrideSeverity;

  const SchwabOrderValidationDetail({
    this.validationRuleName,
    this.message,
    this.activityMessage,
    this.originalSeverity,
    this.overrideName,
    this.overrideSeverity,
  });

  factory SchwabOrderValidationDetail.fromJson(Map<String, dynamic> json) {
    return SchwabOrderValidationDetail(
      validationRuleName: json['validationRuleName']?.toString(),
      message: json['message']?.toString(),
      activityMessage: json['activityMessage']?.toString(),
      originalSeverity: json['originalSeverity']?.toString(),
      overrideName: json['overrideName']?.toString(),
      overrideSeverity: json['overrideSeverity']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (validationRuleName != null) 'validationRuleName': validationRuleName,
      if (message != null) 'message': message,
      if (activityMessage != null) 'activityMessage': activityMessage,
      if (originalSeverity != null) 'originalSeverity': originalSeverity,
      if (overrideName != null) 'overrideName': overrideName,
      if (overrideSeverity != null) 'overrideSeverity': overrideSeverity,
    };
  }

  String get displayMessage =>
      message ?? activityMessage ?? validationRuleName ?? 'Validation notice';
}

@immutable
class SchwabCommissionAndFee {
  final SchwabCommission? commission;
  final SchwabFee? fee;
  final SchwabCommission? trueCommission;

  const SchwabCommissionAndFee({
    this.commission,
    this.fee,
    this.trueCommission,
  });

  factory SchwabCommissionAndFee.fromJson(Map<String, dynamic> json) {
    return SchwabCommissionAndFee(
      commission: json['commission'] is Map<String, dynamic>
          ? SchwabCommission.fromJson(
              json['commission'] as Map<String, dynamic>)
          : (json['commission'] is num
              ? SchwabCommission(commissionLegs: [
                  SchwabCommissionLeg(commissionValues: [
                    SchwabCommissionValue(
                        value: (json['commission'] as num).toDouble(),
                        type: 'COMMISSION')
                  ])
                ])
              : null),
      fee: json['fee'] is Map<String, dynamic>
          ? SchwabFee.fromJson(json['fee'] as Map<String, dynamic>)
          : (json['fee'] is num
              ? SchwabFee(feeLegs: [
                  SchwabFeeLeg(feeValues: [
                    SchwabFeeValue(
                        value: (json['fee'] as num).toDouble(), type: 'FEE')
                  ])
                ])
              : null),
      trueCommission: json['trueCommission'] is Map<String, dynamic>
          ? SchwabCommission.fromJson(
              json['trueCommission'] as Map<String, dynamic>)
          : (json['trueCommission'] is num
              ? SchwabCommission(commissionLegs: [
                  SchwabCommissionLeg(commissionValues: [
                    SchwabCommissionValue(
                        value: (json['trueCommission'] as num).toDouble(),
                        type: 'COMMISSION')
                  ])
                ])
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (commission != null) 'commission': commission!.toJson(),
      if (fee != null) 'fee': fee!.toJson(),
      if (trueCommission != null) 'trueCommission': trueCommission!.toJson(),
    };
  }

  double get totalCommission => commission?.totalAmount ?? 0.0;
  double get totalFee => fee?.totalAmount ?? 0.0;
  double? get commissionAmount => commission?.totalAmount;
  double? get feeAmount => fee?.totalAmount;
}

@immutable
class SchwabCommission {
  final List<SchwabCommissionLeg> commissionLegs;

  const SchwabCommission({this.commissionLegs = const []});

  factory SchwabCommission.fromJson(Map<String, dynamic> json) {
    final legs = json['commissionLegs'] as List<dynamic>?;
    final flatAmount = (json['commissionAmount'] as num?)?.toDouble() ??
        (json['totalAmount'] as num?)?.toDouble();
    return SchwabCommission(
      commissionLegs: legs != null
          ? legs
              .map((e) =>
                  SchwabCommissionLeg.fromJson(e as Map<String, dynamic>))
              .toList()
          : (flatAmount != null
              ? [
                  SchwabCommissionLeg(commissionValues: [
                    SchwabCommissionValue(value: flatAmount, type: 'COMMISSION')
                  ])
                ]
              : const []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'commissionLegs': commissionLegs.map((e) => e.toJson()).toList(),
    };
  }

  double get totalAmount =>
      commissionLegs.fold(0.0, (acc, leg) => acc + leg.totalAmount);
  double? get commissionAmount => totalAmount;
}

@immutable
class SchwabCommissionLeg {
  final List<SchwabCommissionValue> commissionValues;

  const SchwabCommissionLeg({this.commissionValues = const []});

  factory SchwabCommissionLeg.fromJson(Map<String, dynamic> json) {
    final values = json['commissionValues'] as List<dynamic>?;
    return SchwabCommissionLeg(
      commissionValues: values != null
          ? values
              .map((e) =>
                  SchwabCommissionValue.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'commissionValues': commissionValues.map((e) => e.toJson()).toList(),
    };
  }

  double get totalAmount =>
      commissionValues.fold(0.0, (acc, v) => acc + (v.value ?? 0.0));
}

@immutable
class SchwabCommissionValue {
  final double? value;
  final String? type;

  const SchwabCommissionValue({this.value, this.type});

  factory SchwabCommissionValue.fromJson(Map<String, dynamic> json) {
    return SchwabCommissionValue(
      value: (json['value'] as num?)?.toDouble(),
      type: json['type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (value != null) 'value': value,
      if (type != null) 'type': type,
    };
  }
}

@immutable
class SchwabFee {
  final List<SchwabFeeLeg> feeLegs;

  const SchwabFee({this.feeLegs = const []});

  factory SchwabFee.fromJson(Map<String, dynamic> json) {
    final legs = json['feeLegs'] as List<dynamic>?;
    final flatFee = (json['feeAmount'] as num?)?.toDouble() ??
        (json['totalAmount'] as num?)?.toDouble();
    return SchwabFee(
      feeLegs: legs != null
          ? legs
              .map((e) => SchwabFeeLeg.fromJson(e as Map<String, dynamic>))
              .toList()
          : (flatFee != null
              ? [
                  SchwabFeeLeg(feeValues: [
                    SchwabFeeValue(value: flatFee, type: 'FEE')
                  ])
                ]
              : const []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'feeLegs': feeLegs.map((e) => e.toJson()).toList(),
    };
  }

  double get totalAmount =>
      feeLegs.fold(0.0, (acc, leg) => acc + leg.totalAmount);
  double? get feeAmount => totalAmount;
}

@immutable
class SchwabFeeLeg {
  final List<SchwabFeeValue> feeValues;

  const SchwabFeeLeg({this.feeValues = const []});

  factory SchwabFeeLeg.fromJson(Map<String, dynamic> json) {
    final values = json['feeValues'] as List<dynamic>?;
    return SchwabFeeLeg(
      feeValues: values != null
          ? values
              .map((e) => SchwabFeeValue.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'feeValues': feeValues.map((e) => e.toJson()).toList(),
    };
  }

  double get totalAmount =>
      feeValues.fold(0.0, (acc, v) => acc + (v.value ?? 0.0));
}

@immutable
class SchwabFeeValue {
  final double? value;
  final String? type;

  const SchwabFeeValue({this.value, this.type});

  factory SchwabFeeValue.fromJson(Map<String, dynamic> json) {
    return SchwabFeeValue(
      value: (json['value'] as num?)?.toDouble(),
      type: json['type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (value != null) 'value': value,
      if (type != null) 'type': type,
    };
  }
}
