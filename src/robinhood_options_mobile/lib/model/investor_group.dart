import 'package:cloud_firestore/cloud_firestore.dart';

/// Copy trade settings for a member in an investor group
class CopyTradeSettings {
  bool enabled;
  String? targetUserId; // User whose trades to copy
  bool autoExecute; // If true, automatically execute trades
  double?
      copyPercentage; // Percentage of the original trade size to copy (0-100)
  double? maxQuantity; // Maximum quantity to copy
  double? maxAmount; // Maximum dollar amount to copy
  double? maxDailyAmount; // Maximum total dollar amount to copy per day
  bool?
      overridePrice; // If true, use current market price instead of copied price

  CopyTradeSettings({
    this.enabled = false,
    this.targetUserId,
    this.autoExecute = false,
    this.copyPercentage,
    this.maxQuantity,
    this.maxAmount,
    this.maxDailyAmount,
    this.overridePrice = false,
  });

  CopyTradeSettings.fromJson(Map<String, Object?> json)
      : enabled = json['enabled'] as bool? ?? false,
        targetUserId = json['targetUserId'] as String?,
        autoExecute = json['autoExecute'] as bool? ?? false,
        copyPercentage = json['copyPercentage'] as double?,
        maxQuantity = json['maxQuantity'] as double?,
        maxAmount = json['maxAmount'] as double?,
        maxDailyAmount = json['maxDailyAmount'] as double?,
        overridePrice = json['overridePrice'] as bool? ?? false;

  Map<String, Object?> toJson() {
    return {
      'enabled': enabled,
      'targetUserId': targetUserId,
      'autoExecute': autoExecute,
      'copyPercentage': copyPercentage,
      'maxQuantity': maxQuantity,
      'maxAmount': maxAmount,
      'maxDailyAmount': maxDailyAmount,
      'overridePrice': overridePrice,
    };
  }
}

class InvestorGroup {
  String id;
  String name;
  String? description;
  String createdBy; // User ID of creator
  List<String> members; // List of user IDs
  List<String>? admins; // List of user IDs who are admins
  List<String>? pendingInvitations; // List of user IDs with pending invitations
  DateTime dateCreated;
  DateTime? dateUpdated;
  bool isPrivate; // If true, requires approval to join
  Map<String, CopyTradeSettings>?
      memberCopyTradeSettings; // Copy trade settings per member

  InvestorGroup({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    required this.members,
    this.admins,
    this.pendingInvitations,
    required this.dateCreated,
    this.dateUpdated,
    this.isPrivate = true,
    this.memberCopyTradeSettings,
  });

  InvestorGroup.fromJson(Map<String, Object?> json)
      : this(
          id: json['id'] as String,
          name: json['name'] as String,
          description: json['description'] as String?,
          createdBy: json['createdBy'] as String,
          members: json['members'] != null
              ? List<String>.from(json['members'] as Iterable<dynamic>)
              : [],
          admins: json['admins'] != null
              ? List<String>.from(json['admins'] as Iterable<dynamic>)
              : null,
          pendingInvitations: json['pendingInvitations'] != null
              ? List<String>.from(
                  json['pendingInvitations'] as Iterable<dynamic>)
              : null,
          dateCreated: (json['dateCreated'] as Timestamp).toDate(),
          dateUpdated: json['dateUpdated'] != null
              ? (json['dateUpdated'] as Timestamp).toDate()
              : null,
          isPrivate:
              json['isPrivate'] != null ? json['isPrivate'] as bool : true,
          memberCopyTradeSettings: json['memberCopyTradeSettings'] != null
              ? (json['memberCopyTradeSettings'] as Map<String, dynamic>).map(
                  (key, value) => MapEntry(
                      key,
                      CopyTradeSettings.fromJson(
                          value as Map<String, Object?>)))
              : null,
        );

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'members': members,
      'admins': admins,
      'pendingInvitations': pendingInvitations,
      'dateCreated': dateCreated,
      'dateUpdated': dateUpdated,
      'isPrivate': isPrivate,
      'memberCopyTradeSettings': memberCopyTradeSettings
          ?.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  static List<InvestorGroup> fromJsonArray(dynamic json) {
    List<InvestorGroup> list = [];
    for (int i = 0; i < json.length; i++) {
      list.add(InvestorGroup.fromJson(json[i]));
    }
    return list;
  }

  bool isMember(String userId) {
    return members.contains(userId);
  }

  bool isAdmin(String userId) {
    return admins?.contains(userId) ?? false || createdBy == userId;
  }

  bool hasPendingInvitation(String userId) {
    return pendingInvitations?.contains(userId) ?? false;
  }

  CopyTradeSettings? getCopyTradeSettings(String userId) {
    return memberCopyTradeSettings?[userId];
  }

  void setCopyTradeSettings(String userId, CopyTradeSettings settings) {
    memberCopyTradeSettings ??= {};
    memberCopyTradeSettings![userId] = settings;
  }
}
