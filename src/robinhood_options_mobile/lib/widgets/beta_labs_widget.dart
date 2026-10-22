import 'package:flutter/material.dart';
import '../enums.dart';
import '../model/user.dart';
import '../services/feature_access_service.dart';

class BetaLabsWidget extends StatefulWidget {
  final UserRole? userRole;
  final User? user;
  final dynamic userDocRef;
  final FeatureAccessService? featureAccessService;

  const BetaLabsWidget({
    super.key,
    this.userRole,
    this.user,
    this.userDocRef,
    this.featureAccessService,
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

  Future<void> _handleToggle(FeatureBundle bundle, bool newValue) async {
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
        return;
      }
    }

    await _service.setUserPreference(
      bundle,
      newValue,
      user: widget.user,
      userDocRef: widget.userDocRef,
    );
    if (mounted) setState(() {});
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
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isEnabled
                            ? theme.colorScheme.primary.withValues(alpha: 0.3)
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.4),
                      ),
                    ),
                    child: SwitchListTile.adaptive(
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
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
                        ],
                      ),
                      value: isEnabled,
                      onChanged: canToggle
                          ? (val) => _handleToggle(bundle, val)
                          : null,
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
