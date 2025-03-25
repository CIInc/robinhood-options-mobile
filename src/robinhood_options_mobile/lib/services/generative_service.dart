import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/generative_provider.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';

class Prompt {
  final String key;
  final String title;
  String prompt;
  final bool appendPortfolioToPrompt;
  Prompt(
      {required this.key,
      required this.title,
      required this.prompt,
      this.appendPortfolioToPrompt = false});
}

class GenerativeService {
  final GenerativeModel model;

  final List<Prompt> prompts = [
    Prompt(
        key: 'portfolio-summary',
        title: 'Portfolio Summary',
        prompt: 'Summarize this portfolio data',
        appendPortfolioToPrompt: true),
    Prompt(
        key: 'portfolio-recommendations',
        title: 'Portfolio Recommendations',
        prompt: 'Provide recommendations for this portfolio',
        appendPortfolioToPrompt: true),
    Prompt(
        key: 'market-summary',
        title: 'Market Summary',
        prompt:
            'Summarize the financial markets for ${formatLongDate.format(DateTime.now())}'), // in a single paragraph
    Prompt(
        key: 'market-predictions',
        title: 'Market Predictions',
        prompt:
            'Analyze the financial markets and provide predictions for ${formatLongDate.format(DateTime.now().add(Duration(days: 1)))}'), // in a single paragraph
    Prompt(key: 'ask', title: '', prompt: '', appendPortfolioToPrompt: true),
  ];
  // final String _apiKey;
  // final String _baseUrl;

  // GenerativeService(this._apiKey, {String baseUrl = 'https://vertexai.googleapis.com/v1'}) : _baseUrl = baseUrl;
  GenerativeService()
      :
        // Initialize the Vertex AI service and the generative model
        // Specify a model that supports your use case
        model = FirebaseVertexAI.instance
            .generativeModel(model: 'gemini-2.0-flash');

  Future<String> generateContent(
    Prompt prompt,
    InstrumentPositionStore stockPositionStore,
    OptionPositionStore optionPositionStore,
    ForexHoldingStore forexHoldingStore,
  ) async {
    String promptString = """${prompt.prompt}
${prompt.appendPortfolioToPrompt ? portfolioPrompt(stockPositionStore, optionPositionStore, forexHoldingStore) : ''}""";
    HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('generateContent2');
    final resp = await callable.call(<String, dynamic>{
      'prompt': promptString,
    });
    debugPrint("result: ${resp.data}");
    String? response;
    if (resp.data["modelVersion"].toString().startsWith("gemini-2.0")) {
      //  == "gemini-2.0-flash-001"
      response = resp.data["candidates"][0]["content"]["parts"]
          .map((e) => e["text"])
          .join('  \n');
    } else {
      response = resp.data["response"]["candidates"][0]["content"]["parts"]
          .map((e) => e["text"])
          .join('  \n');
    }
    // } catch (e) {
    //   debugPrint(jsonEncode(e));
    // }
    // response = resp.data["response"]["text"];
    return response ?? '';
  }

  Future<GenerateContentResponse> generatePortfolioContent(
      Prompt prompt,
      InstrumentPositionStore stockPositionStore,
      OptionPositionStore optionPositionStore,
      ForexHoldingStore forexHoldingStore,
      GenerativeProvider provider) async {
    String promptString = """${prompt.prompt}
${prompt.appendPortfolioToPrompt ? portfolioPrompt(stockPositionStore, optionPositionStore, forexHoldingStore) : ''}""";
    final prompts = [
      Content.text(promptString),
    ];

    // To generate text output, call generateContent with the text input
    final response = await model.generateContent(
      prompts,
      // generationConfig: GenerationConfig(temperature: 0.0),
      // TODO: Use this local model with GoogleSearch tool for grounding once it becomes available, see:
      // Vertex AI in Firebase (Gemini API) https://firebase.google.com/docs/vertex-ai/text-gen-from-text?authuser=0&platform=flutter
      // tools: [
      //   Tool.functionDeclarations([
      //     FunctionDeclaration(name, description, parameters: parameters)
      //   ])
      // ]
    ); // grounding.GoogleSearchRetrieval()
    provider.setGenerativeResponse(prompt.key, response.text!);
    return response;
  }

  String portfolioPrompt(
      InstrumentPositionStore stockPositionStore,
      OptionPositionStore optionPositionStore,
      ForexHoldingStore forexHoldingStore) {
    String positionPrompt = "This is my portfolio data:\n";
    positionPrompt += """
    | Instrument | Gain/Loss Today | Gain/Loss Total | Market Value |
    | ---------- | --------- | --------- | --------- |""";
    for (var item in stockPositionStore.items) {
      if (item.instrumentObj != null) {
        positionPrompt +=
            "| ${item.instrumentObj!.symbol} | ${item.gainLossToday} | ${item.gainLoss} | ${item.marketValue} |\n";
      }
    }
    positionPrompt += """
    | Option | Gain/Loss Today | Gain/Loss Total | Market Value |
    | ------ | --------- | --------- | --------- |""";
    for (var item in optionPositionStore.items) {
      positionPrompt +=
          "| ${item.symbol} \$${item.legs.isNotEmpty && item.legs.first.strikePrice != null ? formatCompactNumber.format(item.legs.first.strikePrice) : ""} ${item.legs.isNotEmpty && item.legs.first.optionType != '' ? item.legs.first.optionType.capitalize() : ""} ${item.legs.isNotEmpty ? (item.legs.first.positionType == 'long' ? '+' : '-') : ""}${formatCompactNumber.format(item.quantity!)} ${item.legs.isNotEmpty && item.legs.first.expirationDate != null ? item.legs.first.expirationDate!.compareTo(DateTime.now()) < 0 ? "Expired" : "Expires" : ""} ${item.legs.isNotEmpty && item.legs.first.expirationDate != null ? formatDate.format(item.legs.first.expirationDate!) : ""} | ${item.changeToday} | ${item.gainLoss} | ${item.marketValue} |\n";
    }
    positionPrompt += """
    | Crypto | Gain/Loss Today | Gain/Loss Total | Market Value |
    | ------ | --------- | --------- | --------- |""";
    for (var item in forexHoldingStore.items) {
      positionPrompt +=
          "| ${item.currencyName} | ${item.gainLossToday} | ${item.gainLoss} | ${item.marketValue} |\n";
    }
    return positionPrompt;
  }
}
