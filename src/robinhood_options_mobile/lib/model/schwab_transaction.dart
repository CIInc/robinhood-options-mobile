import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';

/// Represents a transaction from Charles Schwab Trader API:
/// `GET /trader/v1/accounts/{accountNumber}/transactions`
@immutable
class SchwabTransaction {
  final int activityId;
  final DateTime time;
  final String accountNumber;
  final String type;
  final String status;
  final String subAccount;
  final DateTime? tradeDate;
  final DateTime? settlementDate;
  final int? positionId;
  final int? orderId;
  final double netAmount;
  final String? description;
  final List<SchwabTransferItem> transferItems;

  const SchwabTransaction({
    required this.activityId,
    required this.time,
    required this.accountNumber,
    required this.type,
    required this.status,
    required this.subAccount,
    this.tradeDate,
    this.settlementDate,
    this.positionId,
    this.orderId,
    required this.netAmount,
    this.description,
    this.transferItems = const [],
  });

  factory SchwabTransaction.fromJson(Map<String, dynamic> json) {
    var rawActivityId = json['activityId'];
    int parsedActivityId = 0;
    if (rawActivityId is int) {
      parsedActivityId = rawActivityId;
    } else if (rawActivityId is String) {
      parsedActivityId = int.tryParse(rawActivityId) ?? 0;
    }

    var items = <SchwabTransferItem>[];
    if (json['transferItems'] is List) {
      for (var item in json['transferItems']) {
        if (item is Map<String, dynamic>) {
          items.add(SchwabTransferItem.fromJson(item));
        }
      }
    }

    return SchwabTransaction(
      activityId: parsedActivityId,
      time: json['time'] != null
          ? DateTime.tryParse(json['time'].toString()) ?? DateTime.now()
          : DateTime.now(),
      accountNumber: (json['accountNumber'] ?? '').toString(),
      type: (json['type'] ?? 'UNKNOWN').toString().toUpperCase(),
      status: (json['status'] ?? 'VALID').toString().toUpperCase(),
      subAccount: (json['subAccount'] ?? 'MARGIN').toString(),
      tradeDate: json['tradeDate'] != null
          ? DateTime.tryParse(json['tradeDate'].toString())
          : null,
      settlementDate: json['settlementDate'] != null
          ? DateTime.tryParse(json['settlementDate'].toString())
          : null,
      positionId: json['positionId'] is int
          ? json['positionId'] as int
          : int.tryParse(json['positionId']?.toString() ?? ''),
      orderId: json['orderId'] is int
          ? json['orderId'] as int
          : int.tryParse(json['orderId']?.toString() ?? ''),
      netAmount: (json['netAmount'] is num)
          ? (json['netAmount'] as num).toDouble()
          : double.tryParse(json['netAmount']?.toString() ?? '0') ?? 0.0,
      description: json['description']?.toString(),
      transferItems: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activityId': activityId,
      'time': time.toIso8601String(),
      'accountNumber': accountNumber,
      'type': type,
      'status': status,
      'subAccount': subAccount,
      if (tradeDate != null) 'tradeDate': tradeDate!.toIso8601String(),
      if (settlementDate != null)
        'settlementDate': settlementDate!.toIso8601String(),
      if (positionId != null) 'positionId': positionId,
      if (orderId != null) 'orderId': orderId,
      'netAmount': netAmount,
      if (description != null) 'description': description,
      'transferItems': transferItems.map((e) => e.toJson()).toList(),
    };
  }

  String get id => activityId.toString();

  bool get isTrade => type == 'TRADE';

  bool get isDividendOrInterest =>
      type == 'DIVIDEND_OR_INTEREST' ||
      (description != null &&
          (description!.toUpperCase().contains('DIVIDEND') ||
              description!.toUpperCase().contains('INTEREST')));

  bool get isDividend =>
      type == 'DIVIDEND_OR_INTEREST' &&
      (description == null ||
          !description!.toUpperCase().contains('INTEREST') ||
          description!.toUpperCase().contains('DIVIDEND'));

  bool get isInterest =>
      (type == 'DIVIDEND_OR_INTEREST' &&
          description != null &&
          description!.toUpperCase().contains('INTEREST')) ||
      type == 'MONEY_MARKET';

  bool get isCashMovement =>
      type.contains('ACH') ||
      type.contains('WIRE') ||
      type == 'ELECTRONIC_FUND' ||
      type == 'RECEIVE_AND_DELIVER' ||
      type == 'JOURNAL';

  bool get isFee => transferItems.any((t) => t.feeType != null);

  /// Primary traded/affected instrument (non-currency).
  SchwabTransferInstrument? get primaryInstrument {
    final nonCurrency = transferItems.firstWhereOrNull(
      (t) => t.instrument.assetType != 'CURRENCY',
    );
    if (nonCurrency != null) {
      return nonCurrency.instrument;
    }
    return transferItems.isNotEmpty ? transferItems.first.instrument : null;
  }

  /// Primary ticker or asset symbol.
  String? get primarySymbol => primaryInstrument?.symbol;

  /// Underlying symbol for options or primary symbol.
  String? get underlyingSymbol =>
      primaryInstrument?.underlyingSymbol ?? primarySymbol;

  /// Quantity associated with the primary non-currency transfer item.
  double get primaryQuantity {
    final nonCurrency = transferItems.firstWhereOrNull(
      (t) => t.instrument.assetType != 'CURRENCY',
    );
    return nonCurrency?.amount ?? 0.0;
  }

  /// Execution price of primary non-currency transfer item.
  double? get primaryPrice {
    final nonCurrency = transferItems.firstWhereOrNull(
      (t) => t.instrument.assetType != 'CURRENCY',
    );
    return nonCurrency?.price;
  }

  /// Position effect (OPENING vs CLOSING).
  String? get positionEffect {
    final nonCurrency = transferItems.firstWhereOrNull(
      (t) => t.positionEffect != null,
    );
    return nonCurrency?.positionEffect;
  }

  /// Brokerage commission charged.
  double get commission {
    return transferItems
        .where((t) => t.feeType == 'COMMISSION')
        .fold<double>(0.0, (sum, t) => sum + t.cost.abs());
  }

  /// Regulatory fees (SEC, OPT_REG, TAF, etc.) charged.
  double get regulatoryFees {
    return transferItems
        .where((t) => t.feeType != null && t.feeType != 'COMMISSION')
        .fold<double>(0.0, (sum, t) => sum + t.cost.abs());
  }

  /// Total transaction expenses (commissions + regulatory fees).
  double get totalFees => commission + regulatoryFees;

  /// Estimated realized P&L for closing trades or return amounts.
  double? get estimatedRealizedPnL {
    if (positionEffect == 'CLOSING') {
      final nonCurrency = transferItems.firstWhereOrNull(
        (t) => t.instrument.assetType != 'CURRENCY',
      );
      if (nonCurrency != null && nonCurrency.cost != 0) {
        // When closing a long position, cost is positive proceeds minus closing cost
        return netAmount - totalFees;
      }
    }
    return null;
  }

  /// Converts this transaction into a map compatible with [DividendStore]
  /// and the existing [IncomeTransactionsWidget].
  Map<String, dynamic> toDividendMap({Instrument? instrumentObj}) {
    final nonCurrency = transferItems.firstWhereOrNull(
      (t) => t.instrument.assetType != 'CURRENCY',
    );
    final sym = nonCurrency?.instrument.symbol ?? primarySymbol ?? 'UNKNOWN';
    final qty = nonCurrency?.amount.abs() ?? 0.0;
    final rate = (qty > 0 && netAmount > 0)
        ? (netAmount / qty)
        : (nonCurrency?.price ?? 0.0);

    return {
      'id': activityId.toString(),
      'payable_date': (settlementDate ?? time).toIso8601String(),
      'record_date': (tradeDate ?? time).toIso8601String(),
      'amount': netAmount.abs().toStringAsFixed(2),
      'rate': rate.toStringAsFixed(4),
      'position': qty > 0 ? qty.toStringAsFixed(2) : '1',
      'state': status.toLowerCase() == 'valid' ? 'paid' : status.toLowerCase(),
      'instrument': sym,
      'symbol': sym,
      'description': description ?? 'Dividend on $sym',
      'accountNumber': accountNumber,
      if (instrumentObj != null) 'instrumentObj': instrumentObj,
    };
  }

  /// Converts this transaction into a map compatible with [InterestStore].
  Map<String, dynamic> toInterestMap() {
    return {
      'id': activityId.toString(),
      'pay_date': (settlementDate ?? time).toIso8601String(),
      'amount': {
        'amount': netAmount.abs().toStringAsFixed(2),
        'currency_code': 'USD',
      },
      'state': status.toLowerCase() == 'valid' ? 'paid' : status.toLowerCase(),
      'reason': description ?? 'Interest Payment',
      'accountNumber': accountNumber,
    };
  }
}

/// Details of a specific item or fee transferred in a Schwab transaction.
@immutable
class SchwabTransferItem {
  final SchwabTransferInstrument instrument;
  final double amount;
  final double cost;
  final double? price;
  final String? feeType;
  final String? positionEffect;

  const SchwabTransferItem({
    required this.instrument,
    required this.amount,
    required this.cost,
    this.price,
    this.feeType,
    this.positionEffect,
  });

  factory SchwabTransferItem.fromJson(Map<String, dynamic> json) {
    return SchwabTransferItem(
      instrument: SchwabTransferInstrument.fromJson(
        (json['instrument'] as Map<String, dynamic>?) ?? {},
      ),
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      cost: (json['cost'] is num)
          ? (json['cost'] as num).toDouble()
          : double.tryParse(json['cost']?.toString() ?? '0') ?? 0.0,
      price: json['price'] != null
          ? (json['price'] is num
              ? (json['price'] as num).toDouble()
              : double.tryParse(json['price'].toString()))
          : null,
      feeType: json['feeType']?.toString(),
      positionEffect: json['positionEffect']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'instrument': instrument.toJson(),
      'amount': amount,
      'cost': cost,
      if (price != null) 'price': price,
      if (feeType != null) 'feeType': feeType,
      if (positionEffect != null) 'positionEffect': positionEffect,
    };
  }
}

/// Instrument associated with a transfer item.
@immutable
class SchwabTransferInstrument {
  final String assetType;
  final String status;
  final String symbol;
  final String? description;
  final int? instrumentId;
  final double? closingPrice;
  final DateTime? expirationDate;
  final String? putCall;
  final double? strikePrice;
  final String? type;
  final String? underlyingSymbol;
  final String? underlyingCusip;

  const SchwabTransferInstrument({
    required this.assetType,
    required this.status,
    required this.symbol,
    this.description,
    this.instrumentId,
    this.closingPrice,
    this.expirationDate,
    this.putCall,
    this.strikePrice,
    this.type,
    this.underlyingSymbol,
    this.underlyingCusip,
  });

  factory SchwabTransferInstrument.fromJson(Map<String, dynamic> json) {
    return SchwabTransferInstrument(
      assetType: (json['assetType'] ?? 'CURRENCY').toString(),
      status: (json['status'] ?? 'ACTIVE').toString(),
      symbol: (json['symbol'] ?? '').toString(),
      description: json['description']?.toString(),
      instrumentId: json['instrumentId'] is int
          ? json['instrumentId'] as int
          : int.tryParse(json['instrumentId']?.toString() ?? ''),
      closingPrice: json['closingPrice'] != null
          ? (json['closingPrice'] is num
              ? (json['closingPrice'] as num).toDouble()
              : double.tryParse(json['closingPrice'].toString()))
          : null,
      expirationDate: json['expirationDate'] != null
          ? DateTime.tryParse(json['expirationDate'].toString())
          : null,
      putCall: json['putCall']?.toString(),
      strikePrice: json['strikePrice'] != null
          ? (json['strikePrice'] is num
              ? (json['strikePrice'] as num).toDouble()
              : double.tryParse(json['strikePrice'].toString()))
          : null,
      type: json['type']?.toString(),
      underlyingSymbol: json['underlyingSymbol']?.toString(),
      underlyingCusip: json['underlyingCusip']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assetType': assetType,
      'status': status,
      'symbol': symbol,
      if (description != null) 'description': description,
      if (instrumentId != null) 'instrumentId': instrumentId,
      if (closingPrice != null) 'closingPrice': closingPrice,
      if (expirationDate != null)
        'expirationDate': expirationDate!.toIso8601String(),
      if (putCall != null) 'putCall': putCall,
      if (strikePrice != null) 'strikePrice': strikePrice,
      if (type != null) 'type': type,
      if (underlyingSymbol != null) 'underlyingSymbol': underlyingSymbol,
      if (underlyingCusip != null) 'underlyingCusip': underlyingCusip,
    };
  }
}
