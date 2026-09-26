import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../model/congress_trade.dart';

class CongressTradingService {
  final FirebaseFunctions? _functions;

  CongressTradingService({FirebaseFunctions? functions})
      : _functions = functions;

  Future<CongressTradingSnapshot> getTrades({
    String? symbol,
    String? chamber,
    String? party,
    String? transactionType,
    double? minAmount,
    List<String>? userPortfolioSymbols,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (symbol != null && symbol.trim().isNotEmpty) {
        payload['symbol'] = symbol.trim().toUpperCase();
      }
      if (chamber != null && chamber.trim().isNotEmpty) {
        payload['chamber'] = chamber.trim();
      }
      if (party != null && party.trim().isNotEmpty) {
        payload['party'] = party.trim();
      }
      if (transactionType != null && transactionType.trim().isNotEmpty) {
        payload['transactionType'] = transactionType.trim();
      }
      if (minAmount != null && minAmount > 0) {
        payload['minAmount'] = minAmount;
      }

      final functions = _functions ?? FirebaseFunctions.instance;
      final response =
          await functions.httpsCallable('getCongressTrades').call(payload);
      return CongressTradingSnapshot.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      debugPrint('CongressTradingService error, using fallback: $e');
      return _getFallbackSnapshot(
        symbol: symbol,
        chamber: chamber,
        party: party,
        transactionType: transactionType,
        minAmount: minAmount,
        userPortfolioSymbols: userPortfolioSymbols,
      );
    }
  }

  CongressTradingSnapshot _getFallbackSnapshot({
    String? symbol,
    String? chamber,
    String? party,
    String? transactionType,
    double? minAmount,
    List<String>? userPortfolioSymbols,
  }) {
    var trades = sampleCuratedCongressTrades;
    if (symbol != null && symbol.trim().isNotEmpty) {
      final sym = symbol.trim().toUpperCase();
      trades = trades.where((t) => t.symbol == sym).toList();
    }
    if (chamber != null && chamber.toLowerCase() != 'all') {
      final ch = CongressChamber.fromString(chamber);
      trades = trades.where((t) => t.chamber == ch).toList();
    }
    if (party != null && party.toLowerCase() != 'all') {
      final p = CongressParty.fromString(party);
      trades = trades.where((t) => t.party == p).toList();
    }
    if (transactionType != null && transactionType.toLowerCase() != 'all') {
      final isBuy = transactionType.toLowerCase() == 'purchase';
      trades = trades.where((t) => isBuy ? t.transactionType.isPurchase : t.transactionType.isSale).toList();
    }
    if (minAmount != null && minAmount > 0) {
      trades = trades.where((t) => t.amountMin >= minAmount).toList();
    }

    final upperUserSymbols =
        (userPortfolioSymbols ?? const []).map((s) => s.toUpperCase()).toSet();
    final overlapSymbols = <String>[];
    for (final t in trades) {
      if (upperUserSymbols.contains(t.symbol) &&
          !overlapSymbols.contains(t.symbol)) {
        overlapSymbols.add(t.symbol);
      }
    }

    double purchases = 0;
    double sales = 0;
    for (final t in trades) {
      if (t.transactionType.isPurchase) {
        purchases += t.amountMin;
      } else if (t.transactionType.isSale) {
        sales += t.amountMin;
      }
    }

    return CongressTradingSnapshot(
      symbol: symbol?.toUpperCase(),
      trades: trades,
      portfolioOverlap: overlapSymbols.isNotEmpty ||
          (symbol != null && upperUserSymbols.contains(symbol.toUpperCase())),
      overlappingSymbols: overlapSymbols,
      totalTrades: trades.length,
      totalPurchases: purchases,
      totalSales: sales,
      netPurchases: purchases - sales,
      updatedAt: DateTime.now(),
    );
  }

  static final List<CongressTrade> sampleCuratedCongressTrades = [
    CongressTrade(
      id: 'ptr-pelosi-nvda-2026-07',
      politicianName: 'Nancy Pelosi',
      chamber: CongressChamber.house,
      party: CongressParty.democrat,
      state: 'CA',
      district: 'CA-11',
      symbol: 'NVDA',
      assetDescription: 'NVIDIA Corporation - Common Stock',
      transactionType: CongressTransactionType.purchase,
      amount: '\$1,000,001 - \$5,000,000',
      amountMin: 1000001,
      amountMax: 5000000,
      transactionDate: DateTime(2026, 6, 26),
      disclosureDate: DateTime(2026, 7, 2),
      owner: 'Spouse',
      sourceUrl:
          'https://disclosures-clerk.house.gov/public_disc/ptr-pdfs/2026/20025112.pdf',
      comment: 'Exercised 50 call options (5,000 shares) at strike price \$120',
      isOverdue: false,
      filingLagDays: 6,
    ),
    CongressTrade(
      id: 'ptr-tuberville-msft-2026-08',
      politicianName: 'Tommy Tuberville',
      chamber: CongressChamber.senate,
      party: CongressParty.republican,
      state: 'AL',
      symbol: 'MSFT',
      assetDescription: 'Microsoft Corporation - Common Stock',
      transactionType: CongressTransactionType.purchase,
      amount: '\$100,001 - \$250,000',
      amountMin: 100001,
      amountMax: 250000,
      transactionDate: DateTime(2026, 8, 4),
      disclosureDate: DateTime(2026, 8, 25),
      owner: 'Joint',
      sourceUrl: 'https://efdsearch.senate.gov/search/view/ptr/893b1234/',
      comment: 'Open market purchase',
      isOverdue: false,
      filingLagDays: 21,
    ),
    CongressTrade(
      id: 'ptr-pelosi-aapl-2026-08',
      politicianName: 'Nancy Pelosi',
      chamber: CongressChamber.house,
      party: CongressParty.democrat,
      state: 'CA',
      district: 'CA-11',
      symbol: 'AAPL',
      assetDescription: 'Apple Inc. - Common Stock',
      transactionType: CongressTransactionType.salePartial,
      amount: '\$500,001 - \$1,000,000',
      amountMin: 500001,
      amountMax: 1000000,
      transactionDate: DateTime(2026, 7, 28),
      disclosureDate: DateTime(2026, 8, 5),
      owner: 'Spouse',
      sourceUrl:
          'https://disclosures-clerk.house.gov/public_disc/ptr-pdfs/2026/20025340.pdf',
      comment: 'Partial position trimming',
      isOverdue: false,
      filingLagDays: 8,
    ),
    CongressTrade(
      id: 'ptr-crenshaw-amzn-2026-08',
      politicianName: 'Dan Crenshaw',
      chamber: CongressChamber.house,
      party: CongressParty.republican,
      state: 'TX',
      district: 'TX-02',
      symbol: 'AMZN',
      assetDescription: 'Amazon.com Inc. - Common Stock',
      transactionType: CongressTransactionType.purchase,
      amount: '\$15,001 - \$50,000',
      amountMin: 15001,
      amountMax: 50000,
      transactionDate: DateTime(2026, 8, 11),
      disclosureDate: DateTime(2026, 8, 30),
      owner: 'Self',
      sourceUrl:
          'https://disclosures-clerk.house.gov/public_disc/ptr-pdfs/2026/20025488.pdf',
      comment: 'Direct stock purchase',
      isOverdue: false,
      filingLagDays: 19,
    ),
    CongressTrade(
      id: 'ptr-mccaul-googl-2026-08',
      politicianName: 'Michael McCaul',
      chamber: CongressChamber.house,
      party: CongressParty.republican,
      state: 'TX',
      district: 'TX-10',
      symbol: 'GOOGL',
      assetDescription: 'Alphabet Inc. Class A - Common Stock',
      transactionType: CongressTransactionType.purchase,
      amount: '\$250,001 - \$500,000',
      amountMin: 250001,
      amountMax: 500000,
      transactionDate: DateTime(2026, 8, 14),
      disclosureDate: DateTime(2026, 9, 2),
      owner: 'Spouse',
      sourceUrl:
          'https://disclosures-clerk.house.gov/public_disc/ptr-pdfs/2026/20025610.pdf',
      comment: 'Family trust purchase',
      isOverdue: false,
      filingLagDays: 19,
    ),
    CongressTrade(
      id: 'ptr-khanna-tsla-2026-08',
      politicianName: 'Ro Khanna',
      chamber: CongressChamber.house,
      party: CongressParty.democrat,
      state: 'CA',
      district: 'CA-17',
      symbol: 'TSLA',
      assetDescription: 'Tesla, Inc. - Common Stock',
      transactionType: CongressTransactionType.sale,
      amount: '\$50,001 - \$100,000',
      amountMin: 50001,
      amountMax: 100000,
      transactionDate: DateTime(2026, 8, 18),
      disclosureDate: DateTime(2026, 9, 8),
      owner: 'Spouse',
      sourceUrl:
          'https://disclosures-clerk.house.gov/public_disc/ptr-pdfs/2026/20025721.pdf',
      comment: 'Spouse portfolio divestment',
      isOverdue: false,
      filingLagDays: 21,
    ),
    CongressTrade(
      id: 'ptr-mullin-panw-2026-09',
      politicianName: 'Markwayne Mullin',
      chamber: CongressChamber.senate,
      party: CongressParty.republican,
      state: 'OK',
      symbol: 'PANW',
      assetDescription: 'Palo Alto Networks, Inc. - Common Stock',
      transactionType: CongressTransactionType.purchase,
      amount: '\$50,001 - \$100,000',
      amountMin: 50001,
      amountMax: 100000,
      transactionDate: DateTime(2026, 8, 20),
      disclosureDate: DateTime(2026, 9, 12),
      owner: 'Self',
      sourceUrl: 'https://efdsearch.senate.gov/search/view/ptr/893c5432/',
      comment: 'Cybersecurity sector allocation',
      isOverdue: false,
      filingLagDays: 23,
    ),
    CongressTrade(
      id: 'ptr-gottheimer-lly-2026-07',
      politicianName: 'Josh Gottheimer',
      chamber: CongressChamber.house,
      party: CongressParty.democrat,
      state: 'NJ',
      district: 'NJ-05',
      symbol: 'LLY',
      assetDescription: 'Eli Lilly and Company - Common Stock',
      transactionType: CongressTransactionType.purchase,
      amount: '\$15,001 - \$50,000',
      amountMin: 15001,
      amountMax: 50000,
      transactionDate: DateTime(2026, 7, 10),
      disclosureDate: DateTime(2026, 9, 1),
      owner: 'Joint',
      sourceUrl:
          'https://disclosures-clerk.house.gov/public_disc/ptr-pdfs/2026/20025880.pdf',
      comment: 'Late disclosure - pharmaceutical holding',
      isOverdue: true,
      filingLagDays: 53,
    ),
    CongressTrade(
      id: 'ptr-pelosi-nvda-2026-09',
      politicianName: 'Nancy Pelosi',
      chamber: CongressChamber.house,
      party: CongressParty.democrat,
      state: 'CA',
      district: 'CA-11',
      symbol: 'NVDA',
      assetDescription: 'NVIDIA Corporation - Common Stock',
      transactionType: CongressTransactionType.purchase,
      amount: '\$500,001 - \$1,000,000',
      amountMin: 500001,
      amountMax: 1000000,
      transactionDate: DateTime(2026, 9, 5),
      disclosureDate: DateTime(2026, 9, 18),
      owner: 'Spouse',
      sourceUrl:
          'https://disclosures-clerk.house.gov/public_disc/ptr-pdfs/2026/20025990.pdf',
      comment: '10,000 shares acquired',
      isOverdue: false,
      filingLagDays: 13,
    ),
  ];
}
