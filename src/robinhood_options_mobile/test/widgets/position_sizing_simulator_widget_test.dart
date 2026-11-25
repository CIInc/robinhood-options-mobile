import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/trade_strategy_config.dart';
import 'package:robinhood_options_mobile/widgets/position_sizing_simulator_widget.dart';

void main() {
  group('PositionSizingSimulatorWidget Tests', () {
    testWidgets('Renders simulator header and expands content', (tester) async {
      final config = TradeStrategyConfig(
        positionSizingMode: PositionSizingMode.fixedShares,
        tradeQuantity: 5,
        maxPositionSize: 50,
        maxPortfolioConcentration: 0.20,
        totalCapitalBudgetPercent: 0.50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PositionSizingSimulatorWidget(
                config: config,
                isPaperTrading: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Position Sizing Simulator'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsOneWidget);

      // Expand the tile
      await tester.tap(find.text('Position Sizing Simulator'));
      await tester.pumpAndSettle();

      expect(find.text('Symbol'), findsOneWidget);
      expect(find.text('Price'), findsOneWidget);
      expect(find.text('Order Quantity'), findsOneWidget);
      expect(find.text('Notional Value'), findsOneWidget);
      expect(find.text('RiskGuard Pre-Flight: APPROVED'), findsOneWidget);
    });

    testWidgets(
        'Target Dollar sizing calculates correct quantity and checks bounds',
        (tester) async {
      final config = TradeStrategyConfig(
        positionSizingMode: PositionSizingMode.targetDollar,
        targetDollarAllocation: 500.0,
        maxPositionSize: 10,
        maxPortfolioConcentration: 0.20,
        totalCapitalBudgetPercent: 0.50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PositionSizingSimulatorWidget(
                config: config,
                isPaperTrading: true,
              ),
            ),
          ),
        ),
      );

      // Expand tile
      await tester.tap(find.text('Position Sizing Simulator'));
      await tester.pumpAndSettle();

      // For NVDA default $140, target $500: floor(500 / 140) = 3 shares
      // Let's select NVDA
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NVDA').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('3 sh'), findsWidgets);
      expect(find.text('RiskGuard Pre-Flight: APPROVED'), findsOneWidget);
    });

    testWidgets('Exceeding Max Position Size triggers DECLINED status',
        (tester) async {
      final config = TradeStrategyConfig(
        positionSizingMode: PositionSizingMode.fixedShares,
        tradeQuantity: 100,
        maxPositionSize: 50, // Ceiling 50 < 100
        maxPortfolioConcentration: 0.50,
        totalCapitalBudgetPercent: 0.80,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PositionSizingSimulatorWidget(
                config: config,
                isPaperTrading: true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Position Sizing Simulator'));
      await tester.pumpAndSettle();

      expect(find.text('RiskGuard Pre-Flight: DECLINED'), findsOneWidget);
      expect(find.textContaining('Exceeds Max Position Size ceiling'),
          findsOneWidget);
    });

    testWidgets(
        'PositionLimitMode.maxPercent ignores share ceiling and enforces concentration',
        (tester) async {
      final config = TradeStrategyConfig(
        positionSizingMode: PositionSizingMode.fixedShares,
        positionLimitMode: PositionLimitMode.maxPercent,
        tradeQuantity: 10,
        maxPositionSize:
            5, // 10 > 5, but mode is maxPercent so share ceiling is ignored!
        maxPortfolioConcentration:
            0.50, // 10 * $585 = $5,850 on $25k default (23.4% < 50%)
        totalCapitalBudgetPercent: 0.80,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PositionSizingSimulatorWidget(
                config: config,
                isPaperTrading: true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Position Sizing Simulator'));
      await tester.pumpAndSettle();

      expect(find.text('RiskGuard Pre-Flight: APPROVED'), findsOneWidget);
      expect(find.textContaining('conforms with Max Concentration'),
          findsOneWidget);
    });

    testWidgets(
        'Renders dynamic ATR sizing cleanly without overflow on standard and narrow viewports',
        (tester) async {
      final config = TradeStrategyConfig(
        positionSizingMode: PositionSizingMode.dynamicRisk,
        atrMultiplier: 2.0,
        riskPerTrade: 0.01,
        maxPositionSize: 50,
        maxPortfolioConcentration: 0.20,
        totalCapitalBudgetPercent: 0.50,
      );

      // Test on standard 360px viewport
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PositionSizingSimulatorWidget(
                config: config,
                isPaperTrading: true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Position Sizing Simulator'));
      await tester.pumpAndSettle();

      expect(find.text('Symbol'), findsOneWidget);
      expect(find.text('Price'), findsOneWidget);
      expect(find.text('ATR (14)'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Test on 320px narrow viewport
      tester.view.physicalSize = const Size(320, 800);
      await tester.pumpAndSettle();

      expect(find.text('Symbol'), findsOneWidget);
      expect(find.text('Price'), findsOneWidget);
      expect(find.text('ATR (14)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
