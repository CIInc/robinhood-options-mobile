import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/devils_advocate_model.dart';
import 'package:robinhood_options_mobile/model/gamma_exposure_model.dart';
import 'package:robinhood_options_mobile/services/factor_alignment_service.dart';

void main() {
  group('FactorAlignmentService Tests', () {
    test('computes bullish high conviction when indicators and flow align', () {
      final input = FactorAlignmentInput(
        symbol: 'AAPL',
        direction: 'Bullish',
        currentPrice: 230.0,
        technicalIndicators: {
          'sma': 'BUY',
          'ema': 'BUY',
          'priceMovement': 'BUY',
          'adx': 'BUY',
          'rsi': 'BUY',
          'macd': 'BUY',
          'stochastic': 'BUY',
          'cci': 'BUY',
          'bollinger': 'BUY',
          'atr': 'EXPANSION',
        },
        optionsFlowBullishRatio: 0.85,
        devilsAdvocate: DevilsAdvocateAnalysis(
          symbol: 'AAPL',
          direction: 'Bullish',
          resilienceScore: 82.0,
          verdict: 'Resilient',
          killerQuestion: 'Can iPhone revenue continue growing?',
          summary: 'Thesis is well supported.',
        ),
      );

      final rating = FactorAlignmentService.computeLocalConviction(input);

      expect(rating.symbol, 'AAPL');
      expect(rating.direction, 'Bullish');
      expect(rating.convictionScore, greaterThanOrEqualTo(75.0));
      expect(rating.isHighConviction, isTrue);
      expect(rating.stressPenalty, 0.0);
      expect(rating.pillarScores.length, 5);
      expect(rating.keyCatalysts.isNotEmpty, isTrue);
    });

    test('applies stress penalty and degrades tier when severe hazards exist',
        () {
      final input = FactorAlignmentInput(
        symbol: 'TSLA',
        direction: 'Bullish',
        currentPrice: 220.0,
        technicalIndicators: {
          'sma': 'BUY',
          'ema': 'HOLD',
          'rsi': 'HOLD',
        },
        devilsAdvocate: DevilsAdvocateAnalysis(
          symbol: 'TSLA',
          direction: 'Bullish',
          resilienceScore: 35.0,
          verdict: 'Fragile',
          killerQuestion: 'What happens if margins deteriorate?',
          eventHazards: [
            EventHazard(
              event: 'Q3 Earnings Report',
              timing: 'Tomorrow after close',
              risk: 'Severe IV crush and margin guidance risk',
              hazardLevel: 'High',
            ),
          ],
          skewTraps: [
            SkewTrap(
              title: 'Downside Put Skew Extreme',
              description: 'Puts are heavily bid relative to calls',
              severity: 'High',
            ),
          ],
          summary: 'High fragility detected.',
        ),
      );

      final rating = FactorAlignmentService.computeLocalConviction(input);

      expect(rating.symbol, 'TSLA');
      expect(rating.stressPenalty, greaterThan(10.0));
      expect(rating.convictionScore, lessThan(60.0));
      expect(rating.primaryRisks.any((r) => r.contains('stress penalty')), isTrue);
    });

    test('evaluates gamma exposure tilt', () {
      final input = FactorAlignmentInput(
        symbol: 'SPY',
        direction: 'Bullish',
        gammaExposure: GammaExposureData(
          symbol: 'SPY',
          spotPrice: 580.0,
          totalCallGEX: 2000000.0,
          totalPutGEX: 500000.0,
          totalNetGEX: 1500000.0,
          gexByStrike: const [],
          dealerPositioning: DealerPositioning.longGamma,
          signalStrength: 75,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final rating = FactorAlignmentService.computeLocalConviction(input);
      final flowGexPillar =
          rating.pillarScores.firstWhere((p) => p.key == 'flow_gex');
      expect(flowGexPillar.score, greaterThanOrEqualTo(50.0));
    });
  });
}
