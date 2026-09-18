import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a follow relationship where [followerId] follows [followingId].
class UserFollow {
  final String id;
  final String followerId;
  final String followerName;
  final String? followerPhotoUrl;
  final String followingId;
  final String followingName;
  final String? followingPhotoUrl;
  final DateTime createdAt;
  final bool notificationsEnabled;

  const UserFollow({
    required this.id,
    required this.followerId,
    required this.followerName,
    this.followerPhotoUrl,
    required this.followingId,
    required this.followingName,
    this.followingPhotoUrl,
    required this.createdAt,
    this.notificationsEnabled = true,
  });

  factory UserFollow.fromJson(Map<String, dynamic> json, [String? docId]) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return UserFollow(
      id: docId ?? (json['id'] as String? ?? ''),
      followerId: json['followerId'] as String? ?? '',
      followerName: json['followerName'] as String? ?? 'Anonymous',
      followerPhotoUrl: json['followerPhotoUrl'] as String?,
      followingId: json['followingId'] as String? ?? '',
      followingName: json['followingName'] as String? ?? 'Anonymous',
      followingPhotoUrl: json['followingPhotoUrl'] as String?,
      createdAt: parseDate(json['createdAt']),
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'followerId': followerId,
      'followerName': followerName,
      if (followerPhotoUrl != null) 'followerPhotoUrl': followerPhotoUrl,
      'followingId': followingId,
      'followingName': followingName,
      if (followingPhotoUrl != null) 'followingPhotoUrl': followingPhotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'notificationsEnabled': notificationsEnabled,
    };
  }

  UserFollow copyWith({
    String? id,
    String? followerId,
    String? followerName,
    String? followerPhotoUrl,
    String? followingId,
    String? followingName,
    String? followingPhotoUrl,
    DateTime? createdAt,
    bool? notificationsEnabled,
  }) {
    return UserFollow(
      id: id ?? this.id,
      followerId: followerId ?? this.followerId,
      followerName: followerName ?? this.followerName,
      followerPhotoUrl: followerPhotoUrl ?? this.followerPhotoUrl,
      followingId: followingId ?? this.followingId,
      followingName: followingName ?? this.followingName,
      followingPhotoUrl: followingPhotoUrl ?? this.followingPhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
