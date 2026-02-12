# Home Screen Widgets

iOS Home Screen widgets providing quick access to portfolio data, watchlists, and trade signals.

## Overview

Home Screen Widgets allow users to view key financial information directly from their iOS Home Screen without opening the app. Widgets update in real-time and support deep linking to relevant app sections.

## Widget Types

### Portfolio Widget
Displays current portfolio value, daily P&L, and top holdings.

**Features:**
- Total portfolio value
- Day's gain/loss with percentage
- Top 3 holdings with current prices
- Tap to open portfolio overview

### Watchlist Widget
Shows selected watchlist symbols with current prices and changes.

**Features:**
- Up to 5 symbols from selected watchlist
- Real-time price updates
- Percentage and dollar changes
- Color-coded for gains/losses
- Tap symbol to view details

### Trade Signals Widget
Displays recent trade signals from the agentic trading system.

**Features:**
- Latest BUY/SELL signals
- Signal confidence scores
- Symbol and current price
- Tap to view signal details

## Configuration

### Setting Up Widgets
1. Long-press on Home Screen to enter jiggle mode
2. Tap the "+" button in the top-left corner
3. Search for "RealizeAlpha" in the widget gallery
4. Choose widget size and type
5. Place on Home Screen

### Customizing Widgets
- **Portfolio Widget**: Automatically displays user's portfolio data
- **Watchlist Widget**: Select from available group watchlists in the app
- **Trade Signals Widget**: Shows global signals (no customization needed)

## Technical Implementation

### iOS Integration
- Uses iOS 14+ WidgetKit framework
- App Groups for data sharing between app and widget extensions
- Background app refresh for data updates

### Data Synchronization
- Widgets update when app is opened or data changes
- Portfolio and watchlist data synced via `HomeWidgetService`
- Trade signals updated from Firestore snapshots

### Deep Linking
- Widgets support deep links to specific app sections
- URL schemes: `realizealpha://portfolio`, `realizealpha://watchlist/{id}`, `realizealpha://signals`

### Permissions
- Requires App Groups entitlement in iOS
- Added to `ios/Runner/Runner.entitlements`

## Data Privacy
- All widget data is stored locally on device
- No sensitive information (API keys, credentials) shared with widgets
- Widgets only display aggregated portfolio values and public market data

## Future Enhancements
- Android widgets support
- More widget sizes and layouts
- Customizable refresh intervals
- Interactive widgets with quick actions</content>
<parameter name="filePath">/Users/aymericgrassart/Documents/Repos/github.com/CIInc/robinhood-options-mobile/docs/home-widgets.md