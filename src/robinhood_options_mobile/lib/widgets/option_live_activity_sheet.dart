import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/live_activity_models.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/services/live_activity_service.dart';

/// Modal bottom sheet for configuring and starting/updating iOS Live Activity
/// and Dynamic Island real-time tracking for an option position.
class OptionLiveActivitySheet extends StatefulWidget {
  final OptionAggregatePosition position;
  final LiveActivityService? liveActivityService;
  final VoidCallback? onSessionChanged;

  const OptionLiveActivitySheet({
    super.key,
    required this.position,
    this.liveActivityService,
    this.onSessionChanged,
  });

  @override
  State<OptionLiveActivitySheet> createState() => _OptionLiveActivitySheetState();
}

class _OptionLiveActivitySheetState extends State<OptionLiveActivitySheet> {
  late LiveActivityService _service;
  late double _trailingStopPercent;
  bool _isLoading = false;

  final List<double> _presetPercentages = [5.0, 10.0, 15.0, 20.0, 25.0];

  @override
  void initState() {
    super.initState();
    _service = widget.liveActivityService ?? LiveActivityService.instance;
    final existingSession = _service.getSession(widget.position.id);
    _trailingStopPercent = existingSession?.trailingStopPercent ?? 10.0;
  }

  OptionLiveActivitySession? get _currentSession =>
      _service.getSession(widget.position.id);

  bool get _isTracking => _currentSession != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pos = widget.position;

    final expDate = pos.optionInstrument?.expirationDate;
    final isZeroDte = OptionLiveActivitySession.calculateIs0DTE(expDate);
    final daysToExpiry = OptionLiveActivitySession.calculateDTE(expDate);

    final markPrice =
        pos.optionInstrument?.optionMarketData?.adjustedMarkPrice ??
            (pos.averageOpenPrice != null ? pos.averageOpenPrice! / 100.0 : 0.0);

    final isDebit = pos.direction.toLowerCase() != 'credit';
    final peak = _currentSession?.peakPrice ?? markPrice;
    final stopPrice = isDebit
        ? peak * (1.0 - (_trailingStopPercent / 100.0))
        : peak * (1.0 + (_trailingStopPercent / 100.0));

    final strike = pos.optionInstrument?.strikePrice ??
        (pos.legs.isNotEmpty ? pos.legs.first.strikePrice ?? 0.0 : 0.0);
    final optType = pos.optionInstrument?.type ??
        (pos.legs.isNotEmpty ? pos.legs.first.optionType : 'call');

    final currencyFormat = NumberFormat.simpleCurrency();
    final percentFormat = NumberFormat.decimalPercentPattern(decimalDigits: 1);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isZeroDte
                        ? Colors.deepOrange.withValues(alpha: 0.15)
                        : colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sensors,
                    color: isZeroDte ? Colors.deepOrange : colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            pos.symbol,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isZeroDte)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '0DTE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${daysToExpiry}DTE',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${currencyFormat.format(strike)} ${optType.toUpperCase()} • ${pos.strategy.toUpperCase()}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // P&L readout
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(markPrice),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${pos.gainLoss >= 0 ? '+' : ''}${currencyFormat.format(pos.gainLoss)} (${percentFormat.format(pos.gainLossPercent)})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pos.gainLoss >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Dynamic Island Mock Preview Capsule
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isTracking
                      ? (_currentSession?.isTrailingStopTriggered ?? false
                          ? Colors.redAccent
                          : Colors.greenAccent.withValues(alpha: 0.6))
                      : Colors.white24,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isTracking
                          ? (_currentSession?.isTrailingStopTriggered ?? false
                              ? Colors.redAccent
                              : Colors.greenAccent)
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${pos.symbol} ${currencyFormat.format(strike)}${optType.substring(0, 1).toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (isZeroDte) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '0DTE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (_currentSession?.isTrailingStopTriggered ?? false) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'STOPPED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      '${pos.gainLossPercent >= 0 ? '+' : ''}${(pos.gainLossPercent * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: pos.gainLossPercent >= 0
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Live Activity & Dynamic Island Preview',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Trailing Stop Setting Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trailing Stop Loss',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_trailingStopPercent.toStringAsFixed(0)}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isZeroDte
                  ? 'Crucial for 0DTE: Automatically ratchets up as price climbs, locking in gains and alerting immediately if rapid gamma reversal strikes.'
                  : 'Ratchets up as option price reaches new intraday highs. Alerts lock screen if price retraces.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 12),

            // Preset percent chips
            Wrap(
              spacing: 8,
              children: _presetPercentages.map((pct) {
                final isSelected = _trailingStopPercent == pct;
                return ChoiceChip(
                  label: Text('${pct.toInt()}%'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _trailingStopPercent = pct;
                      });
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Calculated Stop Metrics Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricColumn(
                    'High Water Mark',
                    currencyFormat.format(peak),
                    theme,
                  ),
                  _buildMetricColumn(
                    'Stop Trigger Price',
                    currencyFormat.format(stopPrice),
                    theme,
                    color: Colors.redAccent,
                  ),
                  _buildMetricColumn(
                    'Trailing Distance',
                    '-${_trailingStopPercent.toStringAsFixed(0)}%',
                    theme,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            if (_isTracking) ...[
              FilledButton.icon(
                onPressed: _isLoading ? null : _handleUpdateStop,
                icon: const Icon(Icons.sync),
                label: const Text('Update Trailing Stop'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleEndActivity,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error),
                ),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('End Live Activity'),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: _isLoading ? null : _handleStartActivity,
                icon: const Icon(Icons.play_circle_fill),
                label: Text(
                  isZeroDte
                      ? 'Track 0DTE Position on Lock Screen'
                      : 'Start Live Activity & Dynamic Island',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(
      String title, String value, ThemeData theme, {Color? color}) {
    return Column(
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _handleStartActivity() async {
    setState(() => _isLoading = true);
    try {
      await _service.startOptionPositionActivity(
        widget.position,
        trailingStopPercent: _trailingStopPercent,
      );
      widget.onSessionChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Live Activity started for ${widget.position.symbol} (${_trailingStopPercent.toInt()}% trailing stop)',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUpdateStop() async {
    setState(() => _isLoading = true);
    try {
      await _service.updateTrailingStopPercent(
        widget.position.id,
        _trailingStopPercent,
      );
      widget.onSessionChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Updated trailing stop to ${_trailingStopPercent.toInt()}%',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEndActivity() async {
    setState(() => _isLoading = true);
    try {
      await _service.endOptionPositionActivity(widget.position.id);
      widget.onSessionChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Live Activity ended for ${widget.position.symbol}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
