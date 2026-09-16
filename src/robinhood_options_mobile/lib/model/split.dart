import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

final _currencyFormat = NumberFormat.simpleCurrency();
final _shortDateFormat = DateFormat.yMMMd();

/// Represents a general corporate stock split declaration.
@immutable
class Split {
  final String? id;
  final String? instrument;
  final String? url;
  final DateTime? executionDate;
  final double multiplier;
  final double divisor;

  const Split({
    this.id,
    this.instrument,
    this.url,
    this.executionDate,
    this.multiplier = 1.0,
    this.divisor = 1.0,
  });

  factory Split.fromJson(dynamic json) {
    if (json is! Map) {
      return const Split();
    }

    DateTime? date;
    if (json['execution_date'] != null) {
      date = DateTime.tryParse(json['execution_date'].toString());
    } else if (json['date'] != null) {
      date = DateTime.tryParse(json['date'].toString());
    }

    final mult = parseDouble(json['multiplier']) ?? 1.0;
    final div = parseDouble(json['divisor']) ?? 1.0;

    return Split(
      id: json['id']?.toString(),
      instrument: json['instrument']?.toString(),
      url: json['url']?.toString(),
      executionDate: date,
      multiplier: mult,
      divisor: div,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (instrument != null) 'instrument': instrument,
        if (url != null) 'url': url,
        if (executionDate != null)
          'execution_date': executionDate!.toIso8601String(),
        'multiplier': multiplier,
        'divisor': divisor,
      };

  double get effectiveMultiplier =>
      (divisor > 0 ? multiplier / divisor : multiplier);

  bool get isForwardSplit => effectiveMultiplier > 1.00001;
  bool get isReverseSplit =>
      effectiveMultiplier < 0.99999 && effectiveMultiplier > 0;

  String get formattedRatio {
    final mult = effectiveMultiplier;
    if (mult > 1.0) {
      if (mult % 1 == 0) {
        return '${mult.toInt()} for 1 Split';
      }
      return '${mult.toStringAsFixed(2)} for 1 Split';
    } else if (mult > 0.0 && mult < 1.0) {
      final reverse = 1.0 / mult;
      if ((reverse - reverse.round()).abs() < 0.001) {
        return '1 for ${reverse.round()} Reverse Split';
      }
      return '1 for ${reverse.toStringAsFixed(2)} Reverse Split';
    }
    return '1 for 1 Split';
  }

  String get shortRatioBadge {
    final mult = effectiveMultiplier;
    if (mult > 1.0) {
      if (mult % 1 == 0) {
        return '${mult.toInt()}:1 Split';
      }
      return '${mult.toStringAsFixed(1)}:1 Split';
    } else if (mult > 0.0 && mult < 1.0) {
      final reverse = 1.0 / mult;
      if ((reverse - reverse.round()).abs() < 0.001) {
        return '1:${reverse.round()} Rev Split';
      }
      return '1:${reverse.toStringAsFixed(1)} Rev Split';
    }
    return '1:1 Split';
  }
}

/// Represents the nested split definition inside Robinhood's split payment corporate action.
/// Contains original and new instrument UUIDs, ratio multiplier/divisor, effective date, and direction.
@immutable
class SplitPaymentSplit {
  final String id;
  final String oldInstrumentId;
  final String newInstrumentId;
  final DateTime? effectiveDate;
  final double multiplier;
  final double divisor;
  final String direction; // 'forward', 'reverse'
  final DateTime? updatedAt;
  final String? url;

  const SplitPaymentSplit({
    this.id = '',
    this.oldInstrumentId = '',
    this.newInstrumentId = '',
    this.effectiveDate,
    this.multiplier = 1.0,
    this.divisor = 1.0,
    this.direction = 'forward',
    this.updatedAt,
    this.url,
  });

  double get effectiveMultiplier =>
      (divisor > 0 ? multiplier / divisor : multiplier);

  factory SplitPaymentSplit.fromJson(dynamic json) {
    if (json == null) return const SplitPaymentSplit();
    if (json is String) {
      if (json.startsWith('http')) {
        return SplitPaymentSplit(url: json);
      }
      return SplitPaymentSplit(id: json);
    }
    if (json is! Map) return const SplitPaymentSplit();

    DateTime? effDate;
    if (json['effective_date'] != null) {
      effDate = DateTime.tryParse(json['effective_date'].toString());
    } else if (json['execution_date'] != null) {
      effDate = DateTime.tryParse(json['execution_date'].toString());
    } else if (json['date'] != null) {
      effDate = DateTime.tryParse(json['date'].toString());
    }

    DateTime? updDate;
    if (json['updated_at'] != null) {
      updDate = DateTime.tryParse(json['updated_at'].toString());
    }

    final mult = parseDouble(json['multiplier']) ?? 1.0;
    final div = parseDouble(json['divisor']) ?? 1.0;
    final dir = json['direction']?.toString() ??
        (mult >= div ? 'forward' : 'reverse');

    return SplitPaymentSplit(
      id: json['id']?.toString() ?? '',
      oldInstrumentId: json['old_instrument_id']?.toString() ??
          json['equity_instrument_id']?.toString() ??
          json['instrument_id']?.toString() ??
          json['instrument']?.toString() ??
          '',
      newInstrumentId: json['new_instrument_id']?.toString() ??
          json['instrument_id']?.toString() ??
          json['instrument']?.toString() ??
          '',
      effectiveDate: effDate,
      multiplier: mult,
      divisor: div,
      direction: dir,
      updatedAt: updDate,
      url: json['url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        if (oldInstrumentId.isNotEmpty) 'old_instrument_id': oldInstrumentId,
        if (newInstrumentId.isNotEmpty) 'new_instrument_id': newInstrumentId,
        if (effectiveDate != null)
          'effective_date':
              "${effectiveDate!.year.toString().padLeft(4, '0')}-${effectiveDate!.month.toString().padLeft(2, '0')}-${effectiveDate!.day.toString().padLeft(2, '0')}",
        'multiplier': multiplier,
        'divisor': divisor,
        'direction': direction,
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        if (url != null) 'url': url,
      };

  @override
  String toString() => url ?? (id.isNotEmpty ? id : super.toString());

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is String) {
      return other == url || (id.isNotEmpty && other == id);
    }
    return other is SplitPaymentSplit &&
        other.id == id &&
        other.oldInstrumentId == oldInstrumentId &&
        other.newInstrumentId == newInstrumentId &&
        other.multiplier == multiplier &&
        other.divisor == divisor &&
        other.direction == direction &&
        other.effectiveDate == effectiveDate;
  }

  @override
  int get hashCode => Object.hash(id, oldInstrumentId, newInstrumentId,
      multiplier, divisor, direction, effectiveDate);
}

/// Represents a corporate action stock split payment and account adjustment.
/// Corresponds to Robinhood's `/corp_actions/v2/split_payments/` endpoint.
@immutable
class SplitPayment {
  final String id;
  final String accountNumber;
  final String instrumentId;
  final String symbol;
  final String actionType; // 'forward_split', 'reverse_split', 'stock_split'
  final double multiplier;
  final double divisor;
  final double oldShares;
  final double newShares;
  final double cashInLieu;
  final String currencyCode;
  final String state; // 'settled', 'pending', 'canceled', 'reversed'
  final DateTime? executionDate;
  final DateTime? paymentDate;
  final String? description;
  final SplitPaymentSplit? split;

  const SplitPayment({
    required this.id,
    required this.accountNumber,
    required this.instrumentId,
    required this.symbol,
    this.actionType = 'stock_split',
    this.multiplier = 1.0,
    this.divisor = 1.0,
    this.oldShares = 0.0,
    this.newShares = 0.0,
    this.cashInLieu = 0.0,
    this.currencyCode = 'USD',
    this.state = 'settled',
    this.executionDate,
    this.paymentDate,
    this.description,
    this.split,
  });

  String get oldInstrumentId =>
      split?.oldInstrumentId.isNotEmpty == true ? split!.oldInstrumentId : instrumentId;
  String get newInstrumentId =>
      split?.newInstrumentId.isNotEmpty == true ? split!.newInstrumentId : instrumentId;
  String? get splitUrl => split?.url;

  SplitPayment copyWith({
    String? id,
    String? accountNumber,
    String? instrumentId,
    String? symbol,
    String? actionType,
    double? multiplier,
    double? divisor,
    double? oldShares,
    double? newShares,
    double? cashInLieu,
    String? currencyCode,
    String? state,
    DateTime? executionDate,
    DateTime? paymentDate,
    String? description,
    dynamic split,
  }) {
    SplitPaymentSplit? splitVal = this.split;
    if (split != null) {
      if (split is SplitPaymentSplit) {
        splitVal = split;
      } else {
        splitVal = SplitPaymentSplit.fromJson(split);
      }
    }
    return SplitPayment(
      id: id ?? this.id,
      accountNumber: accountNumber ?? this.accountNumber,
      instrumentId: instrumentId ?? this.instrumentId,
      symbol: symbol ?? this.symbol,
      actionType: actionType ?? this.actionType,
      multiplier: multiplier ?? this.multiplier,
      divisor: divisor ?? this.divisor,
      oldShares: oldShares ?? this.oldShares,
      newShares: newShares ?? this.newShares,
      cashInLieu: cashInLieu ?? this.cashInLieu,
      currencyCode: currencyCode ?? this.currencyCode,
      state: state ?? this.state,
      executionDate: executionDate ?? this.executionDate,
      paymentDate: paymentDate ?? this.paymentDate,
      description: description ?? this.description,
      split: splitVal,
    );
  }

  factory SplitPayment.fromJson(dynamic json) {
    if (json is! Map) {
      return const SplitPayment(
        id: '',
        accountNumber: '',
        instrumentId: '',
        symbol: '',
      );
    }

    final id = json['id']?.toString() ?? '';
    final accountNumber = json['account_number']?.toString() ??
        json['account']?.toString() ??
        '';

    SplitPaymentSplit? splitObj;
    if (json['split'] != null) {
      splitObj = SplitPaymentSplit.fromJson(json['split']);
    } else if (json['split_url'] != null) {
      splitObj = SplitPaymentSplit.fromJson(json['split_url']);
    } else if (json['split_id'] != null) {
      splitObj = SplitPaymentSplit.fromJson(json['split_id']);
    }

    var instrumentId = json['instrument_id']?.toString() ??
        json['instrument']?.toString() ??
        json['equity_instrument_id']?.toString() ??
        '';
    if (instrumentId.contains('/instruments/')) {
      final match =
          RegExp(r'/instruments/([a-zA-Z0-9-]+)/?').firstMatch(instrumentId);
      if (match != null) {
        instrumentId = match.group(1)!;
      }
    }

    // Extract instrumentId from the nested split object if empty at top level
    if (instrumentId.isEmpty && splitObj != null) {
      if (splitObj.oldInstrumentId.isNotEmpty) {
        instrumentId = splitObj.oldInstrumentId;
      } else if (splitObj.newInstrumentId.isNotEmpty) {
        instrumentId = splitObj.newInstrumentId;
      } else if (splitObj.url != null) {
        final match =
            RegExp(r'/instruments/([a-zA-Z0-9-]+)/?').firstMatch(splitObj.url!);
        if (match != null) {
          instrumentId = match.group(1)!;
        }
      }
    }

    var symbol = json['symbol']?.toString().toUpperCase() ??
        json['ticker']?.toString().toUpperCase() ??
        '';

    var description = json['description']?.toString() ??
        json['details']?.toString() ??
        json['simple_name']?.toString() ??
        json['name']?.toString();

    if (json['instrument'] is Map) {
      final instMap = json['instrument'] as Map;
      if (symbol.isEmpty && instMap['symbol'] != null) {
        symbol = instMap['symbol'].toString().toUpperCase();
      }
      if (instrumentId.isEmpty && instMap['id'] != null) {
        instrumentId = instMap['id'].toString();
      }
      description ??= instMap['simple_name']?.toString() ??
          instMap['name']?.toString();
    }
    if (json['split'] is Map) {
      final splitMap = json['split'] as Map;
      if (symbol.isEmpty && splitMap['symbol'] != null) {
        symbol = splitMap['symbol'].toString().toUpperCase();
      }
      if (instrumentId.isEmpty && splitMap['instrument'] != null) {
        instrumentId = splitMap['instrument'].toString();
      }
      description ??= splitMap['description']?.toString() ??
          splitMap['simple_name']?.toString();
    }

    final actionType = json['action_type']?.toString() ??
        json['type']?.toString() ??
        'stock_split';

    final oldShares = parseDouble(json['old_shares']) ??
        parseDouble(json['pre_split_shares']) ??
        parseDouble(json['shares_held']) ??
        parseDouble(json['original_shares']) ??
        parseDouble(json['prior_shares']) ??
        parseDouble(json['pre_split_position']) ??
        0.0;
    final newShares = parseDouble(json['new_shares']) ??
        parseDouble(json['post_split_shares']) ??
        parseDouble(json['resulting_shares']) ??
        parseDouble(json['adjusted_shares']) ??
        parseDouble(json['new_position']) ??
        parseDouble(json['post_split_position']) ??
        0.0;

    var mult = parseDouble(json['multiplier']) ??
        parseDouble(json['split_multiplier']) ??
        parseDouble(json['to_factor']) ??
        parseDouble(json['numerator']);
    var div = parseDouble(json['divisor']) ??
        parseDouble(json['split_divisor']) ??
        parseDouble(json['from_factor']) ??
        parseDouble(json['denominator']);

    // Check if ratio is provided as a string like "10:1", "1:25", "10/1"
    final ratioStr = json['ratio']?.toString() ??
        json['split_ratio']?.toString() ??
        json['rate']?.toString();
    if (ratioStr != null && ratioStr.isNotEmpty) {
      if (ratioStr.contains(':')) {
        final parts = ratioStr.split(':');
        if (parts.length == 2) {
          mult ??= parseDouble(parts[0]);
          div ??= parseDouble(parts[1]);
        }
      } else if (ratioStr.contains('/')) {
        final parts = ratioStr.split('/');
        if (parts.length == 2) {
          mult ??= parseDouble(parts[0]);
          div ??= parseDouble(parts[1]);
        }
      } else {
        mult ??= parseDouble(ratioStr);
      }
    }

    if (json['split'] is Map) {
      final splitMap = json['split'] as Map;
      mult ??= parseDouble(splitMap['multiplier']);
      div ??= parseDouble(splitMap['divisor']);
    }

    // Derive from oldShares and newShares if mult and div are missing or 1.0:
    if ((mult == null || (mult == 1.0 && (div == null || div == 1.0))) &&
        oldShares > 0 &&
        newShares > 0 &&
        (newShares - oldShares).abs() > 0.0001) {
      final ratio = newShares / oldShares;
      if (ratio > 1.0001) {
        mult = ratio;
        div = 1.0;
      } else if (ratio < 0.9999 && ratio > 0) {
        mult = 1.0;
        div = 1.0 / ratio;
      }
    }

    mult ??= 1.0;
    div ??= 1.0;
    final cashInLieu = parseDouble(json['cash_in_lieu']) ??
        parseDouble(json['cash_in_lieu_amount']) ??
        parseDouble(json['cil_amount']) ??
        parseDouble(json['amount']) ??
        0.0;
    final currencyCode = json['currency_code']?.toString() ??
        json['cash_in_lieu_currency']?.toString() ??
        'USD';
    final state = json['state']?.toString() ??
        json['status']?.toString() ??
        'settled';

    DateTime? execDate;
    if (json['execution_date'] != null) {
      execDate = DateTime.tryParse(json['execution_date'].toString());
    } else if (json['executed_at'] != null) {
      execDate = DateTime.tryParse(json['executed_at'].toString());
    } else if (json['date'] != null) {
      execDate = DateTime.tryParse(json['date'].toString());
    }
    if (execDate == null && splitObj?.effectiveDate != null) {
      execDate = splitObj!.effectiveDate;
    }

    DateTime? payDate;
    if (json['payment_date'] != null) {
      payDate = DateTime.tryParse(json['payment_date'].toString());
    } else if (json['settled_at'] != null) {
      payDate = DateTime.tryParse(json['settled_at'].toString());
    } else if (json['settlement_date'] != null) {
      payDate = DateTime.tryParse(json['settlement_date'].toString());
    }

    return SplitPayment(
      id: id,
      accountNumber: accountNumber,
      instrumentId: instrumentId,
      symbol: symbol,
      actionType: actionType,
      multiplier: mult,
      divisor: div,
      oldShares: oldShares,
      newShares: newShares,
      cashInLieu: cashInLieu,
      currencyCode: currencyCode,
      state: state,
      executionDate: execDate,
      paymentDate: payDate,
      description: description,
      split: splitObj,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'account_number': accountNumber,
        'instrument_id': instrumentId,
        'symbol': symbol,
        'action_type': actionType,
        'multiplier': multiplier,
        'divisor': divisor,
        'old_shares': oldShares,
        'new_shares': newShares,
        'cash_in_lieu': cashInLieu,
        'currency_code': currencyCode,
        'state': state,
        if (executionDate != null)
          'execution_date': executionDate!.toIso8601String(),
        if (paymentDate != null)
          'payment_date': paymentDate!.toIso8601String(),
        if (description != null) 'description': description,
        if (split != null)
          'split': split!.url != null && split!.id.isEmpty
              ? split!.url
              : split!.toJson(),
      };

  String get displaySymbol {
    if (symbol.isNotEmpty) return symbol;
    if (description != null && description!.isNotEmpty) {
      final parts = description!.trim().split(' ');
      if (parts.isNotEmpty && parts.first.isNotEmpty && parts.first.length <= 5) {
        return parts.first.toUpperCase();
      }
      return description!;
    }
    final shortId = shortInstrumentId;
    if (shortId.isNotEmpty) {
      return shortId.length > 8 ? shortId.substring(0, 8).toUpperCase() : shortId.toUpperCase();
    }
    return 'Stock';
  }

  String get shortInstrumentId {
    if (instrumentId.isEmpty) return '';
    if (instrumentId.contains('/')) {
      final segments =
          instrumentId.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) return segments.last;
    }
    return instrumentId;
  }

  double get effectiveMultiplier {
    if (divisor > 0 && multiplier > 0 && (multiplier != 1.0 || divisor != 1.0)) {
      return multiplier / divisor;
    }
    if (oldShares > 0 && newShares > 0 && (newShares - oldShares).abs() > 0.0001) {
      return newShares / oldShares;
    }
    return (divisor > 0 ? multiplier / divisor : multiplier);
  }

  bool get isForwardSplit =>
      actionType == 'forward_split' || effectiveMultiplier > 1.00001;

  bool get isReverseSplit =>
      actionType == 'reverse_split' ||
      (effectiveMultiplier < 0.99999 && effectiveMultiplier > 0);

  bool get hasCashInLieu => cashInLieu > 0.0001;

  bool get isSettled =>
      state.toLowerCase() == 'settled' || state.toLowerCase() == 'completed';

  bool get isPending => state.toLowerCase() == 'pending';

  double get sharesDelta => newShares - oldShares;

  String get formattedRatio {
    if (multiplier > 0 && divisor > 0 && (multiplier != 1.0 || divisor != 1.0)) {
      if (multiplier > divisor) {
        final ratio = multiplier / divisor;
        if ((ratio - ratio.round()).abs() < 0.001) {
          return '${ratio.round()} for 1 Split';
        }
        return '${multiplier.toInt()} for ${divisor.toInt()} Split';
      } else if (divisor > multiplier) {
        final ratio = divisor / multiplier;
        if ((ratio - ratio.round()).abs() < 0.001) {
          return '1 for ${ratio.round()} Reverse Split';
        }
        return '${multiplier.toInt()} for ${divisor.toInt()} Reverse Split';
      }
    }
    final mult = effectiveMultiplier;
    if (mult > 1.0001) {
      if ((mult - mult.round()).abs() < 0.001) {
        return '${mult.round()} for 1 Split';
      }
      return '${mult.toStringAsFixed(2)} for 1 Split';
    } else if (mult > 0.0 && mult < 0.9999) {
      final reverse = 1.0 / mult;
      if ((reverse - reverse.round()).abs() < 0.001) {
        return '1 for ${reverse.round()} Reverse Split';
      }
      return '1 for ${reverse.toStringAsFixed(2)} Reverse Split';
    }
    return '1 for 1 Split';
  }

  String get shortRatioBadge {
    if (multiplier > 0 && divisor > 0 && (multiplier != 1.0 || divisor != 1.0)) {
      if (multiplier > divisor) {
        final ratio = multiplier / divisor;
        if ((ratio - ratio.round()).abs() < 0.001) {
          return '${ratio.round()}:1 Split';
        }
        return '${multiplier.toInt()}:${divisor.toInt()} Split';
      } else if (divisor > multiplier) {
        final ratio = divisor / multiplier;
        if ((ratio - ratio.round()).abs() < 0.001) {
          return '1:${ratio.round()} Rev Split';
        }
        return '${multiplier.toInt()}:${divisor.toInt()} Rev Split';
      }
    }
    final mult = effectiveMultiplier;
    if (mult > 1.0001) {
      if ((mult - mult.round()).abs() < 0.001) {
        return '${mult.round()}:1 Split';
      }
      return '${mult.toStringAsFixed(1)}:1 Split';
    } else if (mult > 0.0 && mult < 0.9999) {
      final reverse = 1.0 / mult;
      if ((reverse - reverse.round()).abs() < 0.001) {
        return '1:${reverse.round()} Rev Split';
      }
      return '1:${reverse.toStringAsFixed(1)} Rev Split';
    }
    return '1:1 Split';
  }

  String get formattedSplitRatio {
    if (multiplier > 0 && divisor > 0 && (multiplier != 1.0 || divisor != 1.0)) {
      if (multiplier % 1 == 0 && divisor % 1 == 0) {
        return '${multiplier.toInt()}:${divisor.toInt()}';
      }
      return '${multiplier.toStringAsFixed(2)}:${divisor.toStringAsFixed(2)}';
    }
    final mult = effectiveMultiplier;
    if (mult > 1.0001) {
      if ((mult - mult.round()).abs() < 0.001) {
        return '${mult.round()}:1';
      }
      return '${mult.toStringAsFixed(2)}:1';
    } else if (mult > 0.0 && mult < 0.9999) {
      final reverse = 1.0 / mult;
      if ((reverse - reverse.round()).abs() < 0.001) {
        return '1:${reverse.round()}';
      }
      return '1:${reverse.toStringAsFixed(2)}';
    }
    return '${multiplier.toInt()}:${divisor.toInt()}';
  }

  String get formattedCashInLieu => _currencyFormat.format(cashInLieu);

  String get formattedOldShares => _formatShareAmount(oldShares);

  String get formattedNewShares => _formatShareAmount(newShares);

  String get formattedSharesDelta {
    final delta = sharesDelta;
    final prefix = delta > 0 ? '+' : '';
    return '$prefix${_formatShareAmount(delta)} sh';
  }

  String get formattedExecutionDate =>
      executionDate != null ? _shortDateFormat.format(executionDate!) : 'N/A';

  String get formattedPaymentDate =>
      paymentDate != null ? _shortDateFormat.format(paymentDate!) : 'N/A';

  static String _formatShareAmount(double shares) {
    if (shares % 1 == 0) {
      return shares.toInt().toString();
    }
    return shares.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}

/// Aggregated corporate action stock split summary metrics for an account or portfolio.
@immutable
class CorporateActionSplitsSummary {
  final int totalSplitsCount;
  final int forwardSplitsCount;
  final int reverseSplitsCount;
  final double totalCashInLieu;
  final List<String> symbolsAffected;

  const CorporateActionSplitsSummary({
    this.totalSplitsCount = 0,
    this.forwardSplitsCount = 0,
    this.reverseSplitsCount = 0,
    this.totalCashInLieu = 0.0,
    this.symbolsAffected = const [],
  });

  factory CorporateActionSplitsSummary.fromPayments(List<SplitPayment> payments) {
    int forwardCount = 0;
    int reverseCount = 0;
    double cashInLieuSum = 0.0;
    final symbolSet = <String>{};

    for (final payment in payments) {
      if (payment.isForwardSplit) {
        forwardCount++;
      } else if (payment.isReverseSplit) {
        reverseCount++;
      }
      cashInLieuSum += payment.cashInLieu;
      if (payment.symbol.isNotEmpty) {
        symbolSet.add(payment.symbol);
      }
    }

    final symbols = symbolSet.toList()..sort();

    return CorporateActionSplitsSummary(
      totalSplitsCount: payments.length,
      forwardSplitsCount: forwardCount,
      reverseSplitsCount: reverseCount,
      totalCashInLieu: cashInLieuSum,
      symbolsAffected: symbols,
    );
  }

  String get formattedTotalCashInLieu =>
      _currencyFormat.format(totalCashInLieu);
}
