import 'package:flutter/material.dart';

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

num? _parseNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse(value.toString());
}

/// Represents short interest fundamentals reported for an equity instrument
@immutable
class ShortInterest {
  final String instrumentId;
  final String? symbol;
  final double?
      pcFreeFloat; // Free float shorted as decimal (0.154) or pct (15.4)
  final bool isPercentage;
  final num? sharesShort;
  final num? sharesShortPrior;
  final num? sharesShortUpperBound;
  final num? sharesShortLowerBound;
  final double? pcFreeFloatUpperBound;
  final double? pcFreeFloatLowerBound;
  final num? shortInterestChange;
  final double? shortInterestChangePct;
  final double? daysToCover;
  final DateTime? settlementDate;
  final num? freeFloat;
  final num? averageDailyVolume;
  final DateTime? updatedAt;

  const ShortInterest({
    required this.instrumentId,
    this.symbol,
    this.pcFreeFloat,
    this.isPercentage = false,
    this.sharesShort,
    this.sharesShortPrior,
    this.sharesShortUpperBound,
    this.sharesShortLowerBound,
    this.pcFreeFloatUpperBound,
    this.pcFreeFloatLowerBound,
    this.shortInterestChange,
    this.shortInterestChangePct,
    this.daysToCover,
    this.settlementDate,
    this.freeFloat,
    this.averageDailyVolume,
    this.updatedAt,
  });

  /// Normalizes free float percentage to a 0-100 range.
  /// Handles both decimal fractions (e.g. 0.0285 -> 2.85%) and direct percentages (e.g. 1.86 -> 1.86%).
  double? get freeFloatPercentage {
    if (pcFreeFloat == null) return null;
    if (isPercentage) {
      return pcFreeFloat;
    }
    // If it was provided as a decimal ratio <= 0.5 (e.g. 0.0285 for 2.85%):
    if (pcFreeFloat! > 0 && pcFreeFloat! <= 0.5) {
      return pcFreeFloat! * 100.0;
    }
    return pcFreeFloat;
  }

  factory ShortInterest.fromJson(Map<String, dynamic> json,
      {String? fallbackInstrumentId,
      String? fallbackSymbol,
      num? fallbackAverageDailyVolume,
      num? fallbackFreeFloat}) {
    Map<String, dynamic> data = json;

    // 1. Unwrap Robinhood marketdata response structure:
    // {"status":"SUCCESS","data":[{"status":"SUCCESS","data":{"symbol":"PCG", ... "daily_data":[...]}}]}
    if (json['data'] is List && (json['data'] as List).isNotEmpty) {
      final firstItem = (json['data'] as List).first;
      if (firstItem is Map<String, dynamic>) {
        if (firstItem['data'] is Map<String, dynamic>) {
          data = firstItem['data'] as Map<String, dynamic>;
        } else {
          data = firstItem;
        }
      }
    } else if (json['data'] is Map<String, dynamic>) {
      data = json['data'] as Map<String, dynamic>;
    } else if (json['results'] is List &&
        (json['results'] as List).isNotEmpty) {
      final firstItem = (json['results'] as List).first;
      if (firstItem is Map<String, dynamic>) {
        data = firstItem;
      }
    }

    final id =
        (data['instrument_id'] ?? data['id'] ?? fallbackInstrumentId ?? '')
            .toString();
    final sym = (data['symbol'] ?? fallbackSymbol)?.toString();

    bool isPercentage = false;
    num? shares;
    num? priorShares;
    num? sharesUpper;
    num? sharesLower;
    double? pcFloatUpper;
    double? pcFloatLower;
    double? rawPcFloat;
    DateTime? settlement;

    // 2. Check if daily_data array is present (Robinhood format)
    if (data['daily_data'] is List && (data['daily_data'] as List).isNotEmpty) {
      final dailyList = (data['daily_data'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      if (dailyList.isNotEmpty) {
        dailyList.sort((a, b) {
          final da = a['date']?.toString() ?? '';
          final db = b['date']?.toString() ?? '';
          return da.compareTo(db);
        });

        final latest = dailyList.last;
        isPercentage = true;
        rawPcFloat = _parseDouble(latest['pc_freefloat']);
        shares = _parseNum(latest['shares_short']);
        sharesUpper = _parseNum(latest['shares_upper_bound']);
        sharesLower = _parseNum(latest['shares_lower_bound']);
        pcFloatUpper = _parseDouble(latest['pc_freefloat_upper_bound']);
        pcFloatLower = _parseDouble(latest['pc_freefloat_lower_bound']);

        final dateStr = latest['date']?.toString();
        if (dateStr != null && dateStr.isNotEmpty) {
          try {
            settlement = DateTime.parse(dateStr);
          } catch (_) {}
        }

        if (dailyList.length >= 2) {
          final prior = dailyList[dailyList.length - 2];
          priorShares = _parseNum(prior['shares_short']);
        }
      }
    }

    // 3. Fallbacks for flat format
    rawPcFloat ??= _parseDouble(data['pc_freefloat'] ??
        data['pc_free_float'] ??
        data['free_float_percentage'] ??
        data['short_percent_of_float'] ??
        data['short_float_pct']);

    shares ??= _parseNum(data['shares_short'] ??
        data['current_shares_short'] ??
        data['short_interest'] ??
        data['shares']);

    priorShares ??= _parseNum(data['shares_short_prior'] ??
        data['prior_shares_short'] ??
        data['previous_shares_short']);

    sharesUpper ??= _parseNum(data['shares_upper_bound']);
    sharesLower ??= _parseNum(data['shares_lower_bound']);
    pcFloatUpper ??= _parseDouble(data['pc_freefloat_upper_bound']);
    pcFloatLower ??= _parseDouble(data['pc_freefloat_lower_bound']);

    if (settlement == null) {
      final dateStr =
          (data['settlement_date'] ?? data['date'] ?? data['report_date'])
              ?.toString();
      if (dateStr != null && dateStr.isNotEmpty) {
        try {
          settlement = DateTime.parse(dateStr);
        } catch (_) {}
      }
    }

    num? change =
        _parseNum(data['short_interest_change'] ?? data['shares_short_change']);
    if (change == null && shares != null && priorShares != null) {
      change = shares - priorShares;
    }

    double? changePct = _parseDouble(data['short_interest_change_pct'] ??
        data['short_interest_change_percent']);
    if (changePct == null &&
        change != null &&
        priorShares != null &&
        priorShares > 0) {
      changePct = change / priorShares;
    }

    double? dtc = _parseDouble(data['days_to_cover'] ??
        data['short_ratio'] ??
        data['days_to_cover_ratio']);

    num? adv =
        _parseNum(data['average_daily_volume'] ?? data['avg_daily_volume']) ??
            fallbackAverageDailyVolume;

    if (dtc == null && shares != null && adv != null && adv > 0) {
      dtc = shares / adv;
    }

    num? ff = _parseNum(data['free_float'] ?? data['shares_free_float']) ??
        fallbackFreeFloat;

    if (ff == null && shares != null && rawPcFloat != null && rawPcFloat > 0) {
      final ratio = isPercentage
          ? (rawPcFloat / 100.0)
          : (rawPcFloat > 1.0 ? rawPcFloat / 100.0 : rawPcFloat);
      if (ratio > 0) {
        ff = shares / ratio;
      }
    }

    DateTime? updated;
    final updatedStr = data['updated_at']?.toString();
    if (updatedStr != null && updatedStr.isNotEmpty) {
      try {
        updated = DateTime.parse(updatedStr);
      } catch (_) {}
    } else if (settlement != null) {
      updated = settlement;
    }

    return ShortInterest(
      instrumentId: id,
      symbol: sym,
      pcFreeFloat: rawPcFloat,
      isPercentage: isPercentage,
      sharesShort: shares,
      sharesShortPrior: priorShares,
      sharesShortUpperBound: sharesUpper,
      sharesShortLowerBound: sharesLower,
      pcFreeFloatUpperBound: pcFloatUpper,
      pcFreeFloatLowerBound: pcFloatLower,
      shortInterestChange: change,
      shortInterestChangePct: changePct,
      daysToCover: dtc,
      settlementDate: settlement,
      freeFloat: ff,
      averageDailyVolume: adv,
      updatedAt: updated,
    );
  }
}

/// Represents real-time shorting availability, borrow inventory tiers, and borrow fee rates
@immutable
class ShortingAvailability {
  final String instrumentId;
  final bool canShort;
  final String inventory; // 'HIGH', 'MEDIUM', 'LOW', 'NONE'
  final double? borrowFeeRate; // Decimal e.g. 0.0035 (0.35%) or 0.15 (15.0%)
  final bool isHardToBorrow;
  final String? hardToBorrowReason;
  final double? marginRequirement; // e.g. 1.50 (150%)
  final bool locateRequired;
  final DateTime? updatedAt;

  const ShortingAvailability({
    required this.instrumentId,
    this.canShort = true,
    this.inventory = 'HIGH',
    this.borrowFeeRate,
    this.isHardToBorrow = false,
    this.hardToBorrowReason,
    this.marginRequirement,
    this.locateRequired = false,
    this.updatedAt,
  });

  /// Annualized borrow fee rate expressed as a percentage (e.g. 0.35% or 15.0%)
  double? get borrowFeeRatePercentage {
    if (borrowFeeRate == null) return null;
    if (borrowFeeRate! > 0 && borrowFeeRate! <= 1.0) {
      return borrowFeeRate! * 100.0;
    }
    return borrowFeeRate;
  }

  factory ShortingAvailability.fromJson(Map<String, dynamic> json,
      {String? fallbackInstrumentId}) {
    final id =
        (json['instrument_id'] ?? json['id'] ?? fallbackInstrumentId ?? '')
            .toString();

    // Map raw inventory / inventory_range to friendly text and inventory tier
    final rawInventoryRange = json['inventory_range']?.toString();
    final rawInventory =
        json['inventory'] ?? json['inventory_level'] ?? json['availability'];

    String inventoryVal;
    if (rawInventoryRange != null && rawInventoryRange.isNotEmpty) {
      inventoryVal = rawInventoryRange;
    } else if (rawInventory != null) {
      inventoryVal = rawInventory.toString().toUpperCase();
    } else {
      inventoryVal = 'HIGH';
    }

    final canShortVal = json['can_short'] ??
        json['shortable'] ??
        (rawInventoryRange != null ? rawInventoryRange != '0' : true);

    // Parse fee which can be string "0.0000" or num in Robinhood's response
    final rawFee = json['fee'] ??
        json['borrow_fee_rate'] ??
        json['borrow_rate'] ??
        json['fee_rate'] ??
        json['annual_borrow_rate'] ??
        json['daily_fee'];

    double? feeRate;
    if (rawFee != null) {
      if (rawFee is num) {
        feeRate = rawFee.toDouble();
      } else {
        feeRate = double.tryParse(rawFee.toString());
      }
    }

    final isLowInventory = inventoryVal == 'LOW' ||
        inventoryVal == '<10K' ||
        inventoryVal == '<10k' ||
        inventoryVal == '0';

    final hardToBorrow = (json['is_hard_to_borrow'] ??
            json['hard_to_borrow'] ??
            (isLowInventory || (feeRate != null && feeRate > 0.05))) as bool? ??
        false;

    final reason = json['hard_to_borrow_reason']?.toString();

    final marginReq = (json['margin_requirement'] ??
        json['maintenance_margin'] ??
        json['initial_margin']) as num?;

    final locate = (json['locate_required'] ?? false) as bool;

    DateTime? updated;
    final updatedStr = (json['updated_at'] ??
            json['fee_timestamp'] ??
            json['inventory_timestamp'])
        ?.toString();
    if (updatedStr != null && updatedStr.isNotEmpty) {
      try {
        updated = DateTime.parse(updatedStr);
      } catch (_) {}
    }

    return ShortingAvailability(
      instrumentId: id,
      canShort:
          canShortVal == true && inventoryVal != 'NONE' && inventoryVal != '0',
      inventory: inventoryVal,
      borrowFeeRate: feeRate,
      isHardToBorrow: hardToBorrow,
      hardToBorrowReason: reason,
      marginRequirement: marginReq?.toDouble(),
      locateRequired: locate,
      updatedAt: updated,
    );
  }
}

/// Squeeze Risk Classification based on short float, days to cover, and borrow fees
enum ShortSqueezeRisk {
  low,
  moderate,
  elevated,
  high,
  extreme;

  String get label {
    switch (this) {
      case ShortSqueezeRisk.low:
        return 'Low Squeeze Risk';
      case ShortSqueezeRisk.moderate:
        return 'Moderate Squeeze Risk';
      case ShortSqueezeRisk.elevated:
        return 'Elevated Squeeze Risk';
      case ShortSqueezeRisk.high:
        return 'High Squeeze Risk';
      case ShortSqueezeRisk.extreme:
        return 'Extreme Squeeze Risk';
    }
  }

  String get shortLabel {
    switch (this) {
      case ShortSqueezeRisk.low:
        return 'Low';
      case ShortSqueezeRisk.moderate:
        return 'Moderate';
      case ShortSqueezeRisk.elevated:
        return 'Elevated';
      case ShortSqueezeRisk.high:
        return 'High';
      case ShortSqueezeRisk.extreme:
        return 'Extreme';
    }
  }

  Color get color {
    switch (this) {
      case ShortSqueezeRisk.low:
        return Colors.green;
      case ShortSqueezeRisk.moderate:
        return Colors.blue;
      case ShortSqueezeRisk.elevated:
        return Colors.orange;
      case ShortSqueezeRisk.high:
        return Colors.deepOrange;
      case ShortSqueezeRisk.extreme:
        return Colors.red;
    }
  }

  String get description {
    switch (this) {
      case ShortSqueezeRisk.low:
        return 'Minimal short exposure. Unlikely to trigger a forced short covering squeeze.';
      case ShortSqueezeRisk.moderate:
        return 'Normal short interest levels. Moderate covering pressure on positive catalysts.';
      case ShortSqueezeRisk.elevated:
        return 'Above-average short float or days to cover. Catalysts may cause sharp short-covering moves.';
      case ShortSqueezeRisk.high:
        return 'Heavily shorted with high borrow costs or days to cover. Significant short squeeze vulnerability.';
      case ShortSqueezeRisk.extreme:
        return 'Extreme short congestion and borrow scarcity. Rapid, volatile short squeezes are highly probable on volume spikes.';
    }
  }
}

/// Borrow Cost Classification
enum BorrowCostLevel {
  easyToBorrow,
  moderate,
  elevated,
  high;

  String get label {
    switch (this) {
      case BorrowCostLevel.easyToBorrow:
        return 'Easy to Borrow';
      case BorrowCostLevel.moderate:
        return 'Moderate Fee';
      case BorrowCostLevel.elevated:
        return 'Elevated Fee';
      case BorrowCostLevel.high:
        return 'Hard to Borrow';
    }
  }

  Color get color {
    switch (this) {
      case BorrowCostLevel.easyToBorrow:
        return Colors.green;
      case BorrowCostLevel.moderate:
        return Colors.blue;
      case BorrowCostLevel.elevated:
        return Colors.orange;
      case BorrowCostLevel.high:
        return Colors.red;
    }
  }
}

/// Consolidated Summary of Short Interest and Live Shorting Availability
@immutable
class ShortInterestSummary {
  final ShortInterest? shortInterest;
  final ShortingAvailability? availability;
  final String instrumentId;
  final String? symbol;

  const ShortInterestSummary({
    required this.instrumentId,
    this.symbol,
    this.shortInterest,
    this.availability,
  });

  bool get hasData => shortInterest != null || availability != null;

  /// Computes Short Squeeze Risk Level
  ShortSqueezeRisk get squeezeRisk {
    final floatPct = shortInterest?.freeFloatPercentage;
    final dtc = shortInterest?.daysToCover ?? 0.0;
    final isHtb = availability?.isHardToBorrow ?? false;
    final feeRatePct = availability?.borrowFeeRatePercentage ?? 0.0;

    int riskScore = 0;

    // Float percentage scoring
    if (floatPct != null) {
      if (floatPct >= 35.0) {
        riskScore += 4;
      } else if (floatPct >= 20.0) {
        riskScore += 3;
      } else if (floatPct >= 10.0) {
        riskScore += 2;
      } else if (floatPct >= 5.0) {
        riskScore += 1;
      }
    }

    // Days to cover scoring (liquidity risk)
    if (dtc >= 8.0) {
      riskScore += 2;
    } else if (dtc >= 4.0) {
      riskScore += 1;
    }

    // Borrow scarcity scoring
    final inventory = (availability?.inventory ?? '').toUpperCase();
    final isLowInventory = inventory == 'LOW' ||
        inventory == '<10K' ||
        inventory == '<100K' ||
        inventory == '0';

    if (isHtb || feeRatePct >= 15.0) {
      riskScore += 2;
    } else if (feeRatePct >= 5.0 || isLowInventory) {
      riskScore += 1;
    }

    if (riskScore >= 6) {
      return ShortSqueezeRisk.extreme;
    } else if (riskScore >= 4) {
      return ShortSqueezeRisk.high;
    } else if (riskScore >= 3) {
      return ShortSqueezeRisk.elevated;
    } else if (riskScore >= 1) {
      return ShortSqueezeRisk.moderate;
    }
    return ShortSqueezeRisk.low;
  }

  /// Categorizes borrow cost level
  BorrowCostLevel get borrowCostLevel {
    final feePct = availability?.borrowFeeRatePercentage ?? 0.0;
    final isHtb = availability?.isHardToBorrow ?? false;

    if (isHtb || feePct >= 15.0) {
      return BorrowCostLevel.high;
    } else if (feePct >= 5.0) {
      return BorrowCostLevel.elevated;
    } else if (feePct >= 1.0) {
      return BorrowCostLevel.moderate;
    }
    return BorrowCostLevel.easyToBorrow;
  }

  factory ShortInterestSummary.fromResponses({
    dynamic shortInterestResponse,
    dynamic shortingAvailabilityResponse,
    required String instrumentId,
    String? symbol,
    num? fallbackAverageDailyVolume,
    num? fallbackFreeFloat,
  }) {
    ShortInterest? interest;
    if (shortInterestResponse != null) {
      if (shortInterestResponse is Map<String, dynamic>) {
        interest = ShortInterest.fromJson(
          shortInterestResponse,
          fallbackInstrumentId: instrumentId,
          fallbackSymbol: symbol,
          fallbackAverageDailyVolume: fallbackAverageDailyVolume,
          fallbackFreeFloat: fallbackFreeFloat,
        );
      } else if (shortInterestResponse is List &&
          shortInterestResponse.isNotEmpty &&
          shortInterestResponse.first is Map<String, dynamic>) {
        interest = ShortInterest.fromJson(
          shortInterestResponse.first as Map<String, dynamic>,
          fallbackInstrumentId: instrumentId,
          fallbackSymbol: symbol,
          fallbackAverageDailyVolume: fallbackAverageDailyVolume,
          fallbackFreeFloat: fallbackFreeFloat,
        );
      }
    }

    ShortingAvailability? avail;
    if (shortingAvailabilityResponse != null &&
        shortingAvailabilityResponse is Map<String, dynamic>) {
      avail = ShortingAvailability.fromJson(
        shortingAvailabilityResponse,
        fallbackInstrumentId: instrumentId,
      );
    }

    return ShortInterestSummary(
      instrumentId: instrumentId,
      symbol: symbol,
      shortInterest: interest,
      availability: avail,
    );
  }
}
