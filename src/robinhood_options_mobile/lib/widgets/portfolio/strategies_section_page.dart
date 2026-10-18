import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/enums.dart';
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

    final isPaper = ctx.brokerageUser.source == BrokerageSource.paper ||
        account?.accountNumber == 'paper_account';

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
          disabled: isPaper,
          disabledReason: isPaper ? 'Not applicable to paper trading' : null,
        ),
        FuturesAutoTradingCardWidget(
          user: appUser,
          userDocRef: userDocRef,
          service: ctx.service,
          analytics: ctx.analytics,
          outerPadding: EdgeInsets.zero,
          disabled: isPaper,
          disabledReason: isPaper ? 'Not applicable to paper trading' : null,
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
          subtitle: isPaper
              ? 'Already active (currently in paper trading mode)'
              : 'Practice trading with virtual money',
          disabledReason: isPaper
              ? 'Paper trading simulator is already active'
              : (ctx.isAggregateMode
                  ? 'Paper trading is not available in aggregate mode'
                  : null),
          // Simulated trading targets one account, so it stays disabled while
          // the user is viewing all brokerages at once or already in paper trading.
          onTap: (ctx.isAggregateMode || isPaper)
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
    String? disabledReason,
  }) {
    final theme = Theme.of(context);
    final isEnabled = onTap != null;
    return AnalyticsStyleCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isEnabled
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 24,
            color: isEnabled
                ? theme.colorScheme.onSecondaryContainer
                : theme.colorScheme.outline,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isEnabled
                ? null
                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: TextStyle(
              color: isEnabled ? null : theme.colorScheme.outline,
            ),
          ),
        ),
        trailing: isEnabled
            ? const Icon(Icons.chevron_right)
            : Icon(Icons.block, size: 16, color: theme.colorScheme.outline),
        onTap: isEnabled
            ? onTap
            : () {
                if (disabledReason != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(disabledReason),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
      ),
    );
  }
}
