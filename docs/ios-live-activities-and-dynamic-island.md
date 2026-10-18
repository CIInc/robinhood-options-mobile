# iOS Live Activities & Dynamic Island Widget

Real-time lock screen position tracking, P&L status, and 0DTE trailing stop alerts for active options contracts (v0.50.0, [#160](https://github.com/CIInc/robinhood-options-mobile/issues/160)).

## Overview

Live Activities bring glanceable, real-time market data to the iOS Lock Screen, StandBy mode, and Dynamic Island (iPhone 14 Pro, 15, 16 series). Designed specifically for retail options traders, this feature delivers continuous mark price updates and automated intraday trailing stop alerts—especially critical for 0DTE contracts subject to aggressive gamma acceleration and sudden intraday reversals.

```
+-----------------------------------------------------------------------------------+
| Flutter App Layer                                                                 |
|                                                                                   |
|  [OptionPositionsWidget] / [OptionInstrumentWidget]                               |
|        |                                                                          |
|        v (Long-press / Live Activity Sensors Button)                              |
|  [OptionLiveActivitySheet] <--> User configures Trailing Stop % (5%, 10%, 20%)     |
|        |                                                                          |
|        v                                                                          |
|  [LiveActivityService]                                                            |
|    - Tracks active sessions, calculates high-water mark / trailing stop price     |
|    - Detects 0DTE contracts (DTE == 0) and computes stop trigger breaches         |
|    - MethodChannel `com.realizealpha.live_activity`                               |
+----------------------------------------+------------------------------------------+
                                         | MethodChannel (start/update/end)
                                         v
+-----------------------------------------------------------------------------------+
| iOS Host Application (Runner)                                                     |
|                                                                                   |
|  [AppDelegate.swift] / [LiveActivityManager.swift]                                |
|    - Bridges MethodChannel calls to native Swift ActivityKit                     |
|    - Requests, updates, and dismisses Activity<OptionPositionAttributes>         |
+----------------------------------------+------------------------------------------+
                                         | ActivityAttributes & ContentState
                                         v
+-----------------------------------------------------------------------------------+
| PortfolioWidgetExtension (ActivityKit / SwiftUI)                                  |
|                                                                                   |
|  [PortfolioWidgetLiveActivity.swift]                                              |
|    - Lock Screen / StandBy Banner:                                                |
|        * Header: Symbol, Strike, Call/Put, Expiration, and [0DTE] Flame Badge     |
|        * Pricing: Mark Price, Total Market Value, and P&L ($ & %)                 |
|        * Trailing Stop Status Bar: Stop Price, Distance %, [STOP TRIGGERED] Alert |
|        * Deep Link: widgetURL(URL(string: "realizealpha://position/{symbol}"))    |
|    - Dynamic Island:                                                              |
|        * Compact Leading: Symbol + 0DTE indicator                                 |
|        * Compact Trailing: Color-coded P&L % or STOP badge                        |
|        * Minimal: Compact symbol / alert icon                                     |
|        * Expanded: Comprehensive 3-region metrics, stop meter, & distance buffer  |
+-----------------------------------------------------------------------------------+
```

---

## Key Capabilities

### 1. Real-Time Lock Screen Position Tracking
- **Glanceable Header**: Displays underlying symbol (e.g. `SPY`, `TSLA`, `NVDA`), strike price, contract type (`CALL`/`PUT`), and expiration date.
- **0DTE Indicator**: Automatically detects contracts expiring on the current trading day (`DTE == 0`) and highlights them with an orange `0DTE` flame badge.
- **Mark & P&L Readout**: Real-time mark price alongside total dollar gain/loss and percentage return, rendered in institutional dark-theme gradients with green/red directional indicators.

### 2. Intraday 0DTE Trailing Stop Loss Engine
Options that expire the same day can experience rapid, non-linear price decay when the underlying asset moves against the position. The Trailing Stop Loss engine provides on-device automated protection:
- **High-Water Mark Tracking**: For debit/long positions, the engine monitors the highest mark price reached since session inception (`peakPrice = max(peakPrice, markPrice)`).
- **Dynamic Stop Ratchet**: The stop price ratchets up as profits expand:
  $$\text{Trailing Stop Price} = \text{Peak Price} \times \left(1 - \frac{\text{Trailing Stop \%}}{100}\right)$$
- **Alert State & Visual Trigger**: When the current option mark breaches below the stop price:
  - The Dynamic Island switches into an urgent red `STOP` / `⚠️` state.
  - The Lock Screen widget displays an alert banner (`STOP TRIGGERED: Exceeded -X% trailing stop at $Y.YY`).
  - Tapping the notification opens the position directly in the app for immediate closing or defensive rolling.

### 3. Dynamic Island Presentation
- **Compact Leading**: Symbol with optional orange 0DTE indicator dot.
- **Compact Trailing**: Color-coded P&L % (or `STOP` warning in red when breached).
- **Minimal**: Compact 3-letter symbol or `⚠️` alert icon.
- **Expanded**:
  - *Leading*: Symbol, strike, contract type, and 0DTE badge.
  - *Trailing*: Mark price and total dollar / percentage P&L.
  - *Bottom*: Full-width trailing stop buffer meter and distance percentage readout.

---

## User Experience & Navigation

1. **Option Positions List (`OptionPositionsWidget`)**:
   - Long-press any option position to open the tactical options sheet.
   - Select **Live Activity & Dynamic Island** (indicated with the `sensors` icon).
   - Positions actively tracked on the lock screen display a subtle `sensors` icon next to their expiration date.

2. **Option Detail Screen (`OptionInstrumentWidget`)**:
   - Tapping the `sensors` icon in the AppBar opens the Live Activity configuration sheet for any active holding.

3. **Tracking Configuration Sheet (`OptionLiveActivitySheet`)**:
   - Visual mock preview of how the position appears on the Dynamic Island.
   - Quick preset chips for trailing stop selection (`5%`, `10%`, `15%`, `20%`, `25%`).
   - Real-time preview of the stop trigger price and buffer percentage.
   - One-tap controls: `Start Live Activity`, `Update Trailing Stop`, and `End Live Activity`.

---

## Platform & Entitlements Configuration

### `Info.plist`
To enable Live Activities and allow high-frequency pricing updates during fast market movements, the following keys are configured in `ios/Runner/Info.plist`:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

### Deep Linking
Tapping any region of the Live Activity triggers deep navigation to the position in RealizeAlpha via custom URL scheme:
```
realizealpha://position/{symbol}
```
If the app is running in the background or killed, iOS automatically opens RealizeAlpha and navigates directly to the instrument.
