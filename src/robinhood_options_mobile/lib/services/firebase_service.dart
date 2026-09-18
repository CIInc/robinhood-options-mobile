import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  Future<HttpsCallableResult<dynamic>> sendPushNotification(
      List<String?> tokens, String body,
      {String title = 'RealizeAlpha Team',
      String imageUrl = 'https://realizealpha.web.app/icons/Icon-512.png',
      String route = '/'}) async {
    HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('sendEachForMulticast');
    final resp = await callable.call(<String, dynamic>{
      'tokens': tokens,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'route': route
    });
    debugPrint("result: ${resp.data}");
    return resp;
  }
}
