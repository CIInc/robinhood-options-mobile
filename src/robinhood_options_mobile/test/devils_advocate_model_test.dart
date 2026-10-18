import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/devils_advocate_model.dart';

void main() {
  group('DevilsAdvocateModel Tests', () {
    test('serializes and deserializes DevilsAdvocateAnalysis correctly', () {
      final json = {
        'symbol': 'TSLA',
        'direction': 'Bullish',
        'resilience_score': 62.5,
        'verdict': 'Moderate',
        'killer_question':
            'If automotive gross margins drop below 14%, how can energy storage sustain valuation?',
        'counter_arguments': [
          {
            'title': 'Multiple Compression Risk',
            'argument':
                'Trading at elevated forward earnings multiple during EV price wars.',
            'severity': 'High',
          },
          {
            'title': 'FSD Regulatory Scrutiny',
            'argument':
                'NHTSA investigations create overhang for robotaxi timelines.',
            'severity': 'Medium',
          }
        ],
        'skew_traps': [
          {
            'title': 'Call Skew Decoupling',
            'description':
                'Out-of-the-money call IV premium is priced for extreme upside, exposing long calls to delta drag.',
            'severity': 'High',
          }
        ],
        'event_hazards': [
          {
            'event': 'Q3 Delivery Numbers',
            'timing': 'Next week',
            'risk': 'Delivery miss could trigger 8-10% gap down.',
            'hazard_level': 'High',
          }
        ],
        'stress_scenarios': [
          {
            'scenario': 'Broad Tech Selloff (-5% QQQ)',
            'projected_impact': '-9.5%',
            'assessment': 'High beta 1.9x amplification on market downturn.',
          }
        ],
        'summary':
            'Strong momentum is counterbalanced by margin compression risks and upcoming delivery catalyst.',
        'last_updated': '2026-09-27T02:00:00.000Z',
      };

      final analysis = DevilsAdvocateAnalysis.fromJson(json);

      expect(analysis.symbol, 'TSLA');
      expect(analysis.direction, 'Bullish');
      expect(analysis.resilienceScore, 62.5);
      expect(analysis.verdict, 'Moderate');
      expect(analysis.killerQuestion, contains('gross margins drop'));
      expect(analysis.counterArguments.length, 2);
      expect(analysis.counterArguments[0].title, 'Multiple Compression Risk');
      expect(analysis.counterArguments[0].severity, 'High');
      expect(analysis.skewTraps.length, 1);
      expect(analysis.skewTraps[0].severity, 'High');
      expect(analysis.eventHazards.length, 1);
      expect(analysis.eventHazards[0].timing, 'Next week');
      expect(analysis.eventHazards[0].hazardLevel, 'High');
      expect(analysis.stressScenarios.length, 1);
      expect(analysis.stressScenarios[0].projectedImpact, '-9.5%');
      expect(analysis.summary, contains('Strong momentum'));
      expect(analysis.lastUpdated, isNotNull);

      final serialized = analysis.toJson();
      expect(serialized['symbol'], 'TSLA');
      expect(serialized['direction'], 'Bullish');
      expect(serialized['resilience_score'], 62.5);
      expect(serialized['verdict'], 'Moderate');
      expect(serialized['counter_arguments'], hasLength(2));
      expect(serialized['skew_traps'], hasLength(1));
      expect(serialized['event_hazards'], hasLength(1));
      expect(serialized['stress_scenarios'], hasLength(1));
    });

    test('handles empty and default JSON values safely', () {
      final analysis = DevilsAdvocateAnalysis.fromJson({});
      expect(analysis.symbol, '');
      expect(analysis.direction, 'Bullish');
      expect(analysis.resilienceScore, 50.0);
      expect(analysis.verdict, 'Moderate');
      expect(analysis.killerQuestion, '');
      expect(analysis.counterArguments, isEmpty);
      expect(analysis.skewTraps, isEmpty);
      expect(analysis.eventHazards, isEmpty);
      expect(analysis.stressScenarios, isEmpty);
      expect(analysis.summary, '');
      expect(analysis.lastUpdated, isNull);
    });
  });
}
