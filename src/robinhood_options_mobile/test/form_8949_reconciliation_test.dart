import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/form_8949_model.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/wash_sale_record.dart';
import 'package:robinhood_options_mobile/services/tax_optimization_service.dart';

void main() {
  InstrumentOrder createStockOrder({
    required String id,
    required String symbol,
    required String side,
    required double price,
    required double quantity,
    required DateTime date,
    String state = 'filled',
  }) {
    final order = InstrumentOrder(
      id,
      id,
      'https://api.robinhood.com/orders/$id/',
      'account_1',
      '',
      null,
      'https://api.robinhood.com/instruments/$symbol/',
      symbol,
      quantity,
      price,
      0.0,
      state,
      null,
      'market',
      side,
      'gtc',
      'immediate',
      price,
      null,
      quantity,
      null,
      date,
      date,
      null,
    );
    order.instrumentObj = Instrument.forSymbol(symbol);
    return order;
  }

  OptionOrder createOptionOrder({
    required String id,
    required String chainSymbol,
    required String direction, // 'debit' for buy, 'credit' for sell
    required double price,
    required double quantity,
    required DateTime date,
    String state = 'filled',
  }) {
    return OptionOrder(
      id,
      'chain_$chainSymbol',
      chainSymbol,
      null,
      0.0,
      direction,
      [],
      0.0,
      price * quantity * 100,
      price * quantity * 100,
      price,
      quantity,
      quantity,
      id,
      state,
      'gtc',
      'immediate',
      'limit',
      null,
      'long_call',
      null,
      null,
      date,
      date,
    );
  }

  group('Form8949Entry Model Tests', () {
    test('calculates short-term entry (<= 365 days) correctly with Box A', () {
      final acq = DateTime(2026, 2, 1);
      final sold = DateTime(2026, 6, 1); // 120 days
      final entry = Form8949Entry.create(
        id: 'entry_st_1',
        description: '10 sh. AAPL',
        symbol: 'AAPL',
        assetType: 'stock',
        quantity: 10,
        acquiredDate: acq,
        soldDate: sold,
        proceeds: 2000.0,
        costBasis: 1500.0,
      );

      expect(entry.isLongTerm, isFalse);
      expect(entry.boxCategory, 'A');
      expect(entry.holdingDays, 120);
      expect(entry.gainOrLoss, 500.0);
      expect(entry.tentativeGainOrLoss, 500.0);
      expect(entry.hasWashSale, isFalse);
    });

    test('calculates long-term entry (> 365 days) correctly with Box D', () {
      final acq = DateTime(2024, 5, 1);
      final sold = DateTime(2026, 6, 1); // > 2 years
      final entry = Form8949Entry.create(
        id: 'entry_lt_1',
        description: '50 sh. MSFT',
        symbol: 'MSFT',
        assetType: 'stock',
        quantity: 50,
        acquiredDate: acq,
        soldDate: sold,
        proceeds: 21000.0,
        costBasis: 15000.0,
      );

      expect(entry.isLongTerm, isTrue);
      expect(entry.boxCategory, 'D');
      expect(entry.holdingDays, greaterThan(365));
      expect(entry.gainOrLoss, 6000.0);
      expect(entry.hasWashSale, isFalse);
    });

    test('reconciles wash sale with adjustment code W per IRS instructions',
        () {
      // Sold 20 shares NVDA at $2,200 with $2,600 cost basis -> tentative loss -$400
      // Repurchased within 30 days -> wash sale disallows $400
      // Reconciled Column (h) = $2,200 - $2,600 + $400 = $0.00
      final acq = DateTime(2026, 3, 1);
      final sold = DateTime(2026, 4, 15);
      final entry = Form8949Entry.create(
        id: 'entry_ws_1',
        description: '20 sh. NVDA',
        symbol: 'NVDA',
        assetType: 'stock',
        quantity: 20,
        acquiredDate: acq,
        soldDate: sold,
        proceeds: 2200.0,
        costBasis: 2600.0,
        adjustmentCode: 'W',
        adjustmentAmount: 400.0,
      );

      expect(entry.isLongTerm, isFalse);
      expect(entry.tentativeGainOrLoss, -400.0);
      expect(entry.adjustmentCode, 'W');
      expect(entry.adjustmentAmount, 400.0);
      expect(entry.gainOrLoss, 0.0);
      expect(entry.hasWashSale, isTrue);
    });
  });

  group('Form8949Totals Tests', () {
    test('aggregates subtotals across multiple entries', () {
      final entries = [
        Form8949Entry.create(
          id: '1',
          description: '10 sh. AAPL',
          symbol: 'AAPL',
          assetType: 'stock',
          quantity: 10,
          acquiredDate: DateTime(2026, 1, 1),
          soldDate: DateTime(2026, 3, 1),
          proceeds: 1500.0,
          costBasis: 1200.0, // Gain = +$300
        ),
        Form8949Entry.create(
          id: '2',
          description: '5 sh. TSLA',
          symbol: 'TSLA',
          assetType: 'stock',
          quantity: 5,
          acquiredDate: DateTime(2026, 2, 1),
          soldDate: DateTime(2026, 4, 1),
          proceeds: 1000.0,
          costBasis: 1300.0,
          adjustmentCode: 'W',
          adjustmentAmount: 200.0, // Tentative -$300 + $200 = -$100
        ),
      ];

      final totals = Form8949Totals.fromEntries(entries);
      expect(totals.transactionCount, 2);
      expect(totals.totalProceeds, 2500.0);
      expect(totals.totalCostBasis, 2500.0);
      expect(totals.totalAdjustments, 200.0);
      expect(totals.totalGainOrLoss, 200.0); // +$300 - $100 = +$200
    });
  });

  group('TaxOptimizationService reconcileForm8949 Tests', () {
    test('generates demo reconciliation when no orders are supplied', () {
      final recon = TaxOptimizationService.reconcileForm8949(
        taxYear: 2026,
        asOf: DateTime(2026, 10, 1),
      );

      expect(recon.allEntries.isNotEmpty, isTrue);
      expect(recon.shortTermEntries.isNotEmpty, isTrue);
      expect(recon.longTermEntries.isNotEmpty, isTrue);
      expect(recon.totalTransactions, recon.allEntries.length);
      expect(recon.totalWashSaleDisallowed, greaterThan(0));

      final hasWashSale = recon.allEntries.any((e) => e.hasWashSale);
      expect(hasWashSale, isTrue);
    });

    test('reconciles live stock orders and matches wash sales', () {
      final saleDate = DateTime(2026, 5, 10, 14, 30);
      final buyDate = DateTime(2026, 2, 10, 10, 0);

      final buyOrder = createStockOrder(
        id: 'buy_1',
        symbol: 'AAPL',
        side: 'buy',
        price: 180.0,
        quantity: 10.0,
        date: buyDate,
      );

      final sellOrder = createStockOrder(
        id: 'sell_1',
        symbol: 'AAPL',
        side: 'sell',
        price: 160.0,
        quantity: 10.0,
        date: saleDate,
      );

      // Realized loss = (160 - 180) * 10 = -$200.
      final washSale = WashSaleRecord(
        id: 'ws_1',
        symbol: 'AAPL',
        name: 'Apple Inc.',
        assetType: 'stock',
        saleDate: saleDate,
        salePrice: 160.0,
        quantitySold: 10.0,
        realizedLoss: -200.0,
        windowStartDate: saleDate.subtract(const Duration(days: 30)),
        windowEndDate: saleDate.add(const Duration(days: 30)),
        status: WashSaleStatus.disallowed,
        disallowedLoss: 200.0,
      );

      final recon = TaxOptimizationService.reconcileForm8949(
        stockOrders: [buyOrder, sellOrder],
        washSales: [washSale],
        taxYear: 2026,
      );

      expect(recon.allEntries.length, 1);
      final entry = recon.allEntries.first;
      expect(entry.symbol, 'AAPL');
      expect(entry.proceeds, 1600.0);
      expect(entry.costBasis, 1800.0);
      expect(entry.adjustmentCode, 'W');
      expect(entry.adjustmentAmount, 200.0);
      expect(entry.gainOrLoss, 0.0); // -$200 + $200
      expect(entry.isLongTerm, isFalse);
    });

    test('reconciles option closing credit order', () {
      final buyDate = DateTime(2026, 3, 1);
      final sellDate = DateTime(2026, 4, 15);

      final debitOrder = createOptionOrder(
        id: 'opt_buy',
        chainSymbol: 'SPY',
        direction: 'debit',
        price: 5.0,
        quantity: 1.0,
        date: buyDate,
      );

      final creditOrder = createOptionOrder(
        id: 'opt_sell',
        chainSymbol: 'SPY',
        direction: 'credit',
        price: 8.0,
        quantity: 1.0,
        date: sellDate,
      );

      final recon = TaxOptimizationService.reconcileForm8949(
        optionOrders: [debitOrder, creditOrder],
        taxYear: 2026,
      );

      expect(recon.allEntries.length, 1);
      final entry = recon.allEntries.first;
      expect(entry.symbol, 'SPY');
      expect(entry.proceeds, 800.0);
      expect(entry.costBasis, 500.0);
      expect(entry.gainOrLoss, 300.0);
      expect(entry.isLongTerm, isFalse);
    });

    test('filters by tax year correctly', () {
      final entries = [
        Form8949Entry.create(
          id: '2025_1',
          description: '10 sh. AAPL',
          symbol: 'AAPL',
          assetType: 'stock',
          quantity: 10,
          acquiredDate: DateTime(2025, 1, 1),
          soldDate: DateTime(2025, 6, 1),
          proceeds: 1500.0,
          costBasis: 1200.0,
        ),
        Form8949Entry.create(
          id: '2026_1',
          description: '10 sh. MSFT',
          symbol: 'MSFT',
          assetType: 'stock',
          quantity: 10,
          acquiredDate: DateTime(2026, 1, 1),
          soldDate: DateTime(2026, 6, 1),
          proceeds: 3500.0,
          costBasis: 3000.0,
        ),
      ];

      final recon2026 = TaxOptimizationService.reconcileForm8949(
        initialEntries: entries,
        taxYear: 2026,
      );
      expect(recon2026.allEntries.length, 1);
      expect(recon2026.allEntries.first.symbol, 'MSFT');

      final reconAll = TaxOptimizationService.reconcileForm8949(
        initialEntries: entries,
        taxYear: null,
      );
      expect(reconAll.allEntries.length, 2);
    });
  });

  group('Form8949 CSV Generation Tests', () {
    test('exports RFC 4180 CSV containing Part I, Part II, Code W, and totals',
        () {
      final recon = TaxOptimizationService.reconcileForm8949(
        taxYear: 2026,
        asOf: DateTime(2026, 10, 1),
      );

      final csv = recon.toCsv();

      // Headers & metadata
      expect(csv, contains('IRS Form 8949 & Schedule D Reconciliation'));
      expect(csv, contains('Tax Year,2026'));
      expect(csv, contains('Part I: Short-Term Capital Gains and Losses'));
      expect(csv, contains('Part II: Long-Term Capital Gains and Losses'));

      // Standard Column Names (a) - (h)
      expect(csv, contains('(a) Description of property'));
      expect(csv, contains('(d) Proceeds (sales price)'));
      expect(csv, contains('(e) Cost or other basis'));
      expect(csv, contains('(f) Code(s) from instructions'));
      expect(csv, contains('(g) Amount of adjustment'));
      expect(csv, contains('(h) Gain or loss'));

      // Data and Totals
      expect(csv, contains('Totals for Part I (Short-Term)'));
      expect(csv, contains('Totals for Part II (Long-Term)'));
      expect(csv, contains('Grand Totals (Schedule D Net Capital Gain/Loss)'));
      expect(csv, contains('Total Disallowed Wash Sales (Code W)'));
      expect(csv, contains('W')); // Wash sale code present
    });
  });
}
