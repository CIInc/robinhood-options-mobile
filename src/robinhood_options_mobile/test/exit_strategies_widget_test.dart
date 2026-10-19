import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/shared/exit_strategies_widget.dart';

void main() {
  group('ExitStrategiesWidget 5-Tier Stop Queue Tests', () {
    late TextEditingController takeProfitController;
    late TextEditingController stopLossController;
    late TextEditingController trailingStopController;
    late TextEditingController timeBasedExitController;
    late TextEditingController marketCloseExitController;
    late TextEditingController rsiExitThresholdController;
    late TextEditingController signalStrengthExitThresholdController;
    late TextEditingController gexExitThresholdController;
    late TextEditingController trailingPeakStopPercentController;
    late TextEditingController minDteStopDaysController;
    late TextEditingController stalledSessionsStopLimitController;
    late TextEditingController catastrophicStopPercentController;

    setUp(() {
      takeProfitController = TextEditingController(text: '10.0');
      stopLossController = TextEditingController(text: '5.0');
      trailingStopController = TextEditingController(text: '3.0');
      timeBasedExitController = TextEditingController(text: '30');
      marketCloseExitController = TextEditingController(text: '15');
      rsiExitThresholdController = TextEditingController(text: '80.0');
      signalStrengthExitThresholdController =
          TextEditingController(text: '40.0');
      gexExitThresholdController = TextEditingController(text: '0.0');
      trailingPeakStopPercentController = TextEditingController(text: '15.0');
      minDteStopDaysController = TextEditingController(text: '7');
      stalledSessionsStopLimitController = TextEditingController(text: '3');
      catastrophicStopPercentController = TextEditingController(text: '30.0');
    });

    tearDown(() {
      takeProfitController.dispose();
      stopLossController.dispose();
      trailingStopController.dispose();
      timeBasedExitController.dispose();
      marketCloseExitController.dispose();
      rsiExitThresholdController.dispose();
      signalStrengthExitThresholdController.dispose();
      gexExitThresholdController.dispose();
      trailingPeakStopPercentController.dispose();
      minDteStopDaysController.dispose();
      stalledSessionsStopLimitController.dispose();
      catastrophicStopPercentController.dispose();
    });

    testWidgets('renders all 5 tiers of the sequential exit stop queue',
        (WidgetTester tester) async {
      bool gexStructuralStops = true;
      bool trailingPeakStop = true;
      bool timeThetaStop = true;
      bool macroRegimeStop = true;
      bool catastrophicStop = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExitStrategiesWidget(
                takeProfitController: takeProfitController,
                stopLossController: stopLossController,
                trailingStopController: trailingStopController,
                timeBasedExitController: timeBasedExitController,
                marketCloseExitController: marketCloseExitController,
                rsiExitThresholdController: rsiExitThresholdController,
                signalStrengthExitThresholdController:
                    signalStrengthExitThresholdController,
                gexExitThresholdController: gexExitThresholdController,
                trailingStopEnabled: false,
                timeBasedExitEnabled: false,
                marketCloseExitEnabled: false,
                partialExitsEnabled: false,
                rsiExitEnabled: false,
                signalStrengthExitEnabled: false,
                gexExitEnabled: false,
                exitStages: const [],
                enableGexStructuralStops: gexStructuralStops,
                enableTrailingPeakStop: trailingPeakStop,
                trailingPeakStopPercentController:
                    trailingPeakStopPercentController,
                enableTimeThetaStop: timeThetaStop,
                minDteStopDaysController: minDteStopDaysController,
                stalledSessionsStopLimitController:
                    stalledSessionsStopLimitController,
                enableMacroRegimeStop: macroRegimeStop,
                enableCatastrophicStop: catastrophicStop,
                catastrophicStopPercentController:
                    catastrophicStopPercentController,
                onTrailingStopChanged: (_) {},
                onTimeBasedExitChanged: (_) {},
                onMarketCloseExitChanged: (_) {},
                onPartialExitsChanged: (_) {},
                onRsiExitChanged: (_) {},
                onSignalStrengthExitChanged: (_) {},
                onGexExitChanged: (_) {},
                onExitStagesChanged: (_) {},
                onGexStructuralStopsChanged: (val) => gexStructuralStops = val,
                onTrailingPeakStopChanged: (val) => trailingPeakStop = val,
                onTimeThetaStopChanged: (val) => timeThetaStop = val,
                onMacroRegimeStopChanged: (val) => macroRegimeStop = val,
                onCatastrophicStopChanged: (val) => catastrophicStop = val,
              ),
            ),
          ),
        ),
      );

      // Verify Section Title
      expect(find.text('5-Tier Sequential Exit Stop Priority Queue'),
          findsOneWidget);

      // Verify Tier 1
      expect(find.text('Stop 1: GEX Structural Stop'), findsOneWidget);

      // Verify Tier 2
      expect(find.text('Stop 2: Trailing Peak Drawdown'), findsOneWidget);
      expect(find.text('Trailing Peak Drawdown'), findsOneWidget);

      // Verify Tier 3
      expect(find.text('Stop 3: Time & Theta Decay Stop'), findsOneWidget);
      expect(find.text('Min DTE Cutoff'), findsOneWidget);
      expect(find.text('Stalled Sessions Limit'), findsOneWidget);

      // Verify Tier 4
      expect(find.text('Stop 4: Macro Regime Stop'), findsOneWidget);

      // Verify Tier 5
      expect(find.text('Stop 5: Catastrophic Loss Cutoff'), findsOneWidget);
      expect(find.text('Catastrophic Loss Floor'), findsOneWidget);

      // Verify Intraday & Technical Exits section (no duplicate trailing or GEX exits)
      expect(find.text('Intraday & Technical Exits'), findsOneWidget);
      expect(find.text('Intraday Scalp Timer'), findsOneWidget);
      expect(find.text('Market Close Exit'), findsOneWidget);
      expect(find.text('RSI Overbought Exit'), findsOneWidget);
      expect(find.text('Signal Strength Degradation Exit'), findsOneWidget);
      expect(find.text('Scaling Out'), findsOneWidget);
      expect(find.text('Partial Exits'), findsOneWidget);

      // Ensure no duplicate cards
      expect(find.text('Trailing Stop'), findsNothing);
      expect(find.text('GEX Exit'), findsNothing);

      // Test toggling Stop 1
      final stop1Finder = find.text('Stop 1: GEX Structural Stop');
      await tester.ensureVisible(stop1Finder);
      await tester.tap(stop1Finder);
      await tester.pumpAndSettle();
      expect(gexStructuralStops, isFalse);

      // Test toggling Stop 4
      final stop4Finder = find.text('Stop 4: Macro Regime Stop');
      await tester.ensureVisible(stop4Finder);
      await tester.tap(stop4Finder);
      await tester.pumpAndSettle();
      expect(macroRegimeStop, isFalse);
    });
  });
}
