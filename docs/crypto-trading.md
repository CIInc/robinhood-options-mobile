# Cryptocurrency Trading

RealizeAlpha now supports cryptocurrency trading through the Robinhood Crypto API integration.

## Overview

The crypto trading feature provides a separate, dedicated service (`RobinhoodCryptoService`) for managing cryptocurrency positions, orders, and transactions. This is separate from the main `RobinhoodService` to provide clear separation of concerns and specialized crypto functionality.

## Architecture

### Service Layer

**`RobinhoodCryptoService`** - Dedicated service for Robinhood Crypto API
- Located: `lib/services/robinhood_crypto_service.dart`
- Endpoints:
  - Crypto API: `https://nummus.robinhood.com`
  - Market Data: `https://api.robinhood.com/marketdata`

### Data Models

#### CryptoHolding
Represents a cryptocurrency position in the user's portfolio.

**Key Fields:**
- `id` - Unique holding identifier
- `accountId` - Account the holding belongs to
- `currencyCode` - Crypto symbol (e.g., "BTC", "ETH")
- `currencyName` - Full name (e.g., "Bitcoin")
- `quantity` - Amount of crypto held
- `directCostBasis` - Total cost of holdings
- `quoteObj` - Real-time quote data

**Calculated Properties:**
- `marketValue` - Current market value (quantity × mark price)
- `averageCost` - Average cost per unit
- `totalReturn` - Total profit/loss in dollars
- `totalReturnPercent` - Total profit/loss as percentage

#### CryptoQuote
Real-time market data for cryptocurrencies.

**Key Fields:**
- `id` - Quote identifier
- `symbol` - Trading pair (e.g., "BTC-USD")
- `markPrice` - Current market price
- `askPrice` / `bidPrice` - Order book prices
- `highPrice` / `lowPrice` - Daily range
- `openPrice` - Opening price for the day
- `volume` - 24-hour trading volume

**Calculated Properties:**
- `spread` - Bid-ask spread
- `changeFromOpen` - Price change since open
- `changePercentFromOpen` - Percentage change

#### CryptoOrder
Represents a crypto buy or sell order.

**Key Fields:**
- `id` - Order identifier
- `side` - "buy" or "sell"
- `type` - "market" or "limit"
- `state` - "confirmed", "filled", "cancelled"
- `quantity` - Amount to trade
- `price` - Limit price (for limit orders)
- `averagePrice` - Actual filled price
- `fees` - Transaction fees

**Helper Methods:**
- `isFilled` - Order completed
- `isPending` - Order waiting to fill
- `canCancel` - Whether order can be cancelled

#### CryptoTransaction
Historical transaction record.

**Key Fields:**
- `type` - "order", "deposit", "withdrawal", "transfer"
- `side` - "buy" or "sell"
- `state` - "completed", "pending", "cancelled"
- `quantity` / `price` / `fees`

#### CryptoHistoricals
Historical price data for charting.

**Structure:**
- `id` / `symbol` - Currency pair identifier
- `bounds` - Market hours ("24_7" for crypto)
- `interval` - Data granularity (5minute, hour, day, etc.)
- `span` - Time range (day, week, month, year)
- `dataPoints[]` - Array of OHLCV data points

### State Management

#### CryptoHoldingStore
`ChangeNotifier` store for managing crypto positions.

**Methods:**
- `add(CryptoHolding)` - Add new holding
- `addOrUpdate(CryptoHolding)` - Add or update existing
- `remove(CryptoHolding)` - Remove holding
- `getById(id)` / `getByCurrencyCode(code)` - Lookup methods

**Aggregations:**
- `totalMarketValue` - Sum of all holdings' market value
- `totalCost` - Sum of all cost bases
- `totalReturn` - Portfolio-wide profit/loss
- `totalReturnPercent` - Portfolio return percentage

#### CryptoOrderStore
`ChangeNotifier` store for managing crypto orders.

**Methods:**
- `add(CryptoOrder)` / `addOrUpdate(CryptoOrder)` / `remove(CryptoOrder)`
- `getFilledOrders()` - Filter completed orders
- `getPendingOrders()` - Filter open orders
- `getCancelledOrders()` - Filter cancelled orders

### Firestore Persistence

Crypto data is persisted to Firestore under user documents:

**Collections:**
- `cryptoPosition` - Crypto holdings
- `cryptoOrder` - Crypto orders

**Methods:**
- `upsertCryptoPosition(CryptoHolding, userDoc)` - Save/update position
- `upsertCryptoOrders(List<CryptoOrder>, userDoc)` - Batch save orders

## API Methods

### Portfolio Management

#### Get Crypto Holdings
```dart
Future<List<CryptoHolding>> getCryptoHoldings(
  BrokerageUser user,
  CryptoHoldingStore store, {
  bool nonzero = true,
  DocumentReference? userDoc,
})
```
Fetches all cryptocurrency positions for the user. Automatically enriches holdings with real-time quotes.

**Parameters:**
- `nonzero` - If true, only returns positions with quantity > 0
- `userDoc` - Optional Firestore document reference for persistence

#### Refresh Crypto Holdings
```dart
Future<List<CryptoHolding>> refreshCryptoHoldings(
  BrokerageUser user,
  CryptoHoldingStore store
)
```
Updates existing holdings with latest quote data. Processes in batches to avoid rate limits.

### Market Data

#### Get Single Crypto Quote
```dart
Future<CryptoQuote> getCryptoQuote(
  BrokerageUser user,
  String id
)
```
Fetches real-time quote for a specific currency pair.

**Parameters:**
- `id` - Currency pair ID (not the symbol)

#### Get Multiple Crypto Quotes
```dart
Future<List<CryptoQuote>> getCryptoQuoteByIds(
  BrokerageUser user,
  List<String> ids
)
```
Batch fetch multiple quotes in a single API call.

#### Get Historical Data
```dart
Future<CryptoHistoricals> getCryptoHistoricals(
  BrokerageUser user,
  String id, {
  Bounds chartBoundsFilter = Bounds.t24_7,
  ChartDateSpan chartDateSpanFilter = ChartDateSpan.day,
})
```
Fetches historical price data for charting.

**Parameters:**
- `id` - Currency pair ID
- `chartBoundsFilter` - Market hours (crypto uses `t24_7`)
- `chartDateSpanFilter` - Time range: `day`, `week`, `month`, `year`, `all`

### Trading

#### Place Crypto Order
```dart
Future<CryptoOrder> placeCryptoOrder(
  BrokerageUser user,
  Account account,
  String currencyPairId,
  String side,
  double quantity, {
  double? price,
  String type = 'market',
  String timeInForce = 'gtc',
})
```
Places a buy or sell order for cryptocurrency.

**Parameters:**
- `side` - "buy" or "sell"
- `quantity` - Amount of crypto to trade
- `type` - "market" or "limit"
- `price` - Required for limit orders
- `timeInForce` - "gtc" (good till cancelled), "gfd" (good for day), "ioc" (immediate or cancel)

**Returns:** `CryptoOrder` with order details including state and order ID

#### Get Crypto Orders
```dart
Future<List<CryptoOrder>> getCryptoOrders(
  BrokerageUser user,
  CryptoOrderStore store
)
```
Fetches all orders (filled, pending, cancelled) for the user.

#### Stream Crypto Orders
```dart
Stream<List<CryptoOrder>> streamCryptoOrders(
  BrokerageUser user,
  CryptoOrderStore store, {
  DocumentReference? userDoc,
})
```
Real-time stream of crypto orders with automatic persistence.

#### Cancel Crypto Order
```dart
Future<void> cancelCryptoOrder(
  BrokerageUser user,
  String orderId
)
```
Cancels a pending order.

### Transaction History

#### Get Crypto Transactions
```dart
Future<List<CryptoTransaction>> getCryptoTransactions(
  BrokerageUser user, {
  String? currencyId,
})
```
Fetches transaction history including orders, deposits, withdrawals, and transfers.

**Parameters:**
- `currencyId` - Optional filter by specific cryptocurrency

### Wallet Integration

#### Get Crypto Wallet
```dart
Future<Map<String, dynamic>> getCryptoWallet(
  BrokerageUser user,
  String currencyCode
)
```
Retrieves wallet information for a specific cryptocurrency.

#### Get Supported Cryptocurrencies
```dart
Future<List<dynamic>> getSupportedCryptocurrencies(
  BrokerageUser user
)
```
Fetches list of all tradeable cryptocurrencies.

## Usage Example

### Basic Integration

```dart
import 'package:robinhood_options_mobile/services/robinhood_crypto_service.dart';
import 'package:robinhood_options_mobile/model/crypto_holding_store.dart';
import 'package:robinhood_options_mobile/model/crypto_order_store.dart';

// Initialize service and stores
final cryptoService = RobinhoodCryptoService();
final holdingStore = CryptoHoldingStore();
final orderStore = CryptoOrderStore();

// Fetch crypto portfolio
final holdings = await cryptoService.getCryptoHoldings(
  user,
  holdingStore,
  nonzero: true,
);

// Refresh quotes
await cryptoService.refreshCryptoHoldings(user, holdingStore);

// Display portfolio summary
print('Total Value: \$${holdingStore.totalMarketValue.toStringAsFixed(2)}');
print('Total Return: \$${holdingStore.totalReturn.toStringAsFixed(2)} (${holdingStore.totalReturnPercent.toStringAsFixed(2)}%)');

// Get real-time quote
final btcQuote = await cryptoService.getCryptoQuote(user, 'btc-pair-id');
print('BTC Price: \$${btcQuote.markPrice}');

// Place market buy order
final order = await cryptoService.placeCryptoOrder(
  user,
  account,
  'btc-usd-pair-id',
  'buy',
  0.001, // quantity
  type: 'market',
);
print('Order ${order.id} placed, state: ${order.state}');
```

### With Provider Pattern

```dart
// In main.dart MultiProvider setup
MultiProvider(
  providers: [
    // ... other providers
    ChangeNotifierProvider(create: (_) => CryptoHoldingStore()),
    ChangeNotifierProvider(create: (_) => CryptoOrderStore()),
  ],
  child: MyApp(),
)

// In widget
class CryptoPortfolioWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final holdingStore = Provider.of<CryptoHoldingStore>(context);
    
    return Column(
      children: [
        Text('Total Value: \$${holdingStore.totalMarketValue.toStringAsFixed(2)}'),
        Text('Total Return: ${holdingStore.totalReturnPercent.toStringAsFixed(2)}%'),
        ListView.builder(
          itemCount: holdingStore.items.length,
          itemBuilder: (context, index) {
            final holding = holdingStore.items[index];
            return ListTile(
              title: Text(holding.currencyName),
              subtitle: Text('${holding.quantity} ${holding.currencyCode}'),
              trailing: Text('\$${holding.marketValue.toStringAsFixed(2)}'),
            );
          },
        ),
      ],
    );
  }
}
```

## Testing

Comprehensive unit tests are provided in `test/crypto_model_test.dart`:

- Model parsing and serialization
- Calculated properties (returns, costs, etc.)
- Store operations (add, update, remove)
- Order state management
- Portfolio aggregations

Run tests:
```bash
flutter test test/crypto_model_test.dart
```

## API Reference

For detailed API documentation, see:
- [Robinhood Crypto Trading API](https://docs.robinhood.com/crypto/trading/)

## Security Considerations

1. **Never store API credentials in the app** - Use OAuth2 tokens through `BrokerageUser.oauth2Client`
2. **Sensitive operations use HTTPS** - All API calls are encrypted
3. **Token management** - OAuth tokens are automatically refreshed by the oauth2 library
4. **Firestore rules** - Ensure proper security rules for crypto collections
5. **Rate limiting** - The service implements batch processing to respect API rate limits

## Limitations

1. **Read-only for some operations** - Certain advanced features may require web interface
2. **Market hours** - Crypto trades 24/7, but system maintenance windows may occur
3. **Rate limits** - Respect Robinhood's API rate limits (implemented via batch processing)
4. **Fee structure** - Transaction fees are determined by Robinhood and may vary

## Future Enhancements

Potential future additions:
- [ ] Advanced order types (stop-loss, take-profit)
- [ ] Recurring buy/sell orders
- [ ] Price alerts and notifications
- [ ] Portfolio rebalancing
- [ ] Tax reporting integration
- [ ] Multi-account support
- [ ] Paper trading mode for crypto
- [ ] Technical indicators specific to crypto
- [ ] Social features (share crypto portfolios)

## Related Features

- **Copy Trading** - Copy crypto trades from other investors (see `docs/copy-trading.md`)
- **Investor Groups** - Share crypto portfolio performance with groups
- **AI Trade Signals** - AI-powered trading signals for crypto assets

## Support

For issues or questions:
- GitHub Issues: [robinhood-options-mobile](https://github.com/CIInc/robinhood-options-mobile/issues)
- Documentation: [docs.realizealpha.com](https://ciinc.github.io/robinhood-options-mobile/)
