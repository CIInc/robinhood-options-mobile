import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/external_token.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

/// Comprehensive management dashboard for OAuth2 integrations, financial aggregators, and autonomous AI trading agents.
class ConnectedAgentsWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;

  const ConnectedAgentsWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
  });

  @override
  State<ConnectedAgentsWidget> createState() => _ConnectedAgentsWidgetState();
}

enum _SortOption {
  recent,
  firstLogin,
  name,
  type,
}

class _ConnectedAgentsWidgetState extends State<ConnectedAgentsWidget> {
  Future<List<ExternalToken>>? _futureTokens;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all'; // 'all', 'agent', 'linked', 'oauth'
  _SortOption _sortOption = _SortOption.recent;
  bool _showActiveOnly = false;
  bool _isCompactView = false;
  bool _isSecurityNoticeExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _futureTokens = widget.service.getExternalTokensModel(widget.brokerageUser);
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied to clipboard'),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _revokeToken(ExternalToken token) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowButtonSpacing: 8,
        actionsOverflowDirection: VerticalDirection.down,
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 36),
        title: Text('Revoke ${token.primaryTitle}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              token.isAgent
                  ? 'Are you sure you want to revoke this AI trading agent token? It will immediately lose permission to query your balances and execute automated orders.'
                  : 'Are you sure you want to revoke access for "${token.primaryTitle}"? Any connected portfolio sync or external access will stop functioning immediately.',
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Token ID: ${token.id}',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                  if (token.agentId != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Agent ID: ${token.agentId}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                  if (token.agenticAccounts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Accounts: ${token.agenticAccounts.join(", ")}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Access'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.link_off, size: 16),
            onPressed: () => Navigator.pop(ctx, true),
            label: const Text('Revoke Access'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.service.revokeExternalToken(widget.brokerageUser, token.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Access revoked for ${token.primaryTitle}.'
                  : 'Failed to revoke access. Please try again.',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (success) {
          _loadData();
        }
      }
    }
  }

  void _showTokenDetailsSheet(BuildContext context, ExternalToken token) {
    final theme = Theme.of(context);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(token.toJson());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sheet Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(context, token, radius: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            token.primaryTitle,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (token.subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              token.subtitle!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildTypeBadge(token),
                              _buildStatusBadge(token),
                              _buildPermissionBadge(token),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Application Description
                if (token.applicationDescription != null &&
                    token.applicationDescription!.isNotEmpty) ...[
                  Text(
                    'About Integration',
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      token.applicationDescription!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Agent Capabilities Section (if AI agent)
                if (token.isAgent) ...[
                  Text(
                    'Agent Capabilities & Scope',
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: token.typeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: token.typeColor.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bolt, color: token.typeColor, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                token.hasTradePermission
                                    ? 'Autonomous Trading & Order Execution Enabled'
                                    : 'Delegated Read & Analysis Access',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: token.typeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (token.agentId != null) ...[
                          const Divider(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.fingerprint, size: 14, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Agent ID: ${token.agentId}',
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _copyToClipboard(token.agentId!, 'Agent ID'),
                              ),
                            ],
                          ),
                        ],
                        if (token.agenticAccounts.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Authorized Accounts: ${token.agenticAccounts.join(", ")}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Permissions Breakdown
                Text(
                  'Granted Permissions & Scopes',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (token.scopes.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            token.isAgent
                                ? 'Standard Agentic Portfolio & Execution Delegations'
                                : 'Account Integration Access',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: token.scopes.map((scope) {
                      final scopeDesc = _explainScope(scope);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                scope.toLowerCase().contains('trade') || scope.toLowerCase().contains('order')
                                    ? Icons.bolt
                                    : Icons.visibility_outlined,
                                size: 16,
                                color: scope.toLowerCase().contains('trade')
                                    ? Colors.amber[700]
                                    : theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                scope.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  scopeDesc,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),

                // Technical Identifiers
                Text(
                  'Identifiers & Credentials',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildCopyableInfoTile(context, 'Token ID', token.id),
                if (token.clientId != null)
                  _buildCopyableInfoTile(context, 'Client ID', token.clientId!),
                if (token.agentId != null)
                  _buildCopyableInfoTile(context, 'Agent ID', token.agentId!),
                _buildCopyableInfoTile(context, 'Token Type', token.tokenType),
                const SizedBox(height: 16),

                // Timestamps & Lifecycle
                Text(
                  'Connection Lifecycle',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _buildTimestampRow(
                        'First Authorized',
                        token.formattedInitialLogin,
                        relative: token.relativeFirstLogin,
                      ),
                      const Divider(height: 14),
                      _buildTimestampRow(
                        'Last Active / Updated',
                        token.formattedUpdatedAt,
                        relative: token.relativeLastActive,
                      ),
                      const Divider(height: 14),
                      _buildTimestampRow('Created', token.formattedCreatedAt),
                      const Divider(height: 14),
                      _buildTimestampRow('Expires', token.formattedExpiresAt),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Technical Raw JSON Viewer
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Technical Details (JSON)',
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Stack(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Text(
                                jsonStr,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                tooltip: 'Copy JSON',
                                onPressed: () => _copyToClipboard(jsonStr, 'JSON payload'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Destructive Revoke Button
                if (token.isActive) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.link_off),
                    label: const Text('Revoke Token Access', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _revokeToken(token);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          },
        );
      },
    );
  }

  String _explainScope(String scope) {
    final lower = scope.toLowerCase();
    if (lower.contains('trade') || lower.contains('order')) {
      return 'Place, cancel, & replace buy and sell orders';
    }
    if (lower.contains('read') || lower.contains('data')) {
      return 'View balances, open positions, & orders';
    }
    if (lower.contains('account')) {
      return 'Access account identifiers & profile details';
    }
    if (lower.contains('instrument')) {
      return 'Search securities, option chains, & live quotes';
    }
    return 'Delegated API access permission';
  }

  Widget _buildCopyableInfoTile(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InkWell(
              onTap: () => _copyToClipboard(value, label),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Icon(Icons.copy, size: 14, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestampRow(String label, String value, {String? relative}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            if (relative != null && relative.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  relative,
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Agents & Apps'),
        actions: [
          // View Mode Toggle
          IconButton(
            icon: Icon(_isCompactView ? Icons.view_agenda_outlined : Icons.view_headline_outlined),
            tooltip: _isCompactView ? 'Detailed View' : 'Compact View',
            onPressed: () => setState(() => _isCompactView = !_isCompactView),
          ),
          // Sort Options Menu
          PopupMenuButton<_SortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort integrations',
            initialValue: _sortOption,
            onSelected: (option) => setState(() => _sortOption = option),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: _SortOption.recent,
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 18),
                    SizedBox(width: 10),
                    Text('Recently Active'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: _SortOption.firstLogin,
                child: Row(
                  children: [
                    Icon(Icons.history_toggle_off, size: 18),
                    SizedBox(width: 10),
                    Text('First Authorized'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: _SortOption.type,
                child: Row(
                  children: [
                    Icon(Icons.psychology, size: 18),
                    SizedBox(width: 10),
                    Text('Type (AI Agents First)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: _SortOption.name,
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, size: 18),
                    SizedBox(width: 10),
                    Text('Name (A-Z)'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: FutureBuilder<List<ExternalToken>>(
        future: _futureTokens,
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
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading connected agents: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final allTokens = snapshot.data ?? [];
          final activeTokens = allTokens.where((t) => t.isActive).toList();
          final agentsCount = allTokens.where((t) => t.isAgent).length;
          final linkedCount = allTokens.where((t) => t.isAggregator).length;
          final oauthCount = allTokens.where((t) => !t.isAgent && !t.isAggregator).length;

          // Apply active-only filter
          var filtered = _showActiveOnly ? activeTokens : allTokens;

          // Apply category filter
          if (_selectedCategory == 'agent') {
            filtered = filtered.where((t) => t.isAgent).toList();
          } else if (_selectedCategory == 'linked') {
            filtered = filtered.where((t) => t.isAggregator).toList();
          } else if (_selectedCategory == 'oauth') {
            filtered = filtered.where((t) => !t.isAgent && !t.isAggregator).toList();
          }

          // Apply keyword search
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            filtered = filtered.where((t) {
              final nameMatch = t.applicationName.toLowerCase().contains(query);
              final titleMatch = t.primaryTitle.toLowerCase().contains(query);
              final subtitleMatch = t.subtitle?.toLowerCase().contains(query) ?? false;
              final agentMatch = t.agentId?.toLowerCase().contains(query) ?? false;
              final idMatch = t.id.toLowerCase().contains(query);
              final accountMatch = t.agenticAccounts.any((a) => a.contains(query));
              return nameMatch || titleMatch || subtitleMatch || agentMatch || idMatch || accountMatch;
            }).toList();
          }

          // Apply sort
          filtered.sort((a, b) {
            switch (_sortOption) {
              case _SortOption.recent:
                final dateA = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                final dateB = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                return dateB.compareTo(dateA);
              case _SortOption.firstLogin:
                final dateA = a.initialLoginTime ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                final dateB = b.initialLoginTime ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                return dateB.compareTo(dateA);
              case _SortOption.name:
                return a.primaryTitle.toLowerCase().compareTo(b.primaryTitle.toLowerCase());
              case _SortOption.type:
                if (a.isAgent && !b.isAgent) return -1;
                if (!a.isAgent && b.isAgent) return 1;
                if (a.isAggregator && !b.isAggregator) return -1;
                if (!a.isAggregator && b.isAggregator) return 1;
                return a.primaryTitle.toLowerCase().compareTo(b.primaryTitle.toLowerCase());
            }
          });

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              children: [
                _buildOverviewHeader(
                  context,
                  total: allTokens.length,
                  active: activeTokens.length,
                  agents: agentsCount,
                  linked: linkedCount,
                  oauth: oauthCount,
                ),
                const SizedBox(height: 12),
                _buildSearchBar(context),
                const SizedBox(height: 10),
                _buildFilterChips(
                  context,
                  total: allTokens.length,
                  agents: agentsCount,
                  linked: linkedCount,
                  oauth: oauthCount,
                ),
                const SizedBox(height: 10),
                _buildToolbar(context, filteredCount: filtered.length, totalCount: allTokens.length),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  _buildEmptyState(context, isSearching: _searchQuery.isNotEmpty)
                else if (_isCompactView)
                  ...filtered.map((token) => _buildCompactTokenTile(context, token))
                else
                  ...filtered.map((token) => _buildTokenCard(context, token)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewHeader(
    BuildContext context, {
    required int total,
    required int active,
    required int agents,
    required int linked,
    required int oauth,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.security_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Authorized Access',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$active Active',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Autonomous trading agents, aggregators, & OAuth integrations.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildStatBadge(context, '$agents', 'AI Agents', const Color(0xFF7C4DFF), Icons.psychology),
                const SizedBox(width: 8),
                _buildStatBadge(context, '$linked', 'Linked Hubs', const Color(0xFF00897B), Icons.hub_outlined),
                const SizedBox(width: 8),
                _buildStatBadge(context, '$oauth', 'Direct Apps', const Color(0xFF1E88E5), Icons.apps_outlined),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => _isSecurityNoticeExpanded = !_isSecurityNoticeExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                child: Row(
                  children: [
                    Icon(
                      _isSecurityNoticeExpanded ? Icons.info : Icons.info_outline,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Security & Delegated Authority Guidance',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      _isSecurityNoticeExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (_isSecurityNoticeExpanded) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'Connected applications and AI agents hold cryptographic tokens granting access to your Robinhood portfolio. '
                  'AI Agents may have active order placement capabilities. '
                  'Regularly review your authorized connections and revoke access for any applications you are no longer using.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(BuildContext context, String count, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by app, agent ID, account, or token...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        isDense: true,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (val) {
        setState(() {
          _searchQuery = val.trim();
        });
      },
    );
  }

  Widget _buildFilterChips(
    BuildContext context, {
    required int total,
    required int agents,
    required int linked,
    required int oauth,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: Text('All ($total)'),
            selected: _selectedCategory == 'all',
            onSelected: (sel) {
              if (sel) setState(() => _selectedCategory = 'all');
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.psychology, size: 16),
            label: Text('AI Agents ($agents)'),
            selected: _selectedCategory == 'agent',
            onSelected: (sel) {
              if (sel) setState(() => _selectedCategory = 'agent');
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.hub_outlined, size: 16),
            label: Text('Linked Services ($linked)'),
            selected: _selectedCategory == 'linked',
            onSelected: (sel) {
              if (sel) setState(() => _selectedCategory = 'linked');
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.apps_outlined, size: 16),
            label: Text('Direct Apps ($oauth)'),
            selected: _selectedCategory == 'oauth',
            onSelected: (sel) {
              if (sel) setState(() => _selectedCategory = 'oauth');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, {required int filteredCount, required int totalCount}) {
    final theme = Theme.of(context);
    String sortLabel = 'Recently Active';
    switch (_sortOption) {
      case _SortOption.recent:
        sortLabel = 'Recent';
        break;
      case _SortOption.firstLogin:
        sortLabel = 'First Login';
        break;
      case _SortOption.type:
        sortLabel = 'By Type';
        break;
      case _SortOption.name:
        sortLabel = 'A-Z';
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final countText = Text(
          'Showing $filteredCount of $totalCount',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        );
        final controls = [
          FilterChip(
            label: const Text('Active Only', style: TextStyle(fontSize: 11)),
            selected: _showActiveOnly,
            visualDensity: VisualDensity.compact,
            onSelected: (val) => setState(() => _showActiveOnly = val),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  sortLabel,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ];

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              countText,
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: controls),
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            countText,
            Row(mainAxisSize: MainAxisSize.min, children: controls),
          ],
        );
      },
    );
  }

  Widget _buildTokenCard(BuildContext context, ExternalToken token) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: token.isAgent
            ? BorderSide(color: token.typeColor.withValues(alpha: 0.35), width: 1.5)
            : BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4), width: 0.8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showTokenDetailsSheet(context, token),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(context, token),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          token.primaryTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (token.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            token.subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildTypeBadge(token),
                      const SizedBox(height: 4),
                      _buildStatusBadge(token),
                    ],
                  ),
                ],
              ),

              // AI Agent Capabilities Box
              if (token.isAgent) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: token.typeColor.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: token.typeColor.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bolt, size: 14, color: token.typeColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Autonomous Execution Authority',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: token.typeColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (token.agenticAccounts.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: token.typeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Account: ${token.agenticAccounts.first}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: token.typeColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (token.agentId != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.fingerprint, size: 13, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Agent ID: ${token.agentId}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              onTap: () => _copyToClipboard(token.agentId!, 'Agent ID'),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4.0),
                                child: Icon(Icons.copy, size: 13, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Scopes & Permissions Row
              if (token.scopes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: token.scopes
                      .map((s) => Chip(
                            label: Text(
                              s.toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          ))
                      .toList(),
                ),
              ],

              const Divider(height: 22),

              // Timestamps & Actions Footer (Responsive LayoutBuilder prevents any horizontal overflow)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 360;

                  final infoColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 12, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Active: ${token.relativeLastActive}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: #${token.id}  •  First: ${token.relativeFirstLogin}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );

                  final actionsRow = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.info_outline, size: 15),
                        label: const Text('Details', style: TextStyle(fontSize: 12)),
                        onPressed: () => _showTokenDetailsSheet(context, token),
                      ),
                      if (token.isActive) ...[
                        const SizedBox(width: 4),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red, width: 1),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () => _revokeToken(token),
                          child: const Text('Revoke', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        infoColumn,
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [actionsRow],
                        ),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: infoColumn),
                      const SizedBox(width: 8),
                      actionsRow,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTokenTile(BuildContext context, ExternalToken token) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: token.isAgent
              ? token.typeColor.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () => _showTokenDetailsSheet(context, token),
        leading: _buildAvatar(context, token, radius: 18),
        title: Row(
          children: [
            Expanded(
              child: Text(
                token.primaryTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            _buildTypeBadge(token),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              token.subtitle ?? 'ID: #${token.id}',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  token.relativeLastActive,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '•  ${token.permissionSummary}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: token.hasTradePermission ? Colors.amber[800] : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: token.isActive
            ? IconButton(
                icon: const Icon(Icons.link_off, size: 18, color: Colors.red),
                tooltip: 'Revoke Access',
                onPressed: () => _revokeToken(token),
              )
            : const Text('Revoked', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTypeBadge(ExternalToken token) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: token.typeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(token.typeIcon, size: 11, color: token.typeColor),
          const SizedBox(width: 3.5),
          Text(
            token.typeLabel.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: token.typeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ExternalToken token) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: token.statusColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        token.statusLabel.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: token.statusColor,
        ),
      ),
    );
  }

  Widget _buildPermissionBadge(ExternalToken token) {
    final hasTrade = token.hasTradePermission;
    final color = hasTrade ? Colors.amber[800]! : Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(hasTrade ? Icons.bolt : Icons.visibility_outlined, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            hasTrade ? 'TRADING ENABLED' : 'READ ONLY',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, ExternalToken token, {double radius = 20}) {
    if (token.fourthPartyLogoUrl != null &&
        token.fourthPartyLogoUrl!.isNotEmpty &&
        !token.fourthPartyLogoUrl!.toLowerCase().endsWith('.svg')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius * 0.4),
        child: Image.network(
          token.fourthPartyLogoUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallbackAvatar(token, radius: radius),
        ),
      );
    }
    return _buildFallbackAvatar(token, radius: radius);
  }

  Widget _buildFallbackAvatar(ExternalToken token, {double radius = 20}) {
    return CircleAvatar(
      backgroundColor: token.typeColor.withValues(alpha: 0.15),
      foregroundColor: token.typeColor,
      radius: radius,
      child: Icon(token.typeIcon, size: radius * 1.1),
    );
  }

  Widget _buildEmptyState(BuildContext context, {bool isSearching = false}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(isSearching ? Icons.search_off : Icons.security, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'No Matching Tokens Found' : 'No Connected Agents or Apps',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try searching with a different keyword or resetting the filter category.'
                  : 'Third-party tools and trading applications authorized with your Robinhood account will be listed here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            if (isSearching) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear Search & Filters'),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = 'all';
                    _showActiveOnly = false;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
