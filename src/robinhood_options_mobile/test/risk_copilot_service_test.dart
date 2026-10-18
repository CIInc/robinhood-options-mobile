import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/earnings_calendar_event.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/risk_copilot_model.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';
import 'package:robinhood_options_mobile/services/risk_copilot_service.dart';

Quote _makeQuote(String symbol, double price) {
  return Quote(
    askPrice: price,
    askSize: 0,
    bidPrice: price,
    bidSize: 0,
    lastTradePrice: price,
    lastExtendedHoursTradePrice: price,
    previousClose: price,
    adjustedPreviousClose: price,
    previousCloseDate: DateTime(2026, 1, 1),
    symbol: symbol,
    tradingHalted: false,
    hasTraded: true,
    lastTradePriceSource: 'test',
    updatedAt: DateTime(2026, 1, 2),
    instrument: '',
    instrumentId: symbol,
  );
}

InstrumentPosition _makeStockPosition({
  required String symbol,
  required double quantity,
  required double price,
}) {
  final pos = InstrumentPosition(
    'https://example.com/positions/$symbol/',
    'https://example.com/instruments/$symbol/',
    'https://example.com/accounts/acc_1/',
    'acc_1',
    price,
    0,
    quantity,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    false,
    DateTime(2026, 1, 1),
    DateTime(2025, 1, 1),
  );
  pos.instrumentObj = Instrument.forSymbol(symbol)
    ..quoteObj = _makeQuote(symbol, price);
  return pos;
}

OptionAggregatePosition _makeOptionPosition({
  required String symbol,
  required String strategy,
  required String direction, // 'debit' or 'credit'
  required double quantity,
  required double averageOpenPrice,
  required double strikePrice,
  required String optionType, // 'call' or 'put'
  double delta = 0.5,
}) {
  final positionType = direction == 'credit' ? 'short' : 'long';
  final leg = OptionLeg(
    'leg-$symbol-$strikePrice-$optionType',
    null,
    positionType,
    'option-1',
    'open',
    1,
    'buy',
    DateTime(2026, 11, 20),
    strikePrice,
    optionType,
    [],
  );

  final opt = OptionAggregatePosition(
    'opt_pos_$symbol',
    'chain_$symbol',
    'acc_1',
    symbol,
    strategy,
    averageOpenPrice,
    [leg],
    quantity,
    null,
    null,
    direction,
    direction,
    100.0,
    DateTime(2026, 1, 1),
    DateTime(2026, 1, 1),
    strategy,
  );
  opt.instrumentObj = Instrument.forSymbol(symbol)
    ..quoteObj = _makeQuote(symbol, 100.0);

  final optionInst = OptionInstrument(
    'chain_$symbol',
    symbol,
    DateTime(2026, 1, 1),
    DateTime(2026, 11, 20),
    'opt_inst_$symbol',
    DateTime(2026, 1, 1),
    MinTicks(0.01, 0.01, 3.0),
    'tradable',
    'active',
    strikePrice,
    'tradable',
    optionType,
    DateTime(2026, 1, 1),
    'https://example.com/options/instruments/opt_inst_$symbol/',
    null,
    'call',
    'call',
  );

  optionInst.optionMarketData = OptionMarketData(
    averageOpenPrice,
    averageOpenPrice + 0.05,
    10,
    averageOpenPrice - 0.05,
    10,
    strikePrice,
    averageOpenPrice + 0.10,
    'https://example.com/options/instruments/opt_inst_$symbol/',
    'opt_inst_$symbol',
    averageOpenPrice,
    1,
    averageOpenPrice - 0.10,
    averageOpenPrice,
    100,
    DateTime(2026, 1, 1),
    averageOpenPrice,
    50,
    symbol,
    symbol,
    0.5,
    0.5,
    delta,
    0.02,
    0.25,
    0.01,
    -0.05,
    0.12,
    averageOpenPrice,
    averageOpenPrice,
    averageOpenPrice,
    averageOpenPrice,
    DateTime(2026, 1, 1),
  );

  opt.optionInstrument = optionInst;
  return opt;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RiskCopilotModel Tests', () {
    test('GapRiskAssessment model serializes and deserializes accurately', () {
      const assessment = GapRiskAssessment(
        symbol: 'NVDA',
        notionalValue: 15000.0,
        beta: 1.75,
        estimatedGapPercent: 0.061,
        potentialDollarLoss: 915.0,
        isLeveragedOrVolatile: true,
        hasShortOptionRisk: false,
        severity: RiskCopilotSeverity.high,
        warningMessage: 'Elevated gap exposure',
        mitigationAction: 'Establish collar hedge',
      );

      final json = assessment.toJson();
      expect(json['symbol'], 'NVDA');
      expect(json['severity'], 'high');
      expect(json['potential_dollar_loss'], 915.0);

      final fromJson = GapRiskAssessment.fromJson(json);
      expect(fromJson.symbol, 'NVDA');
      expect(fromJson.severity, RiskCopilotSeverity.high);
      expect(fromJson.isLeveragedOrVolatile, true);
    });

    test('EarningsHazardAssessment serializes and deserializes accurately', () {
      final now = DateTime(2026, 10, 10);
      final assessment = EarningsHazardAssessment(
        symbol: 'AAPL',
        earningsDate: now.add(const Duration(days: 2)),
        daysUntilEarnings: 2,
        sharesCount: 100,
        optionsCount: 3,
        isLongOptionHolding: true,
        expectedMovePercent: 0.055,
        crushProbability: 0.82,
        hazardType: EarningsHazardType.ivCrush,
        severity: RiskCopilotSeverity.critical,
        warningMessage: 'AAPL earnings in 2 days! Long options risk IV crush.',
        mitigationAction: 'Close long contracts before announcement',
      );

      final json = assessment.toJson();
      expect(json['symbol'], 'AAPL');
      expect(json['hazard_type'], 'ivCrush');
      expect(json['severity'], 'critical');

      final fromJson = EarningsHazardAssessment.fromJson(json);
      expect(fromJson.symbol, 'AAPL');
      expect(fromJson.daysUntilEarnings, 2);
      expect(fromJson.hazardType, EarningsHazardType.ivCrush);
      expect(fromJson.severity, RiskCopilotSeverity.critical);
    });

    test('RiskCopilotReport JSON round-trip maintains integrity', () {
      final report = RiskCopilotReport(
        generatedAt: DateTime(2026, 10, 6),
        overallSeverity: RiskCopilotSeverity.high,
        overallScore: 62.0,
        statusHeadline: 'High Risk Exposure',
        summary: 'Substantial directional drift detected.',
        totalOvernightGapExposure: 1250.0,
        hasImminentEarnings: true,
        portfolioNetDelta: 125.0,
      );

      final json = report.toJson();
      expect(json['overall_score'], 62.0);
      expect(json['overall_severity'], 'high');

      final fromJson = RiskCopilotReport.fromJson(json);
      expect(fromJson.overallScore, 62.0);
      expect(fromJson.overallSeverity, RiskCopilotSeverity.high);
      expect(fromJson.hasElevatedRisk, true);
    });
  });

  group('RiskCopilotService Engine Tests', () {
    test('Balanced low-risk portfolio produces normal severity and high safety score', () {
      final stock1 = _makeStockPosition(symbol: 'JNJ', quantity: 20.0, price: 150.0);
      final stock2 = _makeStockPosition(symbol: 'KO', quantity: 30.0, price: 60.0);

      final report = RiskCopilotService.evaluateRiskReport(
        instrumentPositions: [stock1, stock2],
        optionPositions: const [],
        totalEquity: 25000.0,
        betaBySymbol: {'JNJ': 0.6, 'KO': 0.55},
        now: DateTime(2026, 10, 6),
      );

      expect(report.overallSeverity, RiskCopilotSeverity.normal);
      expect(report.overallScore, greaterThanOrEqualTo(90.0));
      expect(report.statusHeadline, 'Protected & Balanced');
      expect(report.hasImminentEarnings, false);
      expect(report.hasElevatedRisk, false);
    });

    test('Leveraged ETF holding triggers gap risk assessment with high severity', () {
      final tqqq = _makeStockPosition(symbol: 'TQQQ', quantity: 200.0, price: 65.0);

      final report = RiskCopilotService.evaluateRiskReport(
        instrumentPositions: [tqqq],
        optionPositions: const [],
        totalEquity: 20000.0,
        betaBySymbol: {'TQQQ': 2.8},
        now: DateTime(2026, 10, 6),
      );

      expect(report.gapRisks, isNotEmpty);
      final gap = report.gapRisks.firstWhere((g) => g.symbol == 'TQQQ');
      expect(gap.isLeveragedOrVolatile, true);
      expect(gap.severity, isNot(RiskCopilotSeverity.normal));
      expect(report.totalOvernightGapExposure, greaterThan(0.0));
      expect(report.hasElevatedRisk, true);
    });

    test('Unhedged short call triggers critical gap risk hazard', () {
      final nakedCall = _makeOptionPosition(
        symbol: 'TSLA',
        strategy: 'short_call',
        direction: 'credit',
        quantity: 2.0,
        averageOpenPrice: 5.50,
        strikePrice: 260.0,
        optionType: 'call',
        delta: -0.45,
      );

      final report = RiskCopilotService.evaluateRiskReport(
        instrumentPositions: const [],
        optionPositions: [nakedCall],
        totalEquity: 10000.0,
        now: DateTime(2026, 10, 6),
      );

      expect(report.overallSeverity, RiskCopilotSeverity.critical);
      final tslaGap = report.gapRisks.firstWhere((g) => g.symbol == 'TSLA');
      expect(tslaGap.hasShortOptionRisk, true);
      expect(tslaGap.severity, RiskCopilotSeverity.critical);
      expect(tslaGap.warningMessage, contains('short options face severe tail risk'));
    });

    test('Imminent earnings event within 2 days on long options flags critical IV crush hazard', () {
      final now = DateTime(2026, 10, 6);
      final callPos = _makeOptionPosition(
        symbol: 'NVDA',
        strategy: 'long_call',
        direction: 'debit',
        quantity: 3.0,
        averageOpenPrice: 8.00,
        strikePrice: 130.0,
        optionType: 'call',
      );

      final earningsEvent = EarningsCalendarEvent(
        symbol: 'NVDA',
        date: now.add(const Duration(days: 1)), // Tomorrow!
        verified: true,
      );

      final report = RiskCopilotService.evaluateRiskReport(
        instrumentPositions: const [],
        optionPositions: [callPos],
        totalEquity: 15000.0,
        earningsCalendarEvents: [earningsEvent],
        now: now,
      );

      expect(report.earningsHazards, isNotEmpty);
      final nvdaHazard = report.earningsHazards.firstWhere((h) => h.symbol == 'NVDA');
      expect(nvdaHazard.daysUntilEarnings, 1);
      expect(nvdaHazard.hazardType, EarningsHazardType.ivCrush);
      expect(nvdaHazard.severity, RiskCopilotSeverity.critical);
      expect(nvdaHazard.warningMessage, contains('IV crush'));
      expect(report.hasImminentEarnings, true);
    });

    test('Directional delta imbalance generates concrete share and option hedge suggestions', () {
      final largeStock = _makeStockPosition(symbol: 'MSFT', quantity: 150.0, price: 420.0);

      final report = RiskCopilotService.evaluateRiskReport(
        instrumentPositions: [largeStock],
        optionPositions: const [],
        totalEquity: 80000.0,
        now: DateTime(2026, 10, 6),
      );

      expect(report.deltaHedges, isNotEmpty);
      final msftHedge = report.deltaHedges.firstWhere((d) => d.symbol == 'MSFT');
      expect(msftHedge.netDelta, closeTo(150.0, 1.0));
      expect(msftHedge.suggestedSharesHedge, lessThan(0.0)); // Should suggest selling shares to hedge
      expect(msftHedge.suggestedOptionHedge, contains('Put')); // Should suggest buying puts to hedge long delta
      expect(msftHedge.dollarDeltaPerOnePercent, greaterThan(0.0));
    });

    test('Compiles prioritized mitigation action checklist with correct routing targets', () {
      final now = DateTime(2026, 10, 6);
      final stock = _makeStockPosition(symbol: 'TSLA', quantity: 200.0, price: 250.0);
      final earningsEvent = EarningsCalendarEvent(
        symbol: 'TSLA',
        date: now.add(const Duration(days: 2)),
      );

      final report = RiskCopilotService.evaluateRiskReport(
        instrumentPositions: [stock],
        optionPositions: const [],
        totalEquity: 50000.0,
        earningsCalendarEvents: [earningsEvent],
        betaBySymbol: {'TSLA': 2.1},
        now: now,
      );

      expect(report.topMitigations, isNotEmpty);
      expect(report.topMitigations.any((m) => m.symbol == 'TSLA'), true);
      expect(report.overallScore, lessThan(90.0));
    });
  });

  group('PortfolioAlertService Risk Copilot Alerts Tests', () {
    test('Surfaces Action Center alerts with riskCopilot target on elevated hazards', () {
      final now = DateTime(2026, 10, 6);
      final report = RiskCopilotReport(
        generatedAt: now,
        overallSeverity: RiskCopilotSeverity.critical,
        overallScore: 35.0,
        statusHeadline: 'Critical Risk Hazard Detected',
        summary: 'Severe overnight gap vulnerability on short options.',
        gapRisks: const [
          GapRiskAssessment(
            symbol: 'TSLA',
            notionalValue: 12000.0,
            beta: 2.2,
            estimatedGapPercent: 0.08,
            potentialDollarLoss: 960.0,
            hasShortOptionRisk: true,
            severity: RiskCopilotSeverity.critical,
            warningMessage: 'Unhedged short calls face overnight gap risk',
            mitigationAction: 'Close short call',
          )
        ],
        earningsHazards: [
          EarningsHazardAssessment(
            symbol: 'AAPL',
            earningsDate: now.add(const Duration(days: 1)),
            daysUntilEarnings: 1,
            sharesCount: 50,
            optionsCount: 2,
            isLongOptionHolding: true,
            expectedMovePercent: 0.06,
            crushProbability: 0.85,
            hazardType: EarningsHazardType.ivCrush,
            severity: RiskCopilotSeverity.critical,
            warningMessage: 'AAPL earnings tomorrow! IV crush hazard.',
            mitigationAction: 'Close contracts before close',
          )
        ],
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: const [],
        riskCopilotReport: report,
        now: now,
      );

      final copilotAlerts = alerts
          .where((a) => a.target == PortfolioAlertTarget.riskCopilot)
          .toList();

      expect(copilotAlerts, isNotEmpty);
      expect(copilotAlerts.any((a) => a.symbol == 'TSLA' && a.id.contains('gap')), true);
      expect(copilotAlerts.any((a) => a.symbol == 'AAPL' && a.id.contains('earnings')), true);
      expect(copilotAlerts.first.category, 'Risk Copilot');
    });

    test('Suppresses copilot alerts when portfolio is completely normal and protected', () {
      final now = DateTime(2026, 10, 6);
      final report = RiskCopilotReport(
        generatedAt: now,
        overallSeverity: RiskCopilotSeverity.normal,
        overallScore: 98.0,
        statusHeadline: 'Protected & Balanced',
        summary: 'Positions within normal parameters.',
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: const [],
        riskCopilotReport: report,
        now: now,
      );

      final copilotAlerts = alerts
          .where((a) => a.target == PortfolioAlertTarget.riskCopilot)
          .toList();

      expect(copilotAlerts, isEmpty);
    });
  });
}
