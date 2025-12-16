import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

class PresetsWidget extends StatefulWidget {
  final User? user;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  final DocumentReference<User>? userDocRef;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  const PresetsWidget(
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
  State<PresetsWidget> createState() => _PresetsWidgetState();
}

class _PresetsWidgetState extends State<PresetsWidget> {
  late YahooService yahooService;
  ScreenerId? selectedYahooScreener;
  dynamic yahooScreenerResults;
  bool yahooScreenerLoading = false;
  String? yahooScreenerError;

  @override
  void initState() {
    super.initState();
    yahooService = YahooService();
    widget.analytics.logScreenView(screenName: 'Presets');
  }

  @override
  void dispose() {
    yahooService.httpClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presets'),
      ),
      body: CustomScrollView(
        slivers: [
          _buildYahooScreenerSliver(),
        ],
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
        ],
      ),
    );
  }
}
