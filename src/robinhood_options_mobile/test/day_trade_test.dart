import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/day_trade.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';

void main() {
  group('DayTrade Model', () {
    test('parses equity day trade from json', () {
      final json = {
        'symbol': 'AAPL',
        'instrument':
            'https://api.robinhood.com/instruments/00000000-0000-0000-0000-000000000000/',
        'trade_execution_date': '2026-03-23',
        'created_at': '2026-03-23T14:32:00Z',
        'direction': 'buy_then_sell',
        'quantity': 15.0,
        'price': 180.50,
        'count': 1,
      };

      final trade = DayTrade.fromJson(json, defaultType: 'equity');
      expect(trade.symbol, 'AAPL');
      expect(trade.type, 'equity');
      expect(trade.direction, 'buy_then_sell');
      expect(trade.quantity, 15.0);
      expect(trade.price, 180.50);
      expect(trade.count, 1);
      expect(trade.executionDate, DateTime(2026, 3, 23));
    });

    test('parses option day trade from json', () {
      final json = {
        'symbol': 'TSLA 260327C00220000',
        'option':
            'https://api.robinhood.com/options/instruments/00000000-0000-0000-0000-000000000000/',
        'trade_execution_date': '2026-03-24',
        'created_at': '2026-03-24T15:10:00Z',
        'side': 'buy_then_sell',
        'quantity': 2,
        'price': 4.50,
      };

      final trade = DayTrade.fromJson(json, defaultType: 'option');
      expect(trade.symbol, 'TSLA 260327C00220000');
      expect(trade.type, 'option');
      expect(trade.quantity, 2.0);
      expect(trade.price, 4.50);
    });

    test('computes drop-off date skipping weekends (5 business days)', () {
      // Monday March 23, 2026 -> +5 business days = Monday March 30, 2026
      final monday = DateTime(2026, 3, 23);
      final dropOffMon = DayTrade.computeDropOffDate(monday);
      expect(dropOffMon.weekday, DateTime.monday);
      expect(dropOffMon, DateTime(2026, 3, 30));

      // Friday March 27, 2026 -> +5 business days = Friday April 3, 2026
      final friday = DateTime(2026, 3, 27);
      final dropOffFri = DayTrade.computeDropOffDate(friday);
      expect(dropOffFri.weekday, DateTime.friday);
      expect(dropOffFri, DateTime(2026, 4, 3));
    });
  });

  group('DayTradeSummary & Risk Levels', () {
    test('calculates safe risk level for 0 or 1 trade', () {
      final now = DateTime.now();
      final summary = DayTradeSummary(
        accountNumber: '12345678',
        dayTrades: [
          DayTrade(
            id: 't1',
            symbol: 'AAPL',
            executionDate: now,
            timestamp: now,
          ),
        ],
        portfolioEquity: 10000,
        accountType: 'margin',
      );

      expect(summary.activeDayTradeCount, 1);
      expect(summary.remainingDayTrades, 2);
      expect(summary.riskLevel, PdtRiskLevel.safe);
      expect(summary.statusTitle, '2 of 3 Day Trades Available');
    });

    test('calculates warning risk level for 2 trades', () {
      final now = DateTime.now();
      final summary = DayTradeSummary(
        accountNumber: '12345678',
        dayTrades: [
          DayTrade(
              id: 't1', symbol: 'AAPL', executionDate: now, timestamp: now),
          DayTrade(
              id: 't2', symbol: 'MSFT', executionDate: now, timestamp: now),
        ],
        portfolioEquity: 15000,
        accountType: 'margin',
      );

      expect(summary.activeDayTradeCount, 2);
      expect(summary.remainingDayTrades, 1);
      expect(summary.riskLevel, PdtRiskLevel.warning);
      expect(summary.statusTitle, '1 Day Trade Left (Warning)');
    });

    test('calculates danger risk level for 3 trades', () {
      final now = DateTime.now();
      final summary = DayTradeSummary(
        accountNumber: '12345678',
        dayTrades: [
          DayTrade(
              id: 't1', symbol: 'AAPL', executionDate: now, timestamp: now),
          DayTrade(
              id: 't2', symbol: 'MSFT', executionDate: now, timestamp: now),
          DayTrade(
              id: 't3', symbol: 'NVDA', executionDate: now, timestamp: now),
        ],
        portfolioEquity: 18000,
        accountType: 'margin',
      );

      expect(summary.activeDayTradeCount, 3);
      expect(summary.remainingDayTrades, 0);
      expect(summary.riskLevel, PdtRiskLevel.danger);
      expect(summary.statusTitle, 'PDT Limit Reached (0 Left)');
    });

    test('calculates flagged risk level for 4 trades or marked PDT date', () {
      final now = DateTime.now();
      final summary = DayTradeSummary(
        accountNumber: '12345678',
        dayTrades: [
          DayTrade(
              id: 't1', symbol: 'AAPL', executionDate: now, timestamp: now),
          DayTrade(
              id: 't2', symbol: 'MSFT', executionDate: now, timestamp: now),
          DayTrade(
              id: 't3', symbol: 'NVDA', executionDate: now, timestamp: now),
          DayTrade(
              id: 't4', symbol: 'TSLA', executionDate: now, timestamp: now),
        ],
        portfolioEquity: 20000,
        markedPatternDayTraderDate: DateTime(2026, 3, 1),
        accountType: 'margin',
      );

      expect(summary.activeDayTradeCount, 4);
      expect(summary.remainingDayTrades, 0);
      expect(summary.riskLevel, PdtRiskLevel.flagged);
      expect(summary.statusTitle, 'Pattern Day Trader Flagged');
      expect(summary.equityDeficitTo25k, 5000.0);
    });

    test('exempts accounts with \$25,000+ equity from PDT restrictions', () {
      final now = DateTime.now();
      final summary = DayTradeSummary(
        accountNumber: '12345678',
        dayTrades: [
          DayTrade(
              id: 't1', symbol: 'AAPL', executionDate: now, timestamp: now),
          DayTrade(
              id: 't2', symbol: 'MSFT', executionDate: now, timestamp: now),
          DayTrade(
              id: 't3', symbol: 'NVDA', executionDate: now, timestamp: now),
          DayTrade(
              id: 't4', symbol: 'TSLA', executionDate: now, timestamp: now),
        ],
        portfolioEquity: 35000,
        accountType: 'margin',
      );

      expect(summary.isPdtExempt, isTrue);
      expect(summary.riskLevel, PdtRiskLevel.exempt);
      expect(summary.remainingDayTrades, -1);
      expect(summary.statusTitle, 'PDT Exempt (\$25k+ Equity)');
      expect(summary.equityDeficitTo25k, 0.0);
    });

    test('exempts cash accounts from PDT restrictions', () {
      final summary = DayTradeSummary(
        accountNumber: '12345678',
        dayTrades: [],
        portfolioEquity: 5000,
        accountType: 'cash',
      );

      expect(summary.isCashAccount, isTrue);
      expect(summary.riskLevel, PdtRiskLevel.exempt);
      expect(summary.statusTitle, 'Cash Account (PDT Exempt)');
    });
  });

  group('Account PDT Fields', () {
    test('parses PDT margin balances from json', () {
      final accountJson = {
        'account_number': '5RA99999',
        'type': 'margin',
        'portfolio_cash': '15000.00',
        'margin_balances': {
          'day_trade_buying_power': '40000.00',
          'day_trades_protection': true,
          'day_trade_ratio': '0.25',
          'marked_pattern_day_trader_date': '2026-02-15T00:00:00Z',
          'pattern_day_trader_expiry_date': '2026-05-15T00:00:00Z',
          'is_pdt_forever': false,
          'settled_amount_borrowed': '0',
        },
      };

      final account = Account.fromJson(accountJson);
      expect(account.accountNumber, '5RA99999');
      expect(account.dayTradesProtection, isTrue);
      expect(account.dayTradeBuyingPower, 40000.00);
      expect(account.dayTradeRatio, 0.25);
      expect(account.markedPatternDayTraderDate,
          DateTime.parse('2026-02-15T00:00:00Z'));
      expect(account.patternDayTraderExpiryDate,
          DateTime.parse('2026-05-15T00:00:00Z'));
      expect(account.isPdtForever, isFalse);

      final exported = account.toJson();
      expect(exported['day_trades_protection'], isTrue);
      expect(exported['day_trade_buying_power'], 40000.00);
      expect(exported['day_trade_ratio'], 0.25);
      expect(exported['is_pdt_forever'], isFalse);
    });
  });

  group('DemoService Day Trades', () {
    test('returns mock day trades with active trades', () async {
      final demoService = DemoService();
      final user = BrokerageUser(
        BrokerageSource.demo,
        'demo_user',
        null,
        null,
      );

      final res = await demoService.getRecentDayTrades(user, 'DEMO1234');
      expect(res, isNotNull);
      expect(res['equity_day_trades'], isNotEmpty);
      expect(res['option_day_trades'], isNotEmpty);

      final summary = DayTradeSummary.fromJson(
        res,
        accountNumber: 'DEMO1234',
        portfolioEquity: 18000,
        accountType: 'margin',
      );

      expect(summary.dayTrades.length, 2);
      expect(summary.activeDayTradeCount, 2);
      expect(summary.remainingDayTrades, 1);
      expect(summary.riskLevel, PdtRiskLevel.warning);
    });
  });

  group('PortfolioAlertService PDT Alerts', () {
    test(
        'triggers critical alert when account has marked PDT date with under \$25k equity',
        () {
      final account = Account(
        'https://api.robinhood.com/accounts/12345/',
        15000.0,
        '12345',
        'margin',
        15000.0,
        'level_3',
        0.0,
        0.0,
        0.0,
        markedPatternDayTraderDate: DateTime(2026, 3, 1),
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        account: account,
        totalEquity: 15000.0,
      );

      final pdtAlert = alerts.firstWhere((a) => a.id == 'pdt-flagged');
      expect(pdtAlert.severity, PortfolioAlertSeverity.critical);
      expect(pdtAlert.title, contains('Pattern Day Trader restriction'));
      expect(pdtAlert.target, PortfolioAlertTarget.risk);
    });

    test('triggers critical alert when PDT limit reached (3 of 3 trades used)',
        () {
      final account = Account(
        'https://api.robinhood.com/accounts/12345/',
        12000.0,
        '12345',
        'margin',
        12000.0,
        'level_3',
        0.0,
        0.0,
        0.0,
      );

      final now = DateTime.now();
      final summary = DayTradeSummary(
        accountNumber: '12345',
        dayTrades: [
          DayTrade(
              id: 't1', symbol: 'AAPL', executionDate: now, timestamp: now),
          DayTrade(
              id: 't2', symbol: 'TSLA', executionDate: now, timestamp: now),
          DayTrade(
              id: 't3', symbol: 'NVDA', executionDate: now, timestamp: now),
        ],
        portfolioEquity: 12000.0,
        accountType: 'margin',
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        account: account,
        totalEquity: 12000.0,
        dayTradeSummary: summary,
      );

      final pdtAlert = alerts.firstWhere((a) => a.id == 'pdt-limit-reached');
      expect(pdtAlert.severity, PortfolioAlertSeverity.critical);
      expect(pdtAlert.title, contains('PDT limit reached'));
    });

    test('triggers warning alert when 1 day trade remains', () {
      final account = Account(
        'https://api.robinhood.com/accounts/12345/',
        12000.0,
        '12345',
        'margin',
        12000.0,
        'level_3',
        0.0,
        0.0,
        0.0,
      );

      final now = DateTime.now();
      final summary = DayTradeSummary(
        accountNumber: '12345',
        dayTrades: [
          DayTrade(
              id: 't1', symbol: 'AAPL', executionDate: now, timestamp: now),
          DayTrade(
              id: 't2', symbol: 'TSLA', executionDate: now, timestamp: now),
        ],
        portfolioEquity: 12000.0,
        accountType: 'margin',
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        account: account,
        totalEquity: 12000.0,
        dayTradeSummary: summary,
      );

      final pdtAlert = alerts.firstWhere((a) => a.id == 'pdt-warning');
      expect(pdtAlert.severity, PortfolioAlertSeverity.warning);
      expect(pdtAlert.title, contains('1 day trade remaining'));
    });

    test('no PDT alert generated when portfolio equity is \$25,000+', () {
      final account = Account(
        'https://api.robinhood.com/accounts/12345/',
        35000.0,
        '12345',
        'margin',
        35000.0,
        'level_3',
        0.0,
        0.0,
        0.0,
      );

      final now = DateTime.now();
      final summary = DayTradeSummary(
        accountNumber: '12345',
        dayTrades: [
          DayTrade(
              id: 't1', symbol: 'AAPL', executionDate: now, timestamp: now),
          DayTrade(
              id: 't2', symbol: 'TSLA', executionDate: now, timestamp: now),
          DayTrade(
              id: 't3', symbol: 'NVDA', executionDate: now, timestamp: now),
        ],
        portfolioEquity: 35000.0,
        accountType: 'margin',
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        account: account,
        totalEquity: 35000.0,
        dayTradeSummary: summary,
      );

      expect(alerts.any((a) => a.id.startsWith('pdt-')), isFalse);
    });
  });
}
