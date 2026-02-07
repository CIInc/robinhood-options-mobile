/// Member performance metrics for leaderboard and analytics
class MemberPerformanceMetrics {
  final String memberId;
  final String memberName;
  final String? memberPhotoUrl;
  final double totalReturnPercent;
  final double totalReturnDollars;
  final double winRate; // Percentage (0-100)
  final int totalTrades;
  final int winningTrades;
  final int losingTrades;
  final double averageWin;
  final double averageLoss;
  final double profitFactor;
  final double sharpeRatio;
  final double maxDrawdownPercent;
  final double? avgHoldTimeHours;
  final DateTime? firstTradeDate;
  final DateTime? lastTradeDate;

  MemberPerformanceMetrics({
    required this.memberId,
    required this.memberName,
    this.memberPhotoUrl,
    required this.totalReturnPercent,
    required this.totalReturnDollars,
    required this.winRate,
    required this.totalTrades,
    required this.winningTrades,
    required this.losingTrades,
    required this.averageWin,
    required this.averageLoss,
    required this.profitFactor,
    required this.sharpeRatio,
    required this.maxDrawdownPercent,
    this.avgHoldTimeHours,
    this.firstTradeDate,
    this.lastTradeDate,
  });

  MemberPerformanceMetrics.fromJson(Map<String, dynamic> json)
      : memberId = json['memberId'] as String,
        memberName = json['memberName'] as String,
        memberPhotoUrl = json['memberPhotoUrl'] as String?,
        totalReturnPercent = json['totalReturnPercent'] as double? ?? 0,
        totalReturnDollars = json['totalReturnDollars'] as double? ?? 0,
        winRate = json['winRate'] as double? ?? 0,
        totalTrades = json['totalTrades'] as int? ?? 0,
        winningTrades = json['winningTrades'] as int? ?? 0,
        losingTrades = json['losingTrades'] as int? ?? 0,
        averageWin = json['averageWin'] as double? ?? 0,
        averageLoss = json['averageLoss'] as double? ?? 0,
        profitFactor = json['profitFactor'] as double? ?? 0,
        sharpeRatio = json['sharpeRatio'] as double? ?? 0,
        maxDrawdownPercent = json['maxDrawdownPercent'] as double? ?? 0,
        avgHoldTimeHours = json['avgHoldTimeHours'] as double?,
        firstTradeDate = json['firstTradeDate'] != null
            ? DateTime.parse(json['firstTradeDate'] as String)
            : null,
        lastTradeDate = json['lastTradeDate'] != null
            ? DateTime.parse(json['lastTradeDate'] as String)
            : null;

  Map<String, dynamic> toJson() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'memberPhotoUrl': memberPhotoUrl,
      'totalReturnPercent': totalReturnPercent,
      'totalReturnDollars': totalReturnDollars,
      'winRate': winRate,
      'totalTrades': totalTrades,
      'winningTrades': winningTrades,
      'losingTrades': losingTrades,
      'averageWin': averageWin,
      'averageLoss': averageLoss,
      'profitFactor': profitFactor,
      'sharpeRatio': sharpeRatio,
      'maxDrawdownPercent': maxDrawdownPercent,
      'avgHoldTimeHours': avgHoldTimeHours,
      'firstTradeDate': firstTradeDate?.toIso8601String(),
      'lastTradeDate': lastTradeDate?.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'MemberPerformanceMetrics(memberId: $memberId, memberName: $memberName, totalReturnPercent: $totalReturnPercent, winRate: $winRate)';
}

/// Aggregate group performance metrics
class GroupPerformanceMetrics {
  final String groupId;
  final double groupTotalReturnPercent;
  final double groupTotalReturnDollars;
  final double groupAverageReturnPercent;
  final double groupAverageReturnDollars;
  final int totalMembersTraded;
  final int totalGroupTrades;
  final double groupWinRate;
  final double groupAverageSharpeRatio;
  final double topPerformerReturnPercent;
  final String? topPerformerId;
  final int membersWithPositiveReturn;
  final int membersWithNegativeReturn;
  final DateTime? timeRangeStart;
  final DateTime? timeRangeEnd;

  GroupPerformanceMetrics({
    required this.groupId,
    required this.groupTotalReturnPercent,
    required this.groupTotalReturnDollars,
    required this.groupAverageReturnPercent,
    required this.groupAverageReturnDollars,
    required this.totalMembersTraded,
    required this.totalGroupTrades,
    required this.groupWinRate,
    required this.groupAverageSharpeRatio,
    required this.topPerformerReturnPercent,
    this.topPerformerId,
    required this.membersWithPositiveReturn,
    required this.membersWithNegativeReturn,
    this.timeRangeStart,
    this.timeRangeEnd,
  });

  GroupPerformanceMetrics.fromJson(Map<String, dynamic> json)
      : groupId = json['groupId'] as String,
        groupTotalReturnPercent =
            json['groupTotalReturnPercent'] as double? ?? 0,
        groupTotalReturnDollars =
            json['groupTotalReturnDollars'] as double? ?? 0,
        groupAverageReturnPercent =
            json['groupAverageReturnPercent'] as double? ?? 0,
        groupAverageReturnDollars =
            json['groupAverageReturnDollars'] as double? ?? 0,
        totalMembersTraded = json['totalMembersTraded'] as int? ?? 0,
        totalGroupTrades = json['totalGroupTrades'] as int? ?? 0,
        groupWinRate = json['groupWinRate'] as double? ?? 0,
        groupAverageSharpeRatio =
            json['groupAverageSharpeRatio'] as double? ?? 0,
        topPerformerReturnPercent =
            json['topPerformerReturnPercent'] as double? ?? 0,
        topPerformerId = json['topPerformerId'] as String?,
        membersWithPositiveReturn =
            json['membersWithPositiveReturn'] as int? ?? 0,
        membersWithNegativeReturn =
            json['membersWithNegativeReturn'] as int? ?? 0,
        timeRangeStart = json['timeRangeStart'] != null
            ? DateTime.parse(json['timeRangeStart'] as String)
            : null,
        timeRangeEnd = json['timeRangeEnd'] != null
            ? DateTime.parse(json['timeRangeEnd'] as String)
            : null;

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'groupTotalReturnPercent': groupTotalReturnPercent,
      'groupTotalReturnDollars': groupTotalReturnDollars,
      'groupAverageReturnPercent': groupAverageReturnPercent,
      'groupAverageReturnDollars': groupAverageReturnDollars,
      'totalMembersTraded': totalMembersTraded,
      'totalGroupTrades': totalGroupTrades,
      'groupWinRate': groupWinRate,
      'groupAverageSharpeRatio': groupAverageSharpeRatio,
      'topPerformerReturnPercent': topPerformerReturnPercent,
      'topPerformerId': topPerformerId,
      'membersWithPositiveReturn': membersWithPositiveReturn,
      'membersWithNegativeReturn': membersWithNegativeReturn,
      'timeRangeStart': timeRangeStart?.toIso8601String(),
      'timeRangeEnd': timeRangeEnd?.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'GroupPerformanceMetrics(groupId: $groupId, groupTotalReturnPercent: $groupTotalReturnPercent, totalMembersTraded: $totalMembersTraded)';
}

/// Enumeration for time period filters
enum TimePeriodFilter {
  oneWeek,
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  allTime,
}

extension TimePeriodFilterExt on TimePeriodFilter {
  String get displayName {
    switch (this) {
      case TimePeriodFilter.oneWeek:
        return '1 Week';
      case TimePeriodFilter.oneMonth:
        return '1 Month';
      case TimePeriodFilter.threeMonths:
        return '3 Months';
      case TimePeriodFilter.sixMonths:
        return '6 Months';
      case TimePeriodFilter.oneYear:
        return '1 Year';
      case TimePeriodFilter.allTime:
        return 'All Time';
    }
  }

  DateTime? getStartDate() {
    final now = DateTime.now();
    switch (this) {
      case TimePeriodFilter.oneWeek:
        return now.subtract(const Duration(days: 7));
      case TimePeriodFilter.oneMonth:
        return now.subtract(const Duration(days: 30));
      case TimePeriodFilter.threeMonths:
        return now.subtract(const Duration(days: 90));
      case TimePeriodFilter.sixMonths:
        return now.subtract(const Duration(days: 180));
      case TimePeriodFilter.oneYear:
        return now.subtract(const Duration(days: 365));
      case TimePeriodFilter.allTime:
        return null;
    }
  }
}
