import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/option_flow_item.dart';
import 'package:robinhood_options_mobile/model/options_flow_store.dart';
import 'package:robinhood_options_mobile/widgets/option_flow_detail_widget.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OptionFlowListItem extends StatelessWidget {
  static final NumberFormat _currencyFormat = NumberFormat.simpleCurrency();
  static final NumberFormat _compactFormat = NumberFormat.compact();
  static final DateFormat _dateFormat = DateFormat('MMM d');
  static final DateFormat _timeFormat = DateFormat('h:mm a');

  final OptionFlowItem item;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final FirebaseAnalytics? analytics;
  final FirebaseAnalyticsObserver? observer;
  final GenerativeService? generativeService;
  final User? user;
  final DocumentReference<User>? userDocRef;
  final VoidCallback? onTap;

  const OptionFlowListItem({
    super.key,
    required this.item,
    this.brokerageUser,
    this.service,
    this.analytics,
    this.observer,
    this.generativeService,
    this.user,
    this.userDocRef,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color sentimentColor;
    IconData sentimentIcon;

    switch (item.sentiment) {
      case Sentiment.bullish:
        sentimentColor = Colors.green;
        sentimentIcon = Icons.trending_up;
        break;
      case Sentiment.bearish:
        sentimentColor = Colors.red;
        sentimentIcon = Icons.trending_down;
        break;
      case Sentiment.neutral:
        sentimentColor = Colors.grey;
        sentimentIcon = Icons.remove;
        break;
    }

    final dte = item.daysToExpiration;
    final daysLabel = dte <= 0 ? '0d' : '${dte}d';

    // Moneyness
    double moneynessPct = 0;
    bool isItm = false;
    if (item.type.toUpperCase() == 'CALL') {
      moneynessPct = (item.spotPrice - item.strike) / item.spotPrice;
      isItm = item.spotPrice >= item.strike;
    } else {
      moneynessPct = (item.strike - item.spotPrice) / item.spotPrice;
      isItm = item.strike >= item.spotPrice;
    }
    final moneynessLabel =
        '${(moneynessPct.abs() * 100).toStringAsFixed(1)}% ${isItm ? "ITM" : "OTM"}';
    final moneynessColor =
        isItm ? sentimentColor : Theme.of(context).colorScheme.onSurfaceVariant;
    final isGoldenSweep =
        item.flags.any((f) => f.toUpperCase().contains('GOLDEN SWEEP'));
    final isWhale = item.premium >= 1000000 ||
        item.flags.any((f) => f.toUpperCase().contains('WHALE'));
    final isHighConviction = item.score >= 80;

    Color borderColor = Theme.of(context).colorScheme.outlineVariant;
    double borderWidth = 1;
    Color? backgroundColor;

    if (isGoldenSweep) {
      borderColor = Colors.amber;
      borderWidth = 2;
      backgroundColor = Colors.amber.withValues(alpha: 0.05);
    } else if (isWhale) {
      borderColor = isDark ? Colors.blue.shade300 : Colors.blue;
      borderWidth = 2;
      backgroundColor = Colors.blue.withValues(alpha: 0.05);
    } else if (isHighConviction) {
      borderColor = isDark ? Colors.purple.shade300 : Colors.purple;
      borderWidth = 1.5;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      child: InkWell(
        onTap: onTap ?? () => _handleItemTap(context, item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sentimentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(sentimentIcon, color: sentimentColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.symbol,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (item.score > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: getScoreColor(context, item.score)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: getScoreColor(context, item.score),
                                      width: 0.5),
                                ),
                                child: Text(
                                  '${item.score}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: getScoreColor(context, item.score),
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isWhale) ...[
                                  Icon(
                                    Icons.star,
                                    size: 16,
                                    color: isDark
                                        ? Colors.amber.shade300
                                        : Colors.amber.shade800,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  _currencyFormat.format(item.premium),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: isWhale
                                        ? (isDark
                                            ? Colors.amber.shade300
                                            : Colors.amber.shade800)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${_dateFormat.format(item.expirationDate)} ($daysLabel) \$${item.strike.toStringAsFixed(1)} ${item.type}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (isItm) ...[
                              const SizedBox(width: 6),
                              OptionFlowFlagBadge(
                                  flag: 'ITM', small: true, showTooltip: false),
                            ],
                            const Spacer(),
                            Text(
                              _timeFormat.format(item.lastTradeDate ??
                                  DateTime.fromMillisecondsSinceEpoch(0)),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (item.isUnusual)
                    OptionFlowBadge(
                        label: 'UNUSUAL',
                        color: isDark
                            ? Colors.purple.shade200
                            : Colors.purple.shade700,
                        icon: Icons.bolt,
                        showTooltip: false),
                  if (item.daysToExpiration == 0)
                    OptionFlowBadge(
                        label: '0DTE',
                        color: Colors.red,
                        icon: Icons.timer_off,
                        showTooltip: true),
                  if (item.flowType == FlowType.sweep)
                    OptionFlowBadge(
                        label: 'SWEEP',
                        color: isDark
                            ? Colors.orange.shade300
                            : Colors.orange.shade900,
                        icon: Icons.waves,
                        showTooltip: false),
                  if (item.flowType == FlowType.block)
                    OptionFlowBadge(
                        label: 'BLOCK',
                        color: Colors.blue,
                        icon: Icons.view_module,
                        showTooltip: false),
                  if (item.flowType == FlowType.darkPool)
                    OptionFlowBadge(
                        label: 'DARK POOL',
                        color: Colors.grey.shade800,
                        icon: Icons.visibility_off,
                        showTooltip: true),
                  if (item.details.isNotEmpty)
                    OptionFlowBadge(
                        label: item.details,
                        color: Theme.of(context).colorScheme.secondary,
                        icon: null,
                        showTooltip: false),
                  ...item.flags.asMap().entries.map((entry) {
                    final index = entry.key;
                    final flag = entry.value;
                    final reason = index < item.reasons.length
                        ? item.reasons[index]
                        : null;
                    return OptionFlowFlagBadge(
                        flag: flag, showTooltip: true, reason: reason);
                  }),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spot Price',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 10,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _currencyFormat.format(item.spotPrice),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            moneynessLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: moneynessColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vol / OI',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 10,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${_compactFormat.format(item.volume)} / ${_compactFormat.format(item.openInterest)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          if (item.openInterest > 0 &&
                              item.volume > item.openInterest) ...[
                            const SizedBox(width: 4),
                            Tooltip(
                              message:
                                  'Volume is ${(item.volume / item.openInterest).toStringAsFixed(1)}x Open Interest',
                              triggerMode: TooltipTriggerMode.tap,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(color: Colors.white),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: (item.volume / item.openInterest > 5
                                          ? (isDark
                                              ? Colors.purple.shade200
                                              : Colors.purple)
                                          : (isDark
                                              ? Colors.amber
                                              : Colors.amber.shade900))
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${(item.volume / item.openInterest).toStringAsFixed(1)}x',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: item.volume / item.openInterest > 5
                                        ? (isDark
                                            ? Colors.purple.shade200
                                            : Colors.purple)
                                        : (isDark
                                            ? Colors.amber
                                            : Colors.amber.shade900),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  _buildDetailItem(context, 'Implied Vol',
                      '${(item.impliedVolatility * 100).toStringAsFixed(1)}%'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleItemTap(BuildContext context, OptionFlowItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OptionFlowDetailWidget(
          item: item,
          brokerageUser: brokerageUser,
          service: service,
          analytics: analytics,
          observer: observer,
          generativeService: generativeService,
          user: user,
          userDocRef: userDocRef,
        ),
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class OptionFlowBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final double fontSize;
  final bool showTooltip;
  final String? reason;

  const OptionFlowBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.fontSize = 10,
    this.showTooltip = true,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );

    if (showTooltip) {
      final doc = OptionsFlowStore.flagDocumentation[label];
      final tooltipMessage =
          reason != null ? (doc != null ? '$doc\n\n$reason' : reason) : doc;

      if (tooltipMessage != null) {
        return Tooltip(
          message: tooltipMessage,
          triggerMode: TooltipTriggerMode.tap,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          showDuration: const Duration(seconds: 5),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(color: Colors.white),
          child: badge,
        );
      }
    }
    return badge;
  }
}

class OptionFlowFlagBadge extends StatelessWidget {
  final String flag;
  final bool small;
  final double fontSize;
  final bool showTooltip;
  final String? reason;

  const OptionFlowFlagBadge({
    super.key,
    required this.flag,
    this.small = false,
    this.fontSize = 10,
    this.showTooltip = true,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = getFlagStyle(context, flag, isDark);
    final color = style.color;
    final icon = style.icon;

    if (small) {
      final badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: fontSize + 2,
                color: color,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              flag,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );

      if (showTooltip) {
        final doc = OptionsFlowStore.flagDocumentation[flag];
        final tooltipMessage =
            reason != null ? (doc != null ? '$doc\n\n$reason' : reason) : doc;

        if (tooltipMessage != null) {
          return Tooltip(
            message: tooltipMessage,
            triggerMode: TooltipTriggerMode.tap,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            showDuration: const Duration(seconds: 5),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(color: Colors.white),
            child: badge,
          );
        }
      }
      return badge;
    }

    return OptionFlowBadge(
        label: flag,
        color: color,
        icon: icon,
        fontSize: fontSize,
        showTooltip: showTooltip,
        reason: reason);
  }
}

FlagStyle getFlagStyle(BuildContext context, String flag, bool isDark) {
  Color color = Theme.of(context).colorScheme.primary;
  IconData? icon;

  final upperFlag = flag.toUpperCase();

  if (upperFlag.contains('WHALE') || upperFlag.contains('INSTITUTIONAL')) {
    color = isDark ? Colors.amber.shade300 : Colors.amber.shade800;
    icon = Icons.star;
  } else if (upperFlag.contains('VOL') ||
      upperFlag.contains('UNUSUAL') ||
      upperFlag.contains('SQUEEZE')) {
    color = isDark ? Colors.purple.shade200 : Colors.purple;
    icon = Icons.bolt;
  } else if (upperFlag.contains('GOLDEN') || upperFlag.contains('SWEEP')) {
    color = isDark ? Colors.orange.shade300 : Colors.orange.shade800;
    icon = Icons.waves;
  } else if (upperFlag.contains('EARNINGS')) {
    color = Colors.blue;
    icon = Icons.event;
  } else if (upperFlag.contains('DIVERGENCE')) {
    color = Colors.teal;
    icon = Icons.compare_arrows;
  } else if (upperFlag.contains('CHEAP') || upperFlag.contains('LOTTO')) {
    color = Colors.pink.shade300;
    icon = Icons.local_activity;
  } else if (upperFlag.contains('LIQUID')) {
    color = isDark ? Colors.blue.shade200 : Colors.blue.shade800;
    icon = Icons.water;
  } else if (upperFlag.contains('AGGRESSIVE')) {
    color = isDark ? Colors.redAccent : Colors.red;
    icon = Icons.flash_on;
  } else if (upperFlag.contains('BULLISH')) {
    color = isDark ? Colors.green.shade300 : Colors.green.shade700;
    icon = Icons.trending_up;
  } else if (upperFlag.contains('BEARISH')) {
    color = isDark ? Colors.red.shade300 : Colors.red.shade700;
    icon = Icons.trending_down;
  } else if (upperFlag == 'CROSS TRADE') {
    color = isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700;
    icon = Icons.swap_horiz;
  } else if (upperFlag.contains('MID MARKET')) {
    color = isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade700;
    icon = Icons.horizontal_rule;
  } else if (upperFlag.contains('LARGE BLOCK') ||
      upperFlag.contains('DARK POOL')) {
    color = isDark ? Colors.grey.shade400 : Colors.grey.shade800;
    icon = Icons.visibility_off;
  } else if (upperFlag.contains('BLOCK')) {
    color = Colors.blue;
    icon = Icons.view_module;
  } else if (upperFlag == 'ITM') {
    color = isDark ? Colors.amber : Colors.amber.shade900;
    icon = Icons.check_circle_outline;
  } else if (upperFlag == 'OTM') {
    color = Theme.of(context).colorScheme.onSurfaceVariant;
    icon = Icons.radio_button_unchecked;
  }

  return FlagStyle(color, icon);
}

Color getScoreColor(BuildContext context, int score) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (score >= 80) {
    return isDark ? Colors.purple.shade300 : Colors.purple.shade700;
  }
  if (score >= 60) {
    return isDark ? Colors.green.shade300 : Colors.green.shade700;
  }
  if (score >= 40) {
    return isDark ? Colors.amber.shade300 : Colors.amber.shade900;
  }
  return Colors.grey;
}

class FlagStyle {
  final Color color;
  final IconData? icon;

  FlagStyle(this.color, this.icon);
}
