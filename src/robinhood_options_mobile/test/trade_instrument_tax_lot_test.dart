import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/order_template.dart';
import 'package:robinhood_options_mobile/model/order_template_store.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/tax_lot.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/tax_lot_selection_sheet.dart';
import 'package:robinhood_options_mobile/widgets/trade_instrument_widget.dart';
import 'firebase_mocks.dart';

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {
  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    AnalyticsCallOptions? callOptions,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    List<AnalyticsEventItem>? items,
    AnalyticsCallOptions? callOptions,
  }) async {}
}

class FakeFirebaseAnalyticsObserver extends Fake
    implements FirebaseAnalyticsObserver {}

class MockOrderTemplateStore extends ChangeNotifier
    implements OrderTemplateStore {
  @override
  List<OrderTemplate> get templates => [];

  @override
  Future<void> loadTemplates(String userId) async {}

  @override
  Future<void> addTemplate(OrderTemplate template) async {}

  @override
  Future<void> deleteTemplate(String id) async {}

  @override
  OrderTemplate? getTemplateByName(String name) => null;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setupFirebaseMocks();
  });

  final now = DateTime.now();

  final testLots = [
    TaxLot(
      id: 'lot_1',
      symbol: 'AAPL',
      quantity: 10,
      quantityAvailable: 10,
      costPerShare: 130,
      openDate: now.subtract(const Duration(days: 400)),
      term: 'lt',
    ),
    TaxLot(
      id: 'lot_2',
      symbol: 'AAPL',
      quantity: 20,
      quantityAvailable: 20,
      costPerShare: 175,
      openDate: now.subtract(const Duration(days: 100)),
      term: 'st',
    ),
    TaxLot(
      id: 'lot_3',
      symbol: 'AAPL',
      quantity: 15,
      quantityAvailable: 15,
      costPerShare: 190,
      openDate: now.subtract(const Duration(days: 20)),
      term: 'st',
    ),
  ];

  group('TaxLotSelectionSheet Widget Tests', () {
    testWidgets('Renders lots and handles share allocation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Map<String, double>? savedAllocations;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaxLotSelectionSheet(
              symbol: 'AAPL',
              orderQuantity: 15,
              currentPrice: 160,
              taxLots: testLots,
              initialAllocations: const {},
              onAllocationsSaved: (allocations) {
                savedAllocations = allocations;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and symbols
      expect(find.text('Specific Tax Lot Matching'), findsOneWidget);
      expect(find.text('Target: 15 shares of AAPL'), findsOneWidget);

      // Tap 'Max' on the first lot (10 shares available)
      final maxButtons = find.text('Max');
      expect(maxButtons, findsNWidgets(3));
      await tester.tap(maxButtons.first);
      await tester.pumpAndSettle();

      // Progress card should reflect 10 / 15 shares
      expect(find.text('Allocated Shares'), findsOneWidget);
      expect(find.text('10 / 15'), findsOneWidget);

      // Save allocations button should be disabled because total != 15
      final saveButton = find.widgetWithText(FilledButton, 'Allocate 15 Shares to Confirm');
      expect(saveButton, findsOneWidget);

      // Tap 'Max' on lot 2 to fill remaining 5 shares
      await tester.tap(maxButtons.at(1));
      await tester.pumpAndSettle();

      // Total is now 15 shares
      expect(find.text('15 / 15'), findsOneWidget);

      // Confirm button is now enabled
      final completeSaveButton = find.widgetWithText(FilledButton, 'Confirm Specified Lots');
      expect(completeSaveButton, findsOneWidget);

      await tester.tap(completeSaveButton);
      await tester.pumpAndSettle();

      expect(savedAllocations, isNotNull);
      expect(savedAllocations!['lot_1'], 10.0);
      expect(savedAllocations!['lot_2'], 5.0);
    });
  });

  group('TradeInstrumentWidget Tax Lot Matching UI Tests', () {
    testWidgets('Displays Tax Lot Matching section on Sell orders with initial strategy', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final account = Account(
        'https://api.robinhood.com/accounts/DEMO1234/',
        18000.0,
        'DEMO1234',
        'margin',
        18000.0,
        'level_3',
        0.0,
        0.0,
        0.0,
      );

      final brokerageUser = BrokerageUser(
        BrokerageSource.demo,
        'demo_user',
        null,
        null,
        accounts: [account],
      );

      final accountStore = AccountStore();
      accountStore.add(account);

      final orderTemplateStore = MockOrderTemplateStore();
      final agenticProvider = AgenticTradingProvider();
      final paperTradingStore = PaperTradingStore();

      final instrument = Instrument(
        id: 'aapl_inst',
        url: 'https://api.robinhood.com/instruments/aapl_inst/',
        quote: '',
        fundamentals: '',
        splits: '',
        state: 'active',
        market: '',
        simpleName: 'Apple',
        name: 'Apple Inc.',
        tradeable: true,
        tradability: 'tradable',
        symbol: 'AAPL',
        bloombergUnique: '',
        marginInitialRatio: 0.5,
        maintenanceRatio: 0.25,
        country: 'US',
        type: 'stock',
        fractionalTradability: 'tradable',
        rhsTradability: 'tradable',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: DateTime(2025, 1, 1),
        quoteObj: Quote(
          askPrice: 150.0,
          askSize: 0,
          bidPrice: 150.0,
          bidSize: 0,
          lastTradePrice: 150.0,
          lastExtendedHoursTradePrice: 150.0,
          previousClose: 150.0,
          adjustedPreviousClose: 150.0,
          previousCloseDate: DateTime(2026, 1, 1),
          symbol: 'AAPL',
          tradingHalted: false,
          hasTraded: true,
          lastTradePriceSource: 'test',
          updatedAt: DateTime(2026, 1, 2),
          instrument: '',
          instrumentId: 'AAPL',
        ),
      );

      final position = InstrumentPosition.fromJson({
        'url': 'https://api.robinhood.com/positions/aapl_inst/',
        'instrument': 'https://api.robinhood.com/instruments/aapl_inst/',
        'account': 'DEMO1234',
        'account_number': 'DEMO1234',
        'average_buy_price': '140.0',
        'quantity': '25.0',
        'avg_cost_affected': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      position.instrumentObj = instrument;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AccountStore>.value(value: accountStore),
            ChangeNotifierProvider<OrderTemplateStore>.value(value: orderTemplateStore),
            ChangeNotifierProvider<AgenticTradingProvider>.value(value: agenticProvider),
            ChangeNotifierProvider<PaperTradingStore>.value(value: paperTradingStore),
          ],
          child: MaterialApp(
            home: TradeInstrumentWidget(
              brokerageUser,
              DemoService(),
              instrument: instrument,
              stockPosition: position,
              positionType: 'Sell',
              initialTaxLotStrategy: TaxLotStrategy.hifo,
              analytics: FakeFirebaseAnalytics(),
              observer: FakeFirebaseAnalyticsObserver(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The Tax Lot Matching section should be visible for Sell orders
      expect(find.text('Tax Lot Matching'), findsOneWidget);
      expect(find.text(TaxLotStrategy.hifo.displayName), findsOneWidget);

      // Verify that "Preview Order" button exists
      final previewButton = find.text('Preview Order');
      expect(previewButton, findsOneWidget);
    });
  });
}
