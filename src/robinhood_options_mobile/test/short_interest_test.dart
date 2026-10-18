import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/short_interest.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  group('ShortInterest Model', () {
    test('parses short interest from raw map with decimal pc_freefloat', () {
      final json = {
        'instrument_id': 'inst_123',
        'symbol': 'AAPL',
        'pc_freefloat': 0.0285,
        'shares_short': 121400000,
        'shares_short_prior': 119800000,
        'short_interest_change': 1600000,
        'short_interest_change_pct': 0.0133,
        'days_to_cover': 1.9,
        'settlement_date': '2026-08-15',
        'free_float': 4260000000,
        'average_daily_volume': 63900000,
        'updated_at': '2026-08-28T00:00:00Z',
      };

      final si = ShortInterest.fromJson(json);

      expect(si.instrumentId, 'inst_123');
      expect(si.symbol, 'AAPL');
      expect(si.pcFreeFloat, 0.0285);
      expect(si.freeFloatPercentage, closeTo(2.85, 0.01));
      expect(si.sharesShort, 121400000);
      expect(si.sharesShortPrior, 119800000);
      expect(si.shortInterestChange, 1600000);
      expect(si.shortInterestChangePct, closeTo(0.0133, 0.0001));
      expect(si.daysToCover, 1.9);
      expect(si.settlementDate, DateTime(2026, 8, 15));
      expect(si.freeFloat, 4260000000);
      expect(si.averageDailyVolume, 63900000);
      expect(si.updatedAt, isNotNull);
    });

    test('parses short interest wrapped in results list', () {
      final json = {
        'results': [
          {
            'instrument_id': 'inst_456',
            'symbol': 'GME',
            'pc_freefloat': 24.5, // already percentage format
            'shares_short': 64500000,
            'shares_short_prior': 58200000,
            'days_to_cover': 6.4,
            'settlement_date': '2026-08-15',
          }
        ]
      };

      final si = ShortInterest.fromJson(json);

      expect(si.instrumentId, 'inst_456');
      expect(si.symbol, 'GME');
      expect(si.freeFloatPercentage, 24.5);
      expect(si.sharesShort, 64500000);
      expect(si.sharesShortPrior, 58200000);
      expect(si.shortInterestChange, 6300000); // inferred difference
      expect(si.shortInterestChangePct, closeTo(6300000 / 58200000, 0.0001));
      expect(si.daysToCover, 6.4);
    });

    test(
        'parses real Robinhood API short interest daily_data response accurately',
        () {
      final json = {
        "status": "SUCCESS",
        "data": [
          {
            "status": "SUCCESS",
            "data": {
              "symbol": "PCG",
              "instrument_id": "f87d7cd7-a842-47cc-9b32-c607d96e7dfb",
              "exchange_symbol": "NYSE",
              "daily_data": [
                {
                  "shares_short": "37485031.0485",
                  "shares_upper_bound": "45062286.3985",
                  "shares_lower_bound": "28715885.2164",
                  "pc_freefloat": "1.8",
                  "pc_freefloat_upper_bound": "2.1639",
                  "pc_freefloat_lower_bound": "1.3789",
                  "date": "2026-09-07"
                },
                {
                  "shares_short": "41010570.7579",
                  "shares_upper_bound": "59965035.1079",
                  "shares_lower_bound": "18356397.7737",
                  "pc_freefloat": "1.9693",
                  "pc_freefloat_upper_bound": "2.8795",
                  "pc_freefloat_lower_bound": "0.8815",
                  "date": "2026-09-08"
                },
                {
                  "shares_short": "38745955.5719",
                  "shares_upper_bound": "50392318.9219",
                  "shares_lower_bound": "25010769.7326",
                  "pc_freefloat": "1.8606",
                  "pc_freefloat_upper_bound": "2.4199",
                  "pc_freefloat_lower_bound": "1.201",
                  "date": "2026-09-09"
                }
              ]
            }
          }
        ]
      };

      final si =
          ShortInterest.fromJson(json, fallbackAverageDailyVolume: 20000000);

      expect(si.instrumentId, 'f87d7cd7-a842-47cc-9b32-c607d96e7dfb');
      expect(si.symbol, 'PCG');
      expect(si.freeFloatPercentage, closeTo(1.8606, 0.0001));
      expect(si.sharesShort, closeTo(38745955.5719, 0.01));
      expect(si.sharesShortPrior, closeTo(41010570.7579, 0.01));
      expect(
          si.shortInterestChange, closeTo(38745955.5719 - 41010570.7579, 0.01));
      expect(si.settlementDate, DateTime(2026, 9, 9));
      expect(si.sharesShortUpperBound, closeTo(50392318.9219, 0.01));
      expect(si.sharesShortLowerBound, closeTo(25010769.7326, 0.01));
      expect(si.pcFreeFloatUpperBound, closeTo(2.4199, 0.0001));
      expect(si.pcFreeFloatLowerBound, closeTo(1.201, 0.0001));
      expect(si.freeFloat, isNotNull);
      expect(si.daysToCover, closeTo(38745955.5719 / 20000000, 0.01));

      // Check summary construction with both responses
      final shortingJson = {
        "instrument":
            "https://api.robinhood.com/instruments/f87d7cd7-a842-47cc-9b32-c607d96e7dfb/",
        "instrument_id": "f87d7cd7-a842-47cc-9b32-c607d96e7dfb",
        "fee": "0.0000",
        "fee_timestamp": "2026-09-10T23:45:00Z",
        "inventory_range": ">1M",
        "inventory_timestamp": "2026-09-10T22:01:00.050936Z",
        "daily_fee": "0.0000",
        "created_at": "2025-08-06T23:11:01.583130Z",
        "updated_at": "2026-09-10T22:01:57.223877Z"
      };

      final summary = ShortInterestSummary.fromResponses(
        shortInterestResponse: json,
        shortingAvailabilityResponse: shortingJson,
        instrumentId: 'f87d7cd7-a842-47cc-9b32-c607d96e7dfb',
        symbol: 'PCG',
        fallbackAverageDailyVolume: 20000000,
      );

      expect(summary.hasData, isTrue);
      expect(summary.shortInterest!.freeFloatPercentage, closeTo(1.86, 0.01));
      expect(summary.shortInterest!.daysToCover, isNotNull);
      expect(summary.availability!.borrowFeeRatePercentage, 0.0);
      expect(summary.availability!.inventory, '>1M');
      expect(summary.squeezeRisk, ShortSqueezeRisk.low);
      expect(summary.borrowCostLevel, BorrowCostLevel.easyToBorrow);
    });

    test('handles missing or empty fields safely', () {
      final si = ShortInterest.fromJson({},
          fallbackInstrumentId: 'fallback_id', fallbackSymbol: 'XYZ');

      expect(si.instrumentId, 'fallback_id');
      expect(si.symbol, 'XYZ');
      expect(si.freeFloatPercentage, isNull);
      expect(si.sharesShort, isNull);
      expect(si.daysToCover, isNull);
      expect(si.settlementDate, isNull);
    });
  });

  group('ShortingAvailability Model', () {
    test('parses real Robinhood API shorting response accurately', () {
      final json = {
        "instrument":
            "https://api.robinhood.com/instruments/f87d7cd7-a842-47cc-9b32-c607d96e7dfb/",
        "instrument_id": "f87d7cd7-a842-47cc-9b32-c607d96e7dfb",
        "fee": "0.0000",
        "fee_timestamp": "2026-09-10T23:45:00Z",
        "inventory_range": ">1M",
        "inventory_timestamp": "2026-09-10T22:01:00.050936Z",
        "daily_fee": "0.0000",
        "created_at": "2025-08-06T23:11:01.583130Z",
        "updated_at": "2026-09-10T22:01:57.223877Z"
      };

      final avail = ShortingAvailability.fromJson(json);

      expect(avail.instrumentId, 'f87d7cd7-a842-47cc-9b32-c607d96e7dfb');
      expect(avail.canShort, isTrue);
      expect(avail.inventory, '>1M');
      expect(avail.borrowFeeRate, 0.0);
      expect(avail.borrowFeeRatePercentage, 0.0);
      expect(avail.isHardToBorrow, isFalse);
      expect(avail.updatedAt, isNotNull);

      // Verify Summary handles this with no N/A on borrow metrics
      final summary = ShortInterestSummary.fromResponses(
        shortingAvailabilityResponse: json,
        instrumentId: 'f87d7cd7-a842-47cc-9b32-c607d96e7dfb',
        symbol: 'AAPL',
      );

      expect(summary.hasData, isTrue);
      expect(summary.availability!.borrowFeeRatePercentage, 0.0);
      expect(summary.availability!.inventory, '>1M');
      expect(summary.borrowCostLevel, BorrowCostLevel.easyToBorrow);
    });

    test('parses availability details correctly', () {
      final json = {
        'instrument_id': 'inst_789',
        'can_short': true,
        'inventory': 'LOW',
        'borrow_fee_rate': 0.185, // 18.5%
        'is_hard_to_borrow': true,
        'hard_to_borrow_reason': 'High demand and tight loan availability',
        'margin_requirement': 2.0,
        'locate_required': true,
        'updated_at': '2026-09-08T14:30:00Z',
      };

      final avail = ShortingAvailability.fromJson(json);

      expect(avail.instrumentId, 'inst_789');
      expect(avail.canShort, isTrue);
      expect(avail.inventory, 'LOW');
      expect(avail.borrowFeeRate, 0.185);
      expect(avail.borrowFeeRatePercentage, closeTo(18.5, 0.01));
      expect(avail.isHardToBorrow, isTrue);
      expect(
          avail.hardToBorrowReason, 'High demand and tight loan availability');
      expect(avail.marginRequirement, 2.0);
      expect(avail.locateRequired, isTrue);
      expect(avail.updatedAt, isNotNull);
    });

    test('infers hard to borrow when inventory is LOW and fee > 5%', () {
      final json = {
        'instrument_id': 'inst_999',
        'inventory': 'LOW',
        'borrow_fee_rate': 0.08,
      };

      final avail = ShortingAvailability.fromJson(json);

      expect(avail.isHardToBorrow, isTrue);
      expect(avail.borrowFeeRatePercentage, closeTo(8.0, 0.01));
    });

    test('disallows shorting if inventory is NONE', () {
      final json = {
        'instrument_id': 'inst_none',
        'can_short': true,
        'inventory': 'NONE',
      };

      final avail = ShortingAvailability.fromJson(json);

      expect(avail.canShort, isFalse);
    });
  });

  group('ShortSqueezeRisk & BorrowCostLevel', () {
    test('computes Low Squeeze Risk for minimal short interest', () {
      final summary = ShortInterestSummary(
        instrumentId: 'inst_low',
        shortInterest: const ShortInterest(
          instrumentId: 'inst_low',
          pcFreeFloat: 0.02, // 2%
          daysToCover: 1.2,
        ),
        availability: const ShortingAvailability(
          instrumentId: 'inst_low',
          borrowFeeRate: 0.0035, // 0.35%
          inventory: 'HIGH',
        ),
      );

      expect(summary.squeezeRisk, ShortSqueezeRisk.low);
      expect(summary.squeezeRisk.label, 'Low Squeeze Risk');
      expect(summary.squeezeRisk.color, Colors.green);
      expect(summary.borrowCostLevel, BorrowCostLevel.easyToBorrow);
      expect(summary.borrowCostLevel.label, 'Easy to Borrow');
    });

    test('computes Moderate Squeeze Risk for 8% float short', () {
      final summary = ShortInterestSummary(
        instrumentId: 'inst_mod',
        shortInterest: const ShortInterest(
          instrumentId: 'inst_mod',
          pcFreeFloat: 0.08, // 8%
          daysToCover: 2.5,
        ),
        availability: const ShortingAvailability(
          instrumentId: 'inst_mod',
          borrowFeeRate: 0.015, // 1.5%
          inventory: 'MEDIUM',
        ),
      );

      expect(summary.squeezeRisk, ShortSqueezeRisk.moderate);
      expect(summary.borrowCostLevel, BorrowCostLevel.moderate);
      expect(summary.borrowCostLevel.label, 'Moderate Fee');
    });

    test('computes Elevated Squeeze Risk for 15% float short', () {
      final summary = ShortInterestSummary(
        instrumentId: 'inst_ele',
        shortInterest: const ShortInterest(
          instrumentId: 'inst_ele',
          pcFreeFloat: 0.15, // 15%
          daysToCover: 3.5,
        ),
        availability: const ShortingAvailability(
          instrumentId: 'inst_ele',
          borrowFeeRate: 0.06, // 6%
          inventory: 'MEDIUM',
        ),
      );

      expect(summary.squeezeRisk, ShortSqueezeRisk.elevated);
      expect(summary.borrowCostLevel, BorrowCostLevel.elevated);
      expect(summary.borrowCostLevel.label, 'Elevated Fee');
    });

    test('computes High Squeeze Risk for 24% float short and 5 DTC', () {
      final summary = ShortInterestSummary(
        instrumentId: 'inst_high',
        shortInterest: const ShortInterest(
          instrumentId: 'inst_high',
          pcFreeFloat: 0.24, // 24%
          daysToCover: 5.2,
        ),
        availability: const ShortingAvailability(
          instrumentId: 'inst_high',
          borrowFeeRate: 0.08, // 8%
          inventory: 'LOW',
        ),
      );

      expect(summary.squeezeRisk, ShortSqueezeRisk.high);
      expect(summary.squeezeRisk.label, 'High Squeeze Risk');
    });

    test(
        'computes Extreme Squeeze Risk for heavily shorted stock with high borrow fees',
        () {
      final summary = ShortInterestSummary(
        instrumentId: 'inst_ext',
        shortInterest: const ShortInterest(
          instrumentId: 'inst_ext',
          pcFreeFloat: 0.38, // 38%
          daysToCover: 8.5,
        ),
        availability: const ShortingAvailability(
          instrumentId: 'inst_ext',
          borrowFeeRate: 0.22, // 22%
          isHardToBorrow: true,
          inventory: 'LOW',
        ),
      );

      expect(summary.squeezeRisk, ShortSqueezeRisk.extreme);
      expect(summary.squeezeRisk.label, 'Extreme Squeeze Risk');
      expect(summary.squeezeRisk.color, Colors.red);
      expect(summary.borrowCostLevel, BorrowCostLevel.high);
      expect(summary.borrowCostLevel.label, 'Hard to Borrow');
    });
  });

  group('DemoService Short Endpoints', () {
    final demoService = DemoService();
    final user = BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);

    test('fetches demo short interest for default symbol (AAPL)', () async {
      final res = await demoService.getShortInterest(user, 'inst_aapl');
      expect(res, isNotNull);
      final summary = ShortInterestSummary.fromResponses(
        shortInterestResponse: res,
        instrumentId: 'inst_aapl',
        symbol: 'AAPL',
      );

      expect(summary.shortInterest, isNotNull);
      expect(summary.shortInterest!.symbol, 'AAPL');
      expect(summary.shortInterest!.freeFloatPercentage, closeTo(2.85, 0.01));
      expect(summary.shortInterest!.daysToCover, 1.9);
    });

    test('fetches demo short availability for GME with elevated fees',
        () async {
      final resSi = await demoService.getShortInterest(user, 'inst_gme_01');
      final resAvail =
          await demoService.getShortingAvailability(user, 'inst_gme_01');

      final summary = ShortInterestSummary.fromResponses(
        shortInterestResponse: resSi,
        shortingAvailabilityResponse: resAvail,
        instrumentId: 'inst_gme_01',
        symbol: 'GME',
      );

      expect(summary.shortInterest!.freeFloatPercentage, closeTo(24.5, 0.01));
      expect(summary.shortInterest!.daysToCover, 6.4);
      expect(summary.availability!.inventory, 'LOW');
      expect(
          summary.availability!.borrowFeeRatePercentage, closeTo(18.5, 0.01));
      expect(summary.availability!.isHardToBorrow, isTrue);
      expect(summary.availability!.locateRequired, isTrue);
      expect(summary.squeezeRisk,
          isIn([ShortSqueezeRisk.high, ShortSqueezeRisk.extreme]));
      expect(summary.borrowCostLevel, BorrowCostLevel.high);
    });
  });
}
