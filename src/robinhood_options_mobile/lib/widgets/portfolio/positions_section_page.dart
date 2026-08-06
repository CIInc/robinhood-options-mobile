import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';
import 'package:robinhood_options_mobile/widgets/home/allocation_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_movers_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_context.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_scaffold.dart';
import 'package:robinhood_options_mobile/widgets/risk_heatmap_widget.dart';

/// "Why did it happen?" — the holding-level views that read as pictures.
///
/// The per-asset-class ledgers are deliberately *not* here. Each asset class has
/// a summary card on the Portfolio overview whose chevron opens its own full
/// page, so repeating the lists here would be a second path to the same rows and
/// would put this section back to the long scroll it was built to replace.
class PositionsSectionPage extends StatelessWidget {
  final PortfolioSectionContext sectionContext;

  const PositionsSectionPage({super.key, required this.sectionContext});

  @override
  Widget build(BuildContext context) {
    final ctx = sectionContext;

    return PortfolioSectionScaffold(
      title: 'Positions',
      subtitle: 'Allocation, sectors & concentration',
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
