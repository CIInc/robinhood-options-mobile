import 'package:cloud_firestore/cloud_firestore.dart';

class InvestorGroup {
  String id;
  String name;
  String? description;
  String createdBy; // User ID of creator
  List<String> members; // List of user IDs
  List<String>? admins; // List of user IDs who are admins
  DateTime dateCreated;
  DateTime? dateUpdated;
  bool isPrivate; // If true, requires approval to join

  InvestorGroup({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    required this.members,
    this.admins,
    required this.dateCreated,
    this.dateUpdated,
    this.isPrivate = true,
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
          dateCreated: (json['dateCreated'] as Timestamp).toDate(),
          dateUpdated: json['dateUpdated'] != null
              ? (json['dateUpdated'] as Timestamp).toDate()
              : null,
          isPrivate:
              json['isPrivate'] != null ? json['isPrivate'] as bool : true,
        );

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'members': members,
      'admins': admins,
      'dateCreated': dateCreated,
      'dateUpdated': dateUpdated,
      'isPrivate': isPrivate,
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
}
