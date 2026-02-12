import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/watchlist_item.dart';
import 'package:robinhood_options_mobile/model/group_watchlist_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeWidgetService {
  static const String appGroupId =
      'group.com.robinhood_options_mobile'; // Will need to be configured in iOS/Android
  static const String androidWidgetName =
      'PortfolioWidget'; // Class name of Android WidgetProvider
  static const String iOSWidgetName = 'PortfolioWidget'; // Name of iOS Widget

  static Future<void> updatePortfolio(Portfolio portfolio) async {
    final equity = portfolio.equity ?? 0;
    final previousClose = portfolio.equityPreviousClose ?? equity;
    final change = equity - previousClose;
    final changePercent = previousClose != 0 ? change / previousClose : 0.0;

    await HomeWidget.saveWidgetData<double>('portfolio_equity', equity);
    await HomeWidget.saveWidgetData<double>('portfolio_change', change);
    await HomeWidget.saveWidgetData<double>(
        'portfolio_change_percent', changePercent);

    await HomeWidget.updateWidget(
      name: androidWidgetName,
      iOSName: iOSWidgetName,
    );
  }

  static Future<void> updateWatchlist(List<WatchlistItem> items) async {
    final List<Map<String, dynamic>> watchlistData = items.take(5).map((item) {
      String symbol = '';
      double price = 0.0;
      double changePercent = 0.0;

      if (item.instrumentObj != null) {
        symbol = item.instrumentObj!.symbol;
        price = item.instrumentObj!.quoteObj?.lastTradePrice ?? 0.0;
        // Calculate change if available
        if (item.instrumentObj!.quoteObj != null) {
          final previousClose =
              item.instrumentObj!.quoteObj!.previousClose ?? 0.0;
          if (previousClose != 0) {
            changePercent = (price - previousClose) / previousClose;
          }
        }
      }

      return {
        'symbol': symbol,
        'price': price,
        'changePercent': changePercent,
      };
    }).toList();

    await HomeWidget.saveWidgetData<String>(
        'watchlist_data', jsonEncode(watchlistData));

    await HomeWidget.updateWidget(
      name: 'WatchlistWidget',
      iOSName: 'WatchlistWidget',
    );
  }

  static Future<void> updateGroupWatchlist(GroupWatchlist groupWatchlist,
      Map<String, Map<String, dynamic>> quoteData) async {
    final List<Map<String, dynamic>> watchlistData =
        groupWatchlist.symbols.take(5).map((symbol) {
      final symbolQuote = quoteData[symbol.symbol];
      final price = symbolQuote?['lastTradePrice'] as double? ?? 0.0;
      final previousClose = symbolQuote?['previousClose'] as double? ?? 0.0;
      final changePercent =
          previousClose != 0 ? (price - previousClose) / previousClose : 0.0;

      return {
        'symbol': symbol.symbol,
        'price': price,
        'changePercent': changePercent,
      };
    }).toList();

    await HomeWidget.saveWidgetData<String>(
        'group_watchlist_data', jsonEncode(watchlistData));
    await HomeWidget.saveWidgetData<String>(
        'group_watchlist_name', groupWatchlist.name);
    await HomeWidget.saveWidgetData<String>(
        'group_watchlist_id', groupWatchlist.id);
    await HomeWidget.saveWidgetData<String>(
        'group_watchlist_group_id', groupWatchlist.groupId);

    await HomeWidget.updateWidget(
      name: 'WatchlistWidget',
      iOSName: 'WatchlistWidget',
    );
  }

  static Future<void> setSelectedGroupWatchlist(
      String? groupId, String? watchlistId) async {
    final prefs = await SharedPreferences.getInstance();
    if (groupId != null && watchlistId != null) {
      await prefs.setString(
          'widget_selected_group_watchlist', '$groupId:$watchlistId');
    } else {
      await prefs.remove('widget_selected_group_watchlist');
    }
  }

  static Future<void> updateTradeSignals(
      List<Map<String, dynamic>> signals) async {
    final List<Map<String, dynamic>> signalsData =
        signals.take(5).map((signal) {
      final symbol = signal['symbol'] as String? ?? 'N/A';
      final signalType = signal['signal'] as String? ?? 'HOLD';
      final multiIndicatorResult =
          signal['multiIndicatorResult'] as Map<String, dynamic>?;
      final strength = multiIndicatorResult?['signalStrength'] as int? ?? 0;

      return {
        'symbol': symbol,
        'signalType': signalType,
        'strength': strength,
      };
    }).toList();

    final jsonString = jsonEncode(signalsData);
    debugPrint(
        'HomeWidgetService: Updating trade signals widget with ${signalsData.length} signals');
    debugPrint('HomeWidgetService: JSON data: $jsonString');

    await HomeWidget.saveWidgetData<String>('trade_signals_data', jsonString);

    await HomeWidget.updateWidget(
      name: androidWidgetName,
      iOSName: 'TradeSignalsWidget',
    );

    debugPrint('HomeWidgetService: Trade signals widget update completed');
  }

  static Future<Map<String, String>?> getSelectedGroupWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('widget_selected_group_watchlist');
    if (value != null) {
      final parts = value.split(':');
      if (parts.length == 2) {
        return {'groupId': parts[0], 'watchlistId': parts[1]};
      }
    }
    return null;
  }
}
