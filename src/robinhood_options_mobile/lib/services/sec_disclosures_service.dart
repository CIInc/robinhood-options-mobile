import 'package:cloud_functions/cloud_functions.dart';

import '../model/sec_disclosure.dart';

class SecDisclosuresService {
  final FirebaseFunctions _functions;

  SecDisclosuresService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  Future<SecDisclosureSnapshot> getDisclosures(String symbol) async {
    final response = await _functions.httpsCallable('getSecDisclosures').call({
      'symbol': symbol.trim().toUpperCase(),
    });
    return SecDisclosureSnapshot.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
