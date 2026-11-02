import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

enum WashSaleStatus {
  activeWindow,
  disallowed,
  cleared;

  static WashSaleStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'disallowed':
        return WashSaleStatus.disallowed;
      case 'cleared':
        return WashSaleStatus.cleared;
      case 'activewindow':
      case 'active_window':
      case 'active':
      default:
        return WashSaleStatus.activeWindow;
    }
  }

  String get label {
    switch (this) {
      case WashSaleStatus.activeWindow:
        return 'Active Window';
      case WashSaleStatus.disallowed:
        return 'Loss Disallowed';
      case WashSaleStatus.cleared:
        return 'Window Cleared';
    }
  }
}

class WashSaleRecord {
  final String id;
  final String symbol;
  final String name;
  final String assetType; // 'stock' or 'option'
  final DateTime saleDate;
  final double salePrice;
  final double quantitySold;
  final double realizedLoss; // Negative value (e.g. -450.0)
  final DateTime windowStartDate; // saleDate - 30 days
  final DateTime windowEndDate; // saleDate + 30 days
  final WashSaleStatus status;

  // Replacement details if wash sale triggered
  final DateTime? replacementDate;
  final double? replacementPrice;
  final double? replacementQuantity;
  final String? replacementAssetType;
  final double? disallowedLoss; // Positive amount of loss disallowed
  final double? adjustedCostBasis; // Replacement cost basis + disallowed loss

  // Cross-account provenance & IRS Rev. Rul. 2008-5
  final String? saleAccountId;
  final String? saleAccountType; // 'taxable', 'traditional_ira', 'roth_ira'
  final String? replacementAccountId;
  final String? replacementAccountType;
  final bool
      isPermanentIraDisallowance; // True if taxable sale + IRA purchase (permanent loss)

  const WashSaleRecord({
    required this.id,
    required this.symbol,
    required this.name,
    required this.assetType,
    required this.saleDate,
    required this.salePrice,
    required this.quantitySold,
    required this.realizedLoss,
    required this.windowStartDate,
    required this.windowEndDate,
    required this.status,
    this.replacementDate,
    this.replacementPrice,
    this.replacementQuantity,
    this.replacementAssetType,
    this.disallowedLoss,
    this.adjustedCostBasis,
    this.saleAccountId,
    this.saleAccountType,
    this.replacementAccountId,
    this.replacementAccountType,
    this.isPermanentIraDisallowance = false,
  });

  /// Calculates days remaining in the 30-day post-sale window.
  int getDaysRemaining([DateTime? asOf]) {
    final now = asOf ?? DateTime.now();
    if (now.isAfter(windowEndDate)) return 0;
    return windowEndDate.difference(now).inDays + 1;
  }

  bool isWindowActive([DateTime? asOf]) {
    if (status == WashSaleStatus.disallowed) return false;
    return getDaysRemaining(asOf) > 0;
  }

  bool get isDisallowed => status == WashSaleStatus.disallowed;

  bool isCleared([DateTime? asOf]) {
    if (status == WashSaleStatus.cleared) return true;
    if (status == WashSaleStatus.disallowed) return false;
    return getDaysRemaining(asOf) <= 0;
  }

  /// First date when it is safe to repurchase without IRS Section 1091 penalty.
  DateTime get safeRepurchaseDate => windowEndDate.add(const Duration(days: 1));

  bool get isCrossAccount =>
      saleAccountId != null &&
      replacementAccountId != null &&
      saleAccountId != replacementAccountId;

  String get taxConsequenceDescription {
    if (isPermanentIraDisallowance) {
      return 'Permanent Loss Disallowed (IRS Rev. Rul. 2008-5). Basis not adjusted in IRA.';
    }
    if (isDisallowed) {
      return 'Loss Disallowed (IRC §1091). Basis added to replacement.';
    }
    if (isWindowActive()) {
      return 'Active 30-Day Restriction Window';
    }
    return 'Window Cleared';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'name': name,
        'asset_type': assetType,
        'sale_date': saleDate.toIso8601String(),
        'sale_price': salePrice,
        'quantity_sold': quantitySold,
        'realized_loss': realizedLoss,
        'window_start_date': windowStartDate.toIso8601String(),
        'window_end_date': windowEndDate.toIso8601String(),
        'status': status.name,
        'replacement_date': replacementDate?.toIso8601String(),
        'replacement_price': replacementPrice,
        'replacement_quantity': replacementQuantity,
        'replacement_asset_type': replacementAssetType,
        'disallowed_loss': disallowedLoss,
        'adjusted_cost_basis': adjustedCostBasis,
        'sale_account_id': saleAccountId,
        'sale_account_type': saleAccountType,
        'replacement_account_id': replacementAccountId,
        'replacement_account_type': replacementAccountType,
        'is_permanent_ira_disallowance': isPermanentIraDisallowance,
      };

  factory WashSaleRecord.fromJson(dynamic json) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final saleDt =
        parseDate(json['sale_date'] ?? json['saleDate'], DateTime.now());
    final windowStartDt = parseDate(
        json['window_start_date'] ?? json['windowStartDate'],
        saleDt.subtract(const Duration(days: 30)));
    final windowEndDt = parseDate(
        json['window_end_date'] ?? json['windowEndDate'],
        saleDt.add(const Duration(days: 30)));

    return WashSaleRecord(
      id: json['id']?.toString() ?? '',
      symbol: (json['symbol'] ?? '').toString().toUpperCase(),
      name: json['name']?.toString() ?? '',
      assetType: json['asset_type']?.toString() ??
          json['assetType']?.toString() ??
          'stock',
      saleDate: saleDt,
      salePrice: parseDouble(json['sale_price'] ?? json['salePrice']) ?? 0.0,
      quantitySold:
          parseDouble(json['quantity_sold'] ?? json['quantitySold']) ?? 0.0,
      realizedLoss:
          parseDouble(json['realized_loss'] ?? json['realizedLoss']) ?? 0.0,
      windowStartDate: windowStartDt,
      windowEndDate: windowEndDt,
      status: WashSaleStatus.fromString(json['status']?.toString()),
      replacementDate: parseNullableDate(
          json['replacement_date'] ?? json['replacementDate']),
      replacementPrice:
          parseDouble(json['replacement_price'] ?? json['replacementPrice']),
      replacementQuantity: parseDouble(
          json['replacement_quantity'] ?? json['replacementQuantity']),
      replacementAssetType: json['replacement_asset_type']?.toString() ??
          json['replacementAssetType']?.toString(),
      disallowedLoss:
          parseDouble(json['disallowed_loss'] ?? json['disallowedLoss']),
      adjustedCostBasis:
          parseDouble(json['adjusted_cost_basis'] ?? json['adjustedCostBasis']),
      saleAccountId: json['sale_account_id']?.toString() ??
          json['saleAccountId']?.toString(),
      saleAccountType: json['sale_account_type']?.toString() ??
          json['saleAccountType']?.toString(),
      replacementAccountId: json['replacement_account_id']?.toString() ??
          json['replacementAccountId']?.toString(),
      replacementAccountType: json['replacement_account_type']?.toString() ??
          json['replacementAccountType']?.toString(),
      isPermanentIraDisallowance:
          json['is_permanent_ira_disallowance'] == true ||
              json['isPermanentIraDisallowance'] == true,
    );
  }
}

/// Represents an inline pre-trade wash sale evaluation result for order tickets.
class PreTradeWashSaleRisk {
  final String symbol;
  final bool hasRisk;
  final bool isPermanentIraDisallowance;
  final int daysRemaining;
  final DateTime? safeRepurchaseDate;
  final double? potentialDisallowedLoss;
  final String severity; // 'critical' or 'warning'
  final String headline;
  final String details;
  final String? sourceAccountId;
  final String? destinationAccountId;

  const PreTradeWashSaleRisk({
    required this.symbol,
    required this.hasRisk,
    this.isPermanentIraDisallowance = false,
    this.daysRemaining = 0,
    this.safeRepurchaseDate,
    this.potentialDisallowedLoss,
    this.severity = 'warning',
    required this.headline,
    required this.details,
    this.sourceAccountId,
    this.destinationAccountId,
  });
}
