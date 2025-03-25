import 'package:flutter/foundation.dart';

class GenerativeProvider extends ChangeNotifier {
  Map<String, String?> promptResponses = {};
  // String? prompt;
  // String? response;
  bool generating = false;

  void startGenerating(String prompt) async {
    // this.prompt = prompt;
    promptResponses[prompt] = null;
    generating = true;
    notifyListeners();
  }

  void setGenerativeResponse(String prompt, String response) async {
    // this.response = response;
    promptResponses[prompt] = response;
    generating = false;
    notifyListeners();
  }
}
