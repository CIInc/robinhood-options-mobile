import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/gamma_exposure_model.dart';
import 'package:robinhood_options_mobile/model/zero_dte_squeeze_radar_model.dart';
import 'package:robinhood_options_mobile/widgets/zero_dte_squeeze_radar_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setLargeTestWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  final sampleResult = ZeroDteSqueezeRadarResult(
    symbol: 'SPY',
    spotPrice: 502.50,
    squeezeProbability: 82.0,
    riskLevel: GammaSqueezeRiskLevel.high,
    summary: 'HIGH ALERT: 82% Squeeze Risk. Heavy 0DTE call sweeps with spot testing dealer flip thresholds.',
    flowSummary: const ZeroDteFlowSummary(
      totalCallVolume: 24500,
      totalPutVolume: 6200,
      totalCallPremium: 8200000.0,
      totalPutPremium: 1500000.0,
      callPutVolumeRatio: 0.798,
      callPutPremiumRatio: 0.845,
      callVelocity: 816.0,
      putVelocity: 206.0,
      netVelocity: 610.0,
      sweepCount: 18,
      unusualVolumeOiRatio: 3.4,
    ),
    flipMetrics: const DealerGammaFlipMetrics(
      spotPrice: 502.50,
      gammaFlip: 500.0,
      distanceToFlip: 2.50,
      distanceToFlipPercent: 0.005,
      callWall: 505.0,
      putWall: 495.0,
      dealerPositioning: DealerPositioning.shortGamma,
      approachVelocity: 22.0,
      isNearFlip: true,
      inShortGammaZone: true,
    ),
    factors: const [
      SqueezeFactor(
        title: '0DTE Call Flow Dominance',
        description: 'Aggressive call flow (80% of volume) with 18 sweeps.',
        score: 25.0,
        maxScore: 30.0,
        isTriggered: true,
      ),
      SqueezeFactor(
        title: 'Dealer Short Gamma & Flip Proximity',
        description: 'Dealers in Short Gamma with spot 0.5% from Flip (\$500.0).',
        score: 25.0,
        maxScore: 30.0,
        isTriggered: true,
      ),
      SqueezeFactor(
        title: '0DTE Volume vs. Open Interest Surge',
        description: 'Unusual 0DTE volume explosion (3.4x Open Interest).',
        score: 20.0,
        maxScore: 25.0,
        isTriggered: true,
      ),
      SqueezeFactor(
        title: 'Call Wall Penetration Pressure',
        description: 'Spot is pressing against Call Wall (\$505.0).',
        score: 12.0,
        maxScore: 15.0,
        isTriggered: true,
      ),
    ],
    updatedAt: DateTime.now(),
  );

  Widget createWidgetUnderTest({
    ZeroDteSqueezeRadarResult? precomputedResult,
    VoidCallback? onOpenGexAnalysis,
  }) {
    return MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(
        body: ZeroDteSqueezeRadarWidget(
          symbol: 'SPY',
          spotPrice: 502.50,
          precomputedResult: precomputedResult ?? sampleResult,
          onOpenGexAnalysis: onOpenGexAnalysis,
        ),
      ),
    );
  }

  group('ZeroDteSqueezeRadarWidget Tests', () {
    testWidgets('Renders probability gauge and risk badge correctly', (tester) async {
      setLargeTestWindow(tester);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('SPY 0DTE SQUEEZE RADAR'), findsOneWidget);
      expect(find.text('82%'), findsOneWidget);
      expect(find.text('SQUEEZE PROB'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.textContaining('82% Squeeze Risk'), findsOneWidget);
    });

    testWidgets('Renders 0DTE flow velocity and metrics card', (tester) async {
      setLargeTestWindow(tester);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('0DTE Flow Velocity & Volume'), findsOneWidget);
      expect(find.text('18 Sweeps'), findsOneWidget);
      expect(find.textContaining('Calls: 80%'), findsOneWidget);
      expect(find.textContaining('Puts: 20%'), findsOneWidget);
      expect(find.text('816 /min'), findsOneWidget);
      expect(find.text('+610 /min'), findsOneWidget);
      expect(find.text('3.4x'), findsOneWidget);
    });

    testWidgets('Renders dealer gamma flip panel with key levels', (tester) async {
      setLargeTestWindow(tester);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Dealer Gamma Flip & Regimes'), findsOneWidget);
      expect(find.text('Dealer Short Gamma (Amplifying)'), findsOneWidget);
      expect(find.text('\$502.50'), findsOneWidget); // Spot
      expect(find.text('\$500.00'), findsOneWidget); // Flip
      expect(find.text('0.5%'), findsOneWidget); // Distance
      expect(find.text('\$505.00'), findsOneWidget); // Call Wall
      expect(find.text('\$495.00'), findsOneWidget); // Put Wall
    });

    testWidgets('Renders squeeze factor breakdown list', (tester) async {
      setLargeTestWindow(tester);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Squeeze Probability Factors'), findsOneWidget);
      expect(find.text('0DTE Call Flow Dominance'), findsOneWidget);
      expect(find.text('Dealer Short Gamma & Flip Proximity'), findsOneWidget);
      expect(find.text('0DTE Volume vs. Open Interest Surge'), findsOneWidget);
      expect(find.text('Call Wall Penetration Pressure'), findsOneWidget);
      expect(find.text('25 / 30 pts'), findsNWidgets(2));
      expect(find.text('20 / 25 pts'), findsOneWidget);
      expect(find.text('12 / 15 pts'), findsOneWidget);
    });

    testWidgets('Taps GEX Profile button triggering onOpenGexAnalysis callback', (tester) async {
      setLargeTestWindow(tester);
      bool gexOpened = false;

      await tester.pumpWidget(createWidgetUnderTest(
        onOpenGexAnalysis: () {
          gexOpened = true;
        },
      ));
      await tester.pumpAndSettle();

      final gexBtn = find.text('GEX Profile');
      expect(gexBtn, findsOneWidget);

      await tester.tap(gexBtn);
      await tester.pumpAndSettle();

      expect(gexOpened, isTrue);
    });
  });
}
