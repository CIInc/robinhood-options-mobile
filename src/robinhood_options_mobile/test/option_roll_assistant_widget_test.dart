import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/option_roll_assistant_widget.dart';

class MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {
  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object?>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}
}

class MockFirebaseAnalyticsObserver extends Mock
    implements FirebaseAnalyticsObserver {}

class MockGenerativeService extends Mock implements GenerativeService {}

class TestBrokerageService extends Fake implements IBrokerageService {
  final OptionChain chain;
  final List<OptionInstrument> contracts;
  List<Map<String, dynamic>>? lastPlacedLegs;

  TestBrokerageService(this.chain, this.contracts);

  @override
  Future<OptionChain> getOptionChains(BrokerageUser user, String id) async {
    return chain;
  }

  @override
  Stream<List<OptionInstrument>> streamOptionInstruments(
    BrokerageUser user,
    OptionInstrumentStore store,
    Instrument instrument,
    String? expirationDates,
    String? type, {
    String? state = "active",
    bool includeMarketData = false,
  }) async* {
    yield contracts;
  }

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
    lastPlacedLegs = legs;
    return {'id': 'order_123', 'state': 'filled'};
  }
}

void main() {
  final now = DateTime.now();
  final exp1 = now.add(const Duration(days: 7));
  final exp2 = now.add(const Duration(days: 35));

  OptionInstrument makeOption({
    required String id,
    required String symbol,
    required String type,
    required double strike,
    required DateTime expiration,
    double mark = 1.0,
    double bid = 0.95,
    double ask = 1.05,
    double delta = 0.30,
    double theta = -0.05,
  }) {
    final instr = OptionInstrument.fromJson({
      'chain_id': 'chain_$symbol',
      'chain_symbol': symbol,
      'expiration_date': expiration.toIso8601String().split('T').first,
      'id': id,
      'min_ticks': {'above_tick': 0.05, 'below_tick': 0.01, 'cutoff_price': 3.0},
      'rhs_tradability': 'tradable',
      'state': 'active',
      'strike_price': strike.toString(),
      'tradability': 'tradable',
      'type': type,
      'url': 'url_$id',
      'long_strategy_code': '',
      'short_strategy_code': '',
    });
    instr.optionMarketData = OptionMarketData.fromJson({
      'adjusted_mark_price': mark.toString(),
      'ask_price': ask.toString(),
      'ask_size': 10,
      'bid_price': bid.toString(),
      'bid_size': 10,
      'break_even_price': strike.toString(),
      'instrument': instr.url,
      'instrument_id': instr.id,
      'last_trade_price': mark.toString(),
      'mark_price': mark.toString(),
      'open_interest': 100,
      'volume': 50,
      'symbol': symbol,
      'occ_symbol': '${symbol}_TEST',
      'delta': delta.toString(),
      'gamma': '0.02',
      'theta': theta.toString(),
      'vega': '0.15',
      'implied_volatility': '0.25',
    });
    return instr;
  }

  testWidgets('OptionRollAssistantWidget renders and computes roll metrics',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final oldOption = makeOption(
      id: 'old_call_150',
      symbol: 'AAPL',
      type: 'call',
      strike: 150.0,
      expiration: exp1,
      mark: 1.00,
      bid: 0.95,
      ask: 1.05,
      delta: 0.40,
    );

    final targetOption1 = makeOption(
      id: 'target_call_150',
      symbol: 'AAPL',
      type: 'call',
      strike: 150.0,
      expiration: exp2,
      mark: 2.50,
      bid: 2.40,
      ask: 2.60,
      delta: 0.45,
    );

    final targetOption2 = makeOption(
      id: 'target_call_155',
      symbol: 'AAPL',
      type: 'call',
      strike: 155.0,
      expiration: exp2,
      mark: 1.80,
      bid: 1.70,
      ask: 1.90,
      delta: 0.30,
    );

    final chain = OptionChain(
      'chain_AAPL',
      'AAPL',
      true,
      null,
      [exp1, exp2],
      100.0,
      MinTicks(0.01, 0.05, 3.0),
    );

    final service = TestBrokerageService(chain, [targetOption1, targetOption2]);

    final testUser = BrokerageUser(
      BrokerageSource.demo,
      'trader_1',
      null,
      null,
    );

    final leg = OptionLeg(
      'leg_1',
      null,
      'short',
      oldOption.url,
      'open',
      1,
      'sell',
      exp1,
      150.0,
      'call',
      [],
    );

    final position = OptionAggregatePosition(
      'pos_1',
      'chain_AAPL',
      'acct_1',
      'AAPL',
      'covered_call',
      200.0,
      [leg],
      1.0,
      null,
      null,
      'credit',
      '',
      100.0,
      now,
      now,
      'covered_call',
    );
    position.optionInstrument = oldOption;

    final instrument = Instrument.fromJson({
      'id': 'aapl_id',
      'url': 'url_aapl',
      'quote': 'quote_aapl',
      'fundamentals': 'fund_aapl',
      'splits': 'splits_aapl',
      'state': 'active',
      'market': 'nasdaq',
      'name': 'Apple Inc.',
      'tradeable': true,
      'tradability': 'tradable',
      'symbol': 'AAPL',
      'bloomberg_unique': 'unique',
      'country': 'US',
      'type': 'stock',
      'rhs_tradability': 'tradable',
      'fractional_tradability': 'tradable',
      'default_to_sub_day_trading': false,
      'is_spac': false,
      'is_test': false,
      'ipo_access_supports_dsp': false,
      'extended_hours_fractional_trading_enabled': false,
    });

    final accountStore = AccountStore();
    accountStore.add(Account(
      'url_acct',
      10000.0,
      'acct_1',
      'margin',
      25000.0,
      'tier_3',
      5000.0,
      0.0,
      0.0,
    ));

    final optionStore = OptionInstrumentStore();
    final paperStore = PaperTradingStore(firestore: FakeFirebaseFirestore());
    final mockAnalytics = MockFirebaseAnalytics();
    final agenticProvider = AgenticTradingProvider(analytics: mockAnalytics);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: accountStore),
          ChangeNotifierProvider.value(value: optionStore),
          ChangeNotifierProvider.value(value: paperStore),
          ChangeNotifierProvider.value(value: agenticProvider),
        ],
        child: MaterialApp(
          home: OptionRollAssistantWidget(
            user: testUser,
            service: service,
            instrument: instrument,
            optionPosition: position,
            optionInstrument: oldOption,
            analytics: MockFirebaseAnalytics(),
            observer: MockFirebaseAnalyticsObserver(),
            generativeService: MockGenerativeService(),
            appUser: null,
            userDocRef: null,
            underlyingCostBasis: 148.0,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Header
    expect(find.text('Options Roll Assistant'), findsOneWidget);
    expect(find.text('AAPL'), findsWidgets);
    expect(find.text('Apple Inc.'), findsOneWidget);

    // Verify Strategy Badge
    expect(find.text('Covered Call (Short Call)'), findsOneWidget);

    // Verify Current Leg card
    expect(find.text('Current Leg (Closing)'), findsOneWidget);
    expect(find.text('Buy to Close'), findsOneWidget);
    expect(find.text('\$150.0 CALL'), findsOneWidget);

    // Verify Presets exist
    expect(find.text('Roll Out (Same Strike)'), findsOneWidget);
    expect(find.text('Roll Up & Out (+Strike)'), findsOneWidget);
    expect(find.text('Custom Roll'), findsOneWidget);

    // Verify Financial Analysis card
    expect(find.text('Roll Financial Analysis'), findsOneWidget);
    expect(find.text('NET CREDIT'), findsWidgets);

    // Verify Greeks card
    expect(find.text('Greeks & Exposure Shift'), findsOneWidget);
    expect(find.text('Delta (Δ)'), findsOneWidget);
    expect(find.text('Theta (θ)'), findsOneWidget);

    // Verify Order Configuration
    expect(find.text('Order Configuration'), findsOneWidget);
    expect(find.text('Contracts'), findsOneWidget);
    expect(find.textContaining('Leg 1: Close'), findsOneWidget);
    expect(find.textContaining('Leg 2: Open'), findsOneWidget);

    // Tap Roll Up & Out preset
    await tester.tap(find.text('Roll Up & Out (+Strike)'));
    await tester.pumpAndSettle();

    // Verify target strike changed to 155.0
    expect(find.textContaining('Leg 2: Open 1x \$155.0 CALL'), findsOneWidget);

    // Verify strike selector allows custom selection back to 150.0
    await tester.tap(find.text('\$150.0').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Leg 2: Open 1x \$150.0 CALL'), findsOneWidget);
  });
}
