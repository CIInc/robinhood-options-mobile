import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:robinhood_options_mobile/utils/json.dart';
import 'package:robinhood_options_mobile/model/option_leg_execution.dart';

class OptionLeg {
  final String id;
  final String? position; // Not in OptionOrder example ?
  final String? positionType; // Not in OptionOrder example ?
  final String option;
  final String? positionEffect; // Not in OptionAggregatePosition example ?
  final int ratioQuantity;
  final String? side; // Not in OptionAggregatePosition example ?
  final DateTime? expirationDate;
  final double? strikePrice;
  final String optionType;
  final List<OptionLegExecution>
      executions; // Not in OptionAggregatePosition example ?

  OptionLeg(
      this.id,
      this.position,
      this.positionType,
      this.option,
      this.positionEffect,
      this.ratioQuantity,
      this.side,
      this.expirationDate,
      this.strikePrice,
      this.optionType,
      this.executions);

  OptionLeg.fromJson(dynamic json)
      : id = json['id'],
        position = json['position'],
        positionType = json['position_type'],
        option = json['option'],
        positionEffect = json['position_effect'],
        ratioQuantity = json['ratio_quantity'],
        side = json['side'],
        expirationDate = json['expiration_date'] is Timestamp
            ? (json['expiration_date'] as Timestamp).toDate()
            : (json['expiration_date'] is String
                ? DateTime.tryParse(json['expiration_date'])
                : null),
        strikePrice = parseDouble(json['strike_price']),
        optionType = json['option_type'],
        executions = json['executions'] != null
            ? OptionLegExecution.fromJsonArray(json['executions'])
            : [];

  OptionLeg.fromSchwabJson(dynamic json)
      : id = json['legId']?.toString() ?? '',
        position = null,
        positionType = json['instruction'] != null &&
                json['instruction'].toString().startsWith('BUY')
            ? 'long'
            : 'short', // BUY_TO_OPEN, SELL_TO_CLOSE
        option = json['instrument'] != null
            ? (json['instrument']['instrumentId']?.toString() ?? '')
            : '',
        positionEffect = json['positionEffect'] == 'OPENING' ? 'open' : 'close',
        ratioQuantity = (json['quantity'] as num?)?.toInt() ?? 1,
        side = json['instruction'] != null
            ? json['instruction'].toString().split('_')[0].toLowerCase()
            : 'buy',
        expirationDate = _parseSchwabExpirationDate(json['instrument']),
        strikePrice = _parseSchwabStrikePrice(json['instrument']),
        optionType = json['instrument'] != null &&
                json['instrument']['putCall'] != null
            ? json['instrument']['putCall'].toString().toLowerCase()
            : '',
        executions = [];

  static DateTime? _parseSchwabExpirationDate(dynamic instrument) {
    if (instrument == null || instrument is! Map) return null;
    if (instrument['expirationDate'] != null) {
      return DateTime.tryParse(instrument['expirationDate'].toString());
    }
    final desc = instrument['description'];
    if (desc != null) {
      final parts =
          desc.toString().split(' ').where((s) => s.isNotEmpty).toList();
      if (parts.length >= 3) {
        final dateStr = parts[parts.length - 3];
        return DateFormat("MM/dd/yyyy").tryParse(dateStr) ??
            DateTime.tryParse(dateStr);
      }
    }
    return null;
  }

  static double? _parseSchwabStrikePrice(dynamic instrument) {
    if (instrument == null || instrument is! Map) return null;
    if (instrument['strikePrice'] != null) {
      return (instrument['strikePrice'] as num?)?.toDouble();
    }
    final desc = instrument['description'];
    if (desc != null) {
      final parts =
          desc.toString().split(' ').where((s) => s.isNotEmpty).toList();
      if (parts.length >= 2) {
        final priceStr = parts[parts.length - 2].replaceAll(r'$', '');
        return double.tryParse(priceStr);
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'position': position,
        'position_type': positionType,
        'option': option,
        'position_effect': positionEffect,
        'ratio_quantity': ratioQuantity,
        'side': side,
        'expiration_date': expirationDate,
        'strike_price': strikePrice,
        'option_type': optionType,
        'executions': executions.map((e) => e.toJson()).toList()
      };

  static List<OptionLeg> fromJsonArray(dynamic json) {
    List<OptionLeg> legs = [];
    for (int i = 0; i < json.length; i++) {
      //try {
      var leg = OptionLeg.fromJson(json[i]);
      legs.add(leg);
      /*} catch (e) {
        print(e);
      }*/
    }
    return legs;
  }

  static List<OptionLeg> fromSchwabJsonArray(dynamic json) {
    List<OptionLeg> legs = [];
    for (int i = 0; i < json.length; i++) {
      var leg = OptionLeg.fromSchwabJson(json[i]);
      legs.add(leg);
    }
    return legs;
  }
}
