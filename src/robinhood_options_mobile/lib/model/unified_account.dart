import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

/// Status of account margin risk and distance to maintenance liquidation.
enum MarginHealthStatus {
  healthy,
  warning,
  critical,
  marginCall,
  unleveraged,
}

/// Detailed margin health and maintenance buffer breakdown.
class MarginHealth {
  final MarginHealthStatus status;
  final double marginBuffer;
  final double marginBufferPercentage;
  final double borrowedAmount;
  final double marginLimit;
  final double maintenanceRequirement;
  final double portfolioEquity;
  final double leverageRatio;
  final double marginCallAmount;

  const MarginHealth({
    this.status = MarginHealthStatus.healthy,
    this.marginBuffer = 0.0,
    this.marginBufferPercentage = 1.0,
    this.borrowedAmount = 0.0,
    this.marginLimit = 0.0,
    this.maintenanceRequirement = 0.0,
    this.portfolioEquity = 0.0,
    this.leverageRatio = 1.0,
    this.marginCallAmount = 0.0,
  });

  bool get isMarginCall => status == MarginHealthStatus.marginCall;
  bool get isCritical => status == MarginHealthStatus.critical;
  bool get isWarning => status == MarginHealthStatus.warning;
  bool get isHealthy => status == MarginHealthStatus.healthy;
  bool get isUnleveraged => status == MarginHealthStatus.unleveraged;

  String get displayStatus {
    switch (status) {
      case MarginHealthStatus.marginCall:
        return 'Margin Call';
      case MarginHealthStatus.critical:
        return 'Critical Buffer';
      case MarginHealthStatus.warning:
        return 'Low Buffer';
      case MarginHealthStatus.healthy:
        return 'Healthy';
      case MarginHealthStatus.unleveraged:
        return 'Unleveraged';
    }
  }

  Color get statusColor {
    switch (status) {
      case MarginHealthStatus.marginCall:
      case MarginHealthStatus.critical:
        return Colors.redAccent;
      case MarginHealthStatus.warning:
        return Colors.amber;
      case MarginHealthStatus.healthy:
        return Colors.green;
      case MarginHealthStatus.unleveraged:
        return Colors.blueGrey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case MarginHealthStatus.marginCall:
        return Icons.error_rounded;
      case MarginHealthStatus.critical:
        return Icons.warning_amber_rounded;
      case MarginHealthStatus.warning:
        return Icons.info_outline_rounded;
      case MarginHealthStatus.healthy:
        return Icons.check_circle_outline_rounded;
      case MarginHealthStatus.unleveraged:
        return Icons.shield_outlined;
    }
  }

  factory MarginHealth.fromJson(dynamic json, [dynamic parentJson]) {
    if (json == null && parentJson == null) {
      return const MarginHealth(status: MarginHealthStatus.unleveraged);
    }

    final Map<String, dynamic> data = json is Map<String, dynamic>
        ? json
        : (json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{});
    final Map<String, dynamic> parent = parentJson is Map<String, dynamic>
        ? parentJson
        : (parentJson is Map
            ? Map<String, dynamic>.from(parentJson)
            : <String, dynamic>{});

    // If data itself contains 'margin_health', then data is the root payload
    final marginHealthMap = data['margin_health'] is Map
        ? data['margin_health']
        : (parent['margin_health'] is Map ? parent['margin_health'] : data);
    final equitiesMap = data['equities'] is Map
        ? data['equities']
        : (parent['equities'] is Map ? parent['equities'] : null);

    final borrowed = parseDouble(data['levered_amount'] ??
            parent['levered_amount'] ??
            data['borrowed_amount'] ??
            parent['borrowed_amount'] ??
            data['margin_used'] ??
            parent['margin_used'] ??
            data['settled_amount_borrowed'] ??
            parent['settled_amount_borrowed'] ??
            marginHealthMap['borrowed_amount']) ??
        0.0;

    final equity = parseDouble(data['portfolio_equity'] ??
            parent['portfolio_equity'] ??
            data['total_equity'] ??
            parent['total_equity'] ??
            data['equity'] ??
            parent['equity'] ??
            (equitiesMap != null ? equitiesMap['equity'] : null) ??
            marginHealthMap['portfolio_equity'] ??
            marginHealthMap['equity']) ??
        0.0;

    final maintenance = parseDouble(
            (equitiesMap != null ? equitiesMap['margin_maintenance'] : null) ??
                data['margin_maintenance'] ??
                parent['margin_maintenance'] ??
                data['maintenance_requirement'] ??
                parent['maintenance_requirement'] ??
                data['total_margin_maintenance'] ??
                parent['total_margin_maintenance'] ??
                data['excess_maintenance'] ??
                parent['excess_maintenance'] ??
                marginHealthMap['maintenance_requirement']) ??
        0.0;

    final limit = parseDouble(
            (equitiesMap != null ? equitiesMap['total_margin'] : null) ??
                data['margin_limit'] ??
                parent['margin_limit'] ??
                data['borrow_limit'] ??
                parent['borrow_limit'] ??
                marginHealthMap['margin_limit']) ??
        0.0;

    final callAmt = parseDouble(data['margin_call_amount'] ??
            parent['margin_call_amount'] ??
            data['margin_call_deficit'] ??
            parent['margin_call_deficit'] ??
            data['deficit'] ??
            parent['deficit'] ??
            marginHealthMap['margin_call_amount'] ??
            marginHealthMap['margin_call_deficit']) ??
        0.0;

    final nearMarginCall = data['near_margin_call'] == true ||
        parent['near_margin_call'] == true ||
        marginHealthMap['near_margin_call'] == true;

    // Buffer percentage / ratio:
    double bufferPct = 0.0;
    if (data['margin_buffer_percentage'] != null ||
        parent['margin_buffer_percentage'] != null ||
        marginHealthMap['margin_buffer_percentage'] != null) {
      bufferPct = parseDouble(marginHealthMap['margin_buffer_percentage'] ??
              data['margin_buffer_percentage'] ??
              parent['margin_buffer_percentage']) ??
          0.0;
    } else if (data['buffer_percentage'] != null ||
        parent['buffer_percentage'] != null ||
        marginHealthMap['buffer_percentage'] != null) {
      bufferPct = parseDouble(marginHealthMap['buffer_percentage'] ??
              data['buffer_percentage'] ??
              parent['buffer_percentage']) ??
          0.0;
    } else if (data['margin_buffer_ratio'] != null ||
        parent['margin_buffer_ratio'] != null ||
        marginHealthMap['margin_buffer_ratio'] != null) {
      bufferPct = parseDouble(marginHealthMap['margin_buffer_ratio'] ??
              data['margin_buffer_ratio'] ??
              parent['margin_buffer_ratio']) ??
          0.0;
    } else if (marginHealthMap['margin_buffer_amount'] != null ||
        data['margin_buffer_amount'] != null ||
        parent['margin_buffer_amount'] != null) {
      // In Robinhood phoenix API, margin_buffer_amount has dollar buffer, margin_buffer has the ratio (e.g. "1.0000")
      bufferPct = parseDouble(marginHealthMap['margin_buffer'] ??
              data['margin_buffer'] ??
              parent['margin_buffer']) ??
          0.0;
    } else {
      // If no percentage or buffer_amount field, check if margin_buffer is a decimal ratio <= 1.0
      final raw = parseDouble(marginHealthMap['margin_buffer'] ??
          data['margin_buffer'] ??
          parent['margin_buffer']);
      if (raw != null && raw <= 1.0) {
        bufferPct = raw;
      }
    }

    // Normalize percentage if sent as whole percentage (e.g. 42.0 instead of 0.42)
    if (bufferPct > 1.0) {
      bufferPct = bufferPct / 100.0;
    }

    // Margin buffer in dollars:
    double buffer = parseDouble(marginHealthMap['margin_buffer_amount'] ??
            data['margin_buffer_amount'] ??
            parent['margin_buffer_amount'] ??
            marginHealthMap['buffer_amount'] ??
            data['buffer_amount'] ??
            parent['buffer_amount']) ??
        0.0;

    // If dollar buffer was not directly in margin_buffer_amount:
    if (buffer == 0.0) {
      final rawBuffer = parseDouble(marginHealthMap['margin_buffer'] ??
          data['margin_buffer'] ??
          parent['margin_buffer']);
      if (rawBuffer != null &&
          (rawBuffer > 100.0 ||
              (data['margin_buffer_percentage'] != null && rawBuffer > 1.0))) {
        buffer = rawBuffer;
      } else if (equity > 0 && maintenance > 0 && equity >= maintenance) {
        buffer = equity - maintenance;
      } else if (bufferPct > 0 && equity > 0) {
        buffer = bufferPct * equity;
      }
    }

    // If buffer percentage was not set, compute from buffer / equity
    if (bufferPct == 0.0 && equity > 0 && buffer > 0) {
      bufferPct = (buffer / equity).clamp(0.0, 1.0);
    }

    double leverage = parseDouble(data['leverage_ratio'] ??
            parent['leverage_ratio'] ??
            data['leverage'] ??
            parent['leverage'] ??
            marginHealthMap['leverage_ratio']) ??
        1.0;
    if (leverage == 1.0 && equity > 0 && borrowed > 0) {
      leverage = (equity + borrowed) / equity;
    }

    // Status classification:
    // Check margin_health_state, status, state
    final rawStatus = (marginHealthMap['margin_health_state'] ??
            marginHealthMap['status'] ??
            marginHealthMap['state'] ??
            data['margin_health_state'] ??
            parent['margin_health_state'] ??
            data['status'] ??
            parent['status'] ??
            data['state'] ??
            parent['state'] ??
            '')
        .toString()
        .toLowerCase();

    MarginHealthStatus parsedStatus;
    if (callAmt > 0 || rawStatus == 'margin_call' || rawStatus == 'call') {
      parsedStatus = MarginHealthStatus.marginCall;
    } else if (rawStatus == 'critical' ||
        (bufferPct < 0.10 &&
            bufferPct > 0.0 &&
            (borrowed > 0 || maintenance > 0))) {
      parsedStatus = MarginHealthStatus.critical;
    } else if (rawStatus == 'warning' ||
        nearMarginCall ||
        (bufferPct < 0.25 &&
            bufferPct > 0.0 &&
            (borrowed > 0 || maintenance > 0))) {
      parsedStatus = MarginHealthStatus.warning;
    } else if (rawStatus == 'healthy') {
      parsedStatus = MarginHealthStatus.healthy;
    } else if (rawStatus == 'unleveraged' ||
        (borrowed <= 0.001 && maintenance <= 0.001)) {
      parsedStatus = MarginHealthStatus.unleveraged;
    } else {
      parsedStatus = MarginHealthStatus.healthy;
    }

    return MarginHealth(
      status: parsedStatus,
      marginBuffer: buffer,
      marginBufferPercentage: bufferPct,
      borrowedAmount: borrowed,
      marginLimit: limit,
      maintenanceRequirement: maintenance,
      portfolioEquity: equity,
      leverageRatio: leverage,
      marginCallAmount: callAmt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'margin_buffer': marginBuffer,
      'margin_buffer_percentage': marginBufferPercentage,
      'borrowed_amount': borrowedAmount,
      'margin_limit': marginLimit,
      'maintenance_requirement': maintenanceRequirement,
      'portfolio_equity': portfolioEquity,
      'leverage_ratio': leverageRatio,
      'margin_call_amount': marginCallAmount,
    };
  }
}

/// Collateral holds and reserved capital across options, equities, and crypto.
class CollateralAllocations {
  final double totalCollateralHeld;
  final double cashHeldForOptions;
  final double equityHeldForOptions;
  final double cryptoHeldForOrders;
  final double pendingOrderHolds;

  const CollateralAllocations({
    this.totalCollateralHeld = 0.0,
    this.cashHeldForOptions = 0.0,
    this.equityHeldForOptions = 0.0,
    this.cryptoHeldForOrders = 0.0,
    this.pendingOrderHolds = 0.0,
  });

  bool get hasCollateralHolds => totalCollateralHeld > 0.001;

  factory CollateralAllocations.fromJson(dynamic json, [dynamic parentJson]) {
    if (json == null && parentJson == null) {
      return const CollateralAllocations();
    }
    final Map<String, dynamic> data = json is Map<String, dynamic>
        ? json
        : (json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{});
    final Map<String, dynamic> parent = parentJson is Map<String, dynamic>
        ? parentJson
        : (parentJson is Map
            ? Map<String, dynamic>.from(parentJson)
            : <String, dynamic>{});

    final colMap = data['collateral'] is Map
        ? data['collateral']
        : (parent['collateral'] is Map ? parent['collateral'] : data);

    final cashOptions = parseDouble(colMap['cash_held_for_options'] ??
            colMap['cash_held_for_options_collateral'] ??
            data['cash_held_for_options_collateral'] ??
            parent['cash_held_for_options_collateral']) ??
        0.0;
    final equityOptions = parseDouble(colMap['equity_held_for_options'] ??
            colMap['stock_held_for_options_collateral'] ??
            data['cash_held_for_equity_orders'] ??
            parent['cash_held_for_equity_orders'] ??
            data['stock_held_for_options_collateral'] ??
            parent['stock_held_for_options_collateral']) ??
        0.0;
    final cryptoOrders = parseDouble(colMap['crypto_held_for_orders'] ??
            colMap['crypto_collateral'] ??
            data['cash_held_for_currency_orders'] ??
            parent['cash_held_for_currency_orders']) ??
        0.0;
    final pendingOrders = parseDouble(colMap['pending_order_holds'] ??
            colMap['cash_held_for_orders'] ??
            data['cash_held_for_orders'] ??
            parent['cash_held_for_orders'] ??
            data['cash_held_for_restrictions'] ??
            parent['cash_held_for_restrictions'] ??
            data['cash_held_for_dividends'] ??
            parent['cash_held_for_dividends']) ??
        0.0;

    double total = parseDouble(colMap['total_collateral_held'] ??
            colMap['total_collateral_hold'] ??
            data['total_collateral_held'] ??
            parent['total_collateral_held']) ??
        0.0;
    if (total == 0.0) {
      total = cashOptions + equityOptions + cryptoOrders + pendingOrders;
    }

    return CollateralAllocations(
      totalCollateralHeld: total,
      cashHeldForOptions: cashOptions,
      equityHeldForOptions: equityOptions,
      cryptoHeldForOrders: cryptoOrders,
      pendingOrderHolds: pendingOrders,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_collateral_held': totalCollateralHeld,
      'cash_held_for_options': cashHeldForOptions,
      'equity_held_for_options': equityHeldForOptions,
      'crypto_held_for_orders': cryptoHeldForOrders,
      'pending_order_holds': pendingOrderHolds,
    };
  }
}

/// Comprehensive Unified Account model integrating balances, true buying power,
/// margin buffer health, and multi-asset collateral holds from `/phoenix/accounts/unified`.
class UnifiedAccount {
  final String accountNumber;
  final String accountType; // 'margin', 'cash'
  final String? brokerageAccountType;
  final double buyingPower;
  final double optionsBuyingPower;
  final double cryptoBuyingPower;
  final double cashAvailableForWithdrawal;
  final double unsettledFunds;
  final MarginHealth marginHealth;
  final CollateralAllocations collateral;
  final double? dayTradeRatio;
  final double? dayTradeBuyingPower;
  final DateTime? updatedAt;
  final double? totalEquity;
  final double? totalMarketValue;
  final double? cryptoEquity;
  final double? uninvestedCash;

  const UnifiedAccount({
    required this.accountNumber,
    this.accountType = 'margin',
    this.brokerageAccountType,
    this.buyingPower = 0.0,
    this.optionsBuyingPower = 0.0,
    this.cryptoBuyingPower = 0.0,
    this.cashAvailableForWithdrawal = 0.0,
    this.unsettledFunds = 0.0,
    this.marginHealth = const MarginHealth(),
    this.collateral = const CollateralAllocations(),
    this.dayTradeRatio,
    this.dayTradeBuyingPower,
    this.updatedAt,
    this.totalEquity,
    this.totalMarketValue,
    this.cryptoEquity,
    this.uninvestedCash,
  });

  bool get isRetirement =>
      (brokerageAccountType?.toLowerCase().contains('ira') ?? false) ||
      accountType.toLowerCase().contains('ira') ||
      (brokerageAccountType?.toLowerCase().contains('retirement') ?? false);

  bool get isMarginAccount =>
      !isRetirement &&
      (accountType.toLowerCase().contains('margin') ||
          marginHealth.borrowedAmount > 0);

  factory UnifiedAccount.fromJson(dynamic json) {
    if (json == null) {
      return const UnifiedAccount(accountNumber: '');
    }

    // Support wrapped envelopes such as { results: [...] } or { accounts: [...] }
    if (json is Map<String, dynamic>) {
      if (json['results'] is List && (json['results'] as List).isNotEmpty) {
        return UnifiedAccount.fromJson((json['results'] as List).first);
      }
      if (json['accounts'] is List && (json['accounts'] as List).isNotEmpty) {
        return UnifiedAccount.fromJson((json['accounts'] as List).first);
      }
    }

    final Map<String, dynamic> data = json is Map<String, dynamic>
        ? json
        : (json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{});

    final equitiesMap = data['equities'] is Map ? data['equities'] : null;
    final cryptoMap = data['crypto'] is Map ? data['crypto'] : null;

    final acctNum = (data['account_number'] ??
            data['account'] ??
            (equitiesMap != null
                ? (equitiesMap['rhs_account_number'] ??
                    equitiesMap['apex_account_number'])
                : null) ??
            '')
        .toString();
    final type = (data['account_type'] ?? data['type'] ?? 'margin').toString();
    final brokerageType = data['brokerage_account_type']?.toString();

    final bp =
        parseDouble(data['account_buying_power'] ?? data['buying_power']) ??
            0.0;
    final optBp = parseDouble(data['options_buying_power'] ??
            data['option_buying_power'] ??
            data['buying_power']) ??
        bp;
    final cryptoBp = parseDouble(data['crypto_buying_power'] ??
            data['cash_available_for_crypto'] ??
            data['buying_power']) ??
        bp;
    final withdrawable = parseDouble(data['withdrawable_cash'] ??
            data['cash_available_for_withdrawal'] ??
            data['withdrawable_amount']) ??
        0.0;
    final uninvested = parseDouble(data['uninvested_cash']) ?? 0.0;
    final unsettled =
        parseDouble(data['unsettled_funds'] ?? data['unsettled_debit']) ?? 0.0;

    final totalEq = parseDouble(data['total_equity'] ??
            data['portfolio_equity'] ??
            (equitiesMap != null ? equitiesMap['equity'] : null)) ??
        0.0;
    final totalMv = parseDouble(data['total_market_value'] ??
            (equitiesMap != null ? equitiesMap['market_value'] : null)) ??
        0.0;
    final cryptoEq =
        parseDouble(cryptoMap != null ? cryptoMap['equity'] : null) ?? 0.0;

    // Parse MarginHealth (passing data and data['margin_health'])
    MarginHealth parsedHealth;
    if (data['margin_health'] != null) {
      parsedHealth = MarginHealth.fromJson(data['margin_health'], data);
    } else {
      parsedHealth = MarginHealth.fromJson(data);
    }

    // Parse CollateralAllocations
    CollateralAllocations parsedCollateral;
    if (data['collateral'] != null) {
      parsedCollateral =
          CollateralAllocations.fromJson(data['collateral'], data);
    } else {
      parsedCollateral = CollateralAllocations.fromJson(data);
    }

    final dtRatio = parseDouble(data['day_trade_ratio']);
    final dtBp = parseDouble(data['day_trade_buying_power'] ??
        data['day_trading_buying_power'] ??
        data['day_trades_buying_power']);
    final updated = data['updated_at'] != null
        ? DateTime.tryParse(data['updated_at'].toString())
        : null;

    return UnifiedAccount(
      accountNumber: acctNum,
      accountType: type,
      brokerageAccountType: brokerageType,
      buyingPower: bp,
      optionsBuyingPower: optBp,
      cryptoBuyingPower: cryptoBp,
      cashAvailableForWithdrawal: withdrawable,
      unsettledFunds: unsettled,
      marginHealth: parsedHealth,
      collateral: parsedCollateral,
      dayTradeRatio: dtRatio,
      dayTradeBuyingPower: dtBp,
      updatedAt: updated,
      totalEquity: totalEq,
      totalMarketValue: totalMv,
      cryptoEquity: cryptoEq,
      uninvestedCash: uninvested,
    );
  }

  /// Constructs a UnifiedAccount from existing standard Account and Portfolio models
  /// as a reliable client-side fallback when offline or for legacy endpoints.
  factory UnifiedAccount.fromAccountAndPortfolio(
      Account? account, Portfolio? portfolio) {
    if (account == null) {
      return const UnifiedAccount(accountNumber: '');
    }

    final equity = portfolio?.equity ?? account.portfolioCash ?? 0.0;
    final borrowed = account.settledAmountBorrowed ?? 0.0;
    final maintenance = portfolio?.excessMaintenance != null && equity > 0
        ? (equity - (portfolio?.excessMaintenance ?? 0.0))
            .clamp(0.0, double.infinity)
        : 0.0;
    final buffer = portfolio?.excessMaintenance ?? (equity > 0 ? equity : 0.0);
    final bufferPct = equity > 0 ? (buffer / equity).clamp(0.0, 1.0) : 1.0;

    MarginHealthStatus status;
    if (borrowed <= 0.001) {
      status = MarginHealthStatus.unleveraged;
    } else if (bufferPct < 0.10) {
      status = MarginHealthStatus.critical;
    } else if (bufferPct < 0.25) {
      status = MarginHealthStatus.warning;
    } else {
      status = MarginHealthStatus.healthy;
    }

    final marginHealth = MarginHealth(
      status: status,
      marginBuffer: buffer,
      marginBufferPercentage: bufferPct,
      borrowedAmount: borrowed,
      marginLimit: borrowed * 2,
      maintenanceRequirement: maintenance,
      portfolioEquity: equity,
      leverageRatio: equity > 0 ? (equity + borrowed) / equity : 1.0,
      marginCallAmount: 0.0,
    );

    final collateral = CollateralAllocations(
      totalCollateralHeld: account.cashHeldForOptionsCollateral ?? 0.0,
      cashHeldForOptions: account.cashHeldForOptionsCollateral ?? 0.0,
      equityHeldForOptions: 0.0,
      cryptoHeldForOrders: 0.0,
      pendingOrderHolds: 0.0,
    );

    final bp = account.buyingPower ?? account.portfolioCash ?? 0.0;
    final cashHeld = account.cashHeldForOptionsCollateral ?? 0.0;
    final optBp = (bp - cashHeld).clamp(0.0, double.infinity);

    return UnifiedAccount(
      accountNumber: account.accountNumber,
      accountType: account.type,
      brokerageAccountType: account.brokerageAccountType,
      buyingPower: bp,
      optionsBuyingPower: optBp,
      cryptoBuyingPower: bp,
      cashAvailableForWithdrawal:
          portfolio?.withdrawableAmount ?? account.portfolioCash ?? 0.0,
      unsettledFunds: account.unsettledDebit ?? 0.0,
      marginHealth: marginHealth,
      collateral: collateral,
      dayTradeRatio: account.dayTradeRatio,
      dayTradeBuyingPower: account.dayTradeBuyingPower,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_number': accountNumber,
      'account_type': accountType,
      'brokerage_account_type': brokerageAccountType,
      'buying_power': buyingPower,
      'options_buying_power': optionsBuyingPower,
      'crypto_buying_power': cryptoBuyingPower,
      'cash_available_for_withdrawal': cashAvailableForWithdrawal,
      'unsettled_funds': unsettledFunds,
      'margin_health': marginHealth.toJson(),
      'collateral': collateral.toJson(),
      'day_trade_ratio': dayTradeRatio,
      'day_trade_buying_power': dayTradeBuyingPower,
      'updated_at': updatedAt?.toIso8601String(),
      'total_equity': totalEquity,
      'total_market_value': totalMarketValue,
      'crypto_equity': cryptoEquity,
      'uninvested_cash': uninvestedCash,
    };
  }
}
