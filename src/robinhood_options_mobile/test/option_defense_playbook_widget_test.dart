import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/option_defense_playbook_widget.dart';

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
  @override
  Future<OptionChain> getOptionChains(BrokerageUser user, String id) async {
    return OptionChain(
      'chain_AAPL',
      'AAPL',
      true,
      null,
      [DateTime.now().add(const Duration(days: 30))],
      100.0,
      MinTicks(0.01, 0.05, 3.0),
    );
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
    yield [];
  }
}

OptionInstrument buildTestOptionInstrument({
  required String id,
  required String symbol,
  required String type,
  required double strikePrice,
  required DateTime expirationDate,
  required double markPrice,
  double delta = 0.50,
}) {
  final instr = OptionInstrument.fromJson({
    'chain_id': 'chain_$symbol',
    'chain_symbol': symbol,
    'expiration_date': expirationDate.toIso8601String().split('T').first,
    'id': id,
    'min_ticks': {'above_tick': 0.05, 'below_tick': 0.01, 'cutoff_price': 3.0},
    'rhs_tradability': 'tradable',
    'state': 'active',
    'strike_price': strikePrice.toString(),
    'tradability': 'tradable',
    'type': type,
    'url': 'url_$id',
    'long_strategy_code': '',
    'short_strategy_code': '',
  });
  instr.optionMarketData = OptionMarketData.fromJson({
    'adjusted_mark_price': markPrice.toString(),
    'ask_price': (markPrice + 0.05).toString(),
    'ask_size': 10,
    'bid_price': (markPrice - 0.05).toString(),
    'bid_size': 10,
    'break_even_price': strikePrice.toString(),
    'mark_price': markPrice.toString(),
    'symbol': symbol,
    'delta': delta.toString(),
    'instrument': instr.url,
    'instrument_id': instr.id,
    'last_trade_price': markPrice.toString(),
    'open_interest': 100,
    'volume': 50,
    'occ_symbol': '${symbol}_TEST',
  });
  return instr;
}

Quote buildTestQuote({required String symbol, required double lastTradePrice}) {
  return Quote.fromJson({
    'ask_price': lastTradePrice.toString(),
    'ask_size': 10,
    'bid_price': lastTradePrice.toString(),
    'bid_size': 10,
    'last_trade_price': lastTradePrice.toString(),
    'symbol': symbol,
    'last_trade_price_source': 'consolidated',
    'updated_at': DateTime.now().toIso8601String(),
    'instrument': 'url_$symbol',
    'instrument_id': 'inst_$symbol',
  });
}

void main() {
  testWidgets(
      'OptionDefensePlaybookWidget renders threat diagnostics and playbook cards',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();
    final expiration = now.add(const Duration(days: 8));

    final callOption = OptionInstrument.fromJson({
      'chain_id': 'chain_AAPL',
      'chain_symbol': 'AAPL',
      'expiration_date': expiration.toIso8601String().split('T').first,
      'id': 'call_aapl_180',
      'min_ticks': {
        'above_tick': 0.05,
        'below_tick': 0.01,
        'cutoff_price': 3.0
      },
      'rhs_tradability': 'tradable',
      'state': 'active',
      'strike_price': '180.0',
      'tradability': 'tradable',
      'type': 'call',
      'url': 'url_call_180',
      'long_strategy_code': '',
      'short_strategy_code': '',
    });
    callOption.optionMarketData = OptionMarketData.fromJson({
      'adjusted_mark_price': '3.20',
      'ask_price': '3.25',
      'ask_size': 10,
      'bid_price': '3.15',
      'bid_size': 10,
      'break_even_price': '182.50',
      'instrument': callOption.url,
      'instrument_id': callOption.id,
      'last_trade_price': '3.20',
      'mark_price': '3.20',
      'open_interest': 100,
      'volume': 50,
      'symbol': 'AAPL',
      'occ_symbol': 'AAPL_TEST',
      'delta': '0.65',
      'gamma': '0.03',
      'theta': '-0.07',
      'vega': '0.14',
      'implied_volatility': '0.24',
    });

    final leg = OptionLeg(
      'leg_1',
      null,
      'short',
      callOption.url,
      'open',
      1,
      'sell',
      expiration,
      180.0,
      'call',
      [],
    );

    final position = OptionAggregatePosition(
      'pos_1',
      'chain_AAPL',
      'acct_1',
      'AAPL',
      'Covered Call',
      150.0,
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
    position.optionInstrument = callOption;

    final instrument = Instrument.fromJson({
      'id': 'inst_aapl',
      'url': 'url_inst',
      'quote': 'quote_url',
      'fundamentals': 'fund_url',
      'splits': 'splits_url',
      'state': 'active',
      'market': 'nasdaq',
      'name': 'Apple Inc.',
      'tradeable': true,
      'tradability': 'tradable',
      'symbol': 'AAPL',
      'bloomberg_unique': 'bb_aapl',
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

    instrument.quoteObj = Quote.fromJson({
      'ask_price': '184.25',
      'ask_size': 10,
      'bid_price': '184.15',
      'bid_size': 10,
      'last_trade_price': '184.20', // Breaches $180.00 strike
      'last_extended_hours_trade_price': '184.20',
      'previous_close': '180.00',
      'adjusted_previous_close': '180.00',
      'previous_close_date': now.toIso8601String().split('T').first,
      'symbol': 'AAPL',
      'trading_halted': false,
      'has_traded': true,
      'last_trade_price_source': 'consolidated',
      'updated_at': now.toIso8601String(),
      'instrument': 'url_inst',
      'instrument_id': 'inst_aapl',
    });

    final user = BrokerageUser(
      BrokerageSource.robinhood,
      'test_user',
      null,
      null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OptionDefensePlaybookWidget(
          user: user,
          service: TestBrokerageService(),
          instrument: instrument,
          optionPosition: position,
          optionInstrument: callOption,
          analytics: MockFirebaseAnalytics(),
          observer: MockFirebaseAnalyticsObserver(),
          generativeService: MockGenerativeService(),
          appUser: null,
          userDocRef: null,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify AppBar
    expect(find.text('Defense Playbook'), findsOneWidget);
    expect(find.textContaining('AAPL'), findsWidgets);

    // Verify Threat Status Banner
    expect(find.textContaining('TESTED'), findsOneWidget);
    expect(find.text('BREACHED'), findsOneWidget);

    // Verify Metrics
    expect(find.text('Short Strike'), findsOneWidget);
    expect(find.text('Spot Price'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('DTE'), findsOneWidget);
    expect(find.text('Delta'), findsOneWidget);

    // Verify Threat Diagnostics Card
    expect(find.text('Threat Diagnostics'), findsOneWidget);

    // Verify Tactical Playbook Header & Actions
    expect(find.text('Tactical Playbook Actions'), findsOneWidget);
    expect(find.text('RECOMMENDED DEFENSE'), findsOneWidget);
    expect(find.text('Roll Up & Out'), findsOneWidget);
    expect(find.text('Roll Out in Time (Same Strike)'), findsOneWidget);

    // Verify Execute button
    expect(find.textContaining('Execute with Roll Assistant'), findsWidgets);

    // Verify Institutional Defense Rules
    expect(find.text('Institutional Options Defense Rules'), findsOneWidget);
  });

  testWidgets(
      'OptionDefensePlaybookWidget renders Ex-Dividend Early Assignment Hazard card',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();
    final expiration = now.add(const Duration(days: 20));

    final callOption = buildTestOptionInstrument(
      id: 'call_aapl_150',
      symbol: 'AAPL',
      type: 'call',
      strikePrice: 150.0,
      expirationDate: expiration,
      markPrice: 5.20,
      delta: 0.85,
    );

    final leg = OptionLeg(
      'leg_exdiv',
      null,
      'short',
      callOption.url,
      'open',
      1,
      'sell',
      expiration,
      150.0,
      'call',
      [],
    );

    final position = OptionAggregatePosition(
      'pos_exdiv',
      'chain_AAPL',
      'acct_1',
      'AAPL',
      'Covered Call',
      100.0,
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
    position.optionInstrument = callOption;

    final instrument = Instrument.fromJson({
      'id': 'inst_aapl',
      'url': 'url_inst',
      'symbol': 'AAPL',
      'name': 'Apple Inc.',
      'state': 'active',
      'tradeable': true,
      'tradability': 'tradable',
      'rhs_tradability': 'tradable',
      'fractional_tradability': 'tradable',
      'country': 'US',
      'type': 'stock',
    });

    instrument.quoteObj =
        buildTestQuote(symbol: 'AAPL', lastTradePrice: 155.00);

    final user = BrokerageUser(
      BrokerageSource.robinhood,
      'test_user',
      null,
      null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OptionDefensePlaybookWidget(
          user: user,
          service: TestBrokerageService(),
          instrument: instrument,
          optionPosition: position,
          optionInstrument: callOption,
          analytics: MockFirebaseAnalytics(),
          observer: MockFirebaseAnalyticsObserver(),
          generativeService: MockGenerativeService(),
          appUser: null,
          userDocRef: null,
          exDividendDate: now.add(const Duration(days: 3)),
          upcomingDividendAmount: 0.25, // Extrinsic 0.20 <= 1.25 * 0.25 = 0.3125
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('EX-DIVIDEND EARLY ASSIGNMENT HAZARD'), findsOneWidget);
    expect(find.text('EX-DIV HAZARD'), findsWidgets);
    expect(find.text('Roll Ahead of Ex-Dividend'), findsOneWidget);
  });

  testWidgets(
      'OptionDefensePlaybookWidget renders 0DTE/1DTE Pin Risk & Margin Shock card',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();
    final expiration = now; // 0 DTE

    final putOption = buildTestOptionInstrument(
      id: 'put_tsla_200',
      symbol: 'TSLA',
      type: 'put',
      strikePrice: 200.0,
      expirationDate: expiration,
      markPrice: 0.40,
      delta: -0.50,
    );

    final leg = OptionLeg(
      'leg_pin',
      null,
      'short',
      putOption.url,
      'open',
      5,
      'sell',
      expiration,
      200.0,
      'put',
      [],
    );

    final position = OptionAggregatePosition(
      'pos_pin',
      'chain_TSLA',
      'acct_1',
      'TSLA',
      'Cash-Secured Put',
      100.0,
      [leg],
      5.0, // 5 contracts -> Notional = 100 * 200 * 5 = $100,000
      null,
      null,
      'credit',
      '',
      100.0,
      now,
      now,
      'short_put',
    );
    position.optionInstrument = putOption;

    final instrument = Instrument.fromJson({
      'id': 'inst_tsla',
      'url': 'url_inst',
      'symbol': 'TSLA',
      'name': 'Tesla, Inc.',
      'state': 'active',
      'tradeable': true,
      'tradability': 'tradable',
      'rhs_tradability': 'tradable',
      'fractional_tradability': 'tradable',
      'country': 'US',
      'type': 'stock',
    });

    instrument.quoteObj =
        buildTestQuote(symbol: 'TSLA', lastTradePrice: 200.80);

    final user = BrokerageUser(
      BrokerageSource.robinhood,
      'test_user',
      null,
      null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OptionDefensePlaybookWidget(
          user: user,
          service: TestBrokerageService(),
          instrument: instrument,
          optionPosition: position,
          optionInstrument: putOption,
          analytics: MockFirebaseAnalytics(),
          observer: MockFirebaseAnalyticsObserver(),
          generativeService: MockGenerativeService(),
          appUser: null,
          userDocRef: null,
          availableBuyingPower: 45000.0, // Notional $100,000 > $45,000 -> Deficit $55,000
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('CRITICAL MARGIN SHOCK DEFICIT'), findsOneWidget);
    expect(find.text('MARGIN SHOCK'), findsWidgets);
    expect(find.text('Close Position'), findsWidgets);
    expect(find.text('Roll Out'), findsWidgets);
    expect(find.textContaining('Deficit: -\$55,000'), findsOneWidget);
  });
}
