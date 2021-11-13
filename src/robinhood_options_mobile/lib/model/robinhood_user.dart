import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:robinhood_options_mobile/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    debugPrint('Loading cache.');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? contents = prefs.getString(Constants.cacheFilename);
    //String? contents = await Store.readFile(Constants.cacheFilename);
    if (contents == null) {
      debugPrint('No cache file found.');
      return RobinhoodUser(null, null, null);
    }
    try {
      var userMap = jsonDecode(contents) as Map<String, dynamic>;
      var user = RobinhoodUser.fromJson(userMap);
      var credentials = oauth2.Credentials.fromJson(user.credentials as String);
      var client = oauth2.Client(credentials, identifier: Constants.identifier);
      user.oauth2Client = client;
      debugPrint('Loaded cache.');
      return user;
    } on FormatException catch (e) {
      debugPrint(
          'Cache provided is not valid JSON.\nError: $e\nContents: $contents');
      return RobinhoodUser(null, null, null);
    }
  }

  static Future writeUserToStore(RobinhoodUser user) async {
    var contents = jsonEncode(user);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.cacheFilename, contents);
    //await Store.writeFile(Constants.cacheFilename, contents);
  }

  static Future clearUserFromStore() async {
    debugPrint("Cleared user from store.");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(Constants.cacheFilename);
    //await Store.deleteFile(Constants.cacheFilename);
  }
}
