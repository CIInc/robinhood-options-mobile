import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/model/backtesting_provider.dart';
import 'package:robinhood_options_mobile/model/backtesting_models.dart';
import 'package:robinhood_options_mobile/model/trade_strategies.dart';
import 'package:robinhood_options_mobile/widgets/shared/strategy_list_widget.dart';
import 'package:robinhood_options_mobile/widgets/shared/strategy_details_bottom_sheet.dart';
import 'package:robinhood_options_mobile/widgets/trade_signals_page.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';

class TradingStrategiesPage extends StatefulWidget {
  final Function(TradeStrategyTemplate) onLoadStrategy;
  final TradeStrategyConfig? currentConfig;
  final String? selectedStrategyId;
  final User? user;
  final DocumentReference<User>? userDocRef;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;

  const TradingStrategiesPage({
    super.key,
    required this.onLoadStrategy,
    this.currentConfig,
    this.selectedStrategyId,
    this.user,
    this.userDocRef,
    this.brokerageUser,
    this.service,
  });

  @override
  State<TradingStrategiesPage> createState() => _TradingStrategiesPageState();
}

class _TradingStrategiesPageState extends State<TradingStrategiesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy =
      'default'; // default, name_asc, name_desc, date_new, date_old

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
        elevation: 0,
        scrolledUnderElevation: 2,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort Strategies',
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            position: PopupMenuPosition.under,
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
                    Text('Name (Z-A)'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
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
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          indicatorSize: TabBarIndicatorSize.label,
          splashBorderRadius: BorderRadius.circular(16),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'System'),
            Tab(text: 'My Strategies'),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search strategies...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainer
                      .withValues(alpha: 0.5),
                  selectedColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
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

                return TabBarView(
                  controller: _tabController,
                  children: [
                    StrategyListWidget(
                      strategies: allTemplates,
                      allowDelete: false,
                      searchQuery: _searchQuery,
                      indicatorNames: _indicatorNames,
                      selectedIndicators: _selectedIndicators,
                      sortBy: _sortBy,
                      selectedStrategyId: widget.selectedStrategyId,
                      onSelect: (template) {
                        _showTemplateDetailsSheet(context, template);
                      },
                      onDelete: (template) =>
                          _confirmDeleteTemplate(context, template),
                      onEdit: (template) =>
                          _showEditTemplateDialog(context, template),
                      onUpdate: widget.currentConfig != null
                          ? (template) =>
                              _confirmUpdateTemplateConfig(context, template)
                          : null,
                      onDuplicate: (template) =>
                          _duplicateTemplate(context, template),
                    ),
                    StrategyListWidget(
                      strategies: systemTemplates,
                      allowDelete: false,
                      searchQuery: _searchQuery,
                      indicatorNames: _indicatorNames,
                      selectedIndicators: _selectedIndicators,
                      sortBy: _sortBy,
                      selectedStrategyId: widget.selectedStrategyId,
                      onSelect: (template) {
                        _showTemplateDetailsSheet(context, template);
                      },
                      onDuplicate: (template) =>
                          _duplicateTemplate(context, template),
                    ),
                    StrategyListWidget(
                      strategies: userTemplates,
                      allowDelete: true,
                      searchQuery: _searchQuery,
                      indicatorNames: _indicatorNames,
                      selectedIndicators: _selectedIndicators,
                      sortBy: _sortBy,
                      selectedStrategyId: widget.selectedStrategyId,
                      onSelect: (template) {
                        _showTemplateDetailsSheet(context, template);
                      },
                      onDelete: (template) =>
                          _confirmDeleteTemplate(context, template),
                      onEdit: (template) =>
                          _showEditTemplateDialog(context, template),
                      onUpdate: widget.currentConfig != null
                          ? (template) =>
                              _confirmUpdateTemplateConfig(context, template)
                          : null,
                      onDuplicate: (template) =>
                          _duplicateTemplate(context, template),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
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

  void _showTemplateDetailsSheet(
      BuildContext context, TradeStrategyTemplate template) {
    StrategyDetailsBottomSheet.showWithConfirmation(
      context: context,
      template: template,
      currentConfig: widget.currentConfig,
      onConfirmLoad: (t) {
        widget.onLoadStrategy(t);
        Navigator.pop(context); // Close page
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded strategy: ${t.name}')),
        );
      },
      onSearch: () {
        if (widget.user != null && widget.userDocRef != null) {
          final initialIndicators = template.config.enabledIndicators.entries
              .where((e) => e.value)
              .fold<Map<String, String>>({}, (prev, element) {
            prev[element.key] = "BUY";
            return prev;
          });

          Navigator.pop(context); // Close sheet
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => TradeSignalsPage(
                        user: widget.user,
                        userDocRef: widget.userDocRef,
                        brokerageUser: widget.brokerageUser,
                        service: widget.service,
                        analytics: MyApp.analytics,
                        observer: MyApp.observer,
                        generativeService: GenerativeService(),
                        initialIndicators: initialIndicators,
                        strategyTemplate: template,
                      )));
        } else {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in for signal search.')),
          );
        }
      },
    );
  }
}
