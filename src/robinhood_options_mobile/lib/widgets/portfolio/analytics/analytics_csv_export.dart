import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// Exports the aligned portfolio/benchmark series plus the scalar metrics.
class AnalyticsCsvExport {
  const AnalyticsCsvExport._();

  static Future<void> share(
    BuildContext context,
    Map<String, dynamic> metrics, {
    required String benchmarkSymbol,
    Rect? sharePositionOrigin,
  }) async {
    final dates = metrics['alignedDates'] as List<DateTime>?;
    final portfolioPrices = metrics['alignedPortfolioPrices'] as List<double>?;
    final benchmarkPrices = metrics['alignedBenchmarkPrices'] as List<double>?;

    if (dates == null || portfolioPrices == null || benchmarkPrices == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export.')),
      );
      return;
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
}
