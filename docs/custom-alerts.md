# Custom Alerts

Configurable price and event-based alerts for stocks, options, crypto, and other instruments.

## Overview

The Custom Alerts feature allows users to set up personalized notifications for price movements, technical indicators, and market events across their portfolio and watchlists.

## Features

### Alert Types

#### Price Alerts
- **Price Above/Below**: Trigger when an instrument's price crosses a specified threshold
- **Percentage Change**: Alert on significant price movements (e.g., +5% or -10%)
- **Volume Alerts**: Notify on unusual trading volume

#### Technical Indicator Alerts
- **Moving Average Crossovers**: Alert when price crosses above/below MA lines
- **RSI Overbought/Oversold**: Notify when RSI enters extreme zones
- **Bollinger Band Breaks**: Alert on price breaking upper/lower bands

#### Portfolio Alerts
- **Position Size Changes**: Alert on significant changes in position values
- **P&L Thresholds**: Notify when unrealized P&L reaches specified levels
- **Options Expiration Alerts**: Action Center alerts for active option contracts approaching expiration (0 DTE, 1 DTE, 2–3 DTE), tracking moneyness (ITM automatic exercise risk vs. OTM worthless expiration) and short-leg assignment exposure with 1-tap navigation to Positions and the Options Roll Assistant.

#### Options Flow Alerts
- **Flow Criteria**: Trigger on sweeps, blocks, or smart flags (Whale, Golden Sweep, Steamroller).
- **Premium & Expiration Filters**: Set minimum premium thresholds and target short-dated contracts (0DTE, 1DTE).
- **Notification Center**: Triggered flow alerts are stored in the option flow notifications feed for quick review.

### Alert Configuration

Users can configure alerts with:
- **Instrument Selection**: Choose from portfolio holdings, watchlist items, or any symbol
- **Condition Settings**: Define trigger conditions (price levels, percentages, etc.)
- **Frequency Controls**: Set alert frequency to avoid spam (once per day, etc.)
- **Notification Methods**: Choose push notifications, in-app alerts, or email

### Alert Management

- **Active/Inactive Toggle**: Enable or disable alerts without deleting
- **Alert History**: View past triggered alerts with timestamps
- **Search & Filter**: Find triggered notifications with built-in search functionality.
- **Bulk Operations**: Enable/disable multiple alerts at once

## Implementation Details

### Data Storage
Alerts are stored in Firestore under the user's document with the following structure:
```
users/{userId}/alerts/{alertId}
```
**Triggered History:** All notification events are archived in a persistent Firestore history for audit and search.

### Notification Delivery
- Integrates with Firebase Cloud Messaging for push notifications
- Supports **Rich Push Notifications** via `flutter_local_notifications` with actionable data.
- Includes deep links to relevant app sections

### Backend Processing
- Server-side evaluation of alert conditions
- Scheduled checks using Cloud Functions
- Optimized queries to minimize database load

## Instrument View Integration

Custom alerts for an instrument are integrated directly into the instrument's detail page (`InstrumentWidget`):
- **SliverAppBar Action**: An alert icon (`Icons.add_alert_outlined`) in the top navigation bar opens the alerts list filtered to the current instrument's symbol.
- **Embedded Custom Alerts Card**: Available in `Overview`, `Signals & Tech`, and `All` tabs:
  - Displays existing alerts for the current symbol with condition indicators and trigger history.
  - Inline active/inactive toggle switches to quickly enable or pause alerts without navigating away.
  - "Add Alert" button to immediately create a new alert with the symbol pre-filled and locked.
  - "Manage Alerts" button to view and manage all alerts for that instrument in full-screen.
  - Empty state with a single-tap "Set Alert" call-to-action when no alerts are configured for the symbol.

## Usage Examples

### Setting a Price Alert from Instrument View
1. Navigate to an instrument's detail page (e.g., TSLA, NVDA, AAPL).
2. Tap the alert icon in the app bar or tap **Set Alert** in the **Custom Alerts** section of the Overview or Signals tab.
3. Configure target price, condition, or multi-rule conditions.
4. Save the alert — it immediately shows up in the instrument view and begins monitoring.

### Managing Alerts
1. Access Alerts section from main menu or user profile for all alerts.
2. Alternatively, view and toggle alerts directly on any instrument's detail page.
3. Edit or disable individual alerts.
4. Review alert history.

## Future Enhancements
- News-based alerts
- Earnings calendar alerts
- Custom indicator alerts
- Alert templates and presets