import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';

//@immutable
class InstrumentOrder {
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

  InstrumentOrder(
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

  InstrumentOrder.fromJson(dynamic json)
      : id = json['id'],
        refId = json['ref_id'],
        url = json['url'],
        account = json['account'],
        position = json['position'],
        cancel = json['cancel'],
        instrument = json['instrument'],
        instrumentId = json['instrument_id'],
        cumulativeQuantity = json['cumulative_quantity'] is double
            ? json['cumulative_quantity']
            : double.tryParse(json['cumulative_quantity']),
        averagePrice = json['average_price'] != null
            ? (json['average_price'] is double
                ? json['average_price']
                : double.tryParse(json['average_price']))
            : null,
        fees = json['fees'] != null
            ? (json['fees'] is double
                ? json['fees']
                : double.tryParse(json['fees']))
            : null,
        state = json['state'],
        pendingCancelOpenAgent = json['pending_cancel_open_agent'],
        type = json['type'],
        side = json['side'],
        timeInForce = json['time_in_force'],
        trigger = json['trigger'],
        price = json['price'] != null
            ? (json['price'] is double
                ? json['price']
                : double.tryParse(json['price']))
            : null,
        stopPrice = json['stop_price'] != null
            ? (json['stop_price'] is double
                ? json['stop_price']
                : double.tryParse(json['stop_price']))
            : null,
        quantity = json['quantity'] is double
            ? json['quantity']
            : double.tryParse(json['quantity']),
        rejectReason = json['reject_reason'],
        updatedAt =
            //DateFormat('y-M-dTH:m:s.SZ').parse(json['updated_at'].toString()),
            json['updated_at'] is Timestamp
                ? (json['updated_at'] as Timestamp).toDate()
                : DateTime.tryParse(json['updated_at']),
        // 2021-02-09T18:01:28.135813Z
        createdAt =
            //DateFormat('y-M-dTH:m:s.SZ').parse(json['created_at'].toString()),
            json['created_at'] is Timestamp
                ? (json['created_at'] as Timestamp).toDate()
                : DateTime.tryParse(json['created_at']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'ref_id': refId,
        'url': url,
        'account': account,
        'position': position,
        'cancel': cancel,
        'instrument': instrument,
        'instrument_id': instrumentId,
        'cumulative_quantity': cumulativeQuantity,
        'average_price': averagePrice,
        'fees': fees,
        'state': state,
        'pending_cancel_open_agent': pendingCancelOpenAgent,
        'type': type,
        'side': side,
        'time_in_force': timeInForce,
        'trigger': trigger,
        'price': price,
        'stop_price': stopPrice,
        'quantity': quantity,
        'reject_reason': rejectReason,
        'created_at': createdAt,
        'updated_at': updatedAt
      };

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

  static Future<File> generateCsv(List<InstrumentOrder> optionOrders) async {
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is InstrumentOrder && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
