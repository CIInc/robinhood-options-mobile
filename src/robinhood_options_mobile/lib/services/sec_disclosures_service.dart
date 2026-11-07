import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../model/sec_disclosure.dart';

class SecDisclosuresService {
  final FirebaseFunctions _functions;

  SecDisclosuresService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  Future<SecDisclosureSnapshot> getDisclosures(String symbol) async {
    final sym = symbol.trim().toUpperCase();
    if (FirebaseAuth.instance.currentUser == null) {
      return _getMockDisclosures(sym);
    }
    try {
      final response =
          await _functions.httpsCallable('getSecDisclosures').call({
        'symbol': sym,
      });
      return SecDisclosureSnapshot.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      debugPrint('Error getting SEC disclosures for $sym: $e');
      return _getMockDisclosures(sym);
    }
  }

  Future<SecFilingResearchBrief> analyzeFiling({
    required String symbol,
    String? question,
  }) async {
    final sym = symbol.trim().toUpperCase();
    if (FirebaseAuth.instance.currentUser == null) {
      final mockSnapshot = _getMockDisclosures(sym);
      return SecFilingResearchBrief.fromSnapshot(mockSnapshot,
          question: question);
    }
    try {
      final response = await _functions.httpsCallable('analyzeSecFiling').call({
        'symbol': sym,
        if (question != null && question.trim().isNotEmpty)
          'question': question.trim(),
      });
      return SecFilingResearchBrief.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      debugPrint('Error analyzing SEC filing for $sym: $e');
      final mockSnapshot = _getMockDisclosures(sym);
      return SecFilingResearchBrief.fromSnapshot(mockSnapshot,
          question: question);
    }
  }

  SecDisclosureSnapshot _getMockDisclosures(String symbol) {
    final sym = symbol.trim().toUpperCase();
    final now = DateTime.now();
    return SecDisclosureSnapshot(
      symbol: sym,
      disclosures: [
        SecDisclosure(
          accessionNumber: '0000320193-24-000106',
          form: '10-Q',
          filedAt: now.subtract(const Duration(days: 14)),
          companyName: sym == 'AAPL'
              ? 'Apple Inc.'
              : sym == 'SPY'
                  ? 'SPDR S&P 500 ETF Trust'
                  : '$sym Corporation',
          title: 'Quarterly Report [Sections 13 or 15(d)]',
          summary:
              'Quarterly financial report demonstrating solid revenue growth and operating margin resilience.',
          url: 'https://www.sec.gov/edgar',
          symbols: [sym],
          itemCodes: ['Item 1', 'Item 2'],
          itemDescriptions: [
            'Financial Statements',
            'Management Discussion and Analysis'
          ],
        ),
        SecDisclosure(
          accessionNumber: '0000320193-24-000107',
          form: '4',
          filedAt: now.subtract(const Duration(days: 28)),
          companyName: sym == 'AAPL'
              ? 'Apple Inc.'
              : sym == 'SPY'
                  ? 'SPDR S&P 500 ETF Trust'
                  : '$sym Corporation',
          title: 'Statement of Changes in Beneficial Ownership',
          summary:
              'Insider transaction filing disclosing scheduled executive equity grants and open market purchases.',
          url: 'https://www.sec.gov/edgar',
          symbols: [sym],
          reportingOwners: ['Executive Officer'],
          officerTitles: ['Senior Vice President'],
          transactionCount: 2,
          openMarketBuyCount: 1,
          openMarketSellCount: 0,
        ),
        SecDisclosure(
          accessionNumber: '0000320193-24-000108',
          form: '8-K',
          filedAt: now.subtract(const Duration(days: 45)),
          companyName: sym == 'AAPL'
              ? 'Apple Inc.'
              : sym == 'SPY'
                  ? 'SPDR S&P 500 ETF Trust'
                  : '$sym Corporation',
          title: 'Current Report',
          summary:
              'Announcement of quarterly earnings release date and corporate updates.',
          url: 'https://www.sec.gov/edgar',
          symbols: [sym],
          itemCodes: ['Item 2.02'],
          itemDescriptions: ['Results of Operations and Financial Condition'],
        ),
      ],
      portfolioOverlap: true,
      updatedAt: now,
    );
  }
}
