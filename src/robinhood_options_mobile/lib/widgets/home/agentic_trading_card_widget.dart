import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/backtesting_widget.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';

class AgenticTradingCardWidget extends StatelessWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final FirebaseAnalytics? analytics;

  const AgenticTradingCardWidget({
    super.key,
    this.user,
    this.userDocRef,
    this.brokerageUser,
    this.service,
    this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<AgenticTradingProvider>(
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
                    ? Colors.blue.withValues(alpha: 0.5)
                    : colorScheme.outlineVariant,
                width: isEnabled ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: (user == null || userDocRef == null)
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AgenticTradingSettingsWidget(
                                user: user!,
                                userDocRef: userDocRef!,
                                service: service!,
                              ),
                            ),
                          );
                        },
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
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
                                color: (isEnabled ? Colors.blue : Colors.grey)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.auto_graph,
                                color: isEnabled ? Colors.blue : Colors.grey,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Stocks Agentic Trading', //Agentic Trading
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
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
                                          ? (isPaper
                                              ? Colors.blue
                                              : Colors.green)
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
                                                AgenticTradingSettingsWidget(
                                              user: user!,
                                              userDocRef: userDocRef!,
                                              service: service!,
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
                              'Symbols',
                              config.strategyConfig.symbolFilter.length
                                  .toString(),
                              Icons.list,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                InkWell(
                  onTap: (user == null || userDocRef == null)
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BacktestingWidget(
                                user: user,
                                userDocRef: userDocRef,
                                brokerageUser: brokerageUser,
                                service: service,
                              ),
                            ),
                          );
                        },
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history,
                                size: 18, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Strategy Backtesting',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Icon(Icons.chevron_right,
                            size: 18, color: colorScheme.primary),
                      ],
                    ),
                  ),
                ),
              ],
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
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors, size: 14, color: Colors.blue),
            SizedBox(width: 4),
            Text(
              'LIVE',
              style: TextStyle(
                color: Colors.blue,
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
