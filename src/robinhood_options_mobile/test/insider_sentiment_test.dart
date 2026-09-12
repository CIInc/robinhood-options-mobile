import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/insider_sentiment.dart';
import 'package:robinhood_options_mobile/model/insider_transaction.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  group('InsiderSentimentSummary & Models', () {
    test('parses full insider summary with monthly breakdown and transactions', () {
      final summaryJson = {
        'status': 'SUCCESS',
        'data': {
          'instrument_id': 'inst_aapl_01',
          'symbol': 'AAPL',
          'net_sentiment': 'positive',
          'sentiment_score': 28.5,
          'total_buy_shares': 145000,
          'total_sell_shares': 82000,
          'total_buy_value': 32625000.0,
          'total_sell_value': 18450000.0,
          'buy_count': 8,
          'sell_count': 3,
          'net_shares': 63000,
          'net_value': 14175000.0,
          'monthly_summary': [
            {
              'month': '2026-08',
              'buy_shares': 65000,
              'sell_shares': 22000,
              'buy_value': 14625000.0,
              'sell_value': 4950000.0,
              'net_sentiment': 'positive',
              'buy_count': 4,
              'sell_count': 1,
            },
            {
              'month': '2026-07',
              'buy_shares': 48000,
              'sell_shares': 30000,
              'buy_value': 10800000.0,
              'sell_value': 6750000.0,
              'net_sentiment': 'positive',
              'buy_count': 2,
              'sell_count': 1,
            },
          ],
          'updated_at': '2026-09-08T18:00:00Z',
        }
      };

      final txJson = {
        'status': 'SUCCESS',
        'data': {
          'instrument_id': 'inst_aapl_01',
          'symbol': 'AAPL',
          'results': [
            {
              'filer_name': 'Tim Cook',
              'relationship': 'Chief Executive Officer',
              'transaction_date': '2026-08-22',
              'filing_date': '2026-08-24',
              'transaction_type': 'Option Exercise',
              'transaction_code': 'M',
              'shares': 50000,
              'price': 225.50,
              'value': 11275000.0,
              'shares_held_after': 3280000,
              'is_direct': true,
              'sec_form4_url': 'https://www.sec.gov/edgar/data/320193/sample.xml',
            },
            {
              'filer_name': 'Luca Maestri',
              'relationship': 'Chief Financial Officer',
              'transaction_date': '2026-08-18',
              'filing_date': '2026-08-20',
              'transaction_type': 'Open Market Sale',
              'transaction_code': 'S',
              'shares': 20000,
              'price': 224.80,
              'value': 4496000.0,
              'shares_held_after': 112000,
              'is_direct': true,
            },
            {
              'filer_name': 'Arthur Levinson',
              'relationship': 'Chairman of the Board',
              'transaction_date': '2026-08-10',
              'filing_date': '2026-08-12',
              'transaction_type': 'Open Market Purchase',
              'transaction_code': 'P',
              'shares': 15000,
              'price': 221.00,
              'value': 3315000.0,
              'shares_held_after': 4520000,
              'is_direct': true,
            },
            {
              'filer_name': 'Deirdre O\'Brien',
              'relationship': 'Senior Vice President',
              'transaction_date': '2026-07-28',
              'filing_date': '2026-07-30',
              'transaction_type': 'Grant/Award',
              'transaction_code': 'A',
              'shares': 12000,
              'price': 218.40,
              'value': 2620800.0,
              'shares_held_after': 135000,
              'is_direct': true,
            },
          ]
        }
      };

      final summary = InsiderSentimentSummary.fromResponses(
        summaryResponse: summaryJson,
        transactionsResponse: txJson,
      );

      expect(summary.instrumentId, 'inst_aapl_01');
      expect(summary.symbol, 'AAPL');
      expect(summary.isBullish, isTrue);
      expect(summary.isBearish, isFalse);
      expect(summary.sentimentBadge, 'Net Buying');
      expect(summary.sentimentColor, Colors.green);
      expect(summary.totalBuyShares, 145000);
      expect(summary.totalSellShares, 82000);
      expect(summary.netShares, 63000);
      expect(summary.netValue, 14175000.0);
      expect(summary.formattedNetValue, contains('+'));
      expect(summary.formattedNetShares, contains('+63K shares'));
      expect(summary.buyPercentage, closeTo(63.87, 0.1));
      expect(summary.sellPercentage, closeTo(36.12, 0.1));

      // Verify monthly breakdown
      expect(summary.monthlySummary.length, 2);
      expect(summary.monthlySummary.first.month, '2026-08');
      expect(summary.monthlySummary.first.formattedMonth, 'Aug 2026');
      expect(summary.monthlySummary.first.buyShares, 65000);
      expect(summary.monthlySummary.first.sellShares, 22000);
      expect(summary.monthlySummary.first.netValue, 9675000.0);

      // Verify transactions
      expect(summary.transactions.length, 4);
      final cook = summary.transactions[0];
      expect(cook.filerName, 'Tim Cook');
      expect(cook.relationship, 'Chief Executive Officer');
      expect(cook.isOption, isTrue);
      expect(cook.isBuy, isFalse);
      expect(cook.displayType, 'Option Exercise');
      expect(cook.typeColor, Colors.orange);
      expect(cook.shares, 50000);
      expect(cook.value, 11275000.0);
      expect(cook.secForm4Url, contains('sample.xml'));

      final maestri = summary.transactions[1];
      expect(maestri.filerName, 'Luca Maestri');
      expect(maestri.isSale, isTrue);
      expect(maestri.displayType, 'Sale');
      expect(maestri.typeColor, Colors.red);

      final levinson = summary.transactions[2];
      expect(levinson.filerName, 'Arthur Levinson');
      expect(levinson.isBuy, isTrue);
      expect(levinson.displayType, 'Purchase');
      expect(levinson.typeColor, Colors.green);

      final obrien = summary.transactions[3];
      expect(obrien.filerName, 'Deirdre O\'Brien');
      expect(obrien.isGrant, isTrue);
      expect(obrien.displayType, 'Grant / Award');
      expect(obrien.typeColor, Colors.blue);
    });

    test('derives summary statistics and monthly breakdown from transactions only', () {
      final txList = [
        {
          'filer_name': 'Director Alice',
          'relationship': 'Director',
          'transaction_date': '2026-08-10',
          'transaction_type': 'Purchase',
          'transaction_code': 'P',
          'shares': 10000,
          'price': 150.0,
          'value': 1500000.0,
        },
        {
          'filer_name': 'Officer Bob',
          'relationship': 'CFO',
          'transaction_date': '2026-08-05',
          'transaction_type': 'Sale',
          'transaction_code': 'S',
          'shares': 4000,
          'price': 150.0,
          'value': 600000.0,
        },
        {
          'filer_name': 'Director Carol',
          'relationship': 'Director',
          'transaction_date': '2026-07-15',
          'transaction_type': 'Purchase',
          'transaction_code': 'P',
          'shares': 5000,
          'price': 140.0,
          'value': 700000.0,
        },
      ];

      final summary = InsiderSentimentSummary.fromResponses(
        transactionsResponse: txList,
        instrumentId: 'inst_xyz',
        symbol: 'XYZ',
      );

      expect(summary.instrumentId, 'inst_xyz');
      expect(summary.symbol, 'XYZ');
      expect(summary.totalBuyShares, 15000);
      expect(summary.totalSellShares, 4000);
      expect(summary.totalBuyValue, 2200000.0);
      expect(summary.totalSellValue, 600000.0);
      expect(summary.netShares, 11000);
      expect(summary.netValue, 1600000.0);
      expect(summary.buyCount, 2);
      expect(summary.sellCount, 1);
      expect(summary.isBullish, isTrue);
      expect(summary.sentimentBadge, 'Net Buying');

      // Verify derived monthly breakdown
      expect(summary.monthlySummary.length, 2);
      expect(summary.monthlySummary.any((m) => m.month == '2026-08'), isTrue);
      expect(summary.monthlySummary.any((m) => m.month == '2026-07'), isTrue);
    });

    test('classifies net selling sentiment correctly', () {
      final summaryJson = {
        'instrument_id': 'inst_bear',
        'symbol': 'BEAR',
        'net_sentiment': 'negative',
        'total_buy_shares': 5000,
        'total_sell_shares': 95000,
        'total_buy_value': 500000.0,
        'total_sell_value': 9500000.0,
        'buy_count': 1,
        'sell_count': 6,
      };

      final summary = InsiderSentimentSummary.fromResponses(
        summaryResponse: summaryJson,
      );

      expect(summary.isBearish, isTrue);
      expect(summary.isBullish, isFalse);
      expect(summary.sentimentBadge, 'Net Selling');
      expect(summary.sentimentColor, Colors.red);
      expect(summary.formattedNetValue, contains('-'));
    });

    test('bridges legacy InsiderTransaction to InsiderTransactionRecord', () {
      final legacy = InsiderTransaction(
        filerName: 'Satya Nadella',
        filerRelation: 'Chief Executive Officer',
        filerUrl: 'https://example.com/form4',
        maxAge: 1,
        moneyText: '\$5,000,000',
        ownership: 'D',
        shares: '12,500',
        sharesValue: 12500,
        startDate: DateTime(2026, 8, 1),
        transactionText: 'Sale',
        value: 5000000.0,
      );

      final record = legacy.toRecord();
      expect(record.filerName, 'Satya Nadella');
      expect(record.relationship, 'Chief Executive Officer');
      expect(record.isSale, isTrue);
      expect(record.shares, 12500);
      expect(record.value, 5000000.0);
      expect(record.secForm4Url, 'https://example.com/form4');
    });
  });

  group('DemoService Insider Endpoints', () {
    final demoService = DemoService();
    final user = BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);

    test('returns realistic insider data for AAPL', () async {
      final summaryRes = await demoService.getInsiderSummary(user, 'inst_aapl_01');
      final txRes = await demoService.getInsiderTransactions(user, 'inst_aapl_01');

      expect(summaryRes, isNotNull);
      expect(txRes, isNotNull);

      final summary = InsiderSentimentSummary.fromResponses(
        summaryResponse: summaryRes,
        transactionsResponse: txRes,
      );

      expect(summary.symbol, 'AAPL');
      expect(summary.isBullish, isTrue);
      expect(summary.transactions.any((t) => t.filerName == 'Tim Cook'), isTrue);
      expect(summary.monthlySummary.length, greaterThanOrEqualTo(2));
    });

    test('returns realistic insider data for GME (executive buying)', () async {
      final summaryRes = await demoService.getInsiderSummary(user, 'inst_gme_01');
      final txRes = await demoService.getInsiderTransactions(user, 'inst_gme_01');

      expect(summaryRes, isNotNull);
      expect(txRes, isNotNull);

      final summary = InsiderSentimentSummary.fromResponses(
        summaryResponse: summaryRes,
        transactionsResponse: txRes,
      );

      expect(summary.symbol, 'GME');
      expect(summary.isBullish, isTrue);
      expect(summary.transactions.any((t) => t.filerName.contains('Ryan Cohen')), isTrue);
      expect(summary.sellCount, 0);
    });

    test('returns realistic insider data for TSLA (executive selling)', () async {
      final summaryRes = await demoService.getInsiderSummary(user, 'inst_tsla_01');
      final txRes = await demoService.getInsiderTransactions(user, 'inst_tsla_01');

      expect(summaryRes, isNotNull);
      expect(txRes, isNotNull);

      final summary = InsiderSentimentSummary.fromResponses(
        summaryResponse: summaryRes,
        transactionsResponse: txRes,
      );

      expect(summary.symbol, 'TSLA');
      expect(summary.isBearish, isTrue);
      expect(summary.sentimentBadge, 'Net Selling');
      expect(summary.transactions.any((t) => t.filerName.contains('Robyn Denholm')), isTrue);
    });
  });
}
