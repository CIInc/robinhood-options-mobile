import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/services/fidelity_csv_import_service.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';

void main() {
  group('FidelityCsvImportService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fidelity_csv_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('parses stock transaction CSV correctly', () async {
      // Create a test CSV with stock transactions
      final csvContent = '''Run Date,Action,Symbol,Security Description,Security Type,Quantity,Price,Commission,Fees,Accrued Interest,Amount,Settlement Date
01/15/2024,BUY,AAPL,APPLE INC,EQUITY,10,150.50,$0.00,$0.00,$0.00,-$1505.00,01/17/2024
01/20/2024,SELL,GOOGL,ALPHABET INC CLASS A,EQUITY,5,140.25,$0.00,$0.00,$0.00,$701.25,01/22/2024''';

      final csvFile = File('${tempDir.path}/test_stocks.csv');
      await csvFile.writeAsString(csvContent);

      // Parse the CSV
      final result =
          await FidelityCsvImportService.parseTransactionsCsv(csvFile);

      final instrumentOrders =
          (result['instrumentOrders'] as List).cast<InstrumentOrder>();
      final optionOrders = (result['optionOrders'] as List).cast<OptionOrder>();

      // Verify stock transactions
      expect(instrumentOrders.length, 2);
      expect(optionOrders.length, 0);

      // Check first transaction (BUY)
      final buyOrder = instrumentOrders[0];
      expect(buyOrder.instrumentId, 'AAPL');
      expect(buyOrder.side, 'buy');
      expect(buyOrder.quantity, 10);
      expect(buyOrder.averagePrice, 150.50);
      expect(buyOrder.state, 'filled');

      // Check second transaction (SELL)
      final sellOrder = instrumentOrders[1];
      expect(sellOrder.instrumentId, 'GOOGL');
      expect(sellOrder.side, 'sell');
      expect(sellOrder.quantity, 5);
      expect(sellOrder.averagePrice, 140.25);
    });

    test('parses option transaction CSV correctly', () async {
      // Create a test CSV with option transactions
      final csvContent = '''Run Date,Action,Symbol,Security Description,Security Type,Quantity,Price,Commission,Fees,Accrued Interest,Amount,Settlement Date
02/01/2024,BUY TO OPEN,AAPL 02/16/2024 \$150 CALL,APPLE INC CALL OPTION,OPTION,1,5.50,$0.00,$0.65,$0.00,-$550.65,02/02/2024
02/10/2024,SELL TO CLOSE,AAPL 02/16/2024 \$150 CALL,APPLE INC CALL OPTION,OPTION,1,7.25,$0.00,$0.65,$0.00,$724.35,02/12/2024''';

      final csvFile = File('${tempDir.path}/test_options.csv');
      await csvFile.writeAsString(csvContent);

      // Parse the CSV
      final result =
          await FidelityCsvImportService.parseTransactionsCsv(csvFile);

      final instrumentOrders =
          (result['instrumentOrders'] as List).cast<InstrumentOrder>();
      final optionOrders = (result['optionOrders'] as List).cast<OptionOrder>();

      // Verify option transactions
      expect(instrumentOrders.length, 0);
      expect(optionOrders.length, 2);

      // Check first transaction (BUY TO OPEN)
      final buyOrder = optionOrders[0];
      expect(buyOrder.chainSymbol, 'AAPL');
      expect(buyOrder.direction, 'debit');
      expect(buyOrder.quantity, 1);
      expect(buyOrder.price, 5.50);
      expect(buyOrder.openingStrategy, 'long_call');
      expect(buyOrder.state, 'filled');

      // Check second transaction (SELL TO CLOSE)
      final sellOrder = optionOrders[1];
      expect(sellOrder.chainSymbol, 'AAPL');
      expect(sellOrder.direction, 'credit');
      expect(sellOrder.quantity, 1);
      expect(sellOrder.price, 7.25);
      expect(sellOrder.closingStrategy, 'long_call');
    });

    test('handles mixed stock and option transactions', () async {
      // Create a test CSV with both types
      final csvContent = '''Run Date,Action,Symbol,Security Description,Security Type,Quantity,Price,Commission,Fees,Accrued Interest,Amount,Settlement Date
01/15/2024,BUY,MSFT,MICROSOFT CORP,EQUITY,5,380.00,$0.00,$0.00,$0.00,-$1900.00,01/17/2024
02/01/2024,SELL TO OPEN,MSFT 03/15/2024 \$400 CALL,MICROSOFT CALL OPTION,OPTION,1,8.50,$0.00,$0.65,$0.00,$849.35,02/02/2024''';

      final csvFile = File('${tempDir.path}/test_mixed.csv');
      await csvFile.writeAsString(csvContent);

      // Parse the CSV
      final result =
          await FidelityCsvImportService.parseTransactionsCsv(csvFile);

      final instrumentOrders =
          (result['instrumentOrders'] as List).cast<InstrumentOrder>();
      final optionOrders = (result['optionOrders'] as List).cast<OptionOrder>();

      // Verify both types are present
      expect(instrumentOrders.length, 1);
      expect(optionOrders.length, 1);

      expect(instrumentOrders[0].instrumentId, 'MSFT');
      expect(optionOrders[0].chainSymbol, 'MSFT');
    });

    test('handles empty CSV file', () async {
      final csvFile = File('${tempDir.path}/test_empty.csv');
      await csvFile.writeAsString('');

      expect(
        () async =>
            await FidelityCsvImportService.parseTransactionsCsv(csvFile),
        throwsException,
      );
    });

    test('handles CSV with only header row', () async {
      final csvContent = '''Run Date,Action,Symbol,Security Description,Security Type,Quantity,Price,Commission,Fees,Accrued Interest,Amount,Settlement Date''';

      final csvFile = File('${tempDir.path}/test_header_only.csv');
      await csvFile.writeAsString(csvContent);

      final result =
          await FidelityCsvImportService.parseTransactionsCsv(csvFile);

      final instrumentOrders =
          (result['instrumentOrders'] as List).cast<InstrumentOrder>();
      final optionOrders = (result['optionOrders'] as List).cast<OptionOrder>();

      expect(instrumentOrders.length, 0);
      expect(optionOrders.length, 0);
    });

    test('handles CSV with metadata rows before header', () async {
      // Fidelity CSVs often have metadata at the top
      final csvContent = '''Account Number: 123456789
Account Name: John Doe
Date Range: 01/01/2024 - 12/31/2024

Run Date,Action,Symbol,Security Description,Security Type,Quantity,Price,Commission,Fees,Accrued Interest,Amount,Settlement Date
01/15/2024,BUY,TSLA,TESLA INC,EQUITY,2,200.00,$0.00,$0.00,$0.00,-$400.00,01/17/2024''';

      final csvFile = File('${tempDir.path}/test_metadata.csv');
      await csvFile.writeAsString(csvContent);

      final result =
          await FidelityCsvImportService.parseTransactionsCsv(csvFile);

      final instrumentOrders =
          (result['instrumentOrders'] as List).cast<InstrumentOrder>();

      expect(instrumentOrders.length, 1);
      expect(instrumentOrders[0].instrumentId, 'TSLA');
    });

    test('parses PUT options correctly', () async {
      final csvContent = '''Run Date,Action,Symbol,Security Description,Security Type,Quantity,Price,Commission,Fees,Accrued Interest,Amount,Settlement Date
03/01/2024,BUY TO OPEN,SPY 03/29/2024 \$450 PUT,SPY PUT OPTION,OPTION,1,3.50,$0.00,$0.65,$0.00,-$350.65,03/02/2024''';

      final csvFile = File('${tempDir.path}/test_put.csv');
      await csvFile.writeAsString(csvContent);

      final result =
          await FidelityCsvImportService.parseTransactionsCsv(csvFile);

      final optionOrders = (result['optionOrders'] as List).cast<OptionOrder>();

      expect(optionOrders.length, 1);
      expect(optionOrders[0].chainSymbol, 'SPY');
      expect(optionOrders[0].openingStrategy, 'long_put');
    });

    test('handles transactions with commas in numbers', () async {
      final csvContent = '''Run Date,Action,Symbol,Security Description,Security Type,Quantity,Price,Commission,Fees,Accrued Interest,Amount,Settlement Date
01/15/2024,BUY,BRK.B,BERKSHIRE HATHAWAY CLASS B,EQUITY,100,350.50,$1.50,$2.50,$0.00,-\$35,054.00,01/17/2024''';

      final csvFile = File('${tempDir.path}/test_commas.csv');
      await csvFile.writeAsString(csvContent);

      final result =
          await FidelityCsvImportService.parseTransactionsCsv(csvFile);

      final instrumentOrders =
          (result['instrumentOrders'] as List).cast<InstrumentOrder>();

      expect(instrumentOrders.length, 1);
      expect(instrumentOrders[0].quantity, 100);
      expect(instrumentOrders[0].averagePrice, 350.50);
      expect(instrumentOrders[0].fees, 4.0); // commission + fees
    });

    test('skips empty rows in CSV', () async {
      final csvContent = '''Run Date,Action,Symbol,Security Description,Security Type,Quantity,Price,Commission,Fees,Accrued Interest,Amount,Settlement Date
01/15/2024,BUY,AAPL,APPLE INC,EQUITY,10,150.50,$0.00,$0.00,$0.00,-$1505.00,01/17/2024

01/20/2024,SELL,GOOGL,ALPHABET INC CLASS A,EQUITY,5,140.25,$0.00,$0.00,$0.00,$701.25,01/22/2024''';

      final csvFile = File('${tempDir.path}/test_empty_rows.csv');
      await csvFile.writeAsString(csvContent);

      final result =
          await FidelityCsvImportService.parseTransactionsCsv(csvFile);

      final instrumentOrders =
          (result['instrumentOrders'] as List).cast<InstrumentOrder>();

      expect(instrumentOrders.length, 2);
    });
  });
}
