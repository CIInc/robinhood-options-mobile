package com.cidevelop.robinhood_options_mobile

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class PortfolioWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.widget_portfolio)

            // Check if this is watchlist data or portfolio data
            val groupWatchlistData = widgetData.getString("group_watchlist_data", null)
            val watchlistData = widgetData.getString("watchlist_data", null)
            val tradeSignalsData = widgetData.getString("trade_signals_data", null)
            val portfolioEquity = widgetData.getFloat("portfolio_equity", Float.NaN).toDouble()

            if (tradeSignalsData != null) {
                // This is a trade signals widget
                setupTradeSignalsWidget(context, views, widgetData)
            } else if (groupWatchlistData != null || watchlistData != null) {
                // This is a watchlist widget
                setupWatchlistWidget(context, views, widgetData)
            } else if (!portfolioEquity.isNaN()) {
                // This is a portfolio widget
                setupPortfolioWidget(context, views, widgetData)
            }

            // Set up click intent
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse(getWidgetUrl(widgetData))
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = android.app.PendingIntent.getActivity(
                context,
                appWidgetId,
                intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.content, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun setupPortfolioWidget(context: Context, views: RemoteViews, widgetData: SharedPreferences) {
        val equity = widgetData.getFloat("portfolio_equity", 0.0f).toDouble()
        val change = widgetData.getFloat("portfolio_change", 0.0f).toDouble()
        val changePercent = widgetData.getFloat("portfolio_change_percent", 0.0f).toDouble()

        // Set main equity value
        views.setTextViewText(R.id.portfolio_equity, String.format("$%.2f", equity))

        // Set change values with appropriate colors
        val changeColor = if (change >= 0) android.R.color.holo_green_dark else android.R.color.holo_red_dark
        val percentColor = if (change >= 0) android.R.color.holo_green_dark else android.R.color.holo_red_dark

        views.setTextViewText(R.id.portfolio_change, String.format("$%.2f", change))
        views.setTextColor(R.id.portfolio_change, context.getColor(changeColor))

        views.setTextViewText(R.id.portfolio_change_percent, String.format("%.2f%%", changePercent * 100))
        views.setTextColor(R.id.portfolio_change_percent, context.getColor(percentColor))

        // Set appropriate arrow icon
        val arrowResId = if (change >= 0) R.drawable.ic_arrow_up else R.drawable.ic_arrow_down
        views.setImageViewResource(R.id.change_arrow, arrowResId)
    }

    private fun setupWatchlistWidget(context: Context, views: RemoteViews, widgetData: SharedPreferences) {
        // For now, just show a placeholder - the layout might need to be updated for watchlist
        views.setTextViewText(R.id.portfolio_equity, "Watchlist")
        views.setTextViewText(R.id.portfolio_change, "")
        views.setTextViewText(R.id.portfolio_change_percent, "")
    }

    private fun setupTradeSignalsWidget(context: Context, views: RemoteViews, widgetData: SharedPreferences) {
        val tradeSignalsData = widgetData.getString("trade_signals_data", "[]")
        try {
            val signalsArray = org.json.JSONArray(tradeSignalsData)
            if (signalsArray.length() > 0) {
                val firstSignal = signalsArray.getJSONObject(0)
                val symbol = firstSignal.getString("symbol")
                val signalType = firstSignal.getString("signalType")
                val strength = firstSignal.getInt("strength")

                // Set main signal info
                views.setTextViewText(R.id.portfolio_equity, "$symbol $signalType")

                // Set strength as change
                views.setTextViewText(R.id.portfolio_change, "${strength}%")
                val strengthColor = when (signalType.uppercase()) {
                    "BUY" -> android.R.color.holo_green_dark
                    "SELL" -> android.R.color.holo_red_dark
                    else -> android.R.color.holo_orange_dark
                }
                views.setTextColor(R.id.portfolio_change, context.getColor(strengthColor))

                // Set signal count as percentage
                views.setTextViewText(R.id.portfolio_change_percent, "${signalsArray.length()} signals")
                views.setTextColor(R.id.portfolio_change_percent, context.getColor(android.R.color.darker_gray))
            } else {
                views.setTextViewText(R.id.portfolio_equity, "No Signals")
                views.setTextViewText(R.id.portfolio_change, "")
                views.setTextViewText(R.id.portfolio_change_percent, "")
            }
        } catch (e: Exception) {
            views.setTextViewText(R.id.portfolio_equity, "Trade Signals")
            views.setTextViewText(R.id.portfolio_change, "")
            views.setTextViewText(R.id.portfolio_change_percent, "")
        }
    }

    private fun getWidgetUrl(widgetData: SharedPreferences): String {
        val tradeSignalsData = widgetData.getString("trade_signals_data", null)
        val groupWatchlistId = widgetData.getString("group_watchlist_id", null)
        val groupId = widgetData.getString("group_watchlist_group_id", null)

        return when {
            tradeSignalsData != null -> "realizealpha://signals"
            groupWatchlistId != null && groupId != null -> "realizealpha://group-watchlist?groupId=$groupId&watchlistId=$groupWatchlistId"
            else -> "realizealpha://watchlist"
        }
    }
}