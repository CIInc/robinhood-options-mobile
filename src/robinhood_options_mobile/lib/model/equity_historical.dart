import 'package:intl/intl.dart';

class EquityHistorical {
  final double? adjustedOpenEquity;
  final double? adjustedCloseEquity;
  final double? openEquity;
  final double? closeEquity;
  final double? openMarketValue;
  final double? closeMarketValue;
  late DateTime? beginsAt;
  final double? netReturn;
  final String session;

  EquityHistorical(
      this.adjustedOpenEquity,
      this.adjustedCloseEquity,
      this.openEquity,
      this.closeEquity,
      this.openMarketValue,
      this.closeMarketValue,
      this.beginsAt,
      this.netReturn,
      this.session);

  EquityHistorical.fromJson(dynamic json)
      : adjustedOpenEquity = double.tryParse(json['adjusted_open_equity']),
        adjustedCloseEquity = double.tryParse(json['adjusted_close_equity']),
        openEquity = double.tryParse(json['open_equity']),
        closeEquity = double.tryParse(json['close_equity']),
        openMarketValue = double.tryParse(json['open_market_value']),
        closeMarketValue = double.tryParse(json['close_market_value']),
        beginsAt = DateTime.tryParse(json['begins_at']),
        netReturn = double.tryParse(json['net_return']),
        session = json['session'];

  /*
{
  "label": {
      "value": "12:00 AM",
      "color": {
          "light": "fg2",
          "dark": "fg2"
      },
      "text_style": null
  },
  "secondary_label": null,
  "tertiary_label": null,
  "quaternary_label": null,
  "primary_value": {
      "value": "$66,983.97",
      "color": {
          "light": "fg2",
          "dark": "fg2"
      },
      "text_style": null
  },
  "secondary_value": {
      "main": {
          "value": "$898.74 (1.36%)",
          "color": {
              "light": "positive",
              "dark": "positive"
          },
          "icon": "stock_up_16",
          "gradient_color": null
      },
      "string_format": null,
      "description": {
          "value": "",
          "color": {
              "light": "fg",
              "dark": "fg"
          },
          "text_style": null
      }
  },
  "tertiary_value": null,
  "quaternary_value": null,
  "price_chart_data": {
      "dollar_value": {
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
          "amount": "66983.96577182297"
      },
      "dollar_value_for_return": {
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
          "amount": "66983.965771822971873916685581207275390625"
      },
      "dollar_value_for_rate_of_return": {
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
          "amount": "66983.965771822971873916685581207275390625"
      }
  }
}
  */
  EquityHistorical.fromPerformanceJson(dynamic json)
      : adjustedOpenEquity = double.tryParse(json['primary_value']['value']
            .replaceAll('\$', '')
            .replaceAll(',', '')),
        adjustedCloseEquity = double.tryParse(json['primary_value']['value']
            .replaceAll('\$', '')
            .replaceAll(',', '')),
        openEquity = double.tryParse(json['primary_value']['value']
            .replaceAll('\$', '')
            .replaceAll(',', '')),
        closeEquity = double.tryParse(json['primary_value']['value']
            .replaceAll('\$', '')
            .replaceAll(',', '')),
        openMarketValue = double.tryParse(json['primary_value']['value']
            .replaceAll('\$', '')
            .replaceAll(',', '')),
        closeMarketValue = double.tryParse(json['primary_value']['value']
            .replaceAll('\$', '')
            .replaceAll(',', '')),
        beginsAt = null, // DateTime.tryParse(json['label']['value']),
        netReturn = double.tryParse(json['secondary_value']['main']['value']),
        session = json['label']['value'] {
    // For chart span: ytd
    // beginsAt ??= DateFormat('HH:mm MMM d, yyyy').tryParseLoose(json['label']['value']);
    // For chart span: ytd, 3m
    // jan 2, 2025
    beginsAt = DateFormat('MMM d, yyyy').tryParse(json['label']['value']);
    if (beginsAt != null) {
      beginsAt = DateTime(
        beginsAt!.year,
        beginsAt!.month,
        beginsAt!.day,
      );
      return;
    }
    // For chart span: week
    beginsAt = DateFormat('h:mm a, MMM d').tryParseLoose(json['label']['value']);
    if (beginsAt != null) {
      beginsAt = DateTime(
        DateTime.now().year,
        beginsAt!.month,
        beginsAt!.day,
        beginsAt!.hour,
        beginsAt!.minute,
        beginsAt!.second,
      );
      return;
    }
    // For chart span: hour
    beginsAt = DateFormat('h:mm:ss a').tryParse(json['label']['value']);
    if (beginsAt != null) {
      beginsAt = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        beginsAt!.hour,
        beginsAt!.minute,
        beginsAt!.second,
      );
      return;
    }
    // For chart span: day
    beginsAt = DateFormat('h:mm a').tryParse(json['label']['value']);
    // beginsAt = DateFormat.jm().tryParseLoose(json['label']['value']);
    if (beginsAt != null) {
      beginsAt = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        beginsAt!.hour,
        beginsAt!.minute,
        beginsAt!.second,
      );
      return;
    }
    if (beginsAt == null) {
      throw Exception('beginsAt is null ${json['label']['value']}');
    }
  }

  static List<EquityHistorical> fromJsonArray(dynamic json) {
    List<EquityHistorical> list = [];
    for (int i = 0; i < json.length; i++) {
      var equityHistorical = EquityHistorical.fromJson(json[i]);
      list.add(equityHistorical);
    }
    return list;
  }
}
