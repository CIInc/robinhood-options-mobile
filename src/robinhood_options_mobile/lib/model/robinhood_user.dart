import 'package:flutter/material.dart';

import 'package:oauth2/oauth2.dart' as oauth2;

//@immutable
class RobinhoodUser {
  final String userName;
  final String credentials;
  oauth2.Client oauth2Client;

  RobinhoodUser(this.userName, this.credentials, this.oauth2Client);

  RobinhoodUser.fromJson(Map<String, dynamic> json)
      : userName = json['userName'],
        credentials = json['credentials'];

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'credentials': credentials,
      };
}
