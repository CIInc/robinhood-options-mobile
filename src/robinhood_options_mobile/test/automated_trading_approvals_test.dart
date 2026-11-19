import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/automated_trade_proposal.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/widgets/automated_trade_proposal_detail_widget.dart';
import 'package:robinhood_options_mobile/widgets/automated_trading_approvals_widget.dart';
import 'firebase_mocks.dart';

Map<String, dynamic> _makeProposalMap({
  String id = 'prop_1',
  String symbol = 'NVDA',
  String action = 'BUY',
  int quantity = 10,
  double price = 135.50,
  String reason = 'Bullish Golden Cross with positive GEX transition',
  num confidence = 88,
  String qualification = 'CONFIRMED',
  double rr = 2.4,
  String interval = '15m',
}) {
  return {
    'id': id,
    'timestamp': DateTime(2026, 11, 14, 10, 30).toIso8601String(),
    'symbol': symbol,
    'action': action,
    'quantity': quantity,
    'price': price,
    'reason': reason,
    'confidence': confidence,
    'proposal': {
      'qualification': qualification,
      'rewardRiskRatio': rr,
      'interval': interval,
      'reason': reason,
      'gexData': {
        'pTrans': 138.0,
        'nTrans': 130.0,
        'gammaFlip': 132.5,
      },
      'macroAssessment': {
        'status': 'BULLISH',
        'reason': 'Soft landing and dovish rates outlook',
        'score': 82,
      },
    },
    'assessment': {
      'approved': true,
      'metrics': {
        'volatilityFilter': 'pass',
        'correlationFilter': 'pass',
        'sectorLimitFilter': 'pass',
      },
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupFirebaseMocks();
  });

  group('AutomatedTradeProposal Model Tests', () {
    test('Deserializes from map and exposes getters correctly', () {
      final map = _makeProposalMap(
        symbol: 'TSLA',
        action: 'BUY',
        quantity: 20,
        price: 250.0,
      );
      final proposal = AutomatedTradeProposal.fromMap(map);

      expect(proposal.id, equals('prop_1'));
      expect(proposal.symbol, equals('TSLA'));
      expect(proposal.isBuy, isTrue);
      expect(proposal.isSell, isFalse);
      expect(proposal.quantity, equals(20));
      expect(proposal.price, equals(250.0));
      expect(proposal.estimatedCost, equals(5000.0));
      expect(proposal.confidence, equals(88));
      expect(proposal.qualification, equals(ProposalQualification.confirmed));
      expect(proposal.isConfirmed, isTrue);
      expect(proposal.rewardRiskRatio, equals(2.4));
      expect(proposal.interval, equals('15m'));
      expect(proposal.pTransPrice, equals(138.0));
      expect(proposal.nTransPrice, equals(130.0));
      expect(proposal.gammaFlipPrice, equals(132.5));
      expect(proposal.macroStatus, equals('BULLISH'));
      expect(proposal.macroReason,
          equals('Soft landing and dovish rates outlook'));
      expect(proposal.formattedTime, isNotEmpty);
    });

    test('Serializes to map preserving all core fields', () {
      final original = AutomatedTradeProposal.fromMap(_makeProposalMap());
      final map = original.toMap();
      final roundtrip = AutomatedTradeProposal.fromMap(map);

      expect(roundtrip.id, equals(original.id));
      expect(roundtrip.symbol, equals(original.symbol));
      expect(roundtrip.action, equals(original.action));
      expect(roundtrip.quantity, equals(original.quantity));
      expect(roundtrip.price, equals(original.price));
      expect(roundtrip.estimatedCost, equals(original.estimatedCost));
      expect(roundtrip.confidence, equals(original.confidence));
      expect(roundtrip.qualification, equals(original.qualification));
    });
  });

  group('AgenticTradingProvider Approvals Extensions Tests', () {
    test('Calculates pending proposals and capital correctly', () {
      final provider = AgenticTradingProvider();
      expect(provider.pendingApprovalsCount, equals(0));
      expect(provider.totalPendingCapital, equals(0.0));
      expect(provider.pendingProposals, isEmpty);

      // Inject pending orders
      provider.pendingOrders.add(_makeProposalMap(
        id: 'o1',
        symbol: 'AAPL',
        quantity: 10,
        price: 150.0,
      ));
      provider.pendingOrders.add(_makeProposalMap(
        id: 'o2',
        symbol: 'MSFT',
        quantity: 5,
        price: 400.0,
      ));

      expect(provider.pendingApprovalsCount, equals(2));
      expect(provider.totalPendingCapital, equals(1500.0 + 2000.0));
      expect(provider.pendingProposals.length, equals(2));
      expect(provider.pendingProposals[0].symbol, equals('AAPL'));
      expect(provider.pendingProposals[1].symbol, equals('MSFT'));
    });

    test('rejectOrder logs rejection audit entry in autoTradeHistory',
        () async {
      final provider = AgenticTradingProvider();
      final order = _makeProposalMap(
          id: 'rej_1', symbol: 'AMZN', quantity: 10, price: 180.0);
      provider.pendingOrders.add(order);

      expect(provider.pendingOrders.length, equals(1));
      expect(provider.autoTradeHistory.isEmpty, isTrue);

      await provider.rejectOrder(order);

      expect(provider.pendingOrders.isEmpty, isTrue);
      expect(provider.autoTradeHistory.length, equals(1));
      final hist = provider.autoTradeHistory.first;
      expect(hist['symbol'], equals('AMZN'));
      expect(hist['status'], equals('rejected'));
      expect(hist['rejected'], isTrue);
    });

    test('batchRejectOrders dismisses multiple proposals and records history',
        () async {
      final provider = AgenticTradingProvider();
      final o1 = _makeProposalMap(id: 'b1', symbol: 'AMD');
      final o2 = _makeProposalMap(id: 'b2', symbol: 'INTC');
      provider.pendingOrders.addAll([o1, o2]);

      await provider.batchRejectOrders([o1, o2]);

      expect(provider.pendingOrders.isEmpty, isTrue);
      expect(provider.autoTradeHistory.length, equals(2));
      expect(provider.autoTradeHistory[0]['status'], equals('rejected'));
      expect(provider.autoTradeHistory[1]['status'], equals('rejected'));
    });
  });

  group('AutomatedTradingApprovalsWidget Tests', () {
    testWidgets('Renders empty state when no pending proposals',
        (WidgetTester tester) async {
      final provider = AgenticTradingProvider();
      final accountStore = AccountStore();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AgenticTradingProvider>.value(
                value: provider),
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
            ChangeNotifierProvider<BrokerageUserStore>(
                create: (_) => BrokerageUserStore([], 0)),
            ChangeNotifierProvider<PaperTradingStore>(
                create: (_) => PaperTradingStore()),
            ChangeNotifierProvider<QuoteStore>(create: (_) => QuoteStore()),
            ChangeNotifierProvider<InstrumentPositionStore>(
                create: (_) => InstrumentPositionStore()),
          ],
          child: const MaterialApp(
            home: AutomatedTradingApprovalsWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trading Approvals'), findsOneWidget);
      expect(find.text('All Caught Up!'), findsOneWidget);
      expect(find.text('Review Trading Strategy'), findsNothing);
    });

    testWidgets(
        'Renders proposal cards, summary metrics, and respects balance masking',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final provider = AgenticTradingProvider();
      final accountStore = AccountStore();

      provider.pendingOrders.add(_makeProposalMap(
        id: 'prop_nvda',
        symbol: 'NVDA',
        action: 'BUY',
        quantity: 10,
        price: 130.0,
        confidence: 90,
      ));
      provider.pendingOrders.add(_makeProposalMap(
        id: 'prop_tsla',
        symbol: 'TSLA',
        action: 'SELL',
        quantity: 5,
        price: 200.0,
        confidence: 75,
      ));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AgenticTradingProvider>.value(
                value: provider),
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
            ChangeNotifierProvider<BrokerageUserStore>(
                create: (_) => BrokerageUserStore([], 0)),
            ChangeNotifierProvider<PaperTradingStore>(
                create: (_) => PaperTradingStore()),
            ChangeNotifierProvider<QuoteStore>(create: (_) => QuoteStore()),
            ChangeNotifierProvider<InstrumentPositionStore>(
                create: (_) => InstrumentPositionStore()),
          ],
          child: const MaterialApp(
            home: AutomatedTradingApprovalsWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Summary header
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Capital Impact'), findsOneWidget);
      expect(find.text('Avg Confidence'), findsOneWidget);

      // Proposal cards
      expect(find.text('NVDA'), findsOneWidget);
      expect(find.text('TSLA'), findsOneWidget);
      expect(find.text('10 shares @ \$130.00'), findsOneWidget);
      expect(find.text('5 shares @ \$200.00'), findsOneWidget);

      // Now toggle showBalances off (mask balances)
      accountStore.toggleShowBalances();
      await tester.pumpAndSettle();

      // Capital values should now display masked string
      expect(find.text(r'$••••••'), findsWidgets);
    });

    testWidgets('Filters proposals by action (BUY vs SELL)',
        (WidgetTester tester) async {
      final provider = AgenticTradingProvider();
      final accountStore = AccountStore();

      provider.pendingOrders.add(_makeProposalMap(
        id: 'buy_1',
        symbol: 'GOOGL',
        action: 'BUY',
      ));
      provider.pendingOrders.add(_makeProposalMap(
        id: 'sell_1',
        symbol: 'META',
        action: 'SELL',
      ));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AgenticTradingProvider>.value(
                value: provider),
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
            ChangeNotifierProvider<BrokerageUserStore>(
                create: (_) => BrokerageUserStore([], 0)),
            ChangeNotifierProvider<PaperTradingStore>(
                create: (_) => PaperTradingStore()),
            ChangeNotifierProvider<QuoteStore>(create: (_) => QuoteStore()),
            ChangeNotifierProvider<InstrumentPositionStore>(
                create: (_) => InstrumentPositionStore()),
          ],
          child: const MaterialApp(
            home: AutomatedTradingApprovalsWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GOOGL'), findsOneWidget);
      expect(find.text('META'), findsOneWidget);

      // Tap 'BUY Only' filter chip
      await tester.tap(find.text('BUY Only'));
      await tester.pumpAndSettle();

      expect(find.text('GOOGL'), findsOneWidget);
      expect(find.text('META'), findsNothing);

      // Tap 'SELL Only' filter chip
      await tester.tap(find.text('SELL Only'));
      await tester.pumpAndSettle();

      expect(find.text('GOOGL'), findsNothing);
      expect(find.text('META'), findsOneWidget);
    });

    testWidgets('Switches to History tab and displays rejected/executed trades',
        (WidgetTester tester) async {
      final provider = AgenticTradingProvider();
      final accountStore = AccountStore();

      provider.autoTradeHistory.add({
        'symbol': 'AAPL',
        'action': 'BUY',
        'quantity': 15,
        'price': 175.0,
        'status': 'executed',
        'paperMode': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
      provider.autoTradeHistory.add({
        'symbol': 'NFLX',
        'action': 'SELL',
        'quantity': 5,
        'price': 650.0,
        'status': 'rejected',
        'rejected': true,
        'paperMode': true,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AgenticTradingProvider>.value(
                value: provider),
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
            ChangeNotifierProvider<BrokerageUserStore>(
                create: (_) => BrokerageUserStore([], 0)),
            ChangeNotifierProvider<PaperTradingStore>(
                create: (_) => PaperTradingStore()),
            ChangeNotifierProvider<QuoteStore>(create: (_) => QuoteStore()),
            ChangeNotifierProvider<InstrumentPositionStore>(
                create: (_) => InstrumentPositionStore()),
          ],
          child: const MaterialApp(
            home: AutomatedTradingApprovalsWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to History tab
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.text('AAPL'), findsOneWidget);
      expect(find.text('NFLX'), findsOneWidget);
      expect(find.text('REJECTED'), findsOneWidget);
    });

    testWidgets(
        'Opens directly to History tab with initialTabIndex: 1 and taps to inspect',
        (WidgetTester tester) async {
      final provider = AgenticTradingProvider();
      final accountStore = AccountStore();

      provider.autoTradeHistory.add({
        'symbol': 'TSLA',
        'action': 'BUY',
        'quantity': 10,
        'price': 220.0,
        'status': 'rejected',
        'rejected': true,
        'paperMode': true,
        'timestamp': DateTime.now().toIso8601String(),
        'proposal':
            _makeProposalMap(symbol: 'TSLA', quantity: 10, price: 220.0),
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AgenticTradingProvider>.value(
                value: provider),
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
            ChangeNotifierProvider<BrokerageUserStore>(
                create: (_) => BrokerageUserStore([], 0)),
            ChangeNotifierProvider<PaperTradingStore>(
                create: (_) => PaperTradingStore()),
            ChangeNotifierProvider<QuoteStore>(create: (_) => QuoteStore()),
            ChangeNotifierProvider<InstrumentPositionStore>(
                create: (_) => InstrumentPositionStore()),
            ChangeNotifierProvider<InstrumentStore>(
                create: (_) => InstrumentStore()),
          ],
          child: const MaterialApp(
            home: AutomatedTradingApprovalsWidget(initialTabIndex: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified direct start on History tab without clicking
      expect(find.text('TSLA'), findsOneWidget);
      expect(find.text('REJECTED'), findsOneWidget);

      // Tap TSLA history card to inspect details
      await tester.tap(find.text('TSLA'));
      await tester.pumpAndSettle();

      // Verifies inspection sheet opened
      expect(find.text('TSLA Proposal Details'), findsOneWidget);
      expect(find.text('AI Conviction & Reasoning'), findsOneWidget);
    });
  });

  group('AutomatedTradeProposalDetailWidget Tests', () {
    testWidgets('Renders all diagnostics, GEX levels, and RiskGuard metrics',
        (WidgetTester tester) async {
      final proposal = AutomatedTradeProposal.fromMap(_makeProposalMap(
        symbol: 'MSFT',
        quantity: 25,
        price: 420.0,
      ));
      final provider = AgenticTradingProvider();
      final accountStore = AccountStore();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AgenticTradingProvider>.value(
                value: provider),
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
            ChangeNotifierProvider<BrokerageUserStore>(
                create: (_) => BrokerageUserStore([], 0)),
            ChangeNotifierProvider<PaperTradingStore>(
                create: (_) => PaperTradingStore()),
            ChangeNotifierProvider<QuoteStore>(create: (_) => QuoteStore()),
            ChangeNotifierProvider<InstrumentPositionStore>(
                create: (_) => InstrumentPositionStore()),
            ChangeNotifierProvider<InstrumentStore>(
                create: (_) => InstrumentStore()),
          ],
          child: MaterialApp(
            home: AutomatedTradeProposalDetailWidget(
              proposal: proposal,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MSFT Proposal Details'), findsOneWidget);
      expect(find.text('25 shares @ \$420.00'), findsOneWidget);
      expect(find.text('AI Conviction & Reasoning'), findsOneWidget);
      expect(find.text('RiskGuard & Portfolio Safety'), findsOneWidget);
      expect(find.text('Gamma Exposure (GEX) Levels'), findsOneWidget);
      expect(find.text('Macro Economic Assessment'), findsOneWidget);

      // Buttons
      expect(find.text('Reject Proposal'), findsOneWidget);
      expect(find.text('Approve BUY Order'), findsOneWidget);
    });

    testWidgets(
        'AutomatedTradeProposalDetailWidget renders dynamic ATR stops, targets, and volatility ratchet',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final map = _makeProposalMap(
        id: 'prop_atr',
        symbol: 'NVDA',
        action: 'BUY',
        quantity: 10,
        price: 100.0,
      );
      (map['proposal'] as Map<String, dynamic>)['atr'] = 2.50;
      (map['proposal'] as Map<String, dynamic>)['atrStopMultiplier'] = 1.5;
      (map['proposal'] as Map<String, dynamic>)['atrProfitMultiplier'] = 3.0;
      (map['proposal'] as Map<String, dynamic>).remove('rewardRiskRatio');

      final proposal = AutomatedTradeProposal.fromMap(map);
      final provider = AgenticTradingProvider();
      final accountStore = AccountStore();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AgenticTradingProvider>.value(
                value: provider),
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
            ChangeNotifierProvider<BrokerageUserStore>(
                create: (_) => BrokerageUserStore([], 0)),
            ChangeNotifierProvider<PaperTradingStore>(
                create: (_) => PaperTradingStore()),
            ChangeNotifierProvider<QuoteStore>(create: (_) => QuoteStore()),
            ChangeNotifierProvider<InstrumentPositionStore>(
                create: (_) => InstrumentPositionStore()),
            ChangeNotifierProvider<InstrumentStore>(
                create: (_) => InstrumentStore()),
          ],
          child: MaterialApp(
            home: AutomatedTradeProposalDetailWidget(
              proposal: proposal,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Volatility-Adaptive Stops & Targets (ATR)'),
          findsOneWidget);
      expect(find.text('14-Period ATR'), findsOneWidget);
      expect(find.text(r'$2.50'), findsOneWidget);
      expect(find.text('Adaptive Stop Loss (1.5x ATR)'), findsOneWidget);
      expect(find.text(r'$96.25 (-3.8%)'), findsOneWidget);
      expect(find.text('Dynamic Profit Target (3.0x ATR)'), findsOneWidget);
      expect(find.text(r'$107.50 (+7.5%)'), findsOneWidget);
      expect(find.text('Volatility Ratchet'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('R:R 2.0'), findsOneWidget);
    });
  });
}
