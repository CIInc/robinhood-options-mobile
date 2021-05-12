/*
{
  "url":"https://api.robinhood.com/user/",
  "id":"8e620d87-d864-4297-828b-c9b7662f2c2b",
  "id_info":"https://api.robinhood.com/user/id/",
  "username":"aymeric",
  "email":"aymeric@grassart.com",
  "email_verified":true,
  "first_name":"Aymeric",
  "last_name":"Grassart",
  "origin":{
    "locality":"US"
  },
  "profile_name":"Aymeric",
  "created_at":"2015-02-11T13:14:48.784036-05:00"
}
*/
class User {
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

  User(
      this.url,
      this.id,
      this.idInfo,
      this.username,
      this.email,
      this.firstName,
      this.lastName,
      this.locality,
      this.profileName,
      this.createdAt);

  User.fromJson(dynamic json)
      : url = json['url'],
        id = json['id'],
        idInfo = json['id_info'],
        username = json['username'],
        email = json['email'],
        firstName = json['first_name'],
        lastName = json['last_name'],
        locality = json['origin']['locality'],
        profileName = json['profile_name'],
        createdAt = DateTime.tryParse(json['created_at']);
}
