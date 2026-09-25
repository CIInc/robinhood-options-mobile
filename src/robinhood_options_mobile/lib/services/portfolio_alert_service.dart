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
import 'package:robinhood_options_mobile/model/custom_alert.dart';
import 'package:robinhood_options_mobile/model/dividend_payment_event.dart';
import 'package:robinhood_options_mobile/model/earnings_calendar_event.dart';
import 'package:robinhood_options_mobile/model/earnings_iv_crush_model.dart';
import 'package:robinhood_options_mobile/model/volatility_cone_model.dart';
import 'package:robinhood_options_mobile/model/iv_surface_model.dart';
import 'package:robinhood_options_mobile/model/delta_neutral_model.dart';
import 'package:robinhood_options_mobile/model/risk_circuit_breaker_config.dart';
import 'package:robinhood_options_mobile/model/automated_drip_config.dart';
import 'package:robinhood_options_mobile/model/zero_dte_squeeze_radar_model.dart';
import 'package:robinhood_options_mobile/model/news_intelligence.dart';
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
    RiskCircuitBreakerConfig? riskCircuitBreakerConfig,
    AutomatedDripConfig? automatedDripConfig,
    List<ZeroDteSqueezeRadarResult>? squeezeRadarResults,
    List<EarningsCalendarEvent>? earningsCalendarEvents,
    List<EarningsIvCrushAnalysis>? earningsCrushAnalyses,
    List<VolatilityConeAnalysis>? volatilityConeAnalyses,
    List<IvSurfaceAnalysis>? ivSurfaceAnalyses,
    List<DeltaNeutralAnalysis>? deltaNeutralAnalyses,
    List<dynamic>? dividendItems,
    List<DividendPaymentEvent>? dividendEvents,
    List<NewsIntelligence>? newsIntelligence,
    Map<String, NewsIntelligence>? newsIntelligenceBySymbol,
    double? dayPnL,
    double? dayPnLPercent,
    DateTime? now,
  }) {
    final alerts = <PortfolioAlert>[];
    final effectiveNow = now ?? DateTime.now();

    alerts.addAll(
        _circuitBreakerAlerts(riskCircuitBreakerConfig, dayPnL, dayPnLPercent));
    alerts.addAll(_zeroDteSqueezeAlerts(squeezeRadarResults));
    alerts.addAll(_optionExpirationAlerts(optionPositions, effectiveNow));
    alerts.addAll(_earningsCalendarAlerts(
      instrumentPositions: instrumentPositions,
      optionPositions: optionPositions,
      earningsCalendarEvents: earningsCalendarEvents,
      earningsCrushAnalyses: earningsCrushAnalyses,
      now: effectiveNow,
    ));
    alerts.addAll(_dividendAlerts(
      instrumentPositions: instrumentPositions,
      dividendItems: dividendItems,
      dividendEvents: dividendEvents,
      now: effectiveNow,
    ));
    alerts.addAll(_newsAlerts(
      instrumentPositions: instrumentPositions,
      optionPositions: optionPositions,
      newsIntelligence: newsIntelligence,
      newsIntelligenceBySymbol: newsIntelligenceBySymbol,
    ));
    alerts.addAll(_earningsCrushAlerts(earningsCrushAnalyses));
    alerts.addAll(_volatilityConeAlerts(volatilityConeAnalyses));
    alerts.addAll(_ivSurfaceAlerts(ivSurfaceAnalyses));
    alerts.addAll(_deltaNeutralAlerts(deltaNeutralAnalyses));
    alerts.addAll(_dripAlerts(automatedDripConfig));
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

  static List<PortfolioAlert> _circuitBreakerAlerts(
    RiskCircuitBreakerConfig? config,
    double? dayPnL,
    double? dayPnLPercent,
  ) {
    final alerts = <PortfolioAlert>[];
    if (config == null || !config.enabled) return alerts;

    if (config.isInCoolingOff) {
      final rem = config.remainingCoolingOff;
      final remStr = rem != null ? '${rem.inMinutes}m remaining' : 'active';
      alerts.add(
        PortfolioAlert(
          id: 'risk-circuit-breaker-cooling-off',
          severity: PortfolioAlertSeverity.critical,
          icon: Icons.shield_outlined,
          title: 'Trading Suspended ($remStr)',
          detail: config.tripReason ??
              'Risk circuit breaker cooling-off period active. Orders are temporarily blocked to protect capital.',
          target: PortfolioAlertTarget.risk,
        ),
      );
    } else if (config.isTripped) {
      alerts.add(
        PortfolioAlert(
          id: 'risk-circuit-breaker-tripped',
          severity: PortfolioAlertSeverity.critical,
          icon: Icons.shield_outlined,
          title: 'Circuit Breaker Tripped',
          detail: config.tripReason ??
              'Trading execution locked by autonomous risk guardrails.',
          target: PortfolioAlertTarget.risk,
        ),
      );
    } else if (dayPnL != null &&
        dayPnL < 0 &&
        config.maxDailyLossAmount != null &&
        config.maxDailyLossAmount! > 0) {
      final loss = dayPnL.abs();
      final ratio = loss / config.maxDailyLossAmount!;
      if (ratio >= 0.8) {
        alerts.add(
          PortfolioAlert(
            id: 'risk-circuit-breaker-near-daily-loss',
            severity: PortfolioAlertSeverity.warning,
            icon: Icons.warning_amber_rounded,
            title:
                'Approaching Daily Loss Limit (${(ratio * 100).toStringAsFixed(0)}%)',
            detail:
                'Current day loss of -\$${loss.toStringAsFixed(2)} is near your \$${config.maxDailyLossAmount!.toStringAsFixed(2)} circuit breaker threshold.',
            metric: '-\$${loss.toStringAsFixed(0)}',
            target: PortfolioAlertTarget.risk,
          ),
        );
      }
    }

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

  static List<PortfolioAlert> _dripAlerts(AutomatedDripConfig? config) {
    final alerts = <PortfolioAlert>[];
    if (config == null || !config.enabled) return alerts;

    final recentExecuted =
        config.transactions.where((t) => t.status == 'executed').take(1);
    for (final tx in recentExecuted) {
      alerts.add(PortfolioAlert(
        id: 'drip_exec_${tx.id}',
        severity: PortfolioAlertSeverity.positive,
        icon: Icons.autorenew,
        title: 'DRIP Reinvested: ${tx.symbol}',
        detail:
            'Reinvested \$${tx.dividendAmount.toStringAsFixed(2)} for ${tx.sharesPurchased.toStringAsFixed(3)} shares at \$${tx.executionPrice.toStringAsFixed(2)}.',
        metric: '\$${tx.dividendAmount.toStringAsFixed(2)}',
        target: PortfolioAlertTarget.positions,
      ));
    }

    final recentHeld =
        config.transactions.where((t) => t.status == 'threshold_unmet').take(1);
    for (final tx in recentHeld) {
      alerts.add(PortfolioAlert(
        id: 'drip_held_${tx.id}',
        severity: PortfolioAlertSeverity.info,
        icon: Icons.hourglass_top_outlined,
        title: 'DRIP Paused: ${tx.symbol}',
        detail:
            'Price \$${tx.executionPrice.toStringAsFixed(2)} is above threshold (\$${tx.thresholdPrice?.toStringAsFixed(2) ?? 'Target'}). \$${tx.dividendAmount.toStringAsFixed(2)} held in cash.',
        metric: '\$${tx.dividendAmount.toStringAsFixed(2)}',
        target: PortfolioAlertTarget.rebalance,
      ));
    }

    return alerts;
  }

  static List<PortfolioAlert> _zeroDteSqueezeAlerts(
      List<ZeroDteSqueezeRadarResult>? results) {
    final alerts = <PortfolioAlert>[];
    if (results == null || results.isEmpty) return alerts;

    for (final radar in results) {
      if (radar.riskLevel == GammaSqueezeRiskLevel.extreme) {
        alerts.add(
          PortfolioAlert(
            id: 'squeeze_extreme_${radar.symbol}',
            severity: PortfolioAlertSeverity.critical,
            icon: Icons.bolt_rounded,
            title: '${radar.symbol} Critical 0DTE Squeeze Imminent',
            detail: radar.summary,
            metric: '${radar.squeezeProbability.toStringAsFixed(0)}%',
            target: PortfolioAlertTarget.zeroDteRadar,
          ),
        );
      } else if (radar.riskLevel == GammaSqueezeRiskLevel.high) {
        alerts.add(
          PortfolioAlert(
            id: 'squeeze_high_${radar.symbol}',
            severity: PortfolioAlertSeverity.warning,
            icon: Icons.radar_rounded,
            title: '${radar.symbol} High Gamma Squeeze Probability',
            detail: radar.summary,
            metric: '${radar.squeezeProbability.toStringAsFixed(0)}%',
            target: PortfolioAlertTarget.zeroDteRadar,
          ),
        );
      }
    }
    return alerts;
  }

  static List<PortfolioAlert> _earningsCrushAlerts(
      List<EarningsIvCrushAnalysis>? analyses) {
    final alerts = <PortfolioAlert>[];
    if (analyses == null || analyses.isEmpty) return alerts;

    for (final analysis in analyses) {
      final summary = analysis.summary;
      final days = analysis.daysToEarnings;
      final countdown = days != null ? ' in $days days' : '';

      if (summary.riskTier == EarningsIvCrushRiskTier.extreme) {
        alerts.add(
          PortfolioAlert(
            id: 'earnings_crush_extreme_${analysis.symbol}',
            severity: PortfolioAlertSeverity.warning,
            icon: Icons.compress_rounded,
            title: '${analysis.symbol} Extreme IV Crush Risk$countdown',
            detail:
                'Options pricing implies a ±${summary.averageImpliedMovePct}% move vs. historical actual of ±${summary.averageActualMovePct}%. Historical post-earnings IV drops ${summary.averageIvCrushPct}%. Protect long unhedged options.',
            metric: '${summary.crushProbabilityScore.toStringAsFixed(0)}%',
            target: PortfolioAlertTarget.earningsIvCrush,
          ),
        );
      } else if (summary.riskTier == EarningsIvCrushRiskTier.high) {
        alerts.add(
          PortfolioAlert(
            id: 'earnings_crush_high_${analysis.symbol}',
            severity: PortfolioAlertSeverity.info,
            icon: Icons.event_note_rounded,
            title: '${analysis.symbol} Elevated Earnings IV Crush$countdown',
            detail:
                'Options historically overpriced in ${summary.overpricingRatePct}% of past quarters. Historical seller win rate favors straddle/condor selling over unhedged buying.',
            metric: '${summary.crushProbabilityScore.toStringAsFixed(0)}%',
            target: PortfolioAlertTarget.earningsIvCrush,
          ),
        );
      }
    }
    return alerts;
  }

  /// Evaluates a SmartAlertRule against an EarningsIvCrushAnalysis.
  static bool evaluateEarningsCrushAlert({
    required SmartAlertRule rule,
    required EarningsIvCrushAnalysis analysis,
  }) {
    if (rule.type != AlertType.earnings_iv_crush) return false;

    switch (rule.condition) {
      case AlertCondition.above_crush_probability:
      case AlertCondition.above:
        return analysis.summary.crushProbabilityScore >= rule.value;
      case AlertCondition.below:
        return analysis.summary.crushProbabilityScore <= rule.value;
      case AlertCondition.above_implied_move:
        return (analysis.straddleEstimate?.impliedMovePct ??
                analysis.summary.averageImpliedMovePct) >=
            rule.value;
      default:
        return analysis.summary.crushProbabilityScore >= rule.value;
    }
  }

  /// Generates Action Center alerts for upcoming earnings dates across portfolio holdings.
  static List<PortfolioAlert> _earningsCalendarAlerts({
    required List<InstrumentPosition> instrumentPositions,
    required List<OptionAggregatePosition> optionPositions,
    List<EarningsCalendarEvent>? earningsCalendarEvents,
    List<EarningsIvCrushAnalysis>? earningsCrushAnalyses,
    required DateTime now,
  }) {
    final alerts = <PortfolioAlert>[];
    final eventsBySymbol = <String, EarningsCalendarEvent>{};

    // 1. Incorporate explicitly supplied earnings calendar events
    if (earningsCalendarEvents != null) {
      for (final event in earningsCalendarEvents) {
        if (event.symbol.isNotEmpty) {
          eventsBySymbol[event.symbol] = event;
        }
      }
    }

    // 2. Scan equity positions for attached earnings objects
    for (final pos in instrumentPositions) {
      final symbol = pos.instrumentObj?.symbol ?? '';
      if (symbol.isEmpty) continue;
      final shares = pos.quantity ?? 0.0;
      if (shares <= 0) continue;

      final earningsList = pos.instrumentObj?.earningsObj;
      if (earningsList != null && earningsList.isNotEmpty) {
        EarningsCalendarEvent? nextEvent;
        for (final item in earningsList) {
          if (item is Map) {
            try {
              final event = EarningsCalendarEvent.fromRobinhoodJson(
                item,
                defaultSymbol: symbol,
                sharesHeld: shares,
              );
              final days = event.daysUntil(now);
              if (days >= 0 && days <= 7) {
                if (nextEvent == null || days < nextEvent.daysUntil(now)) {
                  nextEvent = event;
                }
              }
            } catch (_) {}
          }
        }
        if (nextEvent != null) {
          final existing = eventsBySymbol[symbol];
          if (existing == null) {
            eventsBySymbol[symbol] = nextEvent;
          } else {
            eventsBySymbol[symbol] = existing.copyWith(
              sharesHeld: (existing.sharesHeld ?? 0.0) + shares,
            );
          }
        } else if (eventsBySymbol.containsKey(symbol)) {
          final existing = eventsBySymbol[symbol]!;
          eventsBySymbol[symbol] = existing.copyWith(
            sharesHeld: (existing.sharesHeld ?? 0.0) + shares,
          );
        }
      } else if (eventsBySymbol.containsKey(symbol)) {
        final existing = eventsBySymbol[symbol]!;
        eventsBySymbol[symbol] = existing.copyWith(
          sharesHeld: (existing.sharesHeld ?? 0.0) + shares,
        );
      }
    }

    // 3. Scan option positions for underlying earnings objects
    for (final pos in optionPositions) {
      final symbol = pos.symbol.isNotEmpty
          ? pos.symbol
          : (pos.optionInstrument?.chainSymbol ?? '');
      if (symbol.isEmpty) continue;
      final contracts = (pos.quantity ?? 0.0).round();
      if (contracts <= 0) continue;

      if (eventsBySymbol.containsKey(symbol)) {
        final existing = eventsBySymbol[symbol]!;
        eventsBySymbol[symbol] = existing.copyWith(
          contractsHeld: (existing.contractsHeld ?? 0) + contracts,
        );
      } else {
        final earningsList = pos.instrumentObj?.earningsObj;
        if (earningsList != null && earningsList.isNotEmpty) {
          EarningsCalendarEvent? nextEvent;
          for (final item in earningsList) {
            if (item is Map) {
              try {
                final event = EarningsCalendarEvent.fromRobinhoodJson(
                  item,
                  defaultSymbol: symbol,
                  contractsHeld: contracts,
                );
                final days = event.daysUntil(now);
                if (days >= 0 && days <= 7) {
                  if (nextEvent == null || days < nextEvent.daysUntil(now)) {
                    nextEvent = event;
                  }
                }
              } catch (_) {}
            }
          }
          if (nextEvent != null) {
            eventsBySymbol[symbol] = nextEvent;
          }
        }
      }
    }

    // 4. Fallback to next earnings dates from EarningsIvCrushAnalysis if not already populated
    if (earningsCrushAnalyses != null) {
      for (final analysis in earningsCrushAnalyses) {
        if (!eventsBySymbol.containsKey(analysis.symbol)) {
          final days = analysis.daysToEarnings;
          if (days != null && days >= 0 && days <= 7) {
            eventsBySymbol[analysis.symbol] = EarningsCalendarEvent(
              symbol: analysis.symbol,
              date: analysis.nextEarningsDate ?? now.add(Duration(days: days)),
              epsEstimate: analysis.quarters.isNotEmpty
                  ? analysis.quarters.first.epsEstimate
                  : null,
            );
          }
        }
      }
    }

    // 5. Generate action center alerts for upcoming reports
    for (final event in eventsBySymbol.values) {
      final days = event.daysUntil(now);
      if (days < 0 || days > 7) continue;

      final symbol = event.symbol;
      final timingDesc =
          event.timingDisplay.isNotEmpty ? ' (${event.timingDisplay})' : '';
      final timingDetail = event.timingDisplay.isNotEmpty
          ? ' ${event.timingDisplay.toLowerCase()}'
          : '';

      final List<String> holdings = [];
      if (event.sharesHeld != null && event.sharesHeld! > 0) {
        final sharesStr = event.sharesHeld!.toStringAsFixed(
            event.sharesHeld!.truncateToDouble() == event.sharesHeld ? 0 : 2);
        holdings.add('$sharesStr shares');
      }
      if (event.contractsHeld != null && event.contractsHeld! > 0) {
        holdings.add(
            '${event.contractsHeld} option contract${event.contractsHeld! > 1 ? 's' : ''}');
      }
      final holdingStr =
          holdings.isNotEmpty ? 'You hold ${holdings.join(' and ')}. ' : '';
      final estimateStr = event.epsEstimate != null
          ? ' (Consensus EPS: ${event.formattedEstimate})'
          : '';

      if (days == 0) {
        // 0 DTE: Reports Today
        alerts.add(PortfolioAlert(
          id: 'earnings-today-$symbol',
          severity: PortfolioAlertSeverity.critical,
          icon: Icons.campaign_rounded,
          title: '$symbol Reports Earnings Today$timingDesc',
          detail:
              '${holdingStr}Scheduled to announce earnings today$timingDetail$estimateStr. High binary risk of price gap and IV crush at the release.',
          metric: 'Today',
          target: PortfolioAlertTarget.earningsIvCrush,
        ));
      } else if (days == 1) {
        // 1 DTE: Reports Tomorrow
        alerts.add(PortfolioAlert(
          id: 'earnings-tomorrow-$symbol',
          severity: PortfolioAlertSeverity.warning,
          icon: Icons.event_note_rounded,
          title: '$symbol Reports Earnings Tomorrow$timingDesc',
          detail:
              '${holdingStr}Scheduled to report earnings tomorrow$timingDetail$estimateStr. Review unhedged exposure or consider delta-neutral and IV crush strategies.',
          metric: '1d',
          target: PortfolioAlertTarget.earningsIvCrush,
        ));
      } else {
        // 2 to 7 Days: Reporting Soon
        final dateStr = DateFormat.MMMd().format(event.date);
        alerts.add(PortfolioAlert(
          id: 'earnings-upcoming-$symbol-$days',
          severity: PortfolioAlertSeverity.info,
          icon: Icons.event_outlined,
          title: '$symbol Earnings in $days Days ($dateStr)',
          detail:
              '${holdingStr}Scheduled announcement on $dateStr$timingDetail$estimateStr. Volatility and options extrinsic value typically expand ahead of earnings.',
          metric: '${days}d',
          target: PortfolioAlertTarget.earningsIvCrush,
        ));
      }
    }

    return alerts;
  }

  /// Evaluates a SmartAlertRule against an EarningsCalendarEvent or days-to-earnings.
  static bool evaluateEarningsCalendarAlert({
    required SmartAlertRule rule,
    required EarningsCalendarEvent event,
    DateTime? now,
  }) {
    if (rule.type != AlertType.earnings_calendar) return false;
    final current = now ?? DateTime.now();
    final days = event.daysUntil(current);

    switch (rule.condition) {
      case AlertCondition.earnings_today:
        return days == 0;
      case AlertCondition.earnings_tomorrow:
        return days == 1;
      case AlertCondition.earnings_imminent:
        return days >= 0 && days <= (rule.value > 0 ? rule.value.round() : 3);
      case AlertCondition.days_until_earnings:
      case AlertCondition.below:
        return days >= 0 && days <= rule.value;
      case AlertCondition.above:
        return days >= rule.value;
      default:
        return days >= 0 && days <= rule.value;
    }
  }

  /// Generates Action Center alerts for upcoming ex-dividend dates and dividend payments.
  static List<PortfolioAlert> _dividendAlerts({
    required List<InstrumentPosition> instrumentPositions,
    List<dynamic>? dividendItems,
    List<DividendPaymentEvent>? dividendEvents,
    required DateTime now,
  }) {
    final alerts = <PortfolioAlert>[];
    final eventsBySymbol = <String, DividendPaymentEvent>{};

    // 1. Build map of held equity quantities by symbol
    final sharesBySymbol = <String, double>{};
    for (final pos in instrumentPositions) {
      final sym = pos.instrumentObj?.symbol ?? '';
      final shares = pos.quantity ?? 0.0;
      if (sym.isNotEmpty && shares > 0) {
        sharesBySymbol[sym] = (sharesBySymbol[sym] ?? 0.0) + shares;
      }
    }

    // 2. Ingest explicitly passed dividendEvents
    if (dividendEvents != null) {
      for (final event in dividendEvents) {
        if (event.symbol.isNotEmpty) {
          final heldShares = sharesBySymbol[event.symbol] ?? event.sharesHeld;
          eventsBySymbol[event.symbol] = event.copyWith(sharesHeld: heldShares);
        }
      }
    }

    // 3. Parse dividend items (from DividendStore / transactions)
    if (dividendItems != null) {
      for (final item in dividendItems) {
        if (item is Map) {
          try {
            final parsed = DividendPaymentEvent.fromDividendMap(item);
            final sym = parsed.symbol;
            if (sym.isEmpty) continue;

            final heldShares = sharesBySymbol[sym] ?? parsed.sharesHeld;
            final updated = parsed.copyWith(sharesHeld: heldShares);

            if (!eventsBySymbol.containsKey(sym)) {
              eventsBySymbol[sym] = updated;
            } else {
              final existing = eventsBySymbol[sym]!;
              final existingPayDays = existing.daysUntilPayable(now);
              final updatedPayDays = updated.daysUntilPayable(now);
              final existingExDays = existing.daysUntilExDividend(now);
              final updatedExDays = updated.daysUntilExDividend(now);

              bool shouldReplace = false;
              if (existingPayDays == null && updatedPayDays != null) {
                shouldReplace = true;
              } else if (updatedPayDays != null && existingPayDays != null) {
                if (updatedPayDays >= 0 &&
                    (existingPayDays < 0 || updatedPayDays < existingPayDays)) {
                  shouldReplace = true;
                }
              } else if (existingExDays == null && updatedExDays != null) {
                shouldReplace = true;
              } else if (updatedExDays != null && existingExDays != null) {
                if (updatedExDays >= 0 &&
                    (existingExDays < 0 || updatedExDays < existingExDays)) {
                  shouldReplace = true;
                }
              }

              if (shouldReplace) {
                eventsBySymbol[sym] = updated;
              }
            }
          } catch (_) {}
        }
      }
    }

    // 4. Generate Action Center alerts
    for (final entry in eventsBySymbol.entries) {
      final sym = entry.key;
      final event = entry.value;

      final shares = event.sharesHeld ?? sharesBySymbol[sym];
      final sharesStr = shares != null && shares > 0
          ? '${shares % 1 == 0 ? shares.toInt() : shares.toStringAsFixed(2)} shares'
          : null;

      final payoutAmount = event.amount ??
          (event.rate != null && shares != null && shares > 0
              ? event.rate! * shares
              : null);
      final payoutStr = payoutAmount != null
          ? '\$${payoutAmount.toStringAsFixed(2)}'
          : (event.formattedRate ?? '');

      // Ex-Dividend Date Reminders
      final exDays = event.daysUntilExDividend(now);
      if (exDays != null) {
        if (exDays == 0) {
          // 0 DTE: Ex-Dividend Today (Warning: Last chance to be eligible)
          final detailParts = <String>[];
          if (sharesStr != null) {
            detailParts.add(
                'Must hold $sharesStr before market close to receive upcoming dividend.');
          } else {
            detailParts.add('Must hold shares before market close to qualify.');
          }
          if (event.rate != null) {
            detailParts.add('Rate: ${event.formattedRate}.');
          }
          if (payoutAmount != null) {
            detailParts.add(
                'Estimated payout: \$${payoutAmount.toStringAsFixed(2)}.');
          }

          alerts.add(PortfolioAlert(
            id: 'dividend_ex_date_today_$sym',
            severity: PortfolioAlertSeverity.warning,
            icon: Icons.event_available_outlined,
            title: '$sym Ex-Dividend Date Today',
            detail: detailParts.join(' '),
            metric: payoutAmount != null
                ? '\$${payoutAmount.toStringAsFixed(2)}'
                : 'Ex-Div Today',
            target: PortfolioAlertTarget.performance,
          ));
        } else if (exDays == 1) {
          // 1 DTE: Ex-Dividend Tomorrow
          alerts.add(PortfolioAlert(
            id: 'dividend_ex_date_tomorrow_$sym',
            severity: PortfolioAlertSeverity.info,
            icon: Icons.event_outlined,
            title: '$sym Ex-Dividend Tomorrow',
            detail:
                'Ex-dividend date is tomorrow. Hold through today\'s close to qualify for the ${event.formattedRate ?? 'upcoming'} dividend.',
            metric: 'Tomorrow',
            target: PortfolioAlertTarget.performance,
          ));
        } else if (exDays >= 2 && exDays <= 7) {
          // 2-7 DTE: Upcoming Ex-Dividend
          final dateStr = DateFormat.MMMd().format(event.exDividendDate!);
          alerts.add(PortfolioAlert(
            id: 'dividend_ex_date_upcoming_${sym}_$exDays',
            severity: PortfolioAlertSeverity.info,
            icon: Icons.date_range_outlined,
            title: '$sym Ex-Dividend in $exDays days',
            detail:
                'Ex-dividend date on $dateStr${event.formattedRate != null ? ' (${event.formattedRate})' : ''}. Hold shares to ensure dividend eligibility.',
            metric: '${exDays}d',
            target: PortfolioAlertTarget.performance,
          ));
        }
      }

      // Dividend Payment Date Reminders
      final payDays = event.daysUntilPayable(now);
      if (payDays != null) {
        if (payDays == 0) {
          // 0 DTE: Payable Today
          final isPaid = event.isPaid;
          final title = isPaid
              ? '$sym Dividend Paid ($payoutStr)'
              : '$sym Dividend Payable Today';
          final actionWord = isPaid ? 'credited' : 'payable today';
          final reinvestStr = event.isReinvested ? ' (DRIP enabled)' : '';

          alerts.add(PortfolioAlert(
            id: 'dividend_payable_today_$sym',
            severity: PortfolioAlertSeverity.positive,
            icon: Icons.payments_outlined,
            title: title,
            detail: sharesStr != null
                ? '$payoutStr $actionWord for your $sharesStr$reinvestStr.'
                : '$payoutStr $actionWord$reinvestStr.',
            metric: payoutStr,
            target: PortfolioAlertTarget.performance,
          ));
        } else if (payDays >= 1 && payDays <= 7) {
          // 1-7 DTE: Upcoming Scheduled Payment
          final dateStr = DateFormat.MMMd().format(event.payableDate!);
          alerts.add(PortfolioAlert(
            id: 'dividend_payable_upcoming_${sym}_$payDays',
            severity: PortfolioAlertSeverity.info,
            icon: Icons.schedule_outlined,
            title:
                '$sym Dividend in $payDays ${payDays == 1 ? 'day' : 'days'}',
            detail:
                'Scheduled payout of $payoutStr on $dateStr${sharesStr != null ? ' for $sharesStr' : ''}.',
            metric: payoutStr,
            target: PortfolioAlertTarget.performance,
          ));
        } else if (payDays >= -2 && payDays < 0 && event.isPaid) {
          // Paid within last 48 hours
          alerts.add(PortfolioAlert(
            id: 'dividend_recently_paid_$sym',
            severity: PortfolioAlertSeverity.positive,
            icon: Icons.check_circle_outline,
            title: '$sym Dividend Paid ($payoutStr)',
            detail:
                '$payoutStr paid${sharesStr != null ? ' for your $sharesStr' : ''}${event.isReinvested ? ' (DRIP reinvested)' : ''}.',
            metric: payoutStr,
            target: PortfolioAlertTarget.performance,
          ));
        }
      }
    }

    return alerts;
  }

  /// Evaluates a SmartAlertRule against a DividendPaymentEvent.
  static bool evaluateDividendAlert({
    required SmartAlertRule rule,
    required DividendPaymentEvent event,
    DateTime? now,
  }) {
    if (rule.type != AlertType.dividend_payment) return false;
    final effectiveNow = now ?? DateTime.now();

    switch (rule.condition) {
      case AlertCondition.ex_dividend_today:
        return event.daysUntilExDividend(effectiveNow) == 0;
      case AlertCondition.ex_dividend_tomorrow:
        return event.daysUntilExDividend(effectiveNow) == 1;
      case AlertCondition.ex_dividend_imminent:
        final days = event.daysUntilExDividend(effectiveNow);
        return days != null &&
            days >= 0 &&
            days <= (rule.value > 0 ? rule.value.round() : 3);
      case AlertCondition.days_until_ex_dividend:
        final days = event.daysUntilExDividend(effectiveNow);
        return days != null && days <= rule.value;
      case AlertCondition.dividend_payable_today:
        return event.daysUntilPayable(effectiveNow) == 0;
      case AlertCondition.dividend_payable_upcoming:
        final days = event.daysUntilPayable(effectiveNow);
        return days != null &&
            days >= 0 &&
            days <= (rule.value > 0 ? rule.value.round() : 7);
      case AlertCondition.days_until_dividend_payable:
        final days = event.daysUntilPayable(effectiveNow);
        return days != null && days <= rule.value;
      case AlertCondition.above:
        return (event.amount ?? 0) >= rule.value;
      case AlertCondition.below:
        return (event.amount ?? 0) <= rule.value;
      default:
        return (event.amount ?? 0) >= rule.value;
    }
  }

  /// Builds news alerts for held equity and option positions.
  static List<PortfolioAlert> _newsAlerts({
    required List<InstrumentPosition> instrumentPositions,
    required List<OptionAggregatePosition> optionPositions,
    List<NewsIntelligence>? newsIntelligence,
    Map<String, NewsIntelligence>? newsIntelligenceBySymbol,
  }) {
    final alerts = <PortfolioAlert>[];
    if (newsIntelligence == null && newsIntelligenceBySymbol == null) {
      return alerts;
    }

    // 1. Gather held positions by symbol (stocks + options)
    final sharesBySymbol = <String, double>{};
    for (final pos in instrumentPositions) {
      final sym = pos.instrumentObj?.symbol ?? '';
      final shares = pos.quantity ?? 0.0;
      if (sym.isNotEmpty && shares > 0) {
        sharesBySymbol[sym] = (sharesBySymbol[sym] ?? 0.0) + shares;
      }
    }

    final optionsBySymbol = <String, int>{};
    for (final op in optionPositions) {
      final sym = op.symbol.isNotEmpty
          ? op.symbol
          : (op.optionInstrument?.chainSymbol ?? '');
      final contracts = (op.quantity ?? 0.0).round();
      if (sym.isNotEmpty && contracts > 0) {
        optionsBySymbol[sym] = (optionsBySymbol[sym] ?? 0) + contracts;
      }
    }

    // Combined held symbols
    final heldSymbols = {...sharesBySymbol.keys, ...optionsBySymbol.keys};
    if (heldSymbols.isEmpty) return alerts;

    // 2. Consolidate news items by symbol
    final itemsBySymbol = <String, NewsIntelligence>{};
    if (newsIntelligenceBySymbol != null) {
      for (final entry in newsIntelligenceBySymbol.entries) {
        final sym = entry.key.toUpperCase();
        if (heldSymbols.contains(sym)) {
          itemsBySymbol[sym] = entry.value;
        }
      }
    }
    if (newsIntelligence != null) {
      for (final item in newsIntelligence) {
        final sym = item.symbol.toUpperCase();
        if (heldSymbols.contains(sym)) {
          if (!itemsBySymbol.containsKey(sym) ||
              item.updatedAt.isAfter(itemsBySymbol[sym]!.updatedAt)) {
            itemsBySymbol[sym] = item;
          }
        }
      }
    }

    // 3. Generate alerts for held symbols
    for (final entry in itemsBySymbol.entries) {
      final sym = entry.key;
      final intel = entry.value;

      final shares = sharesBySymbol[sym];
      final contracts = optionsBySymbol[sym];
      final holdingParts = <String>[];
      if (shares != null && shares > 0) {
        holdingParts.add(
            '${shares % 1 == 0 ? shares.toInt() : shares.toStringAsFixed(2)} shares');
      }
      if (contracts != null && contracts > 0) {
        holdingParts.add(
            '$contracts ${contracts == 1 ? 'option contract' : 'option contracts'}');
      }
      final holdingStr = holdingParts.join(', ');

      PortfolioAlert? candidate;

      // Check 1: High-impact news catalyst
      if (intel.impactRating == NewsImpact.high) {
        final isBearish = intel.sentimentLabel == NewsSentimentLabel.bearish ||
            intel.sentimentLabel == NewsSentimentLabel.veryBearish ||
            intel.overallSentiment < 45.0 ||
            intel.sentimentScoreChange24h <= -10.0;
        final isBullish = intel.sentimentLabel == NewsSentimentLabel.bullish ||
            intel.sentimentLabel == NewsSentimentLabel.veryBullish ||
            intel.overallSentiment > 55.0 ||
            intel.sentimentScoreChange24h >= 10.0;

        final severity = isBearish
            ? (intel.sentimentLabel == NewsSentimentLabel.veryBearish ||
                    intel.overallSentiment < 30.0
                ? PortfolioAlertSeverity.critical
                : PortfolioAlertSeverity.warning)
            : (isBullish
                ? PortfolioAlertSeverity.positive
                : PortfolioAlertSeverity.info);

        final icon = isBearish
            ? Icons.announcement
            : (isBullish ? Icons.campaign : Icons.article);

        final catalyst = intel.bearishCatalysts.isNotEmpty
            ? intel.bearishCatalysts.first
            : (intel.bullishCatalysts.isNotEmpty
                ? intel.bullishCatalysts.first
                : (intel.articles.isNotEmpty
                    ? intel.articles.first.title
                    : intel.headlineSummary));

        final title = isBearish
            ? '$sym: High-impact negative news catalyst'
            : (isBullish
                ? '$sym: High-impact bullish news catalyst'
                : '$sym: High-impact breaking news');

        final detail = holdingStr.isNotEmpty
            ? 'Held in portfolio ($holdingStr). $catalyst'
            : catalyst;

        candidate = PortfolioAlert(
          id: 'news-impact-$sym',
          severity: severity,
          icon: icon,
          title: title,
          detail: detail,
          metric: '${intel.overallSentiment.toStringAsFixed(0)}/100',
          target: PortfolioAlertTarget.insights,
        );
      }

      // Check 2: Rapid 24h sentiment shift
      if (candidate == null && intel.sentimentScoreChange24h.abs() >= 15.0) {
        final isDrop = intel.sentimentScoreChange24h < 0;
        final changeStr =
            '${isDrop ? '' : '+'}${intel.sentimentScoreChange24h.toStringAsFixed(1)} pts';

        final severity = isDrop
            ? (intel.sentimentScoreChange24h <= -25.0
                ? PortfolioAlertSeverity.critical
                : PortfolioAlertSeverity.warning)
            : PortfolioAlertSeverity.positive;

        final title = isDrop
            ? '$sym: News sentiment dropped $changeStr in 24h'
            : '$sym: News sentiment surged $changeStr in 24h';

        final topHeadline = intel.articles.isNotEmpty
            ? intel.articles.first.title
            : intel.headlineSummary;
        final detail = holdingStr.isNotEmpty
            ? 'Holding $holdingStr. $topHeadline'
            : topHeadline;

        candidate = PortfolioAlert(
          id: 'news-shift-$sym',
          severity: severity,
          icon: isDrop ? Icons.trending_down : Icons.trending_up,
          title: title,
          detail: detail,
          metric: '${intel.overallSentiment.toStringAsFixed(0)}/100',
          target: PortfolioAlertTarget.insights,
        );
      }

      // Check 3: Extreme sentiment regime
      if (candidate == null) {
        if (intel.sentimentLabel == NewsSentimentLabel.veryBearish ||
            intel.overallSentiment < 30.0) {
          final topHeadline = intel.bearishCatalysts.isNotEmpty
              ? intel.bearishCatalysts.first
              : (intel.articles.isNotEmpty
                  ? intel.articles.first.title
                  : intel.headlineSummary);
          final detail = holdingStr.isNotEmpty
              ? 'Held in portfolio ($holdingStr). $topHeadline'
              : topHeadline;

          candidate = PortfolioAlert(
            id: 'news-regime-bearish-$sym',
            severity: PortfolioAlertSeverity.warning,
            icon: Icons.mood_bad,
            title: '$sym: Very bearish news sentiment',
            detail: detail,
            metric: '${intel.overallSentiment.toStringAsFixed(0)}/100',
            target: PortfolioAlertTarget.insights,
          );
        } else if (intel.sentimentLabel == NewsSentimentLabel.veryBullish ||
            intel.overallSentiment > 80.0) {
          final topHeadline = intel.bullishCatalysts.isNotEmpty
              ? intel.bullishCatalysts.first
              : (intel.articles.isNotEmpty
                  ? intel.articles.first.title
                  : intel.headlineSummary);
          final detail = holdingStr.isNotEmpty
              ? 'Held in portfolio ($holdingStr). $topHeadline'
              : topHeadline;

          candidate = PortfolioAlert(
            id: 'news-regime-bullish-$sym',
            severity: PortfolioAlertSeverity.positive,
            icon: Icons.sentiment_very_satisfied,
            title: '$sym: Very bullish news sentiment',
            detail: detail,
            metric: '${intel.overallSentiment.toStringAsFixed(0)}/100',
            target: PortfolioAlertTarget.insights,
          );
        }
      }

      if (candidate != null) {
        alerts.add(candidate);
      }
    }

    return alerts;
  }

  /// Evaluates a SmartAlertRule against a NewsIntelligence object.
  static bool evaluateNewsAlert({
    required SmartAlertRule rule,
    required NewsIntelligence intelligence,
  }) {
    if (rule.type != AlertType.news) return false;

    switch (rule.condition) {
      case AlertCondition.high_impact_news:
        return intelligence.impactRating == NewsImpact.high;
      case AlertCondition.sentiment_bearish:
        if (rule.value > 0) {
          return intelligence.overallSentiment <= rule.value;
        }
        return intelligence.overallSentiment <= 40.0 ||
            intelligence.sentimentLabel == NewsSentimentLabel.bearish ||
            intelligence.sentimentLabel == NewsSentimentLabel.veryBearish;
      case AlertCondition.sentiment_bullish:
        if (rule.value > 0) {
          return intelligence.overallSentiment >= rule.value;
        }
        return intelligence.overallSentiment >= 60.0 ||
            intelligence.sentimentLabel == NewsSentimentLabel.bullish ||
            intelligence.sentimentLabel == NewsSentimentLabel.veryBullish;
      case AlertCondition.sentiment_drop_24h:
        final threshold = rule.value > 0
            ? -rule.value
            : (rule.value != 0 ? rule.value : -15.0);
        return intelligence.sentimentScoreChange24h <= threshold;
      case AlertCondition.sentiment_surge_24h:
        final threshold = rule.value > 0 ? rule.value : 15.0;
        return intelligence.sentimentScoreChange24h >= threshold;
      case AlertCondition.above:
        return intelligence.overallSentiment >= rule.value;
      case AlertCondition.below:
        return intelligence.overallSentiment <= rule.value;
      default:
        return intelligence.overallSentiment >= rule.value;
    }
  }

  static List<PortfolioAlert> _volatilityConeAlerts(
      List<VolatilityConeAnalysis>? analyses) {
    final alerts = <PortfolioAlert>[];
    if (analyses == null || analyses.isEmpty) return alerts;

    for (final analysis in analyses) {
      final metrics = analysis.metrics30d;
      final regime = analysis.overallRegime;

      if (regime == VolatilityRegime.extreme) {
        alerts.add(
          PortfolioAlert(
            id: 'volatility_cone_extreme_${analysis.symbol}',
            severity: PortfolioAlertSeverity.warning,
            icon: Icons.warning_amber_rounded,
            title:
                '${analysis.symbol} Extreme Volatility Surge (IV Rank: ${metrics.ivRank.toStringAsFixed(0)}%)',
            detail:
                'Implied volatility (${(metrics.currentIv * 100).toStringAsFixed(1)}%) is trading at historical extremes vs. realized movement. High risk of mean-reverting IV collapse.',
            metric: '${metrics.ivRank.toStringAsFixed(0)}% IVR',
            target: PortfolioAlertTarget.volatilityCone,
          ),
        );
      } else if (regime == VolatilityRegime.expensive) {
        alerts.add(
          PortfolioAlert(
            id: 'volatility_cone_expensive_${analysis.symbol}',
            severity: PortfolioAlertSeverity.info,
            icon: Icons.arrow_upward_rounded,
            title:
                '${analysis.symbol} Elevated Implied Volatility (IV Rank: ${metrics.ivRank.toStringAsFixed(0)}%)',
            detail:
                'Options trade above the 75th percentile of historical realized movement. Positive Variance Risk Premium favors credit collection structures.',
            metric: '${metrics.ivRank.toStringAsFixed(0)}% IVR',
            target: PortfolioAlertTarget.volatilityCone,
          ),
        );
      } else if (regime == VolatilityRegime.cheap) {
        alerts.add(
          PortfolioAlert(
            id: 'volatility_cone_cheap_${analysis.symbol}',
            severity: PortfolioAlertSeverity.positive,
            icon: Icons.arrow_downward_rounded,
            title:
                '${analysis.symbol} Underpriced Volatility (IV Rank: ${metrics.ivRank.toStringAsFixed(0)}%)',
            detail:
                'Options trade in the bottom quartile of historical movement. Option purchase and calendar spreads offer high leverage at minimal extrinsic cost.',
            metric: '${metrics.ivRank.toStringAsFixed(0)}% IVR',
            target: PortfolioAlertTarget.volatilityCone,
          ),
        );
      }
    }
    return alerts;
  }

  /// Generates Action Center alerts from 3D Implied Volatility Surface analyses.
  static List<PortfolioAlert> _ivSurfaceAlerts(
      List<IvSurfaceAnalysis>? analyses) {
    final alerts = <PortfolioAlert>[];
    if (analyses == null || analyses.isEmpty) return alerts;

    for (final analysis in analyses) {
      final metrics = analysis.metrics;

      if (metrics.regime == IvSurfaceRegime.backwardation) {
        alerts.add(
          PortfolioAlert(
            id: 'iv_surface_inverted_${analysis.symbol}',
            severity: PortfolioAlertSeverity.warning,
            icon: Icons.warning_amber_rounded,
            title: '${analysis.symbol} Volatility Surface Inverted',
            detail:
                'Short-term options (${(metrics.atmShortTermIv * 100).toStringAsFixed(1)}%) trade at a sharp premium to back months (${(metrics.atmLongTermIv * 100).toStringAsFixed(1)}%). Indicates acute catalyst or stress.',
            metric: '${(metrics.atmShortTermIv * 100).toStringAsFixed(0)}% IV',
            target: PortfolioAlertTarget.ivSurface,
          ),
        );
      } else if (metrics.hasArbitrage) {
        alerts.add(
          PortfolioAlert(
            id: 'iv_surface_arbitrage_${analysis.symbol}',
            severity: PortfolioAlertSeverity.info,
            icon: Icons.auto_awesome_motion_rounded,
            title: '${analysis.symbol} Pricing Anomaly on IV Surface',
            detail:
                '${metrics.arbitrageCount} potential calendar or butterfly spread pricing discrepancies detected across expiration tenors.',
            metric: '${metrics.arbitrageCount} Spreads',
            target: PortfolioAlertTarget.ivSurface,
          ),
        );
      } else if (metrics.regime == IvSurfaceRegime.extremePutSkew) {
        alerts.add(
          PortfolioAlert(
            id: 'iv_surface_skew_${analysis.symbol}',
            severity: PortfolioAlertSeverity.info,
            icon: Icons.shield_rounded,
            title: '${analysis.symbol} Steep Downside Put Skew',
            detail:
                '25-Delta put/call risk reversal is ${(metrics.riskReversal25D * 100).toStringAsFixed(1)}% vol points, indicating heavy demand for downside tail protection.',
            metric:
                '+${(metrics.riskReversal25D * 100).toStringAsFixed(0)}% Skew',
            target: PortfolioAlertTarget.ivSurface,
          ),
        );
      }
    }
    return alerts;
  }

  /// Evaluates a SmartAlertRule against an IvSurfaceAnalysis.
  static bool evaluateIvSurfaceAlert({
    required SmartAlertRule rule,
    required IvSurfaceAnalysis analysis,
  }) {
    if (rule.type != AlertType.iv_surface) return false;

    switch (rule.condition) {
      case AlertCondition.surface_inversion:
        return analysis.metrics.regime == IvSurfaceRegime.backwardation;
      case AlertCondition.above_surface_skew:
      case AlertCondition.above:
        return analysis.metrics.riskReversal25D >= (rule.value / 100.0);
      case AlertCondition.arbitrage_detected:
        return analysis.metrics.hasArbitrage;
      default:
        return analysis.metrics.meanIv >= (rule.value / 100.0);
    }
  }

  /// Evaluates a SmartAlertRule against a VolatilityConeAnalysis.
  static bool evaluateVolatilityConeAlert({
    required SmartAlertRule rule,
    required VolatilityConeAnalysis analysis,
  }) {
    if (rule.type != AlertType.volatility_cone) return false;

    switch (rule.condition) {
      case AlertCondition.above_iv_rank:
      case AlertCondition.above:
        return analysis.metrics30d.ivRank >= rule.value;
      case AlertCondition.below_iv_rank:
      case AlertCondition.below:
        return analysis.metrics30d.ivRank <= rule.value;
      case AlertCondition.above_vrp:
        return analysis.vrp.vrp30d >= (rule.value / 100.0);
      default:
        return analysis.metrics30d.ivRank >= rule.value;
    }
  }

  static List<PortfolioAlert> _deltaNeutralAlerts(
    List<DeltaNeutralAnalysis>? deltaNeutralAnalyses,
  ) {
    if (deltaNeutralAnalyses == null || deltaNeutralAnalyses.isEmpty) {
      return const [];
    }

    final alerts = <PortfolioAlert>[];
    for (final analysis in deltaNeutralAnalyses) {
      final drift = analysis.netDelta - analysis.targetDelta;
      final deltaSign = drift >= 0 ? '+' : '';
      final deltaStr = '$deltaSign${drift.toStringAsFixed(1)} Δ';

      if (analysis.driftStatus == DeltaDriftStatus.severeDrift) {
        alerts.add(
          PortfolioAlert(
            id: 'delta_neutral_severe_${analysis.symbol}',
            severity: PortfolioAlertSeverity.warning,
            icon: Icons.error_outline_rounded,
            title: '${analysis.symbol} Severe Delta Imbalance ($deltaStr)',
            detail: analysis.rebalanceSuggestion.summaryText,
            metric: deltaStr,
            target: PortfolioAlertTarget.deltaNeutral,
          ),
        );
      } else if (analysis.driftStatus == DeltaDriftStatus.mildDrift) {
        alerts.add(
          PortfolioAlert(
            id: 'delta_neutral_mild_${analysis.symbol}',
            severity: PortfolioAlertSeverity.info,
            icon: Icons.tune_rounded,
            title: '${analysis.symbol} Delta Rebalance Suggested',
            detail: analysis.rebalanceSuggestion.summaryText,
            metric: deltaStr,
            target: PortfolioAlertTarget.deltaNeutral,
          ),
        );
      }
    }
    return alerts;
  }

  static List<PortfolioAlert> _optionExpirationAlerts(
    List<OptionAggregatePosition> optionPositions,
    DateTime now,
  ) {
    final alerts = <PortfolioAlert>[];
    final today = DateTime(now.year, now.month, now.day);

    for (final pos in optionPositions) {
      final qty = pos.quantity ?? 0.0;
      if (qty <= 0) continue;

      final firstLeg = pos.legs.isNotEmpty ? pos.legs.first : null;
      final expDate =
          pos.optionInstrument?.expirationDate ?? firstLeg?.expirationDate;
      if (expDate == null) continue;

      final expDay = DateTime(expDate.year, expDate.month, expDate.day);
      final daysToExpiration = expDay.difference(today).inDays;

      // Ignore already past/expired contracts (> 0 days in the past)
      if (daysToExpiration < 0) continue;

      // Only alert within the immediate expiration window (<= 3 calendar days)
      if (daysToExpiration > 3) continue;

      final symbol = pos.symbol.isNotEmpty
          ? pos.symbol
          : (pos.optionInstrument?.chainSymbol ?? 'Option');
      final strike = firstLeg?.strikePrice ?? pos.optionInstrument?.strikePrice;
      final strikeStr = strike != null
          ? '\$${strike.toStringAsFixed(strike.truncateToDouble() == strike ? 0 : 2)}'
          : '';
      final optionType = (firstLeg?.optionType ??
              pos.optionInstrument?.type ??
              '')
          .toUpperCase();
      final isShort = pos.direction == 'credit' ||
          pos.strategy.startsWith('short') ||
          pos.legs.any((l) => l.positionType == 'short');

      // Determine spot price and moneyness if available
      final spotPrice = pos.instrumentObj?.quoteObj?.lastTradePrice ??
          pos.instrumentObj?.quoteObj?.lastExtendedHoursTradePrice ??
          pos.instrumentObj?.quoteObj?.previousClose;

      bool? isItm;
      if (spotPrice != null && strike != null) {
        if (optionType == 'CALL') {
          isItm = spotPrice >= strike;
        } else if (optionType == 'PUT') {
          isItm = spotPrice <= strike;
        }
      }

      final moneynessStr = isItm == null
          ? ''
          : isItm
              ? 'ITM'
              : 'OTM';

      final contractDesc = [
        symbol,
        if (strikeStr.isNotEmpty) strikeStr,
        if (optionType.isNotEmpty) optionType,
      ].join(' ');

      final id =
          'opt-exp-${pos.id.isNotEmpty ? pos.id : symbol}-$daysToExpiration';

      if (daysToExpiration == 0) {
        // 0 DTE: Expiring Today
        final String detail;
        if (isShort) {
          detail =
              '$contractDesc expires today. High risk of assignment or delivery obligation at 4:00 PM ET.';
        } else if (isItm == true) {
          detail =
              '$contractDesc is In-The-Money ($moneynessStr) and expires today. Will be automatically exercised unless closed before market close.';
        } else if (isItm == false) {
          detail =
              '$contractDesc is Out-of-The-Money ($moneynessStr) and expires today. Will expire worthless at market close unless underlying moves.';
        } else {
          detail =
              '$contractDesc expires today. Review to close, exercise, or roll before market close.';
        }

        alerts.add(
          PortfolioAlert(
            id: id,
            severity: PortfolioAlertSeverity.critical,
            icon: isShort
                ? Icons.assignment_late_outlined
                : Icons.timer_outlined,
            title: '$contractDesc expires today',
            detail: detail,
            metric: '0 DTE${moneynessStr.isNotEmpty ? ' • $moneynessStr' : ''}',
            target: isShort
                ? PortfolioAlertTarget.strategies
                : PortfolioAlertTarget.positions,
          ),
        );
      } else if (daysToExpiration == 1) {
        // 1 DTE: Expiring Tomorrow
        final String detail;
        if (isShort) {
          detail =
              '$contractDesc expires tomorrow. Consider rolling or closing to manage assignment exposure.';
        } else if (isItm == true) {
          detail =
              '$contractDesc is ITM and expires tomorrow. Plan for exercise, rolling, or taking profit.';
        } else if (isItm == false) {
          detail =
              '$contractDesc is OTM and expires tomorrow. Rapid theta decay in effect; assess rolling or exit.';
        } else {
          detail =
              '$contractDesc expires tomorrow. Review positions before final trading session.';
        }

        alerts.add(
          PortfolioAlert(
            id: id,
            severity: PortfolioAlertSeverity.warning,
            icon: Icons.alarm_on_outlined,
            title: '$contractDesc expires tomorrow',
            detail: detail,
            metric: '1 DTE${moneynessStr.isNotEmpty ? ' • $moneynessStr' : ''}',
            target: isShort
                ? PortfolioAlertTarget.strategies
                : PortfolioAlertTarget.positions,
          ),
        );
      } else {
        // 2-3 DTE: Expiring Soon
        final severity = (isShort || isItm == true)
            ? PortfolioAlertSeverity.warning
            : PortfolioAlertSeverity.info;
        final detail = isShort
            ? '$contractDesc expires in $daysToExpiration days. Monitor underlying price for assignment buffer.'
            : '$contractDesc expires in $daysToExpiration days. Evaluate options strategy roll or profit targets as theta decay accelerates.';

        alerts.add(
          PortfolioAlert(
            id: id,
            severity: severity,
            icon: Icons.event_available_outlined,
            title: '$contractDesc expires in $daysToExpiration days',
            detail: detail,
            metric:
                '${daysToExpiration}d DTE${moneynessStr.isNotEmpty ? ' • $moneynessStr' : ''}',
            target: isShort
                ? PortfolioAlertTarget.strategies
                : PortfolioAlertTarget.positions,
          ),
        );
      }
    }

    return alerts;
  }

  /// Evaluates a SmartAlertRule against a DeltaNeutralAnalysis.
  static bool evaluateDeltaNeutralAlert({
    required SmartAlertRule rule,
    required DeltaNeutralAnalysis analysis,
  }) {
    if (rule.type != AlertType.delta_neutral) return false;

    final drift = (analysis.netDelta - analysis.targetDelta).abs();
    switch (rule.condition) {
      case AlertCondition.delta_drift_exceeded:
      case AlertCondition.above:
        return drift >= rule.value;
      case AlertCondition.below:
        return drift <= rule.value;
      case AlertCondition.delta_rebalance_required:
        return analysis.driftStatus != DeltaDriftStatus.neutral;
      default:
        return drift >= rule.value;
    }
  }
}
