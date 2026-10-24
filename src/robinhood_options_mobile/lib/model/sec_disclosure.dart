import 'package:intl/intl.dart';

class SecDisclosureHolding {
  final String issuerName;
  final double shares;
  final double valueThousands;

  const SecDisclosureHolding({
    required this.issuerName,
    required this.shares,
    required this.valueThousands,
  });

  factory SecDisclosureHolding.fromJson(Map<String, dynamic> json) {
    return SecDisclosureHolding(
      issuerName: (json['issuerName'] ?? '').toString(),
      shares: _asDouble(json['shares']),
      valueThousands: _asDouble(json['valueThousands']),
    );
  }
}

class SecFinancialStatementSnapshot {
  final int? fiscalYear;
  final String? fiscalPeriod;
  final String? form;
  final DateTime? filedAt;
  final String? periodEnd;
  final double? revenue;
  final double? revenueGrowthYoY;
  final double? netIncome;
  final double? netMargin;
  final double? dilutedEps;
  final double? operatingIncome;
  final double? operatingMargin;
  final double? operatingCashFlow;
  final double? totalAssets;
  final double? totalLiabilities;
  final double? stockholdersEquity;
  final double? cashAndEquivalents;
  final double? debtToEquity;

  const SecFinancialStatementSnapshot({
    this.fiscalYear,
    this.fiscalPeriod,
    this.form,
    this.filedAt,
    this.periodEnd,
    this.revenue,
    this.revenueGrowthYoY,
    this.netIncome,
    this.netMargin,
    this.dilutedEps,
    this.operatingIncome,
    this.operatingMargin,
    this.operatingCashFlow,
    this.totalAssets,
    this.totalLiabilities,
    this.stockholdersEquity,
    this.cashAndEquivalents,
    this.debtToEquity,
  });

  factory SecFinancialStatementSnapshot.fromJson(Map<String, dynamic> json) {
    return SecFinancialStatementSnapshot(
      fiscalYear: _asInt(json['fiscalYear']),
      fiscalPeriod: _asNullableString(json['fiscalPeriod']),
      form: _asNullableString(json['form']),
      filedAt: json['filedAt'] != null
          ? DateTime.tryParse(json['filedAt'].toString())
          : null,
      periodEnd: _asNullableString(json['periodEnd']),
      revenue: _asNullableDouble(json['revenue']),
      revenueGrowthYoY: _asNullableDouble(json['revenueGrowthYoY']),
      netIncome: _asNullableDouble(json['netIncome']),
      netMargin: _asNullableDouble(json['netMargin']),
      dilutedEps: _asNullableDouble(json['dilutedEps']),
      operatingIncome: _asNullableDouble(json['operatingIncome']),
      operatingMargin: _asNullableDouble(json['operatingMargin']),
      operatingCashFlow: _asNullableDouble(json['operatingCashFlow']),
      totalAssets: _asNullableDouble(json['totalAssets']),
      totalLiabilities: _asNullableDouble(json['totalLiabilities']),
      stockholdersEquity: _asNullableDouble(json['stockholdersEquity']),
      cashAndEquivalents: _asNullableDouble(json['cashAndEquivalents']),
      debtToEquity: _asNullableDouble(json['debtToEquity']),
    );
  }

  String get periodLabel {
    final parts = <String>[
      if (fiscalPeriod != null && fiscalPeriod!.isNotEmpty) fiscalPeriod!,
      if (fiscalYear != null) '$fiscalYear',
    ];
    final base = parts.join(' ');
    if (form != null && form!.isNotEmpty) {
      return base.isNotEmpty ? '$base ($form)' : form!;
    }
    return base.isNotEmpty ? base : 'Latest Period';
  }
}

class SecFilingResearchBrief {
  final String symbol;
  final DateTime generatedAt;
  final String headline;
  final String overallTone;
  final List<String> financialHighlights;
  final String insiderActivitySummary;
  final String materialEventsSummary;
  final String institutionalSummary;
  final List<String> riskFactors;
  final String? answer;

  const SecFilingResearchBrief({
    required this.symbol,
    required this.generatedAt,
    required this.headline,
    required this.overallTone,
    this.financialHighlights = const [],
    required this.insiderActivitySummary,
    required this.materialEventsSummary,
    required this.institutionalSummary,
    this.riskFactors = const [],
    this.answer,
  });

  factory SecFilingResearchBrief.fromJson(Map<String, dynamic> json) {
    return SecFilingResearchBrief(
      symbol: (json['symbol'] ?? '').toString(),
      generatedAt: DateTime.tryParse((json['generatedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      headline: (json['headline'] ?? '').toString(),
      overallTone: (json['overallTone'] ?? 'neutral').toString(),
      financialHighlights: _asStringList(json['financialHighlights']),
      insiderActivitySummary: (json['insiderActivitySummary'] ?? '').toString(),
      materialEventsSummary: (json['materialEventsSummary'] ?? '').toString(),
      institutionalSummary: (json['institutionalSummary'] ?? '').toString(),
      riskFactors: _asStringList(json['riskFactors']),
      answer: _asNullableString(json['answer']),
    );
  }

  /// Synthesizes a local research brief from a [SecDisclosureSnapshot] and optional question.
  factory SecFilingResearchBrief.fromSnapshot(
    SecDisclosureSnapshot snapshot, {
    String? question,
  }) {
    final compactUsd =
        NumberFormat.compactSimpleCurrency(name: 'USD', decimalDigits: 1);
    final financials = snapshot.financials;
    final disclosures = snapshot.disclosures;
    final cleanSymbol = snapshot.symbol.trim().toUpperCase();
    final financialHighlights = <String>[];
    final riskFactors = <String>[];
    var toneScore = 0;

    if (financials != null) {
      final periodTag = [
        if (financials.fiscalPeriod != null) financials.fiscalPeriod!,
        if (financials.fiscalYear != null) '${financials.fiscalYear}',
      ].join(' ');
      if (financials.revenue != null) {
        final growth = financials.revenueGrowthYoY;
        final growthStr = growth != null
            ? ' (${growth >= 0 ? "+" : ""}${growth.toStringAsFixed(1)}% YoY)'
            : '';
        financialHighlights.add(
          'Revenue${periodTag.isNotEmpty ? " ($periodTag)" : ""}: '
          '${compactUsd.format(financials.revenue)}$growthStr',
        );
        if ((growth ?? 0) >= 10) toneScore += 1;
        if ((growth ?? 0) < 0) toneScore -= 1;
      }
      if (financials.netIncome != null) {
        final margin = financials.netMargin;
        final marginStr = margin != null
            ? ' (${margin.toStringAsFixed(1)}% net margin)'
            : '';
        financialHighlights.add(
          'Net Income: ${compactUsd.format(financials.netIncome)}$marginStr',
        );
        if (financials.netIncome! > 0) toneScore += 1;
        if (financials.netIncome! < 0) {
          toneScore -= 1;
          riskFactors.add(
            'Negative net income (${compactUsd.format(financials.netIncome)}) '
            'in latest parsed period',
          );
        }
      }
      if (financials.dilutedEps != null) {
        financialHighlights.add(
          'Diluted EPS: \$${financials.dilutedEps!.toStringAsFixed(2)}',
        );
      }
      if (financials.operatingCashFlow != null) {
        financialHighlights.add(
          'Operating Cash Flow: '
          '${compactUsd.format(financials.operatingCashFlow)}',
        );
      }
      if (financials.cashAndEquivalents != null ||
          financials.debtToEquity != null) {
        final parts = <String>[];
        if (financials.cashAndEquivalents != null) {
          parts.add('Cash: ${compactUsd.format(financials.cashAndEquivalents)}');
        }
        if (financials.debtToEquity != null) {
          parts.add(
            'Liabilities/Equity: ${financials.debtToEquity!.toStringAsFixed(2)}x',
          );
          if (financials.debtToEquity! > 2.5) {
            riskFactors.add(
              'Elevated leverage (Liabilities/Equity '
              '${financials.debtToEquity!.toStringAsFixed(2)}x)',
            );
          }
        }
        financialHighlights.add(parts.join(' · '));
      }
    }

    for (final filing in disclosures.where(
      (d) => d.form == '10-K' || d.form == '10-Q',
    )) {
      for (final risk in filing.riskHighlights) {
        if (!riskFactors.contains(risk)) riskFactors.add(risk);
      }
      for (final mda in filing.mdaHighlights) {
        if (!financialHighlights.contains(mda)) financialHighlights.add(mda);
      }
    }

    final form4s = disclosures.where((d) => d.form == '4').toList();
    final totalBuys = form4s.fold<int>(
      0,
      (sum, d) => sum + (d.openMarketBuyCount ?? 0),
    );
    final totalSells = form4s.fold<int>(
      0,
      (sum, d) => sum + (d.openMarketSellCount ?? 0),
    );
    final buyCluster = form4s.fold<int>(
      0,
      (maxVal, d) => (d.insiderClusterCount ?? 0) > maxVal
          ? (d.insiderClusterCount ?? 0)
          : maxVal,
    );
    final sellCluster = form4s.fold<int>(
      0,
      (maxVal, d) => (d.insiderSellClusterCount ?? 0) > maxVal
          ? (d.insiderSellClusterCount ?? 0)
          : maxVal,
    );

    final String insiderActivitySummary;
    if (form4s.isEmpty) {
      insiderActivitySummary = 'No recent Form 4 insider transactions filed.';
    } else {
      final clusterNotes = <String>[];
      if (buyCluster > 1) {
        clusterNotes.add('$buyCluster distinct buyers in 30d');
        toneScore += 1;
      }
      if (sellCluster > 1) {
        clusterNotes.add('$sellCluster distinct sellers in 30d');
        toneScore -= 1;
        riskFactors.add(
          'Insider selling cluster: $sellCluster insiders sold within 30 days',
        );
      }
      final suffix =
          clusterNotes.isNotEmpty ? ' (${clusterNotes.join(", ")})' : '';
      insiderActivitySummary =
          '${form4s.length} Form 4 filing${form4s.length == 1 ? "" : "s"}: '
          '$totalBuys open-market buy${totalBuys == 1 ? "" : "s"}, '
          '$totalSells open-market sale${totalSells == 1 ? "" : "s"}$suffix.';
    }

    final eightKs = disclosures.where((d) => d.form == '8-K').toList();
    final String materialEventsSummary;
    if (eightKs.isEmpty) {
      materialEventsSummary = 'No recent Form 8-K material events filed.';
    } else {
      final allItems = eightKs.expand((d) => d.itemCodes).toSet().toList()
        ..sort();
      final hasCritical =
          eightKs.any((d) => d.materialEventSeverity == 'critical');
      final hasWarning =
          eightKs.any((d) => d.materialEventSeverity == 'warning');
      if (hasCritical) {
        toneScore -= 2;
        riskFactors.add(
          'Critical Form 8-K disclosure filed (Items ${allItems.join(", ")})',
        );
      } else if (hasWarning) {
        toneScore -= 1;
      }
      materialEventsSummary =
          '${eightKs.length} recent Form 8-K filing${eightKs.length == 1 ? "" : "s"}'
          '${allItems.isNotEmpty ? " covering Items ${allItems.join(", ")}." : "."}';
    }

    final thirteenFs = disclosures.where((d) => d.form == '13F-HR').toList();
    final totalInstShares = thirteenFs.fold<double>(
      0,
      (sum, d) =>
          sum + d.holdings.fold<double>(0, (hSum, h) => hSum + h.shares),
    );
    final institutionalSummary = thirteenFs.isNotEmpty
        ? '${thirteenFs.length} institutional 13F-HR filing${thirteenFs.length == 1 ? "" : "s"} '
            'reporting ${NumberFormat.compact().format(totalInstShares)} aggregate shares.'
        : 'No recent 13F-HR institutional filings matched in current window.';

    String overallTone = 'neutral';
    if (toneScore >= 2) {
      overallTone = 'bullish';
    } else if (toneScore <= -2) {
      overallTone = 'bearish';
    } else if (toneScore < 0) {
      overallTone = 'cautious';
    }

    final headline = '$cleanSymbol SEC Filing Brief: '
        '${financialHighlights.isNotEmpty ? financialHighlights.first : "${disclosures.length} recent filings"} · '
        'Tone: ${overallTone.toUpperCase()}';

    String? answer;
    final trimmedQ = (question ?? '').trim();
    if (trimmedQ.isNotEmpty) {
      final qLower = trimmedQ.toLowerCase();
      if (RegExp(r'(revenue|margin|eps|income|cash|debt|10-k|10-q|financial)')
          .hasMatch(qLower)) {
        answer = financialHighlights.isNotEmpty
            ? '10-K/10-Q Financial Analysis for $cleanSymbol: '
                '${financialHighlights.join("; ")}.'
            : 'No XBRL 10-K/10-Q financial statement facts are cached for $cleanSymbol yet.';
      } else if (RegExp(r'(insider|form 4|buy|sell|cluster|officer)')
          .hasMatch(qLower)) {
        answer =
            'Insider Trading Analysis for $cleanSymbol: $insiderActivitySummary';
      } else if (RegExp(r'(8-k|catalyst|material|event|risk)')
          .hasMatch(qLower)) {
        final riskStr = riskFactors.isNotEmpty
            ? ' Key Risks: ${riskFactors.join("; ")}.'
            : ' No critical risk flags triggered.';
        answer =
            'Material Events & Risk Factors for $cleanSymbol: $materialEventsSummary$riskStr';
      } else if (RegExp(r'(13f|institution|whale|fund|ownership)')
          .hasMatch(qLower)) {
        answer =
            'Institutional 13F Ownership for $cleanSymbol: $institutionalSummary';
      } else {
        answer = '$headline. $insiderActivitySummary $materialEventsSummary'
            '${riskFactors.isNotEmpty ? " Risks noted: ${riskFactors.join("; ")}." : ""}';
      }
    }

    return SecFilingResearchBrief(
      symbol: cleanSymbol,
      generatedAt: snapshot.updatedAt,
      headline: headline,
      overallTone: overallTone,
      financialHighlights: financialHighlights,
      insiderActivitySummary: insiderActivitySummary,
      materialEventsSummary: materialEventsSummary,
      institutionalSummary: institutionalSummary,
      riskFactors: riskFactors,
      answer: answer,
    );
  }
}

class SecDisclosure {
  final String accessionNumber;
  final String form;
  final DateTime filedAt;
  final String companyName;
  final String title;
  final String summary;
  final String url;
  final List<String> symbols;
  final List<String> reportingOwners;
  final List<String> officerTitles;
  final int? transactionCount;
  final int? openMarketBuyCount;
  final int? openMarketSellCount;
  final int? insiderClusterCount;
  final int? insiderSellClusterCount;
  final double? netSharesTransacted;
  final double? netTransactionValue;
  final List<String> itemCodes;
  final List<String> itemDescriptions;
  final String? materialEventSeverity;
  final String? fiscalPeriod;
  final List<String> riskHighlights;
  final List<String> mdaHighlights;
  final List<SecDisclosureHolding> holdings;

  const SecDisclosure({
    required this.accessionNumber,
    required this.form,
    required this.filedAt,
    required this.companyName,
    required this.title,
    required this.summary,
    required this.url,
    required this.symbols,
    this.reportingOwners = const [],
    this.officerTitles = const [],
    this.transactionCount,
    this.openMarketBuyCount,
    this.openMarketSellCount,
    this.insiderClusterCount,
    this.insiderSellClusterCount,
    this.netSharesTransacted,
    this.netTransactionValue,
    this.itemCodes = const [],
    this.itemDescriptions = const [],
    this.materialEventSeverity,
    this.fiscalPeriod,
    this.riskHighlights = const [],
    this.mdaHighlights = const [],
    this.holdings = const [],
  });

  factory SecDisclosure.fromJson(Map<String, dynamic> json) {
    return SecDisclosure(
      accessionNumber: (json['accessionNumber'] ?? '').toString(),
      form: (json['form'] ?? '').toString(),
      filedAt: DateTime.tryParse((json['filedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      companyName: (json['companyName'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      symbols: _asStringList(json['symbols']),
      reportingOwners: _asStringList(json['reportingOwners']),
      officerTitles: _asStringList(json['officerTitles']),
      transactionCount: _asInt(json['transactionCount']),
      openMarketBuyCount: _asInt(json['openMarketBuyCount']),
      openMarketSellCount: _asInt(json['openMarketSellCount']),
      insiderClusterCount: _asInt(json['insiderClusterCount']),
      insiderSellClusterCount: _asInt(json['insiderSellClusterCount']),
      netSharesTransacted: _asNullableDouble(json['netSharesTransacted']),
      netTransactionValue: _asNullableDouble(json['netTransactionValue']),
      itemCodes: _asStringList(json['itemCodes']),
      itemDescriptions: _asStringList(json['itemDescriptions']),
      materialEventSeverity: _asNullableString(json['materialEventSeverity']),
      fiscalPeriod: _asNullableString(json['fiscalPeriod']),
      riskHighlights: _asStringList(json['riskHighlights']),
      mdaHighlights: _asStringList(json['mdaHighlights']),
      holdings: _asMapList(json['holdings'])
          .map(SecDisclosureHolding.fromJson)
          .toList(),
    );
  }
}

class SecDisclosureSnapshot {
  final String symbol;
  final List<SecDisclosure> disclosures;
  final SecFinancialStatementSnapshot? financials;
  final SecFilingResearchBrief? researchBrief;
  final bool portfolioOverlap;
  final DateTime updatedAt;

  const SecDisclosureSnapshot({
    required this.symbol,
    required this.disclosures,
    this.financials,
    this.researchBrief,
    required this.portfolioOverlap,
    required this.updatedAt,
  });

  factory SecDisclosureSnapshot.fromJson(Map<String, dynamic> json) {
    final financialsMap = json['financials'];
    final researchBriefMap = json['researchBrief'];
    return SecDisclosureSnapshot(
      symbol: (json['symbol'] ?? '').toString(),
      disclosures:
          _asMapList(json['disclosures']).map(SecDisclosure.fromJson).toList(),
      financials: financialsMap is Map
          ? SecFinancialStatementSnapshot.fromJson(
              Map<String, dynamic>.from(financialsMap),
            )
          : null,
      researchBrief: researchBriefMap is Map
          ? SecFilingResearchBrief.fromJson(
              Map<String, dynamic>.from(researchBriefMap),
            )
          : null,
      portfolioOverlap: json['portfolioOverlap'] == true,
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String? _asNullableString(dynamic value) {
  if (value == null) return null;
  final str = value.toString().trim();
  return str.isEmpty ? null : str;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

List<String> _asStringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList();
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}
