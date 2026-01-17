import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:robinhood_options_mobile/model/backtesting_provider.dart';
import 'package:robinhood_options_mobile/model/backtesting_models.dart';
import 'package:robinhood_options_mobile/widgets/shared/strategy_details_bottom_sheet.dart';

class TradingStrategiesPage extends StatefulWidget {
  final Function(TradeStrategyTemplate) onLoadStrategy;
  final TradeStrategyConfig? currentConfig;
  final String? selectedStrategyId;

  const TradingStrategiesPage(
      {super.key,
      required this.onLoadStrategy,
      this.currentConfig,
      this.selectedStrategyId});

  @override
  State<TradingStrategiesPage> createState() => _TradingStrategiesPageState();
}

class _TradingStrategiesPageState extends State<TradingStrategiesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  String _searchQuery = '';
  String _sortBy =
      'default'; // default, name_asc, name_desc, date_new, date_old
  bool _hasScrolledToTemplate = false;

  final Set<String> _selectedIndicators = {};

  static const Map<String, String> _indicatorNames = {
    'priceMovement': 'Price Movement',
    'momentum': 'RSI',
    'marketDirection': 'Market Direction',
    'volume': 'Volume',
    'macd': 'MACD',
    'bollingerBands': 'Bollinger Bands',
    'stochastic': 'Stochastic',
    'atr': 'ATR',
    'obv': 'OBV',
    'vwap': 'VWAP',
    'adx': 'ADX',
    'williamsR': 'Williams %R',
    'ichimoku': 'Ichimoku',
    'cci': 'CCI',
    'parabolicSar': 'Parabolic SAR',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trading Strategies'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort Strategies',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'default',
                child: Row(
                  children: [
                    Icon(Icons.view_list, size: 18),
                    SizedBox(width: 8),
                    Text('Default'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'name_asc',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, size: 18),
                    SizedBox(width: 8),
                    Text('Name (A-Z)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'name_desc',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, size: 18),
                    SizedBox(width: 8),
                    Text('Name (Z-A)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'date_new',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18),
                    SizedBox(width: 8),
                    Text('Newest First'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'date_old',
                child: Row(
                  children: [
                    Icon(Icons.history, size: 18),
                    SizedBox(width: 8),
                    Text('Oldest First'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'last_used',
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 18),
                    SizedBox(width: 8),
                    Text('Last Used'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'System'),
            Tab(text: 'My Strategies'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search strategies...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.3),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: _indicatorNames.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final key = _indicatorNames.keys.elementAt(index);
                final label = _indicatorNames.values.elementAt(index);
                final isSelected = _selectedIndicators.contains(key);
                return FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedIndicators.add(key);
                      } else {
                        _selectedIndicators.remove(key);
                      }
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Consumer<BacktestingProvider>(
              builder: (context, provider, child) {
                final allTemplates = provider.templates;
                final systemTemplates = allTemplates
                    .where((t) => t.id.startsWith('default_'))
                    .toList();
                final userTemplates = allTemplates
                    .where((t) => !t.id.startsWith('default_'))
                    .toList();

                if (!_hasScrolledToTemplate &&
                    allTemplates.isNotEmpty &&
                    widget.selectedStrategyId != null) {
                  final index = allTemplates
                      .indexWhere((t) => t.id == widget.selectedStrategyId);
                  if (index != -1) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_itemScrollController.isAttached) {
                        _itemScrollController.scrollTo(
                          index: index,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                          alignment: 0.1, // Slight offset from top
                        );
                      }
                    });
                    _hasScrolledToTemplate = true;
                  }
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStrategyList(context, allTemplates,
                        allowDelete: false,
                        itemScrollController: _itemScrollController),
                    _buildStrategyList(context, systemTemplates,
                        allowDelete: false),
                    _buildStrategyList(context, userTemplates,
                        allowDelete: true),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyList(
      BuildContext context, List<TradeStrategyTemplate> templates,
      {required bool allowDelete, ItemScrollController? itemScrollController}) {
    // Filter by search query
    var filtered = templates.where((t) {
      final matchesName = t.name.toLowerCase().contains(_searchQuery);
      final matchesDesc = t.description.toLowerCase().contains(_searchQuery);
      return matchesName || matchesDesc;
    }).toList();

    // Filter by indicators
    if (_selectedIndicators.isNotEmpty) {
      filtered = filtered.where((t) {
        // Optional: Check if enabledIndicators map exists and contains the keys
        return _selectedIndicators
            .every((key) => t.config.enabledIndicators[key] == true);
      }).toList();
    }

    // Sort
    if (_sortBy != 'default') {
      filtered.sort((a, b) {
        switch (_sortBy) {
          case 'name_asc':
            return a.name.compareTo(b.name);
          case 'name_desc':
            return b.name.compareTo(a.name);
          case 'date_new':
            return b.createdAt.compareTo(a.createdAt);
          case 'date_old':
            return a.createdAt.compareTo(b.createdAt);
          case 'last_used':
            // Sort by lastUsedAt (descending), putting nulls last
            if (a.lastUsedAt == null && b.lastUsedAt == null) return 0;
            if (a.lastUsedAt == null) return 1;
            if (b.lastUsedAt == null) return -1;
            return b.lastUsedAt!.compareTo(a.lastUsedAt!);
          default:
            return 0;
        }
      });
    }

    if (filtered.isEmpty) {
      // Determine what kind of empty state to show
      final isSearching = _searchQuery.isNotEmpty;
      final isMyStrategiesTab =
          allowDelete; // Quick heuristic: user tab allows delete

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  isSearching
                      ? Icons.search_off
                      : (isMyStrategiesTab
                          ? Icons.bookmarks_outlined
                          : Icons.extension_off),
                  size: 64,
                  color:
                      Theme.of(context).colorScheme.outline.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                isSearching
                    ? 'No matches found'
                    : (isMyStrategiesTab
                        ? 'No custom strategies yet'
                        : 'No strategies available'),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              if (!isSearching && isMyStrategiesTab) ...[
                const SizedBox(height: 8),
                Text(
                  'Create one by saving your current specific configuration as a template from the main settings screen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ]
            ],
          ),
        ),
      );
    }

    if (itemScrollController != null) {
      return ScrollablePositionedList.separated(
        itemScrollController: itemScrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: filtered.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _buildStrategyItem(context, filtered[index], allowDelete),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _buildStrategyItem(context, filtered[index], allowDelete),
    );
  }

  Widget _buildStrategyItem(
      BuildContext context, TradeStrategyTemplate template, bool allowDelete) {
    final isDefault = template.id.startsWith('default_');
    final isSelected = template.id == widget.selectedStrategyId;

    return Dismissible(
      key: Key(template.id),
      direction: (!isDefault && allowDelete)
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Strategy?'),
            content: Text(
                'Are you sure you want to delete "${template.name}"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        Provider.of<BacktestingProvider>(context, listen: false)
            .deleteTemplate(template.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${template.name}"')),
        );
      },
      child: Card(
        elevation: isSelected ? 4 : 2,
        shadowColor: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
            : Colors.black12,
        clipBehavior: Clip.antiAlias,
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : (isDefault
                    ? Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withOpacity(0.6)
                    : Theme.of(context).colorScheme.primary.withOpacity(0.3)),
            width: isSelected ? 2 : (isDefault ? 1 : 1.5),
          ),
        ),
        child: InkWell(
          onTap: () {
            _showTemplateDetailsSheet(context, template);
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
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDefault
                                ? Colors.amber.withOpacity(0.1)
                                : Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isDefault ? Icons.verified_rounded : Icons.bookmark,
                            color: isDefault
                                ? Colors.amber[800]
                                : Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    width: 1.5),
                              ),
                              child: Icon(Icons.check,
                                  size: 10,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
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
                                    fontSize: 17, // Increased size
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              if (isDefault) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'SYSTEM',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber[900],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            template.description.isNotEmpty
                                ? template.description
                                : 'No description provided.',
                            // maxLines: 2,
                            // overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'delete') {
                          _confirmDeleteTemplate(context, template);
                        } else if (value == 'edit') {
                          _showEditTemplateDialog(context, template);
                        } else if (value == 'update') {
                          _confirmUpdateTemplateConfig(context, template);
                        } else if (value == 'duplicate') {
                          _duplicateTemplate(context, template);
                        }
                      },
                      itemBuilder: (context) => [
                        if (!isDefault && widget.currentConfig != null)
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
                        if (!isDefault)
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
                        if (!isDefault)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    size: 20, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Delete',
                                    style: TextStyle(color: Colors.red)),
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
                        icon: Icons.trending_up,
                      ),
                      const SizedBox(width: 8),
                      _buildStatBadge(
                        context,
                        'SL',
                        '${template.config.stopLossPercent.toStringAsFixed(1)}%',
                        Colors.red,
                        icon: Icons.trending_down,
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
                        icon: Icons.balance,
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
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildFeatureChip(
                        context,
                        Icons.show_chart,
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
                      _buildFeatureChip(context, Icons.history,
                          'Used ${DateFormat('MMM d').format(template.lastUsedAt!)}'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _duplicateTemplate(
      BuildContext context, TradeStrategyTemplate template) {
    final nameController =
        TextEditingController(text: "${template.name} (Copy)");
    final descriptionController =
        TextEditingController(text: template.description);
    final provider = Provider.of<BacktestingProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            title: const Text('Duplicate Strategy'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'New Strategy Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) => dialogSetState(() {}),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: nameController.text.isEmpty
                    ? null
                    : () {
                        // Check for duplicate names
                        final nameExists = provider.templates.any((t) =>
                            t.name.toLowerCase() ==
                            nameController.text.trim().toLowerCase());

                        if (nameExists) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'A strategy with this name already exists. Please choose a different name.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final newTemplate = TradeStrategyTemplate(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: nameController.text.trim(),
                          description: descriptionController.text.trim(),
                          config: template.config,
                          createdAt: DateTime.now(),
                        );
                        provider.saveTemplate(newTemplate);
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Duplicated "${template.name}"')),
                        );
                      },
                child: const Text('Duplicate'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmUpdateTemplateConfig(
      BuildContext context, TradeStrategyTemplate template) {
    if (widget.currentConfig == null) return;

    final provider = Provider.of<BacktestingProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Update ${template.name}?'),
        content: const Text(
            'This will overwrite the strategy configuration with your current settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final updatedTemplate = TradeStrategyTemplate(
                id: template.id,
                name: template.name,
                description: template.description,
                config: widget.currentConfig!,
                createdAt: template.createdAt,
                lastUsedAt: DateTime.now(),
              );
              provider.saveTemplate(updatedTemplate);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Updated strategy "${template.name}"')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showEditTemplateDialog(
      BuildContext context, TradeStrategyTemplate template) {
    final nameController = TextEditingController(text: template.name);
    final descriptionController =
        TextEditingController(text: template.description);
    final provider = Provider.of<BacktestingProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            title: const Text('Edit Strategy Info'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Strategy Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) => dialogSetState(() {}),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: nameController.text.isEmpty
                    ? null
                    : () {
                        // Check for duplicate names (excluding self)
                        final nameExists = provider.templates.any((t) =>
                            t.name.toLowerCase() ==
                                nameController.text.trim().toLowerCase() &&
                            t.id != template.id);

                        if (nameExists) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'A strategy with this name already exists. Please choose a different name.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final updatedTemplate = TradeStrategyTemplate(
                          id: template.id,
                          name: nameController.text.trim(),
                          description: descriptionController.text.trim(),
                          config: template.config,
                          createdAt: template.createdAt,
                          lastUsedAt: template.lastUsedAt,
                        );

                        provider.saveTemplate(updatedTemplate);
                        Navigator.pop(context);
                      },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteTemplate(
      BuildContext context, TradeStrategyTemplate template) {
    final provider = Provider.of<BacktestingProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Strategy?'),
        content: Text(
            'Are you sure you want to delete "${template.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.deleteTemplate(template.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted "${template.name}"')),
              );
            },
            child: const Text('Delete'),
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

  Widget _buildStatBadge(
      BuildContext context, String label, String value, Color color,
      {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color.withOpacity(0.8)),
            const SizedBox(width: 4),
          ],
          if (label.isNotEmpty) ...[
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.8),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(BuildContext context, IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showTemplateDetailsSheet(
      BuildContext context, TradeStrategyTemplate template) {
    StrategyDetailsBottomSheet.show(context, template, () {
      widget.onLoadStrategy(template);
      Navigator.pop(context); // Close sheet
      Navigator.pop(context); // Close page
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded strategy: ${template.name}')),
      );
    });
  }
}
