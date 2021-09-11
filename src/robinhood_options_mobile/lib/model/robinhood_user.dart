import 'dart:convert';

import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/services/store.dart';

//@immutable
class RobinhoodUser {
  final String? userName;
  final String? credentials;
  oauth2.Client? oauth2Client;

  RobinhoodUser(this.userName, this.credentials, this.oauth2Client);

  RobinhoodUser.fromJson(Map<String, dynamic> json)
      : userName = json['userName'],
        credentials = json['credentials'];

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'credentials': credentials,
      };

  static Future<RobinhoodUser> loadUserFromStore() async {
    // await Store.deleteFile(Constants.cacheFilename);
    print('Loading cache.');

    // SharedPreferences prefs = await SharedPreferences.getInstance();
    String? contents = await Store.readFile(Constants.cacheFilename);
    if (contents == null) {
      print('No cache file found.');
      return RobinhoodUser(null, null, null);
    }
    try {
      var userMap = jsonDecode(contents) as Map<String, dynamic>;
      var user = RobinhoodUser.fromJson(userMap);
      var credentials = oauth2.Credentials.fromJson(user.credentials as String);
      var client = oauth2.Client(credentials, identifier: Constants.identifier);
      user.oauth2Client = client;
      print('Loaded cache.');
      return user;
    } on FormatException catch (e) {
      print(
          'Cache provided is not valid JSON.\nError: $e\nContents: $contents');
      return RobinhoodUser(null, null, null);
    }
  }

  static Future writeUserToStore(RobinhoodUser user) async {
    var contents = jsonEncode(user);
    await Store.writeFile(Constants.cacheFilename, contents);
  }

  static Future clearUserFromStore() async {
    print("Cleared user from store.");
    await Store.deleteFile(Constants.cacheFilename);
  }
}
