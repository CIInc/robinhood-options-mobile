import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_greeks_card.dart';

Quote _makeQuote(String symbol, double price) {
  return Quote.fromJson({
    'symbol': symbol,
    'last_trade_price': price.toString(),
    'ask_price': price.toString(),
    'bid_price': price.toString(),
    'ask_size': 100,
    'bid_size': 100,
    'trading_halted': 'false',
    'has_traded': 'true',
    'last_trade_price_source': 'consolidated',
    'instrument': 'https://api.robinhood.com/instruments/$symbol/',
    'instrument_id': symbol,
  });
}

InstrumentPosition _makeStockPosition({
  required String symbol,
  required double quantity,
  required double price,
}) {
  final pos = InstrumentPosition.fromJson({
    'url': 'https://api.robinhood.com/positions/$symbol/',
    'instrument': 'https://api.robinhood.com/instruments/$symbol/',
    'account': 'acc_1',
    'account_number': 'acc_1',
    'average_buy_price': price.toString(),
    'quantity': quantity.toString(),
    'avg_cost_affected': false,
  });
  pos.instrumentObj = Instrument.forSymbol(symbol)
    ..quoteObj = _makeQuote(symbol, price);
  return pos;
}

OptionAggregatePosition _makeCallOption({
  required String symbol,
  required double contracts,
  required double strike,
  required double spot,
  required double delta,
}) {
  final underlying = Instrument.forSymbol(symbol)
    ..quoteObj = _makeQuote(symbol, spot);

  final optionInstrument = OptionInstrument.fromJson({
    'id': 'opt-$symbol',
    'chain_id': 'c-$symbol',
    'symbol': symbol,
    'url': '',
    'expiration_date': '2026-12-31',
    'strike_price': strike.toString(),
    'type': 'call',
    'chain_symbol': symbol,
    'min_ticks': <String, dynamic>{},
    'rhs_tradability': 'tradable',
    'state': 'active',
    'tradability': 'tradable',
    'long_strategy_code': 'buy',
    'short_strategy_code': 'sell',
    'option_market_data': {
      'instrument': 'opt-$symbol',
      'instrument_id': 'opt-$symbol',
      'last_trade_size': 1,
      'bid_size': 100,
      'ask_size': 100,
      'open_interest': 1000,
      'volume': 100,
      'symbol': symbol,
      'occ_symbol': '${symbol}261231C00000000',
      'delta': delta.toString(),
      'gamma': '0.05',
      'theta': '-0.20',
      'vega': '0.30',
    },
  });

  return OptionAggregatePosition(
    'pos-$symbol',
    'c-$symbol',
    'acc_1',
    symbol,
    'call',
    5.0,
    [],
    contracts,
    null,
    null,
    'debit',
    '',
    100.0,
    null,
    null,
    'long_call',
  )
    ..instrumentObj = underlying
    ..optionInstrument = optionInstrument;
}

void main() {
  group('PortfolioGreeksCard Widget', () {
    testWidgets('renders empty state when no positions are provided',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PortfolioGreeksCard(positions: []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Beta-Weighted Greeks'), findsOneWidget);
      expect(
        find.text(
            'No priced positions available to compute Beta-Weighted Greeks.'),
        findsOneWidget,
      );
    });

    testWidgets('renders beta-weighted exposure, benchmark chips, and drivers',
        (tester) async {
      final stock = _makeStockPosition(
        symbol: 'AAPL',
        quantity: 100.0,
        price: 150.0,
      );
      final option = _makeCallOption(
        symbol: 'NVDA',
        contracts: 2.0,
        strike: 120.0,
        spot: 120.0,
        delta: 0.50,
      );

      String? selectedBenchmark;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PortfolioGreeksCard(
                positions: [option],
                equityPositions: [stock],
                benchmarkSymbol: 'SPY',
                benchmarkPrice: 500.0,
                onBenchmarkChanged: (b) => selectedBenchmark = b,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and view mode
      expect(find.text('Beta-Weighted Greeks'), findsOneWidget);
      expect(find.text('Beta-Weighted'), findsOneWidget);
      expect(find.text('Raw Greeks'), findsOneWidget);

      // Check benchmark selector chips
      expect(find.text('SPY'), findsOneWidget);
      expect(find.text('QQQ'), findsOneWidget);
      expect(find.text('DIA'), findsOneWidget);
      expect(find.text('IWM'), findsOneWidget);

      // Check Net Market Exposure hero section
      expect(find.text('Net Market Exposure (Δ_SPY)'), findsOneWidget);
      expect(find.text('SPY shares equiv'), findsOneWidget);
      expect(find.text('Bullish'), findsOneWidget);

      // Check Greek tiles
      expect(find.text('Delta (1% Move)'), findsOneWidget);
      expect(find.text('Theta (Daily)'), findsOneWidget);
      expect(find.text('Vega (1% IV)'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);

      // Check Asset Class breakdown
      expect(find.text('Delta by Asset Class'), findsOneWidget);
      expect(find.text('Stocks'), findsOneWidget);
      expect(find.text('Options'), findsOneWidget);

      // Check Top Delta Drivers
      expect(find.text('Top Delta Drivers'), findsOneWidget);
      expect(find.text('AAPL'), findsOneWidget);
      expect(find.text('NVDA (Opt)'), findsOneWidget);

      // Tap QQQ benchmark chip
      await tester.tap(find.text('QQQ'));
      await tester.pumpAndSettle();
      expect(selectedBenchmark, 'QQQ');
      expect(find.text('Net Market Exposure (Δ_QQQ)'), findsOneWidget);

      // Tap Raw Greeks segmented button
      await tester.tap(find.text('Raw Greeks'));
      await tester.pumpAndSettle();
      expect(find.text('Portfolio Greeks'), findsOneWidget);
      expect(find.text('Net sensitivity across priced option positions'),
          findsOneWidget);
    });

    testWidgets('opens explanation guide bottom sheet', (tester) async {
      final stock = _makeStockPosition(
        symbol: 'AAPL',
        quantity: 50.0,
        price: 150.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PortfolioGreeksCard(
              positions: const [],
              equityPositions: [stock],
              benchmarkPrice: 500.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap info button
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      // Expect bottom sheet content
      expect(find.text('Beta-Weighted Greeks Guide'), findsOneWidget);
      expect(find.text('What is Beta-Weighted Delta (Δ_SPY)?'), findsOneWidget);
      expect(find.text('Key Formulas'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Interpreting Portfolio Stance'),
        50.0,
      );
      expect(find.text('Interpreting Portfolio Stance'), findsOneWidget);
    });

    testWidgets(
        'renders without RenderFlex overflow in a narrow 320px viewport',
        (tester) async {
      tester.view.physicalSize = const Size(322, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final stock = _makeStockPosition(
        symbol: 'AAPL',
        quantity: 100.0,
        price: 150.0,
      );
      final option = _makeCallOption(
        symbol: 'NVDA',
        contracts: 2.0,
        strike: 120.0,
        spot: 120.0,
        delta: 0.50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 322,
                child: PortfolioGreeksCard(
                  positions: [option],
                  equityPositions: [stock],
                  benchmarkSymbol: 'SPY',
                  benchmarkPrice: 500.0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Benchmark:'), findsOneWidget);
      expect(find.text('SPY'), findsOneWidget);
      expect(find.text('QQQ'), findsOneWidget);
      expect(find.text('DIA'), findsOneWidget);
      expect(find.text('IWM'), findsOneWidget);
    });
  });
}
