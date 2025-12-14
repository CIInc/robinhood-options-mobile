import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../model/leaderboard_store.dart';
import '../model/portfolio_leaderboard.dart';

class LeaderboardWidget extends StatefulWidget {
  const LeaderboardWidget({super.key});

  @override
  State<LeaderboardWidget> createState() => _LeaderboardWidgetState();
}

class _LeaderboardWidgetState extends State<LeaderboardWidget> {
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$');

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaderboardStore>(
      builder: (context, store, child) {
        return RefreshIndicator(
          onRefresh: () async {
            try {
              await store.calculateLeaderboard();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error refreshing: $e')),
                );
              }
            }
          },
          notificationPredicate: (notification) => notification.depth == 0,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                title: const Text('Top Portfolios'),
                actions: [
                  IconButton(
                    icon: Icon(
                      store.showOnlyFollowed
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
                    tooltip: 'Show only followed',
                    onPressed: () {
                      store.toggleShowOnlyFollowed();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Settings',
                    onPressed: () => _showSettingsDialog(context, store),
                  ),
                ],
              ),
              SliverToBoxAdapter(child: _buildTimePeriodFilter(store)),
              if (store.error != null)
                SliverToBoxAdapter(child: _buildErrorBanner(store.error!)),
              if (store.isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _buildLeaderboardSliver(store),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimePeriodFilter(LeaderboardStore store) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: LeaderboardTimePeriod.values.map((period) {
            final isSelected = store.selectedPeriod == period;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: FilterChip(
                label: Text(period.code),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    store.setTimePeriod(period);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.red.shade100,
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardSliver(LeaderboardStore store) {
    final leaderboard = store.leaderboard;

    if (leaderboard.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.leaderboard, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                store.showOnlyFollowed
                    ? 'No followed portfolios'
                    : 'No public portfolios yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                store.showOnlyFollowed
                    ? 'Follow top performers to see their rankings'
                    : 'Be the first to make your portfolio public!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final performance = leaderboard[index];
          return _buildLeaderboardEntry(context, store, performance);
        },
        childCount: leaderboard.length,
      ),
    );
  }

  Widget _buildLeaderboardEntry(
    BuildContext context,
    LeaderboardStore store,
    PortfolioPerformance performance,
  ) {
    final returnValue = performance.getReturnForPeriod(store.selectedPeriod);
    final returnPercentage =
        performance.getReturnPercentageForPeriod(store.selectedPeriod);
    final isPositive = returnValue >= 0;
    final rankChange = performance.rankChange;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: InkWell(
        onTap: () => _showDetailDialog(context, store, performance),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 50,
                child: Column(
                  children: [
                    Text(
                      '#${performance.rank}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (rankChange != null) _buildRankChange(rankChange),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundImage: performance.userAvatarUrl != null
                    ? NetworkImage(performance.userAvatarUrl!)
                    : null,
                child: performance.userAvatarUrl == null
                    ? Text(
                        performance.userName.isNotEmpty
                            ? performance.userName[0].toUpperCase()
                            : '?',
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // User info and performance
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      performance.userName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(performance.portfolioValue),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isPositive
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${isPositive ? '+' : ''}${returnPercentage.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: isPositive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${isPositive ? '+' : ''}${_currencyFormat.format(returnValue)})',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Follow button
              IconButton(
                icon: Icon(
                  store.isFollowing(performance.userId)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color:
                      store.isFollowing(performance.userId) ? Colors.red : null,
                ),
                onPressed: () async {
                  try {
                    await store.toggleFollow(performance.userId);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankChange(int change) {
    if (change == 0) return const SizedBox.shrink();

    final isImprovement = change > 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isImprovement ? Icons.arrow_upward : Icons.arrow_downward,
          size: 12,
          color: isImprovement ? Colors.green : Colors.red,
        ),
        Text(
          change.abs().toString(),
          style: TextStyle(
            fontSize: 10,
            color: isImprovement ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  void _showDetailDialog(
    BuildContext context,
    LeaderboardStore store,
    PortfolioPerformance performance,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: performance.userAvatarUrl != null
                  ? NetworkImage(performance.userAvatarUrl!)
                  : null,
              child: performance.userAvatarUrl == null
                  ? Text(
                      performance.userName.isNotEmpty
                          ? performance.userName[0].toUpperCase()
                          : '?',
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(performance.userName),
                  Text(
                    'Rank #${performance.rank}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMetricRow('Portfolio Value',
                  _currencyFormat.format(performance.portfolioValue)),
              const Divider(),
              const SizedBox(height: 8),
              Text('Performance',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _buildPerformanceRow('Today', performance.dayReturn,
                  performance.dayReturnPercentage),
              _buildPerformanceRow('Week', performance.weekReturn,
                  performance.weekReturnPercentage),
              _buildPerformanceRow('Month', performance.monthReturn,
                  performance.monthReturnPercentage),
              _buildPerformanceRow('3 Months', performance.threeMonthReturn,
                  performance.threeMonthReturnPercentage),
              _buildPerformanceRow('Year', performance.yearReturn,
                  performance.yearReturnPercentage),
              _buildPerformanceRow('All Time', performance.allTimeReturn,
                  performance.allTimeReturnPercentage),
              const Divider(),
              const SizedBox(height: 8),
              Text('Trading Stats',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _buildMetricRow(
                  'Total Trades', performance.totalTrades.toString()),
              _buildMetricRow(
                  'Win Rate', '${performance.winRate.toStringAsFixed(1)}%'),
              _buildMetricRow(
                  'Winning Trades', performance.winningTrades.toString()),
              _buildMetricRow(
                  'Losing Trades', performance.losingTrades.toString()),
              const Divider(),
              const SizedBox(height: 8),
              Text('Risk Metrics',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _buildMetricRow(
                  'Sharpe Ratio', performance.sharpeRatio.toStringAsFixed(2)),
              _buildMetricRow('Max Drawdown',
                  '${performance.maxDrawdown.toStringAsFixed(2)}%'),
              const SizedBox(height: 8),
              Text(
                'Last updated: ${DateFormat.yMd().add_jm().format(performance.lastUpdated)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              try {
                await store.toggleFollow(performance.userId);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            icon: Icon(
              store.isFollowing(performance.userId)
                  ? Icons.favorite
                  : Icons.favorite_border,
            ),
            label: Text(
              store.isFollowing(performance.userId) ? 'Unfollow' : 'Follow',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(String label, double value, double percentage) {
    final isPositive = value >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: isPositive ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                '${isPositive ? '+' : ''}${percentage.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: isPositive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${isPositive ? '+' : ''}${_currencyFormat.format(value)})',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, LeaderboardStore store) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Portfolio Privacy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Make your portfolio public to appear on the leaderboard and share your performance with the community.',
            ),
            const SizedBox(height: 16),
            const Text(
              'When public, other users can:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('• View your performance metrics'),
            const Text('• Follow your portfolio'),
            const Text('• See your rank on the leaderboard'),
            const SizedBox(height: 16),
            const Text(
              'Note: Your specific holdings and trades remain private.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await store.updatePortfolioPublicStatus(true);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Portfolio is now public'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Make Public'),
          ),
        ],
      ),
    );
  }
}
