import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Sentiment classification for an investment thesis or analysis post.
enum GroupAnalysisSentiment {
  bullish,
  bearish,
  neutral;

  String get label {
    switch (this) {
      case GroupAnalysisSentiment.bullish:
        return 'Bullish';
      case GroupAnalysisSentiment.bearish:
        return 'Bearish';
      case GroupAnalysisSentiment.neutral:
        return 'Neutral';
    }
  }

  Color get color {
    switch (this) {
      case GroupAnalysisSentiment.bullish:
        return Colors.green;
      case GroupAnalysisSentiment.bearish:
        return Colors.red;
      case GroupAnalysisSentiment.neutral:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case GroupAnalysisSentiment.bullish:
        return Icons.trending_up_rounded;
      case GroupAnalysisSentiment.bearish:
        return Icons.trending_down_rounded;
      case GroupAnalysisSentiment.neutral:
        return Icons.trending_flat_rounded;
    }
  }

  static GroupAnalysisSentiment fromString(String? value) {
    if (value == null) return GroupAnalysisSentiment.neutral;
    switch (value.toLowerCase()) {
      case 'bullish':
      case 'bull':
        return GroupAnalysisSentiment.bullish;
      case 'bearish':
      case 'bear':
        return GroupAnalysisSentiment.bearish;
      default:
        return GroupAnalysisSentiment.neutral;
    }
  }
}

/// Time horizon for an investment thesis.
enum GroupAnalysisTimeHorizon {
  shortTerm,
  mediumTerm,
  longTerm;

  String get label {
    switch (this) {
      case GroupAnalysisTimeHorizon.shortTerm:
        return 'Short Term (< 1 mo)';
      case GroupAnalysisTimeHorizon.mediumTerm:
        return 'Medium Term (1-6 mo)';
      case GroupAnalysisTimeHorizon.longTerm:
        return 'Long Term (> 6 mo)';
    }
  }

  static GroupAnalysisTimeHorizon fromString(String? value) {
    if (value == null) return GroupAnalysisTimeHorizon.mediumTerm;
    switch (value.toLowerCase()) {
      case 'shortterm':
      case 'short_term':
      case 'short':
        return GroupAnalysisTimeHorizon.shortTerm;
      case 'longterm':
      case 'long_term':
      case 'long':
        return GroupAnalysisTimeHorizon.longTerm;
      default:
        return GroupAnalysisTimeHorizon.mediumTerm;
    }
  }
}

/// A shared investment thesis, analysis, or trade idea posted to an Investor Group.
class GroupAnalysisPost {
  final String id;
  final String groupId;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String title;
  final String symbol;
  final GroupAnalysisSentiment sentiment;
  final String thesis;
  final double? entryTarget;
  final double? targetPrice;
  final double? stopLoss;
  final GroupAnalysisTimeHorizon timeHorizon;
  final bool isPinned;
  final List<String> likes;
  final int commentsCount;
  final List<String> tags;
  final Map<String, String> sentimentVotes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  GroupAnalysisPost({
    required this.id,
    required this.groupId,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.title,
    required this.symbol,
    required this.sentiment,
    required this.thesis,
    this.entryTarget,
    this.targetPrice,
    this.stopLoss,
    this.timeHorizon = GroupAnalysisTimeHorizon.mediumTerm,
    this.isPinned = false,
    this.likes = const [],
    this.commentsCount = 0,
    this.tags = const [],
    this.sentimentVotes = const {},
    required this.createdAt,
    this.updatedAt,
  });

  /// Potential return percentage from entryTarget to targetPrice.
  double? get potentialReturnPercent {
    if (entryTarget == null || targetPrice == null || entryTarget == 0) {
      return null;
    }
    return ((targetPrice! - entryTarget!) / entryTarget!) * 100.0;
  }

  /// Risk / Reward ratio calculated as (targetPrice - entryTarget) / (entryTarget - stopLoss).
  double? get riskRewardRatio {
    if (entryTarget == null || targetPrice == null || stopLoss == null) {
      return null;
    }
    final reward = (targetPrice! - entryTarget!).abs();
    final risk = (entryTarget! - stopLoss!).abs();
    if (risk == 0) return null;
    return reward / risk;
  }

  bool isLikedBy(String userId) => likes.contains(userId);

  /// Community sentiment polling getters
  int get bullishVotes =>
      sentimentVotes.values.where((v) => v.toLowerCase() == 'bullish').length;
  int get bearishVotes =>
      sentimentVotes.values.where((v) => v.toLowerCase() == 'bearish').length;
  int get neutralVotes =>
      sentimentVotes.values.where((v) => v.toLowerCase() == 'neutral').length;
  int get totalPollVotes => sentimentVotes.length;
  double get bullishPollPct =>
      totalPollVotes == 0 ? 0.0 : (bullishVotes / totalPollVotes) * 100.0;
  double get bearishPollPct =>
      totalPollVotes == 0 ? 0.0 : (bearishVotes / totalPollVotes) * 100.0;
  double get neutralPollPct =>
      totalPollVotes == 0 ? 0.0 : (neutralVotes / totalPollVotes) * 100.0;
  String? userPollVote(String userId) => sentimentVotes[userId];

  factory GroupAnalysisPost.fromJson(
      Map<String, dynamic> json, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawVotes = json['sentimentVotes'];
    final parsedVotes = <String, String>{};
    if (rawVotes is Map) {
      rawVotes.forEach((key, val) {
        if (key != null && val != null) {
          parsedVotes[key.toString()] = val.toString();
        }
      });
    }

    return GroupAnalysisPost(
      id: documentId,
      groupId: json['groupId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? 'Anonymous Member',
      authorPhotoUrl: json['authorPhotoUrl'] as String?,
      title: json['title'] as String? ?? '',
      symbol: (json['symbol'] as String? ?? '').toUpperCase(),
      sentiment:
          GroupAnalysisSentiment.fromString(json['sentiment'] as String?),
      thesis: json['thesis'] as String? ?? '',
      entryTarget: (json['entryTarget'] as num?)?.toDouble(),
      targetPrice: (json['targetPrice'] as num?)?.toDouble(),
      stopLoss: (json['stopLoss'] as num?)?.toDouble(),
      timeHorizon:
          GroupAnalysisTimeHorizon.fromString(json['timeHorizon'] as String?),
      isPinned: json['isPinned'] as bool? ?? false,
      likes: (json['likes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              const [],
      sentimentVotes: parsedVotes,
      createdAt: parseDate(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? parseDate(json['updatedAt']) : null,
    );
  }

  factory GroupAnalysisPost.fromDocument(DocumentSnapshot doc) {
    return GroupAnalysisPost.fromJson(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'authorId': authorId,
      'authorName': authorName,
      if (authorPhotoUrl != null) 'authorPhotoUrl': authorPhotoUrl,
      'title': title,
      'symbol': symbol,
      'sentiment': sentiment.name,
      'thesis': thesis,
      if (entryTarget != null) 'entryTarget': entryTarget,
      if (targetPrice != null) 'targetPrice': targetPrice,
      if (stopLoss != null) 'stopLoss': stopLoss,
      'timeHorizon': timeHorizon.name,
      'isPinned': isPinned,
      'likes': likes,
      'commentsCount': commentsCount,
      'tags': tags,
      if (sentimentVotes.isNotEmpty) 'sentimentVotes': sentimentVotes,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  GroupAnalysisPost copyWith({
    String? id,
    String? groupId,
    String? authorId,
    String? authorName,
    String? authorPhotoUrl,
    String? title,
    String? symbol,
    GroupAnalysisSentiment? sentiment,
    String? thesis,
    double? entryTarget,
    double? targetPrice,
    double? stopLoss,
    GroupAnalysisTimeHorizon? timeHorizon,
    bool? isPinned,
    List<String>? likes,
    int? commentsCount,
    List<String>? tags,
    Map<String, String>? sentimentVotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GroupAnalysisPost(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      title: title ?? this.title,
      symbol: symbol ?? this.symbol,
      sentiment: sentiment ?? this.sentiment,
      thesis: thesis ?? this.thesis,
      entryTarget: entryTarget ?? this.entryTarget,
      targetPrice: targetPrice ?? this.targetPrice,
      stopLoss: stopLoss ?? this.stopLoss,
      timeHorizon: timeHorizon ?? this.timeHorizon,
      isPinned: isPinned ?? this.isPinned,
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
      tags: tags ?? this.tags,
      sentimentVotes: sentimentVotes ?? this.sentimentVotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// A comment posted to a shared analysis or portfolio discussion thread.
class GroupAnalysisComment {
  final String id;
  final String analysisId;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String content;
  final bool isPinned;
  final List<String> likes;
  final bool isReported;
  final String? reportReason;
  final List<String> reportedBy;
  final DateTime createdAt;

  GroupAnalysisComment({
    required this.id,
    required this.analysisId,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.content,
    this.isPinned = false,
    this.likes = const [],
    this.isReported = false,
    this.reportReason,
    this.reportedBy = const [],
    required this.createdAt,
  });

  bool isLikedBy(String userId) => likes.contains(userId);
  int get upvotesCount => likes.length;
  bool isReportedBy(String userId) => reportedBy.contains(userId);

  factory GroupAnalysisComment.fromJson(
      Map<String, dynamic> json, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return GroupAnalysisComment(
      id: documentId,
      analysisId: json['analysisId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? 'Anonymous Member',
      authorPhotoUrl: json['authorPhotoUrl'] as String?,
      content: json['content'] as String? ?? '',
      isPinned: json['isPinned'] as bool? ?? false,
      likes: (json['likes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isReported: json['isReported'] as bool? ?? false,
      reportReason: json['reportReason'] as String?,
      reportedBy: (json['reportedBy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: parseDate(json['createdAt']),
    );
  }

  factory GroupAnalysisComment.fromDocument(DocumentSnapshot doc) {
    return GroupAnalysisComment.fromJson(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'analysisId': analysisId,
      'authorId': authorId,
      'authorName': authorName,
      if (authorPhotoUrl != null) 'authorPhotoUrl': authorPhotoUrl,
      'content': content,
      'isPinned': isPinned,
      'likes': likes,
      'isReported': isReported,
      if (reportReason != null) 'reportReason': reportReason,
      'reportedBy': reportedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  GroupAnalysisComment copyWith({
    String? id,
    String? analysisId,
    String? authorId,
    String? authorName,
    String? authorPhotoUrl,
    String? content,
    bool? isPinned,
    List<String>? likes,
    bool? isReported,
    String? reportReason,
    List<String>? reportedBy,
    DateTime? createdAt,
  }) {
    return GroupAnalysisComment(
      id: id ?? this.id,
      analysisId: analysisId ?? this.analysisId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      content: content ?? this.content,
      isPinned: isPinned ?? this.isPinned,
      likes: likes ?? this.likes,
      isReported: isReported ?? this.isReported,
      reportReason: reportReason ?? this.reportReason,
      reportedBy: reportedBy ?? this.reportedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
