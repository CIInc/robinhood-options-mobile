import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/midlands_movers_item.dart';

import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';

final formatDate = DateFormat("yMMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

class SearchWidget extends StatefulWidget {
  final User? user;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  final DocumentReference<User>? userDocRef;

  const SearchWidget(
    this.brokerageUser,
    this.service, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    this.navigatorKey,
    required this.user,
    required this.userDocRef,
  });

  final GlobalKey<NavigatorState>? navigatorKey;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget>
    with AutomaticKeepAliveClientMixin<SearchWidget> {
  final FirestoreService _firestoreService = FirestoreService();

  String? query;
  TextEditingController? searchCtl;
  Future<dynamic>? futureSearch;
  Future<List<MidlandMoversItem>>? futureMovers;
  Future<List<MidlandMoversItem>>? futureLosers;
  Future<List<Instrument>>? futureListMovers;
  Future<List<Instrument>>? futureListMostPopular;
  Future<List<Map<String, dynamic>>>? futureTradeSignals;

  InstrumentStore? instrumentStore;

  // Advanced Stock Screener UI state
  List<Instrument>? screenerResults;
  String? screenerSector;
  int? screenerMarketCapMin;
  int? screenerMarketCapMax;
  int? screenerPeMin;
  int? screenerPeMax;
  int? screenerDividendYieldMin;
  int? screenerDividendYieldMax;
  double? screenerPriceMin;
  double? screenerPriceMax;
  int? screenerVolumeMin;
  bool screenerLoading = false;
  String? errorText;
  String screenerSortBy = 'symbol'; // symbol, marketCap, pe, dividend, price

  // Yahoo Screener integration
  late YahooService yahooService;
  ScreenerId? selectedYahooScreener;
  dynamic yahooScreenerResults;
  bool yahooScreenerLoading = false;
  String? yahooScreenerError;

  // Trade Signal Filters
  String? tradeSignalFilter; // null = all, 'BUY', 'SELL', 'HOLD'
  List<String> selectedIndicators =
      []; // Selected indicators from multiIndicatorResult.indicators
  DateTime? tradeSignalStartDate;
  DateTime? tradeSignalEndDate;
  int tradeSignalLimit = 50; // Default limit

  // Controllers for screener fields
  late TextEditingController marketCapMinCtl;
  late TextEditingController marketCapMaxCtl;
  late TextEditingController peMinCtl;
  late TextEditingController peMaxCtl;
  late TextEditingController dividendYieldMinCtl;
  late TextEditingController dividendYieldMaxCtl;
  late TextEditingController priceMinCtl;
  late TextEditingController priceMaxCtl;
  late TextEditingController volumeMinCtl;

  _SearchWidgetState();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    searchCtl = TextEditingController();
    marketCapMinCtl = TextEditingController();
    marketCapMaxCtl = TextEditingController();
    peMinCtl = TextEditingController();
    peMaxCtl = TextEditingController();
    dividendYieldMinCtl = TextEditingController();
    dividendYieldMaxCtl = TextEditingController();
    priceMinCtl = TextEditingController();
    priceMaxCtl = TextEditingController();
    volumeMinCtl = TextEditingController();
    yahooService = YahooService();
    widget.analytics.logScreenView(screenName: 'Search');

    // Fetch trade signals on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tradeSignalsProvider =
          Provider.of<TradeSignalsProvider>(context, listen: false);
      tradeSignalsProvider.fetchAllTradeSignals();
    });
  }

  @override
  void dispose() {
    searchCtl?.dispose();
    marketCapMinCtl.dispose();
    marketCapMaxCtl.dispose();
    peMinCtl.dispose();
    peMaxCtl.dispose();
    dividendYieldMinCtl.dispose();
    dividendYieldMaxCtl.dispose();
    priceMinCtl.dispose();
    priceMaxCtl.dispose();
    volumeMinCtl.dispose();
    yahooService.httpClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return PopScope(
        canPop: false, //When false, blocks the current route from being popped.
        onPopInvokedWithResult: (didPop, result) {
          //do your logic here
          // setStatusBarColor(statusBarColorPrimary,statusBarIconBrightness: Brightness.light);
          // do your logic ends
          return;
        },
        child: _buildScaffold());
  }

  Widget _buildScaffold() {
    instrumentStore = Provider.of<InstrumentStore>(context, listen: false);

    futureMovers ??=
        widget.service.getMovers(widget.brokerageUser, direction: "up");
    futureLosers ??=
        widget.service.getMovers(widget.brokerageUser, direction: "down");
    futureListMovers ??=
        widget.service.getTopMovers(widget.brokerageUser, instrumentStore!);
    // futureListMostPopular ??=
    //     widget.service.getListMostPopular(widget.user, instrumentStore!);
    futureSearch ??= Future.value(null);

    return Column(
      children: [
        Expanded(child: _buildSearchContent()),
      ],
    );
  }

  Widget _buildScreenerPanel() {
    final sectors = [
      'All',
      'Electronic Technology',
      'Consumer Durables',
      'Consumer Non-Durables',
      'Consumer Services',
      'Finance',
      'Health Technology',
      'Miscellaneous',
      'Retail Trade',
      'Technology Services',
      'Transportation',
    ];

    // Keep controllers in sync with state
    marketCapMinCtl.text = screenerMarketCapMin?.toString() ?? '';
    marketCapMaxCtl.text = screenerMarketCapMax?.toString() ?? '';
    peMinCtl.text = screenerPeMin?.toString() ?? '';
    peMaxCtl.text = screenerPeMax?.toString() ?? '';
    dividendYieldMinCtl.text = screenerDividendYieldMin?.toString() ?? '';
    dividendYieldMaxCtl.text = screenerDividendYieldMax?.toString() ?? '';

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12), // .all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8),
          Text('Quick Presets',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetButton(
                    'High Dividend', () => _applyPreset('dividend')),
                SizedBox(width: 8),
                _buildPresetButton(
                    'Growth Stocks', () => _applyPreset('growth')),
                SizedBox(width: 8),
                _buildPresetButton('Value Stocks', () => _applyPreset('value')),
                SizedBox(width: 8),
                _buildPresetButton('Large Cap', () => _applyPreset('largecap')),
                SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _applyPreset('clear'),
                  icon: Icon(Icons.clear_all, size: 16),
                  label: Text('Clear All', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: screenerSector,
            items: sectors
                .map((s) => DropdownMenuItem(
                      value: s == 'All' ? null : s,
                      child: Text(s),
                    ))
                .toList(),
            decoration: InputDecoration(
              labelText: 'Sector',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.08),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (v) => setState(() => screenerSector = v),
          ),
          SizedBox(height: 12),
          Text('Market Cap',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickFilterChip('Micro (<\$300M)', () {
                  setState(() {
                    screenerMarketCapMin = null;
                    screenerMarketCapMax = 300000000;
                    marketCapMinCtl.clear();
                    marketCapMaxCtl.text = '300000000';
                  });
                }),
                SizedBox(width: 8),
                _buildQuickFilterChip('Small (\$300M-\$2B)', () {
                  setState(() {
                    screenerMarketCapMin = 300000000;
                    screenerMarketCapMax = 2000000000;
                    marketCapMinCtl.text = '300000000';
                    marketCapMaxCtl.text = '2000000000';
                  });
                }),
                SizedBox(width: 8),
                _buildQuickFilterChip('Mid (\$2B-\$10B)', () {
                  setState(() {
                    screenerMarketCapMin = 2000000000;
                    screenerMarketCapMax = 10000000000;
                    marketCapMinCtl.text = '2000000000';
                    marketCapMaxCtl.text = '10000000000';
                  });
                }),
                SizedBox(width: 8),
                _buildQuickFilterChip('Large (>\$10B)', () {
                  setState(() {
                    screenerMarketCapMin = 10000000000;
                    screenerMarketCapMax = null;
                    marketCapMinCtl.text = '10000000000';
                    marketCapMaxCtl.clear();
                  });
                }),
              ],
            ),
          ),
          SizedBox(height: 8),
          Row(children: [
            Flexible(
              child: TextField(
                controller: marketCapMinCtl,
                decoration: InputDecoration(
                  labelText: 'Min (USD)',
                  hintText: '1000000000',
                  helperText: '\$1B = 1,000,000,000',
                  helperMaxLines: 1,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.05),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => screenerMarketCapMin = int.tryParse(v)),
              ),
            ),
            SizedBox(width: 12),
            Flexible(
              child: TextField(
                controller: marketCapMaxCtl,
                decoration: InputDecoration(
                  labelText: 'Max (USD)',
                  hintText: '100000000000',
                  helperText: '\$100B = 100,000,000,000',
                  helperMaxLines: 1,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.05),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => screenerMarketCapMax = int.tryParse(v)),
              ),
            ),
          ]),
          SizedBox(height: 12),
          Text('P/E Ratio',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          Text('Value: <15, Growth: >20',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              )),
          SizedBox(height: 4),
          Row(children: [
            Flexible(
              child: TextField(
                controller: peMinCtl,
                decoration: InputDecoration(
                  labelText: 'Min',
                  hintText: '10',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.05),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    setState(() => screenerPeMin = int.tryParse(v)),
              ),
            ),
            SizedBox(width: 12),
            Flexible(
              child: TextField(
                controller: peMaxCtl,
                decoration: InputDecoration(
                  labelText: 'Max',
                  hintText: '30',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.05),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    setState(() => screenerPeMax = int.tryParse(v)),
              ),
            ),
          ]),
          SizedBox(height: 12),
          Text('Dividend Yield (%)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          Text('High dividend: >3%',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              )),
          SizedBox(height: 4),
          Row(children: [
            Flexible(
              child: TextField(
                controller: dividendYieldMinCtl,
                decoration: InputDecoration(
                  labelText: 'Min',
                  hintText: '2',
                  suffixText: '%',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.05),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    setState(() => screenerDividendYieldMin = int.tryParse(v)),
              ),
            ),
            SizedBox(width: 12),
            Flexible(
              child: TextField(
                controller: dividendYieldMaxCtl,
                decoration: InputDecoration(
                  labelText: 'Max',
                  hintText: '5',
                  suffixText: '%',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.05),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    setState(() => screenerDividendYieldMax = int.tryParse(v)),
              ),
            ),
          ]),
          SizedBox(height: 12),
          Text('Price Range (\$)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          SizedBox(height: 4),
          Row(children: [
            Flexible(
              child: TextField(
                controller: priceMinCtl,
                decoration: InputDecoration(
                  labelText: 'Min',
                  hintText: '10',
                  prefixText: '\$',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.05),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    setState(() => screenerPriceMin = double.tryParse(v)),
              ),
            ),
            SizedBox(width: 12),
            Flexible(
              child: TextField(
                controller: priceMaxCtl,
                decoration: InputDecoration(
                  labelText: 'Max',
                  hintText: '500',
                  prefixText: '\$',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.05),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    setState(() => screenerPriceMax = double.tryParse(v)),
              ),
            ),
          ]),
          SizedBox(height: 12),
          Text('Volume',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          Text('Minimum average daily volume',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              )),
          SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickFilterChip('Low (100K+)', () {
                  setState(() {
                    screenerVolumeMin = 100000;
                    volumeMinCtl.text = '100000';
                  });
                }),
                SizedBox(width: 8),
                _buildQuickFilterChip('Med (500K+)', () {
                  setState(() {
                    screenerVolumeMin = 500000;
                    volumeMinCtl.text = '500000';
                  });
                }),
                SizedBox(width: 8),
                _buildQuickFilterChip('High (1M+)', () {
                  setState(() {
                    screenerVolumeMin = 1000000;
                    volumeMinCtl.text = '1000000';
                  });
                }),
                SizedBox(width: 8),
                _buildQuickFilterChip('Very High (5M+)', () {
                  setState(() {
                    screenerVolumeMin = 5000000;
                    volumeMinCtl.text = '5000000';
                  });
                }),
              ],
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: volumeMinCtl,
            decoration: InputDecoration(
              labelText: 'Min Volume',
              hintText: '1000000',
              helperText: '1M = 1,000,000',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.05),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) =>
                setState(() => screenerVolumeMin = int.tryParse(v)),
          ),
          if (errorText != null) ...[
            SizedBox(height: 8),
            Text(errorText!, style: TextStyle(color: Colors.red)),
          ],
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: screenerLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : Icon(Icons.filter_list_sharp),
                  onPressed: screenerLoading
                      ? null
                      : () async {
                          // Validate min/max fields
                          if (screenerMarketCapMin != null &&
                              screenerMarketCapMax != null &&
                              screenerMarketCapMin! > screenerMarketCapMax!) {
                            setState(() {
                              errorText =
                                  'Market Cap Min cannot be greater than Max.';
                            });
                            return;
                          }
                          if (screenerPeMin != null &&
                              screenerPeMax != null &&
                              screenerPeMin! > screenerPeMax!) {
                            setState(() {
                              errorText = 'P/E Min cannot be greater than Max.';
                            });
                            return;
                          }
                          if (screenerDividendYieldMin != null &&
                              screenerDividendYieldMax != null &&
                              screenerDividendYieldMin! >
                                  screenerDividendYieldMax!) {
                            setState(() {
                              errorText =
                                  'Dividend Yield Min cannot be greater than Max.';
                            });
                            return;
                          }
                          if (screenerPriceMin != null &&
                              screenerPriceMax != null &&
                              screenerPriceMin! > screenerPriceMax!) {
                            setState(() {
                              errorText =
                                  'Price Min cannot be greater than Max.';
                            });
                            return;
                          }
                          setState(() {
                            screenerLoading = true;
                            errorText = null;
                            screenerResults = null;
                          });
                          try {
                            var results = await _firestoreService.stockScreener(
                              sector: screenerSector,
                              marketCapMin: screenerMarketCapMin,
                              marketCapMax: screenerMarketCapMax,
                              peMin: screenerPeMin,
                              peMax: screenerPeMax,
                              dividendYieldMin: screenerDividendYieldMin,
                              dividendYieldMax: screenerDividendYieldMax,
                            );

                            // Client-side filtering for price and volume
                            if (screenerPriceMin != null) {
                              results = results
                                  .where((i) =>
                                      (i.quoteObj?.lastTradePrice ?? 0) >=
                                      screenerPriceMin!)
                                  .toList();
                            }
                            if (screenerPriceMax != null) {
                              results = results
                                  .where((i) =>
                                      (i.quoteObj?.lastTradePrice ??
                                          double.infinity) <=
                                      screenerPriceMax!)
                                  .toList();
                            }
                            if (screenerVolumeMin != null) {
                              results = results
                                  .where((i) =>
                                      (i.fundamentalsObj?.averageVolume ?? 0) >=
                                      screenerVolumeMin!)
                                  .toList();
                            }

                            setState(() {
                              screenerResults = results;
                              screenerLoading = false;
                              // Keep controllers in sync after results
                              marketCapMinCtl.text =
                                  screenerMarketCapMin?.toString() ?? '';
                              marketCapMaxCtl.text =
                                  screenerMarketCapMax?.toString() ?? '';
                              peMinCtl.text = screenerPeMin?.toString() ?? '';
                              peMaxCtl.text = screenerPeMax?.toString() ?? '';
                              dividendYieldMinCtl.text =
                                  screenerDividendYieldMin?.toString() ?? '';
                              dividendYieldMaxCtl.text =
                                  screenerDividendYieldMax?.toString() ?? '';
                              priceMinCtl.text =
                                  screenerPriceMin?.toString() ?? '';
                              priceMaxCtl.text =
                                  screenerPriceMax?.toString() ?? '';
                              volumeMinCtl.text =
                                  screenerVolumeMin?.toString() ?? '';
                            });
                          } catch (e) {
                            setState(() {
                              screenerLoading = false;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: SelectableText(
                                        'Error running screener: $e')),
                              );
                            }
                          }
                        },
                  label: Text(
                    screenerLoading ? 'Screening...' : 'Run Screener',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    disabledBackgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScreenerSliver() {
    return SliverStickyHeader(
      header: Material(
        elevation: 2,
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          alignment: Alignment.centerLeft,
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.filter_alt,
                      color: Theme.of(context).colorScheme.primary, size: 22),
                ),
                title: Text(
                  screenerResults != null && screenerResults!.isNotEmpty
                      ? 'Screener (${screenerResults!.length})'
                      : 'Screener',
                  style: TextStyle(
                    fontSize: 19.0,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                trailing: null,
              ),
            ],
          ),
        ),
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _buildScreenerPanel(),
          if (screenerResults != null && screenerResults!.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sort Results',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: screenerSortBy,
                          underline: Container(
                            height: 1,
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withOpacity(0.3),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          items: [
                            DropdownMenuItem(
                                value: 'symbol',
                                child: Text('Symbol',
                                    style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(
                                value: 'marketCap',
                                child: Text('Market Cap',
                                    style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(
                                value: 'pe',
                                child: Text('P/E Ratio',
                                    style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(
                                value: 'dividend',
                                child: Text('Dividend',
                                    style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(
                                value: 'price',
                                child: Text('Price',
                                    style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(
                                value: 'volume',
                                child: Text('Volume',
                                    style: TextStyle(fontSize: 13))),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => screenerSortBy = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withOpacity(0.3),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150.0,
                mainAxisSpacing: 6.0,
                crossAxisSpacing: 2.0,
                childAspectRatio: 1.2,
              ),
              itemCount: screenerResults!.length,
              itemBuilder: (BuildContext context, int gridIndex) {
                final sortedResults = _sortScreenerResults(screenerResults!);
                return _buildListGridItem(
                    sortedResults, gridIndex, widget.brokerageUser);
              },
            ),
          ] else if (screenerResults != null && screenerResults!.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.3)),
                    SizedBox(height: 16),
                    Text('No results found.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        )),
                    SizedBox(height: 8),
                    Text('Try adjusting your filter criteria',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.4),
                        )),
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildYahooScreenerSliver() {
    return SliverStickyHeader(
      header: Material(
        elevation: 2,
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          alignment: Alignment.centerLeft,
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.dashboard_customize,
                  color: Theme.of(context).colorScheme.primary, size: 22),
            ),
            title: Text(
              "Presets",
              style: TextStyle(
                fontSize: 19.0,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _buildYahooScreenerPanel(),
          if (yahooScreenerLoading) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ],
          if (yahooScreenerError != null) ...[
            const SizedBox(height: 8),
            Text('Error: $yahooScreenerError',
                style: const TextStyle(color: Colors.red)),
          ],
          if (yahooScreenerResults != null) ...[
            Builder(
              builder: (context) {
                final records = yahooScreenerResults['finance']?['result']?[0]
                        ?['records'] ??
                    [];
                if (records.isEmpty) {
                  return const Center(child: Text('No results found.'));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(4.0),
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: records.length,
                  // separatorBuilder: (context, idx) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final item = records[idx];
                    return ListTile(
                        // leading: item['logo_url'] != null
                        //     ? Image.network(item['logo_url'],
                        //         width: 32,
                        //         height: 32,
                        //         errorBuilder: (c, e, s) =>
                        //             const Icon(Icons.image_not_supported))
                        //     : const Icon(Icons.business),
                        title: Text(item['companyName'] ?? item['ticker'] ?? '',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(item['ticker'] ?? '',
                            style: const TextStyle(fontSize: 13)),
                        trailing: item['regularMarketPrice'] != null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatCurrency.format(
                                        item['regularMarketPrice']['raw']),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.normal,
                                        fontSize: 16),
                                  ),
                                  if (item['regularMarketChangePercent'] !=
                                      null)
                                    Text(
                                      formatPercentage.format(
                                          item['regularMarketChangePercent']
                                                  ['raw'] /
                                              100),
                                      style: TextStyle(
                                        color:
                                            (item['regularMarketChangePercent']
                                                            ['raw'] ??
                                                        0) >=
                                                    0
                                                ? Colors.green
                                                : Colors.red,
                                        fontSize: 14,
                                      ),
                                    ),
                                ],
                              )
                            : null,
                        onTap: () async {
                          var instrument = await widget.service
                              .getInstrumentBySymbol(
                                  widget.brokerageUser,
                                  Provider.of<InstrumentStore>(context,
                                      listen: false),
                                  item['ticker']);
                          if (instrument != null) {
                            if (context.mounted) {
                              Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (context) {
                                return InstrumentWidget(
                                  widget.brokerageUser,
                                  widget.service,
                                  instrument,
                                  analytics: widget.analytics,
                                  observer: widget.observer,
                                  generativeService: widget.generativeService,
                                  user: widget.user,
                                  userDocRef: widget.userDocRef,
                                );
                              }));
                            }
                          }
                        });
                  },
                );
              },
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildYahooScreenerPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<ScreenerId>(
            initialValue: selectedYahooScreener,
            items: YahooService.scrIds
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.display),
                    ))
                .toList(),
            onChanged: (v) async {
              setState(() => selectedYahooScreener = v);
              setState(() {
                yahooScreenerLoading = true;
                yahooScreenerError = null;
                yahooScreenerResults = null;
              });
              try {
                final result = await yahooService.getStockScreener(
                  scrIds: selectedYahooScreener!.id,
                );
                setState(() {
                  yahooScreenerResults = result;
                  yahooScreenerLoading = false;
                });
              } catch (e) {
                setState(() {
                  yahooScreenerError = e.toString();
                  yahooScreenerLoading = false;
                });
              }
            },
            decoration: const InputDecoration(labelText: 'Screener'),
          ),
          const SizedBox(height: 12),
          // ElevatedButton.icon(
          //   icon: Icon(Icons.search),
          //   onPressed: selectedYahooScreener == null || yahooScreenerLoading
          //       ? null
          //       : () async {
          //           setState(() {
          //             yahooScreenerLoading = true;
          //             yahooScreenerError = null;
          //             yahooScreenerResults = null;
          //           });
          //           try {
          //             final result = await yahooService.getStockScreener(
          //               scrIds: selectedYahooScreener!.id,
          //             );
          //             setState(() {
          //               yahooScreenerResults = result;
          //               yahooScreenerLoading = false;
          //             });
          //           } catch (e) {
          //             setState(() {
          //               yahooScreenerError = e.toString();
          //               yahooScreenerLoading = false;
          //             });
          //           }
          //         },
          //   label: const Text('Run Screener'),
          // ),
        ],
      ),
    );
  }

  Widget _buildSearchContent() {
    return FutureBuilder(
        future: Future.wait([
          futureSearch as Future,
          futureMovers as Future,
          futureLosers as Future,
          futureListMovers as Future,
          // futureListMostPopular as Future,
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.hasData) {
            List<dynamic> data = snapshot.data as List<dynamic>;
            var search = data.isNotEmpty ? data[0] as dynamic : null;
            var movers =
                data.length > 1 ? data[1] as List<MidlandMoversItem> : null;
            var losers =
                data.length > 2 ? data[2] as List<MidlandMoversItem> : null;
            var listMovers =
                data.length > 3 ? data[3] as List<Instrument> : null;
            // var listMostPopular =
            //     data.length > 4 ? data[4] as List<Instrument> : null;
            return _buildPage(
                search: search,
                movers: movers,
                losers: losers,
                listMovers: listMovers,
                listMostPopular: null, //listMostPopular,
                done: snapshot.connectionState == ConnectionState.done);
          } else if (snapshot.hasError) {
            debugPrint("${snapshot.error}");
            return _buildPage(welcomeWidget: Text("${snapshot.error}"));
          } else {
            return _buildPage(
                done: snapshot.connectionState == ConnectionState.done);
          }
        });
  }

  Widget _buildPage(
      {Widget? welcomeWidget,
      dynamic search,
      List<MidlandMoversItem>? movers,
      List<MidlandMoversItem>? losers,
      List<Instrument>? listMovers,
      List<Instrument>? listMostPopular,
      bool done = false}) {
    return RefreshIndicator(
        onRefresh: _pullRefresh,
        child: GestureDetector(
            onTap: () {
              FocusScopeNode currentFocus = FocusScope.of(context);

              if (!currentFocus.hasPrimaryFocus) {
                currentFocus.unfocus();
              }
            },
            child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverAppBar(
                      floating: false,
                      snap: false,
                      pinned: true,
                      centerTitle: false,
                      title: const Text('Search'),
                      actions: [
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
                                : const Icon(Icons.login),
                            onPressed: () async {
                              var response = await showProfile(
                                  context,
                                  auth,
                                  _firestoreService,
                                  widget.analytics,
                                  widget.observer,
                                  widget.brokerageUser);
                              if (response != null) {
                                setState(() {});
                              }
                            })
                      ]),
                  if (done == false) ...[
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 3, //150.0,
                      child: Align(
                          alignment: Alignment.center,
                          child: Center(
                              child: LinearProgressIndicator(
                                  //value: controller.value,
                                  //semanticsLabel: 'Linear progress indicator',
                                  ) //CircularProgressIndicator(),
                              )),
                    ))
                  ],
                  SliverStickyHeader(
                    header: Material(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          controller: searchCtl,
                          decoration: InputDecoration(
                            hintText: 'Search stocks by name or symbol',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchCtl!.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      searchCtl!.clear();
                                      setState(() {
                                        futureSearch = Future.value(null);
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                  color: Colors.blue, width: 2),
                            ),
                            filled: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16.0),
                          ),
                          onChanged: (text) {
                            widget.analytics.logSearch(searchTerm: text);
                            setState(() {
                              futureSearch = text.isEmpty
                                  ? Future.value(null)
                                  : widget.service
                                      .search(widget.brokerageUser, text);
                            });
                          },
                        ),
                      ),
                    ),
                    sliver: SliverPadding(
                        padding: const EdgeInsets.all(
                            2), // .symmetric(horizontal: 2),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 125.0,
                            mainAxisSpacing: 10.0,
                            crossAxisSpacing: 10.0,
                            childAspectRatio: 1.29,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              return _buildSearchGridItem(search, index);
                            },
                            childCount: search != null
                                ? search["results"][0]["content"]["data"].length
                                : 0,
                          ),
                        )),
                  ),
                  if (welcomeWidget != null) ...[
                    SliverToBoxAdapter(
                        child: SizedBox(
                      height: 150.0,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Align(
                            alignment: Alignment.center, child: welcomeWidget),
                      ),
                    ))
                  ],
                  // if (search != null) ...[
                  //   SliverStickyHeader(
                  //       header: Material(
                  //           //elevation: 2,
                  //           child: Container(
                  //               alignment: Alignment.centerLeft,
                  //               child: const ListTile(
                  //                 title: Text(
                  //                   "Search Results",
                  //                   style: TextStyle(fontSize: 19.0),
                  //                 ),
                  //                 //subtitle: Text(
                  //                 //    "${formatCompactNumber.format(filteredPositionOrders!.length)} of ${formatCompactNumber.format(positionOrders.length)} orders $orderDateFilterDisplay ${positionOrdersBalance > 0 ? "+" : positionOrdersBalance < 0 ? "-" : ""}${formatCurrency.format(positionOrdersBalance.abs())}"),
                  //               ))),
                  //       sliver: SliverPadding(
                  //           padding: const EdgeInsets.symmetric(horizontal: 2),
                  //           sliver: SliverGrid(
                  //             gridDelegate:
                  //                 const SliverGridDelegateWithMaxCrossAxisExtent(
                  //               maxCrossAxisExtent: 125.0,
                  //               mainAxisSpacing: 10.0,
                  //               crossAxisSpacing: 10.0,
                  //               childAspectRatio: 1.25,
                  //             ),
                  //             delegate: SliverChildBuilderDelegate(
                  //               (BuildContext context, int index) {
                  //                 return _buildSearchGridItem(search, index);
                  //               },
                  //               childCount: search["results"][0]["content"]
                  //                       ["data"]
                  //                   .length,
                  //             ),
                  //           ))),
                  //   const SliverToBoxAdapter(
                  //       child: SizedBox(
                  //     height: 25.0,
                  //   )),
                  // ],
                  Consumer<TradeSignalsProvider>(
                    builder: (context, tradeSignalsProvider, child) {
                      final tradeSignals = tradeSignalsProvider.tradeSignals;
                      final isMarketOpen = MarketHours.isMarketOpen();
                      final selectedInterval =
                          tradeSignalsProvider.selectedInterval;
                      final intervalLabel = selectedInterval == '1d'
                          ? 'Daily'
                          : selectedInterval == '1h'
                              ? 'Hourly'
                              : selectedInterval == '30m'
                                  ? '30-min'
                                  : selectedInterval == '15m'
                                      ? '15-min'
                                      : selectedInterval;

                      return SliverStickyHeader(
                          header: Material(
                              elevation: 2,
                              child: Container(
                                  color: Theme.of(context).colorScheme.surface,
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.insights,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              size: 22),
                                        ),
                                        title: Row(
                                          children: [
                                            Text(
                                              "Trade Signals",
                                              style: TextStyle(
                                                fontSize: 19.0,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                            const Spacer(),
                                            IconButton(
                                              icon: const Icon(Icons.settings,
                                                  size: 20),
                                              tooltip:
                                                  'Agentic Trading Settings',
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () async {
                                                // Navigate to agentic trading settings
                                                if (!mounted ||
                                                    widget.user == null ||
                                                    widget.userDocRef == null) {
                                                  return;
                                                }
                                                final result =
                                                    await Navigator.of(context)
                                                        .push(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        AgenticTradingSettingsWidget(
                                                      user: widget.user!,
                                                      userDocRef:
                                                          widget.userDocRef!,
                                                    ),
                                                  ),
                                                );
                                                // Refresh signals when returning from settings
                                                if (result == true && mounted) {
                                                  _fetchTradeSignalsWithFilters();
                                                }
                                              },
                                            ),
                                            const SizedBox(width: 4),
                                            PopupMenuButton<String>(
                                              icon: Icon(
                                                isMarketOpen
                                                    ? Icons.access_time
                                                    : Icons.calendar_today,
                                                color: isMarketOpen
                                                    ? Colors.green.shade700
                                                    : Colors.blue.shade700,
                                              ),
                                              tooltip:
                                                  '${isMarketOpen ? 'Market Open' : 'After Hours'} • $intervalLabel',
                                              itemBuilder:
                                                  (BuildContext context) {
                                                return [
                                                  PopupMenuItem<String>(
                                                    enabled: false,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom: 8.0),
                                                      child: Text(
                                                        isMarketOpen
                                                            ? 'Market Open'
                                                            : 'After Hours',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: isMarketOpen
                                                              ? Colors.green
                                                                  .shade700
                                                              : Colors.blue
                                                                  .shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  PopupMenuDivider(),
                                                  PopupMenuItem<String>(
                                                    value: '15m',
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text('15-min'),
                                                        if (selectedInterval ==
                                                            '15m')
                                                          const SizedBox(
                                                              width: 8),
                                                        if (selectedInterval ==
                                                            '15m')
                                                          Icon(Icons.check,
                                                              size: 18,
                                                              color: Colors
                                                                  .green
                                                                  .shade700),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuItem<String>(
                                                    value: '1h',
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text('Hourly'),
                                                        if (selectedInterval ==
                                                            '1h')
                                                          const SizedBox(
                                                              width: 8),
                                                        if (selectedInterval ==
                                                            '1h')
                                                          Icon(Icons.check,
                                                              size: 18,
                                                              color: Colors
                                                                  .green
                                                                  .shade700),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuItem<String>(
                                                    value: '1d',
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text('Daily'),
                                                        if (selectedInterval ==
                                                            '1d')
                                                          const SizedBox(
                                                              width: 8),
                                                        if (selectedInterval ==
                                                            '1d')
                                                          Icon(Icons.check,
                                                              size: 18,
                                                              color: Colors
                                                                  .green
                                                                  .shade700),
                                                      ],
                                                    ),
                                                  ),
                                                ];
                                              },
                                              onSelected: (String interval) {
                                                tradeSignalsProvider
                                                    .setSelectedInterval(
                                                        interval);
                                                _fetchTradeSignalsWithFilters();
                                              },
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Consumer<AgenticTradingProvider>(
                                        builder:
                                            (context, agenticProvider, child) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16.0,
                                                vertical: 4.0),
                                            child:
                                                _buildTradeSignalFilterChips(),
                                          );
                                        },
                                      ),
                                    ],
                                  ))),
                          sliver: tradeSignals.isEmpty
                              ? SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Center(
                                      child: Text(
                                        tradeSignalFilter == null
                                            ? 'No trade signals available'
                                            : 'No $tradeSignalFilter signals found',
                                        style: TextStyle(
                                          fontSize: 16.0,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : SliverPadding(
                                  padding: const EdgeInsets.all(
                                      2), // .symmetric(horizontal: 2),
                                  sliver: SliverGrid(
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 220.0,
                                      mainAxisSpacing: 10.0,
                                      crossAxisSpacing: 10.0,
                                      childAspectRatio: 1.25,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (BuildContext context, int index) {
                                        return _buildTradeSignalGridItem(
                                            tradeSignals, index);
                                      },
                                      childCount: tradeSignals.length,
                                    ),
                                  )));
                    },
                  ),
                  _buildScreenerSliver(),
                  _buildYahooScreenerSliver(),

                  if (movers != null && movers.isNotEmpty) ...[
                    SliverStickyHeader(
                        header: Material(
                            elevation: 2,
                            child: Container(
                                color: Theme.of(context).colorScheme.surface,
                                alignment: Alignment.centerLeft,
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.trending_up,
                                        color: Colors.green, size: 22),
                                  ),
                                  title: Text(
                                    "S&P Gainers",
                                    style: TextStyle(
                                      fontSize: 19.0,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.all(
                                2), // .symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220.0,
                                mainAxisSpacing: 10.0,
                                crossAxisSpacing: 10.0,
                                childAspectRatio: 1.3,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildMoversGridItem(movers, index);
                                },
                                childCount: movers.length,
                              ),
                            ))),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                  ],
                  if (losers != null && losers.isNotEmpty) ...[
                    SliverStickyHeader(
                        header: Material(
                            elevation: 2,
                            child: Container(
                                color: Theme.of(context).colorScheme.surface,
                                alignment: Alignment.centerLeft,
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.trending_down,
                                        color: Colors.red, size: 22),
                                  ),
                                  title: Text(
                                    "S&P Decliners",
                                    style: TextStyle(
                                      fontSize: 19.0,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.all(
                                2), // .symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220.0,
                                mainAxisSpacing: 10.0,
                                crossAxisSpacing: 10.0,
                                childAspectRatio: 1.3,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildMoversGridItem(losers, index);
                                },
                                childCount: losers.length,
                              ),
                            ))),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                  ],
                  if (listMovers != null && listMovers.isNotEmpty) ...[
                    SliverStickyHeader(
                        header: Material(
                            elevation: 2,
                            child: Container(
                                color: Theme.of(context).colorScheme.surface,
                                alignment: Alignment.centerLeft,
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.show_chart,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 22),
                                  ),
                                  title: Text(
                                    "Top Movers",
                                    style: TextStyle(
                                      fontSize: 19.0,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.all(
                                2), // .symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 150.0,
                                mainAxisSpacing: 6.0,
                                crossAxisSpacing: 2.0,
                                childAspectRatio: 1.25,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildListGridItem(
                                      listMovers, index, widget.brokerageUser);
                                },
                                childCount: listMovers.length,
                              ),
                            ))),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                  ],
                  if (listMostPopular != null &&
                      listMostPopular.isNotEmpty) ...[
                    SliverStickyHeader(
                        header: Material(
                            elevation: 2,
                            child: Container(
                                color: Theme.of(context).colorScheme.surface,
                                alignment: Alignment.centerLeft,
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.star,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 22),
                                  ),
                                  title: Text(
                                    "100 Most Popular",
                                    style: TextStyle(
                                      fontSize: 19.0,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.all(
                                2), // .symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 150.0,
                                mainAxisSpacing: 6.0,
                                crossAxisSpacing: 2.0,
                                childAspectRatio: 1.25,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildListGridItem(listMostPopular,
                                      index, widget.brokerageUser);
                                },
                                childCount: listMostPopular.length,
                              ),
                            ))),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                  ],
                  // TODO: Introduce web banner
                  if (!kIsWeb) ...[
                    SliverToBoxAdapter(
                        child: AdBannerWidget(
                      size: AdSize.mediumRectangle,
                      searchBanner: true,
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
                ])));
  }

  Future<void> _pullRefresh() async {
    setState(() {
      futureMovers = null;
      futureLosers = null;
      futureListMovers = null;
      futureListMostPopular = null;
      futureSearch = Future.value(null);
      futureTradeSignals = null;
    });
    // Refresh trade signals on pull-to-refresh
    final tradeSignalsProvider =
        Provider.of<TradeSignalsProvider>(context, listen: false);
    await tradeSignalsProvider.fetchAllTradeSignals();
  }

  Widget _buildMoversGridItem(List<MidlandMoversItem> movers, int index) {
    final isPositive = movers[index].marketHoursPriceMovement! > 0;
    final isNegative = movers[index].marketHoursPriceMovement! < 0;
    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: isPositive
                ? Colors.green.withOpacity(0.3)
                : (isNegative
                    ? Colors.red.withOpacity(0.3)
                    : Colors.grey.withOpacity(
                        0.2)), // Theme.of(context).colorScheme.outlineVariant)
            width: 1.5,
          ),
        ),
        child: InkWell(
            borderRadius: BorderRadius.circular(12.0),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(movers[index].symbol,
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                              isPositive
                                  ? Icons.trending_up
                                  : (isNegative
                                      ? Icons.trending_down
                                      : Icons.trending_flat),
                              color: isPositive
                                  ? Colors.green
                                  : (isNegative ? Colors.red : Colors.grey),
                              size: 18),
                          const SizedBox(width: 4),
                          Text(
                              formatPercentage.format(movers[index]
                                      .marketHoursPriceMovement!
                                      .abs() /
                                  100),
                              style: TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w600,
                                color: isPositive
                                    ? Colors.green
                                    : (isNegative ? Colors.red : Colors.grey),
                              )),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                          formatCurrency
                              .format(movers[index].marketHoursLastPrice),
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          )),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(movers[index].description,
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ])),
            onTap: () async {
              var instrument = await widget.service.getInstrument(
                  widget.brokerageUser,
                  instrumentStore!,
                  movers[index].instrumentUrl);

              /* For navigation within this tab, uncomment
                widget.navigatorKey!.currentState!.push(MaterialPageRoute(
                    builder: (context) => InstrumentWidget(ru,
                        watchLists[index].instrumentObj as Instrument)));
                        */
              if (!mounted) return;
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => InstrumentWidget(
                            widget.brokerageUser,
                            widget.service,
                            instrument,
                            analytics: widget.analytics,
                            observer: widget.observer,
                            generativeService: widget.generativeService,
                            user: widget.user,
                            userDocRef: widget.userDocRef,
                          )));
            }));
  }

  Widget _buildSearchGridItem(dynamic search, int index) {
    var data = search["results"][0]["content"]["data"][index];
    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: Colors.grey.withOpacity(
                0.2), // Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: InkWell(
            borderRadius: BorderRadius.circular(12.0),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        data["item"]["symbol"],
                        style: TextStyle(
                          fontSize: 17.0,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          data["item"]["simple_name"] ?? data["item"]["name"],
                          style: TextStyle(
                            fontSize: 12.0,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    ])),
            onTap: () {
              var instrument = Instrument.fromJson(data["item"]);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => InstrumentWidget(
                            widget.brokerageUser,
                            widget.service,
                            instrument,
                            analytics: widget.analytics,
                            observer: widget.observer,
                            generativeService: widget.generativeService,
                            user: widget.user,
                            userDocRef: widget.userDocRef,
                          )));
            }));
    /*
    return ListTile(
      title: Text(data["item"]["symbol"]),
      subtitle: Text(data["item"]["simple_name"] ?? data["item"]["name"]),
      onTap: () {
        var instrument = Instrument.fromJson(data["item"]);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    InstrumentWidget(widget.user, instrument)));
      },
    );
    */
  }

  Widget _buildTradeSignalGridItem(
      List<Map<String, dynamic>> tradeSignals, int index) {
    final signal = tradeSignals[index];
    final timestamp = signal['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(signal['timestamp'] as int)
        : DateTime.now();
    final symbol = signal['symbol'] ?? 'N/A';
    final overallSignalType = signal['signal'] ?? 'HOLD';

    // Extract individual indicator signals from multiIndicatorResult
    final multiIndicatorResult =
        signal['multiIndicatorResult'] as Map<String, dynamic>?;
    final indicatorsMap =
        multiIndicatorResult?['indicators'] as Map<String, dynamic>?;

    Map<String, String> indicatorSignals = {};
    if (indicatorsMap != null) {
      const indicatorNames = [
        'priceMovement',
        'momentum',
        'marketDirection',
        'volume',
        'macd',
        'bollingerBands',
        'stochastic',
        'atr',
        'obv',
      ];

      for (final indicator in indicatorNames) {
        final indicatorData = indicatorsMap[indicator] as Map<String, dynamic>?;
        if (indicatorData != null && indicatorData['signal'] != null) {
          indicatorSignals[indicator] = indicatorData['signal'];
        }
      }
    }

    // Calculate composite signal based on enabled indicators
    final agenticProvider =
        Provider.of<AgenticTradingProvider>(context, listen: false);
    final enabledIndicators =
        agenticProvider.config['enabledIndicators'] != null
            ? Map<String, bool>.from(
                agenticProvider.config['enabledIndicators'] as Map)
            : {};

    // If there are enabled indicators, use them to calculate composite signal
    String displaySignalType = overallSignalType;
    if (enabledIndicators.isNotEmpty) {
      final enabledIndicatorSignals = indicatorSignals.entries
          .where((entry) => enabledIndicators[entry.key] == true)
          .map((entry) => entry.value)
          .toList();

      if (enabledIndicatorSignals.isNotEmpty) {
        // Require unanimous agreement for BUY or SELL, otherwise HOLD (mixed)
        final allBuy = enabledIndicatorSignals.every((s) => s == 'BUY');
        final allSell = enabledIndicatorSignals.every((s) => s == 'SELL');

        if (allBuy) {
          displaySignalType = 'BUY';
        } else if (allSell) {
          displaySignalType = 'SELL';
        } else {
          // Mixed signals: use HOLD
          displaySignalType = 'HOLD';
        }
      }
    }

    final signalType = displaySignalType;
    final isBuy = signalType == 'BUY';
    final isSell = signalType == 'SELL';

    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: isBuy
                ? Colors.green.withOpacity(0.3)
                : (isSell
                    ? Colors.red.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2)),
            width: 1.5,
          ),
        ),
        child: InkWell(
            borderRadius: BorderRadius.circular(12.0),
            child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(symbol,
                                style: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isBuy
                                  ? Colors.green.withOpacity(0.15)
                                  : (isSell
                                      ? Colors.red.withOpacity(0.15)
                                      : Colors.grey.withOpacity(0.15)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                    isBuy
                                        ? Icons.trending_up
                                        : (isSell
                                            ? Icons.trending_down
                                            : Icons.trending_flat),
                                    color: isBuy
                                        ? Colors.green
                                        : (isSell ? Colors.red : Colors.grey),
                                    size: 16),
                                const SizedBox(width: 4),
                                Text(signalType,
                                    style: TextStyle(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.bold,
                                      color: isBuy
                                          ? Colors.green
                                          : (isSell ? Colors.red : Colors.grey),
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(_formatSignalTimestamp(timestamp),
                          style: TextStyle(
                              fontSize: 12.0,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          overflow: TextOverflow.ellipsis),
                      // Individual indicator signal tags
                      if (indicatorSignals.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: indicatorSignals.entries.map((entry) {
                            final indicatorName = entry.key;
                            final indicatorSignal = entry.value;
                            final isIndicatorEnabled =
                                enabledIndicators[indicatorName] == true;

                            Color tagColor;
                            if (indicatorSignal == 'BUY') {
                              tagColor = Colors.green;
                            } else if (indicatorSignal == 'SELL') {
                              tagColor = Colors.red;
                            } else {
                              tagColor = Colors.grey;
                            }

                            // Short names for display
                            final displayName = indicatorName == 'priceMovement'
                                ? 'Price'
                                : indicatorName == 'marketDirection'
                                    ? 'Market'
                                    : indicatorName == 'bollingerBands'
                                        ? 'BB'
                                        : indicatorName == 'stochastic'
                                            ? 'Stoch'
                                            : indicatorName[0].toUpperCase() +
                                                indicatorName.substring(1);

                            // Disable styling for indicators not in settings
                            final opacity = isIndicatorEnabled ? 1.0 : 0.4;
                            final disabledColor = Colors.grey;
                            final finalTagColor =
                                isIndicatorEnabled ? tagColor : disabledColor;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    finalTagColor.withOpacity(0.15 * opacity),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color:
                                      finalTagColor.withOpacity(0.4 * opacity),
                                  width: 0.5,
                                ),
                              ),
                              child: Opacity(
                                opacity: opacity,
                                child: Text(
                                  displayName, //'$displayName: ${indicatorSignal[0]}',
                                  style: TextStyle(
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.w600,
                                    color: finalTagColor,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      // const SizedBox(height: 8),
                      // Expanded(
                      //   child: Text(reason,
                      //       style: TextStyle(
                      //         fontSize: 12.0,
                      //         color: Colors.grey.shade700,
                      //       ),
                      //       maxLines: 3,
                      //       overflow: TextOverflow.ellipsis),
                      // ),
                    ])),
            onTap: () async {
              final symbol = signal['symbol'];
              if (symbol == null || symbol == 'N/A') return;
              var instrument = await widget.service.getInstrumentBySymbol(
                  widget.brokerageUser, instrumentStore!, symbol);

              if (!mounted || instrument == null) return;
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => InstrumentWidget(
                            widget.brokerageUser,
                            widget.service,
                            instrument,
                            analytics: widget.analytics,
                            observer: widget.observer,
                            generativeService: widget.generativeService,
                            user: widget.user,
                            userDocRef: widget.userDocRef,
                          )));
            }));
  }

  Widget _buildListGridItem(
      List<Instrument> instruments, int index, BrokerageUser user) {
    var instrumentObj = instruments[index];
    final hasQuote = instrumentObj.quoteObj != null;
    final lastTradePrice =
        hasQuote ? instrumentObj.quoteObj!.lastTradePrice : null;
    final changeToday = hasQuote ? instrumentObj.quoteObj!.changeToday : 0.0;
    final changePercentToday =
        hasQuote ? instrumentObj.quoteObj!.changePercentToday : 0.0;

    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: changeToday > 0
                ? Colors.green.withOpacity(0.3)
                : (changeToday < 0
                    ? Colors.red.withOpacity(0.3)
                    : Colors.grey.withOpacity(
                        0.2)), // Theme.of(context).colorScheme.outlineVariant)
            width: 1.5,
          ),
        ),
        child: InkWell(
            borderRadius: BorderRadius.circular(12.0),
            child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Symbol - always shown
                    Text(
                      instrumentObj.symbol,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Current Price
                    if (lastTradePrice != null) ...[
                      Text(
                        formatCurrency.format(lastTradePrice),
                        style: TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Change indicator with percentage
                    if (hasQuote) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            changeToday > 0
                                ? Icons.trending_up
                                : (changeToday < 0
                                    ? Icons.trending_down
                                    : Icons.trending_flat),
                            color: changeToday > 0
                                ? Colors.green
                                : (changeToday < 0 ? Colors.red : Colors.grey),
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              formatPercentage.format(changePercentToday.abs()),
                              style: TextStyle(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w600,
                                color: changeToday > 0
                                    ? Colors.green
                                    : (changeToday < 0
                                        ? Colors.red
                                        : Colors.grey),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'No quote data',
                        style: TextStyle(
                            fontSize: 12.0,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                )),
            onTap: () {
              /* For navigation within this tab, uncomment
              widget.navigatorKey!.currentState!.push(MaterialPageRoute(
                  builder: (context) => InstrumentWidget(ru,
                      watchLists[index].instrumentObj as Instrument)));
                      */
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => InstrumentWidget(
                            user,
                            widget.service,
                            instrumentObj,
                            analytics: widget.analytics,
                            observer: widget.observer,
                            generativeService: widget.generativeService,
                            user: widget.user,
                            userDocRef: widget.userDocRef,
                          )));
            }));
  }

  Widget _buildQuickFilterChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.primary,
          )),
      onPressed: onTap,
      backgroundColor:
          Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
      side: BorderSide(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        width: 1,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }

  Widget _buildPresetButton(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          )),
    );
  }

  void _applyPreset(String preset) {
    setState(() {
      // Clear all filters first
      screenerSector = null;
      screenerMarketCapMin = null;
      screenerMarketCapMax = null;
      screenerPeMin = null;
      screenerPeMax = null;
      screenerDividendYieldMin = null;
      screenerDividendYieldMax = null;
      screenerPriceMin = null;
      screenerPriceMax = null;
      screenerVolumeMin = null;
      marketCapMinCtl.clear();
      marketCapMaxCtl.clear();
      peMinCtl.clear();
      peMaxCtl.clear();
      dividendYieldMinCtl.clear();
      dividendYieldMaxCtl.clear();
      priceMinCtl.clear();
      priceMaxCtl.clear();
      volumeMinCtl.clear();

      // Apply preset filters
      switch (preset) {
        case 'clear':
          // Already cleared above, do nothing
          break;
        case 'dividend':
          screenerDividendYieldMin = 3;
          screenerVolumeMin = 1000000; // 1M+ volume for liquidity
          dividendYieldMinCtl.text = '3';
          volumeMinCtl.text = '1000000';
          break;
        case 'growth':
          screenerPeMin = 20;
          screenerMarketCapMin = 2000000000; // $2B+
          screenerVolumeMin = 500000; // 500K+ volume
          peMinCtl.text = '20';
          marketCapMinCtl.text = '2000000000';
          volumeMinCtl.text = '500000';
          break;
        case 'value':
          screenerPeMax = 15;
          screenerDividendYieldMin = 2;
          screenerPriceMin = 5; // Avoid penny stocks
          peMaxCtl.text = '15';
          dividendYieldMinCtl.text = '2';
          priceMinCtl.text = '5';
          break;
        case 'largecap':
          screenerMarketCapMin = 10000000000; // $10B+
          screenerVolumeMin = 1000000; // 1M+ volume
          marketCapMinCtl.text = '10000000000';
          volumeMinCtl.text = '1000000';
          break;
      }
    });
  }

  List<Instrument> _sortScreenerResults(List<Instrument> results) {
    final sorted = List<Instrument>.from(results);

    switch (screenerSortBy) {
      case 'marketCap':
        sorted.sort((a, b) {
          final aVal = a.fundamentalsObj?.marketCap ?? 0;
          final bVal = b.fundamentalsObj?.marketCap ?? 0;
          return bVal.compareTo(aVal); // Descending
        });
        break;
      case 'pe':
        sorted.sort((a, b) {
          final aVal = a.fundamentalsObj?.peRatio ?? double.infinity;
          final bVal = b.fundamentalsObj?.peRatio ?? double.infinity;
          return aVal.compareTo(bVal); // Ascending
        });
        break;
      case 'dividend':
        sorted.sort((a, b) {
          final aVal = a.fundamentalsObj?.dividendYield ?? 0;
          final bVal = b.fundamentalsObj?.dividendYield ?? 0;
          return bVal.compareTo(aVal); // Descending
        });
        break;
      case 'price':
        sorted.sort((a, b) {
          final aVal = a.quoteObj?.lastTradePrice ?? 0;
          final bVal = b.quoteObj?.lastTradePrice ?? 0;
          return bVal.compareTo(aVal); // Descending
        });
        break;
      case 'volume':
        sorted.sort((a, b) {
          final aVal = a.fundamentalsObj?.averageVolume ?? 0;
          final bVal = b.fundamentalsObj?.averageVolume ?? 0;
          return bVal.compareTo(aVal); // Descending
        });
        break;
      case 'symbol':
      default:
        sorted.sort((a, b) => a.symbol.compareTo(b.symbol));
        break;
    }

    return sorted;
  }

  void _fetchTradeSignalsWithFilters() {
    final tradeSignalsProvider =
        Provider.of<TradeSignalsProvider>(context, listen: false);
    tradeSignalsProvider.fetchAllTradeSignals(
      signalType: tradeSignalFilter,
      indicators: selectedIndicators.isEmpty ? null : selectedIndicators,
      startDate: tradeSignalStartDate,
      endDate: tradeSignalEndDate,
      limit: tradeSignalLimit,
    );
  }

  Widget _buildTradeSignalFilterChips() {
    final indicatorOptions = [
      'priceMovement',
      'momentum',
      'marketDirection',
      'volume',
      'macd',
      'bollingerBands',
      'stochastic',
      'atr',
      'obv',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // FilterChip(
          //   label: const Text('All'),
          //   selected: tradeSignalFilter == null,
          //   onSelected: (selected) {
          //     if (tradeSignalFilter != null) {
          //       setState(() {
          //         tradeSignalFilter = null;
          //       });
          //       _fetchTradeSignalsWithFilters();
          //     }
          //   },
          // ),
          // const SizedBox(width: 8),
          FilterChip(
            label: const Text('BUY'),
            selected: tradeSignalFilter == 'BUY',
            onSelected: (selected) {
              setState(() {
                tradeSignalFilter = selected ? 'BUY' : null;
              });
              _fetchTradeSignalsWithFilters();
            },
            backgroundColor: Colors.transparent,
            selectedColor: Colors.green.withOpacity(0.2),
            side: BorderSide(
              color: tradeSignalFilter == 'BUY'
                  ? Colors.green.shade400
                  : Colors.grey.shade300,
              width: tradeSignalFilter == 'BUY' ? 1.5 : 1,
            ),
            checkmarkColor: Colors.green.shade700,
            labelStyle: TextStyle(
              color: tradeSignalFilter == 'BUY'
                  ? Colors.green.shade700
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: tradeSignalFilter == 'BUY'
                  ? FontWeight.w600
                  : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('SELL'),
            selected: tradeSignalFilter == 'SELL',
            onSelected: (selected) {
              setState(() {
                tradeSignalFilter = selected ? 'SELL' : null;
              });
              _fetchTradeSignalsWithFilters();
            },
            backgroundColor: Colors.transparent,
            selectedColor: Colors.red.withOpacity(0.2),
            side: BorderSide(
              color: tradeSignalFilter == 'SELL'
                  ? Colors.red.shade400
                  : Colors.grey.shade300,
              width: tradeSignalFilter == 'SELL' ? 1.5 : 1,
            ),
            checkmarkColor: Colors.red.shade700,
            labelStyle: TextStyle(
              color: tradeSignalFilter == 'SELL'
                  ? Colors.red.shade700
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: tradeSignalFilter == 'SELL'
                  ? FontWeight.w600
                  : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('HOLD'),
            selected: tradeSignalFilter == 'HOLD',
            onSelected: (selected) {
              setState(() {
                tradeSignalFilter = selected ? 'HOLD' : null;
              });
              _fetchTradeSignalsWithFilters();
            },
            backgroundColor: Colors.transparent,
            selectedColor: Colors.grey.withOpacity(0.2),
            side: BorderSide(
              color: tradeSignalFilter == 'HOLD'
                  ? Theme.of(context).colorScheme.outlineVariant
                  : Colors.grey.shade300,
              width: tradeSignalFilter == 'HOLD' ? 1.5 : 1,
            ),
            checkmarkColor: Theme.of(context).colorScheme.onSurface,
            labelStyle: TextStyle(
              color: tradeSignalFilter == 'HOLD'
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: tradeSignalFilter == 'HOLD'
                  ? FontWeight.w600
                  : FontWeight.w500,
            ),
          ),
          // const SizedBox(width: 8),
          // IconButton(
          //   icon: const Icon(Icons.refresh),
          //   tooltip: 'Refresh',
          //   onPressed: _fetchTradeSignalsWithFilters,
          //   iconSize: 20,
          // ),
          const SizedBox(width: 8),
          Text('•',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outlineVariant)),
          const SizedBox(width: 8),
          // Indicator chips
          ...indicatorOptions.map((indicator) {
            final indicatorLabel = indicator == 'priceMovement'
                ? 'Price'
                : indicator == 'marketDirection'
                    ? 'Market'
                    : indicator == 'bollingerBands'
                        ? 'Bollinger'
                        : indicator[0].toUpperCase() + indicator.substring(1);

            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: FilterChip(
                label: Text(indicatorLabel),
                selected: selectedIndicators.contains(indicator),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      selectedIndicators.add(indicator);
                    } else {
                      selectedIndicators.remove(indicator);
                    }
                  });
                  _fetchTradeSignalsWithFilters();
                },
                backgroundColor: Colors.transparent,
                selectedColor: Colors.blue.withOpacity(0.15),
                side: BorderSide(
                  color: selectedIndicators.contains(indicator)
                      ? Colors.blue.shade400
                      : Colors.grey.shade300,
                  width: selectedIndicators.contains(indicator) ? 1.5 : 1,
                ),
                labelStyle: TextStyle(
                  color: selectedIndicators.contains(indicator)
                      ? Colors.blue.shade700
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: selectedIndicators.contains(indicator)
                      ? FontWeight.w600
                      : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Formats signal timestamp as "x ago" for recent signals or date for older ones.
  /// Recent signals (within 24 hours) show relative time (e.g., "5 mins ago").
  /// Older signals show the formatted date (e.g., "Dec 5, 2024").
  String _formatSignalTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    // If signal is recent (within 24 hours), show "x ago" format
    if (difference.inHours < 24) {
      if (difference.inMinutes < 1) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        final mins = difference.inMinutes;
        return '$mins min${mins != 1 ? 's' : ''} ago';
      } else {
        final hours = difference.inHours;
        return '$hours hour${hours != 1 ? 's' : ''} ago';
      }
    } else {
      // For older signals, show the date
      return formatDate.format(timestamp);
    }
  }
}
