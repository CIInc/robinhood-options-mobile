import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
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
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';

final formatDate = DateFormat("yMMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

class SearchWidget extends StatefulWidget {
  final User? user;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;

  const SearchWidget(
    this.brokerageUser,
    this.service, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    this.navigatorKey,
    this.user,
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
  String? tradeSignalFilter;      // null = all, 'BUY', 'SELL', 'HOLD'
  DateTime? tradeSignalStartDate;
  DateTime? tradeSignalEndDate;
  int tradeSignalLimit = 50;      // Default limit

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
      final agenticTradingProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      agenticTradingProvider.fetchAllTradeSignals();
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
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetButton(
                  'High Dividend', () => _applyPreset('dividend')),
              _buildPresetButton('Growth Stocks', () => _applyPreset('growth')),
              _buildPresetButton('Value Stocks', () => _applyPreset('value')),
              _buildPresetButton('Large Cap', () => _applyPreset('largecap')),
              OutlinedButton.icon(
                onPressed: () => _applyPreset('clear'),
                icon: Icon(Icons.clear_all, size: 16),
                label: Text('Clear All', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: BorderSide(color: Colors.grey),
                  foregroundColor: Colors.grey,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: screenerSector,
            items: sectors
                .map((s) => DropdownMenuItem(
                      value: s == 'All' ? null : s,
                      child: Text(s),
                    ))
                .toList(),
            decoration: InputDecoration(labelText: 'Sector'),
            onChanged: (v) => setState(() => screenerSector = v),
          ),
          SizedBox(height: 12),
          Text('Market Cap',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickFilterChip('Micro (<\$300M)', () {
                setState(() {
                  screenerMarketCapMin = null;
                  screenerMarketCapMax = 300000000;
                  marketCapMinCtl.clear();
                  marketCapMaxCtl.text = '300000000';
                });
              }),
              _buildQuickFilterChip('Small (\$300M-\$2B)', () {
                setState(() {
                  screenerMarketCapMin = 300000000;
                  screenerMarketCapMax = 2000000000;
                  marketCapMinCtl.text = '300000000';
                  marketCapMaxCtl.text = '2000000000';
                });
              }),
              _buildQuickFilterChip('Mid (\$2B-\$10B)', () {
                setState(() {
                  screenerMarketCapMin = 2000000000;
                  screenerMarketCapMax = 10000000000;
                  marketCapMinCtl.text = '2000000000';
                  marketCapMaxCtl.text = '10000000000';
                });
              }),
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
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => screenerMarketCapMax = int.tryParse(v)),
              ),
            ),
          ]),
          SizedBox(height: 12),
          Text('P/E Ratio',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text('Value: <15, Growth: >20',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
          SizedBox(height: 4),
          Row(children: [
            Flexible(
              child: TextField(
                controller: peMinCtl,
                decoration: InputDecoration(
                  labelText: 'Min',
                  hintText: '10',
                  isDense: true,
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
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    setState(() => screenerPeMax = int.tryParse(v)),
              ),
            ),
          ]),
          SizedBox(height: 12),
          Text('Dividend Yield (%)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text('High dividend: >3%',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    setState(() => screenerDividendYieldMax = int.tryParse(v)),
              ),
            ),
          ]),
          SizedBox(height: 12),
          Text('Price Range (\$)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    setState(() => screenerPriceMax = double.tryParse(v)),
              ),
            ),
          ]),
          SizedBox(height: 12),
          Text('Volume',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text('Minimum average daily volume',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
          SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickFilterChip('Low (100K+)', () {
                setState(() {
                  screenerVolumeMin = 100000;
                  volumeMinCtl.text = '100000';
                });
              }),
              _buildQuickFilterChip('Med (500K+)', () {
                setState(() {
                  screenerVolumeMin = 500000;
                  volumeMinCtl.text = '500000';
                });
              }),
              _buildQuickFilterChip('High (1M+)', () {
                setState(() {
                  screenerVolumeMin = 1000000;
                  volumeMinCtl.text = '1000000';
                });
              }),
              _buildQuickFilterChip('Very High (5M+)', () {
                setState(() {
                  screenerVolumeMin = 5000000;
                  volumeMinCtl.text = '5000000';
                });
              }),
            ],
          ),
          SizedBox(height: 8),
          TextField(
            controller: volumeMinCtl,
            decoration: InputDecoration(
              labelText: 'Min Volume',
              hintText: '1000000',
              helperText: '1M = 1,000,000',
              isDense: true,
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
              ElevatedButton.icon(
                icon: Icon(Icons.search),
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
                            errorText = 'Price Min cannot be greater than Max.';
                          });
                          return;
                        }
                        setState(() {
                          screenerLoading = true;
                          errorText = null;
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
                label: Text('Run Screener'),
              ),
              if (screenerLoading) ...[
                SizedBox(width: 16),
                SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScreenerSliver() {
    if (screenerLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return SliverStickyHeader(
      header: Material(
        child: Container(
          alignment: Alignment.centerLeft,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  screenerResults != null && screenerResults!.isNotEmpty
                      ? 'Screener (${screenerResults!.length})'
                      : 'Screener',
                  style: TextStyle(fontSize: 19.0),
                ),
                trailing: screenerResults != null && screenerResults!.isNotEmpty
                    ? SizedBox(
                        width: 140,
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: screenerSortBy,
                          items: [
                            DropdownMenuItem(
                                value: 'symbol', child: Text('Symbol')),
                            DropdownMenuItem(
                                value: 'marketCap', child: Text('Market Cap')),
                            DropdownMenuItem(
                                value: 'pe', child: Text('P/E Ratio')),
                            DropdownMenuItem(
                                value: 'dividend', child: Text('Dividend')),
                            DropdownMenuItem(
                                value: 'price', child: Text('Price')),
                            DropdownMenuItem(
                                value: 'volume', child: Text('Volume')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => screenerSortBy = value);
                            }
                          },
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _buildScreenerPanel(),
          if (screenerResults != null && screenerResults!.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.all(8),
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150.0,
                mainAxisSpacing: 6.0,
                crossAxisSpacing: 2.0,
                childAspectRatio: 1.3,
              ),
              itemCount: screenerResults!.length,
              itemBuilder: (BuildContext context, int gridIndex) {
                final sortedResults = _sortScreenerResults(screenerResults!);
                return _buildListGridItem(
                    sortedResults, gridIndex, widget.brokerageUser);
              },
            )
          else if (screenerResults != null && screenerResults!.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No results found.',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildYahooScreenerSliver() {
    return SliverStickyHeader(
      header: Material(
        child: Container(
          alignment: Alignment.centerLeft,
          child: const ListTile(
            title: Text(
              "Presets",
              style: TextStyle(fontSize: 19.0),
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
            value: selectedYahooScreener,
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
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
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
                        padding: const EdgeInsets.symmetric(horizontal: 2),
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
                  Consumer<AgenticTradingProvider>(
                    builder: (context, agenticTradingProvider, child) {
                      final tradeSignals = agenticTradingProvider.tradeSignals;
                      return SliverStickyHeader(
                          header: Material(
                              //elevation: 2,
                              child: Container(
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const ListTile(
                                        title: Wrap(children: [
                                          Text(
                                            "Trade Signals",
                                            style: TextStyle(fontSize: 19.0),
                                          ),
                                        ]),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                        child: _buildTradeSignalFilterChips(),
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
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : SliverPadding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 2),
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
                            //elevation: 2,
                            child: Container(
                                alignment: Alignment.centerLeft,
                                child: const ListTile(
                                  title: Wrap(children: [
                                    Text(
                                      "S&P Movers",
                                      style: TextStyle(fontSize: 19.0),
                                    ),
                                    Icon(Icons.trending_up,
                                        color: Colors.green, size: 28)
                                  ]),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
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
                            //elevation: 2,
                            child: Container(
                                alignment: Alignment.centerLeft,
                                child: const ListTile(
                                  title: Wrap(children: [
                                    Text(
                                      "S&P Movers",
                                      style: TextStyle(fontSize: 19.0),
                                    ),
                                    Icon(Icons.trending_down,
                                        color: Colors.red, size: 28)
                                  ]),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
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
                            //elevation: 2,
                            child: Container(
                                alignment: Alignment.centerLeft,
                                child: const ListTile(
                                  title: Wrap(children: [
                                    Text(
                                      "Top Movers",
                                      style: TextStyle(fontSize: 19.0),
                                    ),
                                  ]),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 150.0,
                                mainAxisSpacing: 6.0,
                                crossAxisSpacing: 2.0,
                                childAspectRatio: 1.35,
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
                            //elevation: 2,
                            child: Container(
                                alignment: Alignment.centerLeft,
                                child: const ListTile(
                                  title: Wrap(children: [
                                    Text(
                                      "100 Most Popular",
                                      style: TextStyle(fontSize: 19.0),
                                    ),
                                  ]),
                                ))),
                        sliver: SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 150.0,
                                mainAxisSpacing: 6.0,
                                crossAxisSpacing: 2.0,
                                childAspectRatio: 1.22,
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
    final agenticTradingProvider =
        Provider.of<AgenticTradingProvider>(context, listen: false);
    await agenticTradingProvider.fetchAllTradeSignals();
  }

  Widget _buildMoversGridItem(List<MidlandMoversItem> movers, int index) {
    final isPositive = movers[index].marketHoursPriceMovement! > 0;
    final isNegative = movers[index].marketHoursPriceMovement! < 0;
    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: InkWell(
            borderRadius: BorderRadius.circular(12.0),
            child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(movers[index].symbol,
                          style: const TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
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
                      const SizedBox(height: 4),
                      Text(
                          formatCurrency
                              .format(movers[index].marketHoursLastPrice),
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w500,
                          )),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(movers[index].description,
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Colors.grey.shade600,
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
                          )));
            }));
  }

  Widget _buildSearchGridItem(dynamic search, int index) {
    var data = search["results"][0]["content"]["data"][index];
    return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: InkWell(
            borderRadius: BorderRadius.circular(8.0),
            child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        data["item"]["symbol"],
                        style: const TextStyle(
                          fontSize: 17.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          data["item"]["simple_name"] ?? data["item"]["name"],
                          style: TextStyle(
                            fontSize: 12.0,
                            color: Colors.grey.shade700,
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
    final signalType = signal['signal'] ?? 'HOLD';
    final reason = signal['reason'] ?? 'No reason provided';
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
                      Text(formatDate.format(timestamp),
                          style: TextStyle(
                              fontSize: 12.0, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(reason,
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis),
                      ),
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
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: InkWell(
            borderRadius: BorderRadius.circular(10.0),
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Symbol - always shown
                    Text(
                      instrumentObj.symbol,
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Current Price
                    if (lastTradePrice != null) ...[
                      Text(
                        formatCurrency.format(lastTradePrice),
                        style: const TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
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
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              formatPercentage.format(changePercentToday.abs()),
                              style: TextStyle(
                                fontSize: 14.0,
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
                      const Text(
                        'No quote data',
                        style: TextStyle(fontSize: 12.0, color: Colors.grey),
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
                          )));
            }));
  }

  Widget _buildQuickFilterChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: Colors.blue.withOpacity(0.1),
      labelStyle: TextStyle(color: Colors.blue),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }

  Widget _buildPresetButton(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: Colors.blue),
      ),
      child: Text(label, style: TextStyle(fontSize: 13)),
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
    final agenticTradingProvider =
        Provider.of<AgenticTradingProvider>(context, listen: false);
    agenticTradingProvider.fetchAllTradeSignals(
      signalType: tradeSignalFilter,
      startDate: tradeSignalStartDate,
      endDate: tradeSignalEndDate,
      limit: tradeSignalLimit,
    );
  }

  Widget _buildTradeSignalFilterChips() {
    final agenticTradingProvider =
        Provider.of<AgenticTradingProvider>(context, listen: false);
    final isMarketOpen = agenticTradingProvider.isMarketOpen;

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        // Market status indicator chip
        Chip(
          avatar: Icon(
            isMarketOpen ? Icons.access_time : Icons.calendar_today,
            size: 18,
            color: isMarketOpen ? Colors.green.shade700 : Colors.blue.shade700,
          ),
          label: Text(
            isMarketOpen ? 'Market Hours: Intraday' : 'After Hours: Daily',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isMarketOpen ? Colors.green.shade700 : Colors.blue.shade700,
            ),
          ),
          backgroundColor: isMarketOpen
              ? Colors.green.withOpacity(0.1)
              : Colors.blue.withOpacity(0.1),
          side: BorderSide(
            color: isMarketOpen ? Colors.green.shade300 : Colors.blue.shade300,
            width: 1,
          ),
        ),
        FilterChip(
          label: const Text('All'),
          selected: tradeSignalFilter == null,
          onSelected: (selected) {
            if (tradeSignalFilter != null) {
              setState(() {
                tradeSignalFilter = null;
              });
              _fetchTradeSignalsWithFilters();
            }
          },
        ),
        FilterChip(
          label: const Text('BUY'),
          selected: tradeSignalFilter == 'BUY',
          onSelected: (selected) {
            setState(() {
              tradeSignalFilter = selected ? 'BUY' : null;
            });
            _fetchTradeSignalsWithFilters();
          },
          selectedColor: Colors.green.withOpacity(0.3),
          checkmarkColor: Colors.green,
        ),
        FilterChip(
          label: const Text('SELL'),
          selected: tradeSignalFilter == 'SELL',
          onSelected: (selected) {
            setState(() {
              tradeSignalFilter = selected ? 'SELL' : null;
            });
            _fetchTradeSignalsWithFilters();
          },
          selectedColor: Colors.red.withOpacity(0.3),
          checkmarkColor: Colors.red,
        ),
        FilterChip(
          label: const Text('HOLD'),
          selected: tradeSignalFilter == 'HOLD',
          onSelected: (selected) {
            setState(() {
              tradeSignalFilter = selected ? 'HOLD' : null;
            });
            _fetchTradeSignalsWithFilters();
          },
          selectedColor: Colors.grey.withOpacity(0.3),
          checkmarkColor: Colors.grey,
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _fetchTradeSignalsWithFilters,
          iconSize: 20,
        ),
      ],
    );
  }
}
