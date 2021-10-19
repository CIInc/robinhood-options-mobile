/*
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';

//@immutable
class OptionPosition {
  final String account;
  final double? averagePrice;
  final String chainId;
  final String chainSymbol;
  final String id;
  final String option;
  final String type;
  final double? pendingBuyQuantity;
  final double? pendingExpiredQuantity;
  final double? pendingExpirationQuantity;
  final double? pendingExerciseQuantity;
  final double? pendingAssignmentQuantity;
  final double? pendingSellQuantity;
  final double? quantity;
  final double? intradayQuantity;
  final double? intradayAverageOpenPrice;
  final DateTime? createdAt;
  final double? tradeValueMultiplier;
  final DateTime? updatedAt;
  final String url;
  final String optionId;
  OptionInstrument? optionInstrument;

  OptionPosition(
      this.account,
      this.averagePrice,
      this.chainId,
      this.chainSymbol,
      this.id,
      this.option,
      this.type,
      this.pendingBuyQuantity,
      this.pendingExpiredQuantity,
      this.pendingExpirationQuantity,
      this.pendingExerciseQuantity,
      this.pendingAssignmentQuantity,
      this.pendingSellQuantity,
      this.quantity,
      this.intradayQuantity,
      this.intradayAverageOpenPrice,
      this.createdAt,
      this.tradeValueMultiplier,
      this.updatedAt,
      this.url,
      this.optionId);

  OptionPosition.fromJson(dynamic json)
      : account = json['account'],
        averagePrice = double.tryParse(json['average_price']),
        chainId = json['chain_id'],
        chainSymbol = json['chain_symbol'],
        id = json['id'],
        option = json['option'],
        type = json['type'],
        pendingBuyQuantity = double.tryParse(json['pending_buy_quantity']),
        pendingExpiredQuantity =
            double.tryParse(json['pending_expired_quantity']),
        pendingExpirationQuantity =
            double.tryParse(json['pending_expiration_quantity']),
        pendingExerciseQuantity =
            double.tryParse(json['pending_exercise_quantity']),
        pendingAssignmentQuantity =
            double.tryParse(json['pending_assignment_quantity']),
        pendingSellQuantity = double.tryParse(json['pending_sell_quantity']),
        quantity = double.tryParse(json['quantity']),
        intradayQuantity = double.tryParse(json['intraday_quantity']),
        intradayAverageOpenPrice =
            double.tryParse(json['intraday_average_open_price']),
        // 2021-02-09T18:01:28.135813Z
        createdAt =
            //DateFormat('y-M-dTH:m:s.SZ').parse(json['created_at'].toString()),
            DateTime.tryParse(json['created_at']),
        tradeValueMultiplier = double.tryParse(json['trade_value_multiplier']),
        updatedAt =
            //DateFormat('y-M-dTH:m:s.SZ').parse(json['updated_at'].toString()),
            DateTime.tryParse(json['updated_at']),
        url = json['url'],
        optionId = json['option_id'];

  /* CSV Generation */

  List<dynamic> convertToDynamic() {
    List<dynamic> row = [];
    row.add(account);
    row.add(id);
    row.add(url);
    row.add(averagePrice);
    row.add(chainId);
    row.add(chainSymbol);
    row.add(type);
    row.add(pendingBuyQuantity);
    row.add(pendingExpiredQuantity);
    row.add(pendingExpirationQuantity);
    row.add(pendingExerciseQuantity);
    row.add(pendingAssignmentQuantity);
    row.add(pendingSellQuantity);
    row.add(quantity);
    row.add(intradayQuantity);
    row.add(intradayAverageOpenPrice);
    row.add(createdAt);
    row.add(tradeValueMultiplier);
    row.add(updatedAt);
    //row.add(optionId);
    //row.add(option);
    row.add(optionInstrument!.id);
    row.add(optionInstrument!.url);
    //row.add(optionInstrument!.chainId);
    //row.add(optionInstrument!.chainSymbol);
    row.add(optionInstrument!.createdAt);
    row.add(optionInstrument!.expirationDate);
    row.add(optionInstrument!.issueDate);
    row.add(optionInstrument!.minTicks.aboveTick);
    row.add(optionInstrument!.minTicks.belowTick);
    row.add(optionInstrument!.minTicks.cutoffPrice);
    row.add(optionInstrument!.rhsTradability);
    row.add(optionInstrument!.selloutDateTime);
    row.add(optionInstrument!.state);
    row.add(optionInstrument!.strikePrice);
    row.add(optionInstrument!.tradability);
    row.add(optionInstrument!.type);
    row.add(optionInstrument!.updatedAt);
    //row.add(optionInstrument!.optionMarketData!.instrument);
    //row.add(optionInstrument!.optionMarketData!.instrumentId);
    row.add(optionInstrument!.optionMarketData!.adjustedMarkPrice);
    row.add(optionInstrument!.optionMarketData!.askPrice);
    row.add(optionInstrument!.optionMarketData!.askSize);
    row.add(optionInstrument!.optionMarketData!.bidPrice);
    row.add(optionInstrument!.optionMarketData!.bidSize);
    row.add(optionInstrument!.optionMarketData!.breakEvenPrice);
    row.add(optionInstrument!.optionMarketData!.chanceOfProfitLong);
    row.add(optionInstrument!.optionMarketData!.chanceOfProfitShort);
    row.add(optionInstrument!.optionMarketData!.delta);
    row.add(optionInstrument!.optionMarketData!.gamma);
    row.add(optionInstrument!.optionMarketData!.highFillRateBuyPrice);
    row.add(optionInstrument!.optionMarketData!.highFillRateSellPrice);
    row.add(optionInstrument!.optionMarketData!.highPrice);
    row.add(optionInstrument!.optionMarketData!.impliedVolatility);
    row.add(optionInstrument!.optionMarketData!.lastTradePrice);
    row.add(optionInstrument!.optionMarketData!.lastTradeSize);
    row.add(optionInstrument!.optionMarketData!.lowFillRateBuyPrice);
    row.add(optionInstrument!.optionMarketData!.lowFillRateSellPrice);
    row.add(optionInstrument!.optionMarketData!.lowPrice);
    row.add(optionInstrument!.optionMarketData!.markPrice);
    row.add(optionInstrument!.optionMarketData!.occSymbol);
    row.add(optionInstrument!.optionMarketData!.openInterest);
    row.add(optionInstrument!.optionMarketData!.previousCloseDate);
    row.add(optionInstrument!.optionMarketData!.previousClosePrice);
    row.add(optionInstrument!.optionMarketData!.rho);
    row.add(optionInstrument!.optionMarketData!.symbol);
    row.add(optionInstrument!.optionMarketData!.theta);
    row.add(optionInstrument!.optionMarketData!.volume);
    //row.add(jsonEncode(this));
    return row;
  }

  static Future<File> generateCsv(List<OptionPosition> optionPositions) async {
    List<List<dynamic>> rows = [];
    List<dynamic> row = [];
    row.add("account");
    row.add("id");
    row.add("url");
    row.add("averagePrice");
    row.add("chainId");
    row.add("chainSymbol");
    row.add("type");
    row.add("pendingBuyQuantity");
    row.add("pendingExpiredQuantity");
    row.add("pendingExpirationQuantity");
    row.add("pendingExerciseQuantity");
    row.add("pendingAssignmentQuantity");
    row.add("pendingSellQuantity");
    row.add("quantity");
    row.add("intradayQuantity");
    row.add("intradayAverageOpenPrice");
    row.add("createdAt");
    row.add("tradeValueMultiplier");
    row.add("updatedAt");
    //row.add("optionId");
    //row.add("option");
    row.add("id (Instrument)");
    row.add("url (Instrument)");
    //row.add("chainId (Instrument)");
    //row.add("chainSymbol  (Instrument)");
    row.add("createdAt (Instrument)");
    row.add("expirationDate (Instrument)");
    row.add("issueDate (Instrument)");
    row.add("minTicks.aboveTick (Instrument)");
    row.add("minTicks.belowTick (Instrument)");
    row.add("minTicks.cutoffPrice (Instrument)");
    row.add("rhsTradability (Instrument)");
    row.add("selloutDateTime (Instrument)");
    row.add("state (Instrument)");
    row.add("strikePrice (Instrument)");
    row.add("tradability (Instrument)");
    row.add("type (Instrument)");
    row.add("updatedAt (Instrument)");
    //row.add("instrument (MarketData)");
    //row.add("instrumentId (MarketData)");
    row.add("adjustedMarkPrice (MarketData)");
    row.add("askPrice (MarketData)");
    row.add("askSize (MarketData)");
    row.add("bidPrice (MarketData)");
    row.add("bidSize (MarketData)");
    row.add("breakEvenPrice (MarketData)");
    row.add("chanceOfProfitLong (MarketData)");
    row.add("chanceOfProfitShort (MarketData)");
    row.add("delta (MarketData)");
    row.add("gamma (MarketData)");
    row.add("highFillRateBuyPrice (MarketData)");
    row.add("highFillRateSellPrice (MarketData)");
    row.add("highPrice (MarketData)");
    row.add("impliedVolatility (MarketData)");
    row.add("lastTradePrice (MarketData)");
    row.add("lastTradeSize (MarketData)");
    row.add("lowFillRateBuyPrice (MarketData)");
    row.add("lowFillRateSellPrice (MarketData)");
    row.add("lowPrice (MarketData)");
    row.add("markPrice (MarketData)");
    row.add("occSymbol (MarketData)");
    row.add("openInterest (MarketData)");
    row.add("previousCloseDate (MarketData)");
    row.add("previousClosePrice (MarketData)");
    row.add("rho (MarketData)");
    row.add("symbol (MarketData)");
    row.add("theta (MarketData)");
    row.add("volume (MarketData)");

    //row.add("jsonEncode");
    rows.add(row);
    for (int i = 0; i < optionPositions.length; i++) {
      rows.add(optionPositions[i].convertToDynamic());
    }

    String csv = const ListToCsvConverter().convert(rows);

    // storage permission ask
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }

    //final dir = await getApplicationDocumentsDirectory();
    //final dir = await getDownloadsDirectory();
    //final dir = await getExternalStorageDirectory();
    // _${snapshotUser.userName}

    /*
    final dir =
        await getExternalStorageDirectories(type: StorageDirectory.downloads);
    final file = File('${dir![0].path}/RobinhoodOptions.csv');
    await file.writeAsString(csv);
    return file;
    */
    final file2 = File('/storage/emulated/0/Download/RobinhoodOptions.csv');
    await file2.writeAsString(csv);
    return file2;
  }
}
*/