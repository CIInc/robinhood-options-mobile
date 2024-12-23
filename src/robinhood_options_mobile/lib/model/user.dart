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
        locality = json['origin']['locality'],
        profileName = json['profile_name'],
        createdAt = DateTime.tryParse(json['created_at']),
        lastLoginTime = null;

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
        lastLoginTime = null; // DateTime.tryParse(json['lastLoginTime']);
}
