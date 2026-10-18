import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/schwab_strategy_chain.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

/// Interactive UI widget visualizing Schwab multi-leg strategy option chains:
/// `GET /marketdata/v1/chains?strategy=...`
class SchwabStrategyChainWidget extends StatefulWidget {
  final BrokerageUser user;
  final IBrokerageService service;
  final Instrument instrument;
  final SchwabStrategyType initialStrategy;
  final void Function(SchwabStrategyPackage package)? onPackageSelected;

  const SchwabStrategyChainWidget({
    super.key,
    required this.user,
    required this.service,
    required this.instrument,
    this.initialStrategy = SchwabStrategyType.vertical,
    this.onPackageSelected,
  });

  @override
  State<SchwabStrategyChainWidget> createState() =>
      _SchwabStrategyChainWidgetState();
}

class _SchwabStrategyChainWidgetState extends State<SchwabStrategyChainWidget> {
  late SchwabStrategyType _selectedStrategy;
  String _selectedContractType = 'ALL';
  DateTime? _selectedExpiration;
  double? _selectedInterval;

  Future<SchwabStrategyChain>? _futureChain;
  SchwabStrategyChain? _cachedChain;

  static const List<SchwabStrategyType> _supportedStrategies = [
    SchwabStrategyType.vertical,
    SchwabStrategyType.straddle,
    SchwabStrategyType.strangle,
    SchwabStrategyType.calendar,
    SchwabStrategyType.butterfly,
    SchwabStrategyType.condor,
    SchwabStrategyType.covered,
    SchwabStrategyType.diagonal,
    SchwabStrategyType.collar,
    SchwabStrategyType.roll,
  ];

  static const List<double?> _intervalOptions = [
    null,
    1.0,
    2.5,
    5.0,
    10.0,
  ];

  @override
  void initState() {
    super.initState();
    _selectedStrategy = widget.initialStrategy;
    _loadChain();
  }

  void _loadChain() {
    setState(() {
      _futureChain = widget.service
          .getStrategyOptionChain(
        widget.user,
        widget.instrument.symbol,
        strategy: _selectedStrategy.paramValue,
        contractType: _selectedContractType,
        interval: _selectedInterval,
        fromDate: _selectedExpiration,
        toDate: _selectedExpiration,
      )
          .then((chain) {
        if (chain is SchwabStrategyChain) {
          _cachedChain = chain;
          // Set default expiration if not set
          if (_selectedExpiration == null &&
              chain.availableExpirations.isNotEmpty) {
            _selectedExpiration = chain.availableExpirations.first;
          }
          return chain;
        }
        throw Exception('Received unexpected response type');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.instrument.symbol} Strategy Chains'),
            Text(
              'Schwab Market Data · ${_selectedStrategy.displayName}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Strategy selection chips
          _buildStrategyChips(theme),
          // Filter row: Contract Type & Interval
          _buildFilterBar(theme),
          const Divider(height: 1),
          // Main content: Packages list
          Expanded(
            child: FutureBuilder<SchwabStrategyChain>(
              future: _futureChain,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.orange),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load ${_selectedStrategy.displayName} chain',
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadChain,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final chain = snapshot.data ?? _cachedChain;
                if (chain == null || chain.allPackages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.layers_clear,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'No ${_selectedStrategy.displayName} packages available',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Try adjusting expiration date or strike interval filters',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return _buildChainContent(theme, chain);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyChips(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: _supportedStrategies.map((strategy) {
          final isSelected = strategy == _selectedStrategy;
          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: ChoiceChip(
              label: Text(strategy.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected && strategy != _selectedStrategy) {
                  setState(() {
                    _selectedStrategy = strategy;
                    _selectedExpiration = null;
                  });
                  _loadChain();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Contract Type selector
          DropdownButton<String>(
            value: _selectedContractType,
            isDense: true,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All Types')),
              DropdownMenuItem(value: 'CALL', child: Text('Calls Only')),
              DropdownMenuItem(value: 'PUT', child: Text('Puts Only')),
            ],
            onChanged: (val) {
              if (val != null && val != _selectedContractType) {
                setState(() {
                  _selectedContractType = val;
                });
                _loadChain();
              }
            },
          ),
          const SizedBox(width: 16),
          // Interval filter
          DropdownButton<double?>(
            value: _selectedInterval,
            isDense: true,
            hint: const Text('Interval: Any'),
            underline: const SizedBox(),
            items: _intervalOptions.map((opt) {
              return DropdownMenuItem<double?>(
                value: opt,
                child: Text(opt == null
                    ? 'Any Interval'
                    : '\$${opt.toStringAsFixed(opt % 1 == 0 ? 0 : 1)} spread'),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedInterval = val;
              });
              _loadChain();
            },
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh Chain',
            onPressed: _loadChain,
          ),
        ],
      ),
    );
  }

  Widget _buildChainContent(ThemeData theme, SchwabStrategyChain chain) {
    final expirations = chain.availableExpirations;
    final activePackages = _selectedExpiration != null
        ? chain.packagesForExpiration(_selectedExpiration!)
        : chain.allPackages;

    return ListView(
      children: [
        // Underlying header summary card
        if (chain.underlying != null || chain.underlyingPrice != null)
          _buildUnderlyingSummary(theme, chain),

        // Expiration selector chips if multiple expirations exist
        if (expirations.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: expirations.map((exp) {
                  final isSelected = _selectedExpiration != null &&
                      _selectedExpiration!.year == exp.year &&
                      _selectedExpiration!.month == exp.month &&
                      _selectedExpiration!.day == exp.day;
                  final label = DateFormat('MMM d, yyyy').format(exp);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: FilterChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedExpiration = selected ? exp : null;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

        // Package Cards List
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${activePackages.length} Strategies Available',
                style:
                    theme.textTheme.labelMedium?.copyWith(color: Colors.grey),
              ),
              if (chain.interval != null)
                Text(
                  'Strike Interval: \$${chain.interval!.toStringAsFixed(1)}',
                  style:
                      theme.textTheme.labelMedium?.copyWith(color: Colors.grey),
                ),
            ],
          ),
        ),

        ...activePackages.map((pkg) => _buildPackageCard(theme, pkg)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildUnderlyingSummary(ThemeData theme, SchwabStrategyChain chain) {
    final underlying = chain.underlying;
    final price = chain.underlyingPrice ?? underlying?.last ?? underlying?.mark;
    final change = underlying?.change;
    final pctChange = underlying?.percentChange;
    final iv = chain.volatility;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.instrument.symbol,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (price != null)
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            if (change != null || pctChange != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(
                        (change ?? 0) >= 0
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                        color: (change ?? 0) >= 0 ? Colors.green : Colors.red,
                      ),
                      Text(
                        '${(change ?? 0) >= 0 ? '+' : ''}${change?.toStringAsFixed(2) ?? ''} (${pctChange?.toStringAsFixed(2) ?? '0'}%)',
                        style: TextStyle(
                          color: (change ?? 0) >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (iv != null)
                    Text(
                      'Implied Vol: ${iv.toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageCard(ThemeData theme, SchwabStrategyPackage pkg) {
    final mark = pkg.effectiveMark;
    final isDebit = pkg.isDebit;
    final width = pkg.spreadWidth;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onPackageSelected != null
            ? () => widget.onPackageSelected!(pkg)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Strike title and Net Debit/Credit badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      pkg.strategyStrike ?? 'Custom Spread',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDebit
                          ? Colors.blue.withValues(alpha: 0.15)
                          : Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isDebit ? 'NET DEBIT' : 'NET CREDIT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDebit ? Colors.blue : Colors.teal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Pricing row: Bid / Ask / Mark
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mark: ${mark != null ? '\$${mark.toStringAsFixed(2)}' : 'N/A'}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Bid: ${pkg.effectiveBid?.toStringAsFixed(2) ?? '-'} · Ask: ${pkg.effectiveAsk?.toStringAsFixed(2) ?? '-'}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                  if (width != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Spread Width',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                        Text(
                          '\$${width.toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // Composite Greeks row if available
              if (pkg.delta != null ||
                  pkg.gamma != null ||
                  pkg.theta != null ||
                  pkg.vega != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (pkg.delta != null)
                        _buildGreekChip('Δ', pkg.delta!.toStringAsFixed(2)),
                      if (pkg.gamma != null)
                        _buildGreekChip('Γ', pkg.gamma!.toStringAsFixed(3)),
                      if (pkg.theta != null)
                        _buildGreekChip('Θ', pkg.theta!.toStringAsFixed(2)),
                      if (pkg.vega != null)
                        _buildGreekChip('V', pkg.vega!.toStringAsFixed(2)),
                    ],
                  ),
                ),
              ],

              // Constituent Legs breakdown
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 6),
              if (pkg.primaryLeg != null)
                _buildLegRow(theme, 'Primary Leg', pkg.primaryLeg!),
              if (pkg.secondaryLeg != null)
                _buildLegRow(theme, 'Secondary Leg', pkg.secondaryLeg!),
              for (int i = 0; i < pkg.additionalLegs.length; i++)
                _buildLegRow(theme, 'Leg ${i + 3}', pkg.additionalLegs[i]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreekChip(String symbol, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$symbol: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        Text(value, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildLegRow(ThemeData theme, String label, SchwabStrategyLeg leg) {
    final expFormatted = leg.expirationDate != null
        ? DateFormat('MM/dd').format(leg.expirationDate!)
        : '';
    final strikeStr = leg.strikePrice != null
        ? '\$${leg.strikePrice!.toStringAsFixed(1)}'
        : '';
    final markStr = leg.mark != null ? '\$${leg.mark!.toStringAsFixed(2)}' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: leg.putCall == 'CALL'
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  leg.putCall,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: leg.putCall == 'CALL' ? Colors.green : Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$strikeStr $expFormatted',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Text(
            markStr,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
