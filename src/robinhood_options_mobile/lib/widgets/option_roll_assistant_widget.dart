import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_roll_models.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/risk_circuit_breaker_service.dart';
import 'package:robinhood_options_mobile/widgets/option_defense_playbook_widget.dart';
import 'package:robinhood_options_mobile/widgets/slide_to_confirm_widget.dart';

class OptionRollAssistantWidget extends StatefulWidget {
  final BrokerageUser user;
  final IBrokerageService service;
  final Instrument instrument;
  final OptionAggregatePosition optionPosition;
  final OptionInstrument optionInstrument;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;
  final User? appUser;
  final DocumentReference<User>? userDocRef;
  final bool initialIsPaperTrade;
  final double? underlyingCostBasis;
  final RiskCircuitBreakerService? riskCircuitBreakerService;
  final RollPreset? initialPreset;

  const OptionRollAssistantWidget({
    super.key,
    required this.user,
    required this.service,
    required this.instrument,
    required this.optionPosition,
    required this.optionInstrument,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    required this.appUser,
    required this.userDocRef,
    this.initialIsPaperTrade = false,
    this.underlyingCostBasis,
    this.riskCircuitBreakerService,
    this.initialPreset,
  });

  @override
  State<OptionRollAssistantWidget> createState() =>
      _OptionRollAssistantWidgetState();
}

class _OptionRollAssistantWidgetState extends State<OptionRollAssistantWidget> {
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');
  final DateFormat _expFormat = DateFormat('yyyy-MM-dd');

  Future<OptionChain>? _futureOptionChain;
  Stream<List<OptionInstrument>>? _optionInstrumentStream;
  List<OptionInstrument>? _availableContracts;

  DateTime? _selectedExpirationDate;
  OptionInstrument? _targetInstrument;
  RollPreset _selectedPreset = RollPreset.rollOut;

  final TextEditingController _quantityCtl = TextEditingController();
  final TextEditingController _priceCtl = TextEditingController();

  bool _isPaperTrade = false;
  bool _placingOrder = false;
  String _timeInForce = 'gtc';

  @override
  void initState() {
    super.initState();
    if (widget.initialPreset != null) {
      _selectedPreset = widget.initialPreset!;
    }
    _isPaperTrade = widget.user.source == BrokerageSource.paper ||
        widget.initialIsPaperTrade;
    widget.analytics.logScreenView(screenName: 'Options Roll Assistant');

    final defaultQty = widget.optionPosition.quantity?.toInt() ?? 1;
    _quantityCtl.text = defaultQty.toString();

    _futureOptionChain = widget.service
        .getOptionChains(widget.user, widget.instrument.id)
        .then((chain) {
      if (mounted && chain.expirationDates.isNotEmpty) {
        final currentExp = widget.optionInstrument.expirationDate;
        // Default to first expiration strictly after current expiration date
        final futureExpirations = chain.expirationDates
            .where((d) =>
                currentExp == null ||
                d.isAfter(currentExp) ||
                (d.year == currentExp.year &&
                    d.month == currentExp.month &&
                    d.day == currentExp.day))
            .toList();

        final targetExp = futureExpirations.firstWhereOrNull((d) =>
                currentExp != null &&
                (d.year != currentExp.year ||
                    d.month != currentExp.month ||
                    d.day != currentExp.day)) ??
            chain.expirationDates.first;

        _onExpirationChanged(targetExp);
      }
      return chain;
    });

    _quantityCtl.addListener(_onQuantityChanged);
  }

  @override
  void dispose() {
    _quantityCtl.dispose();
    _priceCtl.dispose();
    super.dispose();
  }

  void _onQuantityChanged() {
    setState(() {});
  }

  void _onExpirationChanged(DateTime expiration) {
    setState(() {
      _selectedExpirationDate = expiration;
      _targetInstrument = null;
      _optionInstrumentStream = widget.service.streamOptionInstruments(
        widget.user,
        Provider.of<OptionInstrumentStore>(context, listen: false),
        widget.instrument,
        _expFormat.format(expiration),
        widget.optionInstrument.type,
        includeMarketData: true,
      );
    });
  }

  void _applyPreset(RollPreset preset, List<OptionInstrument> contracts) {
    if (contracts.isEmpty) return;

    final oldStrike = widget.optionInstrument.strikePrice ?? 0.0;

    // Sort available contracts by strike price ascending
    final sorted = List<OptionInstrument>.from(contracts)
      ..sort((a, b) => (a.strikePrice ?? 0.0).compareTo(b.strikePrice ?? 0.0));

    OptionInstrument? match;

    switch (preset) {
      case RollPreset.rollOut:
        // Find exact or closest same strike
        match = sorted.firstWhereOrNull((c) => (c.strikePrice != null &&
            (c.strikePrice! - oldStrike).abs() < 0.01));
        match ??= sorted.first;
        break;

      case RollPreset.rollUpAndOut:
        // Find next strike above oldStrike
        match = sorted.firstWhereOrNull(
            (c) => c.strikePrice != null && c.strikePrice! > oldStrike);
        match ??= sorted.last;
        break;

      case RollPreset.rollDownAndOut:
        // Find strike directly below oldStrike
        match = sorted.lastWhereOrNull(
            (c) => c.strikePrice != null && c.strikePrice! < oldStrike);
        match ??= sorted.first;
        break;

      case RollPreset.custom:
        match = _targetInstrument ?? sorted.first;
        break;
    }

    setState(() {
      _selectedPreset = preset;
      _targetInstrument = match;
      _updateCalculatedPrice();
    });
  }

  void _updateCalculatedPrice() {
    if (_targetInstrument != null) {
      final calc = OptionRollCalculation.calculate(
        position: widget.optionPosition,
        oldInstrument: widget.optionInstrument,
        newInstrument: _targetInstrument!,
        quantity: double.tryParse(_quantityCtl.text) ?? 1.0,
        underlyingPrice: widget.instrument.quoteObj?.lastTradePrice,
        underlyingCostBasis: widget.underlyingCostBasis,
      );
      _priceCtl.text = calc.netPrice.toStringAsFixed(2);
    }
  }

  OptionRollCalculation? get _calculation {
    if (_targetInstrument == null) return null;
    return OptionRollCalculation.calculate(
      position: widget.optionPosition,
      oldInstrument: widget.optionInstrument,
      newInstrument: _targetInstrument!,
      quantity: double.tryParse(_quantityCtl.text) ?? 1.0,
      underlyingPrice: widget.instrument.quoteObj?.lastTradePrice,
      underlyingCostBasis: widget.underlyingCostBasis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isShort = widget.optionPosition.direction == 'credit' ||
        (widget.optionPosition.legs.isNotEmpty &&
            widget.optionPosition.legs.first.positionType == 'short');
    final isCall = widget.optionInstrument.type.toLowerCase() == 'call';

    String strategyBadge = isCall
        ? (isShort ? 'Covered Call (Short Call)' : 'Long Call')
        : (isShort ? 'Cash-Secured Put (Short Put)' : 'Long Put');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Options Roll Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Defense Playbook',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OptionDefensePlaybookWidget(
                    user: widget.user,
                    service: widget.service,
                    instrument: widget.instrument,
                    optionPosition: widget.optionPosition,
                    optionInstrument: widget.optionInstrument,
                    analytics: widget.analytics,
                    observer: widget.observer,
                    generativeService: widget.generativeService,
                    appUser: widget.appUser,
                    userDocRef: widget.userDocRef,
                    initialIsPaperTrade: widget.initialIsPaperTrade,
                    underlyingCostBasis: widget.underlyingCostBasis,
                    riskCircuitBreakerService: widget.riskCircuitBreakerService,
                  ),
                ),
              );
            },
          ),
          if (_isPaperTrade)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: const Text('PAPER',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                backgroundColor: Colors.blueGrey,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
      body: FutureBuilder<OptionChain>(
        future: _futureOptionChain,
        builder: (context, chainSnapshot) {
          if (chainSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (chainSnapshot.hasError ||
              !chainSnapshot.hasData ||
              chainSnapshot.data!.expirationDates.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.amber),
                    const SizedBox(height: 12),
                    Text(
                      'No expiration dates available to roll ${widget.instrument.symbol}.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          final chain = chainSnapshot.data!;
          final expirationDates = chain.expirationDates;

          return StreamBuilder<List<OptionInstrument>>(
            stream: _optionInstrumentStream,
            builder: (context, contractsSnapshot) {
              if (contractsSnapshot.hasData) {
                _availableContracts = contractsSnapshot.data;
                // Auto-pick target based on selected preset if not yet selected
                if (_targetInstrument == null &&
                    _availableContracts != null &&
                    _availableContracts!.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _targetInstrument == null) {
                      _applyPreset(_selectedPreset, _availableContracts!);
                    }
                  });
                }
              }

              final calc = _calculation;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Underlying Header Card
                    _buildHeaderCard(theme, strategyBadge),
                    const SizedBox(height: 16),

                    // 2. Current Position Leg Card
                    _buildCurrentLegCard(theme, isShort),
                    const SizedBox(height: 16),

                    // 3. Roll Presets Segmented Bar
                    _buildPresetsSection(theme, isCall),
                    const SizedBox(height: 16),

                    // 4. Target Expiration Date Selector
                    _buildExpirationSelector(theme, expirationDates),
                    const SizedBox(height: 16),

                    // 5. Target Strike Selector
                    if (contractsSnapshot.connectionState ==
                        ConnectionState.waiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      _buildStrikeSelector(theme, _availableContracts ?? []),
                    const SizedBox(height: 16),

                    // 6. Financial Analysis & Breakeven Card
                    if (calc != null) ...[
                      _buildAnalysisCard(theme, calc),
                      const SizedBox(height: 16),

                      // 7. Greeks Comparison Card
                      _buildGreeksCard(theme, calc),
                      const SizedBox(height: 16),

                      // 8. Order Preview & Execution Card
                      _buildExecutionCard(theme, calc),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, String strategyBadge) {
    final lastPrice = widget.instrument.quoteObj?.lastTradePrice;
    final change = widget.instrument.quoteObj?.changeToday;
    final isPositive = (change ?? 0) >= 0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.instrument.symbol,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          strategyBadge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.instrument.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (lastPrice != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency.format(lastPrice),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (change != null)
                    Text(
                      '${isPositive ? '+' : ''}${formatCurrency.format(change)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLegCard(ThemeData theme, bool isShort) {
    final exp = widget.optionInstrument.expirationDate;
    final strike = widget.optionInstrument.strikePrice ?? 0.0;
    final type = widget.optionInstrument.type.toUpperCase();
    final dte = exp != null ? exp.difference(DateTime.now()).inDays : 0;
    final mark = widget.optionInstrument.optionMarketData?.markPrice ?? 0.0;
    final closeAction = isShort ? 'Buy to Close' : 'Sell to Close';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current Leg (Closing)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    closeAction,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${strike.toStringAsFixed(1)} $type',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      exp != null ? '${_dateFormat.format(exp)} (${dte}d)' : '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Mark: ${formatCurrency.format(mark)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.optionInstrument.optionMarketData?.bidPrice !=
                            null &&
                        widget.optionInstrument.optionMarketData?.askPrice !=
                            null)
                      Text(
                        'Bid: ${formatCurrency.format(widget.optionInstrument.optionMarketData!.bidPrice!)} / Ask: ${formatCurrency.format(widget.optionInstrument.optionMarketData!.askPrice!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsSection(ThemeData theme, bool isCall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Roll Strategy Preset',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Roll Out (Same Strike)'),
                selected: _selectedPreset == RollPreset.rollOut,
                onSelected: (selected) {
                  if (selected && _availableContracts != null) {
                    _applyPreset(RollPreset.rollOut, _availableContracts!);
                  }
                },
              ),
              const SizedBox(width: 8),
              if (isCall)
                ChoiceChip(
                  label: const Text('Roll Up & Out (+Strike)'),
                  selected: _selectedPreset == RollPreset.rollUpAndOut,
                  onSelected: (selected) {
                    if (selected && _availableContracts != null) {
                      _applyPreset(
                          RollPreset.rollUpAndOut, _availableContracts!);
                    }
                  },
                )
              else
                ChoiceChip(
                  label: const Text('Roll Down & Out (-Strike)'),
                  selected: _selectedPreset == RollPreset.rollDownAndOut,
                  onSelected: (selected) {
                    if (selected && _availableContracts != null) {
                      _applyPreset(
                          RollPreset.rollDownAndOut, _availableContracts!);
                    }
                  },
                ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Custom Roll'),
                selected: _selectedPreset == RollPreset.custom,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedPreset = RollPreset.custom;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpirationSelector(
      ThemeData theme, List<DateTime> expirationDates) {
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Expiration Date',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: expirationDates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final date = expirationDates[index];
              final isSelected = _selectedExpirationDate != null &&
                  date.year == _selectedExpirationDate!.year &&
                  date.month == _selectedExpirationDate!.month &&
                  date.day == _selectedExpirationDate!.day;
              final dte = date.difference(now).inDays;

              return ChoiceChip(
                label: Text(
                  '${_dateFormat.format(date)} (${dte}d)',
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    _onExpirationChanged(date);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStrikeSelector(
      ThemeData theme, List<OptionInstrument> contracts) {
    if (contracts.isEmpty) {
      return const Text('No contracts found for selected expiration date.');
    }

    final sorted = List<OptionInstrument>.from(contracts)
      ..sort((a, b) => (a.strikePrice ?? 0.0).compareTo(b.strikePrice ?? 0.0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Strike Price',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final instr = sorted[index];
              final isSelected = _targetInstrument?.id == instr.id;
              final strike = instr.strikePrice ?? 0.0;
              final mark = instr.optionMarketData?.markPrice ?? 0.0;
              final delta = instr.optionMarketData?.delta;

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() {
                    _selectedPreset = RollPreset.custom;
                    _targetInstrument = instr;
                    _updateCalculatedPrice();
                  });
                },
                child: Container(
                  width: 104,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${strike.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatCurrency.format(mark),
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (delta != null)
                        Text(
                          'Δ ${delta.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisCard(ThemeData theme, OptionRollCalculation calc) {
    final isCredit = calc.creditOrDebit == 'credit';
    final netColor = isCredit ? Colors.green : Colors.amber.shade800;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Roll Financial Analysis',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  calc.summaryLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                      isCredit ? 'NET CREDIT' : 'NET DEBIT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: netColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isCredit ? '+' : '-'}${formatCurrency.format(calc.netPrice)} / sh',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: netColor,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Cash Flow',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isCredit ? '+' : '-'}${formatCurrency.format(calc.totalNetCashFlow.abs())}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: netColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Breakeven Comparison
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current Breakeven',
                          style: theme.textTheme.bodySmall),
                      Text(
                        formatCurrency.format(calc.currentBreakeven),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward, size: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('New Breakeven', style: theme.textTheme.bodySmall),
                      Row(
                        children: [
                          Text(
                            formatCurrency.format(calc.updatedBreakeven),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${calc.breakevenDelta >= 0 ? '+' : ''}${formatCurrency.format(calc.breakevenDelta)})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: calc.breakevenDelta <= 0
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeksCard(ThemeData theme, OptionRollCalculation calc) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Greeks & Exposure Shift',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  children: [
                    Text('Metric',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Old Leg',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('New Leg',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Change',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const TableRow(children: [
                  Divider(),
                  Divider(),
                  Divider(),
                  Divider(),
                ]),
                _buildGreekRow('Delta (Δ)', calc.deltaOld, calc.deltaNew,
                    calc.deltaChange),
                _buildGreekRow('Theta (θ)', calc.thetaOld, calc.thetaNew,
                    calc.thetaChange),
                _buildGreekRow('IV', calc.ivOld, calc.ivNew, calc.ivChange,
                    isPercentage: true),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('DTE'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('${calc.dteCurrent}d'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('${calc.dteTarget}d'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '+${calc.dteDelta}d',
                        style: const TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildGreekRow(
      String label, double? oldVal, double? newVal, double? change,
      {bool isPercentage = false}) {
    String formatVal(double? val) {
      if (val == null) return '-';
      return isPercentage
          ? '${(val * 100).toStringAsFixed(1)}%'
          : val.toStringAsFixed(2);
    }

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(label),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(formatVal(oldVal)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(formatVal(newVal)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            change != null
                ? '${change >= 0 ? '+' : ''}${formatVal(change)}'
                : '-',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: change != null && change > 0 ? Colors.green : Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExecutionCard(ThemeData theme, OptionRollCalculation calc) {
    final qty = int.tryParse(_quantityCtl.text) ?? 1;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Configuration',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: qty > 1
                            ? () {
                                _quantityCtl.text = (qty - 1).toString();
                                _updateCalculatedPrice();
                              }
                            : null,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _quantityCtl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            labelText: 'Contracts',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          _quantityCtl.text = (qty + 1).toString();
                          _updateCalculatedPrice();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _priceCtl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText:
                          'Net ${calc.creditOrDebit.toUpperCase()} Limit',
                      prefixText: '\$ ',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Time in force
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Time In Force', style: theme.textTheme.bodyMedium),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'gtc', label: Text('GTC')),
                    ButtonSegment(value: 'gfd', label: Text('Day')),
                  ],
                  selected: {_timeInForce},
                  onSelectionChanged: (set) {
                    setState(() {
                      _timeInForce = set.first;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 2-leg order summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.remove_circle,
                          size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Leg 1: Close ${qty}x \$${calc.oldInstrument.strikePrice?.toStringAsFixed(1)} ${calc.oldInstrument.type.toUpperCase()} exp ${_dateFormat.format(calc.oldInstrument.expirationDate!)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.add_circle,
                          size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Leg 2: Open ${qty}x \$${calc.newInstrument.strikePrice?.toStringAsFixed(1)} ${calc.newInstrument.type.toUpperCase()} exp ${_dateFormat.format(calc.newInstrument.expirationDate!)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_placingOrder)
              const Center(child: CircularProgressIndicator())
            else
              SlideToConfirm(
                text: 'Slide to Execute Roll',
                backgroundColor: theme.colorScheme.primaryContainer,
                sliderColor: theme.colorScheme.primary,
                textColor: theme.colorScheme.onPrimaryContainer,
                onConfirmed: () => _submitRollOrder(calc),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRollOrder(OptionRollCalculation calc) async {
    setState(() {
      _placingOrder = true;
    });

    final qty = int.tryParse(_quantityCtl.text) ?? 1;
    final limitPrice = double.tryParse(_priceCtl.text) ?? calc.netPrice;
    final direction = calc.creditOrDebit;

    try {
      final accountStore = Provider.of<AccountStore>(context, listen: false);
      final agenticProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      final paperStore = _isPaperTrade
          ? Provider.of<PaperTradingStore>(context, listen: false)
          : null;
      final portfolioState = <String, dynamic>{};

      if (_isPaperTrade && paperStore != null) {
        portfolioState['buyingPower'] = paperStore.cashBalance;
        portfolioState['cashAvailable'] = paperStore.cashBalance;
      } else if (accountStore.items.isNotEmpty) {
        portfolioState['buyingPower'] = accountStore.items[0].buyingPower ??
            accountStore.items[0].portfolioCash ??
            0.0;
        portfolioState['cashAvailable'] =
            accountStore.items[0].portfolioCash ?? 0.0;
      }

      if (!_isPaperTrade) {
        try {
          final riskResult = await FirebaseFunctions.instance
              .httpsCallable('riskguardTask')
              .call({
            'proposal': {
              'symbol': widget.instrument.symbol,
              'quantity': qty,
              'price': limitPrice,
              'action': direction == 'debit' ? 'BUY' : 'SELL',
              'multiplier': 100,
              'strategy': 'Roll Option',
            },
            'portfolioState': portfolioState,
            'config': agenticProvider.config.toRiskGuardConfig(),
          });

          if (riskResult.data['approved'] == false) {
            if (!mounted) return;
            final proceed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('RiskGuard Warning'),
                content: Text(riskResult.data['reason'] ??
                    'Trade rejected by RiskGuard.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Proceed Anyway'),
                  ),
                ],
              ),
            );

            if (proceed != true) {
              setState(() {
                _placingOrder = false;
              });
              return;
            }
          }
        } catch (_) {
          // If riskguardTask fails to execute or is unavailable, proceed
        }
      }

      if (_isPaperTrade && paperStore != null) {
        await paperStore.executeRollOptionStrategy(
          oldPosition: widget.optionPosition,
          newInstrument: calc.newInstrument,
          price: limitPrice,
          quantity: qty.toDouble(),
          direction: direction,
        );
      } else {
        final legs = calc.buildOrderLegs();
        final account = accountStore.items.firstWhereOrNull(
                (a) => a.accountNumber == widget.optionPosition.account) ??
            accountStore.items.first;

        await widget.service.placeMultiLegOptionsOrder(
          widget.user,
          account,
          legs,
          direction,
          limitPrice,
          qty,
          timeInForce: _timeInForce,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isPaperTrade
                  ? 'Paper Roll order executed successfully!'
                  : 'Roll order placed successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error placing roll order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _placingOrder = false;
        });
      }
    }
  }
}
