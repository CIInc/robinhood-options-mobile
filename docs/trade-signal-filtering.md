# Trade Signal Filtering

## Overview

This feature adds server-side filtering capabilities to the trade signals in the Search tab, improving performance and user experience when working with large numbers of signals.

## Features

### Filter by Signal Type

Users can now filter trade signals by type using filter chips:

- **All** - Show all signals (default)
- **BUY** - Show only buy signals (highlighted in green)
- **SELL** - Show only sell signals (highlighted in red)
- **HOLD** - Show only hold signals (highlighted in grey)

### Manual Refresh

A refresh button allows users to manually reload signals while maintaining their active filters.

## Technical Implementation

### Backend (AgenticTradingProvider)

The `fetchAllTradeSignals()` method now accepts optional filtering parameters:

```dart
Future<void> fetchAllTradeSignals({
  String? signalType,        // Filter by 'BUY', 'SELL', or 'HOLD'
  DateTime? startDate,       // Filter signals after this date
  DateTime? endDate,         // Filter signals before this date
  List<String>? symbols,     // Filter by specific symbols (max 30 due to Firestore 'whereIn' limit)
  int? limit,                // Limit number of results (default: 50)
}) async {
  // Implementation...
}
```

**Key Features:**
- Server-side filtering using Firestore `.where()` queries
- Chronological ordering with `.orderBy('timestamp', descending: true)`
- Default limit of 50 results to prevent excessive data fetching
- Client-side fallback for symbol lists > 30 items (Firestore `whereIn` limitation)
- Full backward compatibility (all parameters optional)

### Firestore Indexes

Two composite indexes are required for optimal performance:

```json
{
  "collectionGroup": "agentic_trading",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "signal", "order": "ASCENDING"},
    {"fieldPath": "timestamp", "order": "DESCENDING"}
  ]
},
{
  "collectionGroup": "agentic_trading",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "timestamp", "order": "DESCENDING"}
  ]
}
```

**Deploy indexes:**
```bash
firebase deploy --only firestore:indexes
```

### UI (SearchWidget)

**Filter State Variables:**
- `tradeSignalFilter` - Current filter type (null, 'BUY', 'SELL', 'HOLD')
- `tradeSignalStartDate` - Start date for filtering (optional)
- `tradeSignalEndDate` - End date for filtering (optional)
- `tradeSignalLimit` - Maximum number of results (default: 50)

**UI Components:**
- Filter chips above the Trade Signals grid
- Color-coded filters (green for BUY, red for SELL, grey for HOLD)
- Refresh button for manual reload

## Usage Examples

### Example 1: Filter by Signal Type

```dart
// Show only BUY signals
agenticTradingProvider.fetchAllTradeSignals(signalType: 'BUY');

// Show only SELL signals
agenticTradingProvider.fetchAllTradeSignals(signalType: 'SELL');

// Show all signals (default)
agenticTradingProvider.fetchAllTradeSignals();
```

### Example 2: Date Range Filtering

```dart
// Get signals from the last 7 days
final startDate = DateTime.now().subtract(Duration(days: 7));
agenticTradingProvider.fetchAllTradeSignals(
  startDate: startDate,
  limit: 100,
);
```

### Example 3: Symbol Filtering

```dart
// Filter by specific symbols
agenticTradingProvider.fetchAllTradeSignals(
  symbols: ['AAPL', 'GOOGL', 'MSFT'],
  signalType: 'BUY',
);
```

### Example 4: Combined Filters

```dart
// BUY signals for specific symbols in the last month
final startDate = DateTime.now().subtract(Duration(days: 30));
agenticTradingProvider.fetchAllTradeSignals(
  signalType: 'BUY',
  symbols: ['AAPL', 'TSLA'],
  startDate: startDate,
  limit: 50,
);
```

## Performance Benefits

1. **Reduced Network Traffic**: Only fetches filtered results instead of all signals
2. **Faster Queries**: Firestore indexes enable efficient server-side filtering
3. **Lower Costs**: Fewer Firestore read operations
4. **Better UX**: Faster response times, especially with large datasets
5. **Scalability**: Handles growing number of signals without performance degradation

## Backward Compatibility

The implementation is fully backward compatible. Existing code that calls `fetchAllTradeSignals()` without parameters will continue to work as before, fetching the 50 most recent signals.

## Firestore Limitations

- **`whereIn` Limit**: Firestore limits `whereIn` queries to 30 items
  - **Solution**: Client-side filtering is applied for symbol lists > 30
- **Compound Queries**: Some filter combinations may require additional indexes
  - **Solution**: Required indexes are defined in `firestore.indexes.json`

## Future Enhancements

Potential future improvements:

1. Date range picker UI for startDate/endDate filtering
2. Multi-symbol search/autocomplete
3. Save and load filter presets
4. Export filtered results
5. Analytics on filter usage patterns

## Related Files

- `/src/robinhood_options_mobile/lib/model/agentic_trading_provider.dart` - Backend filtering logic
- `/src/robinhood_options_mobile/lib/widgets/search_widget.dart` - UI filter controls
- `/src/robinhood_options_mobile/firebase/firestore.indexes.json` - Firestore indexes
- `/docs/multi-indicator-trading.md` - Multi-indicator trading system documentation
