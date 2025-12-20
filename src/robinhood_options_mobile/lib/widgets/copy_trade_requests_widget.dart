import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/copy_trading_provider.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';

class CopyTradeRequestsWidget extends StatefulWidget {
  const CopyTradeRequestsWidget({super.key});

  @override
  State<CopyTradeRequestsWidget> createState() =>
      _CopyTradeRequestsWidgetState();
}

class _CopyTradeRequestsWidgetState extends State<CopyTradeRequestsWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedRequestIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _clearSelection();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedRequestIds.contains(id)) {
        _selectedRequestIds.remove(id);
      } else {
        _selectedRequestIds.add(id);
      }
      _isSelectionMode = _selectedRequestIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedRequestIds.clear();
      _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CopyTradingProvider>(context);

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              title: Text('${_selectedRequestIds.length} Selected'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              ),
              actions: [
                if (_tabController.index == 0) ...[
                  IconButton(
                    icon: const Icon(Icons.check),
                    tooltip: 'Approve Selected',
                    onPressed: () => _batchApprove(context, provider),
                  ),
                  IconButton(
                    icon: const Icon(Icons.block),
                    tooltip: 'Reject Selected',
                    onPressed: () => _batchReject(context, provider),
                  ),
                ]
              ],
            )
          : AppBar(
              title: const Text('Copy Trade Requests'),
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Pending'),
                  Tab(text: 'History'),
                ],
              ),
            ),
      body: StreamBuilder<List<CopyTradeRecord>>(
        stream: provider.getTradeHistory(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allRequests = snapshot.data ?? [];
          final pendingRequests =
              allRequests.where((r) => r.status == 'pending_approval').toList();
          final historyRequests =
              allRequests.where((r) => r.status != 'pending_approval').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildRequestList(context, pendingRequests, isPending: true),
              _buildRequestList(context, historyRequests, isPending: false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRequestList(BuildContext context, List<CopyTradeRecord> requests,
      {required bool isPending}) {
    if (requests.isEmpty) {
      return Center(
        child: Text(
          isPending ? 'No pending requests' : 'No history',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        final isSelected = _selectedRequestIds.contains(request.id);

        return Card(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2)
              : null,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onLongPress: isPending
                ? () => _toggleSelection(request.id)
                : null, // Only allow selection in pending tab
            onTap: _isSelectionMode && isPending
                ? () => _toggleSelection(request.id)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (_isSelectionMode && isPending)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                              ),
                            ),
                          Text(
                            request.symbol,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      _buildStatusChip(request.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${request.side.toUpperCase()} ${request.copiedQuantity.toStringAsFixed(0)} ${request.orderType == 'option' ? 'Contracts' : 'Shares'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (request.orderType == 'option' &&
                      request.legs != null) ...[
                    const SizedBox(height: 4),
                    ...request.legs!.map((leg) => Text(
                          '${leg.optionType?.toUpperCase()} ${DateFormat('MM/dd').format(leg.expirationDate!)} \$${leg.strikePrice}',
                          style: const TextStyle(color: Colors.grey),
                        )),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Price: \$${request.price.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'From: User ${request.sourceUserId.substring(0, 5)}...', // Ideally fetch user name
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    DateFormat('MMM d, h:mm a').format(request.timestamp),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  if (isPending && !_isSelectionMode) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _rejectRequest(context, request),
                          child: const Text('Reject'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _approveRequest(context, request),
                          child: const Text('Approve'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending_approval':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'approved':
        color = Colors.green;
        label = 'Approved';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejected';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _approveRequest(
      BuildContext context, CopyTradeRecord request) async {
    try {
      final provider = Provider.of<CopyTradingProvider>(context, listen: false);
      await provider.approveRequest(request);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request approved')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving request: $e')),
        );
      }
    }
  }

  Future<void> _rejectRequest(
      BuildContext context, CopyTradeRecord request) async {
    try {
      final provider = Provider.of<CopyTradingProvider>(context, listen: false);
      await provider.rejectRequest(request);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting request: $e')),
        );
      }
    }
  }

  Future<void> _batchApprove(
      BuildContext context, CopyTradingProvider provider) async {
    final selectedIds = _selectedRequestIds.toList();
    _clearSelection(); // Clear selection immediately

    int successCount = 0;
    try {
      // Fetch current requests to get objects
      final requests = await provider.getRequests().first;
      final selectedRequests =
          requests.where((r) => selectedIds.contains(r.id)).toList();

      for (final request in selectedRequests) {
        await provider.approveRequest(request);
        successCount++;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approved $successCount requests')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during batch approval: $e')),
        );
      }
    }
  }

  Future<void> _batchReject(
      BuildContext context, CopyTradingProvider provider) async {
    final selectedIds = _selectedRequestIds.toList();
    _clearSelection();

    int successCount = 0;
    try {
      final requests = await provider.getRequests().first;
      final selectedRequests =
          requests.where((r) => selectedIds.contains(r.id)).toList();

      for (final request in selectedRequests) {
        await provider.rejectRequest(request);
        successCount++;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rejected $successCount requests')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during batch rejection: $e')),
        );
      }
    }
  }
}
