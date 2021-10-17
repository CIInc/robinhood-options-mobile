import 'dart:io';

import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';
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
        canceledQuantity = double.tryParse(json['canceled_quantity']),
        direction = json['direction'],
        legs = OptionLeg.fromJsonArray(json['legs']),
        pendingQuantity = double.tryParse(json['pending_quantity']),
        premium =
            json['premium'] != null ? double.tryParse(json['premium']) : null,
        processedPremium = double.tryParse(json['processed_premium']),
        price = json['price'] != null ? double.tryParse(json['price']) : null,
        processedQuantity = double.tryParse(json['processed_quantity']),
        quantity = double.tryParse(json['quantity']),
        refId = json['ref_id'],
        state = json['state'],
        timeInForce = json['time_in_force'],
        trigger = json['trigger'],
        type = json['type'],
        responseCategory = json['response_category'],
        openingStrategy = json['opening_strategy'],
        closingStrategy = json['closing_strategy'],
        stopPrice = json['stop_price'] != null
            ? double.tryParse(json['stop_price'])
            : null,
        createdAt =
            //DateFormat('y-M-dTH:m:s.SZ').parse(json['created_at'].toString()),
            DateTime.tryParse(json['created_at']),
        updatedAt =
            //DateFormat('y-M-dTH:m:s.SZ').parse(json['updated_at'].toString()),
            DateTime.tryParse(json['updated_at']);

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
