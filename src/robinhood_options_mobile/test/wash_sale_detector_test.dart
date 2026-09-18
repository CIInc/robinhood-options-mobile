import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/model/wash_sale_record.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';
import 'package:robinhood_options_mobile/services/tax_optimization_service.dart';

void main() {
  group('WashSaleRecord Model Tests', () {
    final now = DateTime(2026, 10, 15, 12, 0);

    test('serializes and deserializes WashSaleRecord JSON correctly', () {
      final record = WashSaleRecord(
        id: 'ws_test_1',
        symbol: 'TSLA',
        name: 'Tesla, Inc.',
        assetType: 'stock',
        saleDate: DateTime(2026, 10, 5),
        salePrice: 210.0,
        quantitySold: 10.0,
        realizedLoss: -400.0,
        windowStartDate: DateTime(2026, 9, 5),
        windowEndDate: DateTime(2026, 11, 4),
        status: WashSaleStatus.activeWindow,
      );

      final json = record.toJson();
      final parsed = WashSaleRecord.fromJson(json);

      expect(parsed.id, 'ws_test_1');
      expect(parsed.symbol, 'TSLA');
      expect(parsed.name, 'Tesla, Inc.');
      expect(parsed.realizedLoss, -400.0);
      expect(parsed.status, WashSaleStatus.activeWindow);
      expect(parsed.isWindowActive(now), isTrue);
      expect(parsed.isDisallowed, isFalse);
    });

    test('computes days remaining and safe repurchase date correctly', () {
      final saleDate = DateTime(2026, 10, 1);
      final windowEnd = DateTime(2026, 10, 31);
      final record = WashSaleRecord(
        id: 'ws_active_1',
        symbol: 'AAPL',
        name: 'Apple Inc.',
        assetType: 'stock',
        saleDate: saleDate,
        salePrice: 220.0,
        quantitySold: 15.0,
        realizedLoss: -300.0,
        windowStartDate: DateTime(2026, 9, 1),
        windowEndDate: windowEnd,
        status: WashSaleStatus.activeWindow,
      );

      // As of Oct 15
      final asOf = DateTime(2026, 10, 15);
      expect(record.getDaysRemaining(asOf), 17);
      expect(record.isWindowActive(asOf), isTrue);
      expect(record.safeRepurchaseDate, DateTime(2026, 11, 1));

      // After Nov 1
      final afterDate = DateTime(2026, 11, 2);
      expect(record.getDaysRemaining(afterDate), 0);
      expect(record.isWindowActive(afterDate), isFalse);
    });

    test('handles disallowed wash sale details and basis adjustments', () {
      final record = WashSaleRecord(
        id: 'ws_disallowed_1',
        symbol: 'NVDA',
        name: 'NVIDIA Corp.',
        assetType: 'stock',
        saleDate: DateTime(2026, 10, 1),
        salePrice: 115.0,
        quantitySold: 20.0,
        realizedLoss: -500.0,
        windowStartDate: DateTime(2026, 9, 1),
        windowEndDate: DateTime(2026, 10, 31),
        status: WashSaleStatus.disallowed,
        replacementDate: DateTime(2026, 10, 10),
        replacementPrice: 120.0,
        replacementQuantity: 20.0,
        replacementAssetType: 'stock',
        disallowedLoss: 500.0,
        adjustedCostBasis: (120.0 * 20.0) + 500.0,
      );

      expect(record.isDisallowed, isTrue);
      expect(record.isWindowActive(), isFalse);
      expect(record.disallowedLoss, 500.0);
      expect(record.adjustedCostBasis, 2900.0);
    });
  });

  group('TaxOptimizationService.detectWashSales Engine Tests', () {
    final asOfDate = DateTime(2026, 10, 20);

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
      required String direction, // 'debit' for buy
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

    test('detects active 30-day wash sale window when sold at a loss without repurchase', () {
      final buyOrder = createStockOrder(
        id: 'buy_1',
        symbol: 'TSLA',
        side: 'buy',
        price: 250.0,
        quantity: 10.0,
        date: DateTime(2026, 9, 15),
      );

      final sellOrder = createStockOrder(
        id: 'sell_1',
        symbol: 'TSLA',
        side: 'sell',
        price: 200.0,
        quantity: 10.0,
        date: DateTime(2026, 10, 10), // Sold at loss of $500 10 days before asOfDate
      );

      final washSales = TaxOptimizationService.detectWashSales(
        stockOrders: [buyOrder, sellOrder],
        asOf: asOfDate,
      );

      expect(washSales.isNotEmpty, isTrue);
      final record = washSales.firstWhere((w) => w.symbol == 'TSLA');
      expect(record.status, WashSaleStatus.activeWindow);
      expect(record.realizedLoss, -500.0);
      expect(record.isWindowActive(asOfDate), isTrue);
      expect(record.getDaysRemaining(asOfDate), 21); // Window ends Nov 9
    });

    test('detects triggered wash sale when replacement stock is bought within 30 days', () {
      final buy1 = createStockOrder(
        id: 'buy_initial',
        symbol: 'AMD',
        side: 'buy',
        price: 150.0,
        quantity: 20.0,
        date: DateTime(2026, 9, 1),
      );

      final sellLoss = createStockOrder(
        id: 'sell_loss',
        symbol: 'AMD',
        side: 'sell',
        price: 130.0,
        quantity: 20.0,
        date: DateTime(2026, 10, 5), // Loss = -$400
      );

      final buyReplacement = createStockOrder(
        id: 'buy_rep',
        symbol: 'AMD',
        side: 'buy',
        price: 135.0,
        quantity: 20.0,
        date: DateTime(2026, 10, 12), // Repurchased 7 days later
      );

      final washSales = TaxOptimizationService.detectWashSales(
        stockOrders: [buy1, sellLoss, buyReplacement],
        asOf: asOfDate,
      );

      final record = washSales.firstWhere((w) => w.symbol == 'AMD');
      expect(record.status, WashSaleStatus.disallowed);
      expect(record.isDisallowed, isTrue);
      expect(record.disallowedLoss, 400.0);
      expect(record.replacementAssetType, 'stock');
      expect(record.adjustedCostBasis, (135.0 * 20.0) + 400.0);
    });

    test('detects cross-instrument wash sale when call option is purchased on loss stock', () {
      final stockBuy = createStockOrder(
        id: 'stock_buy',
        symbol: 'NVDA',
        side: 'buy',
        price: 130.0,
        quantity: 10.0,
        date: DateTime(2026, 9, 10),
      );

      final stockSell = createStockOrder(
        id: 'stock_sell',
        symbol: 'NVDA',
        side: 'sell',
        price: 110.0,
        quantity: 10.0,
        date: DateTime(2026, 10, 2), // Loss = -$200
      );

      final optionBuy = createOptionOrder(
        id: 'option_call_buy',
        chainSymbol: 'NVDA',
        direction: 'debit', // Long Call contract
        price: 5.50,
        quantity: 1.0,
        date: DateTime(2026, 10, 14), // Purchased Call 12 days later
      );

      final washSales = TaxOptimizationService.detectWashSales(
        stockOrders: [stockBuy, stockSell],
        optionOrders: [optionBuy],
        asOf: asOfDate,
      );

      final record = washSales.firstWhere((w) => w.symbol == 'NVDA');
      expect(record.status, WashSaleStatus.disallowed);
      expect(record.isDisallowed, isTrue);
      expect(record.replacementAssetType, 'option');
      expect(record.disallowedLoss, 200.0);
    });

    test('marks window as cleared when 30 days pass without repurchase', () {
      final stockBuy = createStockOrder(
        id: 'b1',
        symbol: 'MSFT',
        side: 'buy',
        price: 420.0,
        quantity: 5.0,
        date: DateTime(2026, 8, 1),
      );

      final stockSell = createStockOrder(
        id: 's1',
        symbol: 'MSFT',
        side: 'sell',
        price: 400.0,
        quantity: 5.0,
        date: DateTime(2026, 8, 15), // 66 days before Oct 20
      );

      final washSales = TaxOptimizationService.detectWashSales(
        stockOrders: [stockBuy, stockSell],
        asOf: asOfDate,
      );

      final record = washSales.firstWhere((w) => w.symbol == 'MSFT');
      expect(record.status, WashSaleStatus.cleared);
      expect(record.isCleared(asOfDate), isTrue);
      expect(record.isWindowActive(asOfDate), isFalse);
    });

    test('incorporates and updates initial demo records correctly', () {
      final demoRecords = DemoService().getDemoWashSales(asOfDate);
      expect(demoRecords.length, 3);

      final washSales = TaxOptimizationService.detectWashSales(
        initialRecords: demoRecords,
        asOf: asOfDate,
      );

      expect(washSales.any((w) => w.symbol == 'TSLA' && w.isWindowActive(asOfDate)), isTrue);
      expect(washSales.any((w) => w.symbol == 'NVDA' && w.isDisallowed), isTrue);
      expect(washSales.any((w) => w.symbol == 'AAPL' && w.isCleared(asOfDate)), isTrue);
    });
  });

  group('PortfolioAlertService Wash Sale Integration Tests', () {
    final now = DateTime(2026, 10, 15);

    test('generates critical alert for disallowed wash sales', () {
      final disallowedRecord = WashSaleRecord(
        id: 'w1',
        symbol: 'NVDA',
        name: 'NVIDIA Corporation',
        assetType: 'stock',
        saleDate: now.subtract(const Duration(days: 10)),
        salePrice: 110.0,
        quantitySold: 10.0,
        realizedLoss: -300.0,
        windowStartDate: now.subtract(const Duration(days: 40)),
        windowEndDate: now.subtract(const Duration(days: 10)).add(const Duration(days: 30)),
        status: WashSaleStatus.disallowed,
        disallowedLoss: 300.0,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        washSales: [disallowedRecord],
      );

      expect(alerts.any((a) => a.id == 'wash-sale-disallowed'), isTrue);
      final alert = alerts.firstWhere((a) => a.id == 'wash-sale-disallowed');
      expect(alert.severity, PortfolioAlertSeverity.critical);
      expect(alert.title, contains('1 disallowed wash sale'));
      expect(alert.detail, contains('NVDA'));
      expect(alert.target, PortfolioAlertTarget.taxes);
    });

    test('generates warning alert for active wash sale restriction windows', () {
      final activeRecord = WashSaleRecord(
        id: 'w2',
        symbol: 'TSLA',
        name: 'Tesla, Inc.',
        assetType: 'stock',
        saleDate: now.subtract(const Duration(days: 12)),
        salePrice: 215.0,
        quantitySold: 20.0,
        realizedLoss: -450.0,
        windowStartDate: now.subtract(const Duration(days: 42)),
        windowEndDate: now.subtract(const Duration(days: 12)).add(const Duration(days: 30)),
        status: WashSaleStatus.activeWindow,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        washSales: [activeRecord],
      );

      expect(alerts.any((a) => a.id == 'wash-sale-window'), isTrue);
      final alert = alerts.firstWhere((a) => a.id == 'wash-sale-window');
      expect(alert.severity, PortfolioAlertSeverity.warning);
      expect(alert.title, contains('1 active wash sale window'));
      expect(alert.detail, contains('TSLA'));
      expect(alert.target, PortfolioAlertTarget.taxes);
    });
  });
}
