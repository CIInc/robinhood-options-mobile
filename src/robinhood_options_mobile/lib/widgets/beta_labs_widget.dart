import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import '../enums.dart';
import '../model/user.dart';
import '../services/feature_access_service.dart';
import '../services/firestore_service.dart';
import '../services/generative_service.dart';
import '../services/ibrokerage_service.dart';
import 'agentic_trading_settings_widget.dart';
import 'backtesting_widget.dart';
import 'copy_trading_dashboard_widget.dart';
import 'investor_groups_widget.dart';
import 'options_flow_widget.dart';
import 'risk_copilot_widget.dart';
import 'search_widget.dart';

class BetaLabsWidget extends StatefulWidget {
  final UserRole? userRole;
  final User? user;
  final dynamic userDocRef;
  final FeatureAccessService? featureAccessService;
  final IBrokerageService? service;

  const BetaLabsWidget({
    super.key,
    this.userRole,
    this.user,
    this.userDocRef,
    this.featureAccessService,
    this.service,
  });

  @override
  State<BetaLabsWidget> createState() => _BetaLabsWidgetState();
}

class _BetaLabsWidgetState extends State<BetaLabsWidget> {
  late final FeatureAccessService _service;

  static const Map<String, List<FeatureBundle>> _bundleCategories = {
    'Trading & Execution': [
      FeatureBundle.advancedTrading,
      FeatureBundle.automatedTrading,
      FeatureBundle.agenticTrading,
      FeatureBundle.backtesting,
    ],
    'Research & Intelligence': [
      FeatureBundle.advancedResearch,
      FeatureBundle.aiResearch,
      FeatureBundle.macroIntelligence,
    ],
    'Risk & Account Management': [
      FeatureBundle.riskGuardrails,
      FeatureBundle.accountTools,
    ],
    'Community & Social': [
      FeatureBundle.investorGroups,
      FeatureBundle.socialCopy,
    ],
    'Integrations': [
      FeatureBundle.extendedBrokerages,
    ],
  };

  @override
  void initState() {
    super.initState();
    _service = widget.featureAccessService ?? FeatureAccessService.instance;
  }

  IconData _iconForBundle(FeatureBundle bundle) => switch (bundle) {
        FeatureBundle.advancedResearch => Icons.analytics_outlined,
        FeatureBundle.aiResearch => Icons.auto_awesome,
        FeatureBundle.advancedTrading => Icons.layers_outlined,
        FeatureBundle.backtesting => Icons.history_edu,
        FeatureBundle.riskGuardrails => Icons.shield_outlined,
        FeatureBundle.socialCopy => Icons.share_outlined,
        FeatureBundle.investorGroups => Icons.groups_outlined,
        FeatureBundle.accountTools => Icons.account_balance_wallet_outlined,
        FeatureBundle.extendedBrokerages => Icons.hub_outlined,
        FeatureBundle.automatedTrading => Icons.auto_graph,
        FeatureBundle.agenticTrading => Icons.smart_toy_outlined,
        FeatureBundle.macroIntelligence => Icons.public_outlined,
      };

  String _locationForBundle(FeatureBundle bundle) => switch (bundle) {
        FeatureBundle.automatedTrading => 'Account > Automated Trading',
        FeatureBundle.agenticTrading =>
          'Account > Automated Trading > Strategy Style',
        FeatureBundle.riskGuardrails =>
          'Account > Automated Trading > Risk Management',
        FeatureBundle.backtesting => 'Account > Strategy Backtesting',
        FeatureBundle.advancedTrading =>
          'Instrument > Trade Options > Multi-Leg Spread Builder',
        FeatureBundle.advancedResearch => 'Research > Options Flow & GEX',
        FeatureBundle.aiResearch => 'Action Center > AI Copilot',
        FeatureBundle.macroIntelligence => 'Search > Macro Market State',
        FeatureBundle.accountTools => 'Account > Tax & Account Tools',
        FeatureBundle.investorGroups => 'Community > Investor Groups',
        FeatureBundle.socialCopy => 'Community > Social Sharing & Copy Trading',
        FeatureBundle.extendedBrokerages => 'Account > Linked Accounts',
      };

  List<String> _highlightsForBundle(FeatureBundle bundle) => switch (bundle) {
        FeatureBundle.automatedTrading => [
            'Systematic indicator criteria & automated order execution',
            'Continuous background monitoring & market crons',
            'Paper simulation mode & live execution guardrails',
          ],
        FeatureBundle.agenticTrading => [
            'AI-driven trading archetypes (Swing, Breakout, Theta, Volatility)',
            'Deep multi-factor market reasoning & real-time regime analysis',
            'Dynamic trade sizing & intelligent risk adaptation',
          ],
        FeatureBundle.riskGuardrails => [
            'Daily maximum loss limit & drawdown circuit breakers',
            'Consecutive loss detection with automatic cooling-off periods',
            'Behavioral tilt prevention for manual and automated orders',
          ],
        FeatureBundle.backtesting => [
            'Historical strategy simulation across SPY, QQQ, and single stocks',
            'Performance analytics: Sharpe ratio, win rate, max drawdown',
            'Direct one-tap promotion of winning backtests to live auto-trading',
          ],
        FeatureBundle.advancedTrading => [
            'Pre-configured templates: Iron Condors, Vertical Spreads, Straddles',
            'Visual profit/loss payoff diagrams with real-time breakevens',
            'Multi-broker routing with slippage protection',
          ],
        FeatureBundle.advancedResearch => [
            'Real-time institutional options flow & dark pool block trades',
            'Gamma exposure (GEX) levels & zero-gamma volatility flip points',
            'Aggressive ask/bid sweep detection and sentiment indicators',
          ],
        FeatureBundle.aiResearch => [
            'Interactive conversational AI market copilot powered by Gemini',
            'Contextual portfolio risk queries & options skew analysis',
            'Real-time macro catalyst and earnings impact summaries',
          ],
        FeatureBundle.macroIntelligence => [
            'Economic cycle phases: Expansion, Late-Cycle, Recession Watch',
            'Inflation YoY & Yield Curve radar (+18 bps, +2 bps, -24 bps)',
            'Quantitative risk-regime scoring (Risk-On, Neutral, Risk-Off)',
          ],
        FeatureBundle.accountTools => [
            'Year-round automated tax-loss harvesting scanning',
            'Cross-broker wash-sale detection & warning badges',
            'Form 8949 reporting export and capital gains optimization',
          ],
        FeatureBundle.investorGroups => [
            'Collaborative watchlists & private investor communities',
            'Shared portfolio tracking and community trading ideas',
            'Real-time group discussions and member sentiment analytics',
          ],
        FeatureBundle.socialCopy => [
            'Discover verified top-performing algorithmic strategies',
            'One-click automated copy trading allocation',
            'Copy Trade Risk Guardian limits and max slippage controls',
          ],
        FeatureBundle.extendedBrokerages => [
            'Multi-broker portfolio aggregation: Robinhood, Schwab, Fidelity',
            'Consolidated net worth, asset allocation, and unified positions',
            'Unified order routing and cross-account analytics',
          ],
      };

  Future<bool> _handleToggle(FeatureBundle bundle, bool newValue) async {
    if (newValue &&
        (bundle == FeatureBundle.advancedTrading ||
            bundle == FeatureBundle.automatedTrading ||
            bundle == FeatureBundle.agenticTrading)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Beta Feature Disclaimer'),
            ],
          ),
          content: Text(
            '${bundle.displayName} is experimental. '
            'Automated execution, strategy models, and trading algorithms are subject to model limitations, latency, and fill differences. '
            'Always test strategies with caution.\n\nDo you wish to enable this feature?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Enable Feature'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return false;
      }
    }

    await _service.setUserPreference(
      bundle,
      newValue,
      user: widget.user,
      userDocRef: widget.userDocRef,
    );
    if (mounted) setState(() {});
    return true;
  }

  void _showFeatureDemo(BuildContext context, FeatureBundle bundle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _BetaFeatureDemoSheet(
        bundle: bundle,
        userRole: widget.userRole,
        user: widget.user,
        userDocRef: widget.userDocRef,
        service: widget.service,
        featureAccessService: _service,
        locationPath: _locationForBundle(bundle),
        highlights: _highlightsForBundle(bundle),
        onNavigate: () {
          Navigator.of(sheetContext).pop();
          _navigateToFeature(context, bundle);
        },
        onToggle: (newValue) => _handleToggle(bundle, newValue),
      ),
    );
  }

  void _navigateToFeature(BuildContext context, FeatureBundle bundle) {
    final effectiveUser = widget.user ??
        User(devices: [], dateCreated: DateTime.now(), brokerageUsers: []);

    // Surface instant location feedback
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 Navigated to ${_locationForBundle(bundle)}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    switch (bundle) {
      case FeatureBundle.automatedTrading:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => AgenticTradingSettingsWidget(
              user: effectiveUser,
              userDocRef: widget.userDocRef,
              service: widget.service,
            ),
          ),
        );
        break;
      case FeatureBundle.agenticTrading:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => AgenticTradingSettingsWidget(
              user: effectiveUser,
              userDocRef: widget.userDocRef,
              service: widget.service,
              initialSection: 'entryStrategies',
            ),
          ),
        );
        break;
      case FeatureBundle.riskGuardrails:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => AgenticTradingSettingsWidget(
              user: effectiveUser,
              userDocRef: widget.userDocRef,
              service: widget.service,
              initialSection: 'riskManagement',
            ),
          ),
        );
        break;
      case FeatureBundle.backtesting:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => BacktestingWidget(
              user: widget.user,
              userDocRef: widget.userDocRef,
              service: widget.service,
            ),
          ),
        );
        break;
      case FeatureBundle.investorGroups:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => InvestorGroupsWidget(
              firestoreService: FirestoreService(),
              brokerageUser: null,
              service: widget.service,
              analytics: FirebaseAnalytics.instance,
              observer: FirebaseAnalyticsObserver(
                  analytics: FirebaseAnalytics.instance),
              user: widget.user,
              userDocRef: widget.userDocRef,
              initialTabIndex: 0,
            ),
          ),
        );
        break;
      case FeatureBundle.socialCopy:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => const CopyTradingDashboardWidget(),
          ),
        );
        break;
      case FeatureBundle.advancedResearch:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => OptionsFlowWidget(
              service: widget.service,
              user: widget.user,
              userDocRef: widget.userDocRef,
            ),
          ),
        );
        break;
      case FeatureBundle.macroIntelligence:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => SearchWidget(
              null,
              widget.service,
              user: effectiveUser,
              userDocRef: widget.userDocRef,
              analytics: FirebaseAnalytics.instance,
              observer: FirebaseAnalyticsObserver(
                analytics: FirebaseAnalytics.instance,
              ),
              generativeService: GenerativeService(),
              embedded: false,
            ),
          ),
        );
        break;
      case FeatureBundle.aiResearch:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => RiskCopilotWidget(
              user: widget.user,
              service: widget.service,
            ),
          ),
        );
        break;
      case FeatureBundle.advancedTrading:
        _showNavigationGuideDialog(
          context,
          title: 'Multi-Leg Option Spreads',
          location: 'Instrument > Trade Options > Spread Builder',
          description:
              'Multi-leg spreads (Verticals, Straddles, Iron Condors) are built directly within any option chain.\n\nOpen any equity or ETF (such as SPY or AAPL), tap "Trade Options", and select "Spread Builder" from the order pad.',
          primaryActionText: 'Explore Options Flow',
          onPrimaryAction: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => OptionsFlowWidget(
                  service: widget.service,
                  user: widget.user,
                  userDocRef: widget.userDocRef,
                ),
              ),
            );
          },
        );
        break;
      case FeatureBundle.accountTools:
        _showNavigationGuideDialog(
          context,
          title: 'Tax & Account Tools',
          location: 'Account > Investment Profile & Tax Lots',
          description:
              'Tax optimization, wash-sale detection, and capital gains tracking are integrated into your Account dashboard under Investment Profile.\n\nReturn to the Account tab to inspect your current tax-loss harvesting status.',
          primaryActionText: 'Got It',
          onPrimaryAction: () => Navigator.pop(context),
        );
        break;
      case FeatureBundle.extendedBrokerages:
        _showNavigationGuideDialog(
          context,
          title: 'Multi-Brokerage Integration',
          location: 'Account > Linked Accounts',
          description:
              'Connect Charles Schwab, Robinhood, or Fidelity accounts to consolidate balances and analytics across all your institutions.\n\nManage links directly in Account > Linked Brokerages.',
          primaryActionText: 'Got It',
          onPrimaryAction: () => Navigator.pop(context),
        );
        break;
    }
  }

  void _showNavigationGuideDialog(
    BuildContext context, {
    required String title,
    required String location,
    required String description,
    required String primaryActionText,
    required VoidCallback onPrimaryAction,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.place_outlined, color: Colors.blue),
            const SizedBox(width: 8),
            Flexible(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: onPrimaryAction,
            child: Text(primaryActionText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelfOptInAllowed = _service.isSelfOptInEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beta Labs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset Opt-Ins',
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              await _service.resetAllOptIns(
                user: widget.user,
                userDocRef: widget.userDocRef,
              );
              if (mounted) {
                setState(() {});
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                      content: Text('All beta opt-ins reset to default')),
                );
              }
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _service,
        builder: (context, _) {
          return ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            children: [
              Card(
                elevation: 0,
                color:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.science,
                          color: theme.colorScheme.primary, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Experimental Features',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Test upcoming features and tailor your experience. You can turn features on or off at any time.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                            if (widget.user != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.cloud_done_outlined,
                                      size: 14,
                                      color:
                                          theme.colorScheme.onPrimaryContainer),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Synced with account (${widget.user?.email ?? widget.user?.phoneNumber ?? widget.user?.name ?? 'active user'})',
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: theme
                                            .colorScheme.onPrimaryContainer,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!isSelfOptInAllowed) ...[
                Card(
                  color:
                      theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline,
                            color: theme.colorScheme.error),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Self-serve beta opt-in is currently paused by administrator.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              for (final entry in _bundleCategories.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
                ...entry.value.map((bundle) {
                  final mode = _service.getRolloutMode(bundle);
                  final isEnabled = _service.isFeatureEnabled(
                    bundle,
                    userRole: widget.userRole,
                    user: widget.user,
                  );

                  String statusLabel;
                  Color statusColor;
                  bool canToggle;

                  switch (mode) {
                    case FeatureRolloutMode.public:
                      statusLabel = isEnabled ? 'Public' : 'Public (Opted Out)';
                      statusColor = isEnabled ? Colors.green : Colors.grey;
                      canToggle = true;
                      break;
                    case FeatureRolloutMode.disabled:
                      statusLabel = 'Disabled';
                      statusColor = theme.colorScheme.error;
                      canToggle = false;
                      break;
                    case FeatureRolloutMode.adminOnly:
                      statusLabel = 'Admin Only';
                      statusColor = Colors.orange;
                      canToggle = widget.userRole == UserRole.admin;
                      break;
                    case FeatureRolloutMode.betaOptIn:
                      statusLabel = 'Beta';
                      statusColor = theme.colorScheme.primary;
                      canToggle = isSelfOptInAllowed ||
                          widget.userRole == UserRole.admin;
                      break;
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isEnabled
                            ? theme.colorScheme.primary.withValues(alpha: 0.3)
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 2.0),
                          secondary: CircleAvatar(
                            backgroundColor: isEnabled
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            foregroundColor: isEnabled
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurfaceVariant,
                            child: Icon(_iconForBundle(bundle)),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  bundle.displayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                bundle.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (mode == FeatureRolloutMode.disabled) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Temporarily disabled by remote configuration',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ] else if (mode == FeatureRolloutMode.public) ...[
                                const SizedBox(height: 2),
                                Text(
                                  isEnabled
                                      ? 'Active by default. Toggle off to hide this feature.'
                                      : 'Opted out by user preference. Toggle on to re-enable.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isEnabled
                                        ? theme.colorScheme.outline
                                        : theme.colorScheme.error,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              // Location indicator badge (tappable to view demo)
                              InkWell(
                                onTap: () => _showFeatureDemo(context, bundle),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.place_outlined,
                                        size: 13,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          _locationForBundle(bundle),
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 11,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          value: isEnabled,
                          onChanged: canToggle
                              ? (val) => _handleToggle(bundle, val)
                              : null,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                key: ValueKey('demo_${bundle.name}'),
                                icon: const Icon(Icons.play_circle_outline,
                                    size: 16),
                                label: const Text('Demo',
                                    overflow: TextOverflow.ellipsis),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                ),
                                onPressed: () =>
                                    _showFeatureDemo(context, bundle),
                              ),
                              if (isEnabled)
                                FilledButton.tonalIcon(
                                  key: ValueKey('open_${bundle.name}'),
                                  icon:
                                      const Icon(Icons.arrow_forward, size: 16),
                                  label: const Text('Open Feature',
                                      overflow: TextOverflow.ellipsis),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                  ),
                                  onPressed: () =>
                                      _navigateToFeature(context, bundle),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

/// Modal Bottom Sheet showcasing an interactive preview, highlights, and direct activation of a feature.
class _BetaFeatureDemoSheet extends StatefulWidget {
  final FeatureBundle bundle;
  final UserRole? userRole;
  final User? user;
  final dynamic userDocRef;
  final IBrokerageService? service;
  final FeatureAccessService featureAccessService;
  final String locationPath;
  final List<String> highlights;
  final VoidCallback onNavigate;
  final Future<bool> Function(bool newValue) onToggle;

  const _BetaFeatureDemoSheet({
    required this.bundle,
    required this.userRole,
    required this.user,
    required this.userDocRef,
    required this.service,
    required this.featureAccessService,
    required this.locationPath,
    required this.highlights,
    required this.onNavigate,
    required this.onToggle,
  });

  @override
  State<_BetaFeatureDemoSheet> createState() => _BetaFeatureDemoSheetState();
}

class _BetaFeatureDemoSheetState extends State<_BetaFeatureDemoSheet> {
  bool _isToggling = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: widget.featureAccessService,
      builder: (context, _) {
        final isEnabled = widget.featureAccessService.isFeatureEnabled(
          widget.bundle,
          userRole: widget.userRole,
          user: widget.user,
        );
        final mode = widget.featureAccessService.getRolloutMode(widget.bundle);
        final canToggle = mode != FeatureRolloutMode.disabled &&
            (mode != FeatureRolloutMode.adminOnly ||
                widget.userRole == UserRole.admin);

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Scrollable body
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    // Header row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: isEnabled
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          foregroundColor: isEnabled
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                          child: Icon(
                            _iconForBundle(widget.bundle),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.bundle.displayName,
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isEnabled
                                              ? theme.colorScheme.primary
                                              : Colors.grey)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isEnabled ? 'Active' : 'Disabled',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isEnabled
                                            ? theme.colorScheme.primary
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.bundle.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Location breadcrumb banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Located in: ${widget.locationPath}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Section 1: Interactive Preview Simulator
                    Row(
                      children: [
                        Icon(Icons.touch_app_outlined,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'INTERACTIVE PREVIEW',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _FeatureDemoSimulator(bundle: widget.bundle),
                    const SizedBox(height: 20),
                    // Section 2: Key Capabilities
                    Row(
                      children: [
                        Icon(Icons.checklist,
                            size: 16, color: theme.colorScheme.secondary),
                        const SizedBox(width: 6),
                        Text(
                          'KEY CAPABILITIES',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...widget.highlights.map(
                      (hl) => Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hl,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Bottom Actions: Enable & Open
                    Row(
                      children: [
                        if (canToggle)
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: _isToggling
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Icon(
                                      isEnabled
                                          ? Icons.power_settings_new
                                          : Icons.check,
                                      size: 18,
                                    ),
                              label: Text(
                                  isEnabled ? 'Opt Out' : 'Enable Feature'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _isToggling
                                  ? null
                                  : () async {
                                      setState(() => _isToggling = true);
                                      await widget.onToggle(!isEnabled);
                                      if (mounted) {
                                        setState(() => _isToggling = false);
                                      }
                                    },
                            ),
                          ),
                        if (isEnabled) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.arrow_forward, size: 18),
                              label: const Text('Open Feature'),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: widget.onNavigate,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _iconForBundle(FeatureBundle bundle) => switch (bundle) {
        FeatureBundle.advancedResearch => Icons.analytics_outlined,
        FeatureBundle.aiResearch => Icons.auto_awesome,
        FeatureBundle.advancedTrading => Icons.layers_outlined,
        FeatureBundle.backtesting => Icons.history_edu,
        FeatureBundle.riskGuardrails => Icons.shield_outlined,
        FeatureBundle.socialCopy => Icons.share_outlined,
        FeatureBundle.investorGroups => Icons.groups_outlined,
        FeatureBundle.accountTools => Icons.account_balance_wallet_outlined,
        FeatureBundle.extendedBrokerages => Icons.hub_outlined,
        FeatureBundle.automatedTrading => Icons.auto_graph,
        FeatureBundle.agenticTrading => Icons.smart_toy_outlined,
        FeatureBundle.macroIntelligence => Icons.public_outlined,
      };
}

/// Interactive simulator widget rendering custom simulated environments for all 12 feature bundles.
class _FeatureDemoSimulator extends StatefulWidget {
  final FeatureBundle bundle;

  const _FeatureDemoSimulator({required this.bundle});

  @override
  State<_FeatureDemoSimulator> createState() => _FeatureDemoSimulatorState();
}

class _FeatureDemoSimulatorState extends State<_FeatureDemoSimulator> {
  // Local state for interactive simulators
  int _selectedTabIndex = 0;
  bool _opt1 = true;
  bool _opt2 = true;
  bool _opt3 = false;
  bool _paperMode = true;
  double _sliderValue = 1500;
  String _selectedTicker = 'SPY';
  int _flowFilterIndex = 0;
  int _aiPromptIndex = 0;
  int _macroRegimeIndex = 0;
  int _accountTab = 0;
  bool _investorVotedBullish = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: switch (widget.bundle) {
        FeatureBundle.automatedTrading =>
          _buildAutomatedTradingSimulator(theme),
        FeatureBundle.agenticTrading => _buildAgenticTradingSimulator(theme),
        FeatureBundle.riskGuardrails => _buildRiskGuardrailsSimulator(theme),
        FeatureBundle.backtesting => _buildBacktestingSimulator(theme),
        FeatureBundle.advancedTrading => _buildAdvancedTradingSimulator(theme),
        FeatureBundle.advancedResearch =>
          _buildAdvancedResearchSimulator(theme),
        FeatureBundle.aiResearch => _buildAiResearchSimulator(theme),
        FeatureBundle.macroIntelligence => _buildMacroSimulator(theme),
        FeatureBundle.accountTools => _buildAccountToolsSimulator(theme),
        FeatureBundle.investorGroups => _buildInvestorGroupsSimulator(theme),
        FeatureBundle.socialCopy => _buildSocialCopySimulator(theme),
        FeatureBundle.extendedBrokerages =>
          _buildExtendedBrokeragesSimulator(theme),
      },
    );
  }

  // 1. Automated Trading Simulator
  Widget _buildAutomatedTradingSimulator(ThemeData theme) {
    final activeCount = (_opt1 ? 1 : 0) + (_opt2 ? 1 : 0) + (_opt3 ? 1 : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'Entry Criteria (Tap to toggle):',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => setState(() => _paperMode = !_paperMode),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (_paperMode ? Colors.blue : Colors.green)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _paperMode ? 'PAPER MODE' : 'LIVE MODE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _paperMode ? Colors.blue : Colors.green,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            FilterChip(
              label: const Text('RSI < 30 (Oversold)'),
              selected: _opt1,
              onSelected: (val) => setState(() => _opt1 = val),
            ),
            FilterChip(
              label: const Text('MACD Bullish Cross'),
              selected: _opt2,
              onSelected: (val) => setState(() => _opt2 = val),
            ),
            FilterChip(
              label: const Text('EMA 20/50 Golden Cross'),
              selected: _opt3,
              onSelected: (val) => setState(() => _opt3 = val),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: activeCount >= 2
                ? Colors.green.withValues(alpha: 0.12)
                : Colors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                activeCount >= 2
                    ? Icons.check_circle_outline
                    : Icons.hourglass_top,
                color: activeCount >= 2 ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  activeCount >= 2
                      ? 'Signal Triggered: BUY 10 SPY \$590 Call • ${_paperMode ? 'Paper Simulated Fill' : 'Live Order Routing'}'
                      : 'Waiting for criteria ($activeCount/2 required indicators met)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: activeCount >= 2 ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 2. Agentic Trading Simulator
  Widget _buildAgenticTradingSimulator(ThemeData theme) {
    final archetypes = [
      (
        'Balanced Swing',
        'Multi-day momentum + macro regime tailwinds',
        88,
        'Moderate'
      ),
      (
        'Breakout Hunter',
        'High volatility breakouts with ATR sizing',
        94,
        'Aggressive'
      ),
      (
        'Theta Yield',
        'High-probability delta-neutral income generation',
        82,
        'Conservative'
      ),
      (
        'Volatility Harvester',
        'Mean-reversion on extreme IV spikes',
        78,
        'Tactical'
      ),
    ];
    final selected = archetypes[_selectedTabIndex % archetypes.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select AI Strategy Archetype:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(archetypes.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: ChoiceChip(
                  label: Text(archetypes[i].$1),
                  selected: _selectedTabIndex == i,
                  onSelected: (val) {
                    if (val) setState(() => _selectedTabIndex = i);
                  },
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'AI Reasoning Confidence: ${selected.$3}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      selected.$4,
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                selected.$2,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 3. Risk Guardrails Simulator
  Widget _buildRiskGuardrailsSimulator(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text('Daily Max Loss Ceiling:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Text('\$${_sliderValue.toInt()}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.red)),
          ],
        ),
        Slider(
          value: _sliderValue,
          min: 500,
          max: 5000,
          divisions: 9,
          onChanged: (val) => setState(() => _sliderValue = val),
        ),
        Row(
          children: [
            const Icon(Icons.shield, size: 16, color: Colors.green),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Tilt Protection: Trading halts automatically if drawdown reaches \$${_sliderValue.toInt()} or 3 consecutive losses occur within 24h.',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 4. Backtesting Simulator
  Widget _buildBacktestingSimulator(ThemeData theme) {
    final tickers = ['SPY', 'QQQ', 'NVDA', 'AAPL'];
    final tickerMetrics = {
      'SPY': {
        'winRate': '68.4%',
        'sharpe': '1.84',
        'maxDd': '-6.2%',
        'alpha': '+14.8%'
      },
      'QQQ': {
        'winRate': '71.2%',
        'sharpe': '2.05',
        'maxDd': '-8.1%',
        'alpha': '+22.4%'
      },
      'NVDA': {
        'winRate': '64.0%',
        'sharpe': '2.31',
        'maxDd': '-12.5%',
        'alpha': '+38.6%'
      },
      'AAPL': {
        'winRate': '66.5%',
        'sharpe': '1.62',
        'maxDd': '-5.4%',
        'alpha': '+11.2%'
      },
    };
    final metrics = tickerMetrics[_selectedTicker] ?? tickerMetrics['SPY']!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text('Asset: ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ...tickers.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(t),
                    selected: _selectedTicker == t,
                    onSelected: (val) {
                      if (val) setState(() => _selectedTicker = t);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child:
                    _metricPill('Win Rate', metrics['winRate']!, Colors.green),
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _metricPill(
                    'Sharpe', metrics['sharpe']!, theme.colorScheme.primary),
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _metricPill('Max DD', metrics['maxDd']!, Colors.orange),
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _metricPill('Alpha', metrics['alpha']!, Colors.green),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 5. Advanced Trading (Option Spreads) Simulator
  Widget _buildAdvancedTradingSimulator(ThemeData theme) {
    final spreads = [
      ('Iron Condor', r'+$340', r'-$160', r'$588 / $598', r'Net Credit $3.40'),
      ('Bull Call Spread', r'+$450', r'-$250', r'$592.50', r'Net Debit $2.50'),
      (
        'Long Straddle',
        'Unlimited',
        r'-$480',
        r'$585 / $595',
        'Long Volatility'
      ),
    ];
    final selected = spreads[_selectedTabIndex % spreads.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(spreads.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: ChoiceChip(
                  label: Text(spreads[i].$1),
                  selected: _selectedTabIndex == i,
                  onSelected: (val) {
                    if (val) setState(() => _selectedTabIndex = i);
                  },
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _metricPill('Max Profit', selected.$2, Colors.green),
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _metricPill('Max Loss', selected.$3, Colors.red),
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _metricPill(
                    'Breakeven', selected.$4, theme.colorScheme.primary),
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _metricPill('Payoff Type', selected.$5, Colors.blueGrey),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 6. Advanced Research (Options Flow & GEX)
  Widget _buildAdvancedResearchSimulator(ThemeData theme) {
    final filters = ['All Flow', 'Sweeps', 'Blocks'];
    final tapeItems = [
      (
        'SPY \$595C 12/20 • \$1.4M Institutional Sweep (Ask)',
        Colors.green,
        Icons.bolt
      ),
      (
        'NVDA \$140P 11/29 • \$820K Dark Pool Block (Bid)',
        Colors.red,
        Icons.layers
      ),
      (
        'AAPL \$230C 01/17 • \$450K Golden Sweep (Ask)',
        Colors.green,
        Icons.bolt
      ),
    ];
    final visibleItems = _flowFilterIndex == 1
        ? [tapeItems[0], tapeItems[2]]
        : _flowFilterIndex == 2
            ? [tapeItems[1]]
            : tapeItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(filters.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: ChoiceChip(
                  label: Text(filters[i]),
                  selected: _flowFilterIndex == i,
                  onSelected: (val) {
                    if (val) setState(() => _flowFilterIndex = i);
                  },
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        ...visibleItems.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: item.$2.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(item.$3, color: item.$2, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.$1,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: item.$2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            children: [
              Icon(Icons.show_chart, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Zero-Gamma Pivot Level: \$587.25 (Key Volatility Flip)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 7. AI Copilot Simulator
  Widget _buildAiResearchSimulator(ThemeData theme) {
    final prompts = [
      'NVDA options skew',
      'Tech sector volatility',
      'FOMC minutes catalyst',
    ];
    final responses = [
      'Gemini Copilot: Implied volatility is elevated at 64%. Call skew reflects heavy upside positioning with dealer negative gamma below \$140.',
      'Gemini Copilot: Tech volatility is driven by the 10-year Treasury yield rising 7 bps and semi capex guidance. Major support sits at QQQ \$502.',
      'Gemini Copilot: FOMC minutes indicate a patient easing stance. Fed funds futures price an 82% probability of a 25 bps cut at the next meeting.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tap a Sample Prompt:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(prompts.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: ChoiceChip(
                  label: Text(prompts[i]),
                  selected: _aiPromptIndex == i,
                  onSelected: (val) {
                    if (val) setState(() => _aiPromptIndex = i);
                  },
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome,
                      size: 15, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '"${prompts[_aiPromptIndex]}"',
                      style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const Divider(height: 12),
              Text(
                responses[_aiPromptIndex],
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 8. Macro Intelligence Simulator
  Widget _buildMacroSimulator(ThemeData theme) {
    final phases = ['Expansion', 'Late-Cycle', 'Recession Watch'];
    final phaseData = [
      {
        'phase': 'Expansion',
        'regime': 'Risk-On (Bullish)',
        'score': '78/100',
        'inflation': '2.4%',
        'yieldCurve': '+18 bps',
        'allocation': 'Equities 70% • Fixed Income 20% • Cash 10%',
        'color': Colors.green,
      },
      {
        'phase': 'Late-Cycle',
        'regime': 'Neutral (Mixed)',
        'score': '52/100',
        'inflation': '3.1%',
        'yieldCurve': '+2 bps',
        'allocation': 'Equities 50% • Fixed Income 30% • Cash 20%',
        'color': Colors.orange,
      },
      {
        'phase': 'Recession Watch',
        'regime': 'Risk-Off (Defensive)',
        'score': '24/100',
        'inflation': '1.8%',
        'yieldCurve': '-24 bps',
        'allocation': 'Equities 25% • Fixed Income 35% • Cash 40%',
        'color': Colors.red,
      },
    ];
    final selected = phaseData[_macroRegimeIndex % phaseData.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'Economic Cycle Phase:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (selected['color'] as Color).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${selected['regime']} • ${selected['score']}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: selected['color'] as Color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(phases.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: ChoiceChip(
                  label: Text(phases[i]),
                  selected: _macroRegimeIndex == i,
                  onSelected: (val) {
                    if (val) setState(() => _macroRegimeIndex = i);
                  },
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _metricPill('Economic Cycle',
                    selected['phase'] as String, selected['color'] as Color),
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _metricPill('Inflation YoY',
                    selected['inflation'] as String, theme.colorScheme.primary),
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _metricPill('Yield Curve',
                    selected['yieldCurve'] as String, Colors.blue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (selected['color'] as Color).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: (selected['color'] as Color).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.pie_chart_outline,
                  size: 15, color: selected['color'] as Color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Suggested Allocation: ${selected['allocation']}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 9. Account Tools Simulator
  Widget _buildAccountToolsSimulator(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Tax-Loss Harvesting'),
                selected: _accountTab == 0,
                onSelected: (val) {
                  if (val) setState(() => _accountTab = 0);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Wash Sale Shield'),
                selected: _accountTab == 1,
                onSelected: (val) {
                  if (val) setState(() => _accountTab = 1);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_accountTab == 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _metricPill(
                      'Harvestable Losses', r'$1,850', Colors.green),
                ),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child:
                      _metricPill('Eligible Lots', '3 Positions', Colors.blue),
                ),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _metricPill('Tax Savings Est.', r'$590', Colors.green),
                ),
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _metricPill('Wash Sales', '0 Detected', Colors.green),
                ),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _metricPill('30-Day Window', 'Compliant', Colors.blue),
                ),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _metricPill('Audit Status', 'Protected', Colors.green),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // 10. Investor Groups Simulator
  Widget _buildInvestorGroupsSimulator(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.groups, size: 16),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('Alpha Syndicate • 148 Members',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 4),
            TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () => setState(
                  () => _investorVotedBullish = !_investorVotedBullish),
              child: Text(
                  _investorVotedBullish
                      ? 'Vote: Bullish 🟢'
                      : 'Vote: Bearish 🔴',
                  style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Community Sentiment: ${_investorVotedBullish ? "82% Bullish" : "78% Bullish"} on Tech • Shared Idea: SPY Dec 590/600 Call Spread (14 Copy Trades)',
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }

  // 11. Social Copy Simulator
  Widget _buildSocialCopySimulator(ThemeData theme) {
    final expectedReturn = (_sliderValue * 0.442).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.verified, size: 16, color: Colors.blue),
            SizedBox(width: 6),
            Expanded(
              child: Text('@DeltaQuant • Verified +44.2% YTD',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text('Copy Allocation: \$${_sliderValue.toInt()}',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Text('Est. Return: +\$$expectedReturn/yr',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green)),
          ],
        ),
        Slider(
          value: _sliderValue,
          min: 500,
          max: 5000,
          divisions: 9,
          onChanged: (val) => setState(() => _sliderValue = val),
        ),
      ],
    );
  }

  // 12. Extended Brokerages Simulator
  Widget _buildExtendedBrokeragesSimulator(ThemeData theme) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Consolidated Multi-Broker Portfolio:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Robinhood: \$48K', style: TextStyle(fontSize: 11)),
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Schwab: \$84K', style: TextStyle(fontSize: 11)),
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Fidelity: \$33K', style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
        Divider(height: 12),
        Center(
          child: Text(
            'Total Unified Net Worth: \$165,000',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _metricPill(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}
