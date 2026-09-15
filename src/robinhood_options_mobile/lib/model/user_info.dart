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

  UserInfo({
    required this.url,
    required this.id,
    required this.idInfo,
    required this.username,
    this.email,
    this.firstName,
    this.lastName,
    this.locality,
    this.profileName,
    this.createdAt,
    this.lastLoginTime,
  });

  UserInfo.fromJson(dynamic json)
    : url = (json['url'] as String?) ?? '',
      id = (json['id'] as String?) ?? '',
      idInfo = (json['id_info'] as String?) ?? '',
      username = (json['username'] as String?) ?? '',
      email = json['email'] as String?,
      firstName =
          (json['first_name'] as String?) ??
          (json['basic_info'] != null
              ? json['basic_info']['first_name'] as String?
              : null),
      lastName =
          (json['last_name'] as String?) ??
          (json['basic_info'] != null
              ? json['basic_info']['last_name'] as String?
              : null),
      locality =
          (json['locality'] as String?) ??
          (json['origin'] != null
              ? json['origin']['locality'] as String?
              : (json['basic_info'] != null
                    ? (json['basic_info']['locality'] as String? ??
                          json['basic_info']['city'] as String?)
                    : null)), // Robinhood uses origin.locality, Firebase stores this object which is flattened by design.
      profileName = json['profile_name'] as String?,
      createdAt = json['created_at'] != null
          ? (json['created_at'] is Timestamp
                ? (json['created_at'] as Timestamp).toDate()
                : DateTime.tryParse(json['created_at'].toString()))
          : null,
      lastLoginTime = json['last_login_time'] is Timestamp
          ? (json['last_login_time'] as Timestamp).toDate()
          : (json['last_login_time'] != null
                ? DateTime.tryParse(json['last_login_time'].toString())
                : null);

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
