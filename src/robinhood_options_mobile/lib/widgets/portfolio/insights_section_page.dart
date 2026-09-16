import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';
import 'package:robinhood_options_mobile/widgets/chat_widget.dart';
import 'package:robinhood_options_mobile/widgets/personalized_coaching_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/ai_insights_card.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_context.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section_scaffold.dart';

/// The single home for AI, merging what were three separate entry points
/// scattered down the old scroll: the trading coach, portfolio insights, and
/// the market assistant.
class InsightsSectionPage extends StatefulWidget {
  final PortfolioSectionContext sectionContext;

  const InsightsSectionPage({super.key, required this.sectionContext});

  @override
  State<InsightsSectionPage> createState() => _InsightsSectionPageState();
}

class _InsightsSectionPageState extends State<InsightsSectionPage> {
  @override
  void initState() {
    super.initState();
    widget.sectionContext.analyticsController.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.sectionContext;
    final controller = ctx.analyticsController;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => PortfolioSectionScaffold(
        title: 'Insights',
        subtitle: 'AI brief, coaching & market assistant',
        cards: [
          if (controller.hasMetrics)
            AiInsightsCard(
              data: controller.metrics,
              generativeService: ctx.generativeService,
              appUser: ctx.appUser,
              benchmarkSymbol: controller.selectedBenchmark,
            ),
          _entry(
            context,
            icon: Icons.auto_awesome,
            title: 'Ask Market Assistant',
            subtitle: 'Get instant insights on your portfolio & markets',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatWidget(
                  generativeService: ctx.generativeService,
                  user: ctx.appUser,
                ),
              ),
            ),
          ),
          _entry(
            context,
            icon: Icons.psychology,
            title: 'AI Trading Coach',
            subtitle: 'Analyze habits, biases & get personalized coaching',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PersonalizedCoachingWidget(
                  service: ctx.service,
                  user: ctx.brokerageUser,
                  userDoc: ctx.userDocRef,
                  firebaseUser: ctx.appUser,
                  analytics: ctx.analytics,
                  observer: ctx.observer,
                  generativeService: ctx.generativeService,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entry(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return AnalyticsStyleCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon,
              size: 24, color: theme.colorScheme.onTertiaryContainer),
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
