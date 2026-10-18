import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/multi_leg_order_entry.dart';
import 'package:robinhood_options_mobile/model/option_strategy.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/multi_leg_spread_builder_sheet.dart';
import 'package:robinhood_options_mobile/widgets/multi_leg_matrix_order_entry_widget.dart';

class _MockBrokerageService extends Fake implements IBrokerageService {
  final List<Map<String, dynamic>> placedOrders = [];
  Object? placeOrderError;

  @override
  Future<dynamic> placeMultiLegOptionsOrder(
    BrokerageUser user,
    Account account,
    List<Map<String, dynamic>> legs,
    String creditOrDebit,
    double price,
    int quantity, {
    String type = 'limit',
    String trigger = 'immediate',
    String timeInForce = 'gtc',
  }) async {
    if (placeOrderError != null) throw placeOrderError!;
    placedOrders.add({
      'user': user,
      'account': account,
      'legs': legs,
      'direction': creditOrDebit,
      'price': price,
      'quantity': quantity,
      'type': type,
      'trigger': trigger,
      'timeInForce': timeInForce,
    });
    return {'id': 'order_123', 'status': 'confirmed'};
  }
}

void main() {
  group('MultiLegOrderEntry model tests', () {
    test('creates Bull Call Spread with correct legs and metrics', () {
      final spread = MultiLegOrderEntry.bullCallSpread(
        symbol: 'AAPL',
        spotPrice: 150.0,
      );

      expect(spread.symbol, 'AAPL');
      expect(spread.strategyType, StrategyType.vertical);
      expect(spread.strategyName, 'Bull Call Spread');
      expect(spread.legs.length, 2);
      expect(spread.legs[0].isBuy, isTrue);
      expect(spread.legs[0].isCall, isTrue);
      expect(spread.legs[1].isSell, isTrue);
      expect(spread.legs[1].isCall, isTrue);
      expect(spread.isDebit, isTrue);
      expect(spread.estimatedTotal, greaterThan(0));
      expect(spread.maxProfitPerContract, isNotNull);
      expect(spread.maxLossPerContract, isNotNull);
      expect(spread.breakevens.length, 1);
    });

    test('creates Iron Condor with 4 legs and credit metrics', () {
      final condor = MultiLegOrderEntry.ironCondor(
        symbol: 'SPY',
        spotPrice: 500.0,
      );

      expect(condor.symbol, 'SPY');
      expect(condor.strategyType, StrategyType.ironCondor);
      expect(condor.strategyName, 'Iron Condor');
      expect(condor.legs.length, 4);
      expect(condor.isCredit, isTrue);
      expect(condor.maxProfitPerContract, greaterThan(0));
      expect(condor.maxLossPerContract, greaterThan(0));
      expect(condor.breakevens.length, 2);
    });

    test('creates Calendar Spreads with front-month short and back-month long', () {
      final now = DateTime.now();
      final nearExp = now.add(const Duration(days: 14));
      final farExp = now.add(const Duration(days: 45));

      final callCal = MultiLegOrderEntry.calendarSpread(
        symbol: 'TSLA',
        spotPrice: 200.0,
        type: LegType.call,
        nearExpiration: nearExp,
        farExpiration: farExp,
      );

      expect(callCal.strategyType, StrategyType.calendar);
      expect(callCal.strategyName, 'Call Calendar Spread');
      expect(callCal.legs.length, 2);
      // Short leg
      expect(callCal.legs[0].isSell, isTrue);
      expect(callCal.legs[0].isCall, isTrue);
      expect(callCal.legs[0].expirationDate, nearExp);
      // Long leg
      expect(callCal.legs[1].isBuy, isTrue);
      expect(callCal.legs[1].isCall, isTrue);
      expect(callCal.legs[1].expirationDate, farExp);
      expect(callCal.isDebit, isTrue);
      expect(callCal.maxLossPerContract, greaterThan(0));

      final putCal = MultiLegOrderEntry.calendarSpread(
        symbol: 'TSLA',
        spotPrice: 200.0,
        type: LegType.put,
      );
      expect(putCal.strategyName, 'Put Calendar Spread');
      expect(putCal.legs.every((l) => l.isPut), isTrue);
    });

    test('creates Short Straddle and Short Strangle', () {
      final sStraddle = MultiLegOrderEntry.shortStraddle(
        symbol: 'NVDA',
        spotPrice: 120.0,
      );
      expect(sStraddle.strategyType, StrategyType.shortStraddle);
      expect(sStraddle.legs.every((l) => l.isSell), isTrue);
      expect(sStraddle.isCredit, isTrue);

      final sStrangle = MultiLegOrderEntry.shortStrangle(
        symbol: 'NVDA',
        spotPrice: 120.0,
      );
      expect(sStrangle.strategyType, StrategyType.shortStrangle);
      expect(sStrangle.legs.every((l) => l.isSell), isTrue);
      expect(sStrangle.isCredit, isTrue);
    });

    test('converts to brokerage legs correctly', () {
      final spread = MultiLegOrderEntry.bullCallSpread(
        symbol: 'AAPL',
        spotPrice: 150.0,
      );
      final brokerageLegs = spread.toBrokerageLegs(
        urlResolver: (leg) => 'https://api.robinhood.com/options/instruments/opt_${leg.id}/',
        symbolResolver: (leg) => 'AAPL_${leg.strike}',
      );

      expect(brokerageLegs.length, 2);
      expect(brokerageLegs[0]['side'], 'buy');
      expect(brokerageLegs[0]['instruction'], 'BUY_TO_OPEN');
      expect(brokerageLegs[0]['option'], contains('opt_leg_bc_1'));
      expect(brokerageLegs[0]['symbol'], contains('AAPL_'));

      expect(brokerageLegs[1]['side'], 'sell');
      expect(brokerageLegs[1]['instruction'], 'SELL_TO_OPEN');
      expect(brokerageLegs[1]['option'], contains('opt_leg_bc_2'));
    });

    test('serializes and deserializes MultiLegOrderEntry to JSON', () {
      final original = MultiLegOrderEntry.calendarSpread(
        symbol: 'AMZN',
        spotPrice: 180.0,
        type: LegType.call,
      );
      final json = original.toJson();
      final restored = MultiLegOrderEntry.fromJson(json);

      expect(restored.symbol, original.symbol);
      expect(restored.strategyType, original.strategyType);
      expect(restored.strategyName, original.strategyName);
      expect(restored.legs.length, original.legs.length);
      expect(restored.legs[0].strike, original.legs[0].strike);
    });
  });

  group('MultiLegSpreadBuilderSheet Widget Tests', () {
    late Instrument testInstrument;
    late BrokerageUser testUser;
    late Account testAccount;
    late _MockBrokerageService mockService;

    Instrument makeTestInstrument({String symbol = 'AAPL', double price = 150.0}) {
      final inst = Instrument(
        id: 'id_$symbol',
        url: 'https://api.robinhood.com/instruments/$symbol/',
        quote: 'quote',
        fundamentals: 'fundamentals',
        splits: 'splits',
        state: 'active',
        market: 'market',
        name: '$symbol Inc.',
        tradeable: true,
        tradability: 'tradable',
        symbol: symbol,
        bloombergUnique: 'bloombergUnique',
        country: 'US',
        type: 'stock',
        rhsTradability: 'tradable',
        fractionalTradability: 'tradable',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: DateTime.now(),
      );
      inst.quoteObj = Quote(
        symbol: symbol,
        askSize: 100,
        bidSize: 100,
        lastTradePrice: price,
        tradingHalted: false,
        hasTraded: true,
        lastTradePriceSource: 'consolidated',
        instrument: 'https://api.robinhood.com/instruments/$symbol/',
        instrumentId: 'id_$symbol',
      );
      return inst;
    }

    setUp(() {
      testInstrument = makeTestInstrument(symbol: 'AAPL', price: 150.0);
      testUser = BrokerageUser(BrokerageSource.schwab, 'user_1', null, null);
      testAccount = Account(
        'acc_url',
        10000.0,
        'SCHWAB-9876',
        'margin',
        5000.0,
        'option_level_3',
        10000.0,
        10000.0,
        5000.0,
      );
      mockService = _MockBrokerageService();
    });

    Widget createTestApp(Widget child) {
      final accountStore = AccountStore();
      accountStore.add(testAccount);
      accountStore.setSelectedAccountNumber('SCHWAB-9876');

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AccountStore>.value(value: accountStore),
        ],
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('renders spread builder sheet with templates and metrics',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          MultiLegSpreadBuilderSheet(
            instrument: testInstrument,
            service: mockService,
            user: testUser,
            account: testAccount,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Spread Builder • AAPL'), findsOneWidget);
      expect(find.text('STRATEGY TEMPLATES'), findsOneWidget);
      expect(find.text('Bull Call Spread'), findsWidgets);
      expect(find.text('Net Order Price'), findsOneWidget);
      expect(find.text('Max Profit'), findsOneWidget);
      expect(find.text('Max Loss'), findsOneWidget);
      expect(find.text('STRATEGY LEGS (2)'), findsOneWidget);
      expect(find.byKey(const ValueKey('review-spread-order')), findsOneWidget);
    });

    testWidgets('switching templates updates legs and strategy metrics',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          MultiLegSpreadBuilderSheet(
            instrument: testInstrument,
            service: mockService,
            user: testUser,
            account: testAccount,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Iron Condor template chip
      final ironCondorChip =
          find.byKey(const ValueKey('template-iron-condor'));
      expect(ironCondorChip, findsOneWidget);
      await tester.ensureVisible(ironCondorChip);
      await tester.pumpAndSettle();
      await tester.tap(ironCondorChip);
      await tester.pumpAndSettle();

      expect(find.text('Iron Condor'), findsWidgets);
      expect(find.text('STRATEGY LEGS (4)'), findsOneWidget);
      expect(find.text('CREDIT'), findsWidgets);

      // Tap Call Calendar Spread
      final calendarChip =
          find.byKey(const ValueKey('template-call-calendar-spread'));
      expect(calendarChip, findsOneWidget);
      await tester.ensureVisible(calendarChip);
      await tester.pumpAndSettle();
      await tester.tap(calendarChip);
      await tester.pumpAndSettle();

      expect(find.text('Call Calendar Spread'), findsWidgets);
      expect(find.text('STRATEGY LEGS (2)'), findsOneWidget);
      expect(find.text('DEBIT'), findsWidgets);
    });

    testWidgets('reviews and submits multi-leg spread order to brokerage',
        (tester) async {
      MultiLegOrderEntry? placedOrder;
      await tester.pumpWidget(
        createTestApp(
          MultiLegSpreadBuilderSheet(
            instrument: testInstrument,
            service: mockService,
            user: testUser,
            account: testAccount,
            onOrderPlaced: (order) => placedOrder = order,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to order parameters section and change quantity to 2
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('spread-quantity')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
          find.byKey(const ValueKey('spread-quantity')), '2');
      await tester.pumpAndSettle();

      // Tap Review Order
      await tester.tap(find.byKey(const ValueKey('review-spread-order')));
      await tester.pumpAndSettle();

      // Confirmation dialog should be visible
      expect(find.text('Confirm Bull Call Spread'), findsOneWidget);
      expect(find.text('Contracts: 2'), findsOneWidget);
      expect(find.textContaining('SCHWAB-9876'), findsOneWidget);
      expect(mockService.placedOrders, isEmpty);

      // Confirm and place order
      await tester.tap(find.byKey(const ValueKey('confirm-spread-order')));
      await tester.pumpAndSettle();

      expect(mockService.placedOrders.length, 1);
      final placed = mockService.placedOrders.first;
      expect(placed['quantity'], 2);
      expect(placed['direction'], 'debit');
      expect((placed['legs'] as List).length, 2);
      expect(placedOrder, isNotNull);
    });

    testWidgets('surfaces error when brokerage order placement fails',
        (tester) async {
      mockService.placeOrderError = Exception('Margin limit exceeded');

      await tester.pumpWidget(
        createTestApp(
          MultiLegSpreadBuilderSheet(
            instrument: testInstrument,
            service: mockService,
            user: testUser,
            account: testAccount,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('review-spread-order')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('confirm-spread-order')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Margin limit exceeded'), findsWidgets);
    });
  });

  group('MultiLegMatrixOrderEntryWidget Tests', () {
    late Instrument testInstrument;
    late BrokerageUser testUser;
    late Account testAccount;
    late _MockBrokerageService mockService;

    setUp(() {
      testInstrument = Instrument(
        id: 'id_AAPL',
        url: 'https://api.robinhood.com/instruments/AAPL/',
        quote: 'quote',
        fundamentals: 'fundamentals',
        splits: 'splits',
        state: 'active',
        market: 'market',
        name: 'Apple Inc.',
        tradeable: true,
        tradability: 'tradable',
        symbol: 'AAPL',
        bloombergUnique: 'bloombergUnique',
        country: 'US',
        type: 'stock',
        rhsTradability: 'tradable',
        fractionalTradability: 'tradable',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: DateTime.now(),
      );
      testInstrument.quoteObj = const Quote(
        symbol: 'AAPL',
        askSize: 100,
        bidSize: 100,
        lastTradePrice: 150.0,
        tradingHalted: false,
        hasTraded: true,
        lastTradePriceSource: 'consolidated',
        instrument: 'https://api.robinhood.com/instruments/AAPL/',
        instrumentId: 'id_AAPL',
      );
      testUser =
          BrokerageUser(BrokerageSource.robinhood, 'user_rh', null, null);
      testAccount = Account(
        'acc_rh',
        5000.0,
        'RH-1234',
        'margin',
        2500.0,
        'option_level_3',
        5000.0,
        5000.0,
        2500.0,
      );
      mockService = _MockBrokerageService();
    });

    testWidgets('supports Calendar and Short spread presets in matrix view',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiLegMatrixOrderEntryWidget(
              instrument: testInstrument,
              service: mockService,
              user: testUser,
              account: testAccount,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bull Call Spread'), findsWidgets);

      // Open strategy preset dropdown
      await tester.tap(find.byType(DropdownButton<String>).first);
      await tester.pumpAndSettle();

      // Check new presets exist
      expect(find.text('Call Calendar Spread').last, findsOneWidget);
      expect(find.text('Short Straddle').last, findsOneWidget);
      expect(find.text('Short Strangle').last, findsOneWidget);

      // Select Call Calendar Spread
      await tester.tap(find.text('Call Calendar Spread').last);
      await tester.pumpAndSettle();

      expect(find.text('Call Calendar Spread'), findsWidgets);
    });
  });
}
