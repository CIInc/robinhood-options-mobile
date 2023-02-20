class UserInfo {
  // Robinhood
  final String url;
  final String id;
  final String idInfo;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String locality;
  final String profileName;
  final DateTime? createdAt;
  // TD Ameritrade
  final DateTime? lastLoginTime;

  UserInfo(
      this.url,
      this.id,
      this.idInfo,
      this.username,
      this.email,
      this.firstName,
      this.lastName,
      this.locality,
      this.profileName,
      this.createdAt,
      this.lastLoginTime);

  UserInfo.fromJson(dynamic json)
      : url = json['url'],
        id = json['id'],
        idInfo = json['id_info'],
        username = json['username'],
        email = json['email'],
        firstName = json['first_name'],
        lastName = json['last_name'],
        locality = json['origin']['locality'],
        profileName = json['profile_name'],
        createdAt = DateTime.tryParse(json['created_at']),
        lastLoginTime = null;

  UserInfo.fromTdAmeritradeJson(dynamic json)
      : url = '',
        id = json['userId'],
        idInfo = '',
        username = json['userId'],
        email = '',
        firstName = '',
        lastName = '',
        locality = '',
        profileName = json['userId'],
        createdAt = null,
        lastLoginTime = DateTime.tryParse(json['lastLoginTime']);
}
