import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/services/live_activity_service.dart';
import 'package:robinhood_options_mobile/widgets/option_live_activity_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OptionAggregatePosition createMockPosition({
    required String symbol,
    required double strike,
    required DateTime expiration,
    required double markPrice,
    String direction = 'debit',
    String type = 'call',
  }) {
    final instrument = OptionInstrument(
      'chain_123',
      symbol,
      DateTime.now().subtract(const Duration(days: 10)),
      expiration,
      'opt_inst_1',
      null,
      const MinTicks(0.01, 0.05, 3.0),
      'tradable',
      'active',
      strike,
      'tradable',
      type,
      DateTime.now(),
      '',
      null,
      '',
      '',
    );

    instrument.optionMarketData = OptionMarketData(
      markPrice, // adjustedMarkPrice
      markPrice + 0.05, // askPrice
      10, // askSize
      markPrice - 0.05, // bidPrice
      10, // bidSize
      strike + markPrice, // breakEvenPrice
      markPrice * 1.1, // highPrice
      'opt_inst_1', // instrument
      'opt_inst_1', // instrumentId
      markPrice, // lastTradePrice
      5, // lastTradeSize
      markPrice * 0.9, // lowPrice
      markPrice, // markPrice
      1000, // openInterest
      DateTime.now().subtract(const Duration(days: 1)), // previousCloseDate
      markPrice * 0.9, // previousClosePrice
      500, // volume
      symbol, // symbol
      '${symbol}261016C00580000', // occSymbol
      0.55, // chanceOfProfitLong
      0.45, // chanceOfProfitShort
      0.50, // delta
      0.05, // gamma
      0.25, // impliedVolatility
      0.01, // rho
      -0.02, // theta
      0.05, // vega
      null,
      null,
      null,
      null,
      DateTime.now(),
    );

    return OptionAggregatePosition(
      'pos_$symbol',
      'chain_123',
      'acct_123',
      symbol,
      type,
      markPrice * 100, // averageOpenPrice
      [
        OptionLeg('leg_1', null, 'long', 'opt_inst_1', null, 1, 'buy',
            expiration, strike, type, []),
      ],
      1.0,
      null,
      null,
      direction,
      '',
      100.0,
      DateTime.now(),
      DateTime.now(),
      'code_123',
    )
      ..optionInstrument = instrument;
  }

  group('OptionLiveActivitySheet Widget Tests', () {
    late LiveActivityService service;

    setUp(() {
      service = LiveActivityService.instance;
      service.clearInternalState();
    });

    testWidgets('renders contract details, 0DTE badge, and Dynamic Island preview',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final todayExpiry = DateTime(now.year, now.month, now.day);
      final pos = createMockPosition(
        symbol: 'SPY',
        strike: 580.0,
        expiration: todayExpiry,
        markPrice: 5.00,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptionLiveActivitySheet(
              position: pos,
              liveActivityService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SPY'), findsWidgets);
      expect(find.text('0DTE'), findsWidgets); // header and preview capsule
      expect(find.text('Trailing Stop Loss'), findsOneWidget);
      expect(find.text('10%'), findsWidgets); // chip and current readout
      expect(find.text('Track 0DTE Position on Lock Screen'), findsOneWidget);
    });

    testWidgets('preset choice chips dynamically update calculated stop price',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final pos = createMockPosition(
        symbol: 'AAPL',
        strike: 220.0,
        expiration: now.add(const Duration(days: 7)),
        markPrice: 10.00,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptionLiveActivitySheet(
              position: pos,
              liveActivityService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial 10%: stop is 10.00 * (1 - 0.10) = $9.00
      expect(find.text('\$9.00'), findsOneWidget);

      // Tap 20% chip
      final chip20 = find.widgetWithText(ChoiceChip, '20%');
      expect(chip20, findsOneWidget);
      await tester.tap(chip20);
      await tester.pumpAndSettle();

      // Now stop price is 10.00 * (1 - 0.20) = $8.00
      expect(find.text('\$8.00'), findsOneWidget);
      expect(find.text('-20%'), findsOneWidget);
    });

    testWidgets('starting activity triggers service and shows active actions',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final pos = createMockPosition(
        symbol: 'QQQ',
        strike: 480.0,
        expiration: now.add(const Duration(days: 1)),
        markPrice: 4.00,
      );

      bool sessionChanged = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptionLiveActivitySheet(
              position: pos,
              liveActivityService: service,
              onSessionChanged: () {
                sessionChanged = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final startButton = find.text('Start Live Activity & Dynamic Island');
      expect(startButton, findsOneWidget);

      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(sessionChanged, isTrue);
      expect(service.isPositionTracked(pos.id), isTrue);

      final session = service.getSession(pos.id);
      expect(session, isNotNull);
      expect(session!.symbol, 'QQQ');
      expect(session.currentPrice, 4.00);
      expect(session.trailingStopPrice, closeTo(3.60, 0.001)); // 4.00 * 0.90
    });

    testWidgets('shows update and end buttons when already tracking',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final pos = createMockPosition(
        symbol: 'TSLA',
        strike: 260.0,
        expiration: now.add(const Duration(days: 5)),
        markPrice: 8.00,
      );

      // Pre-start session
      await service.startOptionPositionActivity(
        pos,
        trailingStopPercent: 15.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptionLiveActivitySheet(
              position: pos,
              liveActivityService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Update Trailing Stop'), findsOneWidget);
      expect(find.text('End Live Activity'), findsOneWidget);

      // Tap End Live Activity
      await tester.tap(find.text('End Live Activity'));
      await tester.pumpAndSettle();

      expect(service.isPositionTracked(pos.id), isFalse);
    });
  });
}
