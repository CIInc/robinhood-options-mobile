import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/verified_track_record.dart';

/// Supported time periods for top portfolio leaderboard rankings.
enum LeaderboardTimePeriod {
  oneWeek,
  oneMonth,
  threeMonths,
  oneYear,
  allTime;

  String get label {
    switch (this) {
      case LeaderboardTimePeriod.oneWeek:
        return '1W';
      case LeaderboardTimePeriod.oneMonth:
        return '1M';
      case LeaderboardTimePeriod.threeMonths:
        return '3M';
      case LeaderboardTimePeriod.oneYear:
        return '1Y';
      case LeaderboardTimePeriod.allTime:
        return 'ALL';
    }
  }

  String get fullLabel {
    switch (this) {
      case LeaderboardTimePeriod.oneWeek:
        return '1 Week';
      case LeaderboardTimePeriod.oneMonth:
        return '1 Month';
      case LeaderboardTimePeriod.threeMonths:
        return '3 Months';
      case LeaderboardTimePeriod.oneYear:
        return '1 Year';
      case LeaderboardTimePeriod.allTime:
        return 'All Time';
    }
  }

  Duration? get duration {
    switch (this) {
      case LeaderboardTimePeriod.oneWeek:
        return const Duration(days: 7);
      case LeaderboardTimePeriod.oneMonth:
        return const Duration(days: 30);
      case LeaderboardTimePeriod.threeMonths:
        return const Duration(days: 90);
      case LeaderboardTimePeriod.oneYear:
        return const Duration(days: 365);
      case LeaderboardTimePeriod.allTime:
        return null;
    }
  }
}

/// Sorting options for top portfolios leaderboard.
enum LeaderboardSortOption {
  totalReturn,
  sharpeRatio,
  winRate,
  reputationScore,
  followersCount;

  String get label {
    switch (this) {
      case LeaderboardSortOption.totalReturn:
        return 'Highest Return';
      case LeaderboardSortOption.sharpeRatio:
        return 'Sharpe Ratio';
      case LeaderboardSortOption.winRate:
        return 'Win Rate';
      case LeaderboardSortOption.reputationScore:
        return 'Reputation';
      case LeaderboardSortOption.followersCount:
        return 'Most Followed';
    }
  }

  IconData get icon {
    switch (this) {
      case LeaderboardSortOption.totalReturn:
        return Icons.trending_up;
      case LeaderboardSortOption.sharpeRatio:
        return Icons.insights;
      case LeaderboardSortOption.winRate:
        return Icons.check_circle_outline;
      case LeaderboardSortOption.reputationScore:
        return Icons.military_tech_outlined;
      case LeaderboardSortOption.followersCount:
        return Icons.people_outline;
    }
  }
}

/// Classification of trader credibility and reputation.
enum ReputationTier {
  novice,
  activeTrader,
  trustedTrader,
  eliteTrader,
  masterTrader;

  String get label {
    switch (this) {
      case ReputationTier.novice:
        return 'Novice Trader';
      case ReputationTier.activeTrader:
        return 'Active Trader';
      case ReputationTier.trustedTrader:
        return 'Trusted Trader';
      case ReputationTier.eliteTrader:
        return 'Elite Trader';
      case ReputationTier.masterTrader:
        return 'Master Trader';
    }
  }

  Color get color {
    switch (this) {
      case ReputationTier.novice:
        return Colors.grey.shade600;
      case ReputationTier.activeTrader:
        return Colors.blue;
      case ReputationTier.trustedTrader:
        return Colors.green;
      case ReputationTier.eliteTrader:
        return Colors.amber.shade700;
      case ReputationTier.masterTrader:
        return Colors.purple;
    }
  }

  IconData get icon {
    switch (this) {
      case ReputationTier.novice:
        return Icons.shield_outlined;
      case ReputationTier.activeTrader:
        return Icons.trending_up_rounded;
      case ReputationTier.trustedTrader:
        return Icons.verified_user_rounded;
      case ReputationTier.eliteTrader:
        return Icons.military_tech_rounded;
      case ReputationTier.masterTrader:
        return Icons.workspace_premium_rounded;
    }
  }

  static ReputationTier fromScore(int score) {
    if (score >= 90) return ReputationTier.masterTrader;
    if (score >= 75) return ReputationTier.eliteTrader;
    if (score >= 50) return ReputationTier.trustedTrader;
    if (score >= 25) return ReputationTier.activeTrader;
    return ReputationTier.novice;
  }
}

/// Quantified reputation breakdown and total credibility score (0 - 100).
class UserReputation {
  final int score;
  final ReputationTier tier;
  final int verificationScore; // 0 - 35
  final int winRateScore; // 0 - 25
  final int returnScore; // 0 - 20
  final int activityScore; // 0 - 10
  final int communityScore; // 0 - 10

  const UserReputation({
    required this.score,
    required this.tier,
    this.verificationScore = 0,
    this.winRateScore = 0,
    this.returnScore = 0,
    this.activityScore = 0,
    this.communityScore = 0,
  });

  factory UserReputation.calculate({
    VerifiedTrackRecord? trackRecord,
    double returnPercent = 0.0,
    double winRate = 0.0,
    int totalTrades = 0,
    int followersCount = 0,
  }) {
    // 1. Verification score (up to 35 pts)
    int verificationPts = 0;
    if (trackRecord != null && trackRecord.isVerified) {
      switch (trackRecord.tier) {
        case VerifiedLeaderTier.masterTrader:
          verificationPts = 35;
          break;
        case VerifiedLeaderTier.topPerformer:
          verificationPts = 28;
          break;
        case VerifiedLeaderTier.verifiedLeader:
          verificationPts = 20;
          break;
        case VerifiedLeaderTier.verifiedTrader:
          verificationPts = 15;
          break;
      }
    }

    // 2. Win rate score (up to 25 pts)
    final effectiveWinRate = trackRecord?.verifiedWinRate ?? winRate;
    int winRatePts = 0;
    if (effectiveWinRate > 0) {
      winRatePts = ((effectiveWinRate / 100.0) * 25).round().clamp(0, 25);
    }

    // 3. Return score (up to 20 pts)
    final effectiveReturn = trackRecord?.verifiedReturnPercent ?? returnPercent;
    int returnPts = 0;
    if (effectiveReturn >= 100.0) {
      returnPts = 20;
    } else if (effectiveReturn > 0) {
      returnPts = ((effectiveReturn / 100.0) * 20).round().clamp(0, 20);
    }

    // 4. Activity & longevity (up to 10 pts)
    final effectiveTrades = trackRecord?.totalTradesAudited ?? totalTrades;
    int activityPts = 0;
    if (effectiveTrades >= 100) {
      activityPts = 10;
    } else if (effectiveTrades >= 50) {
      activityPts = 8;
    } else if (effectiveTrades >= 20) {
      activityPts = 5;
    } else if (effectiveTrades >= 5) {
      activityPts = 2;
    } else if (effectiveTrades > 0) {
      activityPts = 1;
    }

    // 5. Community trust & followers (up to 10 pts)
    int communityPts = 0;
    if (followersCount >= 100) {
      communityPts = 10;
    } else if (followersCount >= 50) {
      communityPts = 8;
    } else if (followersCount >= 20) {
      communityPts = 5;
    } else if (followersCount >= 5) {
      communityPts = 3;
    } else if (followersCount > 0) {
      communityPts = 1;
    }

    final totalScore =
        (verificationPts + winRatePts + returnPts + activityPts + communityPts)
            .clamp(0, 100);

    return UserReputation(
      score: totalScore,
      tier: ReputationTier.fromScore(totalScore),
      verificationScore: verificationPts,
      winRateScore: winRatePts,
      returnScore: returnPts,
      activityScore: activityPts,
      communityScore: communityPts,
    );
  }

  factory UserReputation.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UserReputation(
        score: 0,
        tier: ReputationTier.novice,
      );
    }
    final score = (json['score'] as num?)?.toInt() ?? 0;
    return UserReputation(
      score: score,
      tier: ReputationTier.fromScore(score),
      verificationScore: (json['verificationScore'] as num?)?.toInt() ?? 0,
      winRateScore: (json['winRateScore'] as num?)?.toInt() ?? 0,
      returnScore: (json['returnScore'] as num?)?.toInt() ?? 0,
      activityScore: (json['activityScore'] as num?)?.toInt() ?? 0,
      communityScore: (json['communityScore'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'tier': tier.name,
      'verificationScore': verificationScore,
      'winRateScore': winRateScore,
      'returnScore': returnScore,
      'activityScore': activityScore,
      'communityScore': communityScore,
    };
  }
}

/// A ranked entry on the top portfolios leaderboard.
class TopPortfolioEntry {
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String? location;
  final int followersCount;
  final int followingCount;
  final bool isPublic;
  final double returnPercent;
  final double winRate;
  final int totalTrades;
  final int winningTrades;
  final int losingTrades;
  final double sharpeRatio;
  final double maxDrawdownPercent;
  final double profitFactor;
  final Map<String, double> periodReturns;
  final VerifiedTrackRecord? verifiedTrackRecord;
  final UserReputation reputation;
  final int? rank;

  const TopPortfolioEntry({
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    this.location,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isPublic = true,
    required this.returnPercent,
    required this.winRate,
    this.totalTrades = 0,
    this.winningTrades = 0,
    this.losingTrades = 0,
    this.sharpeRatio = 0.0,
    this.maxDrawdownPercent = 0.0,
    this.profitFactor = 0.0,
    this.periodReturns = const {},
    this.verifiedTrackRecord,
    required this.reputation,
    this.rank,
  });

  bool get isVerified =>
      verifiedTrackRecord != null && verifiedTrackRecord!.isVerified;

  double returnForPeriod(LeaderboardTimePeriod period) {
    if (period == LeaderboardTimePeriod.allTime) {
      return returnPercent;
    }
    return periodReturns[period.label] ?? returnPercent;
  }

  TopPortfolioEntry copyWith({
    String? userId,
    String? userName,
    String? userPhotoUrl,
    String? location,
    int? followersCount,
    int? followingCount,
    bool? isPublic,
    double? returnPercent,
    double? winRate,
    int? totalTrades,
    int? winningTrades,
    int? losingTrades,
    double? sharpeRatio,
    double? maxDrawdownPercent,
    double? profitFactor,
    Map<String, double>? periodReturns,
    VerifiedTrackRecord? verifiedTrackRecord,
    UserReputation? reputation,
    int? rank,
  }) {
    return TopPortfolioEntry(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      location: location ?? this.location,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isPublic: isPublic ?? this.isPublic,
      returnPercent: returnPercent ?? this.returnPercent,
      winRate: winRate ?? this.winRate,
      totalTrades: totalTrades ?? this.totalTrades,
      winningTrades: winningTrades ?? this.winningTrades,
      losingTrades: losingTrades ?? this.losingTrades,
      sharpeRatio: sharpeRatio ?? this.sharpeRatio,
      maxDrawdownPercent: maxDrawdownPercent ?? this.maxDrawdownPercent,
      profitFactor: profitFactor ?? this.profitFactor,
      periodReturns: periodReturns ?? this.periodReturns,
      verifiedTrackRecord: verifiedTrackRecord ?? this.verifiedTrackRecord,
      reputation: reputation ?? this.reputation,
      rank: rank ?? this.rank,
    );
  }

  factory TopPortfolioEntry.fromJson(Map<String, dynamic> json, String id) {
    final verifiedJson = json['verifiedTrackRecord'] as Map<String, dynamic>?;
    final verifiedRecord = verifiedJson != null
        ? VerifiedTrackRecord.fromJson(verifiedJson, id)
        : null;

    final returnPercent = (json['returnPercent'] as num?)?.toDouble() ??
        (verifiedRecord?.verifiedReturnPercent ?? 0.0);
    final winRate = (json['winRate'] as num?)?.toDouble() ??
        (verifiedRecord?.verifiedWinRate ?? 0.0);
    final totalTrades = (json['totalTrades'] as num?)?.toInt() ??
        (verifiedRecord?.totalTradesAudited ?? 0);
    final followersCount = (json['followersCount'] as num?)?.toInt() ?? 0;

    final reputation = json['reputation'] != null
        ? UserReputation.fromJson(json['reputation'] as Map<String, dynamic>)
        : UserReputation.calculate(
            trackRecord: verifiedRecord,
            returnPercent: returnPercent,
            winRate: winRate,
            totalTrades: totalTrades,
            followersCount: followersCount,
          );

    final rawPeriods = json['periodReturns'] as Map<String, dynamic>?;
    final Map<String, double> periodReturns = {};
    if (rawPeriods != null) {
      rawPeriods.forEach((key, val) {
        if (val is num) periodReturns[key] = val.toDouble();
      });
    }

    return TopPortfolioEntry(
      userId: id,
      userName: json['userName'] as String? ?? 'Trader',
      userPhotoUrl: json['userPhotoUrl'] as String?,
      location: json['location'] as String?,
      followersCount: followersCount,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
      isPublic: json['isPublic'] as bool? ?? true,
      returnPercent: returnPercent,
      winRate: winRate,
      totalTrades: totalTrades,
      winningTrades: (json['winningTrades'] as num?)?.toInt() ??
          (verifiedRecord?.winningTrades ?? 0),
      losingTrades: (json['losingTrades'] as num?)?.toInt() ??
          (verifiedRecord?.losingTrades ?? 0),
      sharpeRatio: (json['sharpeRatio'] as num?)?.toDouble() ??
          (verifiedRecord?.sharpeRatio ?? 0.0),
      maxDrawdownPercent: (json['maxDrawdownPercent'] as num?)?.toDouble() ??
          (verifiedRecord?.maxDrawdownPercent ?? 0.0),
      profitFactor: (json['profitFactor'] as num?)?.toDouble() ??
          (verifiedRecord?.profitFactor ?? 0.0),
      periodReturns: periodReturns,
      verifiedTrackRecord: verifiedRecord,
      reputation: reputation,
      rank: (json['rank'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'location': location,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'isPublic': isPublic,
      'returnPercent': returnPercent,
      'winRate': winRate,
      'totalTrades': totalTrades,
      'winningTrades': winningTrades,
      'losingTrades': losingTrades,
      'sharpeRatio': sharpeRatio,
      'maxDrawdownPercent': maxDrawdownPercent,
      'profitFactor': profitFactor,
      'periodReturns': periodReturns,
      'verifiedTrackRecord': verifiedTrackRecord?.toJson(),
      'reputation': reputation.toJson(),
      'rank': rank,
    };
  }
}
