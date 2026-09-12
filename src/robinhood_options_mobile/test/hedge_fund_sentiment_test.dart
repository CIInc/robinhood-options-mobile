import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/hedge_fund_sentiment.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  group('HedgeFundSummary & Models', () {
    test('parses full hedge fund summary and transactions', () {
      final summaryJson = {
        'status': 'SUCCESS',
        'data': {
          'instrument_id': 'inst_aapl_01',
          'symbol': 'AAPL',
          'net_sentiment': 'positive',
          'sentiment_score': 32.0,
          'total_shares_held': 840000000,
          'total_value_held': 189000000000.0,
          'institutional_ownership_percentage': 58.2,
          'total_managers_count': 312,
          'buying_managers_count': 184,
          'selling_managers_count': 86,
          'holding_managers_count': 42,
          'new_positions_count': 16,
          'sold_out_count': 8,
          'net_shares_changed': 24500000,
          'net_value_changed': 5512500000.0,
          'quarterly_summary': [
            {
              'quarter': 'Q2 2026',
              'buy_shares': 58000000,
              'sell_shares': 33500000,
              'buy_value': 13050000000.0,
              'sell_value': 7537500000.0,
              'buying_managers_count': 184,
              'selling_managers_count': 86,
              'holding_managers_count': 42,
              'new_positions_count': 16,
              'sold_out_positions_count': 8,
              'net_sentiment': 'positive',
            },
            {
              'quarter': 'Q1 2026',
              'buy_shares': 49000000,
              'sell_shares': 38000000,
              'buy_value': 10780000000.0,
              'sell_value': 8360000000.0,
              'buying_managers_count': 162,
              'selling_managers_count': 105,
              'holding_managers_count': 45,
              'new_positions_count': 12,
              'sold_out_positions_count': 11,
              'net_sentiment': 'positive',
            },
          ],
          'updated_at': '2026-08-15T16:00:00Z',
        }
      };

      final txJson = {
        'status': 'SUCCESS',
        'data': {
          'instrument_id': 'inst_aapl_01',
          'symbol': 'AAPL',
          'results': [
            {
              'manager_name': 'Berkshire Hathaway Inc.',
              'fund_name': 'Warren Buffett Portfolio',
              'quarter': 'Q2 2026',
              'report_date': '2026-06-30',
              'transaction_type': 'Hold',
              'shares_held': 400000000,
              'share_change': 0,
              'percent_change': 0.0,
              'value': 90000000000.0,
              'portfolio_percent': 28.5,
              'source_url':
                  'https://www.sec.gov/edgar/data/1067983/sample-13f.xml',
            },
            {
              'manager_name': 'Bridgewater Associates LP',
              'fund_name': 'Pure Alpha Fund',
              'quarter': 'Q2 2026',
              'report_date': '2026-06-30',
              'transaction_type': 'Addition',
              'shares_held': 8500000,
              'share_change': 1800000,
              'percent_change': 26.87,
              'value': 1912500000.0,
              'portfolio_percent': 2.1,
            },
            {
              'manager_name': 'Two Sigma Investments, LP',
              'fund_name': 'Two Sigma Horizon',
              'quarter': 'Q2 2026',
              'report_date': '2026-06-30',
              'transaction_type': 'New Position',
              'shares_held': 1500000,
              'share_change': 1500000,
              'percent_change': 100.0,
              'value': 337500000.0,
              'portfolio_percent': 0.45,
            },
          ]
        }
      };

      final summary = HedgeFundSummary.fromResponses(
        summaryResponse: summaryJson,
        transactionsResponse: txJson,
      );

      expect(summary.instrumentId, 'inst_aapl_01');
      expect(summary.symbol, 'AAPL');
      expect(summary.isBullish, isTrue);
      expect(summary.isBearish, isFalse);
      expect(summary.sentimentBadge, 'Accumulation');
      expect(summary.sentimentColor, Colors.green);
      expect(summary.totalManagersCount, 312);
      expect(summary.buyingManagersCount, 184);
      expect(summary.sellingManagersCount, 86);
      expect(summary.institutionalOwnershipPercentage, 58.2);
      expect(summary.buyersPercentage, closeTo(68.1, 0.1));
      expect(summary.sellersPercentage, closeTo(31.8, 0.1));
      expect(summary.formattedNetValue, contains('+'));
      expect(summary.formattedTotalValueHeld, contains(r'$'));
      expect(summary.quarterlySummary.length, 2);
      expect(summary.transactions.length, 3);

      final berk = summary.transactions[0];
      expect(berk.managerName, 'Berkshire Hathaway Inc.');
      expect(berk.fundName, 'Warren Buffett Portfolio');
      expect(berk.sharesHeld, 400000000);
      expect(berk.displayType, 'Held');
      expect(berk.isBuy, isFalse);
      expect(berk.isSell, isFalse);

      final bridge = summary.transactions[1];
      expect(bridge.isBuy, isTrue);
      expect(bridge.displayType, 'Increased');

      final twoSigma = summary.transactions[2];
      expect(twoSigma.isNewPosition, isTrue);
      expect(twoSigma.displayType, 'New Position');
    });

    test('handles bearish distribution classification', () {
      final summary = HedgeFundSummary(
        instrumentId: 'inst_tsla_01',
        symbol: 'TSLA',
        netSentiment: 'negative',
        sentimentScore: -40.0,
        totalSharesHeld: 100000000,
        totalValueHeld: 20000000000.0,
        totalManagersCount: 150,
        buyingManagersCount: 30,
        sellingManagersCount: 110,
        holdingManagersCount: 10,
        netSharesChanged: -15000000,
        netValueChanged: -3000000000.0,
      );

      expect(summary.isBearish, isTrue);
      expect(summary.isBullish, isFalse);
      expect(summary.sentimentBadge, 'Distribution');
      expect(summary.sentimentColor, Colors.red);
      expect(summary.buyersPercentage, closeTo(21.4, 0.1));
      expect(summary.sellersPercentage, closeTo(78.5, 0.1));
    });

    test('parses HedgeFundTransactionRecord with sold out status', () {
      final record = HedgeFundTransactionRecord.fromJson({
        'manager_name': 'Tiger Global Management LLC',
        'fund_name': 'Tiger Global LP',
        'transaction_type': 'Sold Out',
        'shares_held': 0,
        'share_change': -2000000,
        'value': 0.0,
      });

      expect(record.isSoldOut, isTrue);
      expect(record.displayType, 'Sold Out');
      expect(record.isSell, isTrue);
    });
  });

  group('DemoService Hedge Fund Endpoints', () {
    final demoService = DemoService();
    final user = BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);

    test('returns realistic hedge fund data for AAPL', () async {
      final summaryRes =
          await demoService.getHedgeFundSummary(user, 'inst_aapl_01');
      final txRes =
          await demoService.getHedgeFundTransactions(user, 'inst_aapl_01');

      expect(summaryRes, isNotNull);
      expect(txRes, isNotNull);

      final summary = HedgeFundSummary.fromResponses(
        summaryResponse: summaryRes,
        transactionsResponse: txRes,
      );

      expect(summary.symbol, 'AAPL');
      expect(summary.isBullish, isTrue);
      expect(
          summary.transactions.any((t) => t.managerName.contains('Berkshire')),
          isTrue);
      expect(summary.quarterlySummary.length, greaterThanOrEqualTo(2));
    });

    test(
        'returns realistic hedge fund data for GME (institutional accumulation)',
        () async {
      final summaryRes =
          await demoService.getHedgeFundSummary(user, 'inst_gme_01');
      final txRes =
          await demoService.getHedgeFundTransactions(user, 'inst_gme_01');

      expect(summaryRes, isNotNull);
      expect(txRes, isNotNull);

      final summary = HedgeFundSummary.fromResponses(
        summaryResponse: summaryRes,
        transactionsResponse: txRes,
      );

      expect(summary.symbol, 'GME');
      expect(summary.isBullish, isTrue);
      expect(
          summary.transactions
              .any((t) => t.managerName.contains('RC Ventures')),
          isTrue);
      expect(summary.buyingManagersCount,
          greaterThan(summary.sellingManagersCount));
    });

    test(
        'returns realistic hedge fund data for TSLA (institutional distribution)',
        () async {
      final summaryRes =
          await demoService.getHedgeFundSummary(user, 'inst_tsla_01');
      final txRes =
          await demoService.getHedgeFundTransactions(user, 'inst_tsla_01');

      expect(summaryRes, isNotNull);
      expect(txRes, isNotNull);

      final summary = HedgeFundSummary.fromResponses(
        summaryResponse: summaryRes,
        transactionsResponse: txRes,
      );

      expect(summary.symbol, 'TSLA');
      expect(summary.isBearish, isTrue);
      expect(summary.sentimentBadge, 'Distribution');
      expect(summary.transactions.any((t) => t.managerName.contains('ARK')),
          isTrue);
    });
  });
}
