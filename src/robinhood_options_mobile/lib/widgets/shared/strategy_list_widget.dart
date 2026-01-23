import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:robinhood_options_mobile/model/backtesting_models.dart';
import 'package:robinhood_options_mobile/widgets/shared/strategy_details_bottom_sheet.dart';

class StrategyListWidget extends StatelessWidget {
  final List<TradeStrategyTemplate> strategies;
  final String searchQuery;
  final Set<String> selectedIndicators;
  final String
      sortBy; // default, name_asc, name_desc, date_new, date_old, last_used
  final bool allowDelete;
  final Function(TradeStrategyTemplate) onSelect;
  final Function(TradeStrategyTemplate)? onDelete;
  final Function(TradeStrategyTemplate)? onEdit;
  final Function(TradeStrategyTemplate)? onUpdate;
  final Function(TradeStrategyTemplate)? onDuplicate;
  final ItemScrollController? itemScrollController;
  final ScrollController? scrollController;
  final String? selectedStrategyId;

  const StrategyListWidget({
    super.key,
    required this.strategies,
    this.searchQuery = '',
    this.selectedIndicators = const {},
    this.sortBy = 'default',
    this.allowDelete = false,
    required this.onSelect,
    this.onDelete,
    this.onEdit,
    this.onUpdate,
    this.onDuplicate,
    this.itemScrollController,
    this.scrollController,
    this.selectedStrategyId,
  });

  @override
  Widget build(BuildContext context) {
    // Filter by search query
    var filtered = strategies.where((t) {
      if (searchQuery.isEmpty) return true;
      final query = searchQuery.toLowerCase();
      final matchesName = t.name.toLowerCase().contains(query);
      final matchesDesc = t.description.toLowerCase().contains(query);
      return matchesName || matchesDesc;
    }).toList();

    // Filter by indicators
    if (selectedIndicators.isNotEmpty) {
      filtered = filtered.where((t) {
        return selectedIndicators
            .every((key) => t.config.enabledIndicators[key] == true);
      }).toList();
    }

    // Sort
    if (sortBy != 'default') {
      filtered.sort((a, b) {
        switch (sortBy) {
          case 'name_asc':
            return a.name.compareTo(b.name);
          case 'name_desc':
            return b.name.compareTo(a.name);
          case 'date_new':
            return b.createdAt.compareTo(a.createdAt);
          case 'date_old':
            return a.createdAt.compareTo(b.createdAt);
          case 'last_used':
            if (a.lastUsedAt == null && b.lastUsedAt == null) return 0;
            if (a.lastUsedAt == null) return 1;
            if (b.lastUsedAt == null) return -1;
            return b.lastUsedAt!.compareTo(a.lastUsedAt!);
          default:
            return 0;
        }
      });
    }

    // Move selected strategy to the front
    if (selectedStrategyId != null) {
      final selectedIndex =
          filtered.indexWhere((s) => s.id == selectedStrategyId);
      if (selectedIndex > 0) {
        final selected = filtered.removeAt(selectedIndex);
        filtered.insert(0, selected);
      }
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No strategies found',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    if (itemScrollController != null) {
      return ScrollablePositionedList.builder(
        itemCount: filtered.length,
        itemScrollController: itemScrollController,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) =>
            _buildStrategyCard(context, filtered[index]),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: filtered.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) =>
          _buildStrategyCard(context, filtered[index]),
    );
  }

  Widget _buildStrategyCard(
      BuildContext context, TradeStrategyTemplate template) {
    final isDefault = template.id.startsWith('default_');
    final isSelected = template.id == selectedStrategyId;
    final df = DateFormat('MMM dd, yyyy');

    return Card(
      elevation: isSelected ? 2 : 0,
      shadowColor: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
          : Colors.transparent,
      clipBehavior: Clip.antiAlias,
      color: isSelected
          ? Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.15)
          : Theme.of(context).cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor.withValues(alpha: 0.1),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => onSelect(template),
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => StrategyDetailsBottomSheet(
              template: template,
              onLoad: () {
                Navigator.pop(context); // Close bottom sheet
                onSelect(template); // Proceed with load
              },
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDefault
                          ? Colors.amber.withValues(alpha: 0.15)
                          : Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDefault ? Icons.verified : Icons.analytics_rounded,
                      color: isDefault
                          ? Colors.amber[800]
                          : Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                template.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color:
                                          Colors.amber.withValues(alpha: 0.5),
                                      width: 0.5),
                                ),
                                child: Text(
                                  'SYSTEM',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[900],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (template.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            template.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Created ${df.format(template.createdAt)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onEdit == null &&
                      onUpdate == null &&
                      onDuplicate == null &&
                      allowDelete &&
                      onDelete != null &&
                      !isDefault)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Theme.of(context).colorScheme.error,
                      onPressed: () => onDelete!(template),
                    )
                  else if (onEdit != null ||
                      onUpdate != null ||
                      onDuplicate != null ||
                      (allowDelete && onDelete != null && !isDefault))
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'delete' && onDelete != null) {
                          onDelete!(template);
                        } else if (value == 'edit' && onEdit != null) {
                          onEdit!(template);
                        } else if (value == 'update' && onUpdate != null) {
                          onUpdate!(template);
                        } else if (value == 'duplicate' &&
                            onDuplicate != null) {
                          onDuplicate!(template);
                        }
                      },
                      itemBuilder: (context) => [
                        if (onUpdate != null)
                          const PopupMenuItem(
                            value: 'update',
                            child: Row(
                              children: [
                                Icon(Icons.save_as_outlined, size: 20),
                                SizedBox(width: 12),
                                Text('Update Config'),
                              ],
                            ),
                          ),
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 20),
                                SizedBox(width: 12),
                                Text('Edit Info'),
                              ],
                            ),
                          ),
                        if (onDuplicate != null)
                          const PopupMenuItem(
                            value: 'duplicate',
                            child: Row(
                              children: [
                                Icon(Icons.copy_outlined, size: 20),
                                SizedBox(width: 12),
                                Text('Duplicate'),
                              ],
                            ),
                          ),
                        if ((onEdit != null ||
                                onUpdate != null ||
                                onDuplicate != null) &&
                            allowDelete &&
                            onDelete != null &&
                            !isDefault)
                          const PopupMenuDivider(),
                        if (allowDelete && onDelete != null && !isDefault)
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    size: 20,
                                    color: Theme.of(context).colorScheme.error),
                                const SizedBox(width: 12),
                                Text('Delete',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildStatBadge(
                      context,
                      '',
                      template.config.interval,
                      Theme.of(context).colorScheme.tertiary,
                      icon: Icons.timer_outlined,
                    ),
                    const SizedBox(width: 8),
                    _buildStatBadge(
                      context,
                      'TP',
                      '${template.config.takeProfitPercent.toStringAsFixed(1)}%',
                      Colors.green,
                      icon: Icons.trending_up_rounded,
                    ),
                    const SizedBox(width: 8),
                    _buildStatBadge(
                      context,
                      'SL',
                      '${template.config.stopLossPercent.toStringAsFixed(1)}%',
                      Colors.red,
                      icon: Icons.trending_down_rounded,
                    ),
                    const SizedBox(width: 8),
                    _buildStatBadge(
                      context,
                      'R/R',
                      template.config.stopLossPercent == 0
                          ? 'Inf'
                          : (template.config.takeProfitPercent /
                                  template.config.stopLossPercent)
                              .toStringAsFixed(1),
                      Theme.of(context).colorScheme.primary,
                      icon: Icons.balance_rounded,
                    ),
                    const SizedBox(width: 8),
                    _buildStatBadge(
                      context,
                      'Risk',
                      '${(template.config.riskPerTrade * 100).toStringAsFixed(1)}%',
                      Colors.orange,
                      icon: Icons.shield_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFeatureChip(
                      context,
                      Icons.show_chart_rounded,
                      template.config.symbolFilter.isEmpty
                          ? "All Symbols"
                          : (template.config.symbolFilter.length > 3
                              ? "${template.config.symbolFilter.take(3).join(', ')} +${template.config.symbolFilter.length - 3}"
                              : template.config.symbolFilter.join(', '))),
                  _buildFeatureChip(context, Icons.layers_outlined,
                      _getIndicatorsSummary(template.config)),
                  if (template.config.trailingStopEnabled)
                    _buildFeatureChip(context, Icons.trending_up,
                        'Trailing ${template.config.trailingStopPercent}%'),
                  if (template.lastUsedAt != null)
                    _buildFeatureChip(context, Icons.history_rounded,
                        'Used ${_formatTime(template.lastUsedAt!)}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(
      BuildContext context, String label, String value, Color color,
      {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          if (label.isNotEmpty) ...[
            Text(
              '$label ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getIndicatorsSummary(TradeStrategyConfig config) {
    final Map<String, String> friendlyNames = {
      'priceMovement': 'Price',
      'momentum': 'RSI',
      'marketDirection': 'Market',
      'volume': 'Vol',
      'macd': 'MACD',
      'bollingerBands': 'BB',
      'stochastic': 'Stoch',
      'atr': 'ATR',
      'obv': 'OBV',
      'vwap': 'VWAP',
      'adx': 'ADX',
      'williamsR': 'WillR',
      'ichimoku': 'Ichi',
      'cci': 'CCI',
      'parabolicSar': 'SAR',
    };

    final activeKeys = config.enabledIndicators.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    var names = activeKeys
        .map((k) => friendlyNames[k] ?? k)
        .toList(); // Map to friendly names

    if (config.customIndicators.isNotEmpty) {
      names.addAll(config.customIndicators.map((c) => c.name));
    }

    if (names.isEmpty) return 'No indicators';

    if (names.length <= 3) {
      return names.join(', ');
    }
    return '${names.take(3).join(", ")} +${names.length - 3}';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(time);
    }
  }
}
