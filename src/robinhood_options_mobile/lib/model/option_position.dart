import 'package:robinhood_options_mobile/model/option_instrument.dart';

/*
{
  "account":"https://api.robinhood.com/accounts/XYZ/",
  "average_price":"0.0000",
  "chain_id":"1ac71e01-0677-42c6-a490-1457980954f8",
  "chain_symbol":"MSFT",
  "id":"49e1ca43-89e3-4fc1-b425-7fb3373893c0",
  "option":"https://api.robinhood.com/options/instruments/f48cc8d3-cb4f-42bb-8c89-4f53ce43aebc/",
  "type":"short",
  "pending_buy_quantity":"0.0000",
  "pending_expired_quantity":"0.0000",
  "pending_expiration_quantity":"0.0000",
  "pending_exercise_quantity":"0.0000",
  "pending_assignment_quantity":"0.0000",
  "pending_sell_quantity":"0.0000",
  "quantity":"0.0000","
  intraday_quantity":"0.0000",
  "intraday_average_open_price":"0.0000",
  "created_at":"2021-02-22T17:09:20.884248Z",
  "trade_value_multiplier":"100.0000",
  "updated_at":"2021-02-22T17:09:20.884262Z",
  "url":"https://api.robinhood.com/options/positions/xyz1ca43-89e3-4fc1-b425-7fb3373893c0/",
  "option_id":"f48cc8d3-cb4f-42bb-8c89-4f53ce43aebc"}*/
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
}
