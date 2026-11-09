import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/tail_risk_card.dart';

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

void main() {
  Widget buildTestWidget({
    required List<InstrumentPosition> positions,
    required List<OptionAggregatePosition> optionPositions,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TailRiskCard(
            positions: positions,
            optionPositions: optionPositions,
          ),
        ),
      ),
    );
  }

  testWidgets('renders empty state when holdings are unpriced', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(positions: [], optionPositions: []),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tail Risk & Liquidity'), findsOneWidget);
    expect(find.text('Risk assessment needs priced holdings.'), findsOneWidget);
  });

  testWidgets(
      'renders metrics and unified screen reader semantics when holdings are priced',
      (tester) async {
    final positions = [
      _makeStockPosition(symbol: 'AAPL', quantity: 100, price: 150),
    ];

    await tester.pumpWidget(
      buildTestWidget(positions: positions, optionPositions: []),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tail Risk & Liquidity'), findsOneWidget);
    expect(find.text('Downside screen and option exit conditions'),
        findsOneWidget);
    expect(find.text('20% downside screen'), findsOneWidget);
    expect(find.text('Liquidity score'), findsOneWidget);

    // Verify Semantics widgets provide unified labels for screen reader navigation
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!
                .startsWith('20% downside screen: -\$3,000'),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Liquidity score: 70/100',
      ),
      findsOneWidget,
    );
  });
}
