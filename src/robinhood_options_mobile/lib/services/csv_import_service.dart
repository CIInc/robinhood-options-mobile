import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';

class CsvImportService {
  static Future<void> importFidelityCsv(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        String? path = result.files.single.path;
        if (path == null) return;

        File file = File(path);
        // Fidelity CSVs can be funky encoded, but let's try utf8 first
        final input = file.openRead();
        final fields = await input
            .transform(utf8.decoder)
            .transform(const CsvToListConverter())
            .toList();

        if (fields.isEmpty) return;

        // Verify headers
        // Header row index might vary if there is junk at top, usually row 0
        // Fidelity CSV usually starts with headers at row 0 or 1.
        List<dynamic> headers = [];
        Map<String, int> headerMap = {};
        int dataStartRow = 1;

        // Find header row logic
        for (int i = 0; i < fields.length; i++) {
          List<dynamic> row = fields[i];
          // History file: Run Date starting at row 0 or 1
          if (row.isNotEmpty && row[0].toString() == 'Run Date') {
            headers = row;
            headerMap = {
              for (var j = 0; j < headers.length; j++)
                headers[j].toString().trim(): j
            };
            dataStartRow = i + 1;
            break;
          }
          // Positions file: Account Number usually at index 0
          if (row.isNotEmpty && row[0].toString() == 'Account Number') {
            headers = row;
            headerMap = {
              for (var j = 0; j < headers.length; j++)
                headers[j].toString().trim(): j
            };
            dataStartRow = i + 1;
            break;
          }
        }

        if (headerMap.isEmpty) {
          // Fallback to row 0 (or error out if strict)
          if (fields.isNotEmpty) {
            headers = fields.first;
            headerMap = {
              for (var i = 0; i < headers.length; i++)
                headers[i].toString().trim(): i
            };
          }
        }

        // Detect File Type
        if (headerMap.containsKey('Run Date') &&
            headerMap.containsKey('Action')) {
          _importHistory(context, fields, headerMap, dataStartRow);
          return;
        }

        if (!headerMap.containsKey('Symbol') ||
            !headerMap.containsKey('Quantity') ||
            !headerMap.containsKey('Average Cost Basis')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Invalid CSV format - missing required columns')),
          );
          return;
        }

        int importedStocks = 0;
        int importedOptions = 0;

        // Skip header
        for (int i = dataStartRow; i < fields.length; i++) {
          List<dynamic> row = fields[i];
          if (row.isEmpty) continue;

          // Check for disclaimer rows
          if (row.length < headerMap.length ||
              row[0].toString().isEmpty ||
              row[0].toString().contains('The data')) {
            continue;
          }

          String symbol = row[headerMap['Symbol']!].toString().trim();
          var quantityStr = row[headerMap['Quantity']!].toString();
          if (quantityStr.isEmpty) continue;

          double quantity = double.tryParse(quantityStr) ?? 0;

          String costBasisStr =
              _cleanCurrency(row[headerMap['Average Cost Basis']!].toString());
          double averageCost = double.tryParse(costBasisStr) ?? 0;

          // Last Price Parsing
          double lastPrice = 0;
          if (headerMap.containsKey('Last Price')) {
            String lpStr =
                _cleanCurrency(row[headerMap['Last Price']!].toString());
            lastPrice = double.tryParse(lpStr) ?? 0;
          }

          // Last Price Change Parsing (for previous close calculation)
          double lastPriceChange = 0;
          if (headerMap.containsKey('Last Price Change')) {
            String lpcStr =
                _cleanCurrency(row[headerMap['Last Price Change']!].toString());
            lastPriceChange = double.tryParse(lpcStr) ?? 0;
          }

          double previousClose = lastPrice - lastPriceChange;

          String cleanSymbol = symbol.trim();
          if (cleanSymbol.startsWith('-')) {
            // Remove leading hyphen for options
            cleanSymbol = cleanSymbol.substring(1);
          }

          // Regex for Fidelity Option: ^([A-Z]+)(\d{6})([CP])([\d\.]+)$
          RegExp optionRegex = RegExp(r'^([A-Z]+)(\d{6})([CP])([\d\.]+)$');
          Match? match = optionRegex.firstMatch(cleanSymbol);

          if (match != null) {
            importedOptions++;
            _importOption(context, cleanSymbol, match, quantity, averageCost,
                lastPrice, previousClose);
          } else {
            // Filter out Cash
            if (cleanSymbol.contains('**')) continue;

            importedStocks++;
            _importStock(context, cleanSymbol, quantity, averageCost, lastPrice,
                previousClose);
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Imported $importedStocks stocks and $importedOptions options.')),
        );
      }
    } catch (e) {
      debugPrint('Error importing CSV: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing CSV: $e')),
      );
    }
  }

  static String _cleanCurrency(String input) {
    return input.replaceAll('\$', '').replaceAll(',', '').replaceAll('+', '');
  }

  static void _importHistory(BuildContext context, List<List<dynamic>> fields,
      Map<String, int> headerMap, int dataStartRow) {
    int importedOrders = 0;

    for (int i = dataStartRow; i < fields.length; i++) {
      List<dynamic> row = fields[i];
      if (row.isEmpty) continue;
      if (row.length < headerMap.length) continue;

      // Columns: Run Date, Account, Account Number, Action, Symbol, Description, Type, Exchange Quantity, Exchange Currency, Currency, Price, Quantity, Exchange Rate, Commission, Fees, Accrued Interest, Amount, Settlement Date
      String action = row[headerMap['Action']!].toString();

      bool isTrade =
          action.contains('YOU BOUGHT') || action.contains('YOU SOLD');
      bool isDividend = action.contains('DIVIDEND RECEIVED');

      // Filter out non-trades
      // Note: "YOU BOUGHT ... (Cash)" contains 'Cash', so we can't just filter out 'Cash'
      if (!isTrade && !isDividend) {
        // Skip interest, transfers to focus on order history
        continue;
      }

      String symbol = row[headerMap['Symbol']!].toString().trim();
      if (symbol.isEmpty) continue;

      String dateStr = row[headerMap['Run Date']!].toString();
      DateTime? date;
      try {
        // Format: 01/28/2026
        List<String> parts = dateStr.split('/');
        if (parts.length == 3) {
          date = DateTime(
              int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
        }
      } catch (e) {/* ignore */}

      String quantityStr = row[headerMap['Quantity']!].toString();
      double quantity = double.tryParse(quantityStr) ?? 0;

      String priceStr = _cleanCurrency(row[headerMap['Price']!].toString());
      double price = double.tryParse(priceStr) ?? 0;

      String amountStr = _cleanCurrency(row[headerMap['Amount']!].toString());
      double amount = double.tryParse(amountStr) ?? 0;

      // Check if Option
      String cleanSymbol = symbol.trim();
      bool isOption = false;
      if (cleanSymbol.startsWith('-') || cleanSymbol.contains(RegExp(r'\d'))) {
        // Simple heuristic
        if (cleanSymbol.startsWith('-')) cleanSymbol = cleanSymbol.substring(1);
      }

      // Regex for Fidelity Option: ^([A-Z]+)(\d{6})([CP])([\d\.]+)$
      RegExp optionRegex = RegExp(r'^([A-Z]+)(\d{6})([CP])([\d\.]+)$');
      Match? match = optionRegex.firstMatch(cleanSymbol);

      if (match != null) {
        isOption = true;
      }

      if (isDividend) {
        _importDividend(context, cleanSymbol, date, amount);
      } else if (isOption && match != null) {
        _importOptionOrder(
            context, cleanSymbol, match, date, action, quantity, price, amount);
      } else {
        _importStockOrder(
            context, cleanSymbol, date, action, quantity, price, amount);
      }
      importedOrders++;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Imported $importedOrders transactions from history.')),
    );
  }

  static void _importDividend(
      BuildContext context, String symbol, DateTime? date, double amount) {
    var store = Provider.of<DividendStore>(context, listen: false);

    var dividend = {
      'id': 'manual_div_${symbol}_${date?.millisecondsSinceEpoch}',
      'account': 'manual_account',
      'instrument': 'manual_inst_$symbol',
      'amount': amount.toString(),
      'payable_date': date?.toIso8601String(),
      'paid_at': date?.toIso8601String(),
      'state': 'paid',
      'record_date': date?.toIso8601String(),
      'position': 'manual_pos_$symbol',
      'withholding': '0.00',
      'rate': '0.00',
    };
    store.add(dividend);
  }

  static void _importStockOrder(
      BuildContext context,
      String symbol,
      DateTime? date,
      String action,
      double quantity,
      double price,
      double amount) {
    var store = Provider.of<InstrumentOrderStore>(context, listen: false);

    String side = 'buy'; // Default
    if (action.contains('SOLD')) side = 'sell';
    if (action.contains('BOUGHT')) side = 'buy';

    // Calculate fees based on amount diff?
    // Amount = (Price * Quantity) - fees?
    // -5330 = 266.5 * 20. (Buy is negative amount).
    // If Amount is present, use it to calc fees?

    double fees = 0;
    double tradeVal = price * quantity.abs(); // 5330
    if (amount != 0) {
      // Buy: Amount = -(TradeVal + Fees) = -TradeVal - Fees.
      // Sell: Amount = TradeVal - Fees.
      if (side == 'buy') {
        // Amount is negative. -5330.
        // Fees = -Amount - TradeVal ? 5330 - 5330 = 0.
        fees = (-amount) - tradeVal;
      } else {
        // Sell. Amount positive.
        // Fees = TradeVal - Amount.
        fees = tradeVal - amount;
      }
    }

    InstrumentOrder order = InstrumentOrder(
        'manual_order_${symbol}_${date?.millisecondsSinceEpoch}', // id
        null, // refId
        'manual_url', // url
        'manual_account', // account
        'manual_pos_url', // position
        null, // cancel
        'manual_inst_url_$symbol', // instrument
        'manual_inst_id_$symbol', // instrumentId
        quantity.abs(), // cumulativeQuantity
        price, // averagePrice
        fees, // fees
        'filled', // state
        null, // pendingCancelOpenAgent
        'market', // type (unknown)
        side, // side
        'gfd', // timeInForce
        'immediate', // trigger
        price, // price
        null, // stopPrice
        quantity.abs(), // quantity
        null, // rejectReason
        date ?? DateTime.now(), // createdAt
        date ?? DateTime.now(), // updatedAt
        null // trailingPeg
        );

    // Create Dummy Instrument if needed?
    order.instrumentObj = Instrument(
        id: 'manual_$symbol',
        url: 'manual_inst_$symbol',
        quote: 'manual_quote_$symbol',
        fundamentals: 'manual_fundamentals_$symbol',
        splits: 'manual_splits_$symbol',
        state: 'active',
        market: 'manual_market_$symbol',
        name: symbol,
        tradeable: true,
        tradability: 'tradable',
        symbol: symbol,
        bloombergUnique: 'manual_$symbol',
        country: 'US',
        type: 'stock',
        rhsTradability: 'tradable',
        fractionalTradability: 'tradable',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: DateTime.now());

    store.add(order);
  }

  static void _importOptionOrder(
      BuildContext context,
      String occSymbol,
      Match match,
      DateTime? date,
      String action,
      double quantity,
      double price,
      double amount) {
    var store = Provider.of<OptionOrderStore>(context, listen: false);

    String symbol = match.group(1)!;
    // String dateStr = match.group(2)!;
    // String type = match.group(3)!;
    // String strikeStr = match.group(4)!;

    String direction = 'debit';
    if (amount > 0) direction = 'credit';
    if (action.contains('SOLD')) {
      direction = 'credit'; // Usually selling gives credit
    }
    if (action.contains('BOUGHT')) direction = 'debit';

    // Attempt to infer open/close from action string
    // "YOU SOLD OPENING TRANSACTION" -> opening
    // "YOU BOUGHT" -> default to opening?
    // Assuming open for now as history lacks context without position state.
    String openingStrategy = 'long_call'; // placeholder
    String? closingStrategy;

    if (action.contains('OPENING')) {
      closingStrategy = null;
    } else if (action.contains('CLOSING')) {
      closingStrategy = 'close';
    }

    OptionOrder order = OptionOrder(
      'manual_ord_${occSymbol}_${date?.millisecondsSinceEpoch}', // id
      'manual_chain', // chainId
      symbol, // chainSymbol
      null, // cancelUrl
      0, // canceledQuantity
      direction, // direction
      [], // legs (Todo: parse leg)
      0, // pendingQuantity
      amount.abs() /
          100 /
          quantity.abs(), // premium (per share?) No, premium is usually total?
      // OptionOrder premium usually is total price?
      // In RH API "premium" field is usually price * quantity * 100? No.
      // checking Model... premium, processedPremium, price.
      // price is limit price.
      // processedPremium is total amount exchanged.

      amount.abs(), // processedPremium
      price, // price
      quantity.abs(), // processedQuantity
      quantity.abs(), // quantity
      'manual_ref', // refId
      'filled', // state
      'gfd', // timeInForce
      'immediate', // trigger
      'market', // type
      null, // responseCategory
      openingStrategy, // openingStrategy
      closingStrategy, // closingStrategy
      null, // stopPrice
      date ?? DateTime.now(), // createdAt
      date ?? DateTime.now(), // updatedAt
    );

    store.add(order);
  }

  static void _importStock(BuildContext context, String symbol, double quantity,
      double averageCost, double lastPrice, double previousClose) {
    var store = Provider.of<InstrumentPositionStore>(context, listen: false);

    Quote quote = Quote(
      symbol: symbol,
      lastTradePrice: lastPrice,
      lastExtendedHoursTradePrice: lastPrice,
      adjustedPreviousClose: previousClose,
      previousClose: previousClose,
      askSize: 0,
      bidSize: 0,
      updatedAt: DateTime.now(),
      instrument: 'manual_inst_$symbol',
      instrumentId: 'manual_inst_$symbol',
      tradingHalted: false,
      hasTraded: true,
      lastTradePriceSource: 'consolidated',
    );

    Instrument instrument = Instrument(
        id: 'manual_$symbol',
        url: 'manual_inst_$symbol',
        quote: 'manual_quote_$symbol',
        fundamentals: 'manual_fundamentals_$symbol',
        splits: 'manual_splits_$symbol',
        state: 'active',
        market: 'manual_market_$symbol',
        simpleName: symbol,
        name: symbol,
        tradeable: true,
        tradability: 'tradable',
        symbol: symbol,
        bloombergUnique: 'manual_bloomberg_$symbol',
        marginInitialRatio: 0,
        maintenanceRatio: 0,
        country: 'US',
        dayTradeRatio: 0,
        listDate: DateTime.now(),
        minTickSize: null,
        type: 'stock',
        tradeableChainId: 'manual',
        rhsTradability: 'tradable',
        fractionalTradability: 'tradable',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: DateTime.now(),
        quoteObj: quote);

    // Positional arguments for InstrumentPosition
    InstrumentPosition position = InstrumentPosition(
      'manual_pos://$symbol', // url
      'manual://$symbol', // instrument
      'manual_account', // account
      'Imported', // accountNumber
      averageCost, // averageBuyPrice
      0, // pendingAverageBuyPrice
      quantity, // quantity
      0, // intradayAverageBuyPrice
      0, // intradayQuantity
      0, // sharesAvailableForExercise
      0, // sharesHeldForBuys
      0, // sharesHeldForSells
      0, // sharesHeldForStockGrants
      0, // sharesHeldForOptionsCollateral
      0, // sharesHeldForOptionsEvents
      0, // sharesPendingFromOptionsEvents
      0, // sharesAvailableForClosingShortPosition
      false, // avgCostAffected
      DateTime.now(), // updatedAt
      DateTime.now(), // createdAt
    );

    position.instrumentObj = instrument;

    store.add(position);
  }

  static void _importOption(
      BuildContext context,
      String occSymbol,
      Match match,
      double quantity,
      double averageCost,
      double lastPrice,
      double previousClose) {
    var store = Provider.of<OptionPositionStore>(context, listen: false);

    String symbol = match.group(1)!;
    String dateStr = match.group(2)!; // YYMMDD
    String type = match.group(3)!; // C or P
    String strikeStr = match.group(4)!;

    int year = int.parse('20${dateStr.substring(0, 2)}');
    int month = int.parse(dateStr.substring(2, 4));
    int day = int.parse(dateStr.substring(4, 6));
    DateTime expirationDate = DateTime(year, month, day);

    // Strike in Fidelity symbol might be "280" -> 280.0
    double strike = double.parse(strikeStr);
    String optionType = type == 'C' ? 'call' : 'put';

    String direction = quantity < 0 ? 'credit' : 'debit';
    double absQuantity = quantity.abs();

    // Positional for OptionMarketData
    OptionMarketData marketData = OptionMarketData(
        lastPrice, // adjustedMarkPrice
        0, // askPrice
        0, // askSize
        0, // bidPrice
        0, // bidSize
        averageCost, // breakEvenPrice
        0, // highPrice
        'manual_opt_inst_$occSymbol', // instrument
        'manual_opt_inst_id_$occSymbol', // instrumentId
        lastPrice, // lastTradePrice
        0, // lastTradeSize
        0, // lowPrice
        lastPrice, // markPrice
        0, // openInterest
        null, // previousCloseDate
        previousClose, // previousClosePrice
        0, // volume
        symbol, // symbol
        occSymbol, // occSymbol
        0, // chanceOfProfitLong
        0, // chanceOfProfitShort
        0, // delta
        0, // gamma
        0, // impliedVolatility
        0, // rho
        0, // theta
        0, // vega
        0, // highFillRateBuyPrice
        0, // highFillRateSellPrice
        0, // lowFillRateBuyPrice
        0, // lowFillRateSellPrice
        DateTime.now() // updatedAt
        );

    // Positional for OptionInstrument
    OptionInstrument optInstrument = OptionInstrument(
        'manual_chain', // chainId
        'manual_chain_symbol', // chainSymbol
        DateTime.now(), // createdAt
        expirationDate, // expirationDate
        'manual_opt_inst_id_$occSymbol', // id
        DateTime.now(), // issueDate
        const MinTicks(0.01, 0.01, 0.0), // minTicks
        'tradable', // rhsTradability
        'active', // state
        strike, // strikePrice
        'tradable', // tradability
        optionType, // type
        DateTime.now(), // updatedAt
        'manual_opt_inst_$occSymbol', // url
        null, // selloutDateTime
        'none', // longStrategyCode
        'none' // shortStrategyCode
        );
    optInstrument.optionMarketData = marketData;

    // Positional for OptionLeg
    OptionLeg leg = OptionLeg(
        'manual_leg_$occSymbol', // id
        'manual_pos', // position
        direction == 'debit' ? 'long' : 'short', // positionType
        'manual_opt_inst_$occSymbol', // option
        'open', // positionEffect
        1, // ratioQuantity
        direction == 'debit' ? 'long' : 'short', // side
        expirationDate, // expirationDate
        strike, // strikePrice
        optionType, // optionType
        [] // executions
        );

    // Positional for OptionAggregatePosition
    OptionAggregatePosition position = OptionAggregatePosition(
      'manual_op_$occSymbol', // id
      'manual_chain_$symbol', // chain
      'manual_account', // account
      symbol, // symbol
      'long_$optionType', // strategy (guess)
      averageCost, // averageOpenPrice
      [leg], // legs
      absQuantity, // quantity
      0, // intradayAverageOpenPrice
      0, // intradayQuantity
      direction, // direction
      '', // intradayDirection
      100, // tradeValueMultiplier (Standard contracts)
      DateTime.now(), // createdAt
      DateTime.now(), // updatedAt
      'long_$optionType', // strategyCode
    );

    position.optionInstrument = optInstrument;
    position.instrumentObj = Instrument(
        id: 'manual_$symbol',
        url: 'manual_inst_$symbol',
        quote: 'manual_quote_$symbol',
        fundamentals: 'manual_fundamentals_$symbol',
        splits: 'manual_splits_$symbol',
        state: 'active',
        market: 'manual_market_$symbol',
        name: symbol,
        tradeable: true,
        tradability: 'tradable',
        symbol: symbol,
        bloombergUnique: 'manual_bloomberg_$symbol',
        country: 'US',
        type: 'stock',
        rhsTradability: 'tradable',
        fractionalTradability: 'tradable',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: DateTime.now());

    store.add(position);
  }
}
