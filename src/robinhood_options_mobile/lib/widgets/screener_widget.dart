import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

class ScreenerWidget extends StatefulWidget {
  final User? user;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  final DocumentReference<User>? userDocRef;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  const ScreenerWidget(
    this.brokerageUser,
    this.service, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    required this.user,
    required this.userDocRef,
  });

  @override
  State<ScreenerWidget> createState() => _ScreenerWidgetState();
}

class _ScreenerWidgetState extends State<ScreenerWidget> {
  final FirestoreService _firestoreService = FirestoreService();

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

  @override
  void initState() {
    super.initState();
    marketCapMinCtl = TextEditingController();
    marketCapMaxCtl = TextEditingController();
    peMinCtl = TextEditingController();
    peMaxCtl = TextEditingController();
    dividendYieldMinCtl = TextEditingController();
    dividendYieldMaxCtl = TextEditingController();
    priceMinCtl = TextEditingController();
    priceMaxCtl = TextEditingController();
    volumeMinCtl = TextEditingController();
    widget.analytics.logScreenView(screenName: 'Screener');
  }

  @override
  void dispose() {
    marketCapMinCtl.dispose();
    marketCapMaxCtl.dispose();
    peMinCtl.dispose();
    peMaxCtl.dispose();
    dividendYieldMinCtl.dispose();
    dividendYieldMaxCtl.dispose();
    priceMinCtl.dispose();
    priceMaxCtl.dispose();
    volumeMinCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Screener'),
      ),
      body: CustomScrollView(
        slivers: [
          _buildScreenerSliver(),
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
                      ? 'Results (${screenerResults!.length})'
                      : 'Filters',
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
                childAspectRatio: 1.168,
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
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          Text(instrumentObj.fundamentalsObj?.description ?? '',
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
                  ],
                )),
            onTap: () {
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
}
