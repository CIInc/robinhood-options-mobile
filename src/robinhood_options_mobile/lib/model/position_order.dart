import 'dart:io';

import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';

//@immutable
class PositionOrder {
  final String id;
  final String? refId;
  final String url;
  final String account;
  final String position;
  final String? cancel;
  final String instrument;
  final String instrumentId;
  final double? cumulativeQuantity;
  final double? averagePrice;
  final double? fees;
  final String state;
  final String? pendingCancelOpenAgent;
  final String type;
  final String side;
  final String timeInForce;
  final String trigger;
  final double? price;
  final double? stopPrice;
  final double? quantity;
  final String? rejectReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Instrument? instrumentObj;

  PositionOrder(
      this.id,
      this.refId,
      this.url,
      this.account,
      this.position,
      this.cancel,
      this.instrument,
      this.instrumentId,
      this.cumulativeQuantity,
      this.averagePrice,
      this.fees,
      this.state,
      this.pendingCancelOpenAgent,
      this.type,
      this.side,
      this.timeInForce,
      this.trigger,
      this.price,
      this.stopPrice,
      this.quantity,
      this.rejectReason,
      this.createdAt,
      this.updatedAt);

  PositionOrder.fromJson(dynamic json)
      : id = json['id'],
        refId = json['ref_id'],
        url = json['url'],
        account = json['account'],
        position = json['position'],
        cancel = json['cancel'],
        instrument = json['instrument'],
        instrumentId = json['instrument_id'],
        cumulativeQuantity = double.tryParse(json['cumulative_quantity']),
        averagePrice = json['average_price'] != null
            ? double.tryParse(json['average_price'])
            : null,
        fees = json['fees'] != null ? double.tryParse(json['fees']) : null,
        state = json['state'],
        pendingCancelOpenAgent = json['pending_cancel_open_agent'],
        type = json['type'],
        side = json['side'],
        timeInForce = json['time_in_force'],
        trigger = json['trigger'],
        price = json['price'] != null ? double.tryParse(json['price']) : null,
        stopPrice = json['stop_price'] != null
            ? double.tryParse(json['stop_price'])
            : null,
        quantity = double.tryParse(json['quantity']),
        rejectReason = json['reject_reason'],
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
    row.add(refId);
    row.add(url);
    row.add(account);
    row.add(position);
    row.add(cancel);
    row.add(instrument);
    row.add(instrumentId);
    row.add(cumulativeQuantity);
    row.add(averagePrice);
    row.add(fees);
    row.add(state);
    row.add(pendingCancelOpenAgent);
    row.add(type);
    row.add(side);
    row.add(timeInForce);
    row.add(trigger);
    row.add(price);
    row.add(stopPrice);
    row.add(quantity);
    row.add(rejectReason);
    row.add(createdAt);
    row.add(updatedAt);
    //row.add(jsonEncode(this));
    return row;
  }

  static Future<File> generateCsv(List<PositionOrder> optionOrders) async {
    List<List<dynamic>> rows = [];
    List<dynamic> row = [];
    row.add("id");
    row.add("refId");
    row.add("url");
    row.add("account");
    row.add("position");
    row.add("cancel");
    row.add("instrument");
    row.add("instrumentId");
    row.add("cumulativeQuantity");
    row.add("averagePrice");
    row.add("fees");
    row.add("state");
    row.add("pendingCancelOpenAgent");
    row.add("type");
    row.add("side");
    row.add("timeInForce");
    row.add("trigger");
    row.add("price");
    row.add("stopPrice");
    row.add("quantity");
    row.add("rejectReason");
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

    final file2 =
        File('/storage/emulated/0/Download/RobinhoodPositionOrders.csv');
    await file2.writeAsString(csv);
    return file2;
  }
}
