import 'dart:io';
import 'package:csv/csv.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';

/// Service to parse and import Fidelity CSV transaction files
class FidelityCsvImportService {
  /// Parse a Fidelity CSV file and return lists of stock and option orders
  /// 
  /// Returns a Map with keys 'instrumentOrders' and 'optionOrders'
  static Future<Map<String, List<dynamic>>> parseTransactionsCsv(
      File csvFile) async {
    final input = await csvFile.readAsString();
    final rows = const CsvToListConverter().convert(input);

    if (rows.isEmpty) {
      throw Exception('CSV file is empty');
    }

    // Find the header row (Fidelity CSVs often have metadata rows before the actual data)
    int headerIndex = _findHeaderRow(rows);
    if (headerIndex == -1) {
      throw Exception('Could not find header row in CSV file');
    }

    final headers = rows[headerIndex].map((h) => h.toString().trim()).toList();
    final dataRows = rows.sublist(headerIndex + 1);

    List<InstrumentOrder> instrumentOrders = [];
    List<OptionOrder> optionOrders = [];

    for (var row in dataRows) {
      if (row.isEmpty || row.every((cell) => cell == null || cell == '')) {
        continue; // Skip empty rows
      }

      final rowMap = _createRowMap(headers, row);

      // Determine if this is an option or stock transaction
      if (_isOptionTransaction(rowMap)) {
        final optionOrder = _parseOptionOrder(rowMap);
        if (optionOrder != null) {
          optionOrders.add(optionOrder);
        }
      } else if (_isStockTransaction(rowMap)) {
        final instrumentOrder = _parseInstrumentOrder(rowMap);
        if (instrumentOrder != null) {
          instrumentOrders.add(instrumentOrder);
        }
      }
    }

    return {
      'instrumentOrders': instrumentOrders,
      'optionOrders': optionOrders,
    };
  }

  /// Find the header row in the CSV (looks for common Fidelity headers)
  static int _findHeaderRow(List<List<dynamic>> rows) {
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowStr = row.map((cell) => cell.toString().toLowerCase()).toList();

      // Look for typical Fidelity CSV headers
      if (rowStr.any((cell) =>
          cell.contains('run date') ||
          cell.contains('action') ||
          cell.contains('symbol') ||
          cell.contains('description') ||
          cell.contains('quantity') ||
          cell.contains('price'))) {
        return i;
      }
    }
    return -1;
  }

  /// Create a map from headers and row data
  static Map<String, String> _createRowMap(
      List<dynamic> headers, List<dynamic> row) {
    final map = <String, String>{};
    for (int i = 0; i < headers.length && i < row.length; i++) {
      final header = headers[i].toString().trim();
      final value = row[i]?.toString().trim() ?? '';
      map[header] = value;
    }
    return map;
  }

  /// Check if the transaction is an option
  static bool _isOptionTransaction(Map<String, String> rowMap) {
    final symbol = rowMap['Symbol'] ?? '';
    final description = rowMap['Description'] ?? '';
    final securityType = rowMap['Security Type'] ?? '';

    // Fidelity option symbols typically contain spaces and keywords like CALL/PUT
    return symbol.toUpperCase().contains(' CALL ') ||
        symbol.toUpperCase().contains(' PUT ') ||
        description.toUpperCase().contains('OPTION') ||
        securityType.toUpperCase().contains('OPTION');
  }

  /// Check if the transaction is a stock transaction
  static bool _isStockTransaction(Map<String, String> rowMap) {
    final action = rowMap['Action'] ?? '';
    final symbol = rowMap['Symbol'] ?? '';

    // Stock transactions have actions like BUY, SELL and simple symbols
    return (action.toUpperCase().contains('BUY') ||
            action.toUpperCase().contains('SELL')) &&
        symbol.isNotEmpty &&
        !_isOptionTransaction(rowMap);
  }

  /// Parse a stock transaction into an InstrumentOrder
  static InstrumentOrder? _parseInstrumentOrder(Map<String, String> rowMap) {
    try {
      final action = rowMap['Action'] ?? '';
      final symbol = rowMap['Symbol'] ?? '';
      final quantity = double.tryParse(
              rowMap['Quantity']?.replaceAll(',', '') ?? '0') ??
          0.0;
      final price = double.tryParse(
              rowMap['Price']?.replaceAll(r'$', '').replaceAll(',', '') ??
                  '0') ??
          0.0;
      final amount = double.tryParse(
              rowMap['Amount']?.replaceAll(r'$', '').replaceAll(',', '') ??
                  '0') ??
          0.0;
      final commission = double.tryParse(
              rowMap['Commission']?.replaceAll(r'$', '').replaceAll(',', '') ??
                  '0') ??
          0.0;
      final fees = double.tryParse(
              rowMap['Fees']?.replaceAll(r'$', '').replaceAll(',', '') ??
                  '0') ??
          0.0;
      final settlementDate = _parseDate(rowMap['Settlement Date'] ?? '');
      final runDate = _parseDate(rowMap['Run Date'] ?? '');

      // Determine side (buy or sell)
      String side = 'buy';
      if (action.toUpperCase().contains('SELL')) {
        side = 'sell';
      }

      // Generate a unique ID based on the transaction details
      final id =
          'fidelity_${symbol}_${settlementDate?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}_${quantity.toInt()}';

      return InstrumentOrder(
        id,
        id, // refId
        '', // url
        'fidelity_account', // account
        '', // position
        null, // cancel
        '', // instrument
        symbol, // instrumentId (using symbol as ID)
        quantity, // cumulativeQuantity
        price, // averagePrice
        commission + fees, // fees
        'filled', // state
        null, // pendingCancelOpenAgent
        'limit', // type
        side, // side
        'gtc', // timeInForce
        'immediate', // trigger
        price, // price
        null, // stopPrice
        quantity, // quantity
        null, // rejectReason
        settlementDate ?? runDate ?? DateTime.now(), // createdAt
        settlementDate ?? runDate ?? DateTime.now(), // updatedAt
      );
    } catch (e) {
      print('Error parsing instrument order: $e');
      return null;
    }
  }

  /// Parse an option transaction into an OptionOrder
  static OptionOrder? _parseOptionOrder(Map<String, String> rowMap) {
    try {
      final symbol = rowMap['Symbol'] ?? '';
      final description = rowMap['Description'] ?? '';
      final action = rowMap['Action'] ?? '';
      final quantity = double.tryParse(
              rowMap['Quantity']?.replaceAll(',', '') ?? '0') ??
          0.0;
      final price = double.tryParse(
              rowMap['Price']?.replaceAll(r'$', '').replaceAll(',', '') ??
                  '0') ??
          0.0;
      final amount = double.tryParse(
              rowMap['Amount']?.replaceAll(r'$', '').replaceAll(',', '') ??
                  '0') ??
          0.0;
      final commission = double.tryParse(
              rowMap['Commission']?.replaceAll(r'$', '').replaceAll(',', '') ??
                  '0') ??
          0.0;
      final fees = double.tryParse(
              rowMap['Fees']?.replaceAll(r'$', '').replaceAll(',', '') ??
                  '0') ??
          0.0;
      final settlementDate = _parseDate(rowMap['Settlement Date'] ?? '');
      final runDate = _parseDate(rowMap['Run Date'] ?? '');

      // Parse option details from symbol or description
      final optionDetails = _parseOptionDetails(symbol, description);
      if (optionDetails == null) {
        return null;
      }

      // Determine direction (debit or credit)
      String direction = 'debit';
      if (action.toUpperCase().contains('SELL')) {
        direction = 'credit';
      }

      // Determine opening/closing strategy
      String? openingStrategy;
      String? closingStrategy;
      final isBuy = action.toUpperCase().contains('BUY');
      final isCall = optionDetails['type'] == 'call';

      if (action.toUpperCase().contains('BUY TO OPEN') ||
          action.toUpperCase().contains('BOUGHT')) {
        openingStrategy = isCall ? 'long_call' : 'long_put';
      } else if (action.toUpperCase().contains('SELL TO OPEN')) {
        openingStrategy = isCall ? 'short_call' : 'short_put';
      } else if (action.toUpperCase().contains('BUY TO CLOSE')) {
        closingStrategy = isCall ? 'short_call' : 'short_put';
      } else if (action.toUpperCase().contains('SELL TO CLOSE') ||
          action.toUpperCase().contains('SOLD')) {
        closingStrategy = isCall ? 'long_call' : 'long_put';
      }

      // Generate unique ID
      final id =
          'fidelity_option_${optionDetails['chainSymbol']}_${settlementDate?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}_${quantity.toInt()}';

      // Calculate premium (negative for buys, positive for sells)
      final premium = amount.abs() * (isBuy ? -1 : 1);

      // Create option leg
      final leg = OptionLeg(
        id: 'leg_$id',
        side: isBuy ? 'buy' : 'sell',
        positionEffect: openingStrategy != null ? 'open' : 'close',
        ratioQuantity: 1,
        optionId: '',
        optionUrl: '',
        expirationType: 'regular',
        expirationDate: optionDetails['expirationDate'],
      );

      return OptionOrder(
        id,
        optionDetails['chainSymbol']!, // chainId
        optionDetails['chainSymbol']!, // chainSymbol
        null, // cancelUrl
        0, // canceledQuantity
        direction,
        [leg], // legs
        0, // pendingQuantity
        premium, // premium
        premium, // processedPremium
        price, // price
        quantity, // processedQuantity
        quantity, // quantity
        id, // refId
        'filled', // state
        'gtc', // timeInForce
        'immediate', // trigger
        'limit', // type
        null, // responseCategory
        openingStrategy,
        closingStrategy,
        null, // stopPrice
        settlementDate ?? runDate ?? DateTime.now(), // createdAt
        settlementDate ?? runDate ?? DateTime.now(), // updatedAt
      );
    } catch (e) {
      print('Error parsing option order: $e');
      return null;
    }
  }

  /// Parse option details from symbol or description
  /// Returns a map with chainSymbol, strike, expirationDate, and type (call/put)
  static Map<String, dynamic>? _parseOptionDetails(
      String symbol, String description) {
    try {
      // Fidelity option format examples:
      // "AAPL Jan 20 2023 150.00 Call"
      // "AAPL 01/20/2023 150 C"
      // Symbol might be: "AAPL 01/20/23 $150 CALL"

      final combined = '$symbol $description'.toUpperCase();

      // Extract underlying symbol (first word/ticker)
      final parts = symbol.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty) return null;

      final chainSymbol = parts[0];

      // Determine if CALL or PUT
      String type = 'call';
      if (combined.contains(' PUT') || combined.contains(' P ')) {
        type = 'put';
      }

      // Try to find strike price (look for number with decimal)
      final strikeMatch = RegExp(r'\$?(\d+\.?\d*)').firstMatch(combined);
      final strike =
          strikeMatch != null ? double.tryParse(strikeMatch.group(1)!) : null;

      // Try to parse expiration date
      // Look for date patterns like MM/DD/YY, MM/DD/YYYY, or "Jan 20 2023"
      DateTime? expirationDate;

      // Try numeric date format
      final dateMatch = RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})')
          .firstMatch(combined);
      if (dateMatch != null) {
        int month = int.parse(dateMatch.group(1)!);
        int day = int.parse(dateMatch.group(2)!);
        int year = int.parse(dateMatch.group(3)!);
        if (year < 100) year += 2000; // Handle 2-digit years
        expirationDate = DateTime(year, month, day);
      }

      return {
        'chainSymbol': chainSymbol,
        'strike': strike,
        'expirationDate': expirationDate,
        'type': type,
      };
    } catch (e) {
      print('Error parsing option details: $e');
      return null;
    }
  }

  /// Parse a date string in various formats
  static DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;

    try {
      // Try MM/DD/YYYY or MM/DD/YY format
      final dateMatch = RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})')
          .firstMatch(dateStr);
      if (dateMatch != null) {
        int month = int.parse(dateMatch.group(1)!);
        int day = int.parse(dateMatch.group(2)!);
        int year = int.parse(dateMatch.group(3)!);
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      }

      // Try ISO format
      return DateTime.tryParse(dateStr);
    } catch (e) {
      print('Error parsing date: $e');
      return null;
    }
  }
}
