import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/main.dart' as app_main;
import 'package:robinhood_options_mobile/services/feature_access_service.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';
import 'package:robinhood_options_mobile/widgets/home/agentic_trading_card_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/futures_auto_trading_card_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/options_flow_card_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio_gex_dashboard_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_context.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_scaffold.dart';

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

    UserRole? currentUserRole;
    try {
      currentUserRole = app_main.userRole;
    } catch (_) {}

    final isAutomatedTradingEnabled =
        FeatureAccessService.instance.isFeatureEnabled(
      FeatureBundle.automatedTrading,
      userRole: currentUserRole,
    );
    final isAdvancedResearchEnabled =
        FeatureAccessService.instance.isFeatureEnabled(
      FeatureBundle.advancedResearch,
      userRole: currentUserRole,
    );

    return PortfolioSectionScaffold(
      title: 'Strategies',
      subtitle: 'Automation, options flow & GEX',
      cards: [
        if (isAutomatedTradingEnabled) ...[
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
        ],
        if (isAdvancedResearchEnabled) ...[
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
        ],
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
