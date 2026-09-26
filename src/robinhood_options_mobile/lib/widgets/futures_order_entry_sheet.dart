import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

class FuturesOrderEntrySheet extends StatefulWidget {
  final IBrokerageService service;
  final BrokerageUser brokerageUser;
  final String accountId;
  final String contractId;
  final String symbol;
  final double? positionQuantity;

  const FuturesOrderEntrySheet({
    super.key,
    required this.service,
    required this.brokerageUser,
    required this.accountId,
    required this.contractId,
    required this.symbol,
    this.positionQuantity,
  });

  @override
  State<FuturesOrderEntrySheet> createState() => _FuturesOrderEntrySheetState();
}

class _FuturesOrderEntrySheetState extends State<FuturesOrderEntrySheet> {
  final _quantityController = TextEditingController();
  final _limitPriceController = TextEditingController();
  late Future<double?> _quoteRequest;
  double? _quote;
  String? _quoteError;
  String? _orderError;
  String _side = 'BUY';
  String _openingSide = 'BUY';
  String _positionEffect = 'OPENING';
  String _orderType = 'MARKET';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _quoteRequest = _fetchQuote();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _limitPriceController.dispose();
    super.dispose();
  }

  Future<double?> _fetchQuote() async {
    try {
      final quote = await widget.service
          .getFuturesQuote(widget.brokerageUser, widget.contractId);
      if (quote == null || !quote.isFinite || quote <= 0) {
        throw const FormatException('No valid live quote is available.');
      }
      if (mounted) {
        setState(() => _quote = quote);
      }
      return quote;
    } catch (error) {
      if (mounted) {
        setState(() => _quoteError = error.toString());
      }
      rethrow;
    }
  }

  Future<void> _confirmAndSubmit() async {
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      setState(() => _orderError = 'Enter a positive whole-number quantity.');
      return;
    }
    if (_positionEffect == 'CLOSING' &&
        quantity > (widget.positionQuantity?.abs() ?? 0)) {
      setState(() {
        _orderError =
            'Closing quantity cannot exceed the ${widget.positionQuantity!.abs()} open contracts.';
      });
      return;
    }
    final limitPrice = _orderType == 'LIMIT'
        ? double.tryParse(_limitPriceController.text.trim())
        : null;
    if (_orderType == 'LIMIT' &&
        (limitPrice == null || !limitPrice.isFinite || limitPrice <= 0)) {
      setState(() => _orderError = 'Enter a valid limit price.');
      return;
    }
    if (_quote == null) {
      setState(
          () => _orderError = 'A live quote is required to place an order.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm futures order'),
        content: Text(
          '${_positionEffect == 'CLOSING' ? 'Close' : 'Open'} with '
          '${_side == 'BUY' ? 'Buy' : 'Sell'} $quantity ${widget.symbol} '
          '${_orderType.toLowerCase()} order.\n'
          '${_orderType == 'LIMIT' ? 'Limit price: \$${limitPrice!.toStringAsFixed(2)}\n' : ''}'
          'Latest quote: \$${_quote!.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-futures-order'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isSubmitting = true;
      _orderError = null;
    });
    try {
      await widget.service.placeFuturesOrder(
        widget.brokerageUser,
        widget.accountId,
        widget.contractId,
        _side,
        quantity,
        orderType: _orderType,
        limitPrice: limitPrice,
        timeInForce: 'GTC',
        positionEffect: _positionEffect,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _orderError = 'Order was not submitted: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trade ${widget.symbol}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<String>(
                        key: const ValueKey('futures-position-effect'),
                        segments: [
                          const ButtonSegment(
                              value: 'OPENING', label: Text('Open')),
                          if ((widget.positionQuantity?.abs() ?? 0) > 0)
                            const ButtonSegment(
                                value: 'CLOSING', label: Text('Close')),
                        ],
                        selected: {_positionEffect},
                        onSelectionChanged: _isSubmitting
                            ? null
                            : (selection) {
                                setState(() {
                                  _positionEffect = selection.first;
                                  _side = _positionEffect == 'CLOSING'
                                      ? (widget.positionQuantity! > 0
                                          ? 'SELL'
                                          : 'BUY')
                                      : _openingSide;
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'BUY', label: Text('Buy')),
                          ButtonSegment(value: 'SELL', label: Text('Sell')),
                        ],
                        selected: {_side},
                        onSelectionChanged:
                            _isSubmitting || _positionEffect == 'CLOSING'
                                ? null
                                : (selection) => setState(() {
                                      _side = selection.first;
                                      _openingSide = _side;
                                    }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<double?>(
              future: _quoteRequest,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (_quoteError != null) {
                  return Row(
                    children: [
                      Expanded(
                          child: Text('Live quote unavailable: $_quoteError')),
                      IconButton(
                        tooltip: 'Retry quote',
                        onPressed: _isSubmitting ||
                                snapshot.connectionState ==
                                    ConnectionState.waiting
                            ? null
                            : () {
                                setState(() {
                                  _quote = null;
                                  _quoteError = null;
                                  _quoteRequest = _fetchQuote();
                                });
                              },
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  );
                }
                return Text(
                  'Live quote: \$${_quote!.toStringAsFixed(2)}',
                  key: const ValueKey('futures-live-quote'),
                  style: Theme.of(context).textTheme.titleMedium,
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('futures-order-quantity'),
              controller: _quantityController,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Contracts',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('futures-order-type'),
              initialValue: _orderType,
              decoration: const InputDecoration(
                labelText: 'Order type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'MARKET', child: Text('Market')),
                DropdownMenuItem(value: 'LIMIT', child: Text('Limit')),
              ],
              onChanged: _isSubmitting
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _orderType = value;
                          _orderError = null;
                        });
                      }
                    },
            ),
            if (_orderType == 'LIMIT') ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('futures-order-limit-price'),
                controller: _limitPriceController,
                enabled: !_isSubmitting,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Limit price (USD)',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_orderError != null) ...[
              const SizedBox(height: 12),
              Text(
                _orderError!,
                key: const ValueKey('futures-order-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('review-futures-order'),
                onPressed:
                    _isSubmitting || _quote == null ? null : _confirmAndSubmit,
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('Review order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
