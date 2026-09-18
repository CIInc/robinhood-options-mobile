import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/day_trade.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/margin_call.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/model/unified_account.dart';
import 'package:robinhood_options_mobile/model/wash_sale_record.dart';
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
    DayTradeSummary? dayTradeSummary,
    UnifiedAccount? unifiedAccount,
    List<MarginCall>? marginCalls,
    List<WashSaleRecord>? washSales,
  }) {
    final alerts = <PortfolioAlert>[];

    alerts.addAll(
        _marginHealthAlerts(account, unifiedAccount, totalEquity, marginCalls));
    alerts.addAll(_pdtAlerts(account, totalEquity, dayTradeSummary));
    alerts.addAll(_taxAlerts(instrumentPositions, optionPositions, washSales));
    alerts.addAll(_concentrationAlerts(instrumentPositions, optionPositions));
    alerts.addAll(_cashAlerts(account, totalEquity));
    alerts.addAll(_moverAlerts(instrumentPositions));
    if (analytics != null && analytics.isNotEmpty) {
      alerts.addAll(_analyticsAlerts(analytics, benchmarkSymbol));
    }

    alerts.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return alerts;
  }

  static List<PortfolioAlert> _marginHealthAlerts(
    Account? account,
    UnifiedAccount? unifiedAccount,
    double? totalEquity, [
    List<MarginCall>? marginCalls,
  ]) {
    final alerts = <PortfolioAlert>[];

    // Surface discrete margin call demands first if present
    if (marginCalls != null && marginCalls.any((c) => c.isOpen)) {
      for (final call in marginCalls.where((c) => c.isOpen)) {
        final dueStr = call.formattedDueDate != null
            ? ' due ${call.formattedDueDate}'
            : '';
        alerts.add(
          PortfolioAlert(
            id: 'margin-call-${call.id}',
            severity: PortfolioAlertSeverity.critical,
            icon: Icons.error_rounded,
            title: '${call.displayType} active (${call.formattedAmount})',
            detail:
                'Immediate deposit or liquidation required$dueStr. ${call.reason ?? call.description ?? "Deposit cash or sell marginable positions to meet margin requirement."}',
            metric: call.formattedAmount,
            target: PortfolioAlertTarget.risk,
          ),
        );
      }
    }

    if (unifiedAccount == null && account == null) return alerts;

    final marginHealth = unifiedAccount?.marginHealth;
    final borrowed =
        marginHealth?.borrowedAmount ?? account?.settledAmountBorrowed ?? 0.0;

    // Only accounts utilizing borrowed margin require margin health buffer alerts
    if (borrowed <= 0.001) return alerts;

    if (marginHealth != null) {
      if ((marginHealth.status == MarginHealthStatus.marginCall ||
              marginHealth.marginCallAmount > 0) &&
          alerts.isEmpty) {
        final deficitAmt = marginHealth.marginCallAmount > 0
            ? marginHealth.marginCallAmount
            : borrowed;
        alerts.add(
          PortfolioAlert(
            id: 'margin-call-deficit',
            severity: PortfolioAlertSeverity.critical,
            icon: Icons.error_rounded,
            title: 'Margin call active (${_currency.format(deficitAmt)})',
            detail:
                'Immediate deposit or position liquidation is required to meet margin maintenance.',
            metric: _currency.format(deficitAmt),
            target: PortfolioAlertTarget.risk,
          ),
        );
      } else if (marginHealth.status == MarginHealthStatus.critical ||
          marginHealth.marginBufferPercentage < 0.10) {
        alerts.add(
          PortfolioAlert(
            id: 'margin-buffer-critical',
            severity: PortfolioAlertSeverity.critical,
            icon: Icons.warning_amber_rounded,
            title:
                'Critical margin buffer (${_percent.format(marginHealth.marginBufferPercentage)})',
            detail:
                'Only ${_currency.format(marginHealth.marginBuffer)} buffer remains before maintenance liquidation triggers.',
            metric: _percent.format(marginHealth.marginBufferPercentage),
            target: PortfolioAlertTarget.risk,
          ),
        );
      } else if (marginHealth.status == MarginHealthStatus.warning ||
          marginHealth.marginBufferPercentage < 0.25) {
        alerts.add(
          PortfolioAlert(
            id: 'margin-buffer-warning',
            severity: PortfolioAlertSeverity.warning,
            icon: Icons.info_outline_rounded,
            title:
                'Low margin buffer (${_percent.format(marginHealth.marginBufferPercentage)})',
            detail:
                'Margin buffer is ${_currency.format(marginHealth.marginBuffer)}. Market pullbacks could trigger a margin call.',
            metric: _percent.format(marginHealth.marginBufferPercentage),
            target: PortfolioAlertTarget.risk,
          ),
        );
      }
    }
    return alerts;
  }

  static List<PortfolioAlert> _pdtAlerts(
    Account? account,
    double? totalEquity,
    DayTradeSummary? dayTradeSummary,
  ) {
    if (account == null) return const [];
    final isCash = account.type.toLowerCase().contains('cash');
    if (isCash) return const [];

    final equity = totalEquity ?? account.portfolioCash ?? 0.0;
    if (equity >= 25000.0) return const [];

    if (account.markedPatternDayTraderDate != null ||
        (dayTradeSummary != null &&
            dayTradeSummary.riskLevel == PdtRiskLevel.flagged)) {
      return [
        PortfolioAlert(
          id: 'pdt-flagged',
          severity: PortfolioAlertSeverity.critical,
          icon: Icons.gavel_outlined,
          title: 'Pattern Day Trader restriction active',
          detail:
              'Account is flagged as PDT with equity under \$25,000. Day trading is restricted.',
          metric: _currency.format(equity),
          target: PortfolioAlertTarget.risk,
        ),
      ];
    }

    if (dayTradeSummary != null) {
      if (dayTradeSummary.riskLevel == PdtRiskLevel.danger) {
        return [
          PortfolioAlert(
            id: 'pdt-limit-reached',
            severity: PortfolioAlertSeverity.critical,
            icon: Icons.warning_amber_rounded,
            title: 'PDT limit reached (0 remaining)',
            detail:
                'Executing another day trade will designate your account as a Pattern Day Trader under FINRA Rule 4210.',
            metric: '${dayTradeSummary.activeDayTradeCount} / 3 used',
            target: PortfolioAlertTarget.risk,
          ),
        ];
      } else if (dayTradeSummary.riskLevel == PdtRiskLevel.warning) {
        return [
          PortfolioAlert(
            id: 'pdt-warning',
            severity: PortfolioAlertSeverity.warning,
            icon: Icons.shield_outlined,
            title: '1 day trade remaining',
            detail:
                'You have 1 day trade available before reaching the FINRA PDT threshold.',
            metric: '${dayTradeSummary.activeDayTradeCount} / 3 used',
            target: PortfolioAlertTarget.risk,
          ),
        ];
      }
    }

    return const [];
  }

  static List<PortfolioAlert> _taxAlerts(
    List<InstrumentPosition> instrumentPositions,
    List<OptionAggregatePosition> optionPositions, [
    List<WashSaleRecord>? washSales,
  ]) {
    final alerts = <PortfolioAlert>[];

    // 1. Wash Sale Disallowed loss alert (Critical)
    if (washSales != null) {
      final disallowed = washSales.where((w) => w.isDisallowed).toList();
      if (disallowed.isNotEmpty) {
        final totalDisallowed = disallowed.fold<double>(
            0.0, (sum, w) => sum + (w.disallowedLoss ?? w.realizedLoss.abs()));
        final symbols = disallowed.map((w) => w.symbol).toSet().toList();
        alerts.add(
          PortfolioAlert(
            id: 'wash-sale-disallowed',
            severity: PortfolioAlertSeverity.critical,
            icon: Icons.warning_amber_rounded,
            title:
                '${disallowed.length} disallowed wash ${disallowed.length == 1 ? 'sale' : 'sales'}',
            detail:
                '${symbols.join(', ')} loss disallowed by IRS Rule 1091 and deferred to cost basis.',
            metric: _currency.format(totalDisallowed),
            target: PortfolioAlertTarget.taxes,
          ),
        );
      }

      // 2. Active Wash Sale Window warning alert
      final activeWindows = washSales.where((w) => w.isWindowActive()).toList();
      if (activeWindows.isNotEmpty) {
        final minDays =
            activeWindows.map((w) => w.getDaysRemaining()).reduce(min);
        final symbols = activeWindows.map((w) => w.symbol).toSet().toList();
        alerts.add(
          PortfolioAlert(
            id: 'wash-sale-window',
            severity: PortfolioAlertSeverity.warning,
            icon: Icons.schedule,
            title:
                '${activeWindows.length} active wash sale ${activeWindows.length == 1 ? 'window' : 'windows'}',
            detail:
                'Avoid repurchasing ${symbols.join(', ')} to preserve tax loss deductions.',
            metric: '${minDays}d left',
            target: PortfolioAlertTarget.taxes,
          ),
        );
      }
    }

    final suggestions =
        TaxOptimizationService.calculateTaxHarvestingOpportunities(
      instrumentPositions: instrumentPositions,
      optionPositions: optionPositions,
    );
    if (suggestions.isNotEmpty) {
      final totalLoss = suggestions.fold<double>(
          0, (sum, suggestion) => sum + suggestion.estimatedLoss);
      final urgency = TaxOptimizationService.getSeasonalityUrgency();

      // Match the existing card's smart-visibility thresholds so the Action
      // Center and the Taxes section never disagree about whether there is an
      // opportunity worth mentioning.
      final threshold = urgency > 0 ? -100.0 : -1000.0;
      if (totalLoss <= threshold) {
        alerts.add(
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
        );
      }
    }

    // 4. Capital Gains: Approaching Long-Term preferential rate alert
    final capitalGains = TaxOptimizationService.analyzeCapitalGains(
      instrumentPositions: instrumentPositions,
      optionPositions: optionPositions,
    );
    if (capitalGains.approachingLongTermPositions.isNotEmpty) {
      final topApproaching = capitalGains.approachingLongTermPositions.first;
      final totalSavings = capitalGains.potentialTaxSavingsFromHolding;
      if (totalSavings >= 25.0) {
        alerts.add(
          PortfolioAlert(
            id: 'capital-gains-approaching',
            severity: PortfolioAlertSeverity.info,
            icon: Icons.timer_outlined,
            title: '${capitalGains.approachingLongTermPositions.length} '
                '${capitalGains.approachingLongTermPositions.length == 1 ? 'position' : 'positions'} nearing Long-Term status',
            detail:
                'Hold ${topApproaching.symbol} for ${topApproaching.daysUntilLongTerm}d to unlock preferential long-term capital gains tax rates.',
            metric: '+${_currency.format(totalSavings)} savings',
            target: PortfolioAlertTarget.taxes,
          ),
        );
      }
    }

    return alerts;
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
    if (cash == null || totalEquity == null || totalEquity <= 0) {
      return const [];
    }

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
        title: '${mover.instrumentObj!.symbol} ${isGain ? 'moved up' : 'fell'} '
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
