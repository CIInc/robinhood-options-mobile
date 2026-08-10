import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';
import 'package:robinhood_options_mobile/widgets/home/agentic_trading_card_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/futures_auto_trading_card_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/options_flow_card_widget.dart';
import 'package:robinhood_options_mobile/widgets/paper_trading_dashboard_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio_gex_dashboard_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_context.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_scaffold.dart';
import 'package:robinhood_options_mobile/widgets/rebalancing_widget.dart';

/// Automation, derivatives analysis, and simulation gathered from the old
/// portfolio scroll.
///
/// These are all "things running on your behalf" rather than facts about the
/// portfolio, which is why they no longer sit between the allocation chart and
/// the position lists.
class StrategiesSectionPage extends StatelessWidget {
  final PortfolioSectionContext sectionContext;

  const StrategiesSectionPage({super.key, required this.sectionContext});

  @override
  Widget build(BuildContext context) {
    final ctx = sectionContext;
    final appUser = ctx.appUser;
    final userDocRef = ctx.userDocRef;
    final account = ctx.account;

    return PortfolioSectionScaffold(
      title: 'Strategies',
      subtitle: 'Automation, options flow, GEX & simulation',
      cards: [
        AgenticTradingCardWidget(
          user: appUser,
          userDocRef: userDocRef,
          brokerageUser: ctx.brokerageUser,
          service: ctx.service,
          analytics: ctx.analytics,
          outerPadding: EdgeInsets.zero,
        ),
        FuturesAutoTradingCardWidget(
          user: appUser,
          userDocRef: userDocRef,
          service: ctx.service,
          analytics: ctx.analytics,
          outerPadding: EdgeInsets.zero,
        ),
        OptionsFlowCardWidget(
          brokerageUser: ctx.brokerageUser,
          service: ctx.service,
          analytics: ctx.analytics,
          observer: ctx.observer,
          generativeService: ctx.generativeService,
          user: appUser,
          userDocRef: userDocRef,
          includePortfolioSymbols: true,
          outerPadding: EdgeInsets.zero,
        ),
        _entry(
          context,
          icon: Icons.analytics_outlined,
          title: 'Portfolio GEX Dashboard',
          subtitle: 'Monitor aggregate dealer gamma across your holdings',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PortfolioGexDashboardWidget(
                brokerageUser: ctx.brokerageUser,
                service: ctx.service,
                user: appUser,
                userDocRef: userDocRef,
                analytics: ctx.analytics,
                observer: ctx.observer,
                generativeService: ctx.generativeService,
              ),
            ),
          ),
        ),
        if (appUser != null && userDocRef != null && account != null)
          _entry(
            context,
            icon: Icons.balance,
            title: 'Rebalance Portfolio',
            subtitle: 'Set allocation targets and see the trades to get there',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RebalancingWidget(
                  user: appUser,
                  userDocRef: userDocRef,
                  account: account,
                ),
              ),
            ),
          ),
        _entry(
          context,
          icon: Icons.school_outlined,
          title: 'Paper Trading Simulator',
          subtitle: 'Practice trading with virtual money',
          // Simulated trading targets one account, so it stays disabled while
          // the user is viewing all brokerages at once.
          onTap: ctx.isAggregateMode
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaperTradingDashboardWidget(
                        analytics: ctx.analytics,
                        observer: ctx.observer,
                        brokerageUser: ctx.brokerageUser,
                        service: ctx.service,
                        user: appUser,
                        userDocRef: userDocRef,
                      ),
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _entry(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return AnalyticsStyleCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        enabled: onTap != null,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon,
              size: 24, color: theme.colorScheme.onSecondaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
