import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
// import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/model/chat_message.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/generative_provider.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/price_target_analysis.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/remote_config_service.dart';

class Prompt {
  final String key;
  final String title;
  final String prompt;
  bool appendPortfolioToPrompt;
  bool appendInvestmentProfile;
  Prompt({
    required this.key,
    required this.title,
    required this.prompt,
    this.appendPortfolioToPrompt = false,
    this.appendInvestmentProfile = false,
  });
}

class GenerativeService {
  final GenerativeModel model;

  final List<Prompt> prompts = [
    Prompt(
      key: 'portfolio-summary',
      title: 'Portfolio Summary',
      prompt: 'Summarize my portfolio including key metrics and performance.',
      appendInvestmentProfile: true,
      appendPortfolioToPrompt: true,
    ),
    Prompt(
      key: 'portfolio-recommendations',
      title: 'Portfolio Recommendations',
      prompt: 'Investment recommendations for my portfolio',
      // prompt: 'Provide recommendations for my portfolio, including risk '
      //     'management, diversification, and potential trades to consider.',
      appendInvestmentProfile: true,
      appendPortfolioToPrompt: true,
    ),
    Prompt(
      key: 'market-summary',
      title: 'Market Summary',
      prompt:
          'Summarize the financial markets for ${formatLongDate.format(DateTime.now())}',
    ), // in a single paragraph
    Prompt(
      key: 'stock-summary',
      title: 'Stock Summary',
      prompt: 'Summarize the stock {{symbol}}.',
    ), // in a single paragraph
    Prompt(
      key: 'investment-thesis',
      title: 'Investment Thesis',
      prompt:
          'Generate a comprehensive investment thesis for {{symbol}}, covering bullish and bearish arguments, key risks, and catalysts.',
    ),
    Prompt(
      key: 'chart-trend',
      title: 'Chart Trend',
      prompt:
          '''Analyze stock symbol {{symbol}} and provide a summary of the trend.
Use the following chart patterns to identify the trend:
- Head and Shoulders - A reversal pattern that can signal a change in trend direction.
- Double Top and Bottom - A reversal pattern that can signal a change in trend direction.
- Flags and Pennants - Continuation patterns that can signal a continuation of the current trend.
- Cup and Handle - A continuation pattern that can signal a continuation of the current trend.
- Ascending and Descending Triangles - Continuation patterns that can signal a continuation of the current trend.
- Rounding Bottom - A reversal pattern that can signal a change in trend direction.
- Gaps - A price movement that can signal a change in trend direction.
- Support and Resistance - Price levels that can signal a change in trend direction.
- Trend Lines - A line that can signal a change in trend direction.
- Fibonacci Retracement - A tool that can signal a change in trend direction.
- Moving Averages - A tool that can signal a change in trend direction.
- Bollinger Bands - A tool that can signal a change in trend direction.
- Volume - A tool that can signal a change in trend direction.
- Candlestick Patterns - A tool that can signal a change in trend direction.
- Chart Patterns - A tool that can signal a change in trend direction.
- Price Movement - Use chart patterns to predict price movement - https://www.babypips.com/learn/forex/chart-patterns-cheat-sheet''',
    ),
    /*
Momentum - ex: Relative Strength Index (RSI) and other momentum technical indicators
Overall market direction - Moving averages and trend lines on SPY or QQQ
Volume - Volume bar or other volume indicators
            */
    Prompt(
      key: 'construct-portfolio',
      title: 'Construct Portfolio',
      prompt:
          '''Construct a portfolio based on the user's request (or a default Growth portfolio if not specified).
Provide a Markdown table with the following columns:
- **Symbol**: Ticker symbol
- **Allocation**: Recommended percentage (total 100%)
- **Sector**: Industry/Sector

Follow with a bulleted list of rationale (reason for inclusion) for each asset. 

Then include a brief summary of the **Strategy** and **Risk Profile**.
''',
      appendInvestmentProfile: true,
      appendPortfolioToPrompt: false,
    ),
    Prompt(
      key: 'market-predictions',
      title: 'Market Predictions',
      prompt:
          'Predict the market movements for today and the next week, including major indices and sectors.',
    ),
    Prompt(
      key: 'select-option',
      title: 'Option Selector',
      prompt:
          'Analyze the option chain for symbol {{symbol}} as of ${formatLongDate.format(DateTime.now())} and provide the best {{type}} contracts to {{action}} and explain why.',
    ),
    Prompt(
      key: 'ask',
      title: 'Ask a Question',
      prompt: '',
      appendPortfolioToPrompt: true,
    ),
  ];
  // final String _apiKey;
  // final String _baseUrl;

  // GenerativeService(this._apiKey, {String baseUrl = 'https://vertexai.googleapis.com/v1'}) : _baseUrl = baseUrl;
  GenerativeService()
      : // Initialize the Vertex AI service and the generative model
        // Specify a model that supports your use case
        model = FirebaseAI.vertexAI().generativeModel(
            // model: 'gemini-2.5-flash'
            model: RemoteConfigService.instance.aiModelName.isNotEmpty
                ? RemoteConfigService.instance.aiModelName
                : 'gemini-2.5-flash-lite',
            systemInstruction: Content.system(
                'You are a helpful financial assistant for RealizeAlpha. '
                // 'When asked to build or construct a portfolio, always present it as a Markdown table with Asset (Symbol & Name), Allocation, and Sector columns. '
                // 'Provide the Rationale for each holding as a bulleted list after the table. Follow with a Strategy and Risk Profile summary.'
                )); // gemini-2.5-flash-preview-04-17

  Future<String> generateContentFromServer(
    Prompt prompt,
    InstrumentPositionStore? stockPositionStore,
    OptionPositionStore? optionPositionStore,
    ForexHoldingStore? forexHoldingStore, {
    User? user,
  }) async {
    String context = "";
    bool profileAppended = false;

    if (prompt.appendInvestmentProfile && user != null) {
      context += investmentProfilePrompt(user);
      profileAppended = true;
    }

    if (stockPositionStore != null &&
        optionPositionStore != null &&
        forexHoldingStore != null &&
        prompt.appendPortfolioToPrompt) {
      context += portfolioPrompt(
          stockPositionStore, optionPositionStore, forexHoldingStore,
          user: user, includeProfile: !profileAppended);
    }
    String promptString =
        """You are a financial assistant, provide answers in markdown format.
    ${prompt.prompt}
    $context""";
    HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'generateContent25',
    );
    final resp = await callable.call(<String, dynamic>{'prompt': promptString});
    debugPrint("result: ${resp.data}");
    String? response;
    if (resp.data["modelVersion"].toString().startsWith("gemini-2")) {
      //  == "gemini-2.5-flash-lite"
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

  Future<PriceTargetAnalysis?> analyzePriceTargets(String symbol) async {
    try {
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'analyzePriceTargets',
      );
      final resp = await callable.call(<String, dynamic>{'symbol': symbol});

      String? responseText;
      if (resp.data != null) {
        if (resp.data is Map && resp.data["candidates"] != null) {
          responseText =
              (resp.data["candidates"][0]["content"]["parts"] as List)
                  .map((e) => e["text"])
                  .join('  \n');
        } else if (resp.data is Map && resp.data["response"] != null) {
          responseText = (resp.data["response"]["candidates"][0]["content"]
                  ["parts"] as List)
              .map((e) => e["text"])
              .join('  \n');
        }
      }

      if (responseText != null) {
        // Strip Markdown code blocks if present
        responseText = responseText
            .replaceAll(RegExp(r'^```json\s*'), '')
            .replaceAll(RegExp(r'\s*```$'), '');
        final json = jsonDecode(responseText);
        return PriceTargetAnalysis.fromJson(json);
      }
    } catch (e) {
      debugPrint("Error analyzing price targets: $e");
    }
    return null;
  }

  Future<String> sendChatMessage(
    String message, {
    List<ChatMessage>? history,
    InstrumentPositionStore? stockPositionStore,
    OptionPositionStore? optionPositionStore,
    ForexHoldingStore? forexHoldingStore,
    User? user,
    bool includeProfile = true,
    bool includePortfolio = true,
  }) async {
    // Basic history formatting if we want to include context
    String context = "";

    // Add portfolio context if stores are provided
    if (includePortfolio &&
        stockPositionStore != null &&
        optionPositionStore != null &&
        forexHoldingStore != null) {
      context += portfolioPrompt(
        stockPositionStore,
        optionPositionStore,
        forexHoldingStore,
        user: user,
        includeProfile: includeProfile,
      );
      context += "\n";
    } else if (includeProfile && user != null) {
      context += investmentProfilePrompt(user);
      context += "\n";
    }

    String promptString = "";
    if (history != null && history.isNotEmpty) {
      promptString += "History:\n";
      // ... same as before
      for (var msg in history) {
        promptString += "${msg.isUser ? 'User' : 'Assistant'}: ${msg.text}\n";
      }
      promptString += "\nCurrent Question:\n";
    }
    promptString += message;
    if (context.isNotEmpty) {
      promptString += "\n$context";
    }

    HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'generateContent25',
    );
    final resp = await callable.call(<String, dynamic>{'prompt': promptString});

    // Parse response similar to generateContentFromServer
    String? response;
    if (resp.data != null) {
      // Handle potential structure variations
      try {
        if (resp.data is Map && resp.data["candidates"] != null) {
          response = (resp.data["candidates"][0]["content"]["parts"] as List)
              .map((e) => e["text"])
              .join('  \n');
        } else if (resp.data is Map && resp.data["response"] != null) {
          response = (resp.data["response"]["candidates"][0]["content"]["parts"]
                  as List)
              .map((e) => e["text"])
              .join('  \n');
        }
      } catch (e) {
        debugPrint("Error parsing chat response: $e");
      }
    }
    return response ?? "Sorry, I couldn't understand that.";
  }

  Future<GenerateContentResponse> generatePortfolioContent(
    Prompt prompt,
    InstrumentPositionStore? stockPositionStore,
    OptionPositionStore? optionPositionStore,
    ForexHoldingStore? forexHoldingStore,
    GenerativeProvider provider, {
    User? user,
  }) async {
    String context = "";
    bool profileAppended = false;

    if (prompt.appendInvestmentProfile && user != null) {
      context += investmentProfilePrompt(user);
      profileAppended = true;
    }

    if (stockPositionStore != null &&
        optionPositionStore != null &&
        forexHoldingStore != null &&
        prompt.appendPortfolioToPrompt) {
      context += portfolioPrompt(
          stockPositionStore, optionPositionStore, forexHoldingStore,
          user: user, includeProfile: !profileAppended);
    }

    String promptString = "${prompt.prompt}\n$context";
    final prompts = [Content.text(promptString)];

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
    provider.setGenerativeResponse(prompt.prompt, response.text!);
    return response;
  }

  Stream<String> streamChatMessage(
    String message, {
    List<ChatMessage>? history,
    InstrumentPositionStore? stockPositionStore,
    OptionPositionStore? optionPositionStore,
    ForexHoldingStore? forexHoldingStore,
    User? user,
    bool includeProfile = true,
    bool includePortfolio = true,
  }) async* {
    String context = "";

    // Add portfolio context if stores are provided
    if (includePortfolio &&
        stockPositionStore != null &&
        optionPositionStore != null &&
        forexHoldingStore != null) {
      context += portfolioPrompt(
        stockPositionStore,
        optionPositionStore,
        forexHoldingStore,
        user: user,
        includeProfile: includeProfile,
      );
      context += "\n";
    } else if (includeProfile && user != null) {
      context += investmentProfilePrompt(user);
      context += "\n";
    }

    String promptString = "";
    if (history != null && history.isNotEmpty) {
      promptString += "History:\n";
      for (var msg in history) {
        promptString += "${msg.isUser ? 'User' : 'Assistant'}: ${msg.text}\n";
      }
      promptString += "\nCurrent Question:\n";
    }
    promptString += message;
    if (context.isNotEmpty) {
      promptString += "\n$context";
    }

    final prompts = [Content.text(promptString)];
    final buffer = StringBuffer();

    await for (final event in model.generateContentStream(prompts)) {
      final text = event.text;
      if (text != null && text.isNotEmpty) {
        final current = buffer.toString();
        if (current.isEmpty) {
          buffer.write(text);
        } else if (text.startsWith(current)) {
          // Only append the new part.
          buffer.write(text.substring(current.length));
        } else if (!current.endsWith(text)) {
          // Unusual case: append as-is.
          buffer.write(text);
        }
        yield buffer.toString();
      }
    }
  }

  Stream<String> streamPortfolioContent(
    Prompt prompt,
    InstrumentPositionStore? stockPositionStore,
    OptionPositionStore? optionPositionStore,
    ForexHoldingStore? forexHoldingStore,
    GenerativeProvider provider, {
    User? user,
  }) async* {
    String context = "";
    bool profileAppended = false;

    if (prompt.appendInvestmentProfile && user != null) {
      context += investmentProfilePrompt(user);
      profileAppended = true;
    }

    if (stockPositionStore != null &&
        optionPositionStore != null &&
        forexHoldingStore != null &&
        prompt.appendPortfolioToPrompt) {
      context += portfolioPrompt(
          stockPositionStore, optionPositionStore, forexHoldingStore,
          user: user, includeProfile: !profileAppended);
    }

    String promptString = "${prompt.prompt}\n$context";
    final prompts = [Content.text(promptString)];

    final buffer = StringBuffer();
    await for (final event in model.generateContentStream(prompts)) {
      // Each event may contain partial candidates.
      try {
        final text = event.text;
        if (text != null && text.isNotEmpty) {
          // Deduplicate cumulative or partial text updates.
          final current = buffer.toString();
          if (current.isEmpty) {
            buffer.write(text);
          } else if (text.startsWith(current)) {
            // Only append the new part.
            buffer.write(text.substring(current.length));
          } else if (!current.endsWith(text)) {
            // Unusual case: append as-is.
            buffer.write(text);
          }
          // else: text is already present, do not append.
          provider.setGenerativeResponse(prompt.prompt, buffer.toString());
          yield buffer.toString();
        }
      } catch (_) {
        // Ignore malformed partial chunk
      }
    }
  }

  String investmentProfilePrompt(User user) {
    String profilePrompt = "";
    profilePrompt +=
        user.name != null ? "Portfolio of ${user.name}\n" : "Portfolio\n";

    profilePrompt += "## Investment Profile\n";
    if (user.investmentProfile?.investmentGoals != null &&
        user.investmentProfile!.investmentGoals!.isNotEmpty) {
      profilePrompt +=
          "**Investment Goals:** ${user.investmentProfile!.investmentGoals}\n";
    }
    if (user.investmentProfile?.timeHorizon != null &&
        user.investmentProfile!.timeHorizon!.isNotEmpty) {
      profilePrompt +=
          "**Time Horizon:** ${user.investmentProfile!.timeHorizon}\n";
    }
    if (user.investmentProfile?.riskTolerance != null &&
        user.investmentProfile!.riskTolerance!.isNotEmpty) {
      profilePrompt +=
          "**Risk Tolerance:** ${user.investmentProfile!.riskTolerance}\n";
    }
    // Include total portfolio value if available
    if (user.investmentProfile?.totalPortfolioValue != null) {
      profilePrompt +=
          "**Total Portfolio Value:** \$${formatCompactNumber.format(user.investmentProfile!.totalPortfolioValue)}\n";
    }

    // Include cash per account and aggregated cash if accounts are present
    double totalCash = 0.0;
    try {
      if (user.allAccounts.isNotEmpty) {
        profilePrompt += "**Accounts Cash:**\n";
        for (var acct in user.allAccounts) {
          double? acctCash = acct.portfolioCash;
          if (acctCash != null) {
            totalCash += acctCash;
            profilePrompt +=
                "- Account ${acct.accountNumber}: ${formatCurrency.format(acctCash)}\n";
          }
        }
        profilePrompt +=
            "**Total Cash Across Accounts:** ${formatCurrency.format(totalCash)}\n";
      }
    } catch (e) {
      // If accounts are not present or another error occurs, ignore
    }
    profilePrompt += "\n";
    return profilePrompt;
  }

  String portfolioPrompt(
    InstrumentPositionStore stockPositionStore,
    OptionPositionStore optionPositionStore,
    ForexHoldingStore forexHoldingStore, {
    User? user,
    bool includeProfile = true,
  }) {
    String positionPrompt = "";

    // Add investment profile information if user is provided
    if (user != null && includeProfile) {
      positionPrompt += investmentProfilePrompt(user);
    }

    positionPrompt += """
## Stocks
| Symbol | Quantity | Avg Cost | Last Price | Market Value | Day Return | Total Return | PE | Div Yield | 52W High | 52W Low | Sector |
| ------ | -------- | -------- | ---------- | ------------ | ---------- | ------------ | -- | --------- | -------- | ------- | ------ |""";
    for (var item in stockPositionStore.items) {
      if (item.instrumentObj != null) {
        final lastPrice = item.instrumentObj!.quoteObj?.lastTradePrice ?? 0;
        final lastPriceStr = formatCurrency.format(lastPrice);
        final avgCostStr = formatCurrency.format(item.averageBuyPrice ?? 0);
        final marketValueStr = formatCurrency.format(item.marketValue);
        final dayReturnStr =
            "${formatCurrency.format(item.gainLossToday)} (${formatPercentage.format(item.gainLossPercentToday)})";
        final totalReturnStr =
            "${formatCurrency.format(item.gainLoss)} (${formatPercentage.format(item.gainLossPercent)})";

        // Fundamentals
        final fundamentals = item.instrumentObj!.fundamentalsObj;
        final pe = fundamentals?.peRatio != null
            ? fundamentals!.peRatio.toString()
            : "-";
        final divObj = fundamentals?.dividendYield;
        final divYield =
            divObj != null ? formatPercentage.format(divObj / 100) : "-";
        final high52 = fundamentals?.high52Weeks != null
            ? formatCurrency.format(fundamentals!.high52Weeks)
            : "-";
        final low52 = fundamentals?.low52Weeks != null
            ? formatCurrency.format(fundamentals!.low52Weeks)
            : "-";
        final sector = fundamentals?.sector ?? "-";

        positionPrompt +=
            "\n| ${item.instrumentObj!.symbol} | ${formatCompactNumber.format(item.quantity)} | $avgCostStr | $lastPriceStr | $marketValueStr | $dayReturnStr | $totalReturnStr | $pe | $divYield | $high52 | $low52 | $sector |";
      }
    }
    positionPrompt += """
\n\n## Options
| Contract | Side | Qty | Avg Cost | Mark Price | Value | Day Return | Total Return | Expires | IV | Delta | Theta | Gamma | Vega | Chance Profit |
| -------- | ---- | --- | -------- | ---------- | ----- | ---------- | ------------ | ------- | -- | ----- | ----- | ----- | ---- | ------------- |""";
    for (var item in optionPositionStore.items) {
      var contract =
          "${item.symbol} \$${item.legs.isNotEmpty && item.legs.first.strikePrice != null ? formatCompactNumber.format(item.legs.first.strikePrice) : ""} ${item.legs.isNotEmpty ? item.legs.first.optionType.capitalize() : ""}";
      var side = item.legs.isNotEmpty
          ? (item.legs.first.positionType == 'long' ? 'Long' : 'Short')
          : "";
      var avgCost = item.averageOpenPrice ?? 0;
      // Note: Average Open Price from Robinhood is usually x100 per contract cost basis for display?
      // Actually standard convention is per share.
      var avgCostStr = formatCurrency.format(avgCost);

      var markPrice =
          item.optionInstrument?.optionMarketData?.adjustedMarkPrice ??
              item.optionInstrument?.optionMarketData?.markPrice ??
              0;
      var markPriceStr = formatCurrency.format(markPrice);
      var marketValueStr = formatCurrency.format(item.marketValue);

      var dayReturnStr = "-";
      try {
        dayReturnStr = formatCurrency.format(item.changeToday);
      } catch (_) {}

      var totalReturnStr =
          "${formatCurrency.format(item.gainLoss)} (${item.totalCost != 0 ? formatPercentage.format(item.gainLoss / item.totalCost) : '0%'})";

      var expiry =
          item.legs.isNotEmpty && item.legs.first.expirationDate != null
              ? formatDate.format(item.legs.first.expirationDate!)
              : "";

      // Greeks & Risk
      var iv =
          item.optionInstrument?.optionMarketData?.impliedVolatility != null
              ? formatPercentage.format(
                  item.optionInstrument!.optionMarketData!.impliedVolatility,
                )
              : "-";
      var delta =
          item.optionInstrument?.optionMarketData?.delta?.toString() ?? "-";
      var theta =
          item.optionInstrument?.optionMarketData?.theta?.toString() ?? "-";
      var gamma =
          item.optionInstrument?.optionMarketData?.gamma?.toString() ?? "-";
      var vega =
          item.optionInstrument?.optionMarketData?.vega?.toString() ?? "-";
      var chanceProfit = item
                  .optionInstrument?.optionMarketData?.chanceOfProfitLong !=
              null
          ? (side == 'Long'
              ? formatPercentage.format(
                  item.optionInstrument!.optionMarketData!.chanceOfProfitLong,
                )
              : (item.optionInstrument?.optionMarketData?.chanceOfProfitShort !=
                      null
                  ? formatPercentage.format(
                      item.optionInstrument!.optionMarketData!
                          .chanceOfProfitShort,
                    )
                  : "-"))
          : "-";

      positionPrompt +=
          "\n| $contract | $side | ${formatCompactNumber.format(item.quantity)} | $avgCostStr | $markPriceStr | $marketValueStr | $dayReturnStr | $totalReturnStr | $expiry | $iv | $delta | $theta | $gamma | $vega | $chanceProfit |";
    }
    positionPrompt += """
\n\n## Crypto
| Currency | Quantity | Avg Price | Market Value | Day Return | Total Return |
| -------- | -------- | --------- | ------------ | ---------- | ------------ |""";
    for (var item in forexHoldingStore.items) {
      final avgCostStr = formatCurrency.format(item.averageCost);
      final marketValueStr = formatCurrency.format(item.marketValue);
      final dayReturnStr = formatCurrency.format(item.gainLossToday);
      final totalReturnStr =
          "${formatCurrency.format(item.gainLoss)} (${item.totalCost != 0 ? formatPercentage.format(item.gainLoss / item.totalCost) : '0%'})";

      positionPrompt +=
          "\n| ${item.currencyName} | ${formatCompactNumber.format(item.quantity)} | $avgCostStr | $marketValueStr | $dayReturnStr | $totalReturnStr |";
    }
    return positionPrompt;
  }
}
