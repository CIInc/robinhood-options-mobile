import 'package:cloud_firestore/cloud_firestore.dart';

/// Time period options for leaderboard filtering
enum LeaderboardTimePeriod {
  day('1D', 'Today', Duration(days: 1)),
  week('1W', 'This Week', Duration(days: 7)),
  month('1M', 'This Month', Duration(days: 30)),
  threeMonths('3M', '3 Months', Duration(days: 90)),
  year('1Y', 'This Year', Duration(days: 365)),
  all('All', 'All Time', Duration(days: 365 * 10));

  final String code;
  final String label;
  final Duration duration;

  const LeaderboardTimePeriod(this.code, this.label, this.duration);
}

/// Portfolio performance metrics for leaderboard
class PortfolioPerformance {
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final double totalReturn;
  final double returnPercentage;
  final double portfolioValue;
  final double dayReturn;
  final double dayReturnPercentage;
  final double weekReturn;
  final double weekReturnPercentage;
  final double monthReturn;
  final double monthReturnPercentage;
  final double threeMonthReturn;
  final double threeMonthReturnPercentage;
  final double yearReturn;
  final double yearReturnPercentage;
  final double allTimeReturn;
  final double allTimeReturnPercentage;
  final int totalTrades;
  final int winningTrades;
  final int losingTrades;
  final double winRate;
  final double sharpeRatio;
  final double maxDrawdown;
  final bool isPublic;
  final DateTime lastUpdated;
  final int rank;
  final int? previousRank;

  PortfolioPerformance({
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.totalReturn,
    required this.returnPercentage,
    required this.portfolioValue,
    required this.dayReturn,
    required this.dayReturnPercentage,
    required this.weekReturn,
    required this.weekReturnPercentage,
    required this.monthReturn,
    required this.monthReturnPercentage,
    required this.threeMonthReturn,
    required this.threeMonthReturnPercentage,
    required this.yearReturn,
    required this.yearReturnPercentage,
    required this.allTimeReturn,
    required this.allTimeReturnPercentage,
    required this.totalTrades,
    required this.winningTrades,
    required this.losingTrades,
    required this.winRate,
    required this.sharpeRatio,
    required this.maxDrawdown,
    required this.isPublic,
    required this.lastUpdated,
    required this.rank,
    this.previousRank,
  });

  factory PortfolioPerformance.fromFirestore(
      DocumentSnapshot doc, int rank, int? previousRank) {
    final data = doc.data() as Map<String, dynamic>;
    return PortfolioPerformance(
      userId: doc.id,
      userName: data['userName'] ?? 'Anonymous',
      userAvatarUrl: data['userAvatarUrl'],
      totalReturn: (data['totalReturn'] ?? 0.0).toDouble(),
      returnPercentage: (data['returnPercentage'] ?? 0.0).toDouble(),
      portfolioValue: (data['portfolioValue'] ?? 0.0).toDouble(),
      dayReturn: (data['dayReturn'] ?? 0.0).toDouble(),
      dayReturnPercentage: (data['dayReturnPercentage'] ?? 0.0).toDouble(),
      weekReturn: (data['weekReturn'] ?? 0.0).toDouble(),
      weekReturnPercentage: (data['weekReturnPercentage'] ?? 0.0).toDouble(),
      monthReturn: (data['monthReturn'] ?? 0.0).toDouble(),
      monthReturnPercentage: (data['monthReturnPercentage'] ?? 0.0).toDouble(),
      threeMonthReturn: (data['threeMonthReturn'] ?? 0.0).toDouble(),
      threeMonthReturnPercentage:
          (data['threeMonthReturnPercentage'] ?? 0.0).toDouble(),
      yearReturn: (data['yearReturn'] ?? 0.0).toDouble(),
      yearReturnPercentage: (data['yearReturnPercentage'] ?? 0.0).toDouble(),
      allTimeReturn: (data['allTimeReturn'] ?? 0.0).toDouble(),
      allTimeReturnPercentage:
          (data['allTimeReturnPercentage'] ?? 0.0).toDouble(),
      totalTrades: data['totalTrades'] ?? 0,
      winningTrades: data['winningTrades'] ?? 0,
      losingTrades: data['losingTrades'] ?? 0,
      winRate: (data['winRate'] ?? 0.0).toDouble(),
      sharpeRatio: (data['sharpeRatio'] ?? 0.0).toDouble(),
      maxDrawdown: (data['maxDrawdown'] ?? 0.0).toDouble(),
      isPublic: data['isPublic'] ?? false,
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      rank: rank,
      previousRank: previousRank,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'totalReturn': totalReturn,
      'returnPercentage': returnPercentage,
      'portfolioValue': portfolioValue,
      'dayReturn': dayReturn,
      'dayReturnPercentage': dayReturnPercentage,
      'weekReturn': weekReturn,
      'weekReturnPercentage': weekReturnPercentage,
      'monthReturn': monthReturn,
      'monthReturnPercentage': monthReturnPercentage,
      'threeMonthReturn': threeMonthReturn,
      'threeMonthReturnPercentage': threeMonthReturnPercentage,
      'yearReturn': yearReturn,
      'yearReturnPercentage': yearReturnPercentage,
      'allTimeReturn': allTimeReturn,
      'allTimeReturnPercentage': allTimeReturnPercentage,
      'totalTrades': totalTrades,
      'winningTrades': winningTrades,
      'losingTrades': losingTrades,
      'winRate': winRate,
      'sharpeRatio': sharpeRatio,
      'maxDrawdown': maxDrawdown,
      'isPublic': isPublic,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  double getReturnForPeriod(LeaderboardTimePeriod period) {
    switch (period) {
      case LeaderboardTimePeriod.day:
        return dayReturn;
      case LeaderboardTimePeriod.week:
        return weekReturn;
      case LeaderboardTimePeriod.month:
        return monthReturn;
      case LeaderboardTimePeriod.threeMonths:
        return threeMonthReturn;
      case LeaderboardTimePeriod.year:
        return yearReturn;
      case LeaderboardTimePeriod.all:
        return allTimeReturn;
    }
  }

  double getReturnPercentageForPeriod(LeaderboardTimePeriod period) {
    switch (period) {
      case LeaderboardTimePeriod.day:
        return dayReturnPercentage;
      case LeaderboardTimePeriod.week:
        return weekReturnPercentage;
      case LeaderboardTimePeriod.month:
        return monthReturnPercentage;
      case LeaderboardTimePeriod.threeMonths:
        return threeMonthReturnPercentage;
      case LeaderboardTimePeriod.year:
        return yearReturnPercentage;
      case LeaderboardTimePeriod.all:
        return allTimeReturnPercentage;
    }
  }

  int? get rankChange {
    if (previousRank == null) return null;
    return previousRank! - rank;
  }
}

/// User's follow status for leaderboard entries
class FollowStatus {
  final String followerId;
  final String followeeId;
  final DateTime followedAt;

  FollowStatus({
    required this.followerId,
    required this.followeeId,
    required this.followedAt,
  });

  factory FollowStatus.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FollowStatus(
      followerId: data['followerId'],
      followeeId: data['followeeId'],
      followedAt: (data['followedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'followerId': followerId,
      'followeeId': followeeId,
      'followedAt': Timestamp.fromDate(followedAt),
    };
  }
}
