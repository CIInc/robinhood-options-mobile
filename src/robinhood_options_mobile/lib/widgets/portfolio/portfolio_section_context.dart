import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/portfolio_analytics_controller.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

/// The dependency bundle every Portfolio section page needs.
///
/// The six sections all require the same brokerage handles, Firebase plumbing,
/// and historicals futures. Passing one object keeps their constructors honest
/// and means adding a dependency touches one file instead of six.
class PortfolioSectionContext {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;
  final User? appUser;
  final DocumentReference<User>? userDocRef;

  /// Shared across the sections so the metrics are computed once. Owned by the
  /// Portfolio page, which rebuilds it when the account or period changes.
  final PortfolioAnalyticsController analyticsController;

  final Account? account;

  /// Null while viewing all linked brokerages at once.
  final String? accountNumber;
  final bool isAggregateMode;

  final Future<PortfolioHistoricals>? portfolioHistoricalsFuture;
  final Future<dynamic>? futureMarketIndexHistoricalsSp500;
  final Future<dynamic>? futureMarketIndexHistoricalsNasdaq;
  final Future<dynamic>? futureMarketIndexHistoricalsDow;
  final Future<dynamic>? futureMarketIndexHistoricalsRussell2000;
  final ChartDateSpan? benchmarkChartDateSpanFilter;
  final void Function(ChartDateSpan)? onBenchmarkFilterChanged;

  const PortfolioSectionContext({
    required this.brokerageUser,
    required this.service,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    required this.appUser,
    required this.userDocRef,
    required this.analyticsController,
    this.account,
    this.accountNumber,
    this.isAggregateMode = false,
    this.portfolioHistoricalsFuture,
    this.futureMarketIndexHistoricalsSp500,
    this.futureMarketIndexHistoricalsNasdaq,
    this.futureMarketIndexHistoricalsDow,
    this.futureMarketIndexHistoricalsRussell2000,
    this.benchmarkChartDateSpanFilter,
    this.onBenchmarkFilterChanged,
  });
}
