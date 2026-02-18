import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/generative_provider.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_event.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/animated_price_text.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/chat_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/income_transactions_widget.dart';
import 'package:robinhood_options_mobile/widgets/insider_activity_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_chart_widget.dart';
import 'package:robinhood_options_mobile/model/institutional_ownership.dart';
import 'package:robinhood_options_mobile/widgets/institutional_ownership_widget.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';
import 'package:robinhood_options_mobile/widgets/option_chain_widget.dart';
import 'package:robinhood_options_mobile/widgets/list_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_order_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_note_widget.dart';
import 'package:robinhood_options_mobile/widgets/options_flow_widget.dart';
import 'package:robinhood_options_mobile/widgets/pnl_badge.dart';
import 'package:robinhood_options_mobile/widgets/position_order_widget.dart';
import 'package:robinhood_options_mobile/widgets/price_targets_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_signal_notification_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/strategy_builder_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_instrument_widget.dart';
import 'package:url_launcher/url_launcher.dart';
//import 'package:charts_flutter/flutter.dart' as charts;

import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/widgets/indicator_documentation_widget.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/watchlist.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/auto_trade_status_badge_widget.dart';
import 'package:robinhood_options_mobile/widgets/backtesting_widget.dart';
import 'package:share_plus/share_plus.dart';

import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/model/esg_score.dart';
import 'package:robinhood_options_mobile/services/esg_service.dart';

class InstrumentWidget extends StatefulWidget {
  const InstrumentWidget(
      this.brokerageUser,
      this.service,
      //this.account,
      this.instrument,
      {super.key,
      required this.analytics,
      required this.observer,
      required this.generativeService,
      required this.user,
      required this.userDocRef,
      this.heroTag,
      this.scrollToTradeSignal = false,
      this.initialIsPaperTrade = false});

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  final User? user;
  final DocumentReference<User>? userDocRef;
  //final Account account;
  final Instrument instrument;
  final String? heroTag;
  final bool scrollToTradeSignal;
  final bool initialIsPaperTrade;

  @override
  State<InstrumentWidget> createState() => _InstrumentWidgetState();
}

class _InstrumentWidgetState extends State<InstrumentWidget> {
  Future<ESGScore?>? _esgFuture;
  final ESGService _esgService = ESGService();
  Future<InstitutionalOwnership?>? _institutionalOwnershipFuture;
  final YahooService _yahooService = YahooService();

  // ... existing state variables ...
  final FirestoreService _firestoreService = FirestoreService();

  Future<Quote?>? futureQuote;
  Future<Fundamentals?>? futureFundamentals;
  Future<InstrumentHistoricals>? futureHistoricals;
  Future<InstrumentHistoricals>? futureRsiHistoricals;
  Future<List<dynamic>>? futureNews;
  Future<List<dynamic>>? futureLists;
  Future<List<dynamic>>? futureDividends;
  Future<dynamic>? futureRatings;
  Future<dynamic>? futureRatingsOverview;
  Future<dynamic>? futureEarnings;
  Future<List<dynamic>>? futureSimilar;
  Future<List<dynamic>>? futureSplits;
  Future<List<InstrumentOrder>>? futureInstrumentOrders;
  Future<List<OptionOrder>>? futureOptionOrders;
  Future<List<OptionEvent>>? futureOptionEvents;
  Future<dynamic>? futureEtp;

  ChartDateSpan chartDateSpanFilter = ChartDateSpan.day;
  Bounds chartBoundsFilter = Bounds.t24_7;

  List<String> optionFilters = <String>[];
  List<String> positionFilters = <String>[];
  List<bool> hasQuantityFilters = [true, false];

  final List<String> orderFilters = <String>["confirmed", "filled", "queued"];

  double optionOrdersPremiumBalance = 0;
  double positionOrdersBalance = 0;
  // Controls whether all similar instruments are shown or only the first 5.
  final ValueNotifier<bool> _showAllSimilarNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _showAllPositionOrdersNotifier =
      ValueNotifier(false);
  final ValueNotifier<bool> _showAllOptionOrdersNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _showAllNewsNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _showAllEarningsNotifier = ValueNotifier(false);
  // Controls visibility of AI reasoning details in trade signals
  final ValueNotifier<bool> _showAIReasoningNotifier =
      ValueNotifier<bool>(false);
  // Controls visibility of technical indicators details
  final ValueNotifier<bool> _showTechnicalDetailsNotifier =
      ValueNotifier(false);
  // Controls visibility of expanded metadata
  final ValueNotifier<Set<String>> _expandedIndicatorsNotifier =
      ValueNotifier({});
  final ValueNotifier<bool> _showAllListsNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isGeneratingSignalNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isAssessingRiskNotifier = ValueNotifier(false);

  Timer? refreshTriggerTime;
  final GlobalKey tradeSignalKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();

  _InstrumentWidgetState();

  void _updateBalances() {
    var instrument = widget.instrument;
    positionOrdersBalance = instrument.positionOrders != null &&
            instrument.positionOrders!.isNotEmpty
        ? instrument.positionOrders!
            .map((e) =>
                (e.averagePrice != null ? e.averagePrice! * e.quantity! : 0.0) *
                (e.side == "buy" ? 1 : -1))
            .reduce((a, b) => a + b)
        : 0.0;

    optionOrdersPremiumBalance =
        instrument.optionOrders != null && instrument.optionOrders!.isNotEmpty
            ? instrument.optionOrders!
                .map((e) =>
                    (e.processedPremium != null ? e.processedPremium! : 0) *
                    (e.direction == "credit" ? 1 : -1))
                .reduce((a, b) => a + b) as double
            : 0;
  }

  void _loadData() {
    var instrument = widget.instrument;
    var user = widget.brokerageUser;

    _esgFuture = _esgService.getESGScore(instrument.symbol);
    _institutionalOwnershipFuture =
        _yahooService.getInstitutionalOwnership(instrument.symbol);

    var optionOrderStore =
        Provider.of<OptionOrderStore>(context, listen: false);
    var optionOrders = optionOrderStore.items
        .where((element) => element.chainSymbol == widget.instrument.symbol)
        .toList();
    if (optionOrders.isNotEmpty) {
      futureOptionOrders = Future.value(optionOrders);
    } else if (widget.instrument.tradeableChainId != null) {
      futureOptionOrders = widget.service.getOptionOrders(widget.brokerageUser,
          optionOrderStore, widget.instrument.tradeableChainId!);
    } else {
      futureOptionOrders = Future.value([]);
    }
    futureOptionOrders?.then((value) {
      if (mounted) {
        setState(() {
          instrument.optionOrders = value;
          _updateBalances();
        });
      }
    });

    var stockPositionOrderStore =
        Provider.of<InstrumentOrderStore>(context, listen: false);
    var positionOrders = stockPositionOrderStore.items
        .where((element) => element.instrumentId == widget.instrument.id)
        .toList();
    if (positionOrders.isNotEmpty) {
      futureInstrumentOrders = Future.value(positionOrders);
    } else {
      futureInstrumentOrders = widget.service.getInstrumentOrders(
          widget.brokerageUser,
          stockPositionOrderStore,
          [widget.instrument.url]);
    }
    futureInstrumentOrders?.then((value) {
      if (mounted) {
        setState(() {
          instrument.positionOrders = value;
          _updateBalances();
        });
      }
    });

    if (widget.instrument.logoUrl == null &&
        RobinhoodService.logoUrls.containsKey(widget.instrument.symbol) &&
        auth.currentUser != null) {
      widget.instrument.logoUrl =
          RobinhoodService.logoUrls[widget.instrument.symbol];
      _firestoreService.upsertInstrument(widget.instrument);
    }

    //if (instrument.quoteObj == null) {
    futureQuote = widget.service.getQuote(user,
        Provider.of<QuoteStore>(context, listen: false), instrument.symbol);
    futureQuote?.then((value) {
      if (mounted) {
        setState(() {
          instrument.quoteObj = value;
        });
      }
    });
    //}

    if (instrument.fundamentalsObj == null) {
      futureFundamentals = widget.service.getFundamentals(user, instrument);
      futureFundamentals?.then((value) {
        if (mounted) {
          setState(() {
            instrument.fundamentalsObj = value;
          });
        }
      });
    }

    futureNews = widget.service.getNews(user, instrument.symbol);
    futureNews?.then((value) {
      if (mounted) {
        setState(() {
          instrument.newsObj = value;
        });
      }
    });

    futureLists = widget.service.getLists(user, instrument.id);
    futureLists?.then((value) {
      if (mounted) {
        setState(() {
          instrument.listsObj = value;
        });
      }
    });

    futureDividends = widget.service.getDividends(
        user,
        Provider.of<DividendStore>(context, listen: false),
        Provider.of<InstrumentStore>(context, listen: false),
        instrumentId: instrument.id);
    futureDividends?.then((value) {
      if (mounted) {
        setState(() {
          instrument.dividendsObj = value;
        });
      }
    });

    futureRatings = widget.service.getRatings(user, instrument.id);
    futureRatings?.then((value) {
      if (mounted) {
        setState(() {
          instrument.ratingsObj = value;
        });
      }
    });

    futureRatingsOverview =
        widget.service.getRatingsOverview(user, instrument.id);
    futureRatingsOverview?.then((value) {
      if (mounted) {
        setState(() {
          instrument.ratingsOverviewObj = value;
        });
      }
    });

    futureOptionEvents = widget.service
        .getOptionEventsByInstrumentUrl(widget.brokerageUser, instrument.url);
    futureOptionEvents?.then((value) {
      if (mounted) {
        setState(() {
          instrument.optionEvents = value;
        });
      }
    });

    futureEarnings = widget.service.getEarnings(user, instrument.id);
    futureEarnings?.then((value) {
      if (mounted) {
        setState(() {
          instrument.earningsObj = value;
        });
      }
    });

    futureSimilar = widget.service.getSimilar(user, instrument.id);
    futureSimilar?.then((value) {
      if (mounted) {
        setState(() {
          instrument.similarObj = value;
        });
      }
    });

    futureSplits = widget.service.getSplits(user, instrument);
    futureSplits?.then((value) {
      if (mounted) {
        setState(() {
          instrument.splitsObj = value;
        });
      }
    });

    futureHistoricals = widget.service.getInstrumentHistoricals(
        user,
        Provider.of<InstrumentHistoricalsStore>(context, listen: false),
        instrument.symbol,
        chartBoundsFilter: chartBoundsFilter,
        chartDateSpanFilter: chartDateSpanFilter);
    futureHistoricals?.then((value) {
      if (mounted) {
        setState(() {
          instrument.instrumentHistoricalsObj = value;
        });
      }
    });

    if (instrument.type == 'etp' && widget.service is RobinhoodService) {
      futureEtp =
          (widget.service as RobinhoodService).getEtpDetails(user, instrument);
      futureEtp?.then((value) {
        if (mounted) {
          setState(() {
            instrument.etpDetails = value;
            if (auth.currentUser != null) {
              _firestoreService.upsertInstrument(instrument);
            }
          });
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.scrollToTradeSignal) {
      _showTechnicalDetailsNotifier.value = true;
    }

    if (widget.scrollToTradeSignal) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Add a small delay to ensure the widget is fully built and expanded
        await Future.delayed(const Duration(milliseconds: 300));
        if (tradeSignalKey.currentContext != null) {
          Scrollable.ensureVisible(tradeSignalKey.currentContext!,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              alignment: 0.0);
        }
      });
    }

    _loadData();

    _startRefreshTimer();

    widget.analytics.logScreenView(
      screenName: 'Instrument/${widget.instrument.symbol}',
    );
    Provider.of<TradeSignalsProvider>(context, listen: false)
        .fetchTradeSignal(widget.instrument.symbol);
  }

  @override
  void dispose() {
    _stopRefreshTimer();
    _showAIReasoningNotifier.dispose();
    _showAllSimilarNotifier.dispose();
    _showAllPositionOrdersNotifier.dispose();
    _showAllNewsNotifier.dispose();
    _showAllEarningsNotifier.dispose();
    _showTechnicalDetailsNotifier.dispose();
    _expandedIndicatorsNotifier.dispose();
    _showAllListsNotifier.dispose();
    _isGeneratingSignalNotifier.dispose();
    _isAssessingRiskNotifier.dispose();
    super.dispose();
  }

/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  Request to https://api.robinhood.com/marketdata/options/?instruments=942d3704-7247-454f-9fb6-1f98f5d41702 failed with status 400: Bad Request.
  */

  /// Builds a portfolio state map with cash and all stock positions.
  ///
  /// Returns a map containing:
  /// - 'cash': The available portfolio cash from the account
  /// - For each position: symbol -> {quantity, price} or just quantity if price unavailable
  Future<void> _generateTradeSignal(BuildContext context) async {
    if (_isGeneratingSignalNotifier.value) return;

    _isGeneratingSignalNotifier.value = true;

    try {
      final portfolioState = _buildPortfolioState(context);
      final price = widget.instrument.quoteObj?.lastExtendedHoursTradePrice ??
          widget.instrument.quoteObj?.lastTradePrice;

      if (price == null) {
        throw Exception('Unable to fetch current price');
      }

      // Generate new signal via initiateTradeProposal
      final tradeSignalsProvider =
          Provider.of<TradeSignalsProvider>(context, listen: false);
      final agenticTradingProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      await tradeSignalsProvider.initiateTradeProposal(
        symbol: widget.instrument.symbol,
        currentPrice: price,
        portfolioState: portfolioState,
        config: agenticTradingProvider.config,
      );

      // Wait briefly to ensure Firestore write has completed
      await Future.delayed(const Duration(milliseconds: 500));

      // Refresh the signal from Firestore
      await Provider.of<TradeSignalsProvider>(context, listen: false)
          .fetchTradeSignal(widget.instrument.symbol);

      if (mounted) {
        Scrollable.ensureVisible(tradeSignalKey.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trade signal generated successfully!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating signal: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        _isGeneratingSignalNotifier.value = false;
      }
    }
  }

  Future<void> _runRiskAssessment(
      Map<String, dynamic> signal, String signalType) async {
    if (_isAssessingRiskNotifier.value) return;

    _isAssessingRiskNotifier.value = true;

    try {
      final proposal = {
        'symbol': widget.instrument.symbol,
        'action': signalType,
        'quantity': signal['proposal']?['quantity'] ?? 1,
        'price': signal['proposal']?['price'] ?? 0,
      };

      final portfolioState = _buildPortfolioState(context);

      final tradeSignalsProvider =
          Provider.of<TradeSignalsProvider>(context, listen: false);
      final agenticTradingProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      final result = await tradeSignalsProvider.assessTradeRisk(
        proposal: proposal,
        portfolioState: portfolioState,
        config: agenticTradingProvider.config,
      );

      // Update assessment in the signal and refresh UI
      signal['assessment'] = result;
      if (mounted) {
        setState(() {});
      }

      if (mounted) {
        await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  result['approved']
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: result['approved'] ? Colors.green : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result['approved']
                        ? 'Risk Assessment Passed'
                        : 'Risk Assessment Failed',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: result['approved']
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Status:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        result['approved'] ? 'Approved' : 'Rejected',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: result['approved']
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (result['reason'] != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Reason:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result['reason'],
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error running risk assessment: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        _isAssessingRiskNotifier.value = false;
      }
    }
  }

  Map<String, dynamic> _buildPortfolioState(BuildContext context) {
    // Get actual portfolio cash from account (same as Home widget)
    double cash = 0.0;
    double buyingPower = 0.0;
    final accountStore = Provider.of<AccountStore>(context, listen: false);
    if (accountStore.items.isNotEmpty) {
      final account = accountStore.items.first;
      cash = account.portfolioCash ?? 0.0;
      buyingPower = account.buyingPower ?? cash;
    }

    final stockPositionStore =
        Provider.of<InstrumentPositionStore>(context, listen: false);

    final Map<String, dynamic> portfolioState = {
      'buyingPower': buyingPower,
      'cashAvailable': cash,
    };

    // Add all stock positions with their quantities and prices
    for (final position in stockPositionStore.items) {
      if (position.instrumentObj != null &&
          position.quantity != null &&
          position.quantity! > 0) {
        final posSymbol = position.instrumentObj!.symbol;
        final posQuantity = position.quantity!;
        final posPrice =
            position.instrumentObj!.quoteObj?.lastExtendedHoursTradePrice ??
                position.instrumentObj!.quoteObj?.lastTradePrice;

        if (posPrice != null) {
          // Store as object with quantity and price for accurate valuation
          portfolioState[posSymbol] = {
            'quantity': posQuantity,
            'price': posPrice,
          };
        } else {
          // Fallback to just quantity if price unavailable
          portfolioState[posSymbol] = posQuantity;
        }
      }
    }

    return portfolioState;
  }

  Future<void> _generateAIContent(
      GenerativeProvider provider, String key, String promptText) async {
    provider.startGenerating(key);
    try {
      var prompt = Prompt(
        key: key,
        title: 'AI Insight',
        prompt: promptText,
      );
      // Using null for stores as we don't need portfolio context for symbol specific analysis usually,
      var response = await widget.generativeService.generateContentFromServer(
          prompt, null, null, null // Pass nulls for stores
          );
      provider.setGenerativeResponse(key, response);
    } catch (e) {
      provider.setGenerativeResponse(
          key, "Failed to generate insight. Please try again.");
    }
  }

  Widget _buildAIInsights(BuildContext context) {
    return Consumer<GenerativeProvider>(
        builder: (context, generativeProvider, child) {
      final summaryKey = 'insight-${widget.instrument.symbol}-summary';
      final sentimentKey = 'insight-${widget.instrument.symbol}-sentiment';
      final newsKey = 'insight-${widget.instrument.symbol}-news';
      final keyLevelsKey = 'insight-${widget.instrument.symbol}-key-levels';
      final strategyKey = 'insight-${widget.instrument.symbol}-strategy';

      // Check if we are currently generating for this instrument
      final isGeneratingSummary = generativeProvider.generating &&
          generativeProvider.generatingPrompt == summaryKey;
      final isGeneratingSentiment = generativeProvider.generating &&
          generativeProvider.generatingPrompt == sentimentKey;
      final isGeneratingNews = generativeProvider.generating &&
          generativeProvider.generatingPrompt == newsKey;
      final isGeneratingKeyLevels = generativeProvider.generating &&
          generativeProvider.generatingPrompt == keyLevelsKey;
      final isGeneratingStrategy = generativeProvider.generating &&
          generativeProvider.generatingPrompt == strategyKey;

      if (!generativeProvider.promptResponses.containsKey(summaryKey) &&
          !generativeProvider.promptResponses.containsKey(sentimentKey) &&
          !generativeProvider.promptResponses.containsKey(newsKey) &&
          !generativeProvider.promptResponses.containsKey(keyLevelsKey) &&
          !generativeProvider.promptResponses.containsKey(strategyKey) &&
          !isGeneratingSummary &&
          !isGeneratingSentiment &&
          !isGeneratingNews &&
          !isGeneratingKeyLevels &&
          !isGeneratingStrategy) {
        // Collapsed state visualization or just existing state
      }

      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Card(
            elevation: 0,
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: Icon(Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('AI Market Insights',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Analysis & Trade Ideas'),
              initiallyExpanded: generativeProvider.promptResponses
                      .containsKey(summaryKey) ||
                  generativeProvider.promptResponses
                      .containsKey(sentimentKey) ||
                  generativeProvider.promptResponses.containsKey(newsKey) ||
                  generativeProvider.promptResponses
                      .containsKey(keyLevelsKey) ||
                  generativeProvider.promptResponses.containsKey(strategyKey),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          ActionChip(
                            avatar: isGeneratingSummary
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.summarize, size: 16),
                            label: const Text('Summary'),
                            onPressed: () async {
                              if (isGeneratingSummary) return;
                              await _generateAIContent(
                                  generativeProvider,
                                  summaryKey,
                                  'Tell me about ${widget.instrument.symbol} and its recent performance in markdown format. Keep it concise.');
                            },
                          ),
                          ActionChip(
                            avatar: isGeneratingSentiment
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.bar_chart, size: 16),
                            label: const Text('Sentiment'),
                            onPressed: () async {
                              if (isGeneratingSentiment) return;
                              await _generateAIContent(
                                  generativeProvider,
                                  sentimentKey,
                                  'Analyze the market sentiment for ${widget.instrument.symbol}. Include bullish and bearish factors.');
                            },
                          ),
                          ActionChip(
                            avatar: isGeneratingKeyLevels
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.layers, size: 16),
                            label: const Text('Key Levels'),
                            onPressed: () async {
                              if (isGeneratingKeyLevels) return;
                              await _generateAIContent(
                                  generativeProvider,
                                  keyLevelsKey,
                                  'Identify key support and resistance levels for ${widget.instrument.symbol} based on recent price action.');
                            },
                          ),
                          ActionChip(
                            avatar: isGeneratingStrategy
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.lightbulb, size: 16),
                            label: const Text('Strategy'),
                            onPressed: () async {
                              if (isGeneratingStrategy) return;
                              await _generateAIContent(
                                  generativeProvider,
                                  strategyKey,
                                  'Suggest an options trading strategy for ${widget.instrument.symbol} given the current market conditions.');
                            },
                          ),
                          ActionChip(
                            avatar: isGeneratingNews
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.newspaper, size: 16),
                            label: const Text('News Analysis'),
                            onPressed: () async {
                              if (isGeneratingNews) return;
                              await _generateAIContent(
                                  generativeProvider,
                                  newsKey,
                                  'Analyze the latest news for ${widget.instrument.symbol} and explain why it is moving. Be concise.');
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.chat, size: 16),
                            label: const Text('Ask Assistant'),
                            onPressed: () =>
                                _openAIChat(context, widget.instrument),
                          ),
                        ],
                      ),
                      if (generativeProvider.promptResponses[summaryKey] !=
                          null) ...[
                        const Divider(),
                        const Text("Summary",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        MarkdownBody(
                            data: generativeProvider
                                .promptResponses[summaryKey]!),
                      ],
                      if (generativeProvider.promptResponses[sentimentKey] !=
                          null) ...[
                        const Divider(),
                        const Text("Sentiment",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        MarkdownBody(
                            data: generativeProvider
                                .promptResponses[sentimentKey]!),
                      ],
                      if (generativeProvider.promptResponses[keyLevelsKey] !=
                          null) ...[
                        const Divider(),
                        const Text("Key Levels",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        MarkdownBody(
                            data: generativeProvider
                                .promptResponses[keyLevelsKey]!),
                      ],
                      if (generativeProvider.promptResponses[strategyKey] !=
                          null) ...[
                        const Divider(),
                        const Text("Strategy Suggestion",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        MarkdownBody(
                            data: generativeProvider
                                .promptResponses[strategyKey]!),
                      ],
                      if (generativeProvider.promptResponses[newsKey] !=
                          null) ...[
                        const Divider(),
                        const Text("News Analysis",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        MarkdownBody(
                            data: generativeProvider.promptResponses[newsKey]!),
                      ],
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    var instrument = widget.instrument;
    return Scaffold(
      body: buildScrollView(instrument, done: instrument.quoteObj != null),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAIChat(context, instrument),
        child: const Icon(Icons.auto_awesome),
      ),
    );
  }

  void _openAIChat(BuildContext context, Instrument instrument) {
    List<Prompt> prompts = [
      Prompt(
        key: 'overview-${instrument.symbol}',
        title: 'Tell me about ${instrument.symbol}',
        prompt:
            'Tell me about ${instrument.symbol} and its recent performance.',
      ),
      Prompt(
        key: 'chart-${instrument.symbol}',
        title: 'Analyze Chart',
        prompt: 'Analyze the technical chart for ${instrument.symbol}.',
      ),
      Prompt(
        key: 'news-${instrument.symbol}',
        title: 'Why is it moving?',
        prompt:
            'Why is ${instrument.symbol} moving today? Summarize recent news.',
      ),
    ];

    if (instrument.tradeableChainId != null) {
      prompts.add(Prompt(
          key: 'option-strategy-${instrument.symbol}',
          title: 'Option Strategy',
          prompt:
              'Suggest an option trading strategy for ${instrument.symbol} based on current market conditions.'));
    }

    prompts.add(Prompt(
        key: 'sentiment-${instrument.symbol}',
        title: 'Sentiment Analysis',
        prompt: 'What is the market sentiment for ${instrument.symbol}?'));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatWidget(
          generativeService: widget.generativeService,
          user: widget.user,
          prompts: prompts,
        ),
      ),
    );
  }

  void _startRefreshTimer() {
    // Start listening to clipboard
    refreshTriggerTime = Timer.periodic(
      const Duration(milliseconds: 15000),
      (timer) async {
        if (widget.brokerageUser.refreshEnabled) {
          await widget.service.getInstrumentHistoricals(
              widget.brokerageUser,
              Provider.of<InstrumentHistoricalsStore>(context, listen: false),
              widget.instrument.symbol,
              chartBoundsFilter: chartBoundsFilter,
              chartDateSpanFilter: chartDateSpanFilter);

          if (!mounted) return;
          await widget.service.refreshQuote(
              widget.brokerageUser,
              Provider.of<QuoteStore>(context, listen: false),
              widget.instrument.symbol);

          /*
          if (futureHistoricals != null) {
            setState(() {
              futureHistoricals = null;
            });
          }
          */
        }
      },
    );
  }

  void _stopRefreshTimer() {
    if (refreshTriggerTime != null) {
      refreshTriggerTime!.cancel();
    }
  }

  void resetChart(ChartDateSpan span, Bounds bounds) {
    setState(() {
      chartDateSpanFilter = span;
      chartBoundsFilter = bounds;
      futureHistoricals = widget.service.getInstrumentHistoricals(
          widget.brokerageUser,
          Provider.of<InstrumentHistoricalsStore>(context, listen: false),
          widget.instrument.symbol,
          chartBoundsFilter: chartBoundsFilter,
          chartDateSpanFilter: chartDateSpanFilter);
      futureHistoricals?.then((value) {
        if (mounted) {
          setState(() {
            widget.instrument.instrumentHistoricalsObj = value;
          });
        }
      });
    });
  }

  RefreshIndicator buildScrollView(Instrument instrument,
      {List<OptionInstrument>? optionInstruments, bool done = false}) {
    return RefreshIndicator(
        onRefresh: _pullRefresh,
        child: CustomScrollView(slivers: [
          SliverLayoutBuilder(
            builder: (BuildContext context, constraints) {
              const expandedHeight = 160.0; // 1800
              final scrolled =
                  math.min(expandedHeight, constraints.scrollOffset) /
                      expandedHeight;
              final t = (1 - scrolled).clamp(0.0, 1.0);
              final opacity = 1.0 - Interval(0, 1).transform(t);
              // debugPrint("transform: $t scrolled: $scrolled");
              return SliverAppBar(
                centerTitle: false,
                title:
                    Consumer<QuoteStore>(builder: (context, quoteStore, child) {
                  return Opacity(
                      opacity: opacity,
                      child: headerTitle(instrument, quoteStore));
                }),
                expandedHeight: 160, // 240 // 280.0,
                floating: false,
                snap: false,
                pinned: true,
                flexibleSpace: LayoutBuilder(builder:
                    (BuildContext context, BoxConstraints constraints) {
                  //var top = constraints.biggest.height;
                  //debugPrint(top.toString());
                  //debugPrint(kToolbarHeight.toString());

                  final settings = context.dependOnInheritedWidgetOfExactType<
                      FlexibleSpaceBarSettings>();
                  final deltaExtent = settings!.maxExtent - settings.minExtent;
                  final t = (1.0 -
                          (settings.currentExtent - settings.minExtent) /
                              deltaExtent)
                      .clamp(0.0, 1.0);
                  final fadeStart =
                      math.max(0.0, 1.0 - kToolbarHeight * 2 / deltaExtent);
                  const fadeEnd = 1.0;
                  final opacity =
                      1.0 - Interval(fadeStart, fadeEnd).transform(t);
                  return FlexibleSpaceBar(
                      //titlePadding:
                      //    const EdgeInsets.only(top: kToolbarHeight * 2, bottom: 15),
                      //background: const FlutterLogo(),
                      background: Hero(
                          tag: widget.heroTag != null
                              ? '${widget.heroTag}'
                              : 'logo_${instrument.symbol}',
                          child: SizedBox(
                              //width: double.infinity,
                              child: instrument.logoUrl != null
                                  ? Image.network(
                                      instrument.logoUrl!,
                                      fit: BoxFit.none,
                                      errorBuilder: (BuildContext context,
                                          Object exception,
                                          StackTrace? stackTrace) {
                                        debugPrint(
                                            'Error with ${instrument.symbol} ${instrument.logoUrl}');
                                        RobinhoodService.removeLogo(instrument);
                                        return Container(); // Text(instrument.symbol);
                                      },
                                    )
                                  : Container() //const FlutterLogo()
                              /*Image.network(
                        Constants.flexibleSpaceBarBackground,
                        fit: BoxFit.cover,
                      ),*/
                              )),
                      title: Opacity(
                        //duration: Duration(milliseconds: 300),
                        opacity:
                            opacity, //top > kToolbarHeight * 3 ? 1.0 : 0.0,
                        child: Consumer<QuoteStore>(
                            builder: (context, quoteStore, child) {
                          return SingleChildScrollView(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children:
                                      getHeaderWidgets(quoteStore).toList()));
                        }),
                        /*
          ListTile(
            title: Text('${instrument.simpleName}'),
            subtitle: Text(instrument.name),
          )*/
                      ));
                }),
                actions: [
                  IconButton(
                    key: _shareButtonKey,
                    icon: const Icon(Icons.share),
                    tooltip: 'Share Instrument',
                    onPressed: () {
                      final symbol = widget.instrument.symbol;
                      final url =
                          'https://realizealpha.web.app/instrument/$symbol';
                      final shareText =
                          'Check out $symbol on RealizeAlpha: $url';

                      final RenderBox? renderBox =
                          _shareButtonKey.currentContext?.findRenderObject()
                              as RenderBox?;
                      Rect? sharePositionOrigin;
                      if (renderBox != null &&
                          renderBox.size.width > 0 &&
                          renderBox.size.height > 0) {
                        final size = renderBox.size;
                        final offset = renderBox.localToGlobal(Offset.zero);
                        sharePositionOrigin = Rect.fromLTWH(
                          offset.dx,
                          offset.dy,
                          size.width,
                          size.height,
                        );
                      }

                      Share.share(
                        shareText,
                        sharePositionOrigin: sharePositionOrigin,
                      );
                    },
                  ),
                  if (auth.currentUser != null)
                    AutoTradeStatusBadgeWidget(
                      user: widget.user,
                      userDocRef: widget.userDocRef,
                      service: widget.service,
                    ),
                  IconButton(
                      icon: auth.currentUser != null
                          ? (auth.currentUser!.photoURL == null
                              ? const Icon(Icons.account_circle)
                              : CircleAvatar(
                                  maxRadius: 12,
                                  backgroundImage: CachedNetworkImageProvider(
                                      auth.currentUser!.photoURL!
                                      //  ?? Constants .placeholderImage, // No longer used
                                      )))
                          : const Icon(Icons.account_circle_outlined),
                      onPressed: () async {
                        var response = await showProfile(
                            context,
                            auth,
                            _firestoreService,
                            widget.analytics,
                            widget.observer,
                            widget.brokerageUser,
                            widget.service);
                        if (response != null) {
                          setState(() {});
                        }
                      }),
                ],
                // actions: <Widget>[
                //   IconButton(
                //     icon: const Icon(Icons.more_vert),
                //     // icon: const Icon(Icons.settings),
                //     onPressed: () {
                //       showModalBottomSheet<void>(
                //         context: context,
                //        showDragHandle: true,
                //         //isScrollControlled: true,
                //         //useRootNavigator: true,
                //         //constraints: const BoxConstraints(maxHeight: 200),
                //         builder: (_) => MoreMenuBottomSheet(
                //           widget.user,
                //           onSettingsChanged: _handleSettingsChanged,
                //           analytics: widget.analytics,
                //           observer: widget.observer,
                //         ),
                //       );
                //     },
                //   ),
                // ],
              );
            },
          ),
          if (auth.currentUser != null) _buildAIInsights(context),
          SliverToBoxAdapter(
              child: Stack(children: [
            if (done == false) ...[
              SizedBox(
                height: 3, //150.0,
                child: Center(
                    child: LinearProgressIndicator(
                        //value: controller.value,
                        //semanticsLabel: 'Linear progress indicator',
                        ) //CircularProgressIndicator(),
                    ),
              ),
            ],
            buildOverview(instrument)
          ])),
          SliverToBoxAdapter(
            child: InstrumentChartWidget(
              instrument: instrument,
              chartDateSpanFilter: chartDateSpanFilter,
              chartBoundsFilter: chartBoundsFilter,
              onFilterChanged: (span, bounds) {
                resetChart(span, bounds);
              },
            ),
          ),
          if (instrument.quoteObj != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            Consumer<InstrumentPositionStore>(
                builder: (context, stockPositionStore, child) {
              return quoteWidget(instrument);
            })
          ],
          Consumer<InstrumentPositionStore>(
              builder: (context, stockPositionStore, child) {
            var position = stockPositionStore.items
                .firstWhereOrNull((e) => e.instrument == instrument.url);
            if (position == null) {
              return SliverToBoxAdapter(child: Container());
            }
            return SliverToBoxAdapter(
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              ListTile(
                  title: Text("Position", style: TextStyle(fontSize: 20)),
                  subtitle:
                      Text('${formatNumber.format(position.quantity!)} shares'),
                  trailing: Text(formatCurrency.format(position.marketValue),
                      style: const TextStyle(fontSize: 21))),
              _buildDetailScrollRow(
                  position, badgeValueFontSize, badgeLabelFontSize,
                  iconSize: 27.0),
              // ListTile(
              //   minTileHeight: 10,
              //   title: const Text("Cost"),
              //   trailing: Text(formatCurrency.format(position.totalCost),
              //       style: const TextStyle(fontSize: 18)),
              // ),
              // ListTile(
              //   minTileHeight: 10,
              //   contentPadding: const EdgeInsets.fromLTRB(0, 0, 24, 8),
              //   // title: const Text("Average Cost"),
              //   trailing: Text(
              //       formatCurrency.format(position.averageBuyPrice),
              //       style: const TextStyle(fontSize: 18)),
              // ),
              // ListTile(
              //   minTileHeight: 10,
              //   title: const Text("Created"),
              //   trailing: Text(formatDate.format(position.createdAt!),
              //       style: const TextStyle(fontSize: 15)),
              // ),
              // ListTile(
              //   minTileHeight: 10,
              //   title: const Text("Updated"),
              //   trailing: Text(formatDate.format(position.updatedAt!),
              //       style: const TextStyle(fontSize: 15)),
              // ),
            ]));
          }),
          Consumer<OptionPositionStore>(
              builder: (context, optionPositionStore, child) {
            var optionPositions = optionPositionStore.items
                .where((e) => e.symbol == widget.instrument.symbol)
                .toList();
            optionPositions.sort((a, b) {
              int comp = a.legs.first.expirationDate!
                  .compareTo(b.legs.first.expirationDate!);
              if (comp != 0) return comp;
              return a.legs.first.strikePrice!
                  .compareTo(b.legs.first.strikePrice!);
            });

            var filteredOptionPositions = optionPositions
                .where((e) =>
                    (hasQuantityFilters[0] && hasQuantityFilters[1]) ||
                    (!hasQuantityFilters[0] || e.quantity! > 0) &&
                        (!hasQuantityFilters[1] || e.quantity! <= 0))
                .toList();
            filteredOptionPositions.sort((a, b) {
              int comp = a.legs.first.expirationDate!
                  .compareTo(b.legs.first.expirationDate!);
              if (comp != 0) return comp;
              return a.legs.first.strikePrice!
                  .compareTo(b.legs.first.strikePrice!);
            });

            return SliverToBoxAdapter(
                child: ShrinkWrappingViewport(
                    offset: ViewportOffset.zero(),
                    slivers: [
                  if (filteredOptionPositions.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 8.0,
                    )),
                    OptionPositionsWidget(widget.brokerageUser, widget.service,
                        filteredOptionPositions,
                        showFooter: false,
                        showGroupHeader: false,
                        analytics: widget.analytics,
                        observer: widget.observer,
                        generativeService: widget.generativeService,
                        user: widget.user,
                        userDocRef: widget.userDocRef)
                  ]
                ]));
          }),
          // Instrument Notes
          if (auth.currentUser != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: InstrumentNoteWidget(
                  instrument: instrument,
                  userId: auth.currentUser?.uid,
                  firestoreService: _firestoreService,
                  generativeService: widget.generativeService,
                ),
              ),
            ),
          ],
          if (instrument.tradeable) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            SliverToBoxAdapter(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                elevation: 0,
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OptionsFlowWidget(
                          initialSymbol: instrument.symbol,
                          brokerageUser: widget.brokerageUser,
                          service: widget.service,
                          analytics: widget.analytics,
                          observer: widget.observer,
                          generativeService: widget.generativeService,
                          user: widget.user,
                          userDocRef: widget.userDocRef,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: const Icon(Icons.water, color: Colors.blue),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Options Flow',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                'View real-time institutional activity for ${instrument.symbol}',
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
          ],
          _buildAgenticTradeSignals(instrument),
          if (instrument.dividendsObj != null &&
              instrument.dividendsObj!.isNotEmpty) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildDividendsWidget(instrument)
          ],
          if (instrument.fundamentalsObj != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            fundamentalsWidget(instrument)
          ],
          SliverToBoxAdapter(child: _buildESGCard()),
          SliverToBoxAdapter(
              child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: PriceTargetsWidget(
              symbol: instrument.symbol,
              generativeService: widget.generativeService,
            ),
          )),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: FutureBuilder<InstitutionalOwnership?>(
                future: _institutionalOwnershipFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  return InstitutionalOwnershipWidget(
                    ownership: snapshot.data,
                    currentPrice: instrument.quoteObj?.lastTradePrice,
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: InsiderActivityWidget(symbol: instrument.symbol),
          )),
          if (instrument.ratingsObj != null &&
              instrument.ratingsObj["summary"] != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildRatingsWidget(instrument)
          ],
          if (instrument.ratingsOverviewObj != null) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildRatingsOverviewWidget(instrument)
          ],
          if (instrument.earningsObj != null &&
              instrument.earningsObj!.isNotEmpty) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildEarningsWidget(instrument)
          ],
          if (instrument.splitsObj != null &&
              instrument.splitsObj!.isNotEmpty) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildSplitsWidget(instrument)
          ],
          if (instrument.newsObj != null
              // && instrument.earningsObj!.isNotEmpty
              ) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildNewsWidget(instrument)
          ],
          if (instrument.listsObj != null &&
              instrument.listsObj!.isNotEmpty) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildListsWidget(instrument)
          ],
          if (instrument.similarObj != null &&
              instrument.similarObj!.isNotEmpty) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 8.0,
            )),
            _buildSimilarWidget(instrument)
          ],
          Consumer<InstrumentOrderStore>(
              builder: (context, stockOrderStore, child) {
            //var positionOrders = stockOrderStore.items.where(
            //    (element) => element.instrumentId == widget.instrument.id);

            if (instrument.positionOrders != null &&
                instrument.positionOrders!.isNotEmpty) {
              return positionOrdersWidget(instrument.positionOrders!);
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }),
          Consumer<OptionOrderStore>(
              builder: (context, optionOrderStore, child) {
            //var optionOrders = optionOrderStore.items.where(
            //    (element) => element.chainSymbol == widget.instrument.symbol);
            if (instrument.optionOrders != null &&
                instrument.optionOrders!.isNotEmpty) {
              return _buildOptionOrdersWidget(instrument.optionOrders!);
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }),
          // TODO: Introduce web banner
          if (!kIsWeb) ...[
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 25.0,
            )),
            SliverToBoxAdapter(
                child: AdBannerWidget(
              size: AdSize.mediumRectangle,
              // searchBanner: true,
            )),
          ],
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
          const SliverToBoxAdapter(child: DisclaimerWidget()),
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
        ]));
  }

  Future<void> _pullRefresh() async {
    setState(() {
      futureQuote = null;
      futureFundamentals = null;
      futureHistoricals = null;
      futureNews = null;
      //futureInstrumentOrders = null;
      //futureOptionOrders = null;
    });
  }

  /*
  void _handleSettingsChanged(dynamic settings) {
    setState(() {
      hasQuantityFilters = settings['hasQuantityFilters'];
      optionFilters = settings['optionFilters'];
      positionFilters = settings['positionFilters'];
    });
  }
  */

  Widget buildOverview(Instrument instrument) {
    if (instrument.quoteObj == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: <Widget>[
          if (instrument.tradeableChainId != null) ...[
            Expanded(
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                icon: const Icon(Icons.list_alt, size: 20),
                label: const FittedBox(
                    fit: BoxFit.scaleDown, child: Text('Chain')),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => InstrumentOptionChainWidget(
                                widget.brokerageUser,
                                widget.service,
                                instrument,
                                analytics: widget.analytics,
                                observer: widget.observer,
                                generativeService: widget.generativeService,
                                user: widget.user,
                                userDocRef: widget.userDocRef,
                              )));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                icon: const Icon(Icons.build, size: 20),
                label: const FittedBox(
                    fit: BoxFit.scaleDown, child: Text('Strategy')),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => StrategyBuilderWidget(
                                user: widget.brokerageUser,
                                service: widget.service,
                                instrument: instrument,
                                analytics: widget.analytics,
                                observer: widget.observer,
                                generativeService: widget.generativeService,
                                appUser: widget.user,
                                userDocRef: widget.userDocRef,
                              )));
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (instrument.tradeable) ...[
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                icon: const Icon(Icons.attach_money, size: 20),
                label: const FittedBox(
                    fit: BoxFit.scaleDown, child: Text('Trade')),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TradeInstrumentWidget(
                              widget.brokerageUser,
                              widget.service,
                              instrument: instrument,
                              positionType: "Buy",
                              analytics: widget.analytics,
                              observer: widget.observer,
                              initialIsPaperTrade: widget.initialIsPaperTrade,
                            ))),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Badge helpers extracted for reuse across detail & quote scroll rows.

  SingleChildScrollView _buildDetailScrollRow(
      InstrumentPosition ops, double valueFontSize, double labelFontSize,
      {double iconSize = 23.0}) {
    List<Widget> tiles = [];

    double? totalReturn = widget.brokerageUser
        .getDisplayValueInstrumentPosition(ops,
            displayValue: DisplayValue.totalReturn);
    String? totalReturnText = widget.brokerageUser
        .getDisplayText(totalReturn, displayValue: DisplayValue.totalReturn);

    double? totalReturnPercent = widget.brokerageUser
        .getDisplayValueInstrumentPosition(ops,
            displayValue: DisplayValue.totalReturnPercent);
    String? totalReturnPercentText = widget.brokerageUser.getDisplayText(
        totalReturnPercent,
        displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = widget.brokerageUser
        .getDisplayValueInstrumentPosition(ops,
            displayValue: DisplayValue.todayReturn);
    String? todayReturnText = widget.brokerageUser
        .getDisplayText(todayReturn, displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = widget.brokerageUser
        .getDisplayValueInstrumentPosition(ops,
            displayValue: DisplayValue.todayReturnPercent);
    String? todayReturnPercentText = widget.brokerageUser.getDisplayText(
        todayReturnPercent,
        displayValue: DisplayValue.todayReturnPercent);

    tiles = [
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: todayReturnText,
                value: todayReturn,
                fontSize: valueFontSize),
            Text("Return Today", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: todayReturnPercentText,
                value: todayReturnPercent,
                fontSize: valueFontSize),
            Text("Return Today %", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: totalReturnText,
                value: totalReturn,
                fontSize: valueFontSize),
            Text("Total Return", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: totalReturnPercentText,
                value: totalReturnPercent,
                fontSize: valueFontSize),
            Text("Total Return %", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: widget.brokerageUser.getDisplayText(ops.totalCost,
                    displayValue: DisplayValue.totalCost),
                fontSize: valueFontSize,
                neutral: true),
            Text("Cost", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: widget.brokerageUser.getDisplayText(ops.averageBuyPrice!,
                    displayValue: DisplayValue.lastPrice),
                fontSize: valueFontSize,
                neutral: true),
            Text("Cost per share", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: formatCompactDateYear.format(ops.createdAt!),
                fontSize: valueFontSize,
                neutral: true),
            Text("Opened", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: formatCompactDateYear.format(ops.updatedAt!),
                fontSize: valueFontSize,
                neutral: true),
            Text("Updated", style: TextStyle(fontSize: labelFontSize))
          ])),
    ];
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ...tiles,
            ])));
  }

  SingleChildScrollView _buildQuoteScrollRow(
      Instrument ops, double valueFontSize, double labelFontSize,
      {double iconSize = 23.0}) {
    List<Widget> tiles = [];

    // double? totalReturn = 0;
    // widget.user
    //     .getPositionDisplayValue(ops, displayValue: DisplayValue.totalReturn);
    // String? totalReturnText = '';
    // widget.user
    //     .getDisplayText(totalReturn!, displayValue: DisplayValue.totalReturn);

    // double? totalReturnPercent = 0;
    // widget.user.getPositionDisplayValue(ops,
    //     displayValue: DisplayValue.totalReturnPercent);
    // String? totalReturnPercentText = widget.user.getDisplayText(
    //     totalReturnPercent!,
    //     displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = ops.quoteObj?.changeToday;
    String? todayReturnText = widget.brokerageUser.getDisplayText(
        todayReturn ?? 0,
        displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = ops.quoteObj?.changePercentToday;
    String? todayReturnPercentText = widget.brokerageUser.getDisplayText(
        todayReturnPercent ?? 0,
        displayValue: DisplayValue.todayReturnPercent);

    tiles = [
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: todayReturnText,
                value: todayReturn,
                fontSize: valueFontSize),
            Text("Change Today", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: todayReturnPercentText,
                value: todayReturnPercent,
                fontSize: valueFontSize),
            Text("Change Today %", style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: widget.brokerageUser.getDisplayText(
                    ops.quoteObj?.bidPrice ?? 0,
                    displayValue: DisplayValue.lastPrice),
                fontSize: valueFontSize,
                neutral: true),
            Text("Bid x ${ops.quoteObj?.bidSize ?? 0}",
                style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: widget.brokerageUser.getDisplayText(
                    ops.quoteObj?.askPrice ?? 0,
                    displayValue: DisplayValue.lastPrice),
                fontSize: valueFontSize,
                neutral: true),
            Text("Ask x ${ops.quoteObj?.askSize ?? 0}",
                style: TextStyle(fontSize: labelFontSize))
          ])),
      Padding(
          padding: const EdgeInsets.all(summaryEgdeInset),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PnlBadge(
                text: widget.brokerageUser.getDisplayText(
                    ops.quoteObj?.adjustedPreviousClose ?? 0,
                    displayValue: DisplayValue.lastPrice),
                fontSize: valueFontSize,
                neutral: true),
            Text("Previous Close", style: TextStyle(fontSize: labelFontSize))
          ])),
    ];
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ...tiles,
            ])));
  }

  Widget quoteWidget(Instrument instrument) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          ListTile(
            title: const Text(
              "Quote",
              style: TextStyle(fontSize: 20),
            ),
            subtitle: instrument.quoteObj!.lastExtendedHoursTradePrice != null
                ? const Text('Extended hours')
                : null,
            trailing: Text(
                formatCurrency.format(
                    instrument.quoteObj!.lastExtendedHoursTradePrice ??
                        instrument.quoteObj!.lastTradePrice),
                style: const TextStyle(fontSize: 21)),
          ),
          _buildQuoteScrollRow(
              instrument, badgeValueFontSize, badgeLabelFontSize,
              iconSize: 27.0),
        ],
      ),
    );
  }

  Widget fundamentalsWidget(Instrument instrument) {
    if (instrument.fundamentalsObj == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final f = instrument.fundamentalsObj!;
    final etp = instrument.etpDetails;

    final stats = <Map<String, String>>[];
    if (f.open != null) {
      stats.add({"label": "Open", "value": formatCurrency.format(f.open)});
    }
    if (f.high != null) {
      stats.add({"label": "High", "value": formatCurrency.format(f.high)});
    }
    if (f.low != null) {
      stats.add({"label": "Low", "value": formatCurrency.format(f.low)});
    }
    if (f.high52Weeks != null) {
      stats.add(
          {"label": "52W High", "value": formatCurrency.format(f.high52Weeks)});
    }
    if (f.low52Weeks != null) {
      stats.add(
          {"label": "52W Low", "value": formatCurrency.format(f.low52Weeks)});
    }
    if (f.volume != null) {
      stats.add(
          {"label": "Volume", "value": formatCompactNumber.format(f.volume)});
    }
    if (f.averageVolume != null) {
      stats.add({
        "label": "Avg Vol",
        "value": formatCompactNumber.format(f.averageVolume)
      });
    }
    if (f.averageVolume30Days != null) {
      stats.add({
        "label": "Avg Vol (30D)",
        "value": formatCompactNumber.format(f.averageVolume30Days)
      });
    }
    if (f.marketCap != null) {
      stats.add({
        "label": "Mkt Cap",
        "value": formatCompactNumber.format(f.marketCap)
      });
    }
    if (f.sharesOutstanding != null) {
      stats.add({
        "label": "Shares Out",
        "value": formatCompactNumber.format(f.sharesOutstanding)
      });
    }
    if (f.float != null) {
      stats.add(
          {"label": "Float", "value": formatCompactNumber.format(f.float)});
    }
    if (instrument.maintenanceRatio != null) {
      stats.add({
        "label": "Maint Req",
        "value": formatPercentage.format(instrument.maintenanceRatio)
      });
    }
    if (f.peRatio != null) {
      stats
          .add({"label": "P/E Ratio", "value": formatNumber.format(f.peRatio)});
    }
    if (f.pbRatio != null) {
      stats
          .add({"label": "P/B Ratio", "value": formatNumber.format(f.pbRatio)});
    }
    if (f.dividendYield != null) {
      stats.add({
        "label": "Div Yield",
        "value": formatNumber.format(f.dividendYield)
      });
    }
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            title: Text(
              "Fundamentals",
              style: TextStyle(fontSize: 20),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withAlpha(77),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Wrap(
                      runSpacing: 12,
                      children: stats
                          .map((s) => SizedBox(
                              width: (MediaQuery.of(context).size.width - 64) /
                                  3, // 3 columns approx
                              child: _buildStatItem(s["label"]!, s["value"]!)))
                          .toList(),
                    ),
                  ),
                  if (f.description.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text("About",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(f.description,
                            style: const TextStyle(
                                height: 1.4, fontSize: 14, color: Colors.grey)))
                  ],
                  if (f.sector.isNotEmpty ||
                      f.industry.isNotEmpty ||
                      f.ceo.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text("Profile",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    if (f.sector.isNotEmpty)
                      _buildFundamentalRow("Sector", f.sector),
                    if (f.industry.isNotEmpty)
                      _buildFundamentalRow("Industry", f.industry),
                    if (f.numEmployees != null)
                      _buildFundamentalRow("Employees",
                          formatCompactNumber.format(f.numEmployees!)),
                    if (f.yearFounded != null)
                      _buildFundamentalRow("Founded", f.yearFounded.toString()),
                    if (instrument.listDate != null)
                      _buildFundamentalRow("List Date",
                          formatShortDate.format(instrument.listDate!)),
                    if (f.headquartersCity.isNotEmpty)
                      _buildFundamentalRow("Headquarters",
                          "${f.headquartersCity}, ${f.headquartersState}"),
                    if (instrument.country.isNotEmpty)
                      _buildFundamentalRow("Country", instrument.country),
                    if (f.ceo.isNotEmpty) _buildFundamentalRow("CEO", f.ceo),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(),
                  ),
                  _buildFundamentalRow(
                      "Type",
                      instrument.type == "stock"
                          ? "Stock"
                          : (instrument.type == "etp"
                              ? "Exchange Traded Product"
                              : instrument.type)),
                  if (instrument.type == "etp" && etp != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text("ETF Details",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold))),
                    ),
                    if (etp["inception_date"] != null)
                      _buildFundamentalRow(
                          "Inception",
                          formatShortDate
                              .format(DateTime.parse(etp["inception_date"]))),
                    if (etp["aum"] != null)
                      _buildFundamentalRow(
                          "AUM",
                          formatCompactCurrency
                              .format(double.parse(etp["aum"]))),
                    if (etp["gross_expense_ratio"] != null)
                      _buildFundamentalRow(
                          "Expense Ratio",
                          formatPercentage.format(
                              double.tryParse(etp["gross_expense_ratio"])! /
                                  100)),
                    if (etp["sec_yield"] != null)
                      _buildFundamentalRow(
                          "SEC Yield",
                          formatPercentage.format(
                              double.tryParse(etp["sec_yield"])! / 100)),
                    if (etp["month_end_date"] != null &&
                        etp["month_end_performance"]?["market"]?["1Y"] != null)
                      ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -3),
                        title: const Text("Month Performance",
                            style: TextStyle(fontSize: 14)),
                        subtitle: Text("1 year to ${etp["month_end_date"]}",
                            style: const TextStyle(fontSize: 12)),
                        trailing: Text(
                            formatPercentage.format(double.tryParse(
                                    etp["month_end_performance"]["market"]
                                        ["1Y"])! /
                                100),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                      ),
                    if (etp["quarter_end_date"] != null &&
                        etp["quarter_end_performance"]?["market"]
                                ?["since_inception"] !=
                            null)
                      ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -3),
                        title: const Text("Quarter Performance",
                            style: TextStyle(fontSize: 14)),
                        subtitle: Text(
                            "Since inception to ${etp["quarter_end_date"]}",
                            style: const TextStyle(fontSize: 12)),
                        trailing: Text(
                            formatPercentage.format(double.tryParse(
                                    etp["quarter_end_performance"]["market"]
                                        ["since_inception"])! /
                                100),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                      ),
                    if (etp["is_inverse"] == true ||
                        etp["is_leveraged"] == true ||
                        etp["is_volatility_linked"] == true ||
                        etp["is_crypto_futures"] == true ||
                        etp["is_actively_managed"] == true)
                      ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -2),
                        title: const Text("Characteristics",
                            style: TextStyle(fontSize: 14)),
                        subtitle: Wrap(
                          spacing: 6,
                          runSpacing: 0,
                          children: [
                            if (etp["is_inverse"] == true)
                              const Chip(
                                  label: Text("Inverse",
                                      style: TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  labelPadding:
                                      EdgeInsets.symmetric(horizontal: 8)),
                            if (etp["is_leveraged"] == true)
                              const Chip(
                                  label: Text("Leveraged",
                                      style: TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  labelPadding:
                                      EdgeInsets.symmetric(horizontal: 8)),
                            if (etp["is_volatility_linked"] == true)
                              const Chip(
                                  label: Text("Volatility",
                                      style: TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  labelPadding:
                                      EdgeInsets.symmetric(horizontal: 8)),
                            if (etp["is_crypto_futures"] == true)
                              const Chip(
                                  label: Text("Crypto",
                                      style: TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  labelPadding:
                                      EdgeInsets.symmetric(horizontal: 8)),
                            if (etp["is_actively_managed"] == true)
                              const Chip(
                                  label: Text("Active",
                                      style: TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  labelPadding:
                                      EdgeInsets.symmetric(horizontal: 8)),
                          ],
                        ),
                      ),
                    if (etp["total_holdings"] != null)
                      ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -3),
                        title: const Text("Holdings",
                            style: TextStyle(fontSize: 14)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(formatNumber.format(etp["total_holdings"]),
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 4),
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: IconButton(
                                iconSize: 16,
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.info_outline),
                                onPressed: () =>
                                    _showHoldingsDialog(context, instrument),
                              ),
                            )
                          ],
                        ),
                      ),
                  ],
                  if (f.marketDate != null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "Data as of ${formatShortDate.format(f.marketDate!)}",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundamentalRow(String title, String value) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -3),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Text(value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showHoldingsDialog(BuildContext context, Instrument instrument) {
    showDialog<String>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              title: Text('${instrument.symbol} Holdings'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Table(
                    border: TableBorder.all(
                        color: Theme.of(context).dividerColor, width: 0.5),
                    columnWidths: const {
                      0: FlexColumnWidth(4),
                      1: FlexColumnWidth(1)
                    },
                    children: [
                      for (var holding
                          in instrument.etpDetails["holdings"]) ...[
                        TableRow(children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SelectableText(holding["name"]),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SelectableText(holding["weight"]),
                          ),
                        ])
                      ]
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ));
  }

  Widget _buildRatingsWidget(Instrument instrument) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            title: Text(
              "Analyst Ratings",
              style: TextStyle(fontSize: 20),
            ),
          ),
          GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _buildRatingCard(
                context,
                "Buy",
                instrument.ratingsObj["summary"]["num_buy_ratings"],
                Colors.green,
                instrument.ratingsObj["ratings"],
                "buy",
              ),
              _buildRatingCard(
                context,
                "Hold",
                instrument.ratingsObj["summary"]["num_hold_ratings"],
                Colors.grey,
                instrument.ratingsObj["ratings"],
                "hold",
              ),
              _buildRatingCard(
                context,
                "Sell",
                instrument.ratingsObj["summary"]["num_sell_ratings"],
                Colors.red,
                instrument.ratingsObj["ratings"],
                "sell",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard(BuildContext context, String title, int? count,
      Color color, List<dynamic> ratings, String type) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          showDialog<String>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: Text('$title Ratings'),
              content: SingleChildScrollView(
                  child: Column(children: [
                for (var rating in ratings) ...[
                  if (rating["type"] == type) ...[
                    Text("${rating["text"]}\n"),
                    Text(
                        "${formatLongDate.format(DateTime.parse(rating["published_at"]))}\n",
                        style: const TextStyle(fontSize: 11.0)),
                  ]
                ]
              ])),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, 'OK'),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              count != null ? formatCompactNumber.format(count) : "-",
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingsOverviewWidget(Instrument instrument) {
    if (instrument.ratingsOverviewObj == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            title: Text(
              "Research",
              style: TextStyle(fontSize: 20),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (instrument.ratingsOverviewObj!["fair_value"] != null) ...[
                  ListTile(
                    title: const Text("Fair Value"),
                    trailing: Text(
                        formatCurrency.format(double.parse(instrument
                            .ratingsOverviewObj!["fair_value"]["value"])),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                ],
                ListTile(
                  title: const Text("Economic Moat"),
                  trailing: Text(
                      instrument.ratingsOverviewObj!["economic_moat"]
                          .toString()
                          .capitalize(),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                ),
                if (instrument.ratingsOverviewObj!["star_rating"] != null) ...[
                  ListTile(
                      title: const Text("Star Rating"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0;
                              i <
                                  int.parse(instrument
                                      .ratingsOverviewObj!["star_rating"]);
                              i++) ...[
                            const Icon(Icons.star, color: Colors.amber),
                          ]
                        ],
                      )),
                ],
                ListTile(
                  title: const Text("Stewardship"),
                  trailing: Text(
                      instrument.ratingsOverviewObj!["stewardship"]
                          .toString()
                          .capitalize(),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                ),
                ListTile(
                  title: const Text("Uncertainty"),
                  trailing: Text(
                      instrument.ratingsOverviewObj!["uncertainty"]
                          .toString()
                          .replaceAll('_', ' ')
                          .capitalize(),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                ),
                ListTile(
                  title: Text(
                    instrument.ratingsOverviewObj!["report_title"],
                    style: const TextStyle(
                        fontSize: 16.0, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                      instrument.ratingsOverviewObj!["report_updated_at"] !=
                              null
                          ? "Updated ${formatDate.format(DateTime.parse(instrument.ratingsOverviewObj!["report_updated_at"]))} by ${instrument.ratingsOverviewObj!["source"].toString().capitalize()}"
                          : "Published ${formatDate.format(DateTime.parse(instrument.ratingsOverviewObj!["report_published_at"]))} by ${instrument.ratingsOverviewObj!["source"].toString().capitalize()}",
                      style: const TextStyle(fontSize: 14)),
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        child: const Text('DOWNLOAD REPORT'),
                        onPressed: () async {
                          var url =
                              instrument.ratingsOverviewObj!["download_url"];
                          var uri = Uri.parse(url);
                          await canLaunchUrl(uri)
                              ? await launchUrl(uri)
                              : throw 'Could not launch $url';
                        },
                      ),
                    ])
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsWidget(Instrument instrument) {
    dynamic futureEarning;
    dynamic pastEarning;
    final earnings = instrument.earningsObj!;
    if (earnings.isNotEmpty) {
      futureEarning = earnings[earnings.length - 1];
      pastEarning = earnings[earnings.length - 2];
    }

    return SliverToBoxAdapter(
      child: ValueListenableBuilder<bool>(
          valueListenable: _showAllEarningsNotifier,
          builder: (context, showAllEarnings, child) {
            final displayCount = showAllEarnings
                ? earnings.length
                : (earnings.length > 3 ? 3 : earnings.length);
            final displayEarnings = earnings.take(displayCount).toList();

            return Column(
              children: [
                const ListTile(
                  title: Text(
                    "Earnings",
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayEarnings.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    var earning = displayEarnings[index];
                    return Column(
                      children: [
                        ListTile(
                            title: Text(
                              "${earning!["year"]} Q${earning!["quarter"]}",
                              style: const TextStyle(
                                  fontSize: 16.0, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                                earning!["report"] != null
                                    ? "Report${earning!["report"]["verified"] ? "ed" : "ing"} ${formatDate.format(DateTime.parse(earning!["report"]["date"]))} ${earning!["report"]["timing"]}"
                                    : "",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                )),
                            trailing: (earning!["eps"]["estimate"] != null ||
                                    earning!["eps"]["actual"] != null)
                                ? Wrap(spacing: 16.0, children: [
                                    if (earning!["eps"]["estimate"] !=
                                        null) ...[
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text("Estimate",
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color)),
                                          Text(
                                              formatCurrency.format(
                                                  double.parse(earning!["eps"]
                                                      ["estimate"])),
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500)),
                                        ],
                                      )
                                    ],
                                    if (earning!["eps"]["actual"] != null) ...[
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text("Actual",
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color)),
                                          Text(
                                              formatCurrency.format(
                                                  double.parse(earning!["eps"]
                                                      ["actual"])),
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold))
                                        ],
                                      )
                                    ]
                                  ])
                                : null),
                        if (earning!["call"] != null &&
                            ((pastEarning["year"] == earning!["year"] &&
                                    pastEarning["quarter"] ==
                                        earning!["quarter"]) ||
                                (futureEarning["year"] == earning!["year"] &&
                                    futureEarning["quarter"] ==
                                        earning!["quarter"]))) ...[
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!earning!["report"]["verified"]) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    "Report${earning!["report"]["verified"] ? "ed" : "ing"} ${formatDate.format(DateTime.parse(earning!["report"]["date"]))} ${earning!["report"]["timing"]}",
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    formatLongDate.format(DateTime.parse(
                                        earning!["call"]["datetime"])),
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color),
                                  ),
                                ],
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: <Widget>[
                                      if (earning!["call"]["replay_url"] !=
                                          null) ...[
                                        TextButton(
                                          child: const Text('LISTEN TO REPLAY'),
                                          onPressed: () async {
                                            var url =
                                                earning!["call"]["replay_url"];
                                            var uri = Uri.parse(url);
                                            await canLaunchUrl(uri)
                                                ? await launchUrl(uri)
                                                : throw 'Could not launch $url';
                                          },
                                        ),
                                      ],
                                      if (earning!["call"]["broadcast_url"] !=
                                          null) ...[
                                        const SizedBox(width: 8),
                                        TextButton(
                                          child:
                                              const Text('LISTEN TO BROADCAST'),
                                          onPressed: () async {
                                            var url = earning!["call"]
                                                ["broadcast_url"];
                                            var uri = Uri.parse(url);
                                            await canLaunchUrl(uri)
                                                ? await launchUrl(uri)
                                                : throw 'Could not launch $url';
                                          },
                                        ),
                                      ],
                                    ])
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                if (earnings.length > 3)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                        onPressed: () {
                          _showAllEarningsNotifier.value = !showAllEarnings;
                        },
                        icon: Icon(showAllEarnings
                            ? Icons.expand_less
                            : Icons.expand_more),
                        label: Text(showAllEarnings
                            ? 'Show Less'
                            : 'Show All (${earnings.length})')),
                  ),
                const SizedBox(height: 16),
              ],
            );
          }),
    );
  }

  Widget _buildDividendsWidget(Instrument instrument) {
    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      IncomeTransactionsWidget(
          widget.brokerageUser,
          widget.service,
          Provider.of<DividendStore>(context, listen: false),
          Provider.of<InstrumentPositionStore>(context, listen: false),
          Provider.of<InstrumentOrderStore>(context, listen: false),
          Provider.of<ChartSelectionStore>(context, listen: false),
          transactionSymbolFilters: [instrument.symbol],
          showChips: false,
          showList: true,
          showFooter: false,
          showYield: true,
          analytics: widget.analytics,
          observer: widget.observer),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ]));
  }

  Widget _buildSplitsWidget(Instrument instrument) {
    var splits = instrument.splitsObj ?? [];
    return SliverToBoxAdapter(
      child: Column(
        children: [
          const ListTile(
            title: Text(
              "Splits",
              style: TextStyle(fontSize: 20),
            ),
          ),
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: splits.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (BuildContext context, int index) {
              var split = splits[index]; // Note: Assumes splitsObj existence
              var splitText = "${split["multiplier"]} Split";
              try {
                var multiplier = double.parse(split["multiplier"]);
                if (multiplier > 1) {
                  if (multiplier % 1 == 0) {
                    splitText = "${multiplier.toInt()} for 1 Split";
                  } else {
                    splitText = "$multiplier for 1 Split";
                  }
                } else if (multiplier > 0 && multiplier < 1) {
                  var reverse = 1 / multiplier;
                  if ((reverse - reverse.round()).abs() < 0.001) {
                    splitText = "1 for ${reverse.round()} Reverse Split";
                  } else {
                    splitText = "1 for $reverse Reverse Split";
                  }
                }
              } catch (e) {
                // ignore
              }
              return ListTile(
                title: Text(
                  splitText,
                  style: const TextStyle(
                      fontSize: 16.0, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                    "Ex-Date: ${formatDate.format(DateTime.parse(split["execution_date"]))}",
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color)),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSimilarWidget(Instrument instrument) {
    final similar = instrument.similarObj!;

    return SliverToBoxAdapter(
        child: ValueListenableBuilder<bool>(
            valueListenable: _showAllSimilarNotifier,
            builder: (context, showAllSimilar, child) {
              final displayCount = showAllSimilar
                  ? similar.length
                  : (similar.length > 3 ? 3 : similar.length);

              return Column(children: [
                const ListTile(
                  title: Text(
                    "Similar",
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayCount,
                    separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          indent: 72,
                          endIndent: 16,
                        ),
                    itemBuilder: (BuildContext context, int index) {
                      var logoUrl = similar[index]["logo_url"]
                          ?.toString()
                          .replaceAll("https:////", "https://");
                      return InkWell(
                        onTap: () async {
                          var similarInstruments = await widget.service
                              .getInstrumentsByIds(
                                  widget.brokerageUser,
                                  Provider.of<InstrumentStore>(context,
                                      listen: false),
                                  [similar[index]["instrument_id"]]);
                          if (logoUrl != null &&
                              logoUrl != similarInstruments[0].logoUrl &&
                              auth.currentUser != null) {
                            similarInstruments[0].logoUrl = logoUrl;
                            await _firestoreService
                                .upsertInstrument(similarInstruments[0]);
                          }
                          if (context.mounted) {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => InstrumentWidget(
                                          widget.brokerageUser,
                                          widget.service,
                                          similarInstruments[0],
                                          analytics: widget.analytics,
                                          observer: widget.observer,
                                          generativeService:
                                              widget.generativeService,
                                          user: widget.user,
                                          userDocRef: widget.userDocRef,
                                        )));
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            children: [
                              Hero(
                                tag: 'logo_${similar[index]["symbol"]}',
                                child: logoUrl != null
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: logoUrl,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorWidget: (context, url, error) =>
                                              CircleAvatar(
                                                  radius: 20,
                                                  child: Text(
                                                      similar[index]["symbol"]
                                                          .substring(0, 1),
                                                      style: const TextStyle(
                                                          fontSize: 16))),
                                        ),
                                      )
                                    : CircleAvatar(
                                        radius: 20,
                                        child: Text(
                                            similar[index]["symbol"]
                                                .substring(0, 1),
                                            style:
                                                const TextStyle(fontSize: 16))),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${similar[index]["symbol"]}",
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      "${similar[index]["name"]}",
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              )
                            ],
                          ),
                        ),
                      );
                    }),
                if (similar.length > 5)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                        onPressed: () {
                          _showAllSimilarNotifier.value = !showAllSimilar;
                        },
                        icon: Icon(showAllSimilar
                            ? Icons.expand_less
                            : Icons.expand_more),
                        label: Text(showAllSimilar
                            ? 'Show Less'
                            : 'Show All (${similar.length})')),
                  ),
                const SizedBox(height: 16),
              ]);
            }));
  }

  void _showCreateListDialog(Function onListCreated) {
    final TextEditingController nameController = TextEditingController();
    String selectedEmoji = "💡";
    final List<String> emojis = [
      "💡",
      "🔥",
      "🚀",
      "💰",
      "📈",
      "📉",
      "👀",
      "❤️",
      "⭐",
      "⚠️"
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Create New List"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "List Name"),
                ),
                const SizedBox(height: 16),
                const Text("Select Icon"),
                Wrap(
                  spacing: 8.0,
                  children: emojis.map((emoji) {
                    return ChoiceChip(
                      label: Text(emoji, style: const TextStyle(fontSize: 24)),
                      selected: selectedEmoji == emoji,
                      onSelected: (bool selected) {
                        setStateDialog(() {
                          selectedEmoji = emoji;
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: const Text("Create"),
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    try {
                      await widget.service.createList(
                          widget.brokerageUser, nameController.text,
                          emoji: selectedEmoji);
                      if (context.mounted) {
                        Navigator.pop(context);
                        onListCreated();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    }
                  }
                },
              ),
            ],
          );
        });
      },
    );
  }

  void _showAddToListDialog() {
    var futureAllLists = widget.service.getAllLists(widget.brokerageUser);
    Set<String>? selectedListIds;
    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Add to List"),
              content: FutureBuilder<List<Watchlist>>(
                future: futureAllLists,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    var allLists = snapshot.data!;
                    selectedListIds ??= widget.instrument.listsObj
                            ?.map((e) => e['id'].toString())
                            .toSet() ??
                        {};

                    return SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allLists.length,
                        itemBuilder: (context, index) {
                          var list = allLists[index];
                          var isInList = selectedListIds!.contains(list.id);
                          return CheckboxListTile(
                            title: Text(
                                "${list.iconEmoji ?? ''} ${list.displayName}"
                                    .trim()),
                            value: isInList,
                            onChanged: (value) async {
                              setStateDialog(() {
                                if (value == true) {
                                  selectedListIds!.add(list.id);
                                } else {
                                  selectedListIds!.remove(list.id);
                                }
                              });
                              try {
                                if (value == true) {
                                  await widget.service.addToList(
                                      widget.brokerageUser,
                                      list.id,
                                      widget.instrument.id);
                                } else {
                                  await widget.service.removeFromList(
                                      widget.brokerageUser,
                                      list.id,
                                      widget.instrument.id);
                                }

                                // Refresh lists in main widget
                                var newLists = await widget.service.getLists(
                                    widget.brokerageUser, widget.instrument.id);

                                if (mounted) {
                                  setState(() {
                                    widget.instrument.listsObj = newLists;
                                  });
                                  // setStateDialog(() {});
                                }
                              } catch (e) {
                                setStateDialog(() {
                                  if (value == true) {
                                    selectedListIds!.remove(list.id);
                                  } else {
                                    selectedListIds!.add(list.id);
                                  }
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Error: $e")));
                              }
                            },
                          );
                        },
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
              actions: [
                TextButton(
                    child: const Text("Create List"),
                    onPressed: () {
                      _showCreateListDialog(() {
                        setStateDialog(() {
                          futureAllLists =
                              widget.service.getAllLists(widget.brokerageUser);
                        });
                      });
                    }),
                TextButton(
                  child: const Text("Close"),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            );
          });
        });
  }

  Widget _buildListsWidget(Instrument instrument) {
    final lists = instrument.listsObj!;
    final userLists = lists.where((l) => l["owner_type"] == "custom").toList();
    final rhLists = lists.where((l) => l["owner_type"] != "custom").toList();

    return SliverToBoxAdapter(
      child: ValueListenableBuilder<bool>(
          valueListenable: _showAllListsNotifier,
          builder: (context, showAllLists, child) {
            final rhDisplayCount = showAllLists
                ? rhLists.length
                : (rhLists.length > 3 ? 3 : rhLists.length);

            List<Widget> slivers = [];

            slivers.add(SliverToBoxAdapter(
                child: Column(children: [
              ListTile(
                title: const Text(
                  "Lists",
                  style: TextStyle(fontSize: 20),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.playlist_add),
                  onPressed: _showAddToListDialog,
                ),
              )
            ])));

            if (userLists.isNotEmpty) {
              if (rhLists.isNotEmpty) {
                slivers.add(const SliverToBoxAdapter(
                    child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 4.0),
                        child: Text("Your Lists",
                            style: TextStyle(fontWeight: FontWeight.bold)))));
              }
              slivers.add(SliverList(
                delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                  return _buildListItem(userLists[index]);
                }, childCount: userLists.length),
              ));
            }

            if (rhLists.isNotEmpty) {
              if (userLists.isNotEmpty) {
                slivers.add(const SliverToBoxAdapter(
                    child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 4.0),
                        child: Text("Robinhood Lists",
                            style: TextStyle(fontWeight: FontWeight.bold)))));
              }
              slivers.add(SliverList(
                delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                  return _buildListItem(rhLists[index]);
                }, childCount: rhDisplayCount),
              ));

              if (rhLists.length > 3) {
                slivers.add(SliverToBoxAdapter(
                    child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                      onPressed: () {
                        _showAllListsNotifier.value = !showAllLists;
                      },
                      icon: Icon(
                          showAllLists ? Icons.expand_less : Icons.expand_more),
                      label: Text(showAllLists
                          ? 'Show Less'
                          : 'Show All (${rhLists.length})')),
                )));
              }
              slivers
                  .add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
            }

            return ShrinkWrappingViewport(
                offset: ViewportOffset.zero(), slivers: slivers);
          }),
    );
  }

  Widget _buildListItem(dynamic list) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          leading: list["image_urls"] != null
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: list["image_urls"]["circle_64:3"],
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                        const CircleAvatar(child: Icon(Icons.list)),
                  ),
                )
              : (list["icon_emoji"] != null
                  ? CircleAvatar(
                      backgroundColor: Colors.transparent,
                      child: Text(list["icon_emoji"],
                          style: const TextStyle(fontSize: 24)))
                  : const CircleAvatar(
                      child: Icon(Icons.list),
                    )),
          title: Text(
            "${list["display_name"]}",
            style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            "${list["item_count"]} items${list["display_description"] != null ? " • ${list["display_description"]}" : ""}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall?.color),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () async {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ListWidget(widget.brokerageUser,
                        widget.service, list["id"].toString(),
                        analytics: widget.analytics,
                        observer: widget.observer,
                        generativeService: widget.generativeService,
                        user: widget.user,
                        userDocRef: widget.userDocRef,
                        ownerType: list["owner_type"] ?? "robinhood")));
          },
        ),
        const Divider(
          height: 1,
          indent: 72,
          endIndent: 16,
        )
      ],
    );
  }

  Widget _buildNewsWidget(Instrument instrument) {
    final news = instrument.newsObj!;

    return SliverToBoxAdapter(
      child: ValueListenableBuilder<bool>(
          valueListenable: _showAllNewsNotifier,
          builder: (context, showAllNews, child) {
            final displayCount =
                showAllNews ? news.length : (news.length > 3 ? 3 : news.length);
            return Column(
              children: [
                const ListTile(
                  title: Text(
                    "News",
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayCount,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    var item = news[index];
                    return InkWell(
                      onTap: () async {
                        var url = item["url"];
                        var uri = Uri.parse(url);
                        await canLaunchUrl(uri)
                            ? await launchUrl(uri)
                            : throw 'Could not launch $url';
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "${item["source"]}",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        "• ${formatDate.format(DateTime.parse(item["published_at"]!))}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "${item["title"]}",
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (item["preview_image_url"] != null &&
                                item["preview_image_url"]
                                    .toString()
                                    .isNotEmpty) ...[
                              const SizedBox(width: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: CachedNetworkImage(
                                  imageUrl: item["preview_image_url"],
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                      color: Colors.grey.withOpacity(0.1)),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.error),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (news.length > 3)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                        onPressed: () {
                          _showAllNewsNotifier.value = !showAllNews;
                        },
                        icon: Icon(showAllNews
                            ? Icons.expand_less
                            : Icons.expand_more),
                        label: Text(showAllNews
                            ? 'Show Less'
                            : 'Show All (${news.length})')),
                  ),
                const SizedBox(height: 16),
              ],
            );
          }),
    );
  }

  Widget positionOrdersWidget(List<InstrumentOrder> positionOrders) {
    if (positionOrders.isNotEmpty) {
      positionOrdersBalance = positionOrders
          .map((e) =>
              (e.averagePrice != null ? e.averagePrice! * e.quantity! : 0.0) *
              (e.side == "sell" ? 1 : -1))
          .reduce((a, b) => a + b);
    } else {
      positionOrdersBalance = 0;
    }

    var filteredPositionOrders = positionOrders
        .where((element) =>
            orderFilters.isEmpty || orderFilters.contains(element.state))
        .toList();
    filteredPositionOrders.sort((a, b) =>
        (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));

    return SliverToBoxAdapter(
        child: ValueListenableBuilder<bool>(
            valueListenable: _showAllPositionOrdersNotifier,
            builder: (context, showAllPositionOrders, child) {
              final displayCount = showAllPositionOrders
                  ? filteredPositionOrders.length
                  : (filteredPositionOrders.length > 3
                      ? 3
                      : filteredPositionOrders.length);

              return Column(
                children: [
                  ListTile(
                      title: const Text(
                        "Position Orders",
                        style: TextStyle(fontSize: 20.0),
                      ),
                      subtitle: Text(
                          "${formatCompactNumber.format(positionOrders.length)} orders - balance: ${positionOrdersBalance > 0 ? "+" : positionOrdersBalance < 0 ? "-" : ""}${formatCurrency.format(positionOrdersBalance.abs())}"),
                      trailing: IconButton(
                          icon: const Icon(Icons.filter_list),
                          onPressed: () {
                            showModalBottomSheet<void>(
                              context: context,
                              showDragHandle: true,
                              constraints: const BoxConstraints(maxHeight: 260),
                              builder: (BuildContext context) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const ListTile(
                                      // tileColor: Theme.of(context).colorScheme.primary,
                                      leading: Icon(Icons.filter_list),
                                      title: Text(
                                        "Filter Position Orders",
                                        style: TextStyle(fontSize: 20.0),
                                      ),
                                      /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                                    ),
                                    orderFilterWidget,
                                  ],
                                );
                              },
                            );
                          })),
                  ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayCount,
                      separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            indent: 72,
                            endIndent: 16,
                          ),
                      itemBuilder: (BuildContext context, int index) {
                        var order = filteredPositionOrders[index];
                        return ListTile(
                          leading: CircleAvatar(
                              //backgroundImage: AssetImage(user.profilePicture),
                              child: Text('${order.quantity!.round()}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold))),
                          title: Text(
                              "${order.side == "buy" ? "Buy" : order.side == "sell" ? "Sell" : order.side} ${order.quantity} at ${order.averagePrice != null ? formatCurrency.format(order.averagePrice) : (order.price != null ? formatCurrency.format(order.price) : "")}",
                              style: const TextStyle(
                                  fontSize: 16.0, fontWeight: FontWeight.w500)),
                          subtitle: Text(
                              "${order.state} ${formatDate.format(order.updatedAt!)}${order.trailingPeg != null ? "\nTrailing: ${order.trailingPeg!['percentage'] != null ? "${order.trailingPeg!['percentage']}%" : (order.trailingPeg!['price'] != null ? formatCompactNumber.format(double.tryParse(order.trailingPeg!['price']['amount'] ?? "0")) : "")}" : ""}",
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color)),
                          trailing: Text(
                            (order.side == "sell" ? "+" : "-") +
                                (order.averagePrice != null
                                    ? formatCurrency.format(
                                        order.averagePrice! * order.quantity!)
                                    : ""),
                            style: const TextStyle(
                                fontSize: 16.0, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right,
                          ),
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => PositionOrderWidget(
                                          widget.brokerageUser,
                                          widget.service,
                                          order,
                                          generativeService:
                                              widget.generativeService,
                                          user: widget.user,
                                          userDocRef: widget.userDocRef,
                                          analytics: widget.analytics,
                                          observer: widget.observer,
                                        )));
                          },
                        );
                      }),
                  if (filteredPositionOrders.length > 3)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                          onPressed: () {
                            _showAllPositionOrdersNotifier.value =
                                !showAllPositionOrders;
                          },
                          icon: Icon(showAllPositionOrders
                              ? Icons.expand_less
                              : Icons.expand_more),
                          label: Text(showAllPositionOrders
                              ? 'Show Less'
                              : 'Show All (${filteredPositionOrders.length})')),
                    ),
                  const SizedBox(height: 16),
                ],
              );
            }));
  }

  Widget _buildOptionOrdersWidget(List<OptionOrder> optionOrders) {
    if (optionOrders.isNotEmpty) {
      optionOrdersPremiumBalance = optionOrders
          .map((e) =>
              (e.processedPremium != null ? e.processedPremium! : 0) *
              (e.direction == "credit" ? 1 : -1))
          .reduce((a, b) => a + b) as double;
    } else {
      optionOrdersPremiumBalance = 0;
    }

    var filteredOptionOrders = optionOrders
        .where((element) =>
            orderFilters.isEmpty || orderFilters.contains(element.state))
        .toList();
    filteredOptionOrders.sort((a, b) =>
        (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));

    return SliverToBoxAdapter(
        child: ValueListenableBuilder<bool>(
            valueListenable: _showAllOptionOrdersNotifier,
            builder: (context, showAllOptionOrders, child) {
              final displayCount = showAllOptionOrders
                  ? filteredOptionOrders.length
                  : (filteredOptionOrders.length > 3
                      ? 3
                      : filteredOptionOrders.length);

              return Column(
                children: [
                  ListTile(
                      title: const Text(
                        "Option Orders",
                        style: TextStyle(fontSize: 20.0),
                      ),
                      subtitle: Text(
                          "${formatCompactNumber.format(optionOrders.length)} orders - balance: ${optionOrdersPremiumBalance > 0 ? "+" : optionOrdersPremiumBalance < 0 ? "-" : ""}${formatCurrency.format(optionOrdersPremiumBalance.abs())}"),
                      trailing: IconButton(
                          icon: const Icon(Icons.filter_list),
                          onPressed: () {
                            showModalBottomSheet<void>(
                              context: context,
                              showDragHandle: true,
                              constraints: const BoxConstraints(maxHeight: 260),
                              builder: (BuildContext context) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const ListTile(
                                      leading: Icon(Icons.filter_list),
                                      title: Text(
                                        "Filter Option Orders",
                                        style: TextStyle(fontSize: 20.0),
                                      ),
                                    ),
                                    orderFilterWidget,
                                  ],
                                );
                              },
                            );
                          })),
                  ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayCount,
                      separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            indent: 72,
                            endIndent: 16,
                          ),
                      itemBuilder: (BuildContext context, int index) {
                        var optionOrder = filteredOptionOrders[index];

                        var subtitle = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  "${optionOrder.state.capitalize()} ${formatDate.format(optionOrder.updatedAt!)}",
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color)),
                              if (optionOrder.optionEvents != null) ...[
                                Text(
                                    "${optionOrder.optionEvents!.first.type == "expiration" ? "Expired" : (optionOrder.optionEvents!.first.type == "assignment" ? "Assigned" : (optionOrder.optionEvents!.first.type == "exercise" ? "Exercised" : optionOrder.optionEvents!.first.type))} ${formatCompactDate.format(optionOrder.optionEvents!.first.eventDate!)} at ${optionOrder.optionEvents!.first.underlyingPrice != null ? formatCurrency.format(optionOrder.optionEvents!.first.underlyingPrice) : ""}",
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color))
                              ]
                            ]);

                        return ListTile(
                          leading: CircleAvatar(
                              child: optionOrder.optionEvents != null
                                  ? const Icon(Icons.check)
                                  : Text('${optionOrder.quantity!.round()}',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold))),
                          title: Text(
                              "${optionOrder.chainSymbol} \$${formatCompactNumber.format(optionOrder.legs.first.strikePrice)} ${optionOrder.strategy} ${formatCompactDate.format(optionOrder.legs.first.expirationDate!)}",
                              style: const TextStyle(
                                  fontSize: 16.0, fontWeight: FontWeight.w500)),
                          subtitle: subtitle,
                          trailing: Text(
                            (optionOrder.direction == "credit" ? "+" : "-") +
                                (optionOrder.processedPremium != null
                                    ? formatCurrency
                                        .format(optionOrder.processedPremium)
                                    : ""),
                            style: const TextStyle(
                                fontSize: 16.0, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right,
                          ),
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => OptionOrderWidget(
                                          widget.brokerageUser,
                                          widget.service,
                                          optionOrder,
                                          generativeService:
                                              widget.generativeService,
                                          user: widget.user,
                                          userDocRef: widget.userDocRef,
                                          analytics: widget.analytics,
                                          observer: widget.observer,
                                        )));
                          },
                        );
                      }),
                  if (filteredOptionOrders.length > 3)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                          onPressed: () {
                            _showAllOptionOrdersNotifier.value =
                                !showAllOptionOrders;
                          },
                          icon: Icon(showAllOptionOrders
                              ? Icons.expand_less
                              : Icons.expand_more),
                          label: Text(showAllOptionOrders
                              ? 'Show Less'
                              : 'Show All (${filteredOptionOrders.length})')),
                    ),
                  const SizedBox(height: 16),
                ],
              );
            }));
  }

  Widget get openClosedFilterWidget {
    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Row(children: [
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.new_releases_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Open'),
                  selected: hasQuantityFilters[0],
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        hasQuantityFilters[0] = true;
                      } else {
                        hasQuantityFilters[0] = false;
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: Container(),
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Closed'),
                  selected: hasQuantityFilters[1],
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        hasQuantityFilters[1] = true;
                      } else {
                        hasQuantityFilters[1] = false;
                      }
                    });
                  },
                ),
              ),
              /*
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Long'),
                  selected: positionFilters.contains("long"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        positionFilters.add("long");
                      } else {
                        positionFilters.removeWhere((String name) {
                          return name == "long";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Short'),
                  selected: positionFilters.contains("short"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        positionFilters.add("short");
                      } else {
                        positionFilters.removeWhere((String name) {
                          return name == "short";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Call'),
                  selected: optionFilters.contains("call"),
                  //selected: optionFilters[0],
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        optionFilters.add("call");
                      } else {
                        optionFilters.removeWhere((String name) {
                          return name == "call";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Put'),
                  selected: optionFilters.contains("put"),
                  //selected: optionFilters[1],
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        optionFilters.add("put");
                      } else {
                        optionFilters.removeWhere((String name) {
                          return name == "put";
                        });
                      }
                    });
                  },
                ),
              )
              */
            ]);
          },
          itemCount: 1,
        ));
  }

  Widget get optionTypeFilterWidget {
    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: FilterChip(
                    //avatar: const Icon(Icons.history_outlined),
                    //avatar: CircleAvatar(child: Text(optionCount.toString())),
                    label: const Text('Long'), // Positions
                    selected: positionFilters.contains("long"),
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          positionFilters.add("long");
                        } else {
                          positionFilters.removeWhere((String name) {
                            return name == "long";
                          });
                        }
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: FilterChip(
                    //avatar: const Icon(Icons.history_outlined),
                    //avatar: CircleAvatar(child: Text(optionCount.toString())),
                    label: const Text('Short'), // Positions
                    selected: positionFilters.contains("short"),
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          positionFilters.add("short");
                        } else {
                          positionFilters.removeWhere((String name) {
                            return name == "short";
                          });
                        }
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: FilterChip(
                    //avatar: const Icon(Icons.history_outlined),
                    //avatar: CircleAvatar(child: Text(optionCount.toString())),
                    label: const Text('Call'), // Options
                    selected: optionFilters.contains("call"),
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          optionFilters.add("call");
                        } else {
                          optionFilters.removeWhere((String name) {
                            return name == "call";
                          });
                        }
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: FilterChip(
                    //avatar: const Icon(Icons.history_outlined),
                    //avatar: CircleAvatar(child: Text(optionCount.toString())),
                    label: const Text('Put'), // Options
                    selected: optionFilters.contains("put"),
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          optionFilters.add("put");
                        } else {
                          optionFilters.removeWhere((String name) {
                            return name == "put";
                          });
                        }
                      });
                    },
                  ),
                )
              ],
            );
          },
          itemCount: 1,
        ));
  }

  Widget get orderFilterWidget {
    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Row(children: [
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Queued'),
                  selected: orderFilters.contains("queued"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("queued");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "queued";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Confirmed'),
                  selected: orderFilters.contains("confirmed"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("confirmed");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "confirmed";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Filled'),
                  selected: orderFilters.contains("filled"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("filled");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "filled";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Cancelled'),
                  selected: orderFilters.contains("cancelled"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("cancelled");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "cancelled";
                        });
                      }
                    });
                  },
                ),
              ),
            ]);
          },
          itemCount: 1,
        ));
  }

  Widget headerTitle(Instrument instrument, QuoteStore store) {
    var quoteObj = store.items
        .firstWhereOrNull((element) => element.symbol == instrument.symbol);
    quoteObj ??= instrument.quoteObj;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(instrument.symbol,
                        style: const TextStyle(
                            fontSize: 16.0, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                  ),
                  if (widget.brokerageUser.source == BrokerageSource.paper) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        'PAPER',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber),
                      ),
                    ),
                  ],
                ],
              ),
              if (instrument.simpleName != null || instrument.name != "")
                Text(
                  instrument.simpleName ?? instrument.name,
                  style: const TextStyle(fontSize: 12.0),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          ),
        ),
        if (quoteObj != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedPriceText(
                price: quoteObj.lastExtendedHoursTradePrice ??
                    quoteObj.lastTradePrice!,
                format: formatCurrency,
                style: const TextStyle(
                    fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Icon(
                      quoteObj.changeToday > 0
                          ? Icons.trending_up
                          : (quoteObj.changeToday < 0
                              ? Icons.trending_down
                              : Icons.trending_flat),
                      color: (quoteObj.changeToday > 0
                          ? (Theme.of(context).brightness == Brightness.light
                              ? Colors.green
                              : Colors.lightGreenAccent)
                          : (quoteObj.changeToday < 0
                              ? Colors.red
                              : Colors.grey)),
                      size: 14.0),
                  const SizedBox(width: 2),
                  Text(
                    formatPercentage.format(quoteObj.changePercentToday),
                    style: TextStyle(
                        fontSize: 12.0,
                        color: (quoteObj.changeToday > 0
                            ? (Theme.of(context).brightness == Brightness.light
                                ? Colors.green
                                : Colors.lightGreenAccent)
                            : (quoteObj.changeToday < 0
                                ? Colors.red
                                : Colors.grey))),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMultiIndicatorDisplay(Map<String, dynamic> multiIndicator) {
    final indicators = multiIndicator['indicators'] as Map<String, dynamic>?;
    if (indicators == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AgenticTradingProvider>(
      builder: (context, agenticProvider, child) {
        final enabledIndicators =
            agenticProvider.config.strategyConfig.enabledIndicators;
        final enabledCount =
            enabledIndicators.values.where((v) => v == true).length;

        // Recalculate signals based on only enabled indicators
        bool displayAllGreen = true;
        bool displayAllRed = true;

        if (enabledCount > 0) {
          for (final key in [
            'priceMovement',
            'momentum',
            'marketDirection',
            'volume',
            'macd',
            'bollingerBands',
            'stochastic',
            'atr',
            'obv',
            'vwap',
            'adx',
            'williamsR',
            'ichimoku',
            'cci',
            'parabolicSar',
            'roc',
            'chaikinMoneyFlow',
            'fibonacciRetracements',
            'pivotPoints',
          ]) {
            if (enabledIndicators[key] == true) {
              final indicator = indicators[key] as Map<String, dynamic>?;
              final signal = indicator?['signal'];
              if (indicator == null || signal != 'BUY') {
                displayAllGreen = false;
              }
              if (indicator == null || signal != 'SELL') {
                displayAllRed = false;
              }
            }
          }
        } else {
          final overall = multiIndicator['overallSignal'];
          displayAllGreen = overall == 'BUY';
          displayAllRed = overall == 'SELL';
        }

        // Extract signal strength
        final overallSignalStrength = multiIndicator['signalStrength'] as int?;

        // Calculate enabled signal strength
        int? enabledSignalStrength;
        int buyCount = 0;
        int sellCount = 0;
        int holdCount = 0;

        if (enabledCount > 0) {
          for (final entry in {
            'priceMovement': 'priceMovement',
            'momentum': 'momentum',
            'marketDirection': 'marketDirection',
            'volume': 'volume',
            'macd': 'macd',
            'bollingerBands': 'bollingerBands',
            'stochastic': 'stochastic',
            'atr': 'atr',
            'obv': 'obv',
            'vwap': 'vwap',
            'adx': 'adx',
            'williamsR': 'williamsR',
            'ichimoku': 'ichimoku',
            'cci': 'cci',
            'parabolicSar': 'parabolicSar',
            'roc': 'roc',
            'chaikinMoneyFlow': 'chaikinMoneyFlow',
            'fibonacciRetracements': 'fibonacciRetracements',
            'pivotPoints': 'pivotPoints',
          }.entries) {
            final configKey = entry.key;
            final indicatorKey = entry.value;

            if (enabledIndicators[configKey] == true) {
              final indicator =
                  indicators[indicatorKey] as Map<String, dynamic>?;
              final signal = indicator?['signal'];
              if (signal == 'BUY') {
                buyCount++;
              } else if (signal == 'SELL') {
                sellCount++;
              } else {
                holdCount++;
              }
            }
          }
          final maxAgreement = math.max(buyCount, sellCount);
          enabledSignalStrength = ((maxAgreement / enabledCount) * 100).round();
        }

        final Color borderColor = displayAllGreen
            ? (isDark ? Colors.green.shade700 : Colors.green.shade200)
            : displayAllRed
                ? (isDark ? Colors.red.shade700 : Colors.red.shade200)
                : (isDark ? Colors.orange.shade700 : Colors.orange.shade200);

        return ValueListenableBuilder<bool>(
            valueListenable: _showTechnicalDetailsNotifier,
            builder: (context, showTechnicalDetails, child) {
              return Container(
                margin: const EdgeInsets.only(top: 12.0),
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey.shade900.withValues(alpha: 0.5)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: borderColor,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        _showTechnicalDetailsNotifier.value =
                            !showTechnicalDetails;
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.analytics_outlined,
                              size: 20,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Technical Indicators',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  if (enabledCount > 0)
                                    Row(
                                      children: [
                                        if (buyCount > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 8.0),
                                            child: Text(
                                              '$buyCount Buy',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ),
                                        if (sellCount > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 8.0),
                                            child: Text(
                                              '$sellCount Sell',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade700,
                                              ),
                                            ),
                                          ),
                                        if (holdCount > 0)
                                          Text(
                                            '$holdCount Hold',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.settings,
                                size: 20,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Automated Trading: Entry Strategies',
                              onPressed: () async {
                                if (widget.user == null ||
                                    widget.userDocRef == null) {
                                  return;
                                }
                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AgenticTradingSettingsWidget(
                                      user: widget.user!,
                                      userDocRef: widget.userDocRef!,
                                      service: widget.service,
                                      initialSection: 'entryStrategies',
                                    ),
                                  ),
                                );
                                if (result == true && mounted) {
                                  final tradeSignalsProvider =
                                      Provider.of<TradeSignalsProvider>(context,
                                          listen: false);
                                  tradeSignalsProvider.fetchTradeSignal(
                                      widget.instrument.symbol,
                                      interval: tradeSignalsProvider
                                          .selectedInterval);
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(
                                Icons.info_outline,
                                size: 20,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Indicator Documentation',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Technical Indicators'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildDocSection('priceMovement'),
                                          _buildDocSection('momentum'),
                                          _buildDocSection('marketDirection'),
                                          _buildDocSection('volume'),
                                          _buildDocSection('macd'),
                                          _buildDocSection('bollingerBands'),
                                          _buildDocSection('stochastic'),
                                          _buildDocSection('atr'),
                                          _buildDocSection('obv'),
                                          _buildDocSection('vwap'),
                                          _buildDocSection('adx'),
                                          _buildDocSection('williamsR'),
                                          _buildDocSection('ichimoku'),
                                          _buildDocSection('cci'),
                                          _buildDocSection('sar'),
                                          _buildDocSection('roc'),
                                          _buildDocSection('chaikinMoneyFlow'),
                                          _buildDocSection(
                                              'fibonacciRetracements'),
                                          _buildDocSection('pivotPoints'),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              showTechnicalDetails
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 20,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (overallSignalStrength != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        enabledSignalStrength != null
                                            ? 'Signal Strength (Adjusted)${enabledSignalStrength >= Constants.signalStrengthStrongMin ? (sellCount > buyCount ? ' - Strong Sell' : ' - Strong Buy') : enabledSignalStrength >= Constants.signalStrengthModerateMin ? (sellCount > buyCount ? ' - Moderate Sell' : ' - Moderate Buy') : ' - Weak Signal'}'
                                            : 'Signal Strength',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        '${enabledSignalStrength ?? overallSignalStrength}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: (enabledSignalStrength ??
                                                      overallSignalStrength) >=
                                                  Constants
                                                      .signalStrengthStrongMin
                                              ? Colors.green
                                              : ((enabledSignalStrength ??
                                                          overallSignalStrength) >=
                                                      Constants
                                                          .signalStrengthModerateMin
                                                  ? Colors.amber
                                                  : Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final strength = enabledSignalStrength ??
                                          overallSignalStrength;
                                      return Stack(
                                        children: [
                                          Container(
                                            height: 6,
                                            width: constraints.maxWidth,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                          ),
                                          Container(
                                            height: 6,
                                            width: constraints.maxWidth *
                                                (strength / 100),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  strength >=
                                                          Constants
                                                              .signalStrengthStrongMin
                                                      ? Colors.green.shade300
                                                      : (strength >=
                                                              Constants
                                                                  .signalStrengthModerateMin
                                                          ? Colors
                                                              .orange.shade300
                                                          : Colors
                                                              .red.shade300),
                                                  strength >=
                                                          Constants
                                                              .signalStrengthStrongMin
                                                      ? Colors.green
                                                      : (strength >=
                                                              Constants
                                                                  .signalStrengthModerateMin
                                                          ? Colors.orange
                                                          : Colors.red),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    if (showTechnicalDetails) ...[
                      const SizedBox(height: 8),
                      Builder(builder: (context) {
                        final List<Map<String, String>> indicatorDefs = [
                          {'label': 'Price Movement', 'key': 'priceMovement'},
                          {'label': 'RSI (Momentum)', 'key': 'momentum'},
                          {
                            'label': 'Market Direction',
                            'key': 'marketDirection'
                          },
                          {'label': 'Volume Analysis', 'key': 'volume'},
                          {'label': 'MACD', 'key': 'macd'},
                          {'label': 'Bollinger Bands', 'key': 'bollingerBands'},
                          {
                            'label': 'Stochastic Oscillator',
                            'key': 'stochastic'
                          },
                          {'label': 'Average True Range', 'key': 'atr'},
                          {'label': 'On-Balance Volume', 'key': 'obv'},
                          {'label': 'VWAP', 'key': 'vwap'},
                          {'label': 'ADX (Trend Strength)', 'key': 'adx'},
                          {'label': 'Williams %R', 'key': 'williamsR'},
                          {'label': 'Ichimoku Cloud', 'key': 'ichimoku'},
                          {'label': 'CCI', 'key': 'cci'},
                          {'label': 'Parabolic SAR', 'key': 'parabolicSar'},
                          {'label': 'Rate of Change', 'key': 'roc'},
                          {
                            'label': 'Chaikin Money Flow',
                            'key': 'chaikinMoneyFlow'
                          },
                          {
                            'label': 'Fibonacci Retracements',
                            'key': 'fibonacciRetracements'
                          },
                          {'label': 'Pivot Points', 'key': 'pivotPoints'},
                        ];

                        final enabledList = <Widget>[];
                        final disabledList = <Widget>[];

                        for (var def in indicatorDefs) {
                          final key = def['key']!;
                          final label = def['label']!;
                          final configKey = key;
                          final isEnabled =
                              enabledIndicators[configKey] == true;

                          final row = _buildIndicatorRow(
                              label,
                              key,
                              indicators[key] as Map<String, dynamic>?,
                              isEnabled);

                          if (isEnabled) {
                            enabledList.add(row);
                          } else {
                            disabledList.add(row);
                          }
                        }

                        return Column(
                          children: [
                            if (enabledList.isNotEmpty)
                              Column(
                                children: enabledList,
                              ),
                            if (disabledList.isNotEmpty)
                              Theme(
                                data: Theme.of(context)
                                    .copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: Row(
                                    children: [
                                      Text(
                                        'Disabled Indicators (${disabledList.length})',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      if (enabledCount > 0 &&
                                          overallSignalStrength != null &&
                                          overallSignalStrength !=
                                              enabledSignalStrength) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getSignalStrengthColor(
                                                    overallSignalStrength)
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.speed,
                                                  size: 10,
                                                  color: _getSignalStrengthColor(
                                                      overallSignalStrength)),
                                              const SizedBox(width: 3),
                                              Text(
                                                '$overallSignalStrength% Overall',
                                                style: TextStyle(
                                                  fontSize: 10.0,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getSignalStrengthColor(
                                                      overallSignalStrength),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  children: disabledList,
                                ),
                              ),
                          ],
                        );
                      }),
                    ],
                  ],
                ),
              );
            });
      },
    );
  }

  Widget _buildIndicatorRow(String name, String key,
      Map<String, dynamic>? indicator, bool isEnabled) {
    if (indicator == null) return const SizedBox.shrink();

    // Now that disabled indicators are shown in the collapsible `Disabled Indicators`
    // section, we always treat them as enabled for display purposes
    isEnabled = true;

    final signal = indicator['signal'] as String? ?? 'HOLD';
    final reason = indicator['reason'] as String? ?? '';
    final metadata = indicator['metadata'] as Map<String, dynamic>?;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color signalColor;
    Color bgColor;

    switch (signal) {
      case 'BUY':
        signalColor = Colors.green.shade700;
        bgColor = Colors.green.withValues(alpha: 0.1);
        break;
      case 'SELL':
        signalColor = Colors.red.shade700;
        bgColor = Colors.red.withValues(alpha: 0.1);
        break;
      default:
        signalColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
        bgColor = isDark
            ? Colors.grey.shade800.withValues(alpha: 0.5)
            : Colors.grey.shade200;
    }

    return ValueListenableBuilder<Set<String>>(
      valueListenable: _expandedIndicatorsNotifier,
      builder: (context, expandedIndicators, child) {
        final isExpanded = expandedIndicators.contains(key);
        final hasMetadata =
            metadata != null && metadata.isNotEmpty && isEnabled;

        return Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: InkWell(
            onTap: hasMetadata
                ? () {
                    final newSet = Set<String>.from(expandedIndicators);
                    if (isExpanded) {
                      newSet.remove(key);
                    } else {
                      newSet.add(key);
                    }
                    _expandedIndicatorsNotifier.value = newSet;
                  }
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (!isEnabled) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.grey.shade800
                                                : Colors.grey.shade200,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'DISABLED',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (hasMetadata) ...[
                                        const SizedBox(width: 4),
                                        AnimatedRotation(
                                          turns: isExpanded ? 0.5 : 0.0,
                                          duration:
                                              const Duration(milliseconds: 200),
                                          child: Icon(
                                            Icons.keyboard_arrow_down,
                                            size: 16,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color
                                                ?.withOpacity(0.5),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (reason.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 2.0, right: 8.0),
                                      child: Text(
                                        reason,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color
                                              ?.withOpacity(0.8),
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: signalColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          signal,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: signalColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    curve: Curves.easeInOut,
                    child: (hasMetadata && isExpanded)
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  top: 8.0, right: 8.0, bottom: 4.0),
                              child: Wrap(
                                spacing: 6.0,
                                runSpacing: 6.0,
                                children: metadata.entries
                                    .where((e) =>
                                        e.value != null &&
                                        (e.value is String ||
                                            e.value is num ||
                                            e.value is bool))
                                    .map((e) {
                                  var value = e.value;
                                  if (value is double) {
                                    if (value.abs() >= 10000) {
                                      value = formatCompactNumber.format(value);
                                    } else if (value.abs() < 1 && value != 0) {
                                      value = value.toStringAsFixed(4);
                                    } else {
                                      value = value.toStringAsFixed(2);
                                    }
                                  }

                                  // Friendly label mapping
                                  String label = e.key;
                                  const labelMap = {
                                    'ma5': 'SMA 5',
                                    'ma10': 'SMA 10',
                                    'ma20': 'SMA 20',
                                    'ma50': 'SMA 50',
                                    'ma200': 'SMA 200',
                                    'ema12': 'EMA 12',
                                    'ema26': 'EMA 26',
                                    'rsi': 'RSI',
                                    'k': '%K',
                                    'd': '%D',
                                    'upper': 'Upper',
                                    'lower': 'Lower',
                                    'middle': 'Mid',
                                    'plusDI': '+DI',
                                    'minusDI': '-DI',
                                    'histogram': 'Hist',
                                    'conversionLine': 'Tenkan',
                                    'baseLine': 'Kijun',
                                    'leadingSpanA': 'Span A',
                                    'leadingSpanB': 'Span B',
                                    'laggingSpan': 'Chikou',
                                    'currentPrice': 'Price',
                                    'volume': 'Vol',
                                  };

                                  if (labelMap.containsKey(label)) {
                                    label = labelMap[label]!;
                                  } else {
                                    // Format key: camelCase to Title Case
                                    label = label.replaceAllMapped(
                                        RegExp(r'([a-z])([A-Z])'),
                                        (Match m) => '${m[1]} ${m[2]}');
                                    label = label.isNotEmpty
                                        ? '${label[0].toUpperCase()}${label.substring(1)}'
                                        : label;
                                  }

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.3)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .dividerColor
                                            .withValues(alpha: 0.1),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "$label: ",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color
                                                ?.withValues(alpha: 0.7),
                                          ),
                                        ),
                                        Text(
                                          "$value",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Monospace',
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocSection(String key) {
    return IndicatorDocumentationWidget(
      indicatorKey: key,
      showContainer: false,
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Returns color based on signal strength value (0-100).
  /// Matches filter categories:
  /// Strong (75-100): Green
  /// Moderate (50-74): Orange
  /// Weak (0-49): Red
  Color _getSignalStrengthColor(int strength) {
    if (strength >= Constants.signalStrengthStrongMin) {
      return Colors.green;
    } else if (strength >= Constants.signalStrengthModerateMin) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Widget _buildAgenticTradeSignals(Instrument instrument) {
    return SliverToBoxAdapter(
      key: tradeSignalKey,
      child: Column(
        children: [
          Consumer<TradeSignalsProvider>(
            builder: (context, provider, child) {
              return Column(
                children: [
                  ListTile(
                    title: const Text(
                      "Trade Signal",
                      style: TextStyle(fontSize: 20),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.notifications_outlined,
                            size: 20,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Notification Settings',
                          onPressed: () {
                            if (widget.user != null &&
                                widget.userDocRef != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TradeSignalNotificationSettingsWidget(
                                    user: widget.user!,
                                    userDocRef: widget.userDocRef!,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            Icons.science_outlined,
                            size: 20,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Run Backtest',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => BacktestingWidget(
                                  user: widget.user,
                                  userDocRef: widget.userDocRef,
                                  brokerageUser: widget.brokerageUser,
                                  service: widget.service,
                                  prefilledSymbol: widget.instrument.symbol,
                                ),
                              ),
                            );
                          },
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _isGeneratingSignalNotifier,
                          builder: (context, isGeneratingSignal, _) {
                            return IconButton(
                              icon: isGeneratingSignal
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.auto_awesome),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              constraints: const BoxConstraints(),
                              tooltip: 'Generate Trade Signal',
                              onPressed: isGeneratingSignal
                                  ? null
                                  : () => _generateTradeSignal(context),
                            );
                          },
                        ),
                        if (provider.tradeSignal != null)
                          ValueListenableBuilder<bool>(
                            valueListenable: _isAssessingRiskNotifier,
                            builder: (context, isAssessingRisk, _) {
                              return IconButton(
                                icon: isAssessingRisk
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.shield_outlined),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                constraints: const BoxConstraints(),
                                tooltip:
                                    provider.tradeSignal!['assessment'] == null
                                        ? 'Run Risk Guard'
                                        : 'Re-assess Risk',
                                onPressed: isAssessingRisk
                                    ? null
                                    : () => _runRiskAssessment(
                                        provider.tradeSignal!,
                                        provider.tradeSignal!['signal'] ??
                                            'HOLD'),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  if (provider.tradeSignal?['assessment'] != null &&
                      (provider.tradeSignal?['assessment']['skipped'] == null ||
                          provider.tradeSignal?['assessment']['skipped'] !=
                              true)) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: provider.tradeSignal!['assessment']
                                      ['approved'] ==
                                  true
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: provider.tradeSignal!['assessment']
                                        ['approved'] ==
                                    true
                                ? Colors.green.shade300
                                : Colors.red.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.shield_outlined,
                                  size: 16,
                                  color: provider.tradeSignal!['assessment']
                                              ['approved'] ==
                                          true
                                      ? Colors.green.shade700
                                      : Colors.red.shade700),
                              const SizedBox(width: 8),
                              Text("Risk Assessment",
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: provider.tradeSignal!['assessment']
                                                  ['approved'] ==
                                              true
                                          ? Colors.green.shade700
                                          : Colors.red.shade700)),
                            ]),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  provider.tradeSignal!['assessment']
                                              ['approved'] ==
                                          true
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: provider.tradeSignal!['assessment']
                                              ['approved'] ==
                                          true
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  provider.tradeSignal!['assessment']
                                              ['approved'] ==
                                          true
                                      ? 'Trade Approved'
                                      : 'Trade Rejected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: provider.tradeSignal!['assessment']
                                                ['approved'] ==
                                            true
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (provider.tradeSignal!['assessment']['reason'] !=
                                null) ...[
                              const SizedBox(height: 4),
                              SelectableText(
                                provider.tradeSignal!['assessment']['reason'] ??
                                    '',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: '15m',
                          label: Text('15m'),
                          icon: Icon(Icons.timer_outlined, size: 16),
                        ),
                        ButtonSegment<String>(
                          value: '1h',
                          label: Text('Hourly'),
                          icon: Icon(Icons.schedule, size: 16),
                        ),
                        ButtonSegment<String>(
                          value: '1d',
                          label: Text('Daily'),
                          icon: Icon(Icons.calendar_today, size: 16),
                        ),
                      ],
                      selected: {provider.selectedInterval},
                      onSelectionChanged: (Set<String> newSelection) {
                        provider.setSelectedInterval(newSelection.first);
                        provider.fetchTradeSignal(widget.instrument.symbol,
                            interval: newSelection.first);
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                      ),
                      showSelectedIcon: false,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Consumer2<TradeSignalsProvider, AccountStore>(
            builder: (context, tradeSignalsProvider, accountStore, child) {
              if (tradeSignalsProvider.isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final signal = tradeSignalsProvider.tradeSignal;
              if (signal == null || signal.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.signal_cellular_nodata,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "No trade signal found for this instrument.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              final timestamp = DateTime.fromMillisecondsSinceEpoch(
                  signal['timestamp'] as int);
              var signalType = signal['signal'] ?? 'HOLD';
              // String? recalculatedReason;
              // final assessment = signal['assessment'] as Map<String, dynamic>?;
              final multiIndicator =
                  signal['multiIndicatorResult'] as Map<String, dynamic>?;
              final optimization =
                  signal['optimization'] as Map<String, dynamic>?;

              if (optimization != null &&
                  optimization['refinedSignal'] != null) {
                signalType = optimization['refinedSignal'];
              }

              // // Recalculate overall signal based on enabled indicators
              // if (multiIndicator != null) {
              //   final indicators =
              //       multiIndicator['indicators'] as Map<String, dynamic>?;
              //   if (indicators != null) {
              //     final agenticTradingProvider =
              //         Provider.of<AgenticTradingProvider>(context,
              //             listen: false);
              //     final enabledIndicators =
              //         agenticTradingProvider.config['enabledIndicators']
              //                 as Map<String, dynamic>? ??
              //             {};
              //     final enabledCount =
              //         enabledIndicators.values.where((v) => v == true).length;

              //     if (enabledCount > 0) {
              //       final enabledSignals = <String>[];
              //       for (final key in [
              //         'priceMovement',
              //         'momentum',
              //         'marketDirection',
              //         'volume',
              //         'macd',
              //         'bollingerBands',
              //         'stochastic',
              //         'atr',
              //         'obv',
              //         'vwap',
              //         'adx',
              //         'williamsR',
              //       ]) {
              //         if (enabledIndicators[key] == true) {
              //           final indicator =
              //               indicators[key] as Map<String, dynamic>?;
              //           final sig = indicator?['signal'] as String?;
              //           if (sig != null) {
              //             enabledSignals.add(sig);
              //           }
              //         }
              //       }

              //       if (enabledSignals.isNotEmpty) {
              //         final allBuy = enabledSignals.every((s) => s == 'BUY');
              //         final allSell = enabledSignals.every((s) => s == 'SELL');
              //         final buyCount =
              //             enabledSignals.where((s) => s == 'BUY').length;
              //         final sellCount =
              //             enabledSignals.where((s) => s == 'SELL').length;
              //         final holdCount =
              //             enabledSignals.where((s) => s == 'HOLD').length;

              //         if (allBuy) {
              //           signalType = 'BUY';
              //           recalculatedReason =
              //               'All $enabledCount enabled indicators are GREEN - Strong BUY signal';
              //         } else if (allSell) {
              //           signalType = 'SELL';
              //           recalculatedReason =
              //               'All $enabledCount enabled indicators are RED - Strong SELL signal';
              //         } else {
              //           signalType = 'HOLD';
              //           recalculatedReason =
              //               'Mixed signals ($enabledCount enabled) - BUY: $buyCount, SELL: $sellCount, HOLD: $holdCount. Need all $enabledCount indicators aligned for action.';
              //         }
              //       }
              //     } else {
              //       signalType = 'HOLD';
              //       recalculatedReason =
              //           'No indicators enabled - cannot generate signal';
              //     }
              //   }
              // }

              // Determine signal color and icon
              Color signalColor;
              IconData signalIcon;
              switch (signalType) {
                case 'BUY':
                  signalColor = Colors.green;
                  signalIcon = Icons.trending_up;
                  break;
                case 'SELL':
                  signalColor = Colors.red;
                  signalIcon = Icons.trending_down;
                  break;
                default:
                  signalColor = Colors.grey;
                  signalIcon = Icons.trending_flat;
              }

              final isMarketOpen = MarketHours.isMarketOpen();

              return Card(
                elevation: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Header with signal badge and timestamp
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: signalColor.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  // Signal Badge
                                  Tooltip(
                                    message: signal['reason'] ??
                                        'No reason provided',
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    showDuration: const Duration(seconds: 5),
                                    triggerMode: TooltipTriggerMode.tap,
                                    child: InkWell(
                                      onTap: optimization != null
                                          ? () {
                                              _showAIReasoningNotifier.value =
                                                  !_showAIReasoningNotifier
                                                      .value;
                                            }
                                          : null,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                          vertical: 8.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: signalColor,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: optimization != null
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.purple
                                                        .withValues(alpha: 0.3),
                                                    blurRadius: 8,
                                                    spreadRadius: 1,
                                                  )
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              optimization != null
                                                  ? Icons.auto_awesome
                                                  : signalIcon,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              signalType,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            if (optimization != null) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  "${optimization['confidenceScore']}% AI",
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              ValueListenableBuilder<bool>(
                                                  valueListenable:
                                                      _showAIReasoningNotifier,
                                                  builder: (context,
                                                      showAIReasoning, child) {
                                                    return Icon(
                                                      showAIReasoning
                                                          ? Icons
                                                              .keyboard_arrow_up
                                                          : Icons
                                                              .keyboard_arrow_down,
                                                      color: Colors.white,
                                                      size: 16,
                                                    );
                                                  }),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Timestamp and Status
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${formatCompactDateTimeWithHour.format(timestamp)} · ${_getTimeAgo(timestamp)}",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isMarketOpen
                                          ? Colors.amber.withValues(alpha: 0.15)
                                          : Colors.blue.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isMarketOpen
                                            ? Colors.amber
                                                .withValues(alpha: 0.3)
                                            : Colors.blue
                                                .withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isMarketOpen
                                              ? Icons.wb_sunny_rounded
                                              : Icons.nightlight_round,
                                          size: 10,
                                          color: isMarketOpen
                                              ? Colors.amber.shade700
                                              : Colors.blue.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isMarketOpen
                                              ? 'Market Open'
                                              : 'After Hours',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isMarketOpen
                                                ? Colors.amber.shade800
                                                : Colors.blue.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ML Optimization Section - Content Only if expanded or relevant
                    if (optimization != null &&
                        optimization['reasoning'] != null)
                      ValueListenableBuilder<bool>(
                        valueListenable: _showAIReasoningNotifier,
                        builder: (context, showAIReasoning, child) {
                          if (!showAIReasoning) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 12.0),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? [
                                          Colors.purple.shade900
                                              .withValues(alpha: 0.3),
                                          Colors.blue.shade900
                                              .withValues(alpha: 0.3)
                                        ]
                                      : [
                                          Colors.purple.shade50,
                                          Colors.blue.shade50
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.purpleAccent
                                          .withValues(alpha: 0.2)
                                      : Colors.purple.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                        colors: [Colors.purple, Colors.blue],
                                      ).createShader(bounds),
                                      child: const Icon(
                                        Icons.auto_awesome,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text("AI Insight",
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            foreground: Paint()
                                              ..shader = const LinearGradient(
                                                colors: [
                                                  Colors.purple,
                                                  Colors.blue
                                                ],
                                              ).createShader(
                                                  const Rect.fromLTWH(
                                                      0.0, 0.0, 200.0, 70.0))))
                                  ]),
                                  const SizedBox(height: 12),
                                  SelectableText(
                                    optimization['reasoning'],
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color,
                                        height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    // Multi-Indicator Display
                    if (multiIndicator != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                        child: _buildMultiIndicatorDisplay(multiIndicator),
                      ),

                    // Action Buttons
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildESGCard() {
    return FutureBuilder<ESGScore?>(
      future: _esgFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        var score = snapshot.data!;
        Color scoreColor = score.totalScore >= 70
            ? Colors.green
            : (score.totalScore >= 50 ? Colors.orange : Colors.red);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.eco, color: scoreColor),
                        const SizedBox(width: 8),
                        Text(
                          'ESG Score',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${score.totalScore.toStringAsFixed(1)} (${score.rating})',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (score.description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    score.description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildMiniESGBar(
                            'Env', score.environmentalScore, Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildMiniESGBar(
                            'Soc', score.socialScore, Colors.blue)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildMiniESGBar(
                            'Gov', score.governanceScore, Colors.purple)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniESGBar(String label, double score, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(score.toStringAsFixed(0),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Iterable<Widget> getHeaderWidgets(QuoteStore quoteStore) sync* {
    var instrument = widget.instrument;
    var quoteObj = quoteStore.items
        .firstWhereOrNull((element) => element.symbol == instrument.symbol);
    quoteObj ??= instrument.quoteObj;

    yield Padding(
      padding: const EdgeInsets.only(left: 10.0, right: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            instrument.symbol,
            style: TextStyle(
                fontSize: 14.0,
                color: Theme.of(context).appBarTheme.foregroundColor),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 4),
          Text(
            '${instrument.name != "" ? instrument.name : instrument.simpleName}',
            style: TextStyle(
                fontSize: 16.0,
                color: Theme.of(context).appBarTheme.foregroundColor),
            textAlign: TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // if (quoteObj != null) ...[
          //   const SizedBox(height: 4),
          //   AnimatedPriceText(
          //     price: quoteObj.lastTradePrice!,
          //     format: formatCurrency,
          //     style: TextStyle(
          //         fontSize: 24.0,
          //         fontWeight: FontWeight.bold,
          //         color: Theme.of(context).appBarTheme.foregroundColor),
          //   ),
          //   const SizedBox(height: 4),
          //   Row(
          //     children: [
          //       Icon(
          //           quoteObj.changeToday > 0
          //               ? Icons.trending_up
          //               : (quoteObj.changeToday < 0
          //                   ? Icons.trending_down
          //                   : Icons.trending_flat),
          //           color: (quoteObj.changeToday > 0
          //               ? (Theme.of(context).brightness == Brightness.light
          //                   ? Colors.green
          //                   : Colors.lightGreenAccent)
          //               : (quoteObj.changeToday < 0
          //                   ? Colors.red
          //                   : Colors.grey)),
          //           size: 20.0),
          //       const SizedBox(width: 4),
          //       Text(
          //         formatPercentage.format(quoteObj.changePercentToday),
          //         style: TextStyle(
          //             fontSize: 16.0,
          //             color: Theme.of(context).appBarTheme.foregroundColor),
          //       ),
          //       const SizedBox(width: 8),
          //       Text(
          //         "${quoteObj.changeToday > 0 ? "+" : quoteObj.changeToday < 0 ? "-" : ""}${formatCurrency.format(quoteObj.changeToday.abs())}",
          //         style: TextStyle(
          //             fontSize: 16.0,
          //             color: Theme.of(context).appBarTheme.foregroundColor),
          //       ),
          //     ],
          //   ),
          //   if (quoteObj.lastExtendedHoursTradePrice != null) ...[
          //     const SizedBox(height: 4),
          //     Text(
          //       "After Hours: ${formatCurrency.format(quoteObj.lastExtendedHoursTradePrice)}",
          //       style: const TextStyle(fontSize: 12.0, color: Colors.grey),
          //     ),
          //   ]
          // ]
        ],
      ),
    );
  }
}

// Risk Guard Button Widget
