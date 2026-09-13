import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

final _currencyFormat = NumberFormat.simpleCurrency();
final _percentFormat = NumberFormat.percentPattern()..maximumFractionDigits = 2;

/// Severity level for instrument trade warnings.
enum InstrumentWarningSeverity {
  info,
  warning,
  critical,
}

/// Represents an individual risk or trade warning associated with an instrument.
class InstrumentTradeWarning {
  final String id;
  final String type;
  final String title;
  final String message;
  final InstrumentWarningSeverity severity;
  final bool requiresAcknowledgement;
  final String? actionUrl;

  const InstrumentTradeWarning({
    required this.id,
    this.type = 'warning',
    required this.title,
    required this.message,
    this.severity = InstrumentWarningSeverity.warning,
    this.requiresAcknowledgement = false,
    this.actionUrl,
  });

  factory InstrumentTradeWarning.fromJson(dynamic json) {
    if (json is! Map) {
      return const InstrumentTradeWarning(
        id: 'unknown',
        title: 'Notice',
        message: '',
        severity: InstrumentWarningSeverity.info,
      );
    }

    final id = json['id']?.toString() ??
        json['code']?.toString() ??
        'warn_${DateTime.now().millisecondsSinceEpoch}';
    final type = json['type']?.toString() ??
        json['warning_type']?.toString() ??
        json['category']?.toString() ??
        'warning';
    final title = json['title']?.toString() ??
        json['name']?.toString() ??
        _inferTitleFromType(type);
    final message = json['message']?.toString() ??
        json['text']?.toString() ??
        json['description']?.toString() ??
        '';

    final sevRaw = json['severity']?.toString().toLowerCase() ??
        json['level']?.toString().toLowerCase() ??
        '';
    InstrumentWarningSeverity severity = InstrumentWarningSeverity.warning;
    if (sevRaw == 'critical' ||
        sevRaw == 'danger' ||
        sevRaw == 'severe' ||
        sevRaw == 'error' ||
        type == 'halt' ||
        type == 'bankruptcy') {
      severity = InstrumentWarningSeverity.critical;
    } else if (sevRaw == 'info' || sevRaw == 'notice' || sevRaw == 'low') {
      severity = InstrumentWarningSeverity.info;
    }

    final requiresAck = json['requires_acknowledgement'] == true ||
        json['requires_ack'] == true;
    final actionUrl = json['action_url']?.toString() ?? json['url']?.toString();

    return InstrumentTradeWarning(
      id: id,
      type: type,
      title: title,
      message: message,
      severity: severity,
      requiresAcknowledgement: requiresAck,
      actionUrl: actionUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'severity': severity.name,
      'requires_acknowledgement': requiresAcknowledgement,
      if (actionUrl != null) 'action_url': actionUrl,
    };
  }

  static String _inferTitleFromType(String type) {
    switch (type.toLowerCase()) {
      case 'volatility':
      case 'high_volatility':
        return 'High Volatility Warning';
      case 'illiquid':
      case 'low_liquidity':
        return 'Low Liquidity / Wide Spread';
      case 'meme_stock':
        return 'Elevated Retail Volatility';
      case 'bankruptcy':
      case 'delisting':
        return 'Bankruptcy / Delisting Risk';
      case 'reverse_split':
        return 'Recent / Upcoming Reverse Split';
      case 'halt':
        return 'Trading Halt Notice';
      case 'regulatory':
        return 'Regulatory Trading Restriction';
      case 'penny_stock':
        return 'Penny Stock Disclosures';
      case 'leverage':
      case 'leveraged_etf':
        return 'Leveraged / Inverse Product Warning';
      default:
        return 'Trade Advisory Warning';
    }
  }

  IconData get icon {
    switch (severity) {
      case InstrumentWarningSeverity.critical:
        return Icons.error_outline_rounded;
      case InstrumentWarningSeverity.warning:
        return Icons.warning_amber_rounded;
      case InstrumentWarningSeverity.info:
        return Icons.info_outline_rounded;
    }
  }

  Color get severityColor {
    switch (severity) {
      case InstrumentWarningSeverity.critical:
        return Colors.redAccent;
      case InstrumentWarningSeverity.warning:
        return Colors.orange;
      case InstrumentWarningSeverity.info:
        return Colors.blueAccent;
    }
  }

  String get displaySeverity {
    switch (severity) {
      case InstrumentWarningSeverity.critical:
        return 'Critical Risk';
      case InstrumentWarningSeverity.warning:
        return 'Warning';
      case InstrumentWarningSeverity.info:
        return 'Notice';
    }
  }
}

/// Container for all trade warnings, alerts, and tradability restrictions for an instrument.
class InstrumentTradeWarnings {
  final String instrumentId;
  final List<InstrumentTradeWarning> warnings;
  final bool isHalted;
  final bool isTradeRestricted;
  final DateTime? updatedAt;

  const InstrumentTradeWarnings({
    required this.instrumentId,
    this.warnings = const [],
    this.isHalted = false,
    this.isTradeRestricted = false,
    this.updatedAt,
  });

  factory InstrumentTradeWarnings.fromJson(
      String instrumentId, dynamic json) {
    if (json is! Map) {
      return InstrumentTradeWarnings(instrumentId: instrumentId);
    }

    final rawWarnings = json['warnings'] ??
        json['results'] ??
        json['items'] ??
        (json is List ? json : null);

    final list = <InstrumentTradeWarning>[];
    if (rawWarnings is List) {
      for (final item in rawWarnings) {
        list.add(InstrumentTradeWarning.fromJson(item));
      }
    }

    final halted = json['halted'] == true ||
        json['is_halted'] == true ||
        json['trading_halted'] == true;
    final restricted = json['trade_restricted'] == true ||
        json['is_trade_restricted'] == true ||
        json['restricted'] == true;

    // If explicitly halted and no specific halt warning object was present, synthesize one
    if (halted && !list.any((w) => w.type == 'halt')) {
      list.insert(
        0,
        const InstrumentTradeWarning(
          id: 'trading_halt',
          type: 'halt',
          title: 'Trading Halted',
          message:
              'Trading in this instrument is currently halted by the exchange or regulatory authority.',
          severity: InstrumentWarningSeverity.critical,
        ),
      );
    }

    final updatedStr = json['updated_at']?.toString() ??
        json['timestamp']?.toString();
    final updatedAt =
        updatedStr != null ? DateTime.tryParse(updatedStr) : DateTime.now();

    return InstrumentTradeWarnings(
      instrumentId: instrumentId,
      warnings: list,
      isHalted: halted,
      isTradeRestricted: restricted,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'instrument_id': instrumentId,
      'warnings': warnings.map((w) => w.toJson()).toList(),
      'is_halted': isHalted,
      'is_trade_restricted': isTradeRestricted,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  bool get hasWarnings => warnings.isNotEmpty || isHalted || isTradeRestricted;

  bool get hasCritical =>
      isHalted ||
      isTradeRestricted ||
      warnings.any((w) => w.severity == InstrumentWarningSeverity.critical);

  InstrumentWarningSeverity get highestSeverity {
    if (hasCritical) return InstrumentWarningSeverity.critical;
    if (warnings.any((w) => w.severity == InstrumentWarningSeverity.warning)) {
      return InstrumentWarningSeverity.warning;
    }
    return InstrumentWarningSeverity.info;
  }

  InstrumentTradeWarning? get primaryWarning =>
      warnings.isNotEmpty ? warnings.first : null;
}

/// Real-time buying power and margin requirements for an account on a specific instrument.
/// https://bonfire.robinhood.com/accounts/{account}/instrument_buying_power/{instrument_id}/
class InstrumentBuyingPower {
  final String instrumentId;
  final String? accountNumber;
  final double buyingPower;
  final double? shortBuyingPower;
  final bool cashOnly;
  final double? marginRate; // Initial margin requirement (e.g., 0.50 = 50%)
  final double? maintenanceMarginRate; // Maintenance margin requirement (e.g., 0.30 = 30%)
  final double? maxShares;
  final double? maxShortShares;
  final bool isMarginable;
  final double? leverageRatio;
  final DateTime? updatedAt;

  const InstrumentBuyingPower({
    required this.instrumentId,
    this.accountNumber,
    required this.buyingPower,
    this.shortBuyingPower,
    this.cashOnly = false,
    this.marginRate,
    this.maintenanceMarginRate,
    this.maxShares,
    this.maxShortShares,
    this.isMarginable = true,
    this.leverageRatio,
    this.updatedAt,
  });

  factory InstrumentBuyingPower.fromJson(
      String instrumentId, dynamic json, {String? defaultAccount}) {
    if (json is! Map) {
      return InstrumentBuyingPower(
        instrumentId: instrumentId,
        accountNumber: defaultAccount,
        buyingPower: 0.0,
      );
    }

    final acct = json['account_number']?.toString() ??
        json['account']?.toString() ??
        defaultAccount;

    final bp = parseDouble(json['buying_power']) ??
        parseDouble(json['amount']) ??
        parseDouble(json['equity_buying_power']) ??
        0.0;

    final shortBp = parseDouble(json['short_buying_power']) ??
        parseDouble(json['short_selling_buying_power']);

    final cashOnly = json['cash_only'] == true ||
        json['is_cash_only'] == true ||
        json['margin_eligible'] == false;

    // Margin rates may be normalized (0.50) or percentage (50.0)
    var mRate = parseDouble(json['margin_rate']) ??
        parseDouble(json['initial_margin_ratio']) ??
        parseDouble(json['initial_margin_rate']) ??
        parseDouble(json['margin_ratio']);
    if (mRate != null && mRate > 1.0) {
      mRate = mRate / 100.0;
    }

    var mmRate = parseDouble(json['maintenance_margin_rate']) ??
        parseDouble(json['maintenance_margin_ratio']) ??
        parseDouble(json['maintenance_ratio']);
    if (mmRate != null && mmRate > 1.0) {
      mmRate = mmRate / 100.0;
    }

    final maxShares = parseDouble(json['max_shares']) ??
        parseDouble(json['maximum_shares']);
    final maxShortShares = parseDouble(json['max_short_shares']) ??
        parseDouble(json['maximum_short_shares']);

    final isMarginable = json['is_marginable'] != null
        ? json['is_marginable'] == true
        : !cashOnly;

    final leverage = parseDouble(json['leverage_ratio']) ??
        parseDouble(json['leverage']) ??
        (mRate != null && mRate > 0 ? (1.0 / mRate) : null);

    final updatedStr = json['updated_at']?.toString() ??
        json['timestamp']?.toString();
    final updatedAt =
        updatedStr != null ? DateTime.tryParse(updatedStr) : DateTime.now();

    return InstrumentBuyingPower(
      instrumentId: instrumentId,
      accountNumber: acct,
      buyingPower: bp,
      shortBuyingPower: shortBp,
      cashOnly: cashOnly,
      marginRate: mRate,
      maintenanceMarginRate: mmRate,
      maxShares: maxShares,
      maxShortShares: maxShortShares,
      isMarginable: isMarginable,
      leverageRatio: leverage,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'instrument_id': instrumentId,
      if (accountNumber != null) 'account_number': accountNumber,
      'buying_power': buyingPower,
      if (shortBuyingPower != null) 'short_buying_power': shortBuyingPower,
      'cash_only': cashOnly,
      if (marginRate != null) 'margin_rate': marginRate,
      if (maintenanceMarginRate != null)
        'maintenance_margin_rate': maintenanceMarginRate,
      if (maxShares != null) 'max_shares': maxShares,
      if (maxShortShares != null) 'max_short_shares': maxShortShares,
      'is_marginable': isMarginable,
      if (leverageRatio != null) 'leverage_ratio': leverageRatio,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  String get formattedBuyingPower => _currencyFormat.format(buyingPower);

  String get formattedShortBuyingPower => shortBuyingPower != null
      ? _currencyFormat.format(shortBuyingPower!)
      : 'N/A';

  String get marginPercentage =>
      marginRate != null ? _percentFormat.format(marginRate!) : '100%';

  String get maintenanceMarginPercentage => maintenanceMarginRate != null
      ? _percentFormat.format(maintenanceMarginRate!)
      : '30%';

  String get marginStatusLabel {
    if (cashOnly || !isMarginable || (marginRate != null && marginRate! >= 1.0)) {
      return '100% Cash Required';
    }
    if (marginRate != null) {
      final pct = (marginRate! * 100).toStringAsFixed(0);
      return '$pct% Initial Margin';
    }
    return 'Margin Eligible';
  }

  bool get hasShortCapacity =>
      shortBuyingPower != null && shortBuyingPower! > 0;
}
