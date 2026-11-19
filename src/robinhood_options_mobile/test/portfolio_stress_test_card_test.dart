import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_stress_test_card.dart';

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
  Widget buildTestWidget({required List<InstrumentPosition> positions}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PortfolioStressTestCard(positions: positions),
        ),
      ),
    );
  }

  group('PortfolioStressTestCard Widget', () {
    testWidgets('renders empty state when positions are unpriced',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(positions: []));
      await tester.pumpAndSettle();

      expect(find.text('Stress Test'), findsOneWidget);
      expect(
          find.text('Projected impact of broad market moves'), findsOneWidget);
      expect(
          find.text('Stress testing needs priced holdings.'), findsOneWidget);
    });

    testWidgets(
        'renders net priced exposure and scenario tiles with unified semantics',
        (tester) async {
      final positions = [
        _makeStockPosition(symbol: 'AAPL', quantity: 100, price: 150),
      ];

      await tester.pumpWidget(buildTestWidget(positions: positions));
      await tester.pumpAndSettle();

      expect(find.text('Stress Test'), findsOneWidget);
      expect(find.text('Net priced exposure'), findsOneWidget);
      expect(find.text('\$15,000.00'), findsOneWidget);

      // Verify unified semantics for Net priced exposure
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Net priced exposure: \$15,000.00' &&
              widget.excludeSemantics == true,
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Net priced exposure: \$15,000.00'),
        findsOneWidget,
      );

      // Verify scenario tile labels and excludeSemantics: true
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Down 20 percent market scenario, -\$3,000.00 projected change' &&
              widget.excludeSemantics == true,
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
            'Down 20 percent market scenario, -\$3,000.00 projected change'),
        findsOneWidget,
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Up 20 percent market scenario, +\$3,000.00 projected change' &&
              widget.excludeSemantics == true,
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
            'Up 20 percent market scenario, +\$3,000.00 projected change'),
        findsOneWidget,
      );
    });
  });
}
