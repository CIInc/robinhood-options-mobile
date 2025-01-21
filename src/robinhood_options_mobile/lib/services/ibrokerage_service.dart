import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/forex_historicals.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/model/midlands_movers_item.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/option_event.dart';
import 'package:robinhood_options_mobile/model/option_event_store.dart';
import 'package:robinhood_options_mobile/model/option_historicals.dart';
import 'package:robinhood_options_mobile/model/option_historicals_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/watchlist.dart';

abstract class IBrokerageService {
  late String name;
  late Uri endpoint;
  late Uri authEndpoint;
  late Uri tokenEndpoint;
  late String clientId;
  late String redirectUrl;

  Future<UserInfo?> getUser(BrokerageUser user);
  Future<List<Account>> getAccounts(BrokerageUser user, AccountStore store,
      PortfolioStore? portfolioStore, OptionPositionStore? optionPositionStore,
      {InstrumentPositionStore? instrumentPositionStore});
  Future<List<Portfolio>> getPortfolios(
      BrokerageUser user, PortfolioStore store);

  // Stocks
  Future<InstrumentPositionStore> getStockPositionStore(
      BrokerageUser user,
      InstrumentPositionStore store,
      InstrumentStore instrumentStore,
      QuoteStore quoteStore,
      {bool nonzero = true});

  // Forex
  Future<List<ForexHolding>> getNummusHoldings(
      BrokerageUser user, ForexHoldingStore store,
      {bool nonzero = true});
  Future<List<ForexHolding>> refreshNummusHoldings(
      BrokerageUser user, ForexHoldingStore store);
  Future<ForexQuote> getForexQuote(BrokerageUser user, String id);
  Future<List<ForexQuote>> getForexQuoteByIds(
      BrokerageUser user, List<String> ids);

  // Options
  Future<OptionPositionStore> getOptionPositionStore(BrokerageUser user,
      OptionPositionStore store, InstrumentStore instrumentStore,
      {bool nonzero = true});
  Future<List<OptionAggregatePosition>> getAggregateOptionPositions(
      BrokerageUser user,
      {bool nonzero = true});
  Stream<List<OptionInstrument>> streamOptionInstruments(
      BrokerageUser user,
      OptionInstrumentStore store,
      Instrument instrument,
      String? expirationDates, // 2021-03-05
      String? type, // call or put
      {String? state = "active"});
  Future<List<OptionInstrument>> getOptionInstrumentByIds(
      BrokerageUser user, List<String> ids);
  Future<OptionMarketData?> getOptionMarketData(
      BrokerageUser user, OptionInstrument optionInstrument);
  Future<List<OptionMarketData>> getOptionMarketDataByIds(
      BrokerageUser user, List<String> ids);
  Future<List<OptionAggregatePosition>> refreshOptionMarketData(
      BrokerageUser user,
      OptionPositionStore optionPositionStore,
      OptionInstrumentStore optionInstrumentStore);
  Future<List<OptionEvent>> getOptionEventsByInstrumentUrl(
      BrokerageUser user, String instrumentUrl);
  Stream<List<OptionEvent>> streamOptionEvents(
      BrokerageUser user, OptionEventStore store,
      {int pageSize = 20});

  Future<List<OptionChain>> getOptionChainsByIds(
      BrokerageUser user, List<String> ids);
  Future<OptionChain> getOptionChains(BrokerageUser user, String id);

  // Instruments
  Future<Instrument> getInstrument(
      BrokerageUser user, InstrumentStore store, String instrumentUrl);
  Future<Instrument?> getInstrumentBySymbol(
      BrokerageUser user, InstrumentStore store, String symbol);
  Future<List<Instrument>> getInstrumentsByIds(
      BrokerageUser user, InstrumentStore store, List<String> ids);

  // Quotes
  Future<List<Quote>> getQuoteByIds(
      BrokerageUser user, QuoteStore store, List<String> symbols,
      {bool fromCache = true});
  Future<Quote> getQuote(BrokerageUser user, QuoteStore store, String symbol);
  Future<Quote> refreshQuote(
      BrokerageUser user, QuoteStore store, String symbol);
  Future<List<InstrumentPosition>> refreshPositionQuote(
      BrokerageUser user, InstrumentPositionStore store, QuoteStore quoteStore);

  // Fundamentals
  Future<List<Fundamentals>> getFundamentalsById(
      BrokerageUser user, List<String> instruments, InstrumentStore store);
  Future<Fundamentals> getFundamentals(
      BrokerageUser user, Instrument instrumentObj);

  // Historicals
  Future<PortfolioHistoricals> getPortfolioHistoricals(
      BrokerageUser user,
      PortfolioHistoricalsStore store,
      String account,
      Bounds chartBoundsFilter,
      ChartDateSpan chartDateSpanFilter);
  Future<OptionHistoricals> getOptionHistoricals(
      BrokerageUser user, OptionHistoricalsStore store, List<String> ids,
      {Bounds chartBoundsFilter = Bounds.regular,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day});
  Future<InstrumentHistoricals> getInstrumentHistoricals(BrokerageUser user,
      InstrumentHistoricalsStore store, String symbolOrInstrumentId,
      {bool includeInactive = true,
      Bounds chartBoundsFilter = Bounds.trading,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day,
      String? chartInterval});
  Future<ForexHistoricals> getForexHistoricals(BrokerageUser user, String id,
      {Bounds chartBoundsFilter = Bounds.t24_7,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day});

  // Dividends & Interests
  Stream<List<dynamic>> streamDividends(
      BrokerageUser user, InstrumentStore instrumentStore);
  Future<List<dynamic>> getDividends(
      BrokerageUser user, DividendStore dividendStore,
      {String? instrumentId});
  Stream<List<dynamic>> streamInterests(
      BrokerageUser user, InstrumentStore instrumentStore);
  Future<List<dynamic>> getInterests(
      BrokerageUser user, InterestStore dividendStore,
      {String? instrumentId});

  // News, etc
  Future<List<dynamic>> getNews(BrokerageUser user, String symbol);
  Future<dynamic> getRatings(BrokerageUser user, String instrumentId);
  Future<dynamic> getRatingsOverview(BrokerageUser user, String instrumentId);
  Future<List<dynamic>> getEarnings(BrokerageUser user, String instrumentId);
  Future<List<dynamic>> getSimilar(BrokerageUser user, String instrumentId);
  Future<List<dynamic>> getSplits(BrokerageUser user, Instrument instrumentObj);

  // Search
  Future<dynamic> search(BrokerageUser user, String query);

  Future<List<MidlandMoversItem>> getMovers(BrokerageUser user,
      {String direction = "up"});
  Future<List<Instrument>> getListMovers(
      BrokerageUser user, InstrumentStore instrumentStore);
  Future<List<Instrument>> getListMostPopular(
      BrokerageUser user, InstrumentStore instrumentStore);

  // Lists
  Stream<List<Watchlist>> streamLists(BrokerageUser user,
      InstrumentStore instrumentStore, QuoteStore quoteStore);
  Future<List<dynamic>> getLists(BrokerageUser user, String instrumentId);
  Stream<Watchlist> streamList(BrokerageUser user,
      InstrumentStore instrumentStore, QuoteStore quoteStore, String key,
      {String ownerType = "custom"});
  Future<Watchlist> getList(String key, BrokerageUser user,
      {String ownerType = "custom"});

  // Orders
  Stream<List<InstrumentOrder>> streamPositionOrders(BrokerageUser user,
      InstrumentOrderStore store, InstrumentStore instrumentStore);
  Stream<List<OptionOrder>> streamOptionOrders(
      BrokerageUser user, OptionOrderStore store);
  Future<List<OptionOrder>> getOptionOrders(
      BrokerageUser user, OptionOrderStore store, String chainId);
  Future<List<InstrumentOrder>> getInstrumentOrders(BrokerageUser user,
      InstrumentOrderStore store, List<String> instrumentUrls);

  Future<dynamic> placeInstrumentOrder(
      BrokerageUser user,
      Account account,
      Instrument instrument,
      String symbol, // Ticker of the stock to trade.
      String side, // Either 'buy' or 'sell'
      double price, // Limit price to trigger a buy of the option.
      int quantity, // Number of options to buy.
      {String type = 'limit', // market
      String trigger = 'immediate', // stop
      String timeInForce =
          'gtc' // How long order will be in effect. 'gtc' = good until cancelled. 'gfd' = good for the day. 'ioc' = immediate or cancel. 'opg' execute at opening.
      });
  Future<dynamic> placeOptionsOrder(
      BrokerageUser user,
      Account account,
      //Instrument instrument,
      OptionInstrument optionInstrument,
      String side, // Either 'buy' or 'sell'
      String
          positionEffect, // Either 'open' for a buy to open effect or 'close' for a buy to close effect.
      String creditOrDebit, // Either 'debit' or 'credit'.
      double price, // Limit price to trigger a buy of the option.
      //String symbol, // Ticker of the stock to trade.
      int quantity, // Number of options to buy.
      //String expirationDate, // Expiration date of the option in 'YYYY-MM-DD' format.
      //double strike, // The strike price of the option.
      //String optionType, // This should be 'call' or 'put'
      {String type = 'limit', // market
      String trigger = 'immediate',
      String timeInForce =
          'gtc' // How long order will be in effect. 'gtc' = good until cancelled. 'gfd' = good for the day. 'ioc' = immediate or cancel. 'opg' execute at opening.
      });
}
