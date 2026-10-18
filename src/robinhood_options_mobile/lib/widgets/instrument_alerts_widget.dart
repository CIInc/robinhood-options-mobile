import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:robinhood_options_mobile/model/custom_alert.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/custom_alert_service.dart';
import 'package:robinhood_options_mobile/widgets/custom_alerts_widget.dart';

class InstrumentAlertsWidget extends StatefulWidget {
  final Instrument instrument;
  final String? userId;
  final CustomAlertService? customAlertService;
  final VoidCallback? onManageAlerts;

  const InstrumentAlertsWidget({
    super.key,
    required this.instrument,
    this.userId,
    this.customAlertService,
    this.onManageAlerts,
  });

  @override
  State<InstrumentAlertsWidget> createState() => _InstrumentAlertsWidgetState();
}

class _InstrumentAlertsWidgetState extends State<InstrumentAlertsWidget> {
  late final CustomAlertService _service;

  String? get _currentUserId {
    if (widget.userId != null) return widget.userId;
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _service = widget.customAlertService ?? CustomAlertService();
  }

  void _manageAlerts() {
    if (widget.onManageAlerts != null) {
      widget.onManageAlerts!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CustomAlertsWidget(
            initialSymbol: widget.instrument.symbol,
          ),
        ),
      );
    }
  }

  Future<void> _createAlert() async {
    final result = await CustomAlertsWidget.showAlertEditor(
      context,
      initialSymbol: widget.instrument.symbol,
      userId: _currentUserId,
    );

    if (result != null && mounted) {
      await _service.createAlert(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert created')),
        );
      }
    }
  }

  Future<void> _editAlert(CustomAlert alert) async {
    final result = await CustomAlertsWidget.showAlertEditor(
      context,
      alert: alert,
      initialSymbol: widget.instrument.symbol,
      userId: _currentUserId,
    );

    if (result != null && mounted) {
      await _service.updateAlert(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert updated')),
        );
      }
    }
  }

  String _formatAlertValue(CustomAlert alert) {
    final currencyFormatter = NumberFormat.simpleCurrency();
    final numberFormatter = NumberFormat.decimalPattern();

    if (alert.rules.length > 1) {
      return '${alert.rules.length} rules (${alert.logic == AlertLogic.all ? "ALL" : "ANY"})';
    } else if (alert.type == AlertType.price) {
      return currencyFormatter.format(alert.value);
    } else if (alert.type == AlertType.moving_average) {
      return 'SMA(${alert.period}): ${currencyFormatter.format(alert.value)}';
    } else if (alert.type == AlertType.rsi) {
      return 'RSI(${alert.period}): ${numberFormatter.format(alert.value)}';
    } else if (alert.type == AlertType.gex) {
      return (alert.condition == AlertCondition.above ||
              alert.condition == AlertCondition.below)
          ? '\$${alert.value}M GEX'
          : alert.condition.name.replaceAll('_', ' ').toUpperCase();
    } else if (alert.type == AlertType.dynamic_threshold) {
      return '${alert.value}x ATR';
    } else {
      return numberFormatter.format(alert.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetSymbol = widget.instrument.symbol.toUpperCase();

    return StreamBuilder<List<CustomAlert>>(
      stream: _service.getAlerts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error loading alerts: ${snapshot.error}'),
            ),
          );
        }

        final allAlerts = snapshot.data ?? [];
        final symbolAlerts = allAlerts
            .where((a) => a.symbol.toUpperCase() == targetSymbol)
            .toList();
        final activeCount = symbolAlerts.where((a) => a.active).length;

        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.add_alert_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Custom Alerts',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (symbolAlerts.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: activeCount > 0
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          activeCount > 0
                              ? '$activeCount active'
                              : '${symbolAlerts.length} set',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: activeCount > 0
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      tooltip: 'Add Alert',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _createAlert,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 14),
                      tooltip: 'Manage Alerts',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _manageAlerts,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!snapshot.hasData &&
                    snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (symbolAlerts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14.0, horizontal: 12.0),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 20,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No alerts configured for ${widget.instrument.symbol}.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _createAlert,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Set Alert'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4.0),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Display up to 3 alerts directly
                  ...symbolAlerts.take(3).map((alert) {
                    final isMultiRule = alert.rules.length > 1;
                    final valueText = _formatAlertValue(alert);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _editAlert(alert),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: CustomAlertsWidget.buildIcon(alert.type),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        style:
                                            DefaultTextStyle.of(context).style,
                                        children: [
                                          if (!isMultiRule)
                                            TextSpan(
                                              text:
                                                  '${alert.condition.name.replaceAll('_', ' ').toUpperCase()} ',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color:
                                                    theme.colorScheme.secondary,
                                              ),
                                            ),
                                          TextSpan(
                                            text: valueText,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      alert.lastTriggered != null
                                          ? 'Triggered ${DateFormat.yMMMd().add_jm().format(alert.lastTriggered!)}'
                                          : 'Never triggered',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Transform.scale(
                                scale: 0.8,
                                child: Switch(
                                  value: alert.active,
                                  onChanged: (val) {
                                    _service.updateAlert(CustomAlert(
                                      id: alert.id,
                                      userId: alert.userId,
                                      symbol: alert.symbol,
                                      type: alert.type,
                                      condition: alert.condition,
                                      value: alert.value,
                                      period: alert.period,
                                      logic: alert.logic,
                                      rules: alert.rules,
                                      active: val,
                                      lastTriggered: alert.lastTriggered,
                                      createdAt: alert.createdAt,
                                      deviceToken: alert.deviceToken,
                                    ));
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (symbolAlerts.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: InkWell(
                        onTap: _manageAlerts,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4.0, horizontal: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'View all ${symbolAlerts.length} alerts for ${widget.instrument.symbol}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
