import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/congress_trade.dart';

void main() {
  group('CongressTrade model tests', () {
    test('parses CongressChamber correctly', () {
      expect(CongressChamber.fromString('House'), CongressChamber.house);
      expect(CongressChamber.fromString('house of representatives'),
          CongressChamber.house);
      expect(CongressChamber.fromString('Senate'), CongressChamber.senate);
      expect(CongressChamber.fromString('senator'), CongressChamber.senate);
      expect(CongressChamber.fromString('unknown'), CongressChamber.unknown);
      expect(CongressChamber.fromString(null), CongressChamber.unknown);

      expect(CongressChamber.house.displayName, 'House');
      expect(CongressChamber.senate.displayName, 'Senate');
      expect(CongressChamber.house.titlePrefix, 'Rep.');
      expect(CongressChamber.senate.titlePrefix, 'Sen.');
    });

    test('parses CongressParty and provides color and codes', () {
      expect(CongressParty.fromString('Democrat'), CongressParty.democrat);
      expect(CongressParty.fromString('D'), CongressParty.democrat);
      expect(CongressParty.fromString('Republican'), CongressParty.republican);
      expect(CongressParty.fromString('R'), CongressParty.republican);
      expect(
          CongressParty.fromString('Independent'), CongressParty.independent);
      expect(CongressParty.fromString('I'), CongressParty.independent);
      expect(CongressParty.fromString(null), CongressParty.other);

      expect(CongressParty.democrat.shortCode, 'D');
      expect(CongressParty.republican.shortCode, 'R');
      expect(CongressParty.independent.shortCode, 'I');

      expect(CongressParty.democrat.color, Colors.blue);
      expect(CongressParty.republican.color, Colors.red);
      expect(CongressParty.independent.color, Colors.purple);
    });

    test('parses CongressTransactionType and flags buy/sell', () {
      expect(CongressTransactionType.fromString('Purchase'),
          CongressTransactionType.purchase);
      expect(CongressTransactionType.fromString('buy'),
          CongressTransactionType.purchase);
      expect(CongressTransactionType.fromString('Sale'),
          CongressTransactionType.sale);
      expect(CongressTransactionType.fromString('Sale (Partial)'),
          CongressTransactionType.salePartial);
      expect(CongressTransactionType.fromString('Exchange'),
          CongressTransactionType.exchange);

      expect(CongressTransactionType.purchase.isPurchase, isTrue);
      expect(CongressTransactionType.purchase.isSale, isFalse);
      expect(CongressTransactionType.sale.isPurchase, isFalse);
      expect(CongressTransactionType.sale.isSale, isTrue);
      expect(CongressTransactionType.salePartial.isSale, isTrue);
    });

    test('parses CongressTrade from JSON and calculates lag/overdue', () {
      final json = {
        'id': 'trade-123',
        'politicianName': 'Nancy Pelosi',
        'chamber': 'House',
        'party': 'Democrat',
        'state': 'CA',
        'district': 'CA-11',
        'symbol': 'NVDA',
        'assetDescription': 'NVIDIA Corporation',
        'transactionType': 'Purchase',
        'amount': '\$1,000,001 - \$5,000,000',
        'amountMin': 1000001,
        'amountMax': 5000000,
        'transactionDate': '2026-06-26',
        'disclosureDate': '2026-07-02',
        'owner': 'Spouse',
        'sourceUrl': 'https://example.com/ptr.pdf',
        'comment': 'Call option exercise',
        'isOverdue': false,
        'filingLagDays': 6,
      };

      final trade = CongressTrade.fromJson(json);

      expect(trade.id, 'trade-123');
      expect(trade.politicianName, 'Nancy Pelosi');
      expect(trade.politicianTitle, 'Rep. Nancy Pelosi');
      expect(trade.politicalAffiliation, 'D-CA-11');
      expect(trade.chamber, CongressChamber.house);
      expect(trade.party, CongressParty.democrat);
      expect(trade.symbol, 'NVDA');
      expect(trade.amountMin, 1000001);
      expect(trade.amountMax, 5000000);
      expect(trade.transactionType.isPurchase, isTrue);
      expect(trade.isOverdue, isFalse);
      expect(trade.filingLagDays, 6);

      final outJson = trade.toJson();
      expect(outJson['symbol'], 'NVDA');
      expect(outJson['amountMin'], 1000001);
    });

    test('flags overdue filing when disclosure lag exceeds 45 days', () {
      final json = {
        'id': 'trade-overdue',
        'politicianName': 'Josh Gottheimer',
        'chamber': 'House',
        'party': 'Democrat',
        'state': 'NJ',
        'district': 'NJ-05',
        'symbol': 'LLY',
        'assetDescription': 'Eli Lilly and Co',
        'transactionType': 'Purchase',
        'amount': '\$15,001 - \$50,000',
        'amountMin': 15001,
        'amountMax': 50000,
        'transactionDate': '2026-07-10',
        'disclosureDate': '2026-09-01', // 53 days
        'owner': 'Joint',
        'sourceUrl': 'https://example.com/ptr2.pdf',
        'isOverdue': true,
        'filingLagDays': 53,
      };

      final trade = CongressTrade.fromJson(json);
      expect(trade.isOverdue, isTrue);
      expect(trade.filingLagDays, 53);
    });

    test('parses CongressTradingSnapshot from JSON', () {
      final json = {
        'symbol': 'NVDA',
        'portfolioOverlap': true,
        'overlappingSymbols': ['NVDA'],
        'totalTrades': 1,
        'totalPurchases': 1000001.0,
        'totalSales': 0.0,
        'netPurchases': 1000001.0,
        'updatedAt': '2026-09-24T00:00:00.000Z',
        'trades': [
          {
            'id': 'trade-1',
            'politicianName': 'Nancy Pelosi',
            'chamber': 'House',
            'party': 'Democrat',
            'state': 'CA',
            'district': 'CA-11',
            'symbol': 'NVDA',
            'assetDescription': 'NVIDIA Corporation',
            'transactionType': 'Purchase',
            'amount': '\$1,000,001 - \$5,000,000',
            'amountMin': 1000001,
            'amountMax': 5000000,
            'transactionDate': '2026-06-26',
            'disclosureDate': '2026-07-02',
            'owner': 'Spouse',
            'sourceUrl': 'https://example.com/ptr.pdf',
            'isOverdue': false,
            'filingLagDays': 6,
          },
        ],
      };

      final snapshot = CongressTradingSnapshot.fromJson(json);

      expect(snapshot.symbol, 'NVDA');
      expect(snapshot.portfolioOverlap, isTrue);
      expect(snapshot.overlappingSymbols, ['NVDA']);
      expect(snapshot.totalTrades, 1);
      expect(snapshot.totalPurchases, 1000001.0);
      expect(snapshot.trades.length, 1);
      expect(snapshot.trades.first.symbol, 'NVDA');

      final outJson = snapshot.toJson();
      expect(outJson['portfolioOverlap'], isTrue);
      expect(outJson['symbol'], 'NVDA');
    });
  });
}
