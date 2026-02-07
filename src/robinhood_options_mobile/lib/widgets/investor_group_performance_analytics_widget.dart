import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:robinhood_options_mobile/model/group_performance_analytics.dart';
import 'package:robinhood_options_mobile/model/group_performance_analytics_provider.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';

// Constants
const int _kMaxChartMembers = 10;
const double _kBottomSheetHeight = 300.0;
const double _kAvatarRadius = 24.0;
const double _kChartHeight = 300.0;
const int _kGridColumns = 2;
const Duration _kAnimationDuration = Duration(milliseconds: 300);
const double _kTabletBreakpoint = 600.0;
const int _kTopPerformersCount = 3;

/// Widget for displaying group performance analytics and leaderboards
class GroupPerformanceAnalyticsWidget extends StatefulWidget {
  final InvestorGroup group;

  const GroupPerformanceAnalyticsWidget({
    super.key,
    required this.group,
  });

  @override
  State<GroupPerformanceAnalyticsWidget> createState() =>
      _GroupPerformanceAnalyticsWidgetState();
}

class _GroupPerformanceAnalyticsWidgetState
    extends State<GroupPerformanceAnalyticsWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TimePeriodFilter _selectedPeriod = TimePeriodFilter.oneMonth;
  String _searchQuery = '';
  RankingSortOption _sortOption = RankingSortOption.totalReturn;
  bool _sortAscending = false;
  final Set<String> _selectedMembersForComparison = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Defer analytics loading to after the first frame to avoid assertion errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnalytics();
    });
  }

  void _loadAnalytics() {
    final provider = context.read<GroupPerformanceAnalyticsProvider>();
    provider.loadGroupPerformanceAnalytics(widget.group.id, _selectedPeriod);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Performance Analytics'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
              Tab(icon: Icon(Icons.leaderboard), text: 'Rankings'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Charts'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAnalytics,
              tooltip: 'Refresh data',
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showMoreOptions,
              tooltip: 'More options',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildTimeFilterBar(),
            Expanded(
              child: Consumer<GroupPerformanceAnalyticsProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return _buildLoadingSkeleton();
                  }

                  if (provider.error != null) {
                    return _buildErrorView(provider.error!);
                  }

                  return RefreshIndicator(
                    onRefresh: () async => _loadAnalytics(),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(provider),
                        _buildRankingsTab(provider),
                        _buildChartsTab(provider),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: _ShimmerLoading(
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              title: Container(
                height: 16,
                width: double.infinity,
                color: Colors.grey[300],
              ),
              subtitle: Container(
                height: 12,
                margin: const EdgeInsets.only(top: 8),
                width: 150,
                color: Colors.grey[300],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Analytics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            for (final period in TimePeriodFilter.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text(period.displayName),
                  selected: _selectedPeriod == period,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedPeriod = period;
                      });
                      final provider =
                          context.read<GroupPerformanceAnalyticsProvider>();
                      provider.setTimePeriod(period);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(GroupPerformanceAnalyticsProvider provider) {
    final metrics = provider.groupMetrics;
    if (metrics == null) {
      return const Center(child: Text('No data available'));
    }

    final isTablet = MediaQuery.of(context).size.width > _kTabletBreakpoint;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group Summary',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildMetricsGrid(metrics, isTablet),
          const SizedBox(height: 24),
          Text(
            'Member Breakdown',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildMemberBreakdown(metrics),
          const SizedBox(height: 24),
          _buildTopPerformersPodium(provider),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(GroupPerformanceMetrics metrics, bool isTablet) {
    final columns = isTablet ? 3 : _kGridColumns;
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isTablet ? 1.5 : 1.3,
      children: [
        _buildMetricCard(
          'Total Return',
          '${metrics.groupTotalReturnPercent.toStringAsFixed(2)}%',
          metrics.groupTotalReturnPercent >= 0 ? Colors.green : Colors.red,
        ),
        _buildMetricCard(
          'Return (\$)',
          '\$${metrics.groupTotalReturnDollars.toStringAsFixed(2)}',
          Colors.blue,
        ),
        _buildMetricCard(
          'Avg Return',
          '${metrics.groupAverageReturnPercent.toStringAsFixed(2)}%',
          Colors.orange,
        ),
        _buildMetricCard(
          'Win Rate',
          '${metrics.groupWinRate.toStringAsFixed(1)}%',
          Colors.purple,
        ),
        _buildMetricCard(
          'Total Trades',
          metrics.totalGroupTrades.toString(),
          Colors.teal,
        ),
        _buildMetricCard(
          'Sharpe Ratio',
          metrics.groupAverageSharpeRatio.toStringAsFixed(2),
          Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showMetricInfo(label);
        },
        borderRadius: BorderRadius.circular(12),
        child: Semantics(
          label: '$label: $value',
          button: true,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedDefaultTextStyle(
                    duration: _kAnimationDuration,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ) ??
                        TextStyle(color: color, fontWeight: FontWeight.bold),
                    child: Text(
                      value,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMetricInfo(String metric) {
    final info = _getMetricInfo(metric);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(metric),
        content: Text(info),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  String _getMetricInfo(String metric) {
    switch (metric) {
      case 'Total Return':
        return 'The aggregated percentage return of all group members for the selected period.';
      case 'Return (\$)':
        return 'The total dollar value of gains or losses across all group members.';
      case 'Avg Return':
        return 'The average return percentage across all active group members.';
      case 'Win Rate':
        return 'The percentage of profitable trades out of all trades made by the group.';
      case 'Total Trades':
        return 'The combined number of trades executed by all group members.';
      case 'Sharpe Ratio':
        return 'A risk-adjusted return metric. Higher values indicate better risk-adjusted performance (>1 is good, >2 is excellent).';
      default:
        return 'Performance metric for group analysis.';
    }
  }

  Widget _buildMemberBreakdown(GroupPerformanceMetrics metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Members Traded',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metrics.totalMembersTraded.toString(),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'Positive',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metrics.membersWithPositiveReturn.toString(),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.green,
                              ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'Negative',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metrics.membersWithNegativeReturn.toString(),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.red,
                              ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: metrics.membersWithPositiveReturn /
                  (metrics.membersWithPositiveReturn +
                      metrics.membersWithNegativeReturn +
                      0.1),
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPerformersPodium(GroupPerformanceAnalyticsProvider provider) {
    final topPerformers =
        provider.getTopPerformers(limit: _kTopPerformersCount);
    if (topPerformers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Performers',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (topPerformers.length == 1) {
              return _buildTopPerformerCard(topPerformers[0], 1);
            }

            // Podium style for 2-3 performers
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (topPerformers.length > 1)
                  Expanded(
                    child: _buildPodiumCard(topPerformers[1], 2, 140),
                  ),
                if (topPerformers.isNotEmpty)
                  Expanded(
                    child: _buildPodiumCard(topPerformers[0], 1, 180),
                  ),
                if (topPerformers.length > 2)
                  Expanded(
                    child: _buildPodiumCard(topPerformers[2], 3, 120),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTopPerformerCard(MemberPerformanceMetrics performer, int rank) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: _kAvatarRadius,
                  backgroundImage: performer.memberPhotoUrl != null
                      ? NetworkImage(performer.memberPhotoUrl!)
                      : null,
                  child: performer.memberPhotoUrl == null
                      ? Text(
                          performer.memberName.characters.first.toUpperCase())
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.emoji_events,
                        size: 16, color: Colors.white),
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
                          performer.memberName,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildPerformanceBadge(performer),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+${performer.totalReturnPercent.toStringAsFixed(2)}%',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumCard(
      MemberPerformanceMetrics performer, int rank, double height) {
    final rankIcons = [
      Icons.emoji_events,
      Icons.military_tech,
      Icons.workspace_premium
    ];
    final rankColors = [Colors.amber, Colors.grey[400]!, Colors.brown[300]!];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundImage: performer.memberPhotoUrl != null
                    ? NetworkImage(performer.memberPhotoUrl!)
                    : null,
                child: performer.memberPhotoUrl == null
                    ? Text(performer.memberName.characters.first.toUpperCase())
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: rankColors[rank - 1],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    rankIcons[rank - 1],
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            performer.memberName,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '+${performer.totalReturnPercent.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: rankColors[rank - 1].withOpacity(0.3),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: rankColors[rank - 1],
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceBadge(MemberPerformanceMetrics member) {
    String? badge;
    Color? badgeColor;

    if (member.winRate >= 80) {
      badge = '🔥';
      badgeColor = Colors.orange;
    } else if (member.sharpeRatio > 2) {
      badge = '⭐';
      badgeColor = Colors.amber;
    } else if (member.totalTrades > 100) {
      badge = '💪';
      badgeColor = Colors.blue;
    }

    if (badge == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor?.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        badge,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildRankingsTab(GroupPerformanceAnalyticsProvider provider) {
    var memberMetrics = provider.sortedMemberMetrics;

    if (memberMetrics.isEmpty) {
      return _buildEmptyState(
        icon: Icons.trending_up,
        title: 'No Trading Activity',
        message:
            'Group members haven\'t made any trades yet during this period.',
      );
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      memberMetrics = memberMetrics
          .where((m) =>
              m.memberName.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply sorting
    memberMetrics = _sortMembers(memberMetrics);

    return Column(
      children: [
        _buildSearchAndSortBar(),
        Expanded(
          child: memberMetrics.isEmpty
              ? _buildEmptyState(
                  icon: Icons.search_off,
                  title: 'No Results',
                  message: 'No members match your search criteria.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: memberMetrics.length,
                  itemBuilder: (context, index) {
                    final member = memberMetrics[index];
                    final isSelected =
                        _selectedMembersForComparison.contains(member.memberId);
                    return AnimatedContainer(
                      duration: _kAnimationDuration,
                      curve: Curves.easeInOut,
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 0),
                        elevation: isSelected ? 4 : 1,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: _getRankColor(index),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (index < 3)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Icon(
                                    Icons.emoji_events,
                                    size: 14,
                                    color: index == 0
                                        ? Colors.amber
                                        : (index == 1
                                            ? Colors.grey
                                            : Colors.brown),
                                  ),
                                ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(member.memberName)),
                              _buildPerformanceBadge(member),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Trades: ${member.totalTrades}  ',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    TextSpan(
                                      text:
                                          'Win Rate: ${member.winRate.toStringAsFixed(1)}%',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${member.totalReturnPercent > 0 ? '+' : ''}${member.totalReturnPercent.toStringAsFixed(2)}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: member.totalReturnPercent >= 0
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                'Sharpe: ${member.sharpeRatio.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showMemberDetails(member);
                          },
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            _toggleMemberSelection(member.memberId);
                          },
                          selected: isSelected,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amber;
    if (index == 1) return Colors.grey[600]!;
    if (index == 2) return Colors.brown[400]!;
    return Theme.of(context).colorScheme.primary;
  }

  void _toggleMemberSelection(String memberId) {
    setState(() {
      if (_selectedMembersForComparison.contains(memberId)) {
        _selectedMembersForComparison.remove(memberId);
      } else {
        if (_selectedMembersForComparison.length < 2) {
          _selectedMembersForComparison.add(memberId);
          if (_selectedMembersForComparison.length == 2) {
            _showMemberComparison();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 2 members can be compared'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _showMemberComparison() async {
    final provider = context.read<GroupPerformanceAnalyticsProvider>();
    final members = provider.sortedMemberMetrics
        .where((m) => _selectedMembersForComparison.contains(m.memberId))
        .toList();

    if (members.length != 2) return;

    await showDialog(
      context: context,
      builder: (context) => _MemberComparisonDialog(
        member1: members[0],
        member2: members[1],
      ),
    );

    setState(() {
      _selectedMembersForComparison.clear();
    });
  }

  Widget _buildSearchAndSortBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (_selectedMembersForComparison.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selectedMembersForComparison.length} selected - Long press to compare',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedMembersForComparison.clear();
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search members...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<RankingSortOption>(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort by',
                onSelected: (option) {
                  setState(() {
                    if (_sortOption == option) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortOption = option;
                      _sortAscending = false;
                    }
                  });
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: RankingSortOption.totalReturn,
                    child: Row(
                      children: [
                        const Icon(Icons.trending_up),
                        const SizedBox(width: 8),
                        const Text('Total Return'),
                        if (_sortOption == RankingSortOption.totalReturn)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              _sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: RankingSortOption.winRate,
                    child: Row(
                      children: [
                        const Icon(Icons.percent),
                        const SizedBox(width: 8),
                        const Text('Win Rate'),
                        if (_sortOption == RankingSortOption.winRate)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              _sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: RankingSortOption.sharpeRatio,
                    child: Row(
                      children: [
                        const Icon(Icons.analytics),
                        const SizedBox(width: 8),
                        const Text('Sharpe Ratio'),
                        if (_sortOption == RankingSortOption.sharpeRatio)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              _sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: RankingSortOption.totalTrades,
                    child: Row(
                      children: [
                        const Icon(Icons.swap_horiz),
                        const SizedBox(width: 8),
                        const Text('Total Trades'),
                        if (_sortOption == RankingSortOption.totalTrades)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              _sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<MemberPerformanceMetrics> _sortMembers(
      List<MemberPerformanceMetrics> members) {
    final sorted = List<MemberPerformanceMetrics>.from(members);
    sorted.sort((a, b) {
      int comparison;
      switch (_sortOption) {
        case RankingSortOption.totalReturn:
          comparison = a.totalReturnPercent.compareTo(b.totalReturnPercent);
          break;
        case RankingSortOption.winRate:
          comparison = a.winRate.compareTo(b.winRate);
          break;
        case RankingSortOption.sharpeRatio:
          comparison = a.sharpeRatio.compareTo(b.sharpeRatio);
          break;
        case RankingSortOption.totalTrades:
          comparison = a.totalTrades.compareTo(b.totalTrades);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });
    return sorted;
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsTab(GroupPerformanceAnalyticsProvider provider) {
    final memberMetrics = provider.sortedMemberMetrics;

    if (memberMetrics.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bar_chart,
        title: 'No Data Available',
        message: 'Charts will appear once members start trading.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Return Distribution',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildReturnChart(memberMetrics),
          const SizedBox(height: 24),
          Text(
            'Win Rate Comparison',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildWinRateChart(memberMetrics),
          const SizedBox(height: 24),
          Text(
            'Sharpe Ratio Comparison',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildSharpeChart(memberMetrics),
        ],
      ),
    );
  }

  Widget _buildReturnChart(List<MemberPerformanceMetrics> members) {
    final chartData = members
        .take(_kMaxChartMembers)
        .map((m) => _MemberReturnData(m.memberName, m.totalReturnPercent))
        .toList();

    return SizedBox(
      height: _kChartHeight,
      child: charts.BarChart(
        [
          charts.Series<_MemberReturnData, String>(
            id: 'Return',
            domainFn: (datum, _) => datum.name,
            measureFn: (datum, _) => datum.returnValue,
            data: chartData,
            colorFn: (datum, _) => datum.returnValue >= 0
                ? charts.MaterialPalette.green.shadeDefault
                : charts.MaterialPalette.red.shadeDefault,
          ),
        ],
        animate: true,
        barRendererDecorator: charts.BarLabelDecorator<String>(),
        domainAxis: const charts.OrdinalAxisSpec(),
        primaryMeasureAxis: const charts.NumericAxisSpec(),
      ),
    );
  }

  Widget _buildWinRateChart(List<MemberPerformanceMetrics> members) {
    final chartData = members
        .take(_kMaxChartMembers)
        .map((m) => _MemberMetricData(m.memberName, m.winRate))
        .toList();

    return SizedBox(
      height: _kChartHeight,
      child: charts.BarChart(
        [
          charts.Series<_MemberMetricData, String>(
            id: 'Win Rate',
            domainFn: (datum, _) => datum.name,
            measureFn: (datum, _) => datum.value,
            data: chartData,
            colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
          ),
        ],
        animate: true,
        barRendererDecorator: charts.BarLabelDecorator<String>(),
        domainAxis: const charts.OrdinalAxisSpec(),
        primaryMeasureAxis: const charts.NumericAxisSpec(
          viewport: charts.NumericExtents(0, 100),
        ),
      ),
    );
  }

  Widget _buildSharpeChart(List<MemberPerformanceMetrics> members) {
    final chartData = members
        .take(_kMaxChartMembers)
        .map((m) => _MemberMetricData(m.memberName, m.sharpeRatio))
        .toList();

    return SizedBox(
      height: _kChartHeight,
      child: charts.BarChart(
        [
          charts.Series<_MemberMetricData, String>(
            id: 'Sharpe Ratio',
            domainFn: (datum, _) => datum.name,
            measureFn: (datum, _) => datum.value,
            data: chartData,
            colorFn: (_, __) => charts.MaterialPalette.purple.shadeDefault,
          ),
        ],
        animate: true,
        barRendererDecorator: charts.BarLabelDecorator<String>(),
        domainAxis: const charts.OrdinalAxisSpec(),
        primaryMeasureAxis: const charts.NumericAxisSpec(),
      ),
    );
  }

  void _showMemberDetails(MemberPerformanceMetrics member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(member.memberName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _memberDetailRow(
                'Total Return',
                '${member.totalReturnPercent > 0 ? '+' : ''}${member.totalReturnPercent.toStringAsFixed(2)}%',
                member.totalReturnPercent >= 0 ? Colors.green : Colors.red,
              ),
              _memberDetailRow(
                'Return (\$)',
                '\$${member.totalReturnDollars.toStringAsFixed(2)}',
                Colors.blue,
              ),
              _memberDetailRow(
                'Total Trades',
                member.totalTrades.toString(),
                Colors.purple,
              ),
              _memberDetailRow(
                'Win Rate',
                '${member.winRate.toStringAsFixed(1)}%',
                Colors.orange,
              ),
              _memberDetailRow(
                'Sharpe Ratio',
                member.sharpeRatio.toStringAsFixed(2),
                Colors.indigo,
              ),
              _memberDetailRow(
                'Profit Factor',
                member.profitFactor.toStringAsFixed(2),
                Colors.teal,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _memberDetailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    final provider = context.read<GroupPerformanceAnalyticsProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: _kBottomSheetHeight,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Export as CSV'),
                subtitle: const Text('Download performance data'),
                onTap: () {
                  Navigator.pop(context);
                  _exportAsCSV(provider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('Export as JSON'),
                subtitle: const Text('Machine-readable format'),
                onTap: () {
                  Navigator.pop(context);
                  _exportAsJSON(provider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share Summary'),
                subtitle: const Text('Share group performance'),
                onTap: () {
                  Navigator.pop(context);
                  _shareAnalytics(provider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.compare_arrows),
                title: const Text('Compare Members'),
                subtitle: const Text('Select 2 members to compare'),
                enabled: false,
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Long press members to compare')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Refresh'),
                onTap: () {
                  Navigator.pop(context);
                  _loadAnalytics();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportAsCSV(GroupPerformanceAnalyticsProvider provider) {
    final csv = provider.exportAsCSV();
    HapticFeedback.mediumImpact();
    Share.share(csv,
        subject: 'Group Performance Report - ${widget.group.name}');
  }

  void _exportAsJSON(GroupPerformanceAnalyticsProvider provider) {
    final metrics = provider.groupMetrics;
    if (metrics == null) return;

    final json = '''
{
  "group": "${widget.group.name}",
  "period": "${_selectedPeriod.displayName}",
  "generated": "${DateTime.now().toIso8601String()}",
  "summary": {
    "totalReturn": ${metrics.groupTotalReturnPercent},
    "totalReturnDollars": ${metrics.groupTotalReturnDollars},
    "averageReturn": ${metrics.groupAverageReturnPercent},
    "winRate": ${metrics.groupWinRate},
    "totalTrades": ${metrics.totalGroupTrades},
    "sharpeRatio": ${metrics.groupAverageSharpeRatio},
    "membersTraded": ${metrics.totalMembersTraded}
  },
  "members": [
${provider.sortedMemberMetrics.map((m) => '    {"name": "${m.memberName}", "return": ${m.totalReturnPercent}, "winRate": ${m.winRate}, "trades": ${m.totalTrades}}').join(',\n')}
  ]
}
    ''';

    HapticFeedback.mediumImpact();
    Share.share(json, subject: 'Group Performance Data - ${widget.group.name}');
  }

  void _shareAnalytics(GroupPerformanceAnalyticsProvider provider) {
    final metrics = provider.groupMetrics;
    if (metrics == null) return;

    final text = '''
Group: ${widget.group.name}
Period: ${_selectedPeriod.displayName}

Summary:
- Total Return: ${metrics.groupTotalReturnPercent.toStringAsFixed(2)}%
- Avg Return: ${metrics.groupAverageReturnPercent.toStringAsFixed(2)}%
- Total Trades: ${metrics.totalGroupTrades}
- Win Rate: ${metrics.groupWinRate.toStringAsFixed(1)}%
- Members Traded: ${metrics.totalMembersTraded}
''';

    Share.share(text, subject: 'Group Performance Summary');
  }
}

class _MemberReturnData {
  final String name;
  final double returnValue;

  _MemberReturnData(this.name, this.returnValue);
}

class _MemberMetricData {
  final String name;
  final double value;

  _MemberMetricData(this.name, this.value);
}

enum RankingSortOption {
  totalReturn,
  winRate,
  sharpeRatio,
  totalTrades,
}

/// Shimmer loading effect widget
class _ShimmerLoading extends StatefulWidget {
  final Widget child;

  const _ShimmerLoading({required this.child});

  @override
  State<_ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<_ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Colors.grey,
                Colors.white,
                Colors.grey,
              ],
              stops: [
                0.0,
                _controller.value,
                1.0,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

/// Member comparison dialog
class _MemberComparisonDialog extends StatelessWidget {
  final MemberPerformanceMetrics member1;
  final MemberPerformanceMetrics member2;

  const _MemberComparisonDialog({
    required this.member1,
    required this.member2,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Member Comparison',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMemberColumn(context, member1),
                Container(
                  width: 1,
                  height: 200,
                  color: Colors.grey[300],
                ),
                _buildMemberColumn(context, member2),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            _buildComparisonMetrics(context),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberColumn(
      BuildContext context, MemberPerformanceMetrics member) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundImage: member.memberPhotoUrl != null
                ? NetworkImage(member.memberPhotoUrl!)
                : null,
            child: member.memberPhotoUrl == null
                ? Text(member.memberName.characters.first.toUpperCase())
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            member.memberName,
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          _buildMetricItem(context, 'Return',
              '${member.totalReturnPercent.toStringAsFixed(2)}%'),
          _buildMetricItem(
              context, 'Win Rate', '${member.winRate.toStringAsFixed(1)}%'),
          _buildMetricItem(context, 'Trades', member.totalTrades.toString()),
          _buildMetricItem(
              context, 'Sharpe', member.sharpeRatio.toStringAsFixed(2)),
        ],
      ),
    );
  }

  Widget _buildMetricItem(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonMetrics(BuildContext context) {
    final returnDiff = member1.totalReturnPercent - member2.totalReturnPercent;
    final winRateDiff = member1.winRate - member2.winRate;
    final tradesDiff = member1.totalTrades - member2.totalTrades;

    return Column(
      children: [
        Text(
          'Key Differences',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _buildDifferenceRow(
          context,
          'Return',
          returnDiff,
          '%',
        ),
        _buildDifferenceRow(
          context,
          'Win Rate',
          winRateDiff,
          '%',
        ),
        _buildDifferenceRow(
          context,
          'Trades',
          tradesDiff.toDouble(),
          '',
        ),
      ],
    );
  }

  Widget _buildDifferenceRow(
    BuildContext context,
    String label,
    double difference,
    String suffix,
  ) {
    final isPositive = difference > 0;
    final color = difference == 0
        ? Colors.grey
        : (isPositive ? Colors.green : Colors.red);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: color,
              ),
              Text(
                '${difference.abs().toStringAsFixed(1)}$suffix',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
