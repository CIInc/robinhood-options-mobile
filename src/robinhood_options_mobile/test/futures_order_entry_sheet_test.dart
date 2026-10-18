import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/futures_order_entry_sheet.dart';

void main() {
  final brokerageUser =
      BrokerageUser(BrokerageSource.robinhood, 'test-user', null, null);

  testWidgets('reviews and submits a market futures order only after confirm',
      (tester) async {
    final service = _FuturesOrderService();
    await tester.pumpWidget(_app(service, brokerageUser));
    await tester.pumpAndSettle();

    expect(find.text('Live quote: \$5200.25'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('futures-order-quantity')), '2');
    await tester.tap(find.byKey(const ValueKey('review-futures-order')));
    await tester.pumpAndSettle();

    expect(find.text('Confirm futures order'), findsOneWidget);
    expect(service.placedOrders, isEmpty);
    await tester.tap(find.byKey(const ValueKey('confirm-futures-order')));
    await tester.pumpAndSettle();

    expect(service.placedOrders, hasLength(1));
    expect(service.placedOrders.single, {
      'accountId': 'account-1',
      'contractId': 'contract-1',
      'side': 'BUY',
      'quantity': 2,
      'orderType': 'MARKET',
      'limitPrice': null,
      'positionEffect': 'OPENING',
    });
  });

  testWidgets('submits a limit futures order at the entered price',
      (tester) async {
    final service = _FuturesOrderService();
    await tester.pumpWidget(_app(service, brokerageUser));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('futures-order-quantity')), '3');
    await tester.tap(find.byKey(const ValueKey('futures-order-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limit').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('futures-order-limit-price')), '5198.50');
    await tester.tap(find.byKey(const ValueKey('review-futures-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-futures-order')));
    await tester.pumpAndSettle();

    expect(service.placedOrders.single['orderType'], 'LIMIT');
    expect(service.placedOrders.single['limitPrice'], 5198.5);
  });

  testWidgets('closes an existing futures position on the opposite side',
      (tester) async {
    final service = _FuturesOrderService();
    await tester.pumpWidget(_app(service, brokerageUser, positionQuantity: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('futures-position-effect')),
      matching: find.text('Close'),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('futures-order-quantity')), '1');
    await tester.tap(find.byKey(const ValueKey('review-futures-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-futures-order')));
    await tester.pumpAndSettle();

    expect(service.placedOrders.single['side'], 'SELL');
    expect(service.placedOrders.single['positionEffect'], 'CLOSING');
  });

  testWidgets('does not allow closing more contracts than are open',
      (tester) async {
    final service = _FuturesOrderService();
    await tester.pumpWidget(_app(service, brokerageUser, positionQuantity: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('futures-position-effect')),
      matching: find.text('Close'),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('futures-order-quantity')), '3');
    await tester.tap(find.byKey(const ValueKey('review-futures-order')));
    await tester.pumpAndSettle();

    expect(
      find.text('Closing quantity cannot exceed the 2.0 open contracts.'),
      findsOneWidget,
    );
    expect(find.text('Confirm futures order'), findsNothing);
    expect(service.placedOrders, isEmpty);
  });

  testWidgets('requires explicit valid quantity before showing confirmation',
      (tester) async {
    final service = _FuturesOrderService();
    await tester.pumpWidget(_app(service, brokerageUser));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-futures-order')));
    await tester.pumpAndSettle();

    expect(
        find.text('Enter a positive whole-number quantity.'), findsOneWidget);
    expect(find.text('Confirm futures order'), findsNothing);
    expect(service.placedOrders, isEmpty);
  });

  testWidgets('surfaces order submission failures', (tester) async {
    final service = _FuturesOrderService()
      ..placeOrderError = StateError('broker rejected order');
    await tester.pumpWidget(_app(service, brokerageUser));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('futures-order-quantity')), '1');
    await tester.tap(find.byKey(const ValueKey('review-futures-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-futures-order')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Order was not submitted:'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-futures-order')), findsOneWidget);
  });
}

Widget _app(
  _FuturesOrderService service,
  BrokerageUser brokerageUser, {
  double? positionQuantity,
}) =>
    MaterialApp(
      home: Scaffold(
        body: FuturesOrderEntrySheet(
          service: service,
          brokerageUser: brokerageUser,
          accountId: 'account-1',
          contractId: 'contract-1',
          symbol: '/ES',
          positionQuantity: positionQuantity,
        ),
      ),
    );

class _FuturesOrderService extends Fake implements IBrokerageService {
  final List<Map<String, Object?>> placedOrders = [];
  Object? placeOrderError;

  @override
  Future<double?> getFuturesQuote(
          BrokerageUser user, String contractId) async =>
      5200.25;

  @override
  Future<dynamic> placeFuturesOrder(
    BrokerageUser user,
    String accountId,
    String contractId,
    String side,
    int quantity, {
    String orderType = 'MARKET',
    String orderTrigger = 'IMMEDIATE',
    double? limitPrice,
    double? stopPrice,
    String timeInForce = 'GTC',
    String positionEffect = 'OPENING',
  }) async {
    if (placeOrderError case final error?) throw error;
    placedOrders.add({
      'accountId': accountId,
      'contractId': contractId,
      'side': side,
      'quantity': quantity,
      'orderType': orderType,
      'limitPrice': limitPrice,
      'positionEffect': positionEffect,
    });
    return null;
  }
}
