import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:robinhood_options_mobile/model/copy_trading_provider.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/widgets/copy_trade_request_detail_widget.dart';
import 'package:robinhood_options_mobile/widgets/copy_trade_requests_widget.dart';

class _MockCopyTradingProvider extends CopyTradingProvider {
  final List<CopyTradeRecord> mockRequests;
  CopyTradeRecord? approvedRecord;
  CopyTradeRecord? rejectedRecord;

  _MockCopyTradingProvider(this.mockRequests);

  @override
  Stream<List<CopyTradeRecord>> getTradeHistory() => Stream.value(mockRequests);

  @override
  Stream<List<CopyTradeRecord>> getRequests() => Stream.value(
        mockRequests
            .where(
                (r) => r.status == 'pending_approval' || r.status == 'rejected')
            .toList(),
      );

  @override
  Future<void> approveRequest(CopyTradeRecord record) async {
    approvedRecord = record;
  }

  @override
  Future<void> rejectRequest(CopyTradeRecord record) async {
    rejectedRecord = record;
  }
}

void main() {
  final testTimestamp = DateTime(2026, 11, 13, 10, 30);

  CopyTradeRecord createTestRecord({
    String id = 'req-1',
    String symbol = 'AAPL',
    String side = 'buy',
    String status = 'pending_approval',
    String orderType = 'instrument',
    String? sourceUserName = 'AliceTrader',
    double price = 150.0,
    double copiedQuantity = 10,
    double originalQuantity = 50,
    bool isInverse = false,
    List<CopyTradeLeg>? legs,
  }) {
    return CopyTradeRecord(
      id: id,
      sourceUserId: 'leader-uid-12345',
      sourceUserName: sourceUserName,
      targetUserId: 'follower-uid-67890',
      groupId: 'group-1',
      orderType: orderType,
      originalOrderId: 'orig-order-1',
      symbol: symbol,
      side: side,
      originalQuantity: originalQuantity,
      copiedQuantity: copiedQuantity,
      price: price,
      timestamp: testTimestamp,
      executed: status == 'executed',
      status: status,
      isInverse: isInverse,
      legs: legs,
    );
  }

  group('CopyTradeRecord Model Tests', () {
    test('serializes and deserializes sourceUserName correctly', () {
      final record = createTestRecord(sourceUserName: 'AlphaLeader');
      final json = record.toJson();
      expect(json['sourceUserName'], 'AlphaLeader');

      final fromJsonRecord = CopyTradeRecord.fromJson(json, 'test-id');
      expect(fromJsonRecord.sourceUserName, 'AlphaLeader');
      expect(fromJsonRecord.symbol, 'AAPL');
      expect(fromJsonRecord.price, 150.0);
    });
  });

  group('CopyTradeRequestDetailWidget Tests', () {
    testWidgets(
        'renders all request details and action buttons for pending stock',
        (tester) async {
      final record = createTestRecord(
        symbol: 'NVDA',
        side: 'buy',
        sourceUserName: 'TopTrader',
        price: 130.0,
        copiedQuantity: 15,
        status: 'pending_approval',
      );

      final mockProvider = _MockCopyTradingProvider([record]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CopyTradingProvider>.value(
                value: mockProvider),
            ChangeNotifierProvider(create: (_) => AccountStore()),
            ChangeNotifierProvider(create: (_) => AgenticTradingProvider()),
            ChangeNotifierProvider(create: (_) => BrokerageUserStore([], 0)),
            ChangeNotifierProvider(create: (_) => InstrumentStore()),
          ],
          child: MaterialApp(
            home: CopyTradeRequestDetailWidget(record: record),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header and badge verification
      expect(find.text('NVDA'), findsOneWidget);
      expect(find.text('Stock / Equity'), findsOneWidget);
      expect(find.text('Pending Approval'), findsOneWidget);
      expect(find.text('BUY'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text(r'$130.00'), findsOneWidget);
      expect(find.text(r'$1,950.00'), findsOneWidget); // 15 * 130

      // Leader section
      expect(find.text('TopTrader'), findsOneWidget);
      expect(find.text('50 shares'), findsOneWidget);

      // Buttons
      expect(find.text('Approve Request'), findsOneWidget);
      expect(find.text('Reject Request'), findsOneWidget);
      expect(find.text('Inspect NVDA Chart & Fundamentals'), findsOneWidget);
    });

    testWidgets('renders option request details with legs and strategy',
        (tester) async {
      final record = createTestRecord(
        symbol: 'TSLA',
        side: 'buy',
        orderType: 'option',
        sourceUserName: 'OptionsPro',
        price: 3.50,
        copiedQuantity: 2,
        status: 'pending_approval',
        legs: [
          CopyTradeLeg(
            optionType: 'call',
            strikePrice: 250.0,
            expirationDate: DateTime(2026, 12, 18),
            side: 'buy',
            positionEffect: 'open',
            ratioQuantity: 1,
          ),
        ],
      );

      final mockProvider = _MockCopyTradingProvider([record]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CopyTradingProvider>.value(
                value: mockProvider),
            ChangeNotifierProvider(create: (_) => AccountStore()),
            ChangeNotifierProvider(create: (_) => AgenticTradingProvider()),
            ChangeNotifierProvider(create: (_) => BrokerageUserStore([], 0)),
            ChangeNotifierProvider(create: (_) => InstrumentStore()),
          ],
          child: MaterialApp(
            home: CopyTradeRequestDetailWidget(record: record),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TSLA'), findsOneWidget);
      expect(find.text('Option Contract'), findsOneWidget);
      expect(find.text('Option Legs (1)'), findsOneWidget);
      expect(find.text('CALL \$250.00'), findsOneWidget);
      expect(find.text('Exp: 12/18/2026'), findsOneWidget);
      expect(find.text(r'$700.00'), findsOneWidget); // 2 * 3.50 * 100
    });

    testWidgets('rejects request when Reject button is tapped', (tester) async {
      final record = createTestRecord(status: 'pending_approval');
      final mockProvider = _MockCopyTradingProvider([record]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CopyTradingProvider>.value(
                value: mockProvider),
            ChangeNotifierProvider(create: (_) => AccountStore()),
            ChangeNotifierProvider(create: (_) => AgenticTradingProvider()),
            ChangeNotifierProvider(create: (_) => BrokerageUserStore([], 0)),
            ChangeNotifierProvider(create: (_) => InstrumentStore()),
          ],
          child: MaterialApp(
            home: CopyTradeRequestDetailWidget(record: record),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reject Request'));
      await tester.pumpAndSettle();

      expect(mockProvider.rejectedRecord, isNotNull);
      expect(mockProvider.rejectedRecord!.id, record.id);
    });
  });

  group('CopyTradeRequestsWidget Navigation Integration Tests', () {
    testWidgets('tapping request opens CopyTradeRequestDetailWidget',
        (tester) async {
      final record = createTestRecord(
        id: 'tap-target',
        symbol: 'AMZN',
        sourceUserName: 'AmazonBull',
      );
      final mockProvider = _MockCopyTradingProvider([record]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CopyTradingProvider>.value(
                value: mockProvider),
            ChangeNotifierProvider(create: (_) => AccountStore()),
            ChangeNotifierProvider(create: (_) => AgenticTradingProvider()),
            ChangeNotifierProvider(create: (_) => BrokerageUserStore([], 0)),
            ChangeNotifierProvider(create: (_) => InstrumentStore()),
          ],
          child: const MaterialApp(
            home: CopyTradeRequestsWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check card is rendered with sourceUserName
      expect(find.text('AMZN'), findsOneWidget);
      expect(find.text('From: AmazonBull'), findsOneWidget);

      // Tap on the card
      await tester.tap(find.text('AMZN'));
      await tester.pumpAndSettle();

      // Verify detail widget is pushed
      expect(find.byType(CopyTradeRequestDetailWidget), findsOneWidget);
      expect(find.text('AMZN Copy Trade'), findsOneWidget);
      expect(find.text('AmazonBull'), findsOneWidget);
    });

    testWidgets('initialRecordId automatically opens detail widget',
        (tester) async {
      final record = createTestRecord(
        id: 'notification-record-123',
        symbol: 'MSFT',
        sourceUserName: 'SatyaTrader',
      );
      final mockProvider = _MockCopyTradingProvider([record]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CopyTradingProvider>.value(
                value: mockProvider),
            ChangeNotifierProvider(create: (_) => AccountStore()),
            ChangeNotifierProvider(create: (_) => AgenticTradingProvider()),
            ChangeNotifierProvider(create: (_) => BrokerageUserStore([], 0)),
            ChangeNotifierProvider(create: (_) => InstrumentStore()),
          ],
          child: const MaterialApp(
            home: CopyTradeRequestsWidget(
              initialRecordId: 'notification-record-123',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The detail widget should be automatically opened
      expect(find.byType(CopyTradeRequestDetailWidget), findsOneWidget);
      expect(find.text('MSFT'), findsWidgets);
      expect(find.text('SatyaTrader'), findsOneWidget);
    });
  });
}
