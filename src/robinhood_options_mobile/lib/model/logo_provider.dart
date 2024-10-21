import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogoProvider extends ChangeNotifier {
  Map<String, dynamic> logoUrls = {};

  Future<void> add(String symbol, dynamic logo) async {
    logoUrls[symbol] = logo;
    await save();
    notifyListeners();
  }

  void remove(String symbol) {
    logoUrls.remove(symbol);
    notifyListeners();
  }

  Future<void> save() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("logoUrls", jsonEncode(logoUrls));
    debugPrint("Cached ${logoUrls.keys.length} logos");
  }

  Future<void> load() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var prefString = prefs.getString("logoUrls");
    if (prefString != null) {
      logoUrls = jsonDecode(prefString);
    } else {
      logoUrls = {};
    }
    debugPrint("Loaded ${logoUrls.keys.length} logos");
  }
}
