import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/services/tax_optimization_service.dart';

/// Builds the Action Center feed: the ranked list of things worth acting on
/// today.
///
/// Every rule degrades gracefully. Analytics-derived alerts are skipped when
/// [analytics] is null (the metrics have not been computed yet), so the Overview
/// can render immediately from the position stores alone.
class PortfolioAlertService {
  static final _currency = NumberFormat.simpleCurrency(decimalDigits: 0);
  static final _percent = NumberFormat.percentPattern()
    ..maximumFractionDigits = 1;

  /// Weight above which a single holding is called out as concentrated.
  static const _concentrationWarning = 0.20;
  static const _concentrationCritical = 0.30;

  /// Cash weight above which the portfolio is flagged as under-deployed.
  static const _highCashWeight = 0.30;

  /// Daily move that makes a position worth surfacing on its own.
  static const _notableDailyMove = 0.05;

  static List<PortfolioAlert> buildAlerts({
    required List<InstrumentPosition> instrumentPositions,
    required List<OptionAggregatePosition> optionPositions,
    Account? account,
    double? totalEquity,
    Map<String, dynamic>? analytics,
    String benchmarkSymbol = 'SPY',
  }) {
    final alerts = <PortfolioAlert>[];

    alerts.addAll(_taxAlerts(instrumentPositions, optionPositions));
    alerts.addAll(_concentrationAlerts(instrumentPositions, optionPositions));
    alerts.addAll(_cashAlerts(account, totalEquity));
    alerts.addAll(_moverAlerts(instrumentPositions));
    if (analytics != null && analytics.isNotEmpty) {
      alerts.addAll(_analyticsAlerts(analytics, benchmarkSymbol));
    }

    alerts.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return alerts;
  }

  static List<PortfolioAlert> _taxAlerts(
    List<InstrumentPosition> instrumentPositions,
    List<OptionAggregatePosition> optionPositions,
  ) {
    final suggestions =
        TaxOptimizationService.calculateTaxHarvestingOpportunities(
      instrumentPositions: instrumentPositions,
      optionPositions: optionPositions,
    );
    if (suggestions.isEmpty) return const [];

    final totalLoss = suggestions.fold<double>(
        0, (sum, suggestion) => sum + suggestion.estimatedLoss);
    final urgency = TaxOptimizationService.getSeasonalityUrgency();

    // Match the existing card's smart-visibility thresholds so the Action
    // Center and the Taxes section never disagree about whether there is an
    // opportunity worth mentioning.
    final threshold = urgency > 0 ? -100.0 : -1000.0;
    if (totalLoss > threshold) return const [];

    return [
      PortfolioAlert(
        id: 'tax-loss-harvesting',
        severity: urgency == 2
            ? PortfolioAlertSeverity.critical
            : PortfolioAlertSeverity.warning,
        icon: Icons.savings_outlined,
        title: '${suggestions.length} tax-loss '
            '${suggestions.length == 1 ? 'opportunity' : 'opportunities'}',
        detail: urgency > 0
            ? 'Harvest before year-end to offset realized gains.'
            : 'Harvestable losses detected across your holdings.',
        metric: _currency.format(totalLoss.abs()),
        target: PortfolioAlertTarget.taxes,
      ),
    ];
  }

  static List<PortfolioAlert> _concentrationAlerts(
    List<InstrumentPosition> instrumentPositions,
    List<OptionAggregatePosition> optionPositions,
  ) {
    final weights = <String, double>{};
    for (final position in instrumentPositions) {
      final symbol = position.instrumentObj?.symbol;
      if (symbol == null || position.marketValue <= 0) continue;
      weights[symbol] = (weights[symbol] ?? 0) + position.marketValue;
    }
    for (final position in optionPositions) {
      if (position.marketValue <= 0) continue;
      weights[position.symbol] =
          (weights[position.symbol] ?? 0) + position.marketValue;
    }
    if (weights.isEmpty) return const [];

    final total = weights.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return const [];

    final ranked = weights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topWeight = ranked.first.value / total;
    if (topWeight < _concentrationWarning) return const [];

    return [
      PortfolioAlert(
        id: 'concentration-${ranked.first.key}',
        severity: topWeight >= _concentrationCritical
            ? PortfolioAlertSeverity.critical
            : PortfolioAlertSeverity.warning,
        icon: Icons.pie_chart_outline,
        title: 'Concentration risk in ${ranked.first.key}',
        detail: 'A single holding drives an outsized share of your returns.',
        metric: _percent.format(topWeight),
        target: PortfolioAlertTarget.risk,
      ),
    ];
  }

  static List<PortfolioAlert> _cashAlerts(
      Account? account, double? totalEquity) {
    final cash = account?.portfolioCash;
    if (cash == null || totalEquity == null || totalEquity <= 0)
      return const [];

    final weight = cash / totalEquity;
    if (weight < _highCashWeight) return const [];

    return [
      PortfolioAlert(
        id: 'high-cash',
        severity: PortfolioAlertSeverity.info,
        icon: Icons.account_balance_wallet_outlined,
        title: '${_percent.format(weight)} of assets in cash',
        detail: 'Uninvested cash is not tracking the market. Rebalance?',
        metric: _currency.format(cash),
        target: PortfolioAlertTarget.rebalance,
      ),
    ];
  }

  static List<PortfolioAlert> _moverAlerts(
      List<InstrumentPosition> instrumentPositions) {
    final movers = instrumentPositions
        .where((position) =>
            position.instrumentObj?.quoteObj?.adjustedPreviousClose != null &&
            position.marketValue > 0 &&
            position.gainLossPercentToday.abs() >= _notableDailyMove)
        .toList()
      ..sort((a, b) => b.gainLossToday.abs().compareTo(a.gainLossToday.abs()));

    if (movers.isEmpty) return const [];

    final mover = movers.first;
    final isGain = mover.gainLossToday >= 0;
    return [
      PortfolioAlert(
        id: 'mover-${mover.instrumentObj!.symbol}',
        severity: isGain
            ? PortfolioAlertSeverity.positive
            : PortfolioAlertSeverity.warning,
        icon: isGain ? Icons.trending_up : Icons.trending_down,
        title: '${mover.instrumentObj!.symbol} moved '
            '${_percent.format(mover.gainLossPercentToday.abs())} today',
        detail: isGain
            ? 'Your largest contributor to today\'s gain.'
            : 'Your largest detractor from today\'s return.',
        metric: _currency.format(mover.gainLossToday),
        target: PortfolioAlertTarget.positions,
      ),
    ];
  }

  static List<PortfolioAlert> _analyticsAlerts(
      Map<String, dynamic> analytics, String benchmarkSymbol) {
    final alerts = <PortfolioAlert>[];

    final excessReturn = analytics['excessReturn'] as double?;
    if (excessReturn != null && excessReturn.abs() >= 0.02) {
      final trailing = excessReturn < 0;
      alerts.add(PortfolioAlert(
        id: 'benchmark-delta',
        severity: trailing
            ? PortfolioAlertSeverity.warning
            : PortfolioAlertSeverity.positive,
        icon: trailing ? Icons.south_east : Icons.north_east,
        title: '${trailing ? 'Trailing' : 'Beating'} $benchmarkSymbol by '
            '${_percent.format(excessReturn.abs())}',
        detail: trailing
            ? 'Review which positions are dragging on relative return.'
            : 'Your allocation is outperforming the benchmark.',
        target: PortfolioAlertTarget.performance,
      ));
    }

    final currentDrawdown = analytics['currentDrawdown'] as double?;
    if (currentDrawdown != null && currentDrawdown.abs() >= 0.10) {
      alerts.add(PortfolioAlert(
        id: 'drawdown',
        severity: currentDrawdown.abs() >= 0.20
            ? PortfolioAlertSeverity.critical
            : PortfolioAlertSeverity.warning,
        icon: Icons.waterfall_chart,
        title: 'Down ${_percent.format(currentDrawdown.abs())} from peak',
        detail: 'The portfolio has not recovered its previous high.',
        target: PortfolioAlertTarget.risk,
      ));
    }

    final volatility = analytics['volatility'] as double?;
    final benchmarkVolatility = analytics['benchmarkVolatility'] as double?;
    if (volatility != null &&
        benchmarkVolatility != null &&
        benchmarkVolatility > 0 &&
        volatility / benchmarkVolatility >= 1.5) {
      alerts.add(PortfolioAlert(
        id: 'volatility',
        severity: PortfolioAlertSeverity.warning,
        icon: Icons.show_chart,
        title: 'Volatility is '
            '${(volatility / benchmarkVolatility).toStringAsFixed(1)}× '
            '$benchmarkSymbol',
        detail: 'Swings are materially wider than the benchmark.',
        metric: _percent.format(volatility),
        target: PortfolioAlertTarget.risk,
      ));
    }

    return alerts;
  }
}
