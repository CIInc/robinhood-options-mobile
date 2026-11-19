import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:robinhood_options_mobile/model/copy_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/copy_trade_risk_guardian_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

class CopyTradeRequestDetailWidget extends StatefulWidget {
  final CopyTradeRecord? record;
  final String? recordId;
  final String? symbol;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final FirebaseAnalytics? analytics;
  final FirebaseAnalyticsObserver? observer;
  final GenerativeService? generativeService;
  final User? user;
  final DocumentReference<User>? userDocRef;
  final List<OptionContractAdaptation>? initialAdaptations;
  final double? maxAllocationCap;

  const CopyTradeRequestDetailWidget({
    super.key,
    this.record,
    this.recordId,
    this.symbol,
    this.brokerageUser,
    this.service,
    this.analytics,
    this.observer,
    this.generativeService,
    this.user,
    this.userDocRef,
    this.initialAdaptations,
    this.maxAllocationCap,
  });

  @override
  State<CopyTradeRequestDetailWidget> createState() =>
      _CopyTradeRequestDetailWidgetState();
}

class _CopyTradeRequestDetailWidgetState
    extends State<CopyTradeRequestDetailWidget> {
  bool _isProcessing = false;
  List<OptionContractAdaptation> _adaptations = const [];
  OptionContractAdaptation? _selectedAdaptation;
  bool _loadingAdaptations = false;
  bool _loadedAdaptations = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAdaptations != null) {
      _adaptations = widget.initialAdaptations!;
      _loadedAdaptations = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.record != null) {
      return _buildScaffold(context, widget.record!);
    }

    if (widget.recordId != null && widget.recordId!.isNotEmpty) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('copy_trades')
            .doc(widget.recordId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Copy Trade Details')),
              body: Center(child: Text('Error: ${snapshot.error}')),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(title: const Text('Copy Trade Details')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildFallbackOrNotFound(context);
          }

          final record = CopyTradeRecord.fromDocument(snapshot.data!);
          return _buildScaffold(context, record);
        },
      );
    }

    // Fallback: search by symbol if provided
    return _buildFallbackOrNotFound(context);
  }

  Widget _buildFallbackOrNotFound(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && widget.symbol != null && widget.symbol!.isNotEmpty) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('copy_trades')
            .where('targetUserId', isEqualTo: uid)
            .where('symbol', isEqualTo: widget.symbol)
            .where('status', isEqualTo: 'pending_approval')
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(
                title: Text('Copy Trade: ${widget.symbol}'),
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final record =
                CopyTradeRecord.fromDocument(snapshot.data!.docs.first);
            return _buildScaffold(context, record);
          }
          return _buildNotFoundView(context);
        },
      );
    }
    return _buildNotFoundView(context);
  }

  Widget _buildNotFoundView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Copy Trade Details'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.find_in_page_outlined,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Request Not Found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This copy trade request may have already been executed, rejected, or expired.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Requests'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, CopyTradeRecord record) {
    final dateFormat = DateFormat('MMM d, y h:mm a');
    final currencyFormat = NumberFormat.simpleCurrency();
    final isOption = record.orderType == 'option';
    final isPending = record.status == 'pending_approval';
    final isBuy = record.side.toLowerCase() == 'buy' ||
        record.side.toLowerCase() == 'debit';
    final sideColor = isBuy ? Colors.green : Colors.orange;
    final totalEstimatedValue =
        record.copiedQuantity * record.price * (isOption ? 100 : 1);
    final inverseGuardrail =
        CopyTradeRiskGuardianService.evaluateInverseOptionGuardrail(
      record: record,
    );
    final needsAdaptation = isOption &&
        (record.needsContractAdaptation || record.copiedQuantity < 1);
    if (isPending &&
        needsAdaptation &&
        !_loadedAdaptations &&
        !_loadingAdaptations &&
        widget.service != null &&
        widget.brokerageUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadOptionAdaptations(record);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${record.symbol} Copy ${isOption ? 'Option' : 'Trade'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart),
            tooltip: 'View ${record.symbol} Chart',
            onPressed: () => _navigateToInstrument(context, record.symbol),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Summary Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.symbol,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isOption ? 'Option Contract' : 'Stock / Equity',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildStatusChip(record.status),
                            if (record.isInverse) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.purple),
                                ),
                                child: const Text(
                                  'Inverse Trade',
                                  style: TextStyle(
                                    color: Colors.purple,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          'Action',
                          record.side.toUpperCase(),
                          valueColor: sideColor,
                        ),
                        _buildStatColumn(
                          isOption ? 'Contracts' : 'Quantity',
                          record.copiedQuantity.toStringAsFixed(0),
                        ),
                        _buildStatColumn(
                          'Signal Price',
                          currencyFormat.format(record.price),
                        ),
                        _buildStatColumn(
                          'Est. Total',
                          currencyFormat.format(totalEstimatedValue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Option Legs Details (if option)
            if (isOption && record.legs != null && record.legs!.isNotEmpty) ...[
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.layers,
                              size: 20, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Option Legs (${record.legs!.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (record.strategy != null) ...[
                            const Spacer(),
                            Text(
                              record.strategy!.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...record.legs!.map((leg) {
                        final legSide = leg.side?.toUpperCase() ?? 'BUY';
                        final legType = leg.optionType?.toUpperCase() ?? 'CALL';
                        final expStr = leg.expirationDate != null
                            ? DateFormat('MM/dd/yyyy')
                                .format(leg.expirationDate!)
                            : 'N/A';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: legSide == 'BUY'
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      legSide,
                                      style: TextStyle(
                                        color: legSide == 'BUY'
                                            ? Colors.green
                                            : Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$legType \$${leg.strikePrice?.toStringAsFixed(2) ?? "0.00"}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              Text(
                                'Exp: $expStr',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Leader & Source Info Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person_pin, size: 20, color: Colors.indigo),
                        SizedBox(width: 8),
                        Text(
                          'Leader & Signal Source',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Leader',
                      record.sourceUserName ??
                          (record.sourceUserId.length > 8
                              ? '${record.sourceUserId.substring(0, 8)}...'
                              : record.sourceUserId),
                    ),
                    _buildDetailRow(
                        'Signal Time', dateFormat.format(record.timestamp)),
                    _buildDetailRow(
                      'Original Leader Qty',
                      '${record.originalQuantity.toStringAsFixed(0)} ${isOption ? "contracts" : "shares"}',
                    ),
                    if (record.originalOrderId.isNotEmpty)
                      _buildDetailRow(
                          'Leader Order ID', record.originalOrderId),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Execution / Audit Details (if executed, approved, or error)
            if (record.executed ||
                record.executionResult != null ||
                record.error != null) ...[
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.fact_check, size: 20, color: Colors.teal),
                          SizedBox(width: 8),
                          Text(
                            'Execution Audit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (record.executionTime != null)
                        _buildDetailRow(
                          'Execution Time',
                          dateFormat.format(record.executionTime!),
                        ),
                      if (record.executedPrice != null)
                        _buildDetailRow(
                          'Fill Price',
                          currencyFormat.format(record.executedPrice!),
                        ),
                      if (record.effectiveFillLatencyMs != null)
                        _buildDetailRow(
                          'Fill Latency',
                          '${record.effectiveFillLatencyMs} ms',
                        ),
                      if (record.executed)
                        _buildDetailRow(
                          'Price Slippage',
                          '${record.dollarSlippage >= 0 ? "+" : ""}${currencyFormat.format(record.dollarSlippage)} (${record.effectiveSlippageBps >= 0 ? "+" : ""}${record.effectiveSlippageBps.toStringAsFixed(1)} bps)',
                        ),
                      if (record.executionResult != null)
                        _buildDetailRow(
                          'Execution Result',
                          record.executionResult!,
                        ),
                      if (record.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    record.error!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Defined-Risk Inverse Option Guardrail Banner
            if (isOption &&
                record.isInverse &&
                (!inverseGuardrail.isAllowed ||
                    record.inverseAdaptation != null)) ...[
              _buildInverseGuardrailCard(context, record, inverseGuardrail),
              const SizedBox(height: 16),
            ],

            // Small-Account Option Contract Adapter Card
            if (isPending && needsAdaptation) ...[
              _buildContractAdapterCard(context, record, currencyFormat),
              const SizedBox(height: 16),
            ],

            // Action Buttons for Pending Requests
            if (isPending) ...[
              const SizedBox(height: 8),
              if (_isProcessing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                ElevatedButton.icon(
                  onPressed: (!inverseGuardrail.isAllowed ||
                          (needsAdaptation && _selectedAdaptation == null))
                      ? null
                      : () => _handleApprove(record),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    _selectedAdaptation != null
                        ? 'Approve Adapted Trade'
                        : 'Approve Request',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _handleReject(record),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Reject Request'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _navigateToInstrument(context, record.symbol),
              icon: const Icon(Icons.candlestick_chart),
              label: Text('Inspect ${record.symbol} Chart & Fundamentals'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, {Color? valueColor}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending_approval':
        color = Colors.orange;
        label = 'Pending Approval';
        break;
      case 'approved':
        color = Colors.green;
        label = 'Approved';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejected';
        break;
      case 'executed':
        color = Colors.blue;
        label = 'Executed';
        break;
      case 'aborted':
        color = Colors.red.shade700;
        label = 'Aborted';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _handleApprove(CopyTradeRecord record) async {
    setState(() => _isProcessing = true);
    try {
      // RiskGuard Check
      final accountStore = Provider.of<AccountStore>(context, listen: false);
      final agenticProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      final portfolioState = <String, dynamic>{};
      if (accountStore.items.isNotEmpty) {
        final buyingPower = accountStore.items[0].buyingPower ??
            accountStore.items[0].portfolioCash ??
            0.0;
        portfolioState['buyingPower'] = buyingPower;
        portfolioState['cashAvailable'] = accountStore.items[0].portfolioCash;
      }

      final effectiveQuantity =
          _selectedAdaptation != null ? 1.0 : record.copiedQuantity;
      final effectivePrice =
          _selectedAdaptation?.estimatedPrice ?? record.price;

      final riskResult =
          await FirebaseFunctions.instance.httpsCallable('riskguardTask').call({
        'proposal': {
          'symbol': record.symbol,
          'quantity': effectiveQuantity,
          'price': effectivePrice,
          'action': record.side.toUpperCase(),
          'multiplier': record.orderType == 'option' ? 100 : 1,
        },
        'portfolioState': portfolioState,
        'config': agenticProvider.config.toRiskGuardConfig(),
      });

      if (riskResult.data['approved'] == false) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('RiskGuard Warning'),
            content: Text(
                riskResult.data['reason'] ?? 'Trade rejected by RiskGuard.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Proceed Anyway'),
              ),
            ],
          ),
        );

        if (proceed != true) {
          if (mounted) {
            setState(() => _isProcessing = false);
          }
          return;
        }
      }

      if (!mounted) return;
      final provider = Provider.of<CopyTradingProvider>(context, listen: false);
      if (_selectedAdaptation != null) {
        await provider.approveAdaptedRequest(record, _selectedAdaptation!);
      } else {
        await provider.approveRequest(record);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copy trade request approved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _loadOptionAdaptations(CopyTradeRecord record) async {
    if (_loadingAdaptations || _loadedAdaptations) return;
    setState(() => _loadingAdaptations = true);
    try {
      final service = widget.service;
      final user = widget.brokerageUser;
      final legs = record.legs;
      if (service == null || user == null || legs == null || legs.isEmpty) {
        return;
      }

      final instrumentStore =
          Provider.of<InstrumentStore>(context, listen: false);
      final optionInstrumentStore =
          Provider.of<OptionInstrumentStore>(context, listen: false);
      final instrument = await service.getInstrumentBySymbol(
          user, instrumentStore, record.symbol);
      if (instrument == null) return;

      final leg = legs.first;
      final expStr = leg.expirationDate?.toIso8601String().substring(0, 10);
      final chain = await service
          .streamOptionInstruments(
            user,
            optionInstrumentStore,
            instrument,
            expStr,
            leg.optionType,
          )
          .first;

      if (chain.isNotEmpty) {
        final mdList = await service.getOptionMarketDataByIds(
          user,
          chain.map((e) => e.id).take(30).toList(),
        );
        final mdById = {for (final m in mdList) m.instrumentId: m};
        for (final opt in chain) {
          opt.optionMarketData ??= mdById[opt.id];
        }
      }

      final cap = widget.maxAllocationCap ??
          (record.price > 0 ? record.price * 100.0 * 0.75 : 250.0);
      final suggestions = CopyTradeRiskGuardianService.suggestOptionAdaptations(
        record: record,
        maxAllocationAmount: cap,
        chain: chain,
      );
      if (mounted) {
        setState(() {
          _adaptations = suggestions;
          if (suggestions.isNotEmpty) {
            _selectedAdaptation = suggestions.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load option contract adaptations: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingAdaptations = false;
          _loadedAdaptations = true;
        });
      }
    }
  }

  Widget _buildInverseGuardrailCard(
    BuildContext context,
    CopyTradeRecord record,
    InverseOptionGuardrailResult guardrail,
  ) {
    final blocked = !guardrail.isAllowed;
    final color = blocked ? Colors.red : Colors.purple;
    final title = blocked
        ? 'Naked Short Option Blocked'
        : 'Defined-Risk Inverse Guardrail Active';
    final body = blocked
        ? (guardrail.blockReason ??
            'Inverse copy mode cannot open naked short options. Convert to a defined-risk opposite long option before approving.')
        : 'Inverse copy mode mapped this trade to a defined-risk opposite-direction long option to cap downside risk.';

    return Semantics(
      label: '$title. $body',
      child: Card(
        color: color.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    blocked ? Icons.shield_outlined : Icons.verified_user,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(body, style: const TextStyle(fontSize: 13)),
              if (blocked && guardrail.suggestedDefinedRiskRecord != null) ...[
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          final provider = Provider.of<CopyTradingProvider>(
                              context,
                              listen: false);
                          await provider.applyDefinedRiskInverse(
                            record,
                            guardrail.suggestedDefinedRiskRecord!,
                          );
                        },
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Convert to Defined-Risk'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContractAdapterCard(
    BuildContext context,
    CopyTradeRecord record,
    NumberFormat currencyFormat,
  ) {
    return Semantics(
      label: 'Small-account option contract adapter',
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.amber.shade700.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune, color: Colors.amber.shade800, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Contract Adapter (Capital Cap)',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '1 original contract (${currencyFormat.format(record.price * 100)}) exceeds your per-trade cap. Select a smaller-risk alternative:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              if (_loadingAdaptations)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_adaptations.isEmpty)
                const Text(
                  'No liquid strikes or spreads within your capital cap were found for this expiration.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                )
              else
                ..._adaptations.map((opt) {
                  final selected = _selectedAdaptation == opt;
                  return Semantics(
                    selected: selected,
                    label: '${opt.title}. ${opt.subtitle}',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAdaptation = opt;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.35)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    opt.subtitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleReject(CopyTradeRecord record) async {
    setState(() => _isProcessing = true);
    try {
      final provider = Provider.of<CopyTradingProvider>(context, listen: false);
      await provider.rejectRequest(record);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copy trade request rejected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _navigateToInstrument(
      BuildContext navContext, String symbol) async {
    try {
      final userStore =
          Provider.of<BrokerageUserStore>(navContext, listen: false);
      final instrumentStore =
          Provider.of<InstrumentStore>(navContext, listen: false);
      final brokerageUser = widget.brokerageUser ??
          userStore.currentUser ??
          userStore.items.firstOrNull;

      if (brokerageUser != null && widget.service != null) {
        final instrument = await widget.service!
            .getInstrumentBySymbol(brokerageUser, instrumentStore, symbol);
        if (instrument != null && navContext.mounted) {
          Navigator.push(
            navContext,
            MaterialPageRoute(
              builder: (context) => InstrumentWidget(
                brokerageUser,
                widget.service!,
                instrument,
                analytics: widget.analytics ?? FirebaseAnalytics.instance,
                observer: widget.observer ??
                    FirebaseAnalyticsObserver(
                        analytics: FirebaseAnalytics.instance),
                generativeService:
                    widget.generativeService ?? GenerativeService(),
                user: widget.user,
                userDocRef: widget.userDocRef,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error navigating to instrument: $e');
    }
  }
}
