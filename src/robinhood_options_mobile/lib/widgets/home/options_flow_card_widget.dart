import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/options_flow_widget.dart';

class OptionsFlowCardWidget extends StatelessWidget {
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final FirebaseAnalytics? analytics;
  final FirebaseAnalyticsObserver? observer;
  final GenerativeService? generativeService;
  final User? user;
  final DocumentReference<User>? userDocRef;
  final bool includePortfolioSymbols;

  const OptionsFlowCardWidget({
    super.key,
    this.brokerageUser,
    this.service,
    this.analytics,
    this.observer,
    this.generativeService,
    this.user,
    this.userDocRef,
    this.includePortfolioSymbols = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 0,
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            List<String>? portfolioSymbols;
            if (includePortfolioSymbols) {
              final instrumentPositionStore =
                  context.read<InstrumentPositionStore>();
              final optionPositionStore = context.read<OptionPositionStore>();
              portfolioSymbols = {
                ...instrumentPositionStore.symbols,
                ...optionPositionStore.symbols
              }.toList();
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OptionsFlowWidget(
                  brokerageUser: brokerageUser,
                  service: service,
                  analytics: analytics,
                  observer: observer,
                  generativeService: generativeService,
                  user: user,
                  userDocRef: userDocRef,
                  initialSymbols: portfolioSymbols,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.water_rounded,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            includePortfolioSymbols
                                ? 'Portfolio Flow Analysis'
                                : 'Options Flow Analysis',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            includePortfolioSymbols
                                ? 'Track sentiment for your positions'
                                : 'Track institutional sentiment & sweeps',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
