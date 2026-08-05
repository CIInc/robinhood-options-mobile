import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/futures_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';
import 'package:robinhood_options_mobile/widgets/forex_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/futures_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/allocation_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_movers_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_context.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_scaffold.dart';
import 'package:robinhood_options_mobile/widgets/risk_heatmap_widget.dart';

/// "Why did it happen?" — every holding-level view in one place.
///
/// Ordered so the visual answers come first (movers, heatmap, allocation) and
/// the raw ledgers follow. The heatmap in particular is promoted from the
/// bottom of the old scroll to just below the fold here.
class PositionsSectionPage extends StatelessWidget {
  final PortfolioSectionContext sectionContext;

  const PositionsSectionPage({super.key, required this.sectionContext});

  @override
  Widget build(BuildContext context) {
    final ctx = sectionContext;

    return PortfolioSectionScaffold(
      title: 'Positions',
      subtitle: 'Holdings, allocation & sector exposure',
      cards: [
        Consumer<InstrumentPositionStore>(
          builder: (context, store, child) => PortfolioMoversWidget(
            positions: store.items
                .where((position) => _matchesAccount(position.account))
                .toList(),
            rowCount: 5,
          ),
        ),
        const AnalyticsStyleCard(
          padding: EdgeInsets.zero,
          child: RiskHeatmapWidget(),
        ),
        AnalyticsStyleCard(
          padding: EdgeInsets.zero,
          child: AllocationWidget(
            account: ctx.account,
            user: ctx.appUser,
            userDocRef: ctx.userDocRef,
          ),
        ),
      ],
      slivers: [
        if (ctx.brokerageUser.source == BrokerageSource.robinhood)
          Consumer<FuturesPositionStore>(
            builder: (context, store, child) => FuturesPositionsWidget(
              ctx.brokerageUser,
              ctx.service,
              store.items,
              analytics: ctx.analytics,
              observer: ctx.observer,
              generativeService: ctx.generativeService,
              user: ctx.appUser,
              userDocRef: ctx.userDocRef,
              showList: true,
              disableNavigation: ctx.isAggregateMode,
            ),
          ),
        Consumer<OptionPositionStore>(
          builder: (context, store, child) => OptionPositionsWidget(
            ctx.brokerageUser,
            ctx.service,
            store.items
                .where((position) => _matchesAccount(position.account))
                .toList(),
            showList: true,
            analytics: ctx.analytics,
            observer: ctx.observer,
            generativeService: ctx.generativeService,
            user: ctx.appUser,
            userDocRef: ctx.userDocRef,
            disableNavigation: ctx.isAggregateMode,
          ),
        ),
        Consumer<InstrumentPositionStore>(
          builder: (context, store, child) => InstrumentPositionsWidget(
            ctx.brokerageUser,
            ctx.service,
            store.items
                .where((position) =>
                    position.instrumentObj != null &&
                    _matchesAccount(position.account))
                .toList(),
            showList: true,
            analytics: ctx.analytics,
            observer: ctx.observer,
            generativeService: ctx.generativeService,
            user: ctx.appUser,
            userDocRef: ctx.userDocRef,
            disableNavigation: ctx.isAggregateMode,
          ),
        ),
        Consumer<ForexHoldingStore>(
          builder: (context, store, child) => SliverToBoxAdapter(
            // ForexPositionsWidget is itself a sliver, so it needs a viewport
            // to live in when nested under a box-producing builder.
            child: ShrinkWrappingViewport(
              offset: ViewportOffset.zero(),
              slivers: [
                ForexPositionsWidget(
                  ctx.brokerageUser,
                  ctx.service,
                  store.items,
                  showList: true,
                  analytics: ctx.analytics,
                  observer: ctx.observer,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// In aggregate mode every linked account contributes; otherwise only the
  /// selected one does.
  bool _matchesAccount(String? positionAccountUrl) {
    final account = sectionContext.account;
    if (sectionContext.isAggregateMode || account == null) return true;
    return positionAccountUrl == account.url;
  }
}
