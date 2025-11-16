import 'package:cloud_firestore/cloud_firestore.dart';

class UserInfo {
  // Robinhood
  final String url;
  final String id;
  final String idInfo;
  final String username;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? locality;
  final String? profileName;
  final DateTime? createdAt;
  // TD Ameritrade
  final DateTime? lastLoginTime;

  UserInfo(
      {required this.url,
      required this.id,
      required this.idInfo,
      required this.username,
      this.email,
      this.firstName,
      this.lastName,
      this.locality,
      this.profileName,
      this.createdAt,
      this.lastLoginTime});

  UserInfo.fromJson(dynamic json)
      : url = json['url'],
        id = json['id'],
        idInfo = json['id_info'],
        username = json['username'],
        email = json['email'],
        firstName = json['first_name'],
        lastName = json['last_name'],
        locality = json['locality'] ??
            (json['origin'] != null
                ? json['origin']['locality']
                : null), // Robinhood uses origin.locality, Firebase stores this object which is flattened by design.
        profileName = json['profile_name'],
        createdAt = json['created_at'] != null
            ? (json['created_at'] is Timestamp
                ? (json['created_at'] as Timestamp).toDate()
                : DateTime.tryParse(json['created_at']))
            : null,
        lastLoginTime = json['last_login_time'] is Timestamp
            ? (json['last_login_time'] as Timestamp).toDate()
            : null;

  UserInfo.fromSchwab(dynamic json)
      : url = '',
        id = json['accounts'][0]['accountNumber'],
        idInfo = '',
        username = json['accounts'][0]['nickName'],
        email = '',
        firstName = '',
        lastName = '',
        locality = null,
        profileName = json['accounts'][0]['nickName'],
        createdAt = null,
        lastLoginTime = null;

  Map<String, Object?> toJson() {
    return {
      'url': url,
      'id': id,
      'id_info': idInfo,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'locality': locality,
      'profile_name': profileName,
      'created_at': createdAt,
      // 'last_login_time': lastLoginTime,
    };
  }
}
