import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/chat_message.dart';

class GenerativeProvider extends ChangeNotifier {
  Map<String, String?> promptResponses = {};
  List<ChatMessage> chatMessages = [];
  bool generating = false;
  String? generatingPrompt;

  void startGenerating(String prompt) async {
    promptResponses[prompt] = null;
    generating = true;
    generatingPrompt = prompt;
    notifyListeners();
  }

  void setGenerativeResponse(String prompt, String response) async {
    promptResponses[prompt] = response;
    generating = false;
    generatingPrompt = null;
    notifyListeners();
  }

  void addMessage(ChatMessage message) {
    chatMessages.add(message);
    notifyListeners();
  }

  void updateLastMessage(String text) {
    if (chatMessages.isNotEmpty) {
      final last = chatMessages.last;
      chatMessages[chatMessages.length - 1] = ChatMessage(
          text: text, isUser: last.isUser, timestamp: last.timestamp);
      notifyListeners();
    }
  }

  void clearChat() {
    chatMessages.clear();
    notifyListeners();
  }
}
