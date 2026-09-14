import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/instrument_buying_power.dart';

final _currencyFormat = NumberFormat.simpleCurrency();

/// A prominent warning banner displayed when an instrument has active trade warnings,
/// volatility alerts, or restrictions.
class InstrumentTradeWarningsBanner extends StatelessWidget {
  final InstrumentTradeWarnings warnings;
  final VoidCallback? onTapDetails;
  final bool compact;

  const InstrumentTradeWarningsBanner({
    super.key,
    required this.warnings,
    this.onTapDetails,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!warnings.hasWarnings) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isCritical = warnings.hasCritical;
    final primary = warnings.primaryWarning;

    final bgColor = isCritical
        ? theme.colorScheme.errorContainer
        : (theme.brightness == Brightness.dark
            ? Colors.amber.shade900.withAlpha(50)
            : Colors.amber.shade50);

    final borderColor = isCritical
        ? theme.colorScheme.error
        : (theme.brightness == Brightness.dark
            ? Colors.amber.shade700
            : Colors.amber.shade400);

    final textColor = isCritical
        ? theme.colorScheme.onErrorContainer
        : (theme.brightness == Brightness.dark
            ? Colors.amber.shade200
            : Colors.amber.shade900);

    final iconColor =
        isCritical ? theme.colorScheme.error : Colors.amber.shade700;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: onTapDetails,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2.0, right: 10.0),
                  child: Icon(
                    primary?.icon ??
                        (isCritical
                            ? Icons.error_outline_rounded
                            : Icons.warning_amber_rounded),
                    color: iconColor,
                    size: 22.0,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              primary?.title ??
                                  (isCritical
                                      ? 'Critical Trade Warning'
                                      : 'Trade Advisory Warning'),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (warnings.warnings.length > 1)
                            Container(
                              margin: const EdgeInsets.only(left: 6.0),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0, vertical: 1.0),
                              decoration: BoxDecoration(
                                color: borderColor.withAlpha(60),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Text(
                                '+${warnings.warnings.length - 1} more',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (!compact &&
                          primary != null &&
                          primary.message.isNotEmpty) ...[
                        const SizedBox(height: 3.0),
                        Text(
                          primary.message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textColor.withAlpha(220),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTapDetails != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6.0, top: 2.0),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: textColor.withAlpha(180),
                      size: 20.0,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An inline summary chip or row displaying instrument-specific buying power and margin status.
class InstrumentBuyingPowerSummaryTile extends StatelessWidget {
  final InstrumentBuyingPower buyingPower;
  final VoidCallback? onTap;
  final bool showShort;

  const InstrumentBuyingPowerSummaryTile({
    super.key,
    required this.buyingPower,
    this.onTap,
    this.showShort = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayBp = showShort && buyingPower.shortBuyingPower != null
        ? buyingPower.shortBuyingPower!
        : buyingPower.buyingPower;

    final label = showShort ? 'Short Buying Power' : 'Instrument Buying Power';

    final badgeWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: buyingPower.cashOnly
            ? theme.colorScheme.errorContainer.withAlpha(120)
            : theme.colorScheme.primaryContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        buyingPower.marginStatusLabel,
        style: theme.textTheme.labelSmall?.copyWith(
          color: buyingPower.cashOnly
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: 10.0,
        ),
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact =
                constraints.hasBoundedWidth && constraints.maxWidth < 380;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (!isCompact) ...[
                            const SizedBox(width: 6.0),
                            badgeWidget,
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currencyFormat.format(displayBp),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: 4.0),
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16.0,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                if (isCompact) ...[
                  const SizedBox(height: 3.0),
                  badgeWidget,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A comprehensive modal bottom sheet detailing instrument buying power,
/// margin requirements, short selling parameters, and active trade warnings.
class InstrumentBuyingPowerSheet extends StatelessWidget {
  final String symbol;
  final String? name;
  final InstrumentBuyingPower? buyingPower;
  final InstrumentTradeWarnings? warnings;

  const InstrumentBuyingPowerSheet({
    super.key,
    required this.symbol,
    this.name,
    this.buyingPower,
    this.warnings,
  });

  static Future<void> show(
    BuildContext context, {
    required String symbol,
    String? name,
    InstrumentBuyingPower? buyingPower,
    InstrumentTradeWarnings? warnings,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => InstrumentBuyingPowerSheet(
        symbol: symbol,
        name: name,
        buyingPower: buyingPower,
        warnings: warnings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$symbol Buying Power & Risk',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (name != null && name!.isNotEmpty) ...[
                        const SizedBox(height: 2.0),
                        Text(
                          name!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),

              // Buying Power Card
              if (buyingPower != null) ...[
                Card(
                  elevation: 0,
                  color:
                      theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withAlpha(100),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purchasing Capacity',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12.0),
                        _buildMetricRow(
                          context,
                          'Buying Power',
                          buyingPower!.formattedBuyingPower,
                          isEmphasized: true,
                        ),
                        if (buyingPower!.maxShares != null)
                          _buildMetricRow(
                            context,
                            'Max Purchasable Shares',
                            buyingPower!.maxShares!.toStringAsFixed(1),
                          ),
                        if (buyingPower!.shortBuyingPower != null)
                          _buildMetricRow(
                            context,
                            'Short Buying Power',
                            buyingPower!.formattedShortBuyingPower,
                          ),
                        if (buyingPower!.maxShortShares != null)
                          _buildMetricRow(
                            context,
                            'Max Short Shares',
                            buyingPower!.maxShortShares!.toStringAsFixed(1),
                          ),
                        const Divider(height: 20.0),
                        Text(
                          'Margin & Collateral Terms',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12.0),
                        _buildMetricRow(
                          context,
                          'Status',
                          buyingPower!.marginStatusLabel,
                        ),
                        _buildMetricRow(
                          context,
                          'Initial Margin Requirement',
                          buyingPower!.marginPercentage,
                        ),
                        _buildMetricRow(
                          context,
                          'Maintenance Margin Requirement',
                          buyingPower!.maintenanceMarginPercentage,
                        ),
                        if (buyingPower!.leverageRatio != null)
                          _buildMetricRow(
                            context,
                            'Effective Leverage',
                            '${buyingPower!.leverageRatio!.toStringAsFixed(2)}x',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
              ],

              // Trade Warnings Section
              Text(
                'Trade Warnings & Risk Disclosures',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8.0),

              if (warnings != null && warnings!.hasWarnings) ...[
                ...warnings!.warnings.map((w) => _buildWarningItem(context, w)),
              ] else ...[
                Card(
                  elevation: 0,
                  color: Colors.green.withAlpha(25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    side: BorderSide(color: Colors.green.withAlpha(80)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.green,
                          size: 22.0,
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            'No active trading restrictions, volatility halts, or elevated margin requirements for $symbol.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.brightness == Brightness.dark
                                  ? Colors.green.shade200
                                  : Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20.0),
              // Footnote disclosure
              Text(
                'Note: Instrument-specific buying power accounts for individual security margin haircuts, FINRA Rule 4210 maintenance rates, and exchange trading halts. Rates and tradability can change during market hours.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11.0,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    BuildContext context,
    String label,
    String value, {
    bool isEmphasized = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isEmphasized ? FontWeight.bold : FontWeight.w500,
              fontSize: isEmphasized ? 15.0 : 13.0,
              color: isEmphasized ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(
      BuildContext context, InstrumentTradeWarning warning) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: warning.severityColor.withAlpha(20),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: warning.severityColor.withAlpha(100),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0, right: 10.0),
              child: Icon(
                warning.icon,
                color: warning.severityColor,
                size: 20.0,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          warning.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6.0, vertical: 1.0),
                        decoration: BoxDecoration(
                          color: warning.severityColor.withAlpha(40),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          warning.displaySeverity.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: warning.severityColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 9.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (warning.message.isNotEmpty) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      warning.message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
