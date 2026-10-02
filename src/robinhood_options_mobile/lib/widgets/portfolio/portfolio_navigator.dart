import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/earnings_iv_crush_model.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/model/zero_dte_squeeze_radar_model.dart';
import 'package:robinhood_options_mobile/widgets/automated_drip_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/congress_trading_dashboard_widget.dart';
import 'package:robinhood_options_mobile/widgets/day_trade_monitor_widget.dart';
import 'package:robinhood_options_mobile/widgets/delta_neutral_builder_widget.dart';
import 'package:robinhood_options_mobile/widgets/earnings_iv_crush_widget.dart';
import 'package:robinhood_options_mobile/widgets/income_transactions_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/iv_surface_3d_widget.dart';
import 'package:robinhood_options_mobile/widgets/news_intelligence_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_page_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/insights_section_page.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/performance_section_page.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_context.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/positions_section_page.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/risk_section_page.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/strategies_section_page.dart';
import 'package:robinhood_options_mobile/widgets/rebalancing_widget.dart';
import 'package:robinhood_options_mobile/widgets/tax_optimization_widget.dart';
import 'package:robinhood_options_mobile/widgets/volatility_cone_widget.dart';
import 'package:robinhood_options_mobile/widgets/zero_dte_squeeze_radar_widget.dart';
import 'package:robinhood_options_mobile/widgets/search_widget.dart';
import 'package:robinhood_options_mobile/widgets/tab_navigation.dart';

/// One place that knows how to open every Portfolio destination.
///
/// Both the Browse grid and the Action Center route through here. Alert taps
/// deep-link directly into the closest contextual screen (e.g. specific stock,
/// 0DTE squeeze radar, earnings IV crush dashboard, day trade monitor, etc.)
/// rather than generic top-level parent views whenever possible.
class PortfolioNavigator {
  const PortfolioNavigator._();

  static Future<void> openSection(
    BuildContext context,
    PortfolioSection section,
    PortfolioSectionContext sectionContext,
  ) {
    final isPaper =
        sectionContext.brokerageUser.source == BrokerageSource.paper ||
            sectionContext.account?.accountNumber == 'paper_account';
    if (section == PortfolioSection.taxes && isPaper) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Tax optimization does not apply to paper trading accounts.'),
          duration: Duration(seconds: 3),
        ),
      );
      return Future.value();
    }
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _pageFor(section, sectionContext),
      ),
    );
  }

  static Future<void> openAlert(
    BuildContext context,
    PortfolioAlert alert,
    PortfolioSectionContext sectionContext,
  ) {
    switch (alert.target) {
      case PortfolioAlertTarget.zeroDteRadar:
        return _openZeroDteRadar(context, sectionContext, alert);
      case PortfolioAlertTarget.earningsIvCrush:
        return _openEarningsIvCrush(context, sectionContext, alert);
      case PortfolioAlertTarget.volatilityCone:
        return _openVolatilityCone(context, sectionContext, alert);
      case PortfolioAlertTarget.ivSurface:
        return _openIvSurface(context, sectionContext, alert);
      case PortfolioAlertTarget.deltaNeutral:
        return _openDeltaNeutral(context, sectionContext, alert);
      case PortfolioAlertTarget.congressionalTrading:
        return _openCongressionalTrading(context, sectionContext, alert);
      case PortfolioAlertTarget.newsIntelligence:
        return _openNewsIntelligence(context, sectionContext, alert);
      case PortfolioAlertTarget.pdtMonitor:
        return _openPdtMonitor(context, sectionContext);
      case PortfolioAlertTarget.dripSettings:
        return _openDripSettings(context, sectionContext);
      case PortfolioAlertTarget.dividends:
        return _openIncomeTransactions(context, sectionContext, alert.symbol);
      case PortfolioAlertTarget.instrument:
        if (alert.symbol != null) {
          final inst = _findInstrument(context, alert.symbol!);
          if (inst != null) {
            return _openInstrument(context, sectionContext, inst);
          }
        }
        return openSection(context, PortfolioSection.positions, sectionContext);
      case PortfolioAlertTarget.positions:
        if (alert.symbol != null) {
          final inst = _findInstrument(context, alert.symbol!);
          if (inst != null) {
            return _openInstrument(context, sectionContext, inst);
          }
        }
        return openSection(context, PortfolioSection.positions, sectionContext);
      case PortfolioAlertTarget.optionPositions:
      case PortfolioAlertTarget.optionDefense:
        return _openOptionPositions(context, sectionContext,
            symbol: alert.symbol);
      case PortfolioAlertTarget.rebalance:
        return _openRebalance(context, sectionContext);
      case PortfolioAlertTarget.performance:
        if (alert.id.startsWith('dividend') || alert.category == 'Dividends') {
          return _openIncomeTransactions(context, sectionContext, alert.symbol);
        }
        return openSection(
            context, PortfolioSection.performance, sectionContext);
      case PortfolioAlertTarget.risk:
        if (alert.id.startsWith('pdt-')) {
          return _openPdtMonitor(context, sectionContext);
        }
        return openSection(context, PortfolioSection.risk, sectionContext);
      case PortfolioAlertTarget.insights:
        if (alert.id.startsWith('news-') || alert.category == 'News') {
          return _openNewsIntelligence(context, sectionContext, alert);
        }
        return openSection(context, PortfolioSection.insights, sectionContext);
      case PortfolioAlertTarget.taxes:
        return openSection(context, PortfolioSection.taxes, sectionContext);
      case PortfolioAlertTarget.strategies:
        if (alert.id.startsWith('drip-') || alert.category == 'DRIP') {
          return _openDripSettings(context, sectionContext);
        }
        return openSection(
            context, PortfolioSection.strategies, sectionContext);
      case PortfolioAlertTarget.search:
        return _openSearch(context, sectionContext);
      case PortfolioAlertTarget.none:
        return Future.value();
    }
  }

  static Instrument? _findInstrument(BuildContext context, String symbol) {
    try {
      final posStore =
          Provider.of<InstrumentPositionStore>(context, listen: false);
      final match = posStore.items.firstWhereOrNull(
        (p) => p.instrumentObj?.symbol.toUpperCase() == symbol.toUpperCase(),
      );
      if (match?.instrumentObj != null) return match!.instrumentObj;
    } catch (_) {}

    try {
      final instStore = Provider.of<InstrumentStore>(context, listen: false);
      final match = instStore.items.firstWhereOrNull(
        (i) => i.symbol.toUpperCase() == symbol.toUpperCase(),
      );
      if (match != null) return match;
    } catch (_) {}

    return null;
  }

  static Future<void> _openInstrument(
    BuildContext context,
    PortfolioSectionContext sectionContext,
    Instrument instrument,
  ) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InstrumentWidget(
          sectionContext.brokerageUser,
          sectionContext.service,
          instrument,
          analytics: sectionContext.analytics,
          observer: sectionContext.observer,
          generativeService: sectionContext.generativeService,
          user: sectionContext.appUser,
          userDocRef: sectionContext.userDocRef,
        ),
      ),
    );
  }

  static Future<void> _openZeroDteRadar(
    BuildContext context,
    PortfolioSectionContext sectionContext,
    PortfolioAlert alert,
  ) {
    final sym = alert.symbol;
    if (sym == null || sym.isEmpty) {
      return openSection(context, PortfolioSection.risk, sectionContext);
    }

    final result = alert.payload?['result'] as ZeroDteSqueezeRadarResult?;
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('$sym 0DTE Squeeze Radar'),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ZeroDteSqueezeRadarWidget(
                symbol: sym,
                precomputedResult: result,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _openEarningsIvCrush(
    BuildContext context,
    PortfolioSectionContext sectionContext,
    PortfolioAlert alert,
  ) {
    final sym = alert.symbol;
    if (sym == null || sym.isEmpty) {
      return openSection(context, PortfolioSection.risk, sectionContext);
    }

    final analysis = alert.payload?['analysis'] as EarningsIvCrushAnalysis?;
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EarningsIvCrushWidget(
          symbol: sym,
          user: sectionContext.appUser,
          brokerageUser: sectionContext.brokerageUser,
          service: sectionContext.service,
          precomputedAnalysis: analysis,
        ),
      ),
    );
  }

  static Future<void> _openVolatilityCone(
    BuildContext context,
    PortfolioSectionContext sectionContext,
    PortfolioAlert alert,
  ) {
    final sym = alert.symbol;
    if (sym == null || sym.isEmpty) {
      return openSection(context, PortfolioSection.risk, sectionContext);
    }

    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VolatilityConeWidget(
          symbol: sym,
          user: sectionContext.appUser,
          brokerageUser: sectionContext.brokerageUser,
          service: sectionContext.service,
        ),
      ),
    );
  }

  static Future<void> _openIvSurface(
    BuildContext context,
    PortfolioSectionContext sectionContext,
    PortfolioAlert alert,
  ) {
    final sym = alert.symbol;
    if (sym == null || sym.isEmpty) {
      return openSection(context, PortfolioSection.risk, sectionContext);
    }

    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IvSurface3dWidget(
          symbol: sym,
          user: sectionContext.appUser,
          brokerageUser: sectionContext.brokerageUser,
          service: sectionContext.service,
        ),
      ),
    );
  }

  static Future<void> _openDeltaNeutral(
    BuildContext context,
    PortfolioSectionContext sectionContext,
    PortfolioAlert alert,
  ) {
    final sym = alert.symbol;
    if (sym == null || sym.isEmpty) {
      return openSection(context, PortfolioSection.risk, sectionContext);
    }

    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeltaNeutralBuilderWidget(
          symbol: sym,
          user: sectionContext.appUser,
          brokerageUser: sectionContext.brokerageUser,
          service: sectionContext.service,
        ),
      ),
    );
  }

  static Future<void> _openCongressionalTrading(
    BuildContext context,
    PortfolioSectionContext sectionContext,
    PortfolioAlert alert,
  ) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CongressTradingDashboardWidget(
          brokerageUser: sectionContext.brokerageUser,
          initialSymbol: alert.symbol,
        ),
      ),
    );
  }

  static Future<void> _openNewsIntelligence(
    BuildContext context,
    PortfolioSectionContext sectionContext,
    PortfolioAlert alert,
  ) {
    final sym = alert.symbol;
    if (sym != null && sym.isNotEmpty) {
      return Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NewsIntelligenceWidget(symbol: sym),
        ),
      );
    }
    return openSection(context, PortfolioSection.insights, sectionContext);
  }

  static Future<void> _openPdtMonitor(
    BuildContext context,
    PortfolioSectionContext sectionContext,
  ) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DayTradeMonitorWidget(
          brokerageUser: sectionContext.brokerageUser,
          service: sectionContext.service,
          account: sectionContext.account,
        ),
      ),
    );
  }

  static Future<void> _openDripSettings(
    BuildContext context,
    PortfolioSectionContext sectionContext,
  ) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AutomatedDripSettingsWidget(
          user: sectionContext.appUser,
          userDocRef: sectionContext.userDocRef,
          brokerageUser: sectionContext.brokerageUser,
          brokerageService: sectionContext.service,
        ),
      ),
    );
  }

  static Future<void> _openIncomeTransactions(
    BuildContext context,
    PortfolioSectionContext sectionContext,
    String? symbol,
  ) {
    DividendStore? divStore;
    try {
      divStore = Provider.of<DividendStore>(context, listen: false);
    } catch (_) {}
    if (divStore == null) {
      return openSection(context, PortfolioSection.performance, sectionContext);
    }

    InstrumentPositionStore? posStore;
    try {
      posStore = Provider.of<InstrumentPositionStore>(context, listen: false);
    } catch (_) {}
    InstrumentOrderStore? orderStore;
    try {
      orderStore = Provider.of<InstrumentOrderStore>(context, listen: false);
    } catch (_) {}
    ChartSelectionStore? chartStore;
    try {
      chartStore = Provider.of<ChartSelectionStore>(context, listen: false);
    } catch (_) {}
    InterestStore? intStore;
    try {
      intStore = Provider.of<InterestStore?>(context, listen: false);
    } catch (_) {}

    if (posStore == null || orderStore == null || chartStore == null) {
      return openSection(context, PortfolioSection.performance, sectionContext);
    }

    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title:
                Text(symbol != null ? '$symbol Income' : 'Income & Dividends'),
          ),
          body: CustomScrollView(
            slivers: [
              IncomeTransactionsWidget(
                sectionContext.brokerageUser,
                sectionContext.service,
                divStore!,
                posStore!,
                orderStore!,
                chartStore!,
                interestStore: intStore,
                analytics: sectionContext.analytics,
                observer: sectionContext.observer,
                transactionSymbolFilters:
                    symbol != null ? [symbol] : const <String>[],
                isFullScreen: false,
                showList: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _openOptionPositions(
    BuildContext context,
    PortfolioSectionContext sectionContext, {
    String? symbol,
  }) {
    final account = sectionContext.account;
    final allPositions =
        Provider.of<OptionPositionStore>(context, listen: false)
            .items
            .where((position) =>
                sectionContext.isAggregateMode ||
                account == null ||
                position.account == account.accountNumber ||
                position.account == account.url)
            .toList();

    List<OptionAggregatePosition> positions = allPositions;
    if (symbol != null && symbol.isNotEmpty) {
      final filtered = allPositions
          .where((p) =>
              p.symbol.toUpperCase() == symbol.toUpperCase() ||
              (p.optionInstrument?.chainSymbol ?? '').toUpperCase() ==
                  symbol.toUpperCase())
          .toList();
      if (filtered.isNotEmpty) {
        positions = filtered;
      }
    }

    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OptionPositionsPageWidget(
          sectionContext.brokerageUser,
          sectionContext.service,
          positions,
          analytics: sectionContext.analytics,
          observer: sectionContext.observer,
          generativeService: sectionContext.generativeService,
          user: sectionContext.appUser,
          userDocRef: sectionContext.userDocRef,
          disableNavigation: sectionContext.isAggregateMode,
        ),
      ),
    );
  }

  static Widget _pageFor(
      PortfolioSection section, PortfolioSectionContext sectionContext) {
    switch (section) {
      case PortfolioSection.positions:
        return PositionsSectionPage(sectionContext: sectionContext);
      case PortfolioSection.performance:
        return PerformanceSectionPage(sectionContext: sectionContext);
      case PortfolioSection.risk:
        return RiskSectionPage(sectionContext: sectionContext);
      case PortfolioSection.insights:
        return InsightsSectionPage(sectionContext: sectionContext);
      case PortfolioSection.taxes:
        return TaxOptimizationWidget(
          user: sectionContext.brokerageUser,
          service: sectionContext.service,
          analytics: sectionContext.analytics,
          observer: sectionContext.observer,
          generativeService: sectionContext.generativeService,
          appUser: sectionContext.appUser,
          userDocRef: sectionContext.userDocRef,
          analyticsController: sectionContext.analyticsController,
        );
      case PortfolioSection.strategies:
        return StrategiesSectionPage(sectionContext: sectionContext);
    }
  }

  static Future<void> _openRebalance(
      BuildContext context, PortfolioSectionContext sectionContext) {
    final appUser = sectionContext.appUser;
    final userDocRef = sectionContext.userDocRef;
    final account = sectionContext.account;

    // Rebalancing writes allocation targets against a specific account, so fall
    // back to the Strategies section when we do not have one.
    if (appUser == null || userDocRef == null || account == null) {
      return openSection(context, PortfolioSection.strategies, sectionContext);
    }

    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RebalancingWidget(
          user: appUser,
          userDocRef: userDocRef,
          account: account,
        ),
      ),
    );
  }

  static Future<void> _openSearch(
      BuildContext context, PortfolioSectionContext sectionContext) {
    Navigator.of(context).popUntil((route) => route.isFirst);

    if (sectionContext.onTabChanged != null) {
      sectionContext.onTabChanged!(2);
      return Future.value();
    }

    final tabNav = TabNavigation.of(context);
    if (tabNav != null) {
      tabNav(2);
      return Future.value();
    }

    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchWidget(
          sectionContext.brokerageUser,
          sectionContext.service,
          user: sectionContext.appUser,
          analytics: sectionContext.analytics,
          observer: sectionContext.observer,
          generativeService: sectionContext.generativeService,
          userDocRef: sectionContext.userDocRef,
        ),
      ),
    );
  }
}
