import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

enum ComboLegType { equity, option }

class ComboLegExecution {
  final String id;
  final double? price;
  final double? quantity;
  final String? settlementDate;
  final DateTime? timestamp;

  ComboLegExecution({
    required this.id,
    this.price,
    this.quantity,
    this.settlementDate,
    this.timestamp,
  });

  ComboLegExecution.fromJson(dynamic json)
      : id = json['id']?.toString() ?? '',
        price = parseDouble(json['price']),
        quantity = parseDouble(json['quantity']),
        settlementDate = json['settlement_date']?.toString(),
        timestamp = json['timestamp'] is Timestamp
            ? (json['timestamp'] as Timestamp).toDate()
            : (json['timestamp'] is String
                ? DateTime.tryParse(json['timestamp'])
                : null);

  Map<String, dynamic> toJson() => {
        'id': id,
        'price': price,
        'quantity': quantity,
        'settlement_date': settlementDate,
        'timestamp': timestamp?.toIso8601String(),
      };

  static List<ComboLegExecution> fromJsonArray(dynamic json) {
    if (json == null || json is! List) return [];
    return json.map((e) => ComboLegExecution.fromJson(e)).toList();
  }
}

class ComboLeg {
  final String id;
  final ComboLegType legType;
  final String? instrument;
  final String? option;
  final String? symbol;
  final String? positionEffect; // 'open' | 'close'
  final double ratioQuantity;
  final String side; // 'buy' | 'sell'
  final DateTime? expirationDate;
  final double? strikePrice;
  final String? optionType; // 'call' | 'put'
  final List<ComboLegExecution> executions;

  ComboLeg({
    required this.id,
    required this.legType,
    this.instrument,
    this.option,
    this.symbol,
    this.positionEffect,
    required this.ratioQuantity,
    required this.side,
    this.expirationDate,
    this.strikePrice,
    this.optionType,
    this.executions = const [],
  });

  bool get isOption => legType == ComboLegType.option;
  bool get isEquity => legType == ComboLegType.equity;

  ComboLeg.fromJson(dynamic json)
      : id = json['id']?.toString() ?? '',
        legType = (json['leg_type'] == 'equity' ||
                json['leg_type'] == 'stock' ||
                json['execution_type'] == 'equity' ||
                json['execution_type'] == 'stock' ||
                json['instrument'] != null ||
                json['instrument_id'] != null)
            ? ComboLegType.equity
            : ComboLegType.option,
        instrument = (json['instrument'] ?? json['instrument_id'])?.toString(),
        option = (json['option'] ?? json['option_id'])?.toString(),
        symbol = json['symbol']?.toString(),
        positionEffect = json['position_effect']?.toString(),
        ratioQuantity = parseDouble(json['ratio_quantity']) ?? 1.0,
        side = json['side']?.toString().toLowerCase() ?? 'buy',
        expirationDate = json['expiration_date'] is Timestamp
            ? (json['expiration_date'] as Timestamp).toDate()
            : (json['expiration_date'] is String
                ? DateTime.tryParse(json['expiration_date'])
                : null),
        strikePrice = parseDouble(json['strike_price']),
        optionType = json['option_type']?.toString().toLowerCase(),
        executions = json['executions'] != null
            ? ComboLegExecution.fromJsonArray(json['executions'])
            : [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'leg_type': legType.name,
        'instrument': instrument,
        'option': option,
        'symbol': symbol,
        'position_effect': positionEffect,
        'ratio_quantity': ratioQuantity,
        'side': side,
        'expiration_date': expirationDate?.toIso8601String(),
        'strike_price': strikePrice,
        'option_type': optionType,
        'executions': executions.map((e) => e.toJson()).toList(),
      };

  String get actionDisplay {
    final s = side.isNotEmpty
        ? '${side[0].toUpperCase()}${side.substring(1).toLowerCase()}'
        : '';
    if (positionEffect != null && positionEffect!.isNotEmpty) {
      final pe =
          '${positionEffect![0].toUpperCase()}${positionEffect!.substring(1).toLowerCase()}';
      return '$s to $pe';
    }
    return s;
  }

  String get formattedLegDescription {
    if (isEquity) {
      final shares = ratioQuantity % 1 == 0
          ? ratioQuantity.toInt().toString()
          : ratioQuantity.toStringAsFixed(2);
      final sym = symbol ?? 'Stock';
      return '$actionDisplay $shares shares of $sym';
    } else {
      final contracts = ratioQuantity % 1 == 0
          ? ratioQuantity.toInt().toString()
          : ratioQuantity.toStringAsFixed(0);
      final optType = (optionType ?? '').toUpperCase();
      final strike =
          strikePrice != null ? '\$${strikePrice!.toStringAsFixed(2)}' : '';
      final exp = expirationDate != null
          ? DateFormat('MM/dd/yy').format(expirationDate!)
          : '';
      final sym = symbol ?? '';
      return '$actionDisplay $contracts contract $sym $exp $strike $optType'
          .trim();
    }
  }

  String get ratioQuantityDisplay {
    final qty = ratioQuantity.round();
    if (isEquity) {
      return '$qty ${qty == 1 ? "Share" : "Shares"}';
    }
    return '$qty ${qty == 1 ? "Contract" : "Contracts"}';
  }

  String get optionSummary {
    if (!isOption) return '';
    final strikeStr = strikePrice != null
        ? '\$${strikePrice! % 1 == 0 ? strikePrice!.toInt() : strikePrice}'
        : '';
    final typeStr = optionType != null
        ? '${optionType![0].toUpperCase()}${optionType!.substring(1)}'
        : '';
    final expStr = expirationDate != null
        ? '${expirationDate!.month}/${expirationDate!.day}/${expirationDate!.year}'
        : '';
    return '$strikeStr $typeStr $expStr'.trim();
  }

  static List<ComboLeg> fromJsonArray(dynamic json) {
    if (json == null || json is! List) return [];
    return json.map((e) => ComboLeg.fromJson(e)).toList();
  }
}

class ComboOrder {
  final String id;
  final String account;
  final String? cancelUrl;
  final String direction; // 'debit' | 'credit'
  final List<ComboLeg> legs;
  final double quantity;
  final double? price;
  final double? stopPrice;
  final double? processedQuantity;
  final double? pendingQuantity;
  final double? canceledQuantity;
  final double? premium;
  final double? processedPremium;
  final String refId;
  final String
      state; // 'queued', 'confirmed', 'filled', 'cancelled', 'rejected'
  final String timeInForce; // 'gtc', 'gfd', 'ioc', 'opg'
  final String trigger; // 'immediate', 'stop'
  final String type; // 'limit', 'market'
  final String? responseCategory;
  final String? openingStrategy;
  final String? closingStrategy;
  final String? chainSymbol;
  final String? chainId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ComboOrder({
    required this.id,
    this.account = '',
    this.cancelUrl,
    required this.direction,
    required this.legs,
    required this.quantity,
    this.price,
    this.stopPrice,
    this.processedQuantity,
    this.pendingQuantity,
    this.canceledQuantity,
    this.premium,
    this.processedPremium,
    this.refId = '',
    required this.state,
    this.timeInForce = 'gtc',
    this.trigger = 'immediate',
    this.type = 'limit',
    this.responseCategory,
    this.openingStrategy,
    this.closingStrategy,
    this.chainSymbol,
    this.chainId,
    this.createdAt,
    this.updatedAt,
  });

  ComboOrder.fromJson(dynamic json)
      : id = json['id']?.toString() ?? '',
        account = json['account']?.toString() ??
            json['account_number']?.toString() ??
            '',
        cancelUrl = json['cancel_url']?.toString(),
        direction = json['direction']?.toString().toLowerCase() ?? 'debit',
        legs = json['legs'] != null ? ComboLeg.fromJsonArray(json['legs']) : [],
        quantity = parseDouble(json['quantity']) ?? 1.0,
        price = parseDouble(json['price']),
        stopPrice = parseDouble(json['stop_price']),
        processedQuantity = parseDouble(json['processed_quantity']),
        pendingQuantity = parseDouble(json['pending_quantity']),
        canceledQuantity = parseDouble(json['canceled_quantity']),
        premium = parseDouble(json['premium']),
        processedPremium = parseDouble(json['processed_premium']),
        refId = json['ref_id']?.toString() ?? '',
        state = json['state']?.toString().toLowerCase() ?? 'queued',
        timeInForce = json['time_in_force']?.toString().toLowerCase() ?? 'gtc',
        trigger = json['trigger']?.toString().toLowerCase() ?? 'immediate',
        type = json['type']?.toString().toLowerCase() ?? 'limit',
        responseCategory = json['response_category']?.toString(),
        openingStrategy = json['opening_strategy']?.toString(),
        closingStrategy = json['closing_strategy']?.toString(),
        chainSymbol = json['chain_symbol']?.toString(),
        chainId = json['chain_id']?.toString(),
        createdAt = json['created_at'] is Timestamp
            ? (json['created_at'] as Timestamp).toDate()
            : (json['created_at'] is String
                ? DateTime.tryParse(json['created_at'])
                : null),
        updatedAt = json['updated_at'] is Timestamp
            ? (json['updated_at'] as Timestamp).toDate()
            : (json['updated_at'] is String
                ? DateTime.tryParse(json['updated_at'])
                : null);

  Map<String, dynamic> toJson() => {
        'id': id,
        'account': account,
        'cancel_url': cancelUrl,
        'direction': direction,
        'legs': legs.map((e) => e.toJson()).toList(),
        'quantity': quantity,
        'price': price,
        'stop_price': stopPrice,
        'processed_quantity': processedQuantity,
        'pending_quantity': pendingQuantity,
        'canceled_quantity': canceledQuantity,
        'premium': premium,
        'processed_premium': processedPremium,
        'ref_id': refId,
        'state': state,
        'time_in_force': timeInForce,
        'trigger': trigger,
        'type': type,
        'response_category': responseCategory,
        'opening_strategy': openingStrategy,
        'closing_strategy': closingStrategy,
        'chain_symbol': chainSymbol,
        'chain_id': chainId,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  bool get isFilled => state == 'filled';
  bool get isCancelled => state == 'cancelled' || state == 'canceled';
  bool get isRejected => state == 'rejected' || state == 'failed';
  bool get isOpen =>
      state == 'queued' ||
      state == 'unconfirmed' ||
      state == 'confirmed' ||
      state == 'partially_filled';
  bool get canCancel => cancelUrl != null && isOpen;

  String get directionDisplay => direction.isEmpty
      ? ''
      : '${direction[0].toUpperCase()}${direction.substring(1)}';

  String get strategyDisplay {
    final strat = openingStrategy ?? closingStrategy;
    if (strat != null && strat.isNotEmpty) {
      return strat
          .split('_')
          .map((w) =>
              w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
          .join(' ');
    }
    // Derive from legs
    final hasStock = legs.any((l) => l.isEquity);
    final hasOption = legs.any((l) => l.isOption);
    if (hasStock && hasOption) {
      if (legs.length == 2) {
        final opt = legs.firstWhere((l) => l.isOption);
        final stock = legs.firstWhere((l) => l.isEquity);
        if (stock.side == 'buy' &&
            opt.side == 'sell' &&
            opt.optionType == 'call') {
          return 'Covered Call';
        }
        if (stock.side == 'buy' &&
            opt.side == 'buy' &&
            opt.optionType == 'put') {
          return 'Married Put';
        }
        if (stock.side == 'buy' && opt.side == 'sell') {
          return 'Buy-Write';
        }
      } else if (legs.length == 3) {
        final hasCall = legs.any(
            (l) => l.isOption && l.optionType == 'call' && l.side == 'sell');
        final hasPut = legs
            .any((l) => l.isOption && l.optionType == 'put' && l.side == 'buy');
        if (hasCall && hasPut) {
          return 'Collar';
        }
      }
      return 'Stock + Option Package';
    }
    return 'Multi-Leg Combo';
  }

  String get primarySymbol {
    if (chainSymbol != null && chainSymbol!.isNotEmpty) {
      return chainSymbol!;
    }
    final sym = legs
        .firstWhereOrNull((l) => l.symbol != null && l.symbol!.isNotEmpty)
        ?.symbol;
    return sym ?? 'COMBO';
  }

  double get netAmount {
    if (processedPremium != null && processedPremium! > 0) {
      return processedPremium!;
    }
    if (premium != null && premium! > 0) {
      return premium!;
    }
    if (price != null) {
      return price! * quantity * 100;
    }
    return 0.0;
  }

  String get accountNumber {
    if (account.isEmpty) return '';
    return account.split('/').where((s) => s.isNotEmpty).last;
  }

  bool get isCancelable => canCancel;
  String get packageTypeDisplay => strategyDisplay;
  String get summaryTitle => '$primarySymbol $strategyDisplay';
  String get statusDisplay =>
      state.isEmpty ? '' : '${state[0].toUpperCase()}${state.substring(1)}';
  String get netDisplayPrice =>
      '\$${(price ?? netAmount).toStringAsFixed(2)} $directionDisplay';
  int get totalOptionQuantity => legs
      .where((l) => l.isOption)
      .fold(0, (total, l) => total + l.ratioQuantity.round());
  int get totalEquityQuantity => legs
      .where((l) => l.isEquity)
      .fold(0, (total, l) => total + l.ratioQuantity.round());

  static List<String> get csvHeader => [
        'Order ID',
        'Symbol',
        'Strategy',
        'State',
        'Direction',
        'Quantity',
        'Price',
        'Net Premium',
        'Time In Force',
        'Created At',
        'Updated At',
        'Legs Count',
      ];

  List<dynamic> toCsvRow() => [
        id,
        primarySymbol,
        strategyDisplay,
        state,
        directionDisplay,
        quantity,
        price ?? '',
        netAmount,
        timeInForce.toUpperCase(),
        createdAt != null
            ? DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt!)
            : '',
        updatedAt != null
            ? DateFormat('yyyy-MM-dd HH:mm:ss').format(updatedAt!)
            : '',
        legs.length,
      ];
}
