import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/screener_criterion.dart';
import 'package:robinhood_options_mobile/model/screener_preset.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  group('ScreenerPresetCriterion', () {
    test('parses numeric criterion and generates display label', () {
      final json = {
        'field': 'dividend_yield',
        'operator': 'gte',
        'min_value': 3.5,
      };

      final criterion = ScreenerPresetCriterion.fromJson(json);

      expect(criterion.field, 'dividend_yield');
      expect(criterion.operator, 'gte');
      expect(criterion.minValue, 3.5);
      expect(criterion.displayLabel, 'Div Yield ≥ 3.5%');

      final native = criterion.toScreenerCriterion();
      expect(native, isNotNull);
      expect(native!.field, ScreenerField.dividendYield);
      expect(native.minimum, 3.5);
    });

    test('parses market cap criterion and generates display label', () {
      final json = {
        'field': 'market_cap',
        'operator': 'gte',
        'min_value': 50000000000.0,
      };

      final criterion = ScreenerPresetCriterion.fromJson(json);
      expect(criterion.displayLabel, 'Market Cap ≥ \$50B');

      final native = criterion.toScreenerCriterion();
      expect(native, isNotNull);
      expect(native!.field, ScreenerField.marketCap);
      expect(native.minimum, 50000000000.0);
    });

    test('parses sector criterion and converts to native criterion', () {
      final json = {
        'field': 'sector',
        'operator': 'eq',
        'text_value': 'Technology',
      };

      final criterion = ScreenerPresetCriterion.fromJson(json);
      expect(criterion.displayLabel, 'Sector: Technology');

      final native = criterion.toScreenerCriterion();
      expect(native, isNotNull);
      expect(native!.field, ScreenerField.sector);
      expect(native.textValue, 'Technology');
    });
  });

  group('RobinhoodScreenerPreset', () {
    test('parses preset from JSON with criteria and sample symbols', () {
      final json = {
        'id': 'top-dividend-stocks',
        'name': 'Top Dividend Stocks',
        'description': 'High-yield companies with strong balance sheets.',
        'category': 'Dividends',
        'is_curated': true,
        'is_featured': true,
        'item_count': 42,
        'sort_by': 'dividend_yield',
        'sort_direction': 'desc',
        'sample_symbols': ['JNJ', 'PG', 'KO'],
        'criteria': [
          {
            'field': 'dividend_yield',
            'operator': 'gte',
            'min_value': 3.0,
          },
          {
            'field': 'market_cap',
            'operator': 'gte',
            'min_value': 50000000000.0,
          },
        ],
      };

      final preset = RobinhoodScreenerPreset.fromJson(json);

      expect(preset.id, 'top-dividend-stocks');
      expect(preset.name, 'Top Dividend Stocks');
      expect(preset.category, 'Dividends');
      expect(preset.isCurated, isTrue);
      expect(preset.isFeatured, isTrue);
      expect(preset.itemCount, 42);
      expect(preset.sampleSymbols, ['JNJ', 'PG', 'KO']);
      expect(preset.criteria.length, 2);
      expect(preset.criteria[0].displayLabel, 'Div Yield ≥ 3.0%');
      expect(preset.criteria[1].displayLabel, 'Market Cap ≥ \$50B');
    });

    test('parses real Robinhood preset JSON with display_name and asset_urls',
        () {
      final json = {
        'id': '94ee72a4-5b0b-4164-9f02-7e119a1e68c0',
        'display_name': 'Daily price jumps',
        'display_description': 'Stocks with the biggest price increases today',
        'hide_from_search': null,
        'icon_emoji': '💡',
        'icon_url': '',
        'sort_by': '1d_price_change',
        'sort_direction': 'DESC',
        'filters': [],
        'is_preset': true,
        'asset_urls': {
          '180x100': {
            '1x':
                'https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/180x100/1x.png',
            '2x':
                'https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/180x100/2x.png',
            'svg':
                'https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/180x100/svg.svg'
          },
          '255x160': {
            '1x':
                'https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/255x160/1x.png',
            '2x':
                'https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/255x160/2x.png',
            'svg':
                'https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/255x160/svg.svg'
          }
        },
        'columns': [
          'sparkline',
          '1d_price_change',
          'price',
          'todays_volume',
          'market_cap'
        ]
      };

      final preset = RobinhoodScreenerPreset.fromJson(json);

      expect(preset.id, '94ee72a4-5b0b-4164-9f02-7e119a1e68c0');
      expect(preset.name, 'Daily price jumps');
      expect(
          preset.description, 'Stocks with the biggest price increases today');
      expect(preset.category, 'Movers');
      expect(preset.iconEmoji, '💡');
      expect(preset.isCurated, isTrue);
      expect(preset.isFeatured, isTrue);
      expect(preset.hideFromSearch, isFalse);
      expect(preset.sortBy, '1d_price_change');
      expect(preset.sortDirection, 'DESC');
      expect(preset.sortDisplay, '1d Price Change (Descending)');
      expect(preset.illustrationUrl, contains('255x160/2x.png'));
      expect(preset.columns, [
        'sparkline',
        '1d_price_change',
        'price',
        'todays_volume',
        'market_cap'
      ]);
      expect(preset.columnLabels,
          ['Sparkline', '1D Change', 'Price', 'Volume', 'Market Cap']);
      expect(preset.criteria.isNotEmpty, isTrue);
      expect(preset.criteria.first.displayLabel, 'Top 1-Day Price Gainers');
      expect(preset.sampleSymbols, contains('NVDA'));
      expect(preset.sampleSymbols, contains('TSLA'));
    });

    test('parses Robinhood dividend yield preset with auto-inferred criteria',
        () {
      final json = {
        'id': '834ca4dc-7d82-4cfc-b95b-ccd9d85db5c0',
        'display_name': 'Highest dividend yield',
        'display_description': 'Stocks with dividend yield above 5%',
        'hide_from_search': null,
        'icon_emoji': '💡',
        'icon_url': '',
        'sort_by': 'dividend_yield',
        'sort_direction': 'DESC',
        'filters': [],
        'is_preset': true,
        'columns': [
          'sparkline',
          'dividend_yield',
          'price',
          'todays_volume',
          'market_cap'
        ]
      };

      final preset = RobinhoodScreenerPreset.fromJson(json);

      expect(preset.name, 'Highest dividend yield');
      expect(preset.description, 'Stocks with dividend yield above 5%');
      expect(preset.category, 'Dividends');
      expect(preset.criteria.any((c) => c.displayLabel == 'Div Yield ≥ 5.0%'),
          isTrue);
      expect(preset.sampleSymbols, contains('JNJ'));
      expect(preset.sampleSymbols, contains('KO'));
    });

    test('serializes to JSON correctly', () {
      const preset = RobinhoodScreenerPreset(
        id: 'growth-101',
        name: 'Growth 101',
        description: 'Tech growth stocks',
        category: 'Growth',
        sampleSymbols: ['AAPL', 'NVDA'],
      );

      final json = preset.toJson();
      expect(json['id'], 'growth-101');
      expect(json['name'], 'Growth 101');
      expect(json['category'], 'Growth');
      expect(json['sample_symbols'], ['AAPL', 'NVDA']);
    });
  });

  group('RobinhoodScreener', () {
    test('parses available screener definition', () {
      final json = {
        'id': 'screener_equities_core',
        'name': 'US Equities Core Screener',
        'description': 'Primary screener filtering US equities',
        'filter_count': 12,
        'available_filters': ['market_cap', 'pe_ratio', 'dividend_yield'],
      };

      final screener = RobinhoodScreener.fromJson(json);
      expect(screener.id, 'screener_equities_core');
      expect(screener.name, 'US Equities Core Screener');
      expect(screener.filterCount, 12);
      expect(screener.availableFilters,
          ['market_cap', 'pe_ratio', 'dividend_yield']);
    });
  });

  group('DemoService Presets Integration', () {
    test('fetches curated screener presets from DemoService', () async {
      final service = DemoService();
      final user = BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);

      final response = await service.getScreenerPresets(user);
      expect(response, isNotNull);
      expect(response['results'], isA<List>());

      final presets = (response['results'] as List)
          .map((p) =>
              RobinhoodScreenerPreset.fromJson(p as Map<String, dynamic>))
          .toList();

      expect(presets.length, greaterThanOrEqualTo(5));

      final jumpsPreset =
          presets.firstWhere((p) => p.name == 'Daily price jumps');
      expect(jumpsPreset.category, 'Movers');
      expect(jumpsPreset.sampleSymbols, contains('NVDA'));
      expect(jumpsPreset.sampleSymbols, contains('TSLA'));

      final dividendPreset =
          presets.firstWhere((p) => p.name == 'Highest dividend yield');
      expect(dividendPreset.category, 'Dividends');
      expect(dividendPreset.sampleSymbols, contains('JNJ'));
      expect(dividendPreset.sampleSymbols, contains('KO'));

      final ivPreset =
          presets.firstWhere((p) => p.name == 'Highest implied volatility');
      expect(ivPreset.category, 'Volatility');
      expect(ivPreset.sampleSymbols, contains('MSTR'));

      final techPreset = presets.firstWhere((p) => p.id == 'mega-cap-tech');
      expect(techPreset.category, 'Growth');
      expect(techPreset.sampleSymbols, contains('AAPL'));
      expect(techPreset.sampleSymbols, contains('NVDA'));

      final shortSqueezePreset =
          presets.firstWhere((p) => p.id == 'high-short-squeeze');
      expect(shortSqueezePreset.category, 'Short Squeeze');
      expect(shortSqueezePreset.sampleSymbols, contains('GME'));
    });

    test('fetches available screeners from DemoService', () async {
      final service = DemoService();
      final user = BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);

      final response = await service.getScreeners(user);
      expect(response, isNotNull);
      expect(response['results'], isA<List>());

      final screeners = (response['results'] as List)
          .map((s) => RobinhoodScreener.fromJson(s as Map<String, dynamic>))
          .toList();

      expect(screeners.length, greaterThanOrEqualTo(2));
      expect(screeners[0].id, 'screener_equities_core');
      expect(screeners[0].availableFilters, contains('market_cap'));
      expect(screeners[0].availableFilters, contains('pe_ratio'));
    });
  });
}
