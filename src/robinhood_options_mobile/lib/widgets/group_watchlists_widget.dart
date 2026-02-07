import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/group_watchlist_models.dart';
import 'package:robinhood_options_mobile/services/group_watchlist_service.dart';
import 'package:robinhood_options_mobile/widgets/group_watchlist_detail_widget.dart';
import 'package:robinhood_options_mobile/widgets/group_watchlist_create_widget.dart';

class GroupWatchlistsWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final String groupId;

  const GroupWatchlistsWidget({
    Key? key,
    required this.brokerageUser,
    required this.groupId,
  }) : super(key: key);

  @override
  State<GroupWatchlistsWidget> createState() => _GroupWatchlistsWidgetState();
}

enum WatchlistSortOption {
  nameAsc,
  nameDesc,
  symbolCountAsc,
  symbolCountDesc,
  newest,
  oldest,
}

enum WatchlistFilterOption {
  all,
  myWatchlists,
  editorAccess,
}

class _GroupWatchlistsWidgetState extends State<GroupWatchlistsWidget> {
  final GroupWatchlistService _service = GroupWatchlistService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  WatchlistSortOption _sortOption = WatchlistSortOption.newest;
  WatchlistFilterOption _filterOption = WatchlistFilterOption.all;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;

  Color _getCardBorderColor() =>
      _isDarkTheme ? Colors.grey[700]! : Colors.grey[200]!;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GroupWatchlist> _filterAndSortWatchlists(
      List<GroupWatchlist> watchlists) {
    var filtered = watchlists;

    // Apply role filter
    if (_filterOption != WatchlistFilterOption.all) {
      if (_filterOption == WatchlistFilterOption.myWatchlists) {
        filtered =
            filtered.where((w) => w.createdBy == _currentUserId).toList();
      } else if (_filterOption == WatchlistFilterOption.editorAccess) {
        filtered = filtered.where((w) {
          final permission = w.permissions[_currentUserId];
          return w.createdBy == _currentUserId || permission == 'editor';
        }).toList();
      }
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((w) {
        return w.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            w.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            w.symbols.any((s) =>
                s.symbol.toLowerCase().contains(_searchQuery.toLowerCase()));
      }).toList();
    }

    // Apply sorting
    switch (_sortOption) {
      case WatchlistSortOption.nameAsc:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case WatchlistSortOption.nameDesc:
        filtered.sort((a, b) => b.name.compareTo(a.name));
        break;
      case WatchlistSortOption.symbolCountAsc:
        filtered.sort((a, b) => a.symbols.length.compareTo(b.symbols.length));
        break;
      case WatchlistSortOption.symbolCountDesc:
        filtered.sort((a, b) => b.symbols.length.compareTo(a.symbols.length));
        break;
      case WatchlistSortOption.newest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case WatchlistSortOption.oldest:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
    }

    return filtered;
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.green[400]
                  : Colors.green[300],
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.green[900]?.withOpacity(0.8)
            : Colors.green[800],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.red[400]
                  : Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.red[900]?.withOpacity(0.8)
            : Colors.red[800],
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupWatchlist>>(
      stream: _service.getGroupWatchlistsStream(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error);
        }

        final allWatchlists = snapshot.data ?? [];
        final filteredWatchlists = _filterAndSortWatchlists(allWatchlists);

        return Scaffold(
          appBar: _buildAppBar(allWatchlists),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'create_watchlist_fab',
            key: const Key('create_watchlist_fab'),
            onPressed: () => _showCreateDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('New Watchlist'),
          ),
          body: allWatchlists.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: CustomScrollView(
                    slivers: [
                      _buildSearchBar(filteredWatchlists, allWatchlists),
                      _buildFilterChips(),
                      if (filteredWatchlists.isEmpty && _searchQuery.isNotEmpty)
                        _buildNoSearchResults()
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final watchlist = filteredWatchlists[index];
                                final userId =
                                    FirebaseAuth.instance.currentUser?.uid ??
                                        '';
                                final permission =
                                    watchlist.permissions[userId] ?? '';
                                final isCreator = watchlist.createdBy == userId;
                                final isEditor =
                                    permission == 'editor' || isCreator;

                                return GroupWatchlistCard(
                                  watchlist: watchlist,
                                  brokerageUser: widget.brokerageUser,
                                  groupId: widget.groupId,
                                  isEditor: isEditor,
                                  isCreator: isCreator,
                                  borderColor: _getCardBorderColor(),
                                  onEdit: () =>
                                      _showEditDialog(context, watchlist),
                                  onDelete: () => _showDeleteConfirmation(
                                      context, watchlist),
                                );
                              },
                              childCount: filteredWatchlists.length,
                            ),
                          ),
                        ),
                      const SliverPadding(
                        padding: EdgeInsets.only(bottom: 80),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(List<GroupWatchlist> allWatchlists) {
    return AppBar(
      title: const Text('Group Watchlists'),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Back',
      ),
      // Sort action moved to search bar
      actions: [],
    );
  }

  Widget _buildSortMenuItem(
      IconData icon, String label, WatchlistSortOption option) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: _sortOption == option
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontWeight:
                _sortOption == option ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(
      List<GroupWatchlist> filtered, List<GroupWatchlist> all) {
    // Theme-aware color for sort button background
    final sortBgColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[800]
        : Colors.grey[200];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search watchlists...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              tooltip: 'Clear search',
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
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                if (all.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<WatchlistSortOption>(
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: sortBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sort, size: 24),
                    ),
                    tooltip: 'Sort watchlists',
                    onSelected: (option) {
                      setState(() {
                        _sortOption = option;
                      });
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: WatchlistSortOption.newest,
                        child: _buildSortMenuItem(
                          Icons.access_time,
                          'Newest First',
                          WatchlistSortOption.newest,
                        ),
                      ),
                      PopupMenuItem(
                        value: WatchlistSortOption.oldest,
                        child: _buildSortMenuItem(
                          Icons.history,
                          'Oldest First',
                          WatchlistSortOption.oldest,
                        ),
                      ),
                      PopupMenuItem(
                        value: WatchlistSortOption.nameAsc,
                        child: _buildSortMenuItem(
                          Icons.sort_by_alpha,
                          'Name (A-Z)',
                          WatchlistSortOption.nameAsc,
                        ),
                      ),
                      PopupMenuItem(
                        value: WatchlistSortOption.nameDesc,
                        child: _buildSortMenuItem(
                          Icons.sort_by_alpha,
                          'Name (Z-A)',
                          WatchlistSortOption.nameDesc,
                        ),
                      ),
                      PopupMenuItem(
                        value: WatchlistSortOption.symbolCountDesc,
                        child: _buildSortMenuItem(
                          Icons.trending_up,
                          'Most Symbols',
                          WatchlistSortOption.symbolCountDesc,
                        ),
                      ),
                      PopupMenuItem(
                        value: WatchlistSortOption.symbolCountAsc,
                        child: _buildSortMenuItem(
                          Icons.trending_down,
                          'Least Symbols',
                          WatchlistSortOption.symbolCountAsc,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            if (all.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Semantics(
                  label: '${filtered.length} watchlists found',
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? '${filtered.length} of ${all.length} ${filtered.length == 1 ? 'Watchlist' : 'Watchlists'}'
                        : '${all.length} ${all.length == 1 ? 'Watchlist' : 'Watchlists'}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: SliverToBoxAdapter(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                'All Watchlists',
                WatchlistFilterOption.all,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Created by Me',
                WatchlistFilterOption.myWatchlists,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Editor Access',
                WatchlistFilterOption.editorAccess,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, WatchlistFilterOption option) {
    final isSelected = _filterOption == option;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _filterOption = option;
        });
      },
      backgroundColor: Theme.of(context).cardColor,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).textTheme.bodyMedium?.color,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color:
              isSelected ? Colors.transparent : Theme.of(context).dividerColor,
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Watchlists'),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 250,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 80,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(Object? error) {
    final isNetworkError = error.toString().contains('Failed host lookup') ||
        error.toString().contains('Network error');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isNetworkError ? Colors.orange : Colors.red)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isNetworkError ? Icons.wifi_off : Icons.error_outline,
                  color: isNetworkError ? Colors.orange[700] : Colors.red,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isNetworkError ? 'Network Error' : 'Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isNetworkError
                    ? 'Please check your internet connection'
                    : 'Failed to load watchlists. Please try again.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withOpacity(0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.bookmark_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Watchlists Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first watchlist to track group symbols',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Watchlist'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No matches found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Try a different search term',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withOpacity(0.7),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => GroupWatchlistCreateWidget(
        groupId: widget.groupId,
        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
        onCreated: () {
          Navigator.of(context).pop();
          _showSuccessSnackBar('Watchlist created successfully');
        },
        onError: (error) {
          Navigator.of(context).pop();
          _showErrorSnackBar('Failed to create: $error');
        },
      ),
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
                          _showSuccessSnackBar('Watchlist updated');
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (mounted) {
                          _showErrorSnackBar('Error: $e');
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
                          Navigator.of(context).pop();
                          _showSuccessSnackBar('Watchlist deleted');
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (mounted) {
                          _showErrorSnackBar('Error: $e');
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
}

class GroupWatchlistCard extends StatelessWidget {
  final GroupWatchlist watchlist;
  final BrokerageUser brokerageUser;
  final String groupId;
  final bool isEditor;
  final bool isCreator;
  final Color borderColor;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const GroupWatchlistCard({
    Key? key,
    required this.watchlist,
    required this.brokerageUser,
    required this.groupId,
    this.isEditor = false,
    this.isCreator = false,
    this.borderColor = Colors.grey,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine colors for badges here to reuse
    final primaryColor = Theme.of(context).colorScheme.primary;
    final primaryLight = primaryColor.withOpacity(0.1);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label:
          'Watchlist ${watchlist.name}, ${watchlist.symbols.length} symbols, ${isEditor ? "Editor access" : "Viewer access"}',
      button: true,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1),
        ),
        child: InkWell(
          key: Key('watchlist_card_${watchlist.id}'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GroupWatchlistDetailWidget(
                  brokerageUser: brokerageUser,
                  groupId: groupId,
                  watchlistId: watchlist.id,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon, name, role badge, and menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.bookmarks_rounded,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            watchlist.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isEditor
                                  ? primaryLight
                                  : Theme.of(context)
                                      .dividerColor
                                      .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isEditor ? Icons.edit_note : Icons.visibility,
                                  size: 12,
                                  color: isEditor
                                      ? primaryColor
                                      : Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isEditor ? 'Editor' : 'Viewer',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isEditor
                                        ? primaryColor
                                        : Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      tooltip: 'Watchlist actions',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: Row(
                            children: [
                              const Icon(Icons.open_in_new, size: 18),
                              const SizedBox(width: 12),
                              const Text('View Details'),
                            ],
                          ),
                          onTap: () {
                            // Delay navigation to let menu close smoothly
                            Future.delayed(const Duration(milliseconds: 10),
                                () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      GroupWatchlistDetailWidget(
                                    brokerageUser: brokerageUser,
                                    groupId: groupId,
                                    watchlistId: watchlist.id,
                                  ),
                                ),
                              );
                            });
                          },
                        ),
                        if (isEditor && onEdit != null)
                          PopupMenuItem(
                            child: Row(
                              children: [
                                const Icon(Icons.edit, size: 18),
                                const SizedBox(width: 12),
                                const Text('Edit'),
                              ],
                            ),
                            onTap: onEdit,
                          ),
                        if (isCreator && onDelete != null)
                          PopupMenuItem(
                            child: Row(
                              children: [
                                const Icon(Icons.delete, size: 18),
                                const SizedBox(width: 12),
                                const Text('Delete'),
                              ],
                            ),
                            onTap: onDelete,
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Description
                if (watchlist.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      watchlist.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withOpacity(0.7),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // Metadata row using helper
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetadataBadge(
                      context,
                      icon: Icons.trending_up,
                      label: '${watchlist.symbols.length} Symbols',
                      color: primaryColor,
                      bgColor: primaryLight,
                    ),
                    if (watchlist.symbols
                        .any((s) => s.alerts.any((a) => a.active)))
                      _buildMetadataBadge(
                        context,
                        icon: Icons.notifications_active,
                        label:
                            '${watchlist.symbols.expand((s) => s.alerts).where((a) => a.active).length} Alerts',
                        color:
                            isDark ? Colors.orange[400]! : Colors.orange[800]!,
                        bgColor: isDark
                            ? Colors.orange[900]!.withOpacity(0.3)
                            : Colors.orange[100]!,
                      ),
                    if (isCreator)
                      _buildMetadataBadge(
                        context,
                        icon: Icons.person,
                        label: 'Owner',
                        color: isDark ? Colors.amber[400]! : Colors.amber[700]!,
                        bgColor: isDark
                            ? Colors.amber[900]!.withOpacity(0.3)
                            : Colors.amber[100]!,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Updated ${DateFormat.yMMMd().add_jm().format(watchlist.updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(0.5),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
