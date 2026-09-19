import 'dart:math';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

/// Represents a single realized disposition row on IRS Form 8949
/// (Sales and Other Dispositions of Capital Assets).
class Form8949Entry {
  final String id;
  final String description; // Column (a): Description of property
  final String symbol;
  final String assetType; // 'stock' or 'option'
  final double quantity;
  final DateTime acquiredDate; // Column (b): Date acquired
  final DateTime soldDate; // Column (c): Date sold or disposed
  final double proceeds; // Column (d): Proceeds (sales price)
  final double costBasis; // Column (e): Cost or other basis
  final String?
      adjustmentCode; // Column (f): Code(s) from instructions ('W', etc.)
  final double adjustmentAmount; // Column (g): Amount of adjustment
  final double gainOrLoss; // Column (h): Gain or loss ((d) - (e) + (g))
  final bool isLongTerm; // Part I (<= 365 days) vs Part II (> 365 days)
  final int holdingDays;
  final String
      boxCategory; // 'A' (Short-term covered) or 'D' (Long-term covered)
  final String? washSaleRecordId;

  const Form8949Entry({
    required this.id,
    required this.description,
    required this.symbol,
    required this.assetType,
    required this.quantity,
    required this.acquiredDate,
    required this.soldDate,
    required this.proceeds,
    required this.costBasis,
    this.adjustmentCode,
    this.adjustmentAmount = 0.0,
    required this.gainOrLoss,
    required this.isLongTerm,
    required this.holdingDays,
    required this.boxCategory,
    this.washSaleRecordId,
  });

  /// Factory constructor to compute holding periods, classification, and reconciled gain/loss.
  factory Form8949Entry.create({
    required String id,
    required String description,
    required String symbol,
    required String assetType,
    required double quantity,
    required DateTime acquiredDate,
    required DateTime soldDate,
    required double proceeds,
    required double costBasis,
    String? adjustmentCode,
    double adjustmentAmount = 0.0,
    String? boxCategory,
    String? washSaleRecordId,
  }) {
    // Normalize to UTC calendar dates to prevent Daylight Saving Time (DST)
    // hour shifts from affecting inDays calculations across different timezones.
    final acqUtc =
        DateTime.utc(acquiredDate.year, acquiredDate.month, acquiredDate.day);
    final soldUtc = DateTime.utc(soldDate.year, soldDate.month, soldDate.day);
    final diff = soldUtc.difference(acqUtc);
    final days = max(0, diff.inDays);
    // Under IRS rules, holding > 1 year (> 365 days) qualifies as long-term (Part II)
    final isLong = days > 365;
    final defaultBox = isLong ? 'D' : 'A';
    // IRS Column (h) = Column (d) Proceeds - Column (e) Cost + Column (g) Adjustment
    final netGainLoss = proceeds - costBasis + adjustmentAmount;

    return Form8949Entry(
      id: id,
      description: description,
      symbol: symbol,
      assetType: assetType,
      quantity: quantity,
      acquiredDate: acquiredDate,
      soldDate: soldDate,
      proceeds: proceeds,
      costBasis: costBasis,
      adjustmentCode: adjustmentCode,
      adjustmentAmount: adjustmentAmount,
      gainOrLoss: netGainLoss,
      isLongTerm: isLong,
      holdingDays: days,
      boxCategory: boxCategory ?? defaultBox,
      washSaleRecordId: washSaleRecordId,
    );
  }

  bool get hasWashSale =>
      adjustmentCode == 'W' && adjustmentAmount.abs() > 0.0001;

  double get tentativeGainOrLoss => proceeds - costBasis;
}

/// Holds subtotal or grand total aggregates for Form 8949 columns
class Form8949Totals {
  final double totalProceeds; // Column (d) sum
  final double totalCostBasis; // Column (e) sum
  final double totalAdjustments; // Column (g) sum
  final double totalGainOrLoss; // Column (h) sum
  final int transactionCount;

  const Form8949Totals({
    required this.totalProceeds,
    required this.totalCostBasis,
    required this.totalAdjustments,
    required this.totalGainOrLoss,
    required this.transactionCount,
  });

  factory Form8949Totals.fromEntries(List<Form8949Entry> entries) {
    double proceeds = 0.0;
    double cost = 0.0;
    double adjustments = 0.0;
    double gainLoss = 0.0;

    for (final e in entries) {
      proceeds += e.proceeds;
      cost += e.costBasis;
      adjustments += e.adjustmentAmount;
      gainLoss += e.gainOrLoss;
    }

    return Form8949Totals(
      totalProceeds: proceeds,
      totalCostBasis: cost,
      totalAdjustments: adjustments,
      totalGainOrLoss: gainLoss,
      transactionCount: entries.length,
    );
  }

  static const zero = Form8949Totals(
    totalProceeds: 0.0,
    totalCostBasis: 0.0,
    totalAdjustments: 0.0,
    totalGainOrLoss: 0.0,
    transactionCount: 0,
  );
}

/// Represents the complete IRS Form 8949 & Schedule D reconciliation
class Form8949Reconciliation {
  final int? taxYear;
  final DateTime generatedAt;
  final List<Form8949Entry> shortTermEntries; // Part I
  final List<Form8949Entry> longTermEntries; // Part II
  final Form8949Totals shortTermTotals;
  final Form8949Totals longTermTotals;
  final Form8949Totals grandTotals;
  final double totalWashSaleDisallowed;

  const Form8949Reconciliation({
    this.taxYear,
    required this.generatedAt,
    required this.shortTermEntries,
    required this.longTermEntries,
    required this.shortTermTotals,
    required this.longTermTotals,
    required this.grandTotals,
    required this.totalWashSaleDisallowed,
  });

  List<Form8949Entry> get allEntries => [
        ...shortTermEntries,
        ...longTermEntries,
      ];

  int get totalTransactions => shortTermEntries.length + longTermEntries.length;

  /// Generates a standardized RFC 4180 CSV string formatted according to
  /// IRS Form 8949 and Schedule D specifications.
  String toCsv() {
    final dateFormat = DateFormat('MM/dd/yyyy');
    final rows = <List<dynamic>>[];

    // File metadata / header
    final yearStr = taxYear != null ? '$taxYear' : 'All Years';
    rows.add(['IRS Form 8949 & Schedule D Reconciliation']);
    rows.add(['Tax Year', yearStr]);
    rows.add([
      'Generated At',
      DateFormat('yyyy-MM-dd HH:mm:ss').format(generatedAt)
    ]);
    rows.add(['Source', 'RealizeAlpha Portfolio & Tax Suite']);
    rows.add([]);

    // --- PART I: SHORT-TERM ---
    rows.add([
      'Part I: Short-Term Capital Gains and Losses - Assets Held One Year or Less (Box A - Covered Securities)'
    ]);
    rows.add([
      '(a) Description of property',
      '(b) Date acquired',
      '(c) Date sold or disposed of',
      '(d) Proceeds (sales price)',
      '(e) Cost or other basis',
      '(f) Code(s) from instructions',
      '(g) Amount of adjustment',
      '(h) Gain or loss',
    ]);

    for (final e in shortTermEntries) {
      rows.add([
        e.description,
        dateFormat.format(e.acquiredDate),
        dateFormat.format(e.soldDate),
        e.proceeds.toStringAsFixed(2),
        e.costBasis.toStringAsFixed(2),
        e.adjustmentCode ?? '',
        e.adjustmentAmount != 0.0 ? e.adjustmentAmount.toStringAsFixed(2) : '',
        e.gainOrLoss.toStringAsFixed(2),
      ]);
    }

    // Part I Subtotal (Form 8949 Line 2 / Schedule D Line 1b)
    rows.add([
      'Totals for Part I (Short-Term)',
      '',
      '',
      shortTermTotals.totalProceeds.toStringAsFixed(2),
      shortTermTotals.totalCostBasis.toStringAsFixed(2),
      '',
      shortTermTotals.totalAdjustments.toStringAsFixed(2),
      shortTermTotals.totalGainOrLoss.toStringAsFixed(2),
    ]);
    rows.add([]);

    // --- PART II: LONG-TERM ---
    rows.add([
      'Part II: Long-Term Capital Gains and Losses - Assets Held More Than One Year (Box D - Covered Securities)'
    ]);
    rows.add([
      '(a) Description of property',
      '(b) Date acquired',
      '(c) Date sold or disposed of',
      '(d) Proceeds (sales price)',
      '(e) Cost or other basis',
      '(f) Code(s) from instructions',
      '(g) Amount of adjustment',
      '(h) Gain or loss',
    ]);

    for (final e in longTermEntries) {
      rows.add([
        e.description,
        dateFormat.format(e.acquiredDate),
        dateFormat.format(e.soldDate),
        e.proceeds.toStringAsFixed(2),
        e.costBasis.toStringAsFixed(2),
        e.adjustmentCode ?? '',
        e.adjustmentAmount != 0.0 ? e.adjustmentAmount.toStringAsFixed(2) : '',
        e.gainOrLoss.toStringAsFixed(2),
      ]);
    }

    // Part II Subtotal (Form 8949 Line 4 / Schedule D Line 8b)
    rows.add([
      'Totals for Part II (Long-Term)',
      '',
      '',
      longTermTotals.totalProceeds.toStringAsFixed(2),
      longTermTotals.totalCostBasis.toStringAsFixed(2),
      '',
      longTermTotals.totalAdjustments.toStringAsFixed(2),
      longTermTotals.totalGainOrLoss.toStringAsFixed(2),
    ]);
    rows.add([]);

    // --- GRAND TOTALS (SCHEDULE D RECONCILIATION) ---
    rows.add([
      'Grand Totals (Schedule D Net Capital Gain/Loss)',
      '',
      '',
      grandTotals.totalProceeds.toStringAsFixed(2),
      grandTotals.totalCostBasis.toStringAsFixed(2),
      '',
      grandTotals.totalAdjustments.toStringAsFixed(2),
      grandTotals.totalGainOrLoss.toStringAsFixed(2),
    ]);
    rows.add([
      'Total Disallowed Wash Sales (Code W)',
      totalWashSaleDisallowed.toStringAsFixed(2),
    ]);

    return Csv().encode(rows);
  }
}
