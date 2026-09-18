import 'package:robinhood_options_mobile/model/screener_criterion.dart';

/// Criterion rule within a Robinhood screener preset
class ScreenerPresetCriterion {
  final String field;
  final String operator; // 'gte', 'lte', 'between', 'eq', 'in'
  final double? minValue;
  final double? maxValue;
  final String? textValue;
  final List<String>? values;

  const ScreenerPresetCriterion({
    required this.field,
    required this.operator,
    this.minValue,
    this.maxValue,
    this.textValue,
    this.values,
  });

  String get displayLabel {
    if (textValue != null &&
        textValue!.isNotEmpty &&
        !field.toLowerCase().contains('sector')) {
      return textValue!;
    }
    switch (field.toLowerCase()) {
      case 'market_cap':
      case 'marketcap':
        if (minValue != null && minValue! >= 1e12) {
          return 'Market Cap ≥ \$${(minValue! / 1e12).toStringAsFixed(1)}T';
        } else if (minValue != null && minValue! >= 1e9) {
          return 'Market Cap ≥ \$${(minValue! / 1e9).toStringAsFixed(0)}B';
        }
        return 'Market Cap Filter';
      case 'pe_ratio':
      case 'pe':
        if (maxValue != null) {
          return 'P/E ≤ ${maxValue!.toStringAsFixed(0)}';
        } else if (minValue != null) {
          return 'P/E ≥ ${minValue!.toStringAsFixed(0)}';
        }
        return 'P/E Filter';
      case 'dividend_yield':
      case 'dividendyield':
        if (minValue != null) {
          return 'Div Yield ≥ ${minValue!.toStringAsFixed(1)}%';
        }
        return 'Dividend Filter';
      case 'price':
        if (minValue != null && maxValue != null) {
          return '\$${minValue!.toStringAsFixed(0)} - \$${maxValue!.toStringAsFixed(0)}';
        } else if (minValue != null) {
          return 'Price ≥ \$${minValue!.toStringAsFixed(0)}';
        } else if (maxValue != null) {
          return 'Price ≤ \$${maxValue!.toStringAsFixed(0)}';
        }
        return 'Price Filter';
      case 'volume':
      case 'average_volume':
      case 'todays_volume':
        if (minValue != null && minValue! >= 1e6) {
          return 'Volume ≥ ${(minValue! / 1e6).toStringAsFixed(0)}M';
        }
        return 'Volume Filter';
      case 'sector':
        return textValue != null ? 'Sector: $textValue' : 'Sector Filter';
      case 'short_float':
      case 'short_interest':
        if (minValue != null) {
          return 'Short Float ≥ ${minValue!.toStringAsFixed(0)}%';
        }
        return 'Short Float Filter';
      case '52_week_high':
      case 'fifty_two_week_high':
        return 'Near 52W High';
      case '52_week_low':
      case 'fifty_two_week_low':
        return 'Near 52W Low';
      default:
        return textValue ?? formatFieldName(field);
    }
  }

  static String formatFieldName(String name) {
    return name
        .replaceAll('_', ' ')
        .split(' ')
        .map(
            (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  /// Maps this preset criterion to a native [ScreenerCriterion] when supported.
  ScreenerCriterion? toScreenerCriterion() {
    final lower = field.toLowerCase();
    if (lower.contains('cap')) {
      return ScreenerCriterion(
        field: ScreenerField.marketCap,
        minimum: minValue,
        maximum: maxValue,
      );
    } else if (lower.contains('pe')) {
      return ScreenerCriterion(
        field: ScreenerField.peRatio,
        minimum: minValue,
        maximum: maxValue,
      );
    } else if (lower.contains('dividend')) {
      return ScreenerCriterion(
        field: ScreenerField.dividendYield,
        minimum: minValue,
        maximum: maxValue,
      );
    } else if (lower == 'price') {
      return ScreenerCriterion(
        field: ScreenerField.price,
        minimum: minValue,
        maximum: maxValue,
      );
    } else if (lower.contains('volume')) {
      return ScreenerCriterion(
        field: ScreenerField.volume,
        minimum: minValue,
        maximum: maxValue,
      );
    } else if (lower.contains('sector')) {
      return ScreenerCriterion(
        field: ScreenerField.sector,
        textValue: textValue ??
            (values != null && values!.isNotEmpty ? values!.first : null),
      );
    }
    return null;
  }

  factory ScreenerPresetCriterion.fromJson(Map<String, dynamic> json) {
    return ScreenerPresetCriterion(
      field: json['field'] as String? ?? json['name'] as String? ?? '',
      operator: json['operator'] as String? ?? 'gte',
      minValue: (json['min_value'] ?? json['minimum'] ?? json['min'] as num?)
          ?.toDouble(),
      maxValue: (json['max_value'] ?? json['maximum'] ?? json['max'] as num?)
          ?.toDouble(),
      textValue: json['text_value'] as String? ?? json['value'] as String?,
      values:
          (json['values'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'field': field,
        'operator': operator,
        if (minValue != null) 'min_value': minValue,
        if (maxValue != null) 'max_value': maxValue,
        if (textValue != null) 'text_value': textValue,
        if (values != null) 'values': values,
      };
}

/// Curated Robinhood screener preset representing server-side saved filter collections
/// Endpoint: GET /screeners/presets/
class RobinhoodScreenerPreset {
  final String id;
  final String name;
  final String description;
  final String category;
  final String? iconEmoji;
  final String? iconUrl;
  final bool isCurated;
  final bool isFeatured;
  final bool hideFromSearch;
  final String? sortBy;
  final String? sortDirection;
  final int? itemCount;
  final List<String> columns;
  final Map<String, dynamic>? assetUrls;
  final List<String> sampleSymbols;
  final List<ScreenerPresetCriterion> criteria;

  const RobinhoodScreenerPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.iconEmoji,
    this.iconUrl,
    this.isCurated = true,
    this.isFeatured = false,
    this.hideFromSearch = false,
    this.sortBy,
    this.sortDirection,
    this.itemCount,
    this.columns = const [],
    this.assetUrls,
    this.sampleSymbols = const [],
    this.criteria = const [],
  });

  String? get illustrationUrl {
    if (assetUrls != null && assetUrls!.isNotEmpty) {
      for (final size in ['255x160', '180x100', '48x64', '28x28']) {
        final entry = assetUrls![size];
        if (entry is Map) {
          final candidate = entry['2x'] ??
              entry['1x'] ??
              entry['svg'] ??
              entry['1.5x'] ??
              entry['3x'];
          if (candidate != null && candidate.toString().isNotEmpty) {
            return candidate.toString();
          }
        }
      }
    }
    if (iconUrl != null && iconUrl!.isNotEmpty) {
      return iconUrl;
    }
    return null;
  }

  List<String> get columnLabels {
    return columns.map((col) {
      switch (col.toLowerCase()) {
        case 'sparkline':
          return 'Sparkline';
        case 'price':
          return 'Price';
        case '1d_price_change':
          return '1D Change';
        case 'todays_volume':
          return 'Volume';
        case 'market_cap':
          return 'Market Cap';
        case 'upcoming_earnings':
          return 'Earnings Date';
        case 'analyst_ratings.rating':
          return 'Analyst Rating';
        case 'implied_volatility':
          return 'Implied Vol';
        case 'options_volume':
          return 'Options Vol';
        case 'dividend_yield':
          return 'Div Yield';
        case '52_week_high_price':
          return '52W High';
        case '52_week_low_price':
          return '52W Low';
        default:
          return ScreenerPresetCriterion.formatFieldName(col);
      }
    }).toList();
  }

  String get sortDisplay {
    final sortName = sortBy != null
        ? ScreenerPresetCriterion.formatFieldName(sortBy!)
        : 'Market Cap';
    final dir = (sortDirection ?? '').toUpperCase() == 'ASC'
        ? 'Ascending'
        : 'Descending';
    return '$sortName ($dir)';
  }

  factory RobinhoodScreenerPreset.fromJson(Map<String, dynamic> json) {
    final rawName = json['display_name'] as String? ??
        json['name'] as String? ??
        json['title'] as String? ??
        '';
    final rawDescription = json['display_description'] as String? ??
        json['description'] as String? ??
        '';
    final sortBy = json['sort_by'] as String?;
    final sortDirection = json['sort_direction'] as String?;
    final iconEmoji = json['icon_emoji'] as String?;
    final iconUrl = json['icon_url'] as String?;
    final hideFromSearch = json['hide_from_search'] as bool? ?? false;
    final isCurated =
        json['is_curated'] as bool? ?? json['is_preset'] as bool? ?? true;

    Map<String, dynamic>? assetUrls;
    if (json['asset_urls'] is Map<String, dynamic>) {
      assetUrls = json['asset_urls'] as Map<String, dynamic>;
    } else if (json['asset_urls'] is Map) {
      assetUrls = Map<String, dynamic>.from(json['asset_urls'] as Map);
    }

    final columns = (json['columns'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    final isFeatured = json['is_featured'] as bool? ??
        (rawName.toLowerCase().contains('jump') ||
            rawName.toLowerCase().contains('dividend') ||
            rawName.toLowerCase().contains('high') ||
            rawName.toLowerCase().contains('analyst'));

    final category = json['category'] as String? ??
        json['theme'] as String? ??
        _inferCategory(rawName, sortBy);

    List<ScreenerPresetCriterion> parsedCriteria = [];
    if (json['criteria'] != null) {
      parsedCriteria = (json['criteria'] as List<dynamic>)
          .map((c) =>
              ScreenerPresetCriterion.fromJson(c as Map<String, dynamic>))
          .toList();
    } else if (json['filters'] != null) {
      if (json['filters'] is List) {
        parsedCriteria = (json['filters'] as List<dynamic>)
            .map((c) =>
                ScreenerPresetCriterion.fromJson(c as Map<String, dynamic>))
            .toList();
      } else if (json['filters'] is Map) {
        (json['filters'] as Map<String, dynamic>).forEach((key, val) {
          if (val is Map<String, dynamic>) {
            parsedCriteria.add(ScreenerPresetCriterion.fromJson({
              'field': key,
              ...val,
            }));
          }
        });
      }
    }

    if (parsedCriteria.isEmpty) {
      parsedCriteria = _inferCriteria(
        rawName,
        rawDescription,
        sortBy,
        sortDirection,
        columns,
      );
    }

    List<String> symbols = [];
    if (json['sample_symbols'] != null) {
      symbols = (json['sample_symbols'] as List<dynamic>)
          .map((s) => s.toString())
          .toList();
    } else if (json['symbols'] != null) {
      symbols =
          (json['symbols'] as List<dynamic>).map((s) => s.toString()).toList();
    }

    if (symbols.isEmpty) {
      symbols = _inferSampleSymbols(rawName, sortBy);
    }

    return RobinhoodScreenerPreset(
      id: json['id'] as String? ?? json['preset_id'] as String? ?? '',
      name: rawName,
      description: rawDescription,
      category: category,
      iconEmoji: iconEmoji,
      iconUrl: iconUrl,
      isCurated: isCurated,
      isFeatured: isFeatured,
      hideFromSearch: hideFromSearch,
      sortBy: sortBy,
      sortDirection: sortDirection,
      itemCount: json['item_count'] as int? ?? json['count'] as int?,
      columns: columns,
      assetUrls: assetUrls,
      sampleSymbols: symbols,
      criteria: parsedCriteria,
    );
  }

  static String _inferCategory(String name, String? sortBy) {
    final lowerName = name.toLowerCase();
    final lowerSort = sortBy?.toLowerCase() ?? '';

    if (lowerSort == '1d_price_change' ||
        lowerName.contains('jump') ||
        lowerName.contains('dip') ||
        lowerName.contains('price')) {
      return 'Movers';
    } else if (lowerSort == 'dividend_yield' ||
        lowerName.contains('dividend')) {
      return 'Dividends';
    } else if (lowerSort == 'upcoming_earnings' ||
        lowerName.contains('earning')) {
      return 'Earnings';
    } else if (lowerSort == 'implied_volatility' ||
        lowerName.contains('volatility')) {
      return 'Volatility';
    } else if (lowerSort == 'options_volume' || lowerName.contains('option')) {
      return 'Options';
    } else if (lowerName.contains('analyst')) {
      return 'Analyst Picks';
    } else if (lowerName.contains('52-week') ||
        lowerName.contains('high') ||
        lowerName.contains('low')) {
      return '52-Week Range';
    } else if (lowerName.contains('custom')) {
      return 'Custom';
    } else if (lowerName.contains('short') || lowerName.contains('squeeze')) {
      return 'Short Squeeze';
    } else if (lowerName.contains('growth') || lowerName.contains('tech')) {
      return 'Growth';
    } else if (lowerName.contains('value')) {
      return 'Value';
    } else if (lowerName.contains('active')) {
      return 'Active';
    }
    return 'General';
  }

  static List<ScreenerPresetCriterion> _inferCriteria(
    String name,
    String description,
    String? sortBy,
    String? sortDirection,
    List<String> columns,
  ) {
    final lowerName = name.toLowerCase();
    final lowerSort = sortBy?.toLowerCase() ?? '';
    final isAsc = (sortDirection ?? '').toUpperCase() == 'ASC';
    List<ScreenerPresetCriterion> list = [];

    if (lowerSort == 'dividend_yield' || lowerName.contains('dividend')) {
      list.add(const ScreenerPresetCriterion(
        field: 'dividend_yield',
        operator: 'gte',
        minValue: 5.0,
      ));
      list.add(const ScreenerPresetCriterion(
        field: 'sort_by',
        operator: 'sort',
        textValue: 'Sorted by Dividend Yield (High to Low)',
      ));
    } else if (lowerSort == '1d_price_change' && !isAsc) {
      list.add(const ScreenerPresetCriterion(
        field: '1d_price_change',
        operator: 'sort',
        textValue: 'Top 1-Day Price Gainers',
      ));
      list.add(const ScreenerPresetCriterion(
        field: 'market_cap',
        operator: 'gte',
        minValue: 1000000000.0,
      ));
    } else if (lowerSort == '1d_price_change' && isAsc) {
      list.add(const ScreenerPresetCriterion(
        field: '1d_price_change',
        operator: 'sort',
        textValue: 'Top 1-Day Price Decliners',
      ));
      list.add(const ScreenerPresetCriterion(
        field: 'market_cap',
        operator: 'gte',
        minValue: 1000000000.0,
      ));
    } else if (lowerSort == 'upcoming_earnings' ||
        lowerName.contains('earning')) {
      list.add(const ScreenerPresetCriterion(
        field: 'earnings_date',
        operator: 'lte',
        textValue: 'Reporting in Next 2 Weeks',
      ));
      list.add(const ScreenerPresetCriterion(
        field: 'sort_by',
        operator: 'sort',
        textValue: 'Sorted by Earliest Report Date',
      ));
    } else if (lowerName.contains('analyst') ||
        columns.contains('analyst_ratings.rating')) {
      list.add(const ScreenerPresetCriterion(
        field: 'analyst_rating',
        operator: 'eq',
        textValue: 'Consensus "Buy" Rating',
      ));
      list.add(const ScreenerPresetCriterion(
        field: 'market_cap',
        operator: 'gte',
        minValue: 10000000000.0,
      ));
    } else if (lowerSort == 'implied_volatility' ||
        lowerName.contains('volatility')) {
      list.add(const ScreenerPresetCriterion(
        field: 'implied_volatility',
        operator: 'gte',
        textValue: 'Elevated Implied Volatility (IV)',
      ));
      list.add(const ScreenerPresetCriterion(
        field: 'options',
        operator: 'eq',
        textValue: 'Options Tradable Underlyings',
      ));
    } else if (lowerSort == 'options_volume' || lowerName.contains('option')) {
      list.add(const ScreenerPresetCriterion(
        field: 'options_volume',
        operator: 'gte',
        textValue: 'Heavy Daily Options Flow',
      ));
      list.add(const ScreenerPresetCriterion(
        field: 'sort_by',
        operator: 'sort',
        textValue: 'Sorted by Options Volume',
      ));
    } else if (lowerName.contains('52-week highs') ||
        lowerName.contains('highs')) {
      list.add(const ScreenerPresetCriterion(
        field: '52_week_high',
        operator: 'gte',
        textValue: 'Broke 52-Week High Today',
      ));
      list.add(const ScreenerPresetCriterion(
        field: 'market_cap',
        operator: 'gte',
        minValue: 5000000000.0,
      ));
    } else if (lowerName.contains('52-week lows') ||
        lowerName.contains('lows')) {
      list.add(const ScreenerPresetCriterion(
        field: '52_week_low',
        operator: 'lte',
        textValue: 'Fell Below 52-Week Low Today',
      ));
      list.add(const ScreenerPresetCriterion(
        field: 'market_cap',
        operator: 'gte',
        minValue: 1000000000.0,
      ));
    } else if (lowerName.contains('custom')) {
      list.add(const ScreenerPresetCriterion(
        field: 'custom',
        operator: 'custom',
        textValue: 'Build Custom Multi-Factor Screen',
      ));
    }

    if (list.isEmpty && sortBy != null && sortBy.isNotEmpty) {
      list.add(ScreenerPresetCriterion(
        field: sortBy,
        operator: 'sort',
        textValue:
            'Sorted by ${ScreenerPresetCriterion.formatFieldName(sortBy)} ($sortDirection)',
      ));
    }
    return list;
  }

  static List<String> _inferSampleSymbols(String name, String? sortBy) {
    final lowerName = name.toLowerCase();
    final lowerSort = sortBy?.toLowerCase() ?? '';

    if (lowerSort == '1d_price_change' && !lowerName.contains('dip')) {
      return const ['NVDA', 'TSLA', 'PLTR', 'AMD', 'COIN'];
    } else if (lowerName.contains('dip')) {
      return const ['INTC', 'BABA', 'DIS', 'NKE', 'PYPL'];
    } else if (lowerSort == 'dividend_yield' ||
        lowerName.contains('dividend')) {
      return const ['JNJ', 'PG', 'KO', 'ABBV', 'XOM', 'MO'];
    } else if (lowerSort == 'upcoming_earnings' ||
        lowerName.contains('earning')) {
      return const ['AAPL', 'MSFT', 'AMZN', 'GOOGL', 'META'];
    } else if (lowerName.contains('analyst')) {
      return const ['MSFT', 'NVDA', 'AMZN', 'V', 'UNH'];
    } else if (lowerSort == 'implied_volatility' ||
        lowerName.contains('volatility')) {
      return const ['TSLA', 'MSTR', 'GME', 'SMCI', 'MARA'];
    } else if (lowerSort == 'options_volume' || lowerName.contains('option')) {
      return const ['SPY', 'QQQ', 'NVDA', 'TSLA', 'AAPL', 'AMD'];
    } else if (lowerName.contains('high')) {
      return const ['NVDA', 'META', 'LLY', 'COST', 'AVGO'];
    } else if (lowerName.contains('low')) {
      return const ['WBA', 'BA', 'PFE', 'SNOW', 'LULU'];
    } else if (lowerName.contains('custom')) {
      return const ['AAPL', 'MSFT', 'GOOGL'];
    }
    return const [];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        if (iconEmoji != null) 'icon_emoji': iconEmoji,
        if (iconUrl != null) 'icon_url': iconUrl,
        'is_curated': isCurated,
        'is_featured': isFeatured,
        'hide_from_search': hideFromSearch,
        if (sortBy != null) 'sort_by': sortBy,
        if (sortDirection != null) 'sort_direction': sortDirection,
        if (itemCount != null) 'item_count': itemCount,
        if (columns.isNotEmpty) 'columns': columns,
        if (assetUrls != null) 'asset_urls': assetUrls,
        'sample_symbols': sampleSymbols,
        'criteria': criteria.map((c) => c.toJson()).toList(),
      };
}

/// Available screener collection or saved screener definition
/// Endpoint: GET /screeners
class RobinhoodScreener {
  final String id;
  final String name;
  final String? description;
  final int filterCount;
  final List<String> availableFilters;

  const RobinhoodScreener({
    required this.id,
    required this.name,
    this.description,
    this.filterCount = 0,
    this.availableFilters = const [],
  });

  factory RobinhoodScreener.fromJson(Map<String, dynamic> json) {
    List<String> filters = [];
    if (json['available_filters'] != null) {
      filters = (json['available_filters'] as List<dynamic>)
          .map((f) => f.toString())
          .toList();
    } else if (json['filters'] != null && json['filters'] is List) {
      filters = (json['filters'] as List<dynamic>)
          .map((f) => f is Map
              ? (f['name'] ?? f['field'] ?? '').toString()
              : f.toString())
          .toList();
    }

    return RobinhoodScreener(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['title'] as String? ?? '',
      description: json['description'] as String?,
      filterCount: json['filter_count'] as int? ?? filters.length,
      availableFilters: filters,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'filter_count': filterCount,
        'available_filters': availableFilters,
      };
}
