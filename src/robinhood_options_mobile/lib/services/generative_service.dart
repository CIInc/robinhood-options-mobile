import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mcp_dart/mcp_dart.dart' as mcp;
import 'package:crypto/crypto.dart';
// import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/widgets/mcp_oauth_webview.dart';
import 'package:http/http.dart' as http;
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

  static Content buildSystemInstruction({List<String>? mcpToolNames}) {
    String instruction =
        'You are a helpful financial assistant for RealizeAlpha. You are integrated with Robinhood Agentic Trading.\n';

    if (mcpToolNames != null && mcpToolNames.isNotEmpty) {
      instruction +=
          '\n**ROBINHOOD MODEL CONTEXT PROTOCOL (MCP) IS ACTIVE & CONNECTED!**\n'
          'You have direct, real-time access to the user\'s Robinhood account through the following active tools: ${mcpToolNames.join(", ")}.\n'
          'CRITICAL GUIDELINES:\n'
          '- Whenever the user asks about their portfolio, holdings, cash, buying power, positions, watchlists, or any specific stock/option details, **you must use the appropriate MCP tool(s)** to fetch the real-time data instead of relying on legacy assumptions, guessing, or claiming you lack access.\n'
          '- Realize that you can invoke tools step-by-step (e.g., fetch account first, then portfolio holdings or a specific quote) as needed.\n'
          '- Inform the user of the actions/tools you are executing so they know you are querying Robinhood on their behalf.\n\n';
    }

    instruction +=
        'When the user asks you to buy, sell, or trade stocks, or when you strongly recommend a specific stock trade (e.g. as part of rebalancing, ideas, or analysis), you must append a special trade instruction block at the very end of your response formatted exactly as:\n'
        '[TRADE_PROPOSAL: Action Stock Symbol Qty Quantity Type market/limit Price LimitPrice]\n'
        'Examples:\n'
        '- [TRADE_PROPOSAL: BUY AAPL Qty 10 Type limit Price 185.50]\n'
        '- [TRADE_PROPOSAL: SELL TSLA Qty 5 Type market]\n'
        'For options suggestions, specify:\n'
        '[TRADE_PROPOSAL_OPTION: Action Stock Symbol Call/Put Exp ExpiryDate Strike StrikePrice Qty Quantity Type limit Price LimitPrice]\n'
        'Example: [TRADE_PROPOSAL_OPTION: BUY AAPL Call Exp 2026-06-19 Strike 180.0 Qty 1 Type limit Price 2.50]\n'
        'Always ensure the format is exact so the client can present a native interactive trading preview card to the user.';

    return Content.system(instruction);
  }

  static final Content systemInstruction = buildSystemInstruction();

  final List<Prompt> prompts = [
    Prompt(
      key: 'portfolio-summary',
      title: 'Portfolio Summary',
      // Previous prompt: 'Summarize my portfolio including key metrics and performance.'
      prompt:
          'Provide a comprehensive executive summary of my portfolio. Please analyze my asset allocation (stocks vs. options vs. cash), highlight my top holdings by market value, identify any sector concentrations, and summarize my performance metrics (including total equity, today\'s change, and overall gains/losses). Keep it clear, concise, and structured with bullet points.',
      appendInvestmentProfile: true,
      appendPortfolioToPrompt: true,
    ),
    Prompt(
      key: 'portfolio-recommendations',
      title: 'Portfolio Recommendations',
      // Previous prompt: 'Investment recommendations for my portfolio'
      prompt:
          'Recommend 3 tailored investment opportunities or strategic adjustments that complement my existing portfolio and align with my risk profile. For each recommendation, provide the ticker symbol, targeted percentage allocation, entry strategy, and a concise fundamental or technical rationale explaining why this is a strong addition. Highlight any potential hedges or diversification benefits.',
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
      /*
      Previous prompt:
      '''Construct a portfolio based on the user's request (or a default Growth portfolio if not specified).
Provide a Markdown table with the following columns:
- **Symbol**: Ticker symbol
- **Allocation**: Recommended percentage (total 100%)
- **Sector**: Industry/Sector

Follow with a bulleted list of rationale (reason for inclusion) for each asset. 

Then include a brief summary of the **Strategy** and **Risk Profile**.
'''
      */
      prompt:
          '''Construct a professionally diversified, theme-based portfolio tailored to my risk tolerance and investment profile (or design a balanced Growth & Income portfolio if my request is open-ended).
Provide a clean Markdown table with the following columns:
- **Asset Class**: Stock, Option, Fixed Income, or Crypto
- **Ticker / Symbol**: Targeted symbol
- **Target Allocation (%)**: Percentage (summing to 100%)
- **Sector / Type**: Industry sector or category

Follow the table with a strategic breakdown:
1. **Investment Thesis & Strategy**: The macro reasoning behind this asset mix.
2. **Asset Rationale**: Quick, high-conviction bullet points for each selected asset.
3. **Risk Management Plan**: Core guidelines for stop-losses, sizing, or periodic rebalancing to manage downside.
''',
      appendInvestmentProfile: true,
      appendPortfolioToPrompt: false,
    ),
    Prompt(
      key: 'market-predictions',
      title: 'Market Predictions',
      // Previous prompt: 'Predict the market movements for today and the next week, including major indices and sectors.'
      prompt:
          'Perform an expert technical and fundamental analysis of major financial indices (SPY, QQQ, IWM, VIX) and sector trends for today and the upcoming week. Identify critical support/resistance levels, pivot points, and potential trend changes. Highlight upcoming high-impact economic catalysts (such as CPI releases, Fed announcements, or key earnings reports) that could drive market volatility, and outline both bullish and bearish scenarios.',
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
            systemInstruction: systemInstruction,
            tools: [Tool.googleSearch()]);

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
    RobinhoodMcpClient? mcpClient;
    List<Tool>? modelTools;
    final List<String> mcpToolNames = [];

    final accessToken = await getMcpAccessToken();

    if (accessToken != null) {
      try {
        mcpClient = RobinhoodMcpClient(accessToken);
        final mcpTools =
            await mcpClient.listTools().timeout(const Duration(seconds: 5));
        if (mcpTools.isNotEmpty) {
          final List<FunctionDeclaration> functionDeclarations = [];
          for (final tool in mcpTools) {
            final name = tool.name;
            final description = tool.description;
            final inputSchema = tool.inputSchema.toJson();
            functionDeclarations.add(FunctionDeclaration(
              name,
              description ?? '',
              parameters: _parseJsonSchemaProperties(inputSchema),
              optionalParameters: _getOptionalParameters(inputSchema),
            ));
            mcpToolNames.add(name);
          }
          if (functionDeclarations.isNotEmpty) {
            modelTools = [
              Tool.functionDeclarations(functionDeclarations),
              // Tool.googleSearch(),
            ];
          }
        }
      } catch (e) {
        debugPrint("Error initializing MCP client tools for chat message: $e");
        mcpClient?.dispose();
        mcpClient = null;
      }
    }

    // Basic history formatting if we want to include context
    String context = "";

    // Add portfolio context if stores are provided AND MCP is NOT connected.
    // If MCP is connected, let it fetch details dynamically via tools.
    final mcpConnected = mcpClient != null && modelTools != null;
    if (!mcpConnected &&
        includePortfolio &&
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
    } else {
      if (includeProfile && user != null) {
        context += investmentProfilePrompt(user);
        context += "\n";
      }
      if (mcpConnected) {
        context += "\n[SYSTEM NOTICE: Robinhood MCP client is ACTIVE and CONNECTED with tools: ${mcpToolNames.join(', ')}. "
            "To fulfill the user's request about their portfolio, holdings, or balances, you MUST call the appropriate dynamic tool(s). "
            "Start by calling list_accounts (or equivalent) to retrieve the active account ID/number if needed, and proceed step-by-step. "
            "Never claim you lack access, say you need access, or instruct the user to grant or authorize account access, as you are already authorized and connected.]\n";
      }
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

    if (mcpConnected) {
      debugPrint(
          "GenerativeService [generateContent]: Local MCP is connected. Active tools count: ${modelTools.length}");
      debugPrint("  Tool functions available for Gemini: $mcpToolNames");

      final activeModel = FirebaseAI.vertexAI().generativeModel(
        model: RemoteConfigService.instance.aiModelName.isNotEmpty
            ? RemoteConfigService.instance.aiModelName
            : 'gemini-2.5-flash-lite',
        systemInstruction: buildSystemInstruction(mcpToolNames: mcpToolNames),
        tools: modelTools,
      );

      final currentContents = [Content.text(promptString)];
      final buffer = StringBuffer();

      try {
        int turnCount = 0;
        while (true) {
          turnCount++;
          debugPrint(
              "GenerativeService [generateContent Turn $turnCount]: Calling Vertex AI with ${currentContents.length} items in history.");
          final response = await activeModel.generateContent(currentContents);
          final text = response.text;
          if (text != null && text.isNotEmpty) {
            buffer.write(text);
          }

          final functionCalls = response.functionCalls;
          debugPrint(
              "GenerativeService [generateContent Turn $turnCount]: Model generated text length ${text?.length ?? 0}, raw functionCalls count: ${functionCalls.length}");
          if (functionCalls.isEmpty) {
            return buffer.isNotEmpty
                ? buffer.toString()
                : (response.text ?? "Sorry, I couldn't understand that.");
          }

          // We have function calls, execute them!
          final deduplicatedCalls = _deduplicateCalls(functionCalls.toList());
          debugPrint(
              "GenerativeService [generateContent Turn $turnCount]: Deduplicated functionCalls count: ${deduplicatedCalls.length}");

          List<FunctionResponse> responses = [];
          for (final call in deduplicatedCalls) {
            buffer.write("\n\n> ⚙️ **Executing tool:** `${call.name}`");
            if (call.args.isNotEmpty) {
              buffer.write("\n> *Arguments:* `${jsonEncode(call.args)}`");
            }
            debugPrint(
                "  Executing tool: ${call.name} with arguments: ${jsonEncode(call.args)}");

            try {
              final result = await mcpClient.callTool(call.name, call.args);
              Map<String, Object?> resultMap;
              if (result is Map) {
                resultMap = result.cast<String, Object?>();
              } else {
                resultMap = {'result': result};
              }
              responses.add(FunctionResponse(call.name, resultMap));

              final resultStr = jsonEncode(resultMap);
              buffer.write("\n> 📥 **Response:** `$resultStr`\n\n");
              debugPrint("    Success from tool ${call.name}: $resultStr");
            } catch (e) {
              responses
                  .add(FunctionResponse(call.name, {'error': e.toString()}));
              buffer.write("\n> ❌ **Error:** `$e`\n\n");
              debugPrint("    Error from tool ${call.name}: $e");
            }
          }

          final List<Part> modelParts = [];
          if (text != null && text.isNotEmpty) {
            modelParts.add(TextPart(text));
          }
          if (deduplicatedCalls.isNotEmpty) {
            modelParts.addAll(
                deduplicatedCalls.map((c) => FunctionCall(c.name, c.args)));
          }

          debugPrint(
              "GenerativeService [generateContent Turn $turnCount]: Appending Content.model and Content.functionResponses to conversation history.");
          currentContents.add(Content.model(modelParts));
          currentContents.add(Content.functionResponses(responses));
        }
      } catch (e, stackTrace) {
        debugPrint(
            "GenerativeService Exception in local MCP client generateContent: $e");
        debugPrint("Stack trace: $stackTrace");
        try {
          final historyJson = jsonEncode(currentContents
              .map((c) => {
                    'role': c.role,
                    'parts': c.parts.map((p) {
                      if (p is TextPart)
                        return {'type': 'text', 'text': p.text};
                      if (p is FunctionCall)
                        return {
                          'type': 'functionCall',
                          'name': p.name,
                          'args': p.args
                        };
                      if (p is FunctionResponse)
                        return {
                          'type': 'functionResponse',
                          'name': p.name,
                          'response': p.response
                        };
                      return {'type': 'unknown', 'string': p.toString()};
                    }).toList(),
                  })
              .toList());
          debugPrint("Current Contents context at failure: $historyJson");
        } catch (encodeError) {
          debugPrint(
              "Failed to encode currentContents for debugging: $encodeError");
        }
        return "Error: $e";
      } finally {
        mcpClient.dispose();
      }
    }

    // Fallback to server-side generation if no MCP/AccessToken is available
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
    // Check if we can use the Robinhood MCP client
    RobinhoodMcpClient? mcpClient;
    List<Tool>? modelTools;
    final List<String> mcpToolNames = [];

    final accessToken = await getMcpAccessToken();

    if (accessToken != null) {
      try {
        mcpClient = RobinhoodMcpClient(accessToken);
        final mcpTools =
            await mcpClient.listTools().timeout(const Duration(seconds: 5));
        if (mcpTools.isNotEmpty) {
          final List<FunctionDeclaration> functionDeclarations = [];
          for (final tool in mcpTools) {
            final name = tool.name;
            final description = tool.description;
            final inputSchema = tool.inputSchema.toJson();
            functionDeclarations.add(FunctionDeclaration(
              name,
              description ?? '',
              parameters: _parseJsonSchemaProperties(inputSchema),
              optionalParameters: _getOptionalParameters(inputSchema),
            ));
            mcpToolNames.add(name);
          }
          if (functionDeclarations.isNotEmpty) {
            modelTools = [
              Tool.functionDeclarations(functionDeclarations),
              // Tool.googleSearch(),
            ];
          }
        }
      } catch (e) {
        debugPrint("Error initializing MCP client tools: $e");
        mcpClient?.dispose();
        mcpClient = null;
      }
    }

    String context = "";

    // Add portfolio context if stores are provided AND MCP is NOT connected.
    // If MCP is connected, let it fetch details dynamically via tools.
    final mcpConnected = mcpClient != null && modelTools != null;
    if (!mcpConnected &&
        includePortfolio &&
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

    // Create a local model instance if we have tools, else use default
    final activeModel = mcpConnected
        ? FirebaseAI.vertexAI().generativeModel(
            model: RemoteConfigService.instance.aiModelName.isNotEmpty
                ? RemoteConfigService.instance.aiModelName
                : 'gemini-2.5-flash-lite',
            systemInstruction:
                buildSystemInstruction(mcpToolNames: mcpToolNames),
            tools: modelTools,
          )
        : model;

    final currentContents = [Content.text(promptString)];
    final mainBuffer = StringBuffer();

    if (mcpConnected) {
      debugPrint(
          "GenerativeService [streamChatMessage]: Local MCP is connected. Active tools count: ${modelTools.length}");
      debugPrint("  Tool functions available for Gemini: $mcpToolNames");
    } else {
      debugPrint(
          "GenerativeService [streamChatMessage]: Standard stream call (no local MCP connection).");
    }

    try {
      int turnCount = 0;
      while (true) {
        turnCount++;
        List<FunctionCall> pendingCalls = [];
        final turnBuffer = StringBuffer();

        debugPrint(
            "GenerativeService [streamChatMessage Turn $turnCount]: Calling generateContentStream with ${currentContents.length} items in history.");
        int eventCount = 0;
        await for (final event
            in activeModel.generateContentStream(currentContents)) {
          eventCount++;
          if (event.functionCalls.isNotEmpty) {
            debugPrint(
                "GenerativeService [streamChatMessage Turn $turnCount Event $eventCount]: Received ${event.functionCalls.length} raw functionCalls: ${event.functionCalls.map((c) => c.name).toList()}");
            for (final call in event.functionCalls) {
              debugPrint(
                  "    Raw Call name: ${call.name}, args: ${jsonEncode(call.args)}");
            }
            pendingCalls.addAll(event.functionCalls);
          }
          // Collect text part
          final text = event.text;
          if (text != null && text.isNotEmpty) {
            final current = turnBuffer.toString();
            if (current.isEmpty) {
              turnBuffer.write(text);
            } else if (text.startsWith(current)) {
              turnBuffer.write(text.substring(current.length));
            } else if (!current.endsWith(text)) {
              turnBuffer.write(text);
            }
            yield mainBuffer.toString() + turnBuffer.toString();
          }
        }

        // Commit turnBuffer to mainBuffer
        mainBuffer.write(turnBuffer.toString());
        debugPrint(
            "GenerativeService [streamChatMessage Turn $turnCount]: Finished parsing stream. Total events: $eventCount. Accumulated text length: ${turnBuffer.length}, raw pending function calls collected: ${pendingCalls.length}");

        if (pendingCalls.isEmpty || mcpClient == null) {
          debugPrint(
              "GenerativeService [streamChatMessage Turn $turnCount]: No function calls generated. Conversing complete!");
          break;
        }

        // We have pending calls, deduplicate and execute them!
        final deduplicatedCalls = _deduplicateCalls(pendingCalls);
        debugPrint(
            "GenerativeService [streamChatMessage Turn $turnCount]: Deduplicated functionCalls count: ${deduplicatedCalls.length}");

        List<FunctionResponse> responses = [];
        for (final call in deduplicatedCalls) {
          mainBuffer.write("\n\n> ⚙️ **Executing tool:** `${call.name}`");
          if (call.args.isNotEmpty) {
            mainBuffer.write("\n> *Arguments:* `${jsonEncode(call.args)}`");
          }
          yield mainBuffer.toString();
          debugPrint(
              "  Executing tool: ${call.name} with arguments: ${jsonEncode(call.args)}");

          try {
            final result = await mcpClient.callTool(call.name, call.args);
            Map<String, Object?> resultMap;
            if (result is Map) {
              resultMap = result.cast<String, Object?>();
            } else {
              resultMap = {'result': result};
            }
            responses.add(FunctionResponse(call.name, resultMap));

            final resultStr = jsonEncode(resultMap);
            mainBuffer.write("\n> 📥 **Response:** `$resultStr`\n\n");
            yield mainBuffer.toString();
            debugPrint("    Success from tool ${call.name}: $resultStr");
          } catch (e) {
            responses.add(FunctionResponse(call.name, {'error': e.toString()}));
            mainBuffer.write("\n> ❌ **Error:** `$e`\n\n");
            yield mainBuffer.toString();
            debugPrint("    Error from tool ${call.name}: $e");
          }
        }

        final List<Part> modelParts = [];
        final turnText = turnBuffer.toString();
        if (turnText.isNotEmpty) {
          modelParts.add(TextPart(turnText));
        }
        if (deduplicatedCalls.isNotEmpty) {
          modelParts.addAll(
              deduplicatedCalls.map((c) => FunctionCall(c.name, c.args)));
        }

        debugPrint(
            "GenerativeService [streamChatMessage Turn $turnCount]: Appending Content.model and Content.functionResponses to conversation history.");
        currentContents.add(Content.model(modelParts));
        currentContents.add(Content.functionResponses(responses));
      }
    } catch (e, stackTrace) {
      debugPrint("GenerativeService Exception in streamChatMessage: $e");
      debugPrint("Stack trace: $stackTrace");
      try {
        final historyJson = jsonEncode(currentContents
            .map((c) => {
                  'role': c.role,
                  'parts': c.parts.map((p) {
                    if (p is TextPart) return {'type': 'text', 'text': p.text};
                    if (p is FunctionCall)
                      return {
                        'type': 'functionCall',
                        'name': p.name,
                        'args': p.args
                      };
                    if (p is FunctionResponse)
                      return {
                        'type': 'functionResponse',
                        'name': p.name,
                        'response': p.response
                      };
                    return {'type': 'unknown', 'string': p.toString()};
                  }).toList(),
                })
            .toList());
        debugPrint("Current Contents context at failure: $historyJson");
      } catch (encodeError) {
        debugPrint(
            "Failed to encode currentContents for debugging: $encodeError");
      }
      rethrow;
    } finally {
      mcpClient?.dispose();
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

  Future<Map<String, String>> _discoverEndpoints() async {
    final prefs = await SharedPreferences.getInstance();

    final regEp = prefs.getString('mcp_registration_endpoint');
    var authEp = prefs.getString('mcp_authorization_endpoint');
    final tokenEp = prefs.getString('mcp_token_endpoint');

    if (authEp == 'https://robinhood.com/oauth/authorize') {
      await prefs.remove('mcp_authorization_endpoint');
      authEp = null;
    }

    if (regEp != null && authEp != null && tokenEp != null) {
      return {
        'registration_endpoint': regEp,
        'authorization_endpoint': authEp,
        'token_endpoint': tokenEp,
      };
    }

    String registrationEndpoint =
        'https://agent.robinhood.com/oauth/trading/register';
    String authorizationEndpoint = 'https://robinhood.com/oauth';
    String tokenEndpoint = 'https://api.robinhood.com/oauth2/token/';

    try {
      final resourceUri = Uri.parse('https://agent.robinhood.com/mcp/trading');
      final resourceMetaUri = Uri.parse(
          '${resourceUri.origin}/.well-known/oauth-protected-resource${resourceUri.path}');

      final resResponse =
          await http.get(resourceMetaUri).timeout(const Duration(seconds: 5));
      if (resResponse.statusCode == 200) {
        final resData = jsonDecode(resResponse.body);
        final authServers = resData['authorization_servers'] as List<dynamic>?;
        if (authServers != null && authServers.isNotEmpty) {
          final authServerStr = authServers.first as String;
          final authServerUri = Uri.parse(authServerStr);
          final authMetaUri = Uri.parse(
              '${authServerUri.origin}/.well-known/oauth-authorization-server${authServerUri.path}');

          final authResponse =
              await http.get(authMetaUri).timeout(const Duration(seconds: 5));
          if (authResponse.statusCode == 200) {
            final authData = jsonDecode(authResponse.body);

            registrationEndpoint =
                authData['registration_endpoint'] as String? ??
                    registrationEndpoint;
            authorizationEndpoint =
                authData['authorization_endpoint'] as String? ??
                    authorizationEndpoint;
            tokenEndpoint =
                authData['token_endpoint'] as String? ?? tokenEndpoint;

            await prefs.setString(
                'mcp_registration_endpoint', registrationEndpoint);
            await prefs.setString(
                'mcp_authorization_endpoint', authorizationEndpoint);
            await prefs.setString('mcp_token_endpoint', tokenEndpoint);
          }
        }
      }
    } catch (e) {
      debugPrint(
          "Error performing OAuth discovery: $e. Using fallback endpoints.");
    }

    return {
      'registration_endpoint': registrationEndpoint,
      'authorization_endpoint': authorizationEndpoint,
      'token_endpoint': tokenEndpoint,
    };
  }

  String _resolveMcpRedirectUri() {
    // Robinhood's OAuth callback must be platform-compatible.
    // if (kIsWeb) {
    //   return 'https://realizealpha.web.app/oauth-callback';
    // }
    // return 'realizealpha://login-callback';
    return 'http://127.0.0.1:33418/';
  }

  Future<String> _getOrRegisterClientId(String redirectUri) async {
    final prefs = await SharedPreferences.getInstance();

    // Always force fresh registration to avoid stale client metadata
    // Clear any cached client ID before re-registering
    await prefs.remove('mcp_client_id');
    await prefs.remove('mcp_redirect_uri');

    final endpoints = await _discoverEndpoints();
    final registrationEndpoint = endpoints['registration_endpoint']!;

    try {
      final response = await http.post(
        Uri.parse(registrationEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'client_name': 'RealizeAlpha',
          'redirect_uris': [
            'http://127.0.0.1:33418/',
          ],
          'grant_types': ['authorization_code', 'refresh_token'],
          'response_types': ['code'],
          'token_endpoint_auth_method': 'none',
          'scope': 'internal',
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final clientId = data['client_id'] as String?;
        if (clientId != null && clientId.isNotEmpty) {
          await prefs.setString('mcp_client_id', clientId);
          await prefs.setString('mcp_redirect_uri', redirectUri);
          debugPrint(
              "Successfully registered MCP client: $clientId with redirect URI: $redirectUri");
          return clientId;
        }
      }
      throw Exception(
          'Failed to register client: ${response.statusCode} - ${response.body}');
    } catch (e) {
      debugPrint("Error registering dynamic client: $e");
      rethrow;
    }
  }

  Future<String?> getMcpAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('mcp_access_token');
    final refreshToken = prefs.getString('mcp_refresh_token');
    final expiryTimeMs = prefs.getInt('mcp_token_expiry_ms');

    if (accessToken == null || refreshToken == null) {
      return null;
    }

    // Check if expired or expiring in the next 5 minutes
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (expiryTimeMs == null || nowMs >= (expiryTimeMs - 5 * 60 * 1000)) {
      try {
        final success = await refreshMcpToken(refreshToken);
        if (success) {
          return prefs.getString('mcp_access_token');
        }
      } catch (e) {
        debugPrint("Error refreshing MCP token: $e");
      }
      return null;
    }

    return accessToken;
  }

  Future<bool> refreshMcpToken(String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    final clientId = prefs.getString('mcp_client_id');
    if (clientId == null || clientId.isEmpty) {
      return false;
    }

    final endpoints = await _discoverEndpoints();
    final tokenEndpoint = endpoints['token_endpoint']!;

    try {
      final response = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': clientId,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;
        final expiresIn = data['expires_in'] as int? ?? 86400;

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await prefs.setString('mcp_access_token', newAccessToken);
          if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
            await prefs.setString('mcp_refresh_token', newRefreshToken);
          }
          final expiryMs =
              DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);
          await prefs.setInt('mcp_token_expiry_ms', expiryMs);
          return true;
        }
      }
    } catch (e) {
      debugPrint("Error during refreshMcpToken: $e");
    }
    return false;
  }

  Future<bool> authorizeMcp([BuildContext? context]) async {
    final prefs = await SharedPreferences.getInstance();

    final endpoints = await _discoverEndpoints();
    final authorizationEndpoint = endpoints['authorization_endpoint']!;
    final tokenEndpoint = endpoints['token_endpoint']!;
    final redirectUri = _resolveMcpRedirectUri();

    String clientId;
    try {
      clientId = await _getOrRegisterClientId(redirectUri);
    } catch (e) {
      debugPrint("Authorization failed during registration phase: $e");
      return false;
    }

    final state = _generateState();
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    final authUrl = Uri.parse(authorizationEndpoint).replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'scope': 'internal',
        'resource': 'https://agent.robinhood.com/mcp/trading',
      },
    ).toString();

    try {
      debugPrint("Launching MCP Authorization URL: $authUrl");
      debugPrint(
          "Expected redirect URI: $redirectUri, Callback scheme: ${Uri.parse(redirectUri).scheme}");

      String? resultUrl;
      if (context != null &&
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android)) {
        resultUrl = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (context) => McpOAuthWebViewPage(
              initialUrl: authUrl,
              redirectUri: redirectUri,
            ),
          ),
        );
      } else {
        final callbackScheme = Uri.parse(redirectUri).scheme;
        resultUrl = await FlutterWebAuth2.authenticate(
          url: authUrl,
          callbackUrlScheme: callbackScheme,
        );
      }

      if (resultUrl == null) {
        debugPrint("Authorization cancelled or returned null.");
        return false;
      }

      debugPrint("OAuth callback received. Result URL: $resultUrl");

      final returnedUri = Uri.parse(resultUrl);

      // Check for OAuth error parameters
      final error = returnedUri.queryParameters['error'];
      final errorDescription = returnedUri.queryParameters['error_description'];
      if (error != null && error.isNotEmpty) {
        debugPrint(
            "Authorization failed with error: $error, description: $errorDescription");
        return false;
      }

      final code = returnedUri.queryParameters['code'];
      final returnedState = returnedUri.queryParameters['state'];

      debugPrint(
          "Code present: ${code != null && code.isNotEmpty}, State match: ${returnedState == state}");

      if (code == null || code.isEmpty) {
        debugPrint(
            "Authorization failed: No authorization code returned. Query parameters: ${returnedUri.queryParameters}");
        return false;
      }
      if (returnedState != state) {
        debugPrint(
            "Authorization failed: State mismatch. Expected: $state, Got: $returnedState");
        return false;
      }

      debugPrint("Exchanging authorization code for tokens...");
      final tokenResponse = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'client_id': clientId,
          'code_verifier': codeVerifier,
        },
      ).timeout(const Duration(seconds: 15));

      if (tokenResponse.statusCode == 200) {
        final data = jsonDecode(tokenResponse.body);
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;
        final expiresIn = data['expires_in'] as int? ?? 86400;

        if (accessToken != null && accessToken.isNotEmpty) {
          await prefs.setString('mcp_access_token', accessToken);
          if (refreshToken != null && refreshToken.isNotEmpty) {
            await prefs.setString('mcp_refresh_token', refreshToken);
          }
          final expiryMs =
              DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);
          await prefs.setInt('mcp_token_expiry_ms', expiryMs);
          debugPrint(
              "MCP Authorization successful. Access token obtained via manual PKCE.");
          return true;
        }
      } else {
        debugPrint(
            "Failed to exchange code for token: ${tokenResponse.statusCode} - ${tokenResponse.body}");
      }
    } catch (e) {
      debugPrint("Authorization flow failed: $e");
    }

    return false;
  }

  Future<void> disconnectMcp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mcp_access_token');
    await prefs.remove('mcp_refresh_token');
    await prefs.remove('mcp_token_expiry_ms');
    await prefs.remove('mcp_client_id');
    await prefs.remove('mcp_redirect_uri');
    await prefs.remove('mcp_registration_endpoint');
    await prefs.remove('mcp_authorization_endpoint');
    await prefs.remove('mcp_token_endpoint');
  }

  String _generateState() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url
        .encode(values)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
  }

  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url
        .encode(values)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url
        .encode(digest.bytes)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
  }
}

Schema _parseJsonSchema(Map<String, dynamic> schemaMap) {
  final typeObj = schemaMap['type'];
  String? type;
  if (typeObj is String) {
    type = typeObj;
  } else if (typeObj is List) {
    final nonNullType =
        typeObj.firstWhere((t) => t != 'null', orElse: () => null);
    if (nonNullType != null) {
      type = nonNullType.toString();
    } else if (typeObj.isNotEmpty) {
      type = typeObj.first.toString();
    }
  }
  final description = schemaMap['description'] as String?;

  switch (type) {
    case 'string':
      return Schema.string(description: description);
    case 'integer':
      return Schema.integer(description: description);
    case 'number':
      return Schema.number(description: description);
    case 'boolean':
      return Schema.boolean(description: description);
    case 'array':
      final items = schemaMap['items'];
      if (items is Map<String, dynamic>) {
        return Schema.array(
          items: _parseJsonSchema(items),
          description: description,
        );
      }
      return Schema.array(items: Schema.string(), description: description);
    case 'object':
    default:
      final properties = schemaMap['properties'] as Map<String, dynamic>? ?? {};
      final Map<String, Schema> geminiProps = {};
      properties.forEach((key, val) {
        if (val is Map<String, dynamic>) {
          geminiProps[key] = _parseJsonSchema(val);
        }
      });
      return Schema.object(
        properties: geminiProps,
        optionalProperties: _getOptionalParameters(schemaMap),
        description: description,
      );
  }
}

Map<String, Schema> _parseJsonSchemaProperties(Map<String, dynamic> schemaMap) {
  final properties = schemaMap['properties'] as Map<String, dynamic>? ?? {};
  final Map<String, Schema> geminiProps = {};
  properties.forEach((key, val) {
    if (val is Map<String, dynamic>) {
      geminiProps[key] = _parseJsonSchema(val);
    }
  });
  return geminiProps;
}

List<String> _getOptionalParameters(Map<String, dynamic> schemaMap) {
  final properties = schemaMap['properties'] as Map<String, dynamic>? ?? {};
  final requiredPropsList = schemaMap['required'] as List<dynamic>?;
  final Set<String> requiredProps = requiredPropsList != null
      ? requiredPropsList.map((e) => e.toString()).toSet()
      : <String>{};

  final List<String> optionalProps = [];
  properties.forEach((key, val) {
    if (!requiredProps.contains(key)) {
      optionalProps.add(key.toString());
    }
  });
  return optionalProps;
}

List<FunctionCall> _deduplicateCalls(List<FunctionCall> calls) {
  final List<FunctionCall> deduplicated = [];
  final Set<String> seen = {};
  for (final call in calls) {
    try {
      final signature = "${call.name}:${jsonEncode(call.args)}";
      if (!seen.contains(signature)) {
        seen.add(signature);
        deduplicated.add(call);
      } else {
        debugPrint(
            "GenerativeService: Skipping duplicate function call from stream: ${call.name} with args: ${call.args}");
      }
    } catch (e) {
      // Fallback if jsonEncode fails on args
      deduplicated.add(call);
    }
  }
  return deduplicated;
}

class RobinhoodMcpClient {
  final String _accessToken;
  mcp.McpClient? _client;
  mcp.StreamableHttpClientTransport? _transport;
  final Completer<void> _connectCompleter = Completer<void>();
  bool _isDisposed = false;

  RobinhoodMcpClient(this._accessToken) {
    _connect();
  }

  Future<void> _connect() async {
    try {
      _client = mcp.McpClient(
        mcp.Implementation(
          name: 'RealizeAlpha MCP Client',
          title: 'RealizeAlpha MCP Client',
          version: '1.0.0',
          description: 'RealizeAlpha MCP Client for Robinhood Agentic Trading',
          icons: const [],
          websiteUrl: '',
        ),
        options: mcp.McpClientOptions(
          capabilities: mcp.ClientCapabilities(),
        ),
      );

      _transport = mcp.StreamableHttpClientTransport(
        Uri.parse('https://agent.robinhood.com/mcp/trading'),
        opts: mcp.StreamableHttpClientTransportOptions(
          requestInit: {
            'headers': {
              'Authorization': 'Bearer $_accessToken',
            },
          },
        ),
      );

      await _client!.connect(_transport!);

      if (!_connectCompleter.isCompleted) {
        _connectCompleter.complete();
      }
    } catch (e) {
      debugPrint("Failed to initialize MCP connection: $e");
      if (!_connectCompleter.isCompleted) {
        _connectCompleter.completeError(e);
      }
    }
  }

  Future<void> _ensureConnected() async {
    if (_isDisposed) {
      throw Exception('MCP client is disposed');
    }
    await _connectCompleter.future;
    if (_client == null) {
      throw Exception('MCP client connection is not available');
    }
  }

  Future<List<mcp.Tool>> listTools() async {
    await _ensureConnected();
    final result = await _client!.listTools();
    return result.tools;
  }

  Future<dynamic> callTool(String name, Map<String, dynamic> arguments) async {
    await _ensureConnected();
    final response = await _client!.callTool(
      mcp.CallToolRequest(
        name: name,
        arguments: arguments,
      ),
    );
    return response.toJson();
  }

  void dispose() {
    _isDisposed = true;
    try {
      _transport?.close();
    } catch (e) {
      debugPrint("Error closing MCP transport: $e");
    }
    _client = null;
    _transport = null;
  }
}
