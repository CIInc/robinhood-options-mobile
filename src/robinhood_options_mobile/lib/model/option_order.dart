import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:robinhood_options_mobile/model/option_event.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';

//@immutable
class OptionOrder {
  final String id;
  final String chainId;
  final String chainSymbol;
  final String? cancelUrl;
  final double? canceledQuantity;
  final String direction;
  List<OptionLeg> legs;
  final double? pendingQuantity;
  final double? premium;
  final double? processedPremium;
  final double? price;
  final double? processedQuantity;
  final double? quantity;
  final String refId;
  final String state;
  final String timeInForce;
  final String trigger;
  final String type;
  final String? responseCategory;
  final String? openingStrategy;
  final String? closingStrategy;
  final double? stopPrice;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  List<OptionEvent>? optionEvents;

  OptionOrder(
      this.id,
      this.chainId,
      this.chainSymbol,
      this.cancelUrl,
      this.canceledQuantity,
      this.direction,
      this.legs,
      this.pendingQuantity,
      this.premium,
      this.processedPremium,
      this.price,
      this.processedQuantity,
      this.quantity,
      this.refId,
      this.state,
      this.timeInForce,
      this.trigger,
      this.type,
      this.responseCategory,
      this.openingStrategy,
      this.closingStrategy,
      this.stopPrice,
      this.createdAt,
      this.updatedAt);

  OptionOrder.fromJson(dynamic json)
      : id = json['id'],
        chainId = json['chain_id'],
        chainSymbol = json['chain_symbol'],
        cancelUrl = json['cancel_url'],
        canceledQuantity = json['canceled_quantity'] is double
            ? json['canceled_quantity']
            : double.tryParse(json['canceled_quantity']),
        direction = json['direction'],
        legs = OptionLeg.fromJsonArray(json['legs']),
        pendingQuantity = json['pending_quantity'] is double
            ? json['pending_quantity']
            : double.tryParse(json['pending_quantity']),
        premium = json['premium'] != null
            ? (json['premium'] is double
                ? json['premium']
                : double.tryParse(json['premium']))
            : null,
        processedPremium = json['processed_premium'] is double
            ? json['processed_premium']
            : double.tryParse(json['processed_premium']),
        price = json['price'] != null
            ? (json['price'] is double
                ? json['price']
                : double.tryParse(json['price']))
            : null,
        processedQuantity = json['processed_quantity'] is double
            ? json['processed_quantity']
            : double.tryParse(json['processed_quantity']),
        quantity = json['quantity'] is double
            ? json['quantity']
            : double.tryParse(json['quantity']),
        refId = json['ref_id'],
        state = json['state'],
        timeInForce = json['time_in_force'],
        trigger = json['trigger'],
        type = json['type'],
        responseCategory = json['response_category'],
        openingStrategy = json['opening_strategy'],
        closingStrategy = json['closing_strategy'],
        stopPrice = json['stop_price'] != null
            ? (json['stop_price'] is double
                ? json['stop_price']
                : double.tryParse(json['stop_price']))
            : null,
        createdAt = json['created_at'] is Timestamp
            ? (json['created_at'] as Timestamp).toDate()
            : DateTime.tryParse(json['created_at']),
        updatedAt = json['updated_at'] is Timestamp
            ? (json['updated_at'] as Timestamp).toDate()
            : DateTime.tryParse(json['updated_at']);

  String get strategy {
    String strat = "";
    if (openingStrategy != null) {
      switch (openingStrategy) {
        case "long_call":
          strat = "Call Buy";
          break;
        case "short_call":
          strat = "Call Sell";
          break;
        case "long_put":
          strat = "Put Buy";
          break;
        case "short_put":
          strat = "Put Sell";
          break;
      }
    } else if (closingStrategy != null) {
      switch (closingStrategy) {
        case "long_call":
          strat = "Call Sell";
          break;
        case "short_call":
          strat = "Call Buy";
          break;
        case "long_put":
          strat = "Put Sell";
          break;
        case "short_put":
          strat = "Put Buy";
          break;
      }
    }
    return strat;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'chain_id': chainId,
        'chain_symbol': chainSymbol,
        'cancel_url': cancelUrl,
        'canceled_quantity': canceledQuantity,
        'direction': direction,
        'legs': legs.map((e) => e.toJson()).toList(),
        'pending_quantity': pendingQuantity,
        'premium': premium,
        'processed_premium': processedPremium,
        'price': price,
        'processed_quantity': processedQuantity,
        'quantity': quantity,
        'ref_id': refId,
        'state': state,
        'time_in_force': timeInForce,
        'trigger': trigger,
        'type': type,
        'response_category': responseCategory,
        'opening_strategy': openingStrategy,
        'closing_strategy': closingStrategy,
        'stop_price': stopPrice,
        'created_at': createdAt,
        'updated_at': updatedAt
      };

  /* CSV Generation */

  List<dynamic> convertToDynamic() {
    List<dynamic> row = [];
    row.add(id);
    row.add(chainId);
    row.add(chainSymbol);
    row.add(cancelUrl);
    row.add(canceledQuantity);
    row.add(direction);
    row.add(legs);
    row.add(pendingQuantity);
    row.add(premium);
    row.add(processedPremium);
    row.add(price);
    row.add(processedQuantity);
    row.add(quantity);
    row.add(refId);
    row.add(state);
    row.add(timeInForce);
    row.add(trigger);
    row.add(type);
    row.add(responseCategory);
    row.add(openingStrategy);
    row.add(closingStrategy);
    row.add(stopPrice);
    row.add(createdAt);
    row.add(updatedAt);
    //row.add(jsonEncode(this));
    return row;
  }

  static Future<File> generateCsv(List<OptionOrder> optionOrders) async {
    List<List<dynamic>> rows = [];
    List<dynamic> row = [];
    row.add("id");
    row.add("chainId");
    row.add("chainSymbol");
    row.add("cancelUrl");
    row.add("canceledQuantity");
    row.add("direction");
    row.add("legs");
    row.add("pendingQuantity");
    row.add("premium");
    row.add("processedPremium");
    row.add("price");
    row.add("processedQuantity");
    row.add("quantity");
    row.add("refId");
    row.add("state");
    row.add("timeInForce");
    row.add("trigger");
    row.add("type");
    row.add("responseCategory");
    row.add("openingStrategy");
    row.add("closingStrategy");
    row.add("stopPrice");
    row.add("createdAt");
    row.add("updatedAt");

    //row.add("jsonEncode");
    rows.add(row);
    for (int i = 0; i < optionOrders.length; i++) {
      rows.add(optionOrders[i].convertToDynamic());
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
