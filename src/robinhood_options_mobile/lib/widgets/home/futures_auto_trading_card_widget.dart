import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/futures_auto_trading_provider.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/futures_trading_settings_widget.dart';

class FuturesAutoTradingCardWidget extends StatelessWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;
  final IBrokerageService? service;
  final FirebaseAnalytics? analytics;

  const FuturesAutoTradingCardWidget({
    super.key,
    this.user,
    this.userDocRef,
    this.service,
    this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<FuturesAutoTradingProvider>(
      builder: (context, provider, child) {
        final config = provider.config;
        final isEnabled = config.autoTradeEnabled;
        final isPaper = config.paperTradingMode;

        final history = provider.autoTradeHistory;
        final today = DateTime.now();
        final todayHistory = history.where((t) {
          final timestamp = t['timestamp'];
          if (timestamp == null) return false;
          final date = timestamp is Timestamp
              ? timestamp.toDate()
              : DateTime.parse(timestamp.toString());
          return date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;
        }).toList();

        double totalPnl = 0;
        for (var trade in history) {
          totalPnl += (trade['pnl'] ?? 0).toDouble();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isEnabled
                    ? Colors.green.withValues(alpha: 0.5)
                    : colorScheme.outlineVariant,
                width: isEnabled ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              onTap: (user == null || userDocRef == null)
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FuturesTradingSettingsWidget(
                            user: user!,
                            userDocRef: userDocRef!,
                            service: service,
                          ),
                        ),
                      );
                    },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (isEnabled ? Colors.green : Colors.orange)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEnabled ? Icons.sensors : Icons.sensors_off,
                            color: isEnabled ? Colors.green : Colors.orange,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Futures Auto-Trading',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isEnabled
                                    ? (isPaper
                                        ? 'Live Paper Trading'
                                        : 'Live Real Trading')
                                    : 'Inactive',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isEnabled
                                      ? (isPaper ? Colors.blue : Colors.green)
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (provider.isAutoTrading)
                          const _AutoTradingIndicator()
                        else
                          IconButton(
                            icon: const Icon(Icons.settings_outlined),
                            onPressed: (user == null || userDocRef == null)
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            FuturesTradingSettingsWidget(
                                          user: user!,
                                          userDocRef: userDocRef!,
                                          service: service,
                                        ),
                                      ),
                                    );
                                  },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStat(
                          context,
                          'Trades Today',
                          todayHistory.length.toString(),
                          Icons.swap_horiz,
                        ),
                        _buildStat(
                          context,
                          'Total P&L',
                          '\$${totalPnl.toStringAsFixed(2)}',
                          Icons.insights,
                          color: totalPnl >= 0 ? Colors.green : Colors.red,
                        ),
                        _buildStat(
                          context,
                          'Contracts',
                          config.strategyConfig.contractIds.length.toString(),
                          Icons.layers,
                        ),
                      ],
                    ),
                    if (provider.activityLog.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          provider.activityLog.first,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(
      BuildContext context, String label, String value, IconData icon,
      {Color? color}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AutoTradingIndicator extends StatefulWidget {
  const _AutoTradingIndicator();

  @override
  State<_AutoTradingIndicator> createState() => _AutoTradingIndicatorState();
}

class _AutoTradingIndicatorState extends State<_AutoTradingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors, size: 14, color: Colors.green),
            SizedBox(width: 4),
            Text(
              'LIVE',
              style: TextStyle(
                color: Colors.green,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
