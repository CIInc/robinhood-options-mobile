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

class SecDisclosure {
  final String accessionNumber;
  final String form;
  final DateTime filedAt;
  final String companyName;
  final String title;
  final String summary;
  final String url;
  final List<String> symbols;
  final int? transactionCount;
  final int? openMarketBuyCount;
  final int? insiderClusterCount;
  final List<String> itemCodes;
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
    this.transactionCount,
    this.openMarketBuyCount,
    this.insiderClusterCount,
    this.itemCodes = const [],
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
      transactionCount: _asInt(json['transactionCount']),
      openMarketBuyCount: _asInt(json['openMarketBuyCount']),
      insiderClusterCount: _asInt(json['insiderClusterCount']),
      itemCodes: _asStringList(json['itemCodes']),
      holdings: _asMapList(json['holdings'])
          .map(SecDisclosureHolding.fromJson)
          .toList(),
    );
  }
}

class SecDisclosureSnapshot {
  final String symbol;
  final List<SecDisclosure> disclosures;
  final bool portfolioOverlap;
  final DateTime updatedAt;

  const SecDisclosureSnapshot({
    required this.symbol,
    required this.disclosures,
    required this.portfolioOverlap,
    required this.updatedAt,
  });

  factory SecDisclosureSnapshot.fromJson(Map<String, dynamic> json) {
    return SecDisclosureSnapshot(
      symbol: (json['symbol'] ?? '').toString(),
      disclosures:
          _asMapList(json['disclosures']).map(SecDisclosure.fromJson).toList(),
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
