import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/insights_section_page.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/performance_section_page.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_context.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/positions_section_page.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/risk_section_page.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/strategies_section_page.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/taxes_section_page.dart';
import 'package:robinhood_options_mobile/widgets/rebalancing_widget.dart';

/// One place that knows how to open every Portfolio destination.
///
/// Both the Browse grid and the Action Center route through here, so a tapped
/// alert and a tapped tile always land on the same screen.
class PortfolioNavigator {
  const PortfolioNavigator._();

  static Future<void> openSection(
    BuildContext context,
    PortfolioSection section,
    PortfolioSectionContext sectionContext,
  ) {
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
      case PortfolioAlertTarget.positions:
        return openSection(context, PortfolioSection.positions, sectionContext);
      case PortfolioAlertTarget.performance:
        return openSection(
            context, PortfolioSection.performance, sectionContext);
      case PortfolioAlertTarget.risk:
        return openSection(context, PortfolioSection.risk, sectionContext);
      case PortfolioAlertTarget.insights:
        return openSection(context, PortfolioSection.insights, sectionContext);
      case PortfolioAlertTarget.taxes:
        return openSection(context, PortfolioSection.taxes, sectionContext);
      case PortfolioAlertTarget.strategies:
        return openSection(
            context, PortfolioSection.strategies, sectionContext);
      case PortfolioAlertTarget.rebalance:
        return _openRebalance(context, sectionContext);
      case PortfolioAlertTarget.none:
        return Future.value();
    }
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
        return TaxesSectionPage(sectionContext: sectionContext);
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
}
