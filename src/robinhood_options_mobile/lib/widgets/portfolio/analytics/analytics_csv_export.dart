import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/return_attribution.dart';
import 'package:share_plus/share_plus.dart';

/// Exports the aligned portfolio/benchmark series plus the scalar metrics.
class AnalyticsCsvExport {
  const AnalyticsCsvExport._();

  static Future<void> share(
    BuildContext context,
    Map<String, dynamic> metrics, {
    required String benchmarkSymbol,
    BrinsonAttributionResult? brinsonAttribution,
    OptionsAttributionResult? optionsAttribution,
    Rect? sharePositionOrigin,
  }) async {
    final rows = buildRows(
      metrics,
      benchmarkSymbol: benchmarkSymbol,
      brinsonAttribution: brinsonAttribution,
      optionsAttribution: optionsAttribution,
    );

    if (rows == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export.')),
      );
      return;
    }

    final file = XFile.fromData(
      utf8.encode(Csv().encode(rows)),
      mimeType: 'text/csv',
      name: 'portfolio_analytics_'
          '${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        text: 'Portfolio Analytics Export',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Builds the CSV rows, or returns null when there is no series to export.
  ///
  /// Attribution sections are appended only when supplied. Effects and
  /// weights are written as decimal fractions, matching the return columns.
  static List<List<dynamic>>? buildRows(
    Map<String, dynamic> metrics, {
    required String benchmarkSymbol,
    BrinsonAttributionResult? brinsonAttribution,
    OptionsAttributionResult? optionsAttribution,
  }) {
    final dates = metrics['alignedDates'] as List<DateTime>?;
    final portfolioPrices = metrics['alignedPortfolioPrices'] as List<double>?;
    final benchmarkPrices = metrics['alignedBenchmarkPrices'] as List<double>?;

    if (dates == null || portfolioPrices == null || benchmarkPrices == null) {
      return null;
    }

    final rows = <List<dynamic>>[
      [
        'Date',
        'Portfolio Value',
        '$benchmarkSymbol Value',
        'Portfolio Return %',
        'Benchmark Return %',
        'Excess Return %',
      ],
    ];

    final portfolioBase =
        portfolioPrices.isNotEmpty ? portfolioPrices.first : 1.0;
    final benchmarkBase =
        benchmarkPrices.isNotEmpty ? benchmarkPrices.first : 1.0;
    final dateFormat = DateFormat('yyyy-MM-dd');

    for (var i = 0; i < dates.length; i++) {
      final portfolioReturn = (portfolioPrices[i] / portfolioBase) - 1.0;
      final benchmarkReturn = (benchmarkPrices[i] / benchmarkBase) - 1.0;
      rows.add([
        dateFormat.format(dates[i]),
        portfolioPrices[i],
        benchmarkPrices[i],
        portfolioReturn,
        benchmarkReturn,
        portfolioReturn - benchmarkReturn,
      ]);
    }

    rows.add([]);
    rows.add(['Metric', 'Value']);
    metrics.forEach((key, value) {
      if (value is num) rows.add([key, value]);
    });

    final brinson = brinsonAttribution;
    if (brinson != null && !brinson.isEmpty) {
      rows.add([]);
      rows.add([
        'Sector Attribution (Brinson-Fachler) vs ${brinson.benchmarkSymbol}',
        brinson.windowLabel,
      ]);
      rows.add([
        'Sector',
        'Portfolio Weight',
        'Benchmark Weight',
        'Portfolio Return',
        'Benchmark Return',
        'Allocation Effect',
        'Selection Effect',
        'Interaction Effect',
        'Total Effect',
      ]);
      for (final r in brinson.sectorAttributions) {
        rows.add([
          r.sector,
          r.portfolioWeight,
          r.benchmarkWeight,
          r.portfolioReturn,
          r.benchmarkReturn,
          r.allocationEffect,
          r.selectionEffect,
          r.interactionEffect,
          r.totalEffect,
        ]);
      }
      rows.add([
        'Total',
        1.0,
        1.0,
        brinson.totalPortfolioReturn,
        brinson.totalBenchmarkReturn,
        brinson.totalAllocationEffect,
        brinson.totalSelectionEffect,
        brinson.totalInteractionEffect,
        brinson.activeReturn,
      ]);
    }

    final options = optionsAttribution;
    if (options != null && !options.isEmpty) {
      rows.add([]);
      rows.add(['Options Greeks P&L Attribution', options.windowLabel]);
      rows.add(['Component', 'P&L']);
      rows.add(['Delta P&L', options.totalDeltaPnL]);
      rows.add(['Gamma P&L', options.totalGammaPnL]);
      rows.add(['Theta P&L', options.totalThetaPnL]);
      rows.add(['Vega P&L (implied)', options.totalVegaPnL]);
      rows.add(['Residual P&L', options.totalResidualPnL]);
      rows.add(['Income/Yield P&L', options.totalIncomePnL]);
      rows.add(['Total Options P&L', options.totalOptionPnL]);
      rows.add(['Total incl. Income', options.totalPnL]);
      rows.add(['Note', OptionsAttributionResult.disclaimer]);
    }

    return rows;
  }
}
