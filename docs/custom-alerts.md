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

## Usage Examples

### Setting a Price Alert
1. Navigate to an instrument's detail page
2. Tap the alert icon
3. Choose "Price Alert"
4. Set target price and direction (above/below)
5. Configure notification preferences

### Managing Alerts
1. Access Alerts section from main menu
2. View active alerts list
3. Edit or disable individual alerts
4. Review alert history

## Future Enhancements
- News-based alerts
- Earnings calendar alerts
- Custom indicator alerts
- Alert templates and presets</content>
<parameter name="filePath">/Users/aymericgrassart/Documents/Repos/github.com/CIInc/robinhood-options-mobile/docs/custom-alerts.md