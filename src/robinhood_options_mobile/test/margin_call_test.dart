import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/margin_call.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';

void main() {
  group('MarginCall Model Tests', () {
    test('parses active maintenance call correctly', () {
      final now = DateTime.now();
      final due = now.add(const Duration(days: 2));
      final json = {
        'id': 'mc_123',
        'account': 'https://api.robinhood.com/accounts/5QR99999/',
        'type': 'maintenance',
        'state': 'open',
        'amount': 1250.50,
        'cash_deficit': 1250.50,
        'equity_deficit': 2501.00,
        'created_at': now.toIso8601String(),
        'due_date': due.toIso8601String(),
        'reason': 'Equity below 30% maintenance threshold.',
      };

      final call = MarginCall.fromJson(json);

      expect(call.id, 'mc_123');
      expect(call.accountNumber, '5QR99999');
      expect(call.type, MarginCallType.maintenance);
      expect(call.state, MarginCallState.open);
      expect(call.amount, 1250.50);
      expect(call.cashDeficit, 1250.50);
      expect(call.equityDeficit, 2501.00);
      expect(call.isOpen, isTrue);
      expect(call.isSatisfied, isFalse);
      expect(call.isOverdue, isFalse);
      expect(call.displayType, 'Maintenance Call');
      expect(call.displayState, 'Active Deficit');
      expect(call.formattedAmount, contains('1,250.50'));
    });

    test('parses federal and day trade calls with varied keys', () {
      final regTJson = {
        'id': 'regt_call_1',
        'call_type': 'regulation_t',
        'status': 'open',
        'deficit': '500.00',
      };
      final regT = MarginCall.fromJson(regTJson);
      expect(regT.type, MarginCallType.federal);
      expect(regT.amount, 500.00);
      expect(regT.displayType, 'Regulation T Call');

      final dayTradeJson = {
        'id': 'dt_call_1',
        'call_type': 'day_trade_call',
        'status': 'satisfied',
        'demand_amount': 2000,
        'satisfied_at': '2026-09-10T12:00:00Z',
      };
      final dt = MarginCall.fromJson(dayTradeJson);
      expect(dt.type, MarginCallType.dayTrade);
      expect(dt.state, MarginCallState.satisfied);
      expect(dt.amount, 2000.00);
      expect(dt.isSatisfied, isTrue);
      expect(dt.displayType, 'Day Trade Call');
      expect(dt.displayState, 'Satisfied');
    });

    test('detects overdue calls', () {
      final pastDue = DateTime.now().subtract(const Duration(hours: 4));
      final call = MarginCall(
        id: 'past_due',
        amount: 300,
        state: MarginCallState.open,
        dueDate: pastDue,
      );

      expect(call.isOverdue, isTrue);
      expect(call.displayState, 'Overdue');
    });

    test('serializes to json roundtrip', () {
      final now = DateTime.now();
      final call = MarginCall(
        id: 'roundtrip_call',
        accountNumber: 'ACC123',
        type: MarginCallType.house,
        state: MarginCallState.open,
        amount: 750.25,
        createdAt: now,
        dueDate: now.add(const Duration(days: 1)),
      );

      final json = call.toJson();
      expect(json['id'], 'roundtrip_call');
      expect(json['type'], 'house');
      expect(json['state'], 'open');
      expect(json['amount'], 750.25);

      final restored = MarginCall.fromJson(json);
      expect(restored.id, call.id);
      expect(restored.type, call.type);
      expect(restored.amount, call.amount);
    });
  });

  group('MarginInterestCharge Model Tests', () {
    test('parses monthly margin interest debit correctly', () {
      final effDate = DateTime(2026, 8, 31);
      final json = {
        'id': 'mic_aug_26',
        'account_number': '5QR12345',
        'amount': '42.50',
        'state': 'posted',
        'effective_date': effDate.toIso8601String(),
        'interest_rate': '0.065',
        'settled_amount_borrowed': '7846.15',
        'description': 'Margin Interest Charge for August 2026',
      };

      final charge = MarginInterestCharge.fromJson(json);

      expect(charge.id, 'mic_aug_26');
      expect(charge.amount, 42.50);
      expect(charge.isPosted, isTrue);
      expect(charge.isPending, isFalse);
      expect(charge.interestRate, 0.065);
      expect(charge.settledAmountBorrowed, 7846.15);
      expect(charge.formattedAmount, contains('42.50'));
      expect(charge.formattedInterestRate, contains('6.5'));
    });

    test('normalizes whole percentage rates (e.g. 7.5 -> 0.075)', () {
      final json = {
        'id': 'mic_rate_norm',
        'amount': 25.00,
        'rate': 7.5,
      };

      final charge = MarginInterestCharge.fromJson(json);
      expect(charge.interestRate, closeTo(0.075, 0.0001));
    });

    test('serializes to json roundtrip', () {
      final charge = MarginInterestCharge(
        id: 'mic_test',
        accountNumber: 'ACC_99',
        amount: 35.20,
        effectiveDate: DateTime(2026, 7, 31),
        interestRate: 0.0675,
      );

      final json = charge.toJson();
      expect(json['id'], 'mic_test');
      expect(json['amount'], 35.20);
      expect(json['interest_rate'], 0.0675);

      final restored = MarginInterestCharge.fromJson(json);
      expect(restored.id, charge.id);
      expect(restored.amount, charge.amount);
      expect(restored.interestRate, charge.interestRate);
    });
  });

  group('MarginFinancingSummary Aggregation Tests', () {
    test('aggregates calls, deficits, and monthly financing costs', () {
      final now = DateTime.now();
      final rawCalls = [
        {
          'id': 'call_1',
          'type': 'maintenance',
          'state': 'open',
          'amount': 800.00,
          'due_date': now.add(const Duration(days: 2)).toIso8601String(),
        },
        {
          'id': 'call_2',
          'type': 'federal',
          'state': 'satisfied',
          'amount': 400.00,
          'due_date': now.subtract(const Duration(days: 10)).toIso8601String(),
        },
        {
          'id': 'call_3',
          'type': 'house',
          'state': 'open',
          'amount': 350.00,
          'due_date': now.add(const Duration(days: 4)).toIso8601String(),
        },
      ];

      final rawInterest = [
        {
          'id': 'mic_1',
          'amount': 40.00,
          'effective_date': DateTime(now.year, 8, 31).toIso8601String(),
          'interest_rate': 0.065,
        },
        {
          'id': 'mic_2',
          'amount': 35.00,
          'effective_date': DateTime(now.year, 7, 31).toIso8601String(),
          'interest_rate': 0.065,
        },
      ];

      final summary = MarginFinancingSummary.fromMarginCallsAndInterest(
        accountNumber: '5QR12345',
        rawCalls: rawCalls,
        rawInterestCharges: rawInterest,
      );

      expect(summary.accountNumber, '5QR12345');
      expect(summary.openCallsCount, 2);
      expect(summary.totalDeficitDemand, 1150.00);
      expect(summary.hasActiveMarginCall, isTrue);
      expect(summary.marginCalls.first.id, 'call_1'); // Open calls sorted first
      expect(summary.totalInterestYtd, 75.00);
      expect(summary.latestMonthlyCharge, 40.00);
      expect(summary.averageBorrowingRate, closeTo(0.065, 0.001));
    });

    test('DemoService returns populated margin calls and financing charges',
        () async {
      final service = DemoService();
      final mockUser = BrokerageUser(
        BrokerageSource.demo,
        'demo_user',
        null,
        null,
      );

      final calls = await service.getMarginCalls(mockUser);
      final interest = await service.getMarginInterestCharges(mockUser);

      expect(calls, isNotEmpty);
      expect(interest, isNotEmpty);

      final summary = MarginFinancingSummary.fromMarginCallsAndInterest(
        accountNumber: '5QR12345',
        rawCalls: calls,
        rawInterestCharges: interest,
      );

      expect(summary.marginCalls, isNotEmpty);
      expect(summary.interestCharges.length, greaterThanOrEqualTo(4));
      expect(summary.totalInterestYtd, greaterThan(0));
    });
  });

  group('PortfolioAlertService Margin Call Alerts', () {
    test('triggers critical alert on active margin call demand', () {
      final now = DateTime.now();
      final call = MarginCall(
        id: 'critical_call_1',
        type: MarginCallType.maintenance,
        state: MarginCallState.open,
        amount: 1500.00,
        dueDate: now.add(const Duration(days: 1)),
        reason: 'Maintenance deficit due to tech drop.',
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        marginCalls: [call],
      );

      final callAlerts =
          alerts.where((a) => a.id.startsWith('margin-call-')).toList();
      expect(callAlerts, hasLength(1));
      expect(callAlerts.first.severity, PortfolioAlertSeverity.critical);
      expect(callAlerts.first.title, contains('Maintenance Call active'));
      expect(callAlerts.first.title, contains('1,500'));
      expect(callAlerts.first.detail, contains('Immediate deposit'));
    });

    test('no margin call alerts for satisfied calls', () {
      final satisfied = MarginCall(
        id: 'sat_call_1',
        type: MarginCallType.maintenance,
        state: MarginCallState.satisfied,
        amount: 500.00,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        marginCalls: [satisfied],
      );

      final callAlerts =
          alerts.where((a) => a.id.startsWith('margin-call-')).toList();
      expect(callAlerts, isEmpty);
    });
  });
}
