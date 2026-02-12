import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/group_watchlist_models.dart';
import 'package:robinhood_options_mobile/model/user.dart'; // Added import
import 'package:robinhood_options_mobile/services/group_watchlist_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart'; // Added import
import 'package:robinhood_options_mobile/services/home_widget_service.dart';

enum SortOption { nameAsc, nameDesc, dateAdded, dateAddedDesc }

class GroupWatchlistDetailWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final String groupId;
  final String watchlistId;

  const GroupWatchlistDetailWidget({
    super.key,
    required this.brokerageUser,
    required this.groupId,
    required this.watchlistId,
  });

  @override
  State<GroupWatchlistDetailWidget> createState() =>
      _GroupWatchlistDetailWidgetState();
}

class _GroupWatchlistDetailWidgetState
    extends State<GroupWatchlistDetailWidget> {
  final GroupWatchlistService _service = GroupWatchlistService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  SortOption _sortOption = SortOption.dateAddedDesc;
  bool _showOnlyActive = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Watchlist'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Symbols'),
              Tab(text: 'Alerts'),
              Tab(text: 'Settings'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSymbolsTab(),
            _buildAlertsTab(),
            _buildSettingsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSymbolsTab() {
    return StreamBuilder<GroupWatchlist?>(
      stream: _service.getWatchlistStream(
        groupId: widget.groupId,
        watchlistId: widget.watchlistId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('Symbols');
        }

        if (snapshot.hasError) {
          return _buildErrorState('symbols', snapshot.error.toString());
        }

        final watchlist = snapshot.data;
        if (watchlist == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Watchlist not found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('This watchlist may have been deleted.'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final isEditor = _isEditor(watchlist);
        var symbols = watchlist.symbols;

        // Filter by search
        if (_searchController.text.isNotEmpty) {
          symbols = symbols
              .where((s) => s.symbol
                  .toUpperCase()
                  .contains(_searchController.text.toUpperCase()))
              .toList();
        }

        // Sort
        symbols = _sortSymbols(symbols);

        return Column(
          children: [
            // Search bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search symbols...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (symbols.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<SortOption>(
                      icon: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.sort, size: 24),
                      ),
                      tooltip: 'Sort symbols',
                      onSelected: (option) =>
                          setState(() => _sortOption = option),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: SortOption.nameAsc,
                          child: const Text('Name (A-Z)'),
                        ),
                        PopupMenuItem(
                          value: SortOption.nameDesc,
                          child: const Text('Name (Z-A)'),
                        ),
                        PopupMenuItem(
                          value: SortOption.dateAdded,
                          child: const Text('Oldest First'),
                        ),
                        PopupMenuItem(
                          value: SortOption.dateAddedDesc,
                          child: const Text('Newest First'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Action bar
            if (isEditor)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddSymbolDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Symbol'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // Symbols list or empty state
            Expanded(
              child: symbols.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _searchController.text.isNotEmpty
                                    ? Icons.search_off
                                    : Icons.bookmark_outline,
                                size: 48,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No symbols found'
                                  : 'No Symbols Yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Try adjusting your search'
                                  : 'Add symbols to start tracking',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            if (isEditor && _searchController.text.isEmpty) ...[
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => _showAddSymbolDialog(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Symbol'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: symbols.length,
                      itemBuilder: (context, index) {
                        final symbol = symbols[index];
                        final alertCount = symbol.alerts.length;
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        final borderColor =
                            isDark ? Colors.grey[700]! : Colors.grey[200]!;

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: borderColor, width: 1),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              // Could navigate to symbol details in future
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      symbol.symbol.isNotEmpty
                                          ? symbol.symbol[0]
                                          : '?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          symbol.symbol,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            if (symbol.addedBy.isNotEmpty)
                                              FutureBuilder<
                                                  DocumentSnapshot<User>>(
                                                future: _firestoreService
                                                    .userCollection
                                                    .doc(symbol.addedBy)
                                                    .get(),
                                                builder: (context, snapshot) {
                                                  if (!snapshot.hasData ||
                                                      !snapshot.data!.exists) {
                                                    return const SizedBox
                                                        .shrink();
                                                  }
                                                  final user =
                                                      snapshot.data!.data();
                                                  final name =
                                                      user?.name ?? 'Unknown';
                                                  return Text(
                                                    'Added by $name',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontSize: 11,
                                                          color:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.color
                                                                  ?.withOpacity(
                                                                      0.7),
                                                        ),
                                                  );
                                                },
                                              ),
                                            if (alertCount > 0)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Colors.orange[900]!
                                                          .withOpacity(0.3)
                                                      : Colors.orange[100]!,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .notifications_active,
                                                      size: 10,
                                                      color: isDark
                                                          ? Colors.orange[400]!
                                                          : Colors.orange[800]!,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '$alertCount alert${alertCount > 1 ? 's' : ''}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: isDark
                                                            ? Colors
                                                                .orange[400]!
                                                            : Colors
                                                                .orange[800]!,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isEditor)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () {
                                        _showDeleteSymbolConfirmation(
                                            context, symbol.symbol);
                                      },
                                      tooltip: 'Remove symbol',
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  List<WatchlistSymbol> _sortSymbols(List<WatchlistSymbol> symbols) {
    switch (_sortOption) {
      case SortOption.nameAsc:
        return symbols..sort((a, b) => a.symbol.compareTo(b.symbol));
      case SortOption.nameDesc:
        return symbols..sort((a, b) => b.symbol.compareTo(a.symbol));
      case SortOption.dateAdded:
        return symbols..sort((a, b) => a.addedAt.compareTo(b.addedAt));
      case SortOption.dateAddedDesc:
        return symbols..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    }
  }

  Widget _buildAlertsTab() {
    return StreamBuilder<GroupWatchlist?>(
      stream: _service.getWatchlistStream(
        groupId: widget.groupId,
        watchlistId: widget.watchlistId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('Alerts');
        }

        if (snapshot.hasError) {
          return _buildErrorState('alerts', snapshot.error.toString());
        }

        final watchlist = snapshot.data;
        if (watchlist == null) {
          return const Center(child: Text('Watchlist not found'));
        }

        final isEditor = _isEditor(watchlist);
        final symbols = watchlist.symbols;

        // Get all alerts and count by status
        final allAlerts = <WatchlistAlert>[];
        for (final symbol in symbols) {
          allAlerts.addAll(symbol.alerts);
        }

        final activeAlerts = allAlerts.where((a) => a.active).toList();
        final inactiveAlerts = allAlerts.where((a) => !a.active).toList();

        return symbols.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.notifications_none,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Symbols to Alert On',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add symbols to this watchlist to set price alerts',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  // Alert summary
                  if (allAlerts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          _buildAlertStatCard(
                            icon: Icons.check_circle,
                            label: 'Active',
                            count: activeAlerts.length,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _buildAlertStatCard(
                            icon: Icons.pause_circle,
                            label: 'Inactive',
                            count: inactiveAlerts.length,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          _buildAlertStatCard(
                            icon: Icons.notifications_active,
                            label: 'Total',
                            count: allAlerts.length,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  // Filter toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilterChip(
                            label: const Text('Show All'),
                            selected: !_showOnlyActive,
                            onSelected: (val) =>
                                setState(() => _showOnlyActive = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilterChip(
                            label: const Text('Active Only'),
                            selected: _showOnlyActive,
                            onSelected: (val) =>
                                setState(() => _showOnlyActive = true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Alerts list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: symbols.length,
                      itemBuilder: (context, index) {
                        final symbol = symbols[index];
                        final symbolAlerts = _showOnlyActive
                            ? symbol.alerts.where((a) => a.active).toList()
                            : symbol.alerts;

                        if (symbolAlerts.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[850]
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            child: ExpansionTile(
                              subtitle: symbol.addedBy.isNotEmpty
                                  ? FutureBuilder<DocumentSnapshot<User>>(
                                      future: _firestoreService.userCollection
                                          .doc(symbol.addedBy)
                                          .get(),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData ||
                                            !snapshot.data!.exists) {
                                          return const SizedBox.shrink();
                                        }
                                        final user = snapshot.data!.data();
                                        final name = user?.name ?? 'Unknown';
                                        return Text(
                                          'Added by $name',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        );
                                      },
                                    )
                                  : null,
                              title: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      symbol.symbol[0],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(symbol.symbol),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${symbolAlerts.length}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ...symbolAlerts
                                          .map((alert) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              4),
                                                      decoration: BoxDecoration(
                                                        color: alert.active
                                                            ? Colors.green
                                                                .withOpacity(
                                                                    0.1)
                                                            : Colors.grey
                                                                .withOpacity(
                                                                    0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(3),
                                                      ),
                                                      child: Icon(
                                                        alert.active
                                                            ? Icons.check_circle
                                                            : Icons
                                                                .pause_circle,
                                                        size: 16,
                                                        color: alert.active
                                                            ? Colors.green
                                                            : Colors.grey,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            alert.type ==
                                                                    'price_above'
                                                                ? 'Price above \$${alert.threshold.toStringAsFixed(2)}'
                                                                : 'Price below \$${alert.threshold.toStringAsFixed(2)}',
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .labelMedium,
                                                          ),
                                                          const SizedBox(
                                                              height: 2),
                                                          Text(
                                                            alert.active
                                                                ? 'Active'
                                                                : 'Inactive',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: alert
                                                                      .active
                                                                  ? Colors.green
                                                                  : Colors.grey,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (isEditor)
                                                      IconButton(
                                                        icon: const Icon(Icons
                                                            .delete_outline),
                                                        onPressed: () {
                                                          _showDeleteAlertConfirmation(
                                                            context,
                                                            symbol.symbol,
                                                            alert.id,
                                                          );
                                                        },
                                                        iconSize: 20,
                                                        color: Colors.red[600],
                                                      ),
                                                  ],
                                                ),
                                              ))
                                          ,
                                      if (isEditor) ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              _showAddAlertDialog(
                                                  context, symbol.symbol);
                                            },
                                            icon: const Icon(Icons.add),
                                            label: const Text('Add Alert'),
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
                      },
                    ),
                  ),
                ],
              );
      },
    );
  }

  Widget _buildSettingsTab() {
    return StreamBuilder<GroupWatchlist?>(
      stream: _service.getWatchlistStream(
        groupId: widget.groupId,
        watchlistId: widget.watchlistId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('Settings');
        }

        if (snapshot.hasError) {
          return _buildErrorState('settings', snapshot.error.toString());
        }

        final watchlist = snapshot.data;
        if (watchlist == null) {
          return const Center(child: Text('Watchlist not found'));
        }

        final userId =
            firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
        final isCreator = watchlist.createdBy == userId;
        final isEditor = _isEditor(watchlist);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Watchlist Info Section
              Text(
                'Watchlist Details',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[850]
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSettingsRow('Name', watchlist.name, Icons.bookmark),
                    _buildSettingsDivider(),
                    FutureBuilder<DocumentSnapshot<User>>(
                      future: _firestoreService.userCollection
                          .doc(watchlist.createdBy)
                          .get(),
                      builder: (context, snapshot) {
                        final name = snapshot.data?.data()?.name ?? 'Unknown';
                        return _buildSettingsRow(
                            'Created By', name, Icons.person_outline);
                      },
                    ),
                    if (watchlist.description.isNotEmpty) ...[
                      _buildSettingsDivider(),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        watchlist.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Members Section,
              if (isCreator || isEditor) ...[
                ..._buildMembersSection(
                    context, isCreator, watchlist, userId, userId),
                const SizedBox(height: 32),
                _buildActionsSection(context, watchlist, isCreator),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemberTile(
    BuildContext context,
    String memberId,
    String role,
    bool isCreator,
    String currentUserId,
    String watchlistCreator,
  ) {
    final isCurrentUser = memberId == currentUserId;
    final bgColor = isCurrentUser
        ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.white);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentUser
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).dividerColor,
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                Icons.person_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<DocumentSnapshot<User>>(
                  future: _firestoreService.userCollection.doc(memberId).get(),
                  builder: (context, snapshot) {
                    String displayName = memberId;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      displayName = snapshot.data!.data()?.name ?? memberId;
                    }

                    return Text(
                      isCurrentUser ? '$displayName (You)' : displayName,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
                const SizedBox(height: 2),
                _buildRoleBadge(role),
              ],
            ),
          ),
          if (!isCurrentUser && isCreator && role != 'creator')
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'remove') {
                  _showRemoveMemberConfirmation(context, memberId);
                } else {
                  _showPermissionChangeConfirmation(
                    context,
                    memberId,
                    value,
                    role,
                  );
                }
              },
              itemBuilder: (context) => [
                if (role != 'editor')
                  const PopupMenuItem(
                    value: 'editor',
                    child: Text('Promote to Editor'),
                  ),
                if (role != 'viewer')
                  const PopupMenuItem(
                    value: 'viewer',
                    child: Text('Demote to Viewer'),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text(
                    'Remove Member',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
              child: Icon(
                Icons.more_vert,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        color: Theme.of(context).dividerColor,
        height: 1,
      ),
    );
  }

  bool _isEditor(GroupWatchlist watchlist) {
    final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    return watchlist.permissions[userId] == 'editor' ||
        watchlist.createdBy == userId;
  }

  Widget _buildLoadingState(String section) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading $section...',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String section, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red[700],
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load $section',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertStatCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color getColorForRole() {
      switch (role) {
        case 'creator':
          return Colors.purple;
        case 'editor':
          return Theme.of(context).colorScheme.primary;
        default:
          return Colors.grey;
      }
    }

    String getRoleLabel() {
      switch (role) {
        case 'creator':
          return 'Creator';
        case 'editor':
          return 'Editor';
        default:
          return 'Viewer';
      }
    }

    final color = getColorForRole();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Text(
        getRoleLabel(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _showAddSymbolDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Symbol'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Symbol (e.g., AAPL)',
            hintText: 'Enter stock symbol',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _addSymbol(context, controller.text.toUpperCase());
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteSymbolConfirmation(BuildContext context, String symbol) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_outlined,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.amber[400]
              : Colors.amber[700],
          size: 32,
        ),
        title: const Text('Delete Symbol'),
        content: Text('Remove "$symbol" from this watchlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeSymbol(context, symbol);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAlertConfirmation(
    BuildContext context,
    String symbol,
    String alertId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_outlined,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.amber[400]
              : Colors.amber[700],
          size: 32,
        ),
        title: const Text('Delete Alert'),
        content: Text('Remove the price alert for $symbol?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAlert(context, symbol, alertId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSymbol(BuildContext context, String symbol) async {
    if (symbol.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final functions = FirebaseFunctions.instance;
      await functions.httpsCallable('addSymbolToWatchlist').call({
        'groupId': widget.groupId,
        'watchlistId': widget.watchlistId,
        'symbol': symbol,
      });

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Added $symbol to watchlist')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    }
  }

  Future<void> _removeSymbol(BuildContext context, String symbol) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final functions = FirebaseFunctions.instance;
      await functions.httpsCallable('removeSymbolFromWatchlist').call({
        'groupId': widget.groupId,
        'watchlistId': widget.watchlistId,
        'symbol': symbol,
      });

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Removed $symbol from watchlist')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    }
  }

  void _showAddAlertDialog(BuildContext context, String symbol) {
    final thresholdController = TextEditingController();
    String selectedType = 'price_above';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Price Alert'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Symbol: $symbol'),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: selectedType,
                items: const [
                  DropdownMenuItem(
                    value: 'price_above',
                    child: Text('Price above'),
                  ),
                  DropdownMenuItem(
                    value: 'price_below',
                    child: Text('Price below'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => selectedType = value ?? 'price_above');
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: thresholdController,
                decoration: const InputDecoration(
                  labelText: 'Price Threshold',
                  hintText: 'Enter price',
                  prefixText: '\$',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _createAlert(
                  context,
                  symbol,
                  selectedType,
                  double.tryParse(thresholdController.text) ?? 0,
                );
                Navigator.of(context).pop();
              },
              child: const Text('Create Alert'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAlert(
    BuildContext context,
    String symbol,
    String type,
    double threshold,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final functions = FirebaseFunctions.instance;
      await functions.httpsCallable('createPriceAlert').call({
        'groupId': widget.groupId,
        'watchlistId': widget.watchlistId,
        'symbol': symbol,
        'type': type,
        'threshold': threshold,
      });

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Alert created')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    }
  }

  Future<void> _deleteAlert(
    BuildContext context,
    String symbol,
    String alertId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final functions = FirebaseFunctions.instance;
      await functions.httpsCallable('deletePriceAlert').call({
        'groupId': widget.groupId,
        'watchlistId': widget.watchlistId,
        'symbol': symbol,
        'alertId': alertId,
      });

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Alert deleted')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    }
  }

  Future<void> _setMemberPermission(
    BuildContext context,
    String memberId,
    String permission,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final functions = FirebaseFunctions.instance;
      await functions.httpsCallable('setWatchlistMemberPermission').call({
        'groupId': widget.groupId,
        'watchlistId': widget.watchlistId,
        'memberId': memberId,
        'permission': permission,
      });

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Permission updated to $permission')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    }
  }

  void _showPermissionChangeConfirmation(
    BuildContext context,
    String memberId,
    String newRole,
    String currentRole,
  ) {
    final roleLabel = newRole == 'editor' ? 'Editor' : 'Viewer';
    final description = newRole == 'editor'
        ? 'Editors can add, remove, and manage symbols and alerts'
        : 'Viewers can only view the watchlist';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.info_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 32,
        ),
        title: Text('Change Role to $roleLabel?'),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _setMemberPermission(context, memberId, newRole);
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showRemoveMemberConfirmation(
    BuildContext context,
    String memberId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_outlined,
          color: Colors.orange[700],
          size: 32,
        ),
        title: const Text('Remove Member?'),
        content: Text(
          'Are you sure you want to remove $memberId from this watchlist? They will no longer have access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeMember(context, memberId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(
    BuildContext context,
    String memberId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final functions = FirebaseFunctions.instance;
      await functions.httpsCallable('removeWatchlistMember').call({
        'groupId': widget.groupId,
        'watchlistId': widget.watchlistId,
        'memberId': memberId,
      });

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Removed $memberId from watchlist')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    }
  }

  List<Widget> _buildMembersSection(
    BuildContext context,
    bool isCreator,
    GroupWatchlist watchlist,
    String userId,
    String currentUserId,
  ) {
    return [
      Text(
        'Members',
        style: Theme.of(context)
            .textTheme
            .headlineSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      Text(
        'Manage who has access to this watchlist',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
      ),
      const SizedBox(height: 16),
      _buildRoleInfoCards(),
      const SizedBox(height: 16),
      FutureBuilder<List<String>>(
        future: _getGroupMembers(),
        builder: (context, memberSnapshot) {
          if (memberSnapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            );
          }

          if (memberSnapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Failed to load members',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }

          final groupMembers = memberSnapshot.data ?? [];
          if (groupMembers.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No group members',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }

          // Sort members: creator first, then editors, then viewers
          final sortedMembers = List<String>.from(groupMembers);
          sortedMembers.sort((a, b) {
            final aIsCreator = a == watchlist.createdBy;
            final bIsCreator = b == watchlist.createdBy;
            if (aIsCreator != bIsCreator) {
              return aIsCreator ? -1 : 1;
            }

            final aIsEditor = watchlist.permissions[a] == 'editor';
            final bIsEditor = watchlist.permissions[b] == 'editor';
            if (aIsEditor != bIsEditor) {
              return aIsEditor ? -1 : 1;
            }

            return a.compareTo(b);
          });

          return Column(
            children: sortedMembers
                .map((memberId) => _buildMemberTile(
                      context,
                      memberId,
                      memberId == watchlist.createdBy
                          ? 'creator'
                          : (watchlist.permissions[memberId] ?? 'viewer'),
                      isCreator,
                      userId,
                      watchlist.createdBy,
                    ))
                .toList(),
          );
        },
      ),
    ];
  }

  Widget _buildRoleInfoCards() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        children: [
          _buildRoleInfoRow(
            role: 'Creator',
            icon: Icons.admin_panel_settings,
            color: Colors.purple,
            description: 'Full control. Can manage all settings and members.',
          ),
          const SizedBox(height: 12),
          _buildRoleInfoRow(
            role: 'Editor',
            icon: Icons.edit,
            color: Theme.of(context).colorScheme.primary,
            description: 'Can add, remove, and manage symbols and alerts.',
          ),
          const SizedBox(height: 12),
          _buildRoleInfoRow(
            role: 'Viewer',
            icon: Icons.visibility,
            color: Colors.grey,
            description: 'Read-only access. Cannot make changes.',
          ),
        ],
      ),
    );
  }

  Widget _buildRoleInfoRow({
    required String role,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<List<String>> _getGroupMembers() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('investor_groups')
          .doc(widget.groupId)
          .get();

      if (!doc.exists) {
        return [];
      }

      final data = doc.data();
      if (data == null) {
        return [];
      }

      final members = data['members'] as List<dynamic>?;
      if (members == null) {
        return [];
      }

      return members.cast<String>();
    } catch (e) {
      debugPrint('Error fetching group members: $e');
      return [];
    }
  }

  Widget _buildActionsSection(
    BuildContext context,
    GroupWatchlist watchlist,
    bool isCreator,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'Manage this watchlist',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[900]
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.widgets_outlined,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                title: const Text('Set as Widget Watchlist'),
                subtitle: const Text('Display this watchlist on home screen'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _setAsWidgetWatchlist(context, watchlist),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor,
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.clear_outlined,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                title: const Text('Clear Widget Watchlist'),
                subtitle: const Text('Remove watchlist from home screen'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _clearWidgetWatchlist(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor,
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: const Text('Edit Details'),
                subtitle: const Text('Change name and description'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _showEditDialog(context, watchlist),
              ),
              if (isCreator) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Delete Watchlist',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text('Permanently remove this watchlist'),
                  onTap: () => _showDeleteConfirmation(context, watchlist),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, GroupWatchlist watchlist) {
    final nameController = TextEditingController(text: watchlist.name);
    final descController = TextEditingController(text: watchlist.description);
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Watchlist'),
          content: isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              : SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Name',
                            hintText: 'e.g., Tech Stocks',
                            prefixIcon: const Icon(Icons.bookmark),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            errorMaxLines: 2,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a watchlist name';
                            }
                            if (value.length > 100) {
                              return 'Name must be 100 characters or less';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: descController,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            hintText: 'Optional description',
                            prefixIcon: const Icon(Icons.description),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            errorMaxLines: 2,
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value != null && value.length > 500) {
                              return 'Description must be 500 characters or less';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setState(() => isLoading = true);
                      try {
                        await _service.updateWatchlist(
                          groupId: widget.groupId,
                          watchlistId: watchlist.id,
                          name: nameController.text,
                          description: descController.text,
                        );
                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Watchlist updated')),
                          );
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, GroupWatchlist watchlist) {
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          icon: Icon(
            Icons.warning_outlined,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.amber[400]
                : Colors.amber[700],
            size: 32,
          ),
          title: const Text('Delete Watchlist'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete "${watchlist.name}"?',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.red[900]?.withOpacity(0.2)
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'This action cannot be undone.',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.red[400]
                        : Colors.red[700],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() => isLoading = true);
                      try {
                        await _service.deleteGroupWatchlist(
                          groupId: widget.groupId,
                          watchlistId: watchlist.id,
                        );
                        if (mounted) {
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(context).pop(); // Close detail page
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Watchlist deleted'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _setAsWidgetWatchlist(
      BuildContext context, GroupWatchlist watchlist) async {
    try {
      await HomeWidgetService.setSelectedGroupWatchlist(
        widget.groupId,
        watchlist.id,
      );

      // Update the widget immediately with current data
      final quoteData = <String, Map<String, dynamic>>{};
      // Note: In a real implementation, you'd want to get fresh quote data here
      // For now, we'll update with placeholder data that will be refreshed by the widget's timeline
      await HomeWidgetService.updateGroupWatchlist(watchlist, quoteData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Set "${watchlist.name}" as home screen widget'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting widget watchlist: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearWidgetWatchlist(BuildContext context) async {
    try {
      await HomeWidgetService.setSelectedGroupWatchlist(null, null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cleared home screen widget watchlist'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing widget watchlist: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
