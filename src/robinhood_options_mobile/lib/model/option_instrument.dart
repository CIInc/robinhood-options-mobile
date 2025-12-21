import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';

@immutable
class MinTicks {
  final double? aboveTick;
  final double? belowTick;
  final double? cutoffPrice;
  const MinTicks(this.aboveTick, this.belowTick, this.cutoffPrice);
  Map<String, dynamic> toJson() => {
        'above_tick': aboveTick,
        'below_tick': belowTick,
        'cutoff_price': cutoffPrice
      };
}

//@immutable
class OptionInstrument {
  final String chainId;
  final String chainSymbol;
  final DateTime? createdAt;
  final DateTime? expirationDate;
  final String id;
  final DateTime? issueDate;
  final MinTicks minTicks;

  final String rhsTradability;
  final String state;
  final double? strikePrice;
  final String tradability;
  final String type;
  final DateTime? updatedAt;
  final String url;
  final DateTime? selloutDateTime;
  final String longStrategyCode;
  final String shortStrategyCode;

  OptionMarketData? optionMarketData;

  OptionInstrument(
      this.chainId,
      this.chainSymbol,
      this.createdAt,
      this.expirationDate,
      this.id,
      this.issueDate,
      this.minTicks,
      this.rhsTradability,
      this.state,
      this.strikePrice,
      this.tradability,
      this.type,
      this.updatedAt,
      this.url,
      this.selloutDateTime,
      this.longStrategyCode,
      this.shortStrategyCode);

  OptionInstrument.fromJson(dynamic json)
      : chainId = json['chain_id'],
        chainSymbol = json['chain_symbol'],
        createdAt = DateTime.tryParse(json['created_at']),
        expirationDate = DateTime.tryParse(json['expiration_date']),
        id = json['id'],
        issueDate = DateTime.tryParse(json['issue_date']),
        minTicks = MinTicks(
            double.tryParse(json['min_ticks']['above_tick']),
            double.tryParse(json['min_ticks']['below_tick']),
            double.tryParse(json['min_ticks']['cutoff_price'])),
        rhsTradability = json['rhs_tradability'],
        state = json['state'],
        strikePrice = double.tryParse(json['strike_price']),
        tradability = json['tradability'],
        type = json['type'],
        updatedAt = DateTime.tryParse(json['updated_at']),
        url = json['url'],
        selloutDateTime = DateTime.tryParse(json['sellout_datetime']),
        longStrategyCode = json['long_strategy_code'],
        shortStrategyCode = json['short_strategy_code'];

  // toMarkdownTable generates a markdown table from a list of OptionInstrument populating the table with all the daya including the properties of OptionMarketData.

  /// Generates a markdown table from a list of OptionInstrument,
  /// including all OptionInstrument fields and the properties of OptionMarketData.
  static String toMarkdownTable(List<OptionInstrument> options) {
    if (options.isEmpty) return 'No option instruments available.';

    // OptionInstrument headers
    final headers = [
      'Chain Symbol',
      'Type',
      'Strike',
      'Expiration',
      'State',
      'Tradability',
      'RHS Tradability',
      'Long Strategy',
      'Short Strategy',
      'Min Tick Above',
      'Min Tick Below',
      'Min Tick Cutoff',
    ];

    // OptionMarketData headers (reuse the header row from OptionMarketData)
    final marketDataHeaderRow = OptionMarketData.toMarkdownTableHeader();
    final marketDataHeaders = marketDataHeaderRow
        .split('\n')
        .first
        .replaceAll('|', '')
        .split(' ')
        .where((h) => h.isNotEmpty)
        .toList();

    final allHeaders = [...headers, ...marketDataHeaders];

    final buffer = StringBuffer();
    buffer.writeln('| ${allHeaders.join(' | ')} |');
    buffer.writeln('|${List.filled(allHeaders.length, '---').join('|')}|');

    for (final o in options) {
      final row = [
        o.chainSymbol,
        o.type,
        o.strikePrice?.toStringAsFixed(2) ?? '',
        o.expirationDate?.toIso8601String().split('T').first ?? '',
        o.state,
        o.tradability,
        o.rhsTradability,
        o.longStrategyCode,
        o.shortStrategyCode,
        o.minTicks.aboveTick?.toString() ?? '',
        o.minTicks.belowTick?.toString() ?? '',
        o.minTicks.cutoffPrice?.toString() ?? '',
        ..._optionMarketDataRow(o.optionMarketData, marketDataHeaders.length),
      ];
      buffer.writeln('| ${row.join(' | ')} |');
    }
    return buffer.toString();
  }

  /// Helper to get OptionMarketData row as a list of strings, or empty if null.
  static List<String> _optionMarketDataRow(OptionMarketData? data, int length) {
    if (data == null) {
      return List.filled(length, '');
    }
    // Use OptionMarketData.toMarkdownTableRow() if available, else fallback to splitting the markdown row
    // if (data.toMarkdownTableRow != null) {
    return data.toMarkdownTableRow();
    // }
    // fallback: parse the markdown row string
    // final rowString = OptionMarketData.toMarkdownTable([data]).split('\n')[1];
    // return rowString
    //     .split('|')
    //     .map((s) => s.trim())
    //     .where((s) => s.isNotEmpty)
    //     .toList();
  }
}
