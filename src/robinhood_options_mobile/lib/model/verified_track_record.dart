import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Badge classification for a verified track record.
enum VerifiedLeaderTier {
  verifiedTrader,
  verifiedLeader,
  topPerformer,
  masterTrader;

  String get label {
    switch (this) {
      case VerifiedLeaderTier.verifiedTrader:
        return 'Verified Trader';
      case VerifiedLeaderTier.verifiedLeader:
        return 'Verified Leader';
      case VerifiedLeaderTier.topPerformer:
        return 'Top Performer';
      case VerifiedLeaderTier.masterTrader:
        return 'Master Trader';
    }
  }

  Color get color {
    switch (this) {
      case VerifiedLeaderTier.verifiedTrader:
        return Colors.blue;
      case VerifiedLeaderTier.verifiedLeader:
        return Colors.green;
      case VerifiedLeaderTier.topPerformer:
        return Colors.amber.shade700;
      case VerifiedLeaderTier.masterTrader:
        return Colors.purple;
    }
  }

  IconData get icon {
    switch (this) {
      case VerifiedLeaderTier.verifiedTrader:
        return Icons.verified_user_rounded;
      case VerifiedLeaderTier.verifiedLeader:
        return Icons.verified_rounded;
      case VerifiedLeaderTier.topPerformer:
        return Icons.military_tech_rounded;
      case VerifiedLeaderTier.masterTrader:
        return Icons.workspace_premium_rounded;
    }
  }

  static VerifiedLeaderTier fromMetrics({
    required double returnPercent,
    required double winRate,
    required int totalTrades,
  }) {
    if (totalTrades >= 50 && returnPercent >= 50.0 && winRate >= 65.0) {
      return VerifiedLeaderTier.masterTrader;
    }
    if (totalTrades >= 25 && returnPercent >= 25.0 && winRate >= 55.0) {
      return VerifiedLeaderTier.topPerformer;
    }
    if (totalTrades >= 10 && returnPercent >= 0.0) {
      return VerifiedLeaderTier.verifiedLeader;
    }
    return VerifiedLeaderTier.verifiedTrader;
  }
}

/// A broker-verified performance track record for an investor group leader or member.
class VerifiedTrackRecord {
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String? groupId;
  final bool isVerified;
  final VerifiedLeaderTier tier;
  final double verifiedReturnPercent;
  final double verifiedWinRate; // 0-100%
  final int totalTradesAudited;
  final int winningTrades;
  final int losingTrades;
  final double sharpeRatio;
  final double maxDrawdownPercent;
  final double profitFactor;
  final DateTime verificationDate;
  final String verificationSource;
  final Map<String, double> monthlyReturns;

  VerifiedTrackRecord({
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    this.groupId,
    this.isVerified = true,
    required this.tier,
    required this.verifiedReturnPercent,
    required this.verifiedWinRate,
    required this.totalTradesAudited,
    this.winningTrades = 0,
    this.losingTrades = 0,
    this.sharpeRatio = 0.0,
    this.maxDrawdownPercent = 0.0,
    this.profitFactor = 1.0,
    required this.verificationDate,
    this.verificationSource = 'Robinhood Authenticated API',
    this.monthlyReturns = const {},
  });

  factory VerifiedTrackRecord.fromJson(
      Map<String, dynamic> json, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final tierStr = json['tier'] as String?;
    VerifiedLeaderTier tier;
    if (tierStr != null) {
      tier = VerifiedLeaderTier.values.firstWhere(
        (t) => t.name == tierStr,
        orElse: () => VerifiedLeaderTier.verifiedLeader,
      );
    } else {
      tier = VerifiedLeaderTier.fromMetrics(
        returnPercent: (json['verifiedReturnPercent'] as num?)?.toDouble() ?? 0,
        winRate: (json['verifiedWinRate'] as num?)?.toDouble() ?? 0,
        totalTrades: (json['totalTradesAudited'] as num?)?.toInt() ?? 0,
      );
    }

    Map<String, double> monthly = {};
    if (json['monthlyReturns'] is Map) {
      (json['monthlyReturns'] as Map).forEach((k, v) {
        if (v is num) {
          monthly[k.toString()] = v.toDouble();
        }
      });
    }

    return VerifiedTrackRecord(
      userId: documentId,
      userName: json['userName'] as String? ?? 'Group Leader',
      userPhotoUrl: json['userPhotoUrl'] as String?,
      groupId: json['groupId'] as String?,
      isVerified: json['isVerified'] as bool? ?? true,
      tier: tier,
      verifiedReturnPercent:
          (json['verifiedReturnPercent'] as num?)?.toDouble() ?? 0.0,
      verifiedWinRate: (json['verifiedWinRate'] as num?)?.toDouble() ?? 0.0,
      totalTradesAudited: (json['totalTradesAudited'] as num?)?.toInt() ?? 0,
      winningTrades: (json['winningTrades'] as num?)?.toInt() ?? 0,
      losingTrades: (json['losingTrades'] as num?)?.toInt() ?? 0,
      sharpeRatio: (json['sharpeRatio'] as num?)?.toDouble() ?? 0.0,
      maxDrawdownPercent:
          (json['maxDrawdownPercent'] as num?)?.toDouble() ?? 0.0,
      profitFactor: (json['profitFactor'] as num?)?.toDouble() ?? 1.0,
      verificationDate: parseDate(json['verificationDate']),
      verificationSource: json['verificationSource'] as String? ??
          'Robinhood Authenticated API',
      monthlyReturns: monthly,
    );
  }

  factory VerifiedTrackRecord.fromDocument(DocumentSnapshot doc) {
    return VerifiedTrackRecord.fromJson(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      if (userPhotoUrl != null) 'userPhotoUrl': userPhotoUrl,
      if (groupId != null) 'groupId': groupId,
      'isVerified': isVerified,
      'tier': tier.name,
      'verifiedReturnPercent': verifiedReturnPercent,
      'verifiedWinRate': verifiedWinRate,
      'totalTradesAudited': totalTradesAudited,
      'winningTrades': winningTrades,
      'losingTrades': losingTrades,
      'sharpeRatio': sharpeRatio,
      'maxDrawdownPercent': maxDrawdownPercent,
      'profitFactor': profitFactor,
      'verificationDate': Timestamp.fromDate(verificationDate),
      'verificationSource': verificationSource,
      'monthlyReturns': monthlyReturns,
    };
  }

  VerifiedTrackRecord copyWith({
    String? userId,
    String? userName,
    String? userPhotoUrl,
    String? groupId,
    bool? isVerified,
    VerifiedLeaderTier? tier,
    double? verifiedReturnPercent,
    double? verifiedWinRate,
    int? totalTradesAudited,
    int? winningTrades,
    int? losingTrades,
    double? sharpeRatio,
    double? maxDrawdownPercent,
    double? profitFactor,
    DateTime? verificationDate,
    String? verificationSource,
    Map<String, double>? monthlyReturns,
  }) {
    return VerifiedTrackRecord(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      groupId: groupId ?? this.groupId,
      isVerified: isVerified ?? this.isVerified,
      tier: tier ?? this.tier,
      verifiedReturnPercent:
          verifiedReturnPercent ?? this.verifiedReturnPercent,
      verifiedWinRate: verifiedWinRate ?? this.verifiedWinRate,
      totalTradesAudited: totalTradesAudited ?? this.totalTradesAudited,
      winningTrades: winningTrades ?? this.winningTrades,
      losingTrades: losingTrades ?? this.losingTrades,
      sharpeRatio: sharpeRatio ?? this.sharpeRatio,
      maxDrawdownPercent: maxDrawdownPercent ?? this.maxDrawdownPercent,
      profitFactor: profitFactor ?? this.profitFactor,
      verificationDate: verificationDate ?? this.verificationDate,
      verificationSource: verificationSource ?? this.verificationSource,
      monthlyReturns: monthlyReturns ?? this.monthlyReturns,
    );
  }
}
