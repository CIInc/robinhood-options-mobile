import 'package:robinhood_options_mobile/model/equity_historical.dart';

class PortfolioHistoricals {
  double? adjustedOpenEquity;
  double? adjustedPreviousCloseEquity;
  double? openEquity;
  double? previousCloseEquity;
  final String? openTime;
  final String interval;
  final String span;
  final String bounds;
  final double? totalReturn;
  List<EquityHistorical> equityHistoricals;
  final bool useNewHp;

  PortfolioHistoricals(
      this.adjustedOpenEquity,
      this.adjustedPreviousCloseEquity,
      this.openEquity,
      this.previousCloseEquity,
      this.openTime,
      this.interval,
      this.span,
      this.bounds,
      this.totalReturn,
      this.equityHistoricals,
      this.useNewHp);

  PortfolioHistoricals.fromJson(dynamic json)
      : adjustedOpenEquity = json['adjusted_open_equity'] != null
            ? double.tryParse(json['adjusted_open_equity'])
            : null,
        adjustedPreviousCloseEquity =
            json['adjusted_previous_close_equity'] != null
                ? double.tryParse(json['adjusted_previous_close_equity'])
                : null,
        openEquity = json['open_equity'] != null
            ? double.tryParse(json['open_equity'])
            : null,
        previousCloseEquity = json['previous_close_equity'] != null
            ? double.tryParse(json['previous_close_equity'])
            : null,
        openTime = json['open_time'],
        interval = json['interval'],
        span = json['span'],
        bounds = json['bounds'],
        totalReturn = double.tryParse(json['total_return']),
        equityHistoricals =
            EquityHistorical.fromJsonArray(json['equity_historicals']),
        useNewHp = json['use_new_hp'];

/*
{
    "title": null,
    "weight": null,
    "lines": [
        {
            "identifier": "returns",
            "segments": [
                {
                    "points": [ ... ],
                    "styles": {
                        "default": {
                            "color": {
                                "light": "positive",
                                "dark": "positive"
                            },
                            "opacity": 1.0,
                            "line_type": {
                                "type": "solid",
                                "stroke_width": 1.5,
                                "cap_style": "round"
                            },
                            "gradient_color": null
                        },
                        "active": {
                            "color": {
                                "light": "positive",
                                "dark": "positive"
                            },
                            "opacity": 1.0,
                            "line_type": {
                                "type": "solid",
                                "stroke_width": 1.5,
                                "cap_style": "round"
                            },
                            "gradient_color": null
                        },
                        "inactive": {
                            "color": {
                                "light": "positive",
                                "dark": "positive"
                            },
                            "opacity": 0.5,
                            "line_type": {
                                "type": "solid",
                                "stroke_width": 1.5,
                                "cap_style": "round"
                            },
                            "gradient_color": null
                        }
                    }
                }
            ],
            "direction": "up",
            "is_primary": true
        },
        {
            "identifier": "baseline",
            "segments": [
                {
                    "points": [
                        {
                            "x": 0.0,
                            "y": 0.0,
                            "cursor_data": null
                        },
                        {
                            "x": 1.0,
                            "y": 0.0,
                            "cursor_data": null
                        }
                    ],
                    "styles": {
                        "default": {
                            "color": {
                                "light": "fg2",
                                "dark": "fg2"
                            },
                            "opacity": 1.0,
                            "line_type": {
                                "type": "dotted",
                                "dash_gap": 0.013937282229965157
                            },
                            "gradient_color": null
                        },
                        "active": {
                            "color": {
                                "light": "fg",
                                "dark": "fg"
                            },
                            "opacity": 1.0,
                            "line_type": {
                                "type": "dotted",
                                "dash_gap": 0.013937282229965157
                            },
                            "gradient_color": null
                        },
                        "inactive": {
                            "color": {
                                "light": "fg2",
                                "dark": "fg2"
                            },
                            "opacity": 1.0,
                            "line_type": {
                                "type": "dotted",
                                "dash_gap": 0.013937282229965157
                            },
                            "gradient_color": null
                        }
                    }
                }
            ],
            "direction": "up",
            "is_primary": false
        }
    ],
    "x_axis": null,
    "y_axis": null,
    "legend_data": {},
    "fills": [],
    "overlays": [
        {
            "sdui_component_type": "CHART_LAYERED_STACK",
            "current_platform": null,
            "skip_compatibility_check": null,
            "content": [
                {
                    "content": {
                        "sdui_component_type": "CHART_PULSING_DOT",
                        "current_platform": null,
                        "skip_compatibility_check": null,
                        "id": "returns-c49ca12e-b97f-4561-9f0c-53c7e7a2b7f2",
                        "color": {
                            "light": "positive",
                            "dark": "positive"
                        },
                        "size": 6.0,
                        "pulse_duration": 1.0,
                        "pulse_frequency": "AUTOMATIC",
                        "pulse_scale": 5.0
                    },
                    "position": {
                        "x": 0.5505226480836237,
                        "y": 0.7563477113445074,
                        "horizontal_edge": "CENTER",
                        "vertical_edge": "CENTER"
                    },
                    "size": null
                }
            ]
        }
    ],
    "id": "0f25eb04-d66b-41d1-87fc-c318d1155da7",
    "default_display": {
        "label": {
            "value": "1:09 PM",
            "color": {
                "light": "fg2",
                "dark": "fg2"
            },
            "text_style": null
        },
        "secondary_label": null,
        "tertiary_label": null,
        "quaternary_label": null,
        "primary_value": {
            "value": "$63,189.47",
            "color": {
                "light": "fg2",
                "dark": "fg2"
            },
            "text_style": null
        },
        "secondary_value": {
            "main": {
                "value": "$111.28 (0.18%)",
                "color": {
                    "light": "positive",
                    "dark": "positive"
                },
                "icon": "stock_up_16",
                "gradient_color": null
            },
            "string_format": null,
            "description": {
                "value": "Today",
                "color": {
                    "light": "fg",
                    "dark": "fg"
                },
                "text_style": null
            }
        },
        "tertiary_value": null,
        "quaternary_value": null,
        "price_chart_data": {
            "dollar_value": {
                "currency_code": "USD",
                "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
                "amount": "63189.4695280075124702"
            },
            "dollar_value_for_return": {
                "currency_code": "USD",
                "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
                "amount": "63189.469528007510234601795673370361328125"
            },
            "dollar_value_for_rate_of_return": {
                "currency_code": "USD",
                "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
                "amount": "63189.469528007510234601795673370361328125"
            }
        }
    },
    "display_span": "day",
    "page_direction": "up",
    "chart_type": "historical_portfolio",
    "chart_style": "PERFORMANCE",
    "account_number": "5QR24141",
    "benchmark_ids": "",
    "spans": {
        "available_spans": [
            {
                "display_value": "LIVE",
                "query_value": "hour",
                "has_blinking_dot": true
            },
            {
                "display_value": "1D",
                "query_value": "day",
                "has_blinking_dot": false
            },
            {
                "display_value": "1W",
                "query_value": "week",
                "has_blinking_dot": false
            },
            {
                "display_value": "1M",
                "query_value": "month",
                "has_blinking_dot": false
            },
            {
                "display_value": "3M",
                "query_value": "3month",
                "has_blinking_dot": false
            },
            {
                "display_value": "YTD",
                "query_value": "ytd",
                "has_blinking_dot": false
            },
            {
                "display_value": "1Y",
                "query_value": "year",
                "has_blinking_dot": false
            },
            {
                "display_value": "ALL",
                "query_value": "all",
                "has_blinking_dot": false
            }
        ],
        "default_selected_index": 1
    },
    "include_all_hours": true,
    "line_ordering": [],
    "performance_baseline": {
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
        "amount": "63078.18880018416"
    },
    "is_for_widget": false,
    "is_privacy_enabled": false
}
*/
  PortfolioHistoricals.fromPerformanceJson(dynamic json)
      : adjustedOpenEquity = json['performance_baseline'] != null
            ? double.parse(json['performance_baseline']['amount'])
            : null,
        adjustedPreviousCloseEquity = null,
        openEquity = null,
        previousCloseEquity = null,
        openTime = null,
        interval = '',
        span = json['display_span'] ?? 'day',
        bounds = '',
        totalReturn = null,
        equityHistoricals = [],
        useNewHp = false {
    if (json == null) {
      return;
    }
    var lines = json['lines'];
    if (lines == null) {
      return;
    }
    var primaryLines = lines.where((line) => line['is_primary'] == true);
    for (var line in primaryLines) {
      var segments = line['segments'];
      if (segments != null) {
        for (var segment in segments) {
          List<dynamic>? points = segment['points'];
          if (points != null) {
            for (var point in points) {
              var cursorData = point['cursor_data'];
              if (cursorData != null) {
                equityHistoricals
                    .add(EquityHistorical.fromPerformanceJson(cursorData));
              }
            }
          }
        }
      }
    }
  }

  void add(EquityHistorical item) {
    equityHistoricals.add(item);
    // This call tells the widgets that are listening to this model to rebuild.
  }

  bool update(EquityHistorical item) {
    var index = equityHistoricals
        .indexWhere((element) => element.beginsAt == item.beginsAt);
    if (index == -1) {
      return false;
    }
    equityHistoricals[index] = item;
    return true;
  }

  void addOrUpdate(EquityHistorical item) {
    if (!update(item)) {
      add(item);
    }
  }
}
