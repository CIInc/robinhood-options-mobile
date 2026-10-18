# Crypto Trading

RealizeAlpha now supports cryptocurrency trading, allowing users to trade digital assets directly within the app. This feature provides a seamless experience for managing crypto portfolios alongside stocks and options.

## Features

- **Real-Time Quotes:** View real-time price data for supported cryptocurrencies with **Animated Price Text** that color-codes price changes (green for up, red for down).
- **Order Placement:** Place **Market** and **Limit** orders for buying and selling crypto.
- **Order Management:** View and manage open crypto orders, including the ability to cancel pending orders.
- **Portfolio Integration:** Crypto holdings are integrated into the main portfolio view, allowing for a holistic view of your assets.
- **Dedicated Widgets:**
    - **`TradeForexWidget`:** A dedicated widget for placing crypto orders with an intuitive interface.
    - **`ForexOrdersWidget`:** A widget to list and filter your crypto orders.
    - **`ForexPositionsWidget`:** Displays your current crypto holdings and their performance.
    - **`ForexInstrumentWidget`:** Full detail view featuring advanced charting, technical analysis, and AI insights.

## Instrument View & Technical Analysis

The `ForexInstrumentWidget` brings full parity with standard equity instruments:

- **Technical Analysis Card:** An animated summary card displaying consensus verdict (`Strong Buy`, `Buy`, `Neutral`, `Sell`, `Strong Sell`), period sample count, `TTM Squeeze` badge, bullish/bearish ratio bar, and quick metrics (`RSI`, `MACD`).
- **Interactive Modal Bottom Sheet:** Tap the Technical Analysis card to open an in-depth breakdown categorized into:
  - **Momentum & Oscillators:** RSI (14), Stochastic (14, 3), CCI (20), Williams %R (14), MACD (12, 26, 9), ROC (9), and Chaikin Money Flow (20).
  - **Trend Strength:** ADX (14), Ichimoku Cloud (Span A & B), and Parabolic SAR.
  - **Moving Averages:** SMA 10, SMA 20, SMA 50, SMA 200, EMA 12, EMA 26, and VWAP.
  - **Volatility & Volume:** ATR (14), OBV, Bollinger Bands, and TTM Squeeze indicator.
  - **Indicator Documentation:** Every indicator includes an info icon `(i)` opening comprehensive formula and interpretation dialogs via `IndicatorDocumentationWidget`.
- **Candlestick Mode & Chart Settings:**
  - Toggle between Line Chart and Candlestick modes with bucketed candle generation.
  - Quick presets: **Trend Following** (SMA 20/50, EMA 12), **Mean Reversion** (Bollinger, SMA 20, VWAP), and **Reset All**.
  - Built-in **Indicator Help** dialog explaining moving averages, VWAP, and Bollinger Bands.
- **Adaptive Volume Handling:** Volume series, indicators, and metrics adaptively hide when OTC volume data is zero or not provided by the broker API.
- **Haptic Date Filter Bar:** Compact date span selector (1D, 1W, 1M, 3M, 1Y, 5Y) with light haptic feedback.
- **AI Market Insights & Assistant:** Integrated generative summaries, sentiment, and trade strategies with direct assistant chat.

## How to Trade Crypto

1.  **Navigate to Crypto:** Use the navigation menu or search to find the cryptocurrency you wish to trade.
2.  **View Details:** Tap on the crypto asset to view its details, including charts and current price.
3.  **Place Order:** Tap the "Trade" button to open the `TradeForexWidget`.
4.  **Configure Order:**
    - Select "Buy" or "Sell".
    - Choose the order type: **Market** (execute immediately at best price) or **Limit** (set a specific price).
    - For Limit orders, enter your desired **Limit Price**.
    - Enter the quantity or amount.
    - **Time in Force:** Defaults to **GTC** (Good Till Cancelled).
5.  **Review and Confirm:** Review your order details and swipe to confirm placement.

## Supported Assets

The app currently supports a range of popular cryptocurrencies available through the brokerage integration. Please check the app for the full list of supported assets.

## Future Enhancements

- **Advanced Charting:** Enhanced charting tools specifically for crypto assets.
- **Price Alerts:** Set custom price alerts for your favorite cryptocurrencies.
- **Recurring Buys:** Schedule recurring purchases for dollar-cost averaging.
