# Multi-Indicator Automatic Trading System

## Overview

The multi-indicator automatic trading system correlates **9 technical indicators** to generate trade signals. **All 9 indicators must be "green" (BUY signal) to trigger an automatic trade.**

This system provides a comprehensive multi-factor analysis approach combining price action, momentum, trend, volume, and volatility indicators.

## The 9 Technical Indicators

### 1. Price Movement (Multi-Pattern Detection)

**Purpose:** Identifies and scores multiple bullish and bearish chart patterns from recent price action to produce a directional signal with confidence.

**Implementation:** `detectChartPattern()` in `technical-indicators.ts`

**Supported Patterns:**
- Bullish: Breakout, Double Bottom, Ascending Triangle, Cup & Handle, Bull Flag
- Bearish: Breakdown, Double Top, Head & Shoulders, Descending Triangle, Bear Flag

**Signals:**
- **BUY**: Highest-confidence bullish pattern reaches action threshold (≥ 0.60)
- **SELL**: Highest-confidence bearish pattern reaches action threshold (≥ 0.60)
- **HOLD**: No qualifying pattern or only emerging (confidence < 0.60)

**Confidence Scoring:** Each detected pattern is assigned a `confidence` (0–1) based on structure completeness and volume confirmation (e.g., breakout with volume > 130% avg adds a boost). The system selects the strongest non-neutral pattern to drive the signal.

**Key Heuristics:**
- Moving averages (5/10/20 SMA) establish trend context
- Breakout/Breakdown requires price displacement vs 20 SMA ±2%
- Double Top/Bottom similarity tolerance ~1%
- Head & Shoulders shoulder symmetry tolerance ~2%
- Triangles require flat highs/lows plus rising/falling opposing side
- Cup & Handle recovery >5% from handle low with short-term momentum
- Flags require prior impulsive move (>6%) followed by tight consolidation (<1.5% range)

**Metadata Returned:**
```json
{
   "selectedPattern": "ascending_triangle",
   "confidence": 0.63,
   "patterns": [
      {"key": "ascending_triangle", "confidence": 0.63, "direction": "bullish"},
      {"key": "breakout", "confidence": 0.60, "direction": "bullish"}
   ],
   "ma5": 101.2,
   "ma10": 100.8,
   "ma20": 99.9,
   "slope": 0.15
}
```

**Action Threshold:** Only patterns with confidence ≥ 0.60 generate BUY/SELL; otherwise the system issues a HOLD with an "emerging" reason.

**Advantages vs Previous Version:**
- Multiple pattern support instead of single breakout/cup detection
- Confidence-weighted decisions reduce false positives
- Volume-aware breakout/breakdown scoring
- Rich metadata for UI & analytics (pattern list + slope + moving averages)

**Fallback:** If no actionable pattern found, a neutral summary of price and MAs is returned.

### 2. Momentum (RSI - Relative Strength Index)

**Purpose:** Measures the momentum and identifies overbought/oversold conditions.

**Implementation:** `evaluateMomentum()` and `computeRSI()` in `technical-indicators.ts`

**Signals:**
- **BUY**: RSI < 30 (oversold) or 60 < RSI ≤ 70 (strong bullish momentum)
- **SELL**: RSI > 70 (overbought) or 30 ≤ RSI < 40 (bearish momentum)
- **HOLD**: 40 ≤ RSI ≤ 60 (neutral zone)

**Configuration:**
- Default RSI period: 14
- Configurable via `rsiPeriod` parameter

**Technical Details:**
- Classic RSI formula with smoothed averages
- Oversold threshold: 30
- Overbought threshold: 70
- Neutral range: 40-60

### 3. Market Direction (Moving Average Crossovers)

**Purpose:** Evaluates overall market trend using SPY or QQQ index.

**Implementation:** `evaluateMarketDirection()` in `technical-indicators.ts`

**Signals:**
- **BUY**: Fast MA crosses above slow MA (bullish crossover) or trend strength > 2%
- **SELL**: Fast MA crosses below slow MA (bearish crossover) or trend strength < -2%
- **HOLD**: No crossover and trend strength between -2% and 2%

**Configuration:**
- Default market index: SPY (can be changed to QQQ)
- Default fast period: 10
- Default slow period: 30
- Configurable via `marketIndexSymbol`, `smaPeriodFast`, `smaPeriodSlow`

**Technical Details:**
- Fetches market index data from Yahoo Finance
- Detects crossovers by comparing current and previous MA values
- Calculates trend strength as percentage spread between fast and slow MA

### 4. Volume

**Purpose:** Confirms price movements with volume analysis.

**Implementation:** `evaluateVolume()` in `technical-indicators.ts`

**Signals:**
- **BUY**: High volume (>150% of average) with price increase (>0.5%) or normal volume with strong price increase (>1%)
- **SELL**: High volume (>150% of average) with price decrease (<-0.5%)
- **HOLD**: Low volume (<70% of average) or neutral volume with small price changes

**Technical Details:**
- Compares current volume to 20-period average
- Correlates volume with price change
- Identifies accumulation (high volume + price up) and distribution (high volume + price down)

### 5. MACD (Moving Average Convergence Divergence)

**Purpose:** Identifies trend following momentum through the relationship between two exponential moving averages.

**Implementation:** `evaluateMACD()` and `computeMACD()` in `technical-indicators.ts`

**Signals:**
- **BUY**: MACD histogram crosses above zero (bullish crossover) or positive histogram (bullish momentum)
- **SELL**: MACD histogram crosses below zero (bearish crossover) or negative histogram (bearish momentum)
- **HOLD**: Histogram near zero (neutral)

**Configuration:**
- Fast EMA period: 12
- Slow EMA period: 26
- Signal line period: 9

**Technical Details:**
- MACD Line = Fast EMA - Slow EMA
- Signal Line = EMA of MACD Line
- Histogram = MACD Line - Signal Line
- Crossovers detected by comparing current and previous histogram values

### 6. Bollinger Bands

**Purpose:** Measures price volatility and identifies overbought/oversold conditions relative to recent price range.

**Implementation:** `evaluateBollingerBands()` and `computeBollingerBands()` in `technical-indicators.ts`

**Signals:**
- **BUY**: Price at or below lower band (oversold), or in lower third of bands
- **SELL**: Price at or above upper band (overbought), or in upper third of bands
- **HOLD**: Price in middle region of bands

**Configuration:**
- Period: 20 (SMA)
- Standard deviations: 2

**Technical Details:**
- Middle Band = 20-period SMA
- Upper Band = Middle + (2 × Standard Deviation)
- Lower Band = Middle - (2 × Standard Deviation)
- Position calculated as percentage between lower and upper bands

### 7. Stochastic Oscillator

**Purpose:** Compares closing price to price range over a period to identify momentum and overbought/oversold conditions.

**Implementation:** `evaluateStochastic()` and `computeStochastic()` in `technical-indicators.ts`

**Signals:**
- **BUY**: %K < 20 (oversold), or bullish crossover (%K crosses above %D) in oversold region
- **SELL**: %K > 80 (overbought), or bearish crossover (%K crosses below %D) in overbought region
- **HOLD**: %K between 20-80 (neutral zone)

**Configuration:**
- %K period: 14
- %D period: 3 (SMA of %K)
- Oversold threshold: 20
- Overbought threshold: 80

**Technical Details:**
- %K = ((Current Close - Lowest Low) / (Highest High - Lowest Low)) × 100
- %D = 3-period SMA of %K
- Uses high, low, and close prices

### 8. ATR (Average True Range)

**Purpose:** Measures market volatility to assess risk and potential breakout conditions.

**Implementation:** `evaluateATR()` and `computeATR()` in `technical-indicators.ts`

**Signals:**
- **BUY**: Low volatility (ATR < 60% of average) suggests potential breakout setup
- **SELL**: Never issues SELL signal (volatility is not directional)
- **HOLD**: Normal or high volatility

**Configuration:**
- Period: 14

**Technical Details:**
- True Range = max(High - Low, |High - Previous Close|, |Low - Previous Close|)
- ATR = Smoothed average of True Range values
- Compared to 14-period historical ATR average
- High volatility (>150% of avg) = caution
- Low volatility (<60% of avg) = potential breakout

### 9. OBV (On-Balance Volume)

**Purpose:** Tracks volume flow to confirm price trends and detect divergences between price and volume.

**Implementation:** `evaluateOBV()` and `computeOBV()` in `technical-indicators.ts`

**Signals:**
- **BUY**: Bullish divergence (OBV rising while price falling), or OBV uptrend confirms price rise
- **SELL**: Bearish divergence (OBV falling while price rising), or OBV downtrend confirms price decline
- **HOLD**: OBV trend neutral or not significant

**Configuration:**
- Lookback period: 20 (for trend calculation)
- Divergence threshold: ±5%
- Strong trend threshold: ±10%

**Technical Details:**
- OBV increases by volume on up days
- OBV decreases by volume on down days
- OBV unchanged when price unchanged
- Compares recent 10-period OBV average vs previous 10-period average
- Detects divergences by comparing OBV trend with price change

## How It Works

### Signal Generation Flow

1. **Data Collection**
   - Fetch historical prices and volumes for the target symbol
   - Fetch market index (SPY/QQQ) data
   - Minimum 30-60 periods of data required

2. **Indicator Evaluation**
   - Each of the 9 indicators is evaluated independently
   - Each returns: `{ signal: "BUY"|"SELL"|"HOLD", reason: string, value: number }`

3. **Multi-Indicator Correlation**
   - Function: `evaluateAllIndicators()` in `technical-indicators.ts`
   - Checks if ALL 9 indicators signal BUY
   - Returns `allGreen: true` only when all 9 are BUY

4. **Trade Decision**
   - Alpha agent (`alpha-agent.ts`) calls multi-indicator evaluation
   - If `allGreen = false`: **No trade (HOLD)**
   - If `allGreen = true`: Generate trade proposal
   - RiskGuard agent performs final risk assessment

5. **Trade Execution**
   - Trade proposal sent to risk assessment
   - If approved: Trade is executed
   - Results stored in Firestore under `agentic_trading/signals_{symbol}`

### Code Flow

```
agentic-trading.ts (getMarketData with OHLCV)
         ↓
alpha-agent.ts (handleAlphaTask)
         ↓
technical-indicators.ts (evaluateAllIndicators)
         ↓
    ┌────┴────┬────────┬───────────┬──────────┬──────┐
    ↓         ↓        ↓           ↓          ↓      ↓
  Price   Momentum  Market     Volume     MACD   Bollinger
Movement    (RSI)  Direction                      Bands
    ↓         ↓        ↓           ↓          ↓      ↓
    └────┬────┴────────┴───────────┴──────────┴──────┘
         ↓
    ┌────┴────┬─────────┬────────┐
    ↓         ↓         ↓        ↓
Stochastic  ATR       OBV    (9 total)
    ↓         ↓         ↓        ↓
    └────┬────┴─────────┴────────┘
         ↓
   All 9 Green?
         ↓
    Yes → Trade Proposal → RiskGuard → Execute
    No  → HOLD
```

## Configuration

### Backend Configuration (Firebase Functions)

File: `functions/src/agentic-trading.ts`

Default configuration:
```typescript
{
  smaPeriodFast: 10,
  smaPeriodSlow: 30,
  tradeQuantity: 1,
  maxPositionSize: 100,
  maxPortfolioConcentration: 0.5,
  rsiPeriod: 14,
  marketIndexSymbol: "SPY"
}
```

Stored in Firestore: `agentic_trading/config`

### Frontend Configuration (Flutter App)

File: `lib/widgets/agentic_trading_settings_widget.dart`

Configurable parameters:
- **SMA Period (Fast)**: Default 10 - used for market direction
- **SMA Period (Slow)**: Default 30 - used for market direction
- **RSI Period**: Default 14 - used for momentum calculation
- **Market Index Symbol**: Default "SPY" - can be changed to "QQQ"
- **Trade Quantity**: Number of shares to trade
- **Max Position Size**: Maximum position size allowed
- **Max Portfolio Concentration**: Maximum concentration in any position

### Updating Configuration

**Via Mobile App:**
1. Navigate to Agentic Trading Settings
2. Modify desired parameters
3. Tap "Save Settings"
4. Changes are persisted to Firestore

**Via Firebase Console:**
1. Open Firestore database
2. Navigate to `agentic_trading/config` document
3. Modify fields directly
4. Changes take effect on next trade evaluation

### Firestore Indexes

For optimal performance with server-side filtering, deploy the following indexes:

**Required Indexes:**
1. Composite index for filtered queries by signal type and timestamp
2. Single-field index for timestamp ordering

**Deployment:**
```bash
firebase deploy --only firestore:indexes
```

**Configuration File:** `firebase/firestore.indexes.json`

These indexes enable efficient server-side filtering of trade signals by signal type, date range, and ordering by timestamp.

## Intraday Trading

### Overview

The system supports multiple trading intervals for different time horizons:

- **15-minute signals**: Ultra-short-term trading opportunities updated every 15 minutes
- **Hourly signals**: Short-term trading opportunities updated every hour
- **Daily signals**: End-of-day trading opportunities (existing functionality)

### Interval Selection

Users can select their preferred interval in the mobile app using a SegmentedButton:

```dart
// Fetch hourly signal
await provider.fetchTradeSignal(symbol, interval: '1h');

// Fetch 15-minute signal
await provider.fetchTradeSignal(symbol, interval: '15m');

// Fetch daily signal (default)
await provider.fetchTradeSignal(symbol, interval: '1d');
```

### Market Hours Intelligence

The system automatically filters signals based on market hours with DST awareness:

- **During market hours (9:30 AM - 4:00 PM ET, Mon-Fri)**: Shows intraday signals (15m, 1h)
- **After market hours**: Shows daily signals
- **Weekends**: Shows daily signals
- **DST Support**: Automatically adjusts for Daylight Saving Time transitions
- **Visual Indicators:** 
  - Green "Market Open" chip/banner during trading hours
  - Blue "After Hours" chip/banner outside trading hours
  - Displays current interval (15m, 1h, Daily)

**Implementation:**
- `isMarketOpen` getter in `AgenticTradingProvider` exposes market status
- Checks current time against ET market hours (9:30 AM - 4:00 PM)
- Handles DST transitions automatically via timezone-aware DateTime calculations
- Used for intelligent default interval selection and UI display

### Backend Cron Jobs

**Hourly Cron (`agenticTradingIntradayCronJob`):**
- Schedule: `30 9-16 * * mon-fri` (every hour at 30 minutes past)
- Generates 1-hour interval signals
- Runs during market hours only

**15-Minute Cron (`agenticTrading15mCronJob`):**
- Schedule: `15,30,45,0 9-16 * * mon-fri` (every 15 minutes)
- Generates 15-minute interval signals
- Runs during market hours only

**End-of-Day Cron (`agenticTradingCron`):**
- Schedule: `0 16 * * mon-fri` (4:00 PM ET)
- Generates daily interval signals
- Runs after market close
- **Manual Execution:** Can be triggered via callable/HTTP endpoint (`runAgenticTradingCron`) for ad-hoc signal generation

### Signal Storage Schema

**Daily signals (backward compatible):**
```
agentic_trading/signals_<SYMBOL>
```

**Intraday signals:**
```
agentic_trading/signals_<SYMBOL>_<INTERVAL>
```

Examples:
- `agentic_trading/signals_AAPL` (daily)
- `agentic_trading/signals_AAPL_1h` (hourly)
- `agentic_trading/signals_AAPL_15m` (15-minute)

### Cache Strategy

Interval-specific cache TTLs optimize performance:

- **15m interval**: 15-minute cache expiry
- **30m interval**: 30-minute cache expiry
- **1h interval**: 1-hour cache expiry
- **1d interval**: Cache until end of trading day

Cache staleness is checked before fetching new data from Yahoo Finance API.

### Data Fetching

The `getMarketData()` function accepts interval parameters:

```typescript
await getMarketData(
  symbol,
  smaPeriodFast,
  smaPeriodSlow,
  interval,  // '15m', '30m', '1h', '1d'
  range      // '1d', '5d', '1mo', '1y', etc.
);
```

Yahoo Finance API provides OHLCV data for all supported intervals.

## Real-Time Signal Updates

### Overview

Trade signals now update in real-time using Firestore snapshot listeners, eliminating the need for manual refresh or polling.

### Implementation

**Previous Approach (Deprecated):**
```dart
// One-time fetch - missed backend updates
final snapshot = await query.get();
_tradeSignals = snapshot.docs.map(...).toList();
notifyListeners();
```

**Current Approach:**
```dart
// Real-time listener - automatically updates on changes
_tradeSignalsSubscription = query.snapshots().listen((snapshot) {
  _tradeSignals = snapshot.docs.map(...).toList();
  notifyListeners(); // Fires on every Firestore update
});
```

### Subscription Lifecycle

**Setup:**
```dart
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tradeSignalsSubscription;
```

**Cleanup:**
```dart
@override
void dispose() {
  _tradeSignalsSubscription?.cancel();
  super.dispose();
}
```

### Server Data Prioritization

The system intelligently handles cached vs server data:

1. **Initial fetch**: Requests server data explicitly with `Source.server`
2. **First snapshot**: If from cache, waits up to 1 second for server data
3. **Server arrival**: Immediately processes server data when available
4. **Fallback**: Uses cached data if server doesn't respond within 1 second
5. **Subsequent updates**: Processes all snapshots in real-time

### Benefits

- **No manual refresh**: Signals update automatically when EOD cron runs
- **Real-time updates**: Changes appear immediately across all views
- **State synchronization**: Single signal and signal list stay consistent
- **Memory safe**: Proper subscription cleanup prevents leaks

## Monitoring Trade Signals

### Firebase Firestore

Trade signals are stored in:
- Daily: `agentic_trading/signals_{SYMBOL}`
- Intraday: `agentic_trading/signals_{SYMBOL}_{INTERVAL}`

Document structure:
```json
{
  "timestamp": 1234567890000,
  "symbol": "AAPL",
  "interval": "1h",
  "signal": "BUY" | "SELL" | "HOLD",
  "reason": "All 9 indicators are GREEN - Strong BUY signal",
  "multiIndicatorResult": {
    "allGreen": true,
    "overallSignal": "BUY",
    "indicators": {
         "priceMovement": {
            "signal": "BUY",
            "reason": "Ascending Triangle pattern (conf 63%)",
            "value": 0.63,
            "metadata": {
               "selectedPattern": "ascending_triangle",
               "confidence": 0.63,
               "patterns": [ {"key": "ascending_triangle", "confidence": 0.63} ],
               "ma5": 101.2,
               "ma10": 100.8,
               "ma20": 99.9,
               "slope": 0.15
            }
         },
      "momentum": {
        "signal": "BUY",
        "reason": "RSI indicates oversold condition...",
        "value": 28.5,
        "metadata": { "rsi": 28.5, ... }
      },
      "marketDirection": {
        "signal": "BUY",
        "reason": "Market bullish: 10-day MA crossed above...",
        "value": 3.2,
        "metadata": { ... }
      },
      "volume": {
        "signal": "BUY",
        "reason": "High volume with price increase...",
        "value": 1.8,
        "metadata": { ... }
      }
    }
  },
  "currentPrice": 450.25,
  "config": { ... },
  "proposal": { ... },
  "assessment": { ... }
}
```

#### Firestore Indexes

Required composite indexes for optimized queries (configured in `firebase/firestore.indexes.json`):

**Signal type + timestamp:**
```json
{
  "collectionGroup": "agentic_trading",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "signal", "order": "ASCENDING"},
    {"fieldPath": "timestamp", "order": "DESCENDING"}
  ]
}
```

**Interval + timestamp:**
```json
{
  "collectionGroup": "agentic_trading",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "interval", "order": "ASCENDING"},
    {"fieldPath": "timestamp", "order": "DESCENDING"}
  ]
}
```

Deploy indexes with: `firebase deploy --only firestore:indexes`

### Server-Side Filtering

The `fetchAllTradeSignals()` function in `AgenticTradingProvider` supports optional server-side filtering:

**Parameters:**
- `signalType`: Filter by 'BUY', 'SELL', or 'HOLD'
- `startDate`: Filter signals after this date
- `endDate`: Filter signals before this date
- `symbols`: Filter by specific symbols (max 30 due to Firestore `whereIn` limit)
- `limit`: Limit number of results (default: 50 for intraday, 500 for daily)

**Query Limits:**
- Daily signals: 500 documents (increased to handle mixed interval data)
- Intraday signals: 200 documents
- Higher limit for daily prevents truncation when intraday signals are present

**Example Usage:**
```dart
// Fetch only BUY signals with limit
await agenticTradingProvider.fetchAllTradeSignals(
  signalType: 'BUY',
  limit: 50,
);

// Fetch signals for specific symbols
await agenticTradingProvider.fetchAllTradeSignals(
  symbols: ['AAPL', 'MSFT', 'GOOGL'],
  limit: 100,
);

// Fetch all signals (backward compatible)
await agenticTradingProvider.fetchAllTradeSignals();
```

**Performance Benefits:**
- Reduced network payload (50 vs all signals by default)
- Lower Firestore read operations
- Server-side indexed queries vs client-side filtering
- Scalable for growing signal datasets

**Note:** For symbol lists exceeding 30 items, client-side filtering is automatically applied as a fallback due to Firestore's `whereIn` limitation.

### Mobile App UI

#### Agentic Trading Settings Screen

The Agentic Trading Settings screen displays:
- Current configuration values
- Latest trade proposal (if any)
- Multi-indicator breakdown with visual status:
  - ✓ Green arrow up = BUY signal
  - ✓ Red arrow down = SELL signal
  - ✓ Gray horizontal line = HOLD signal
- Overall signal status with highlighting when all 9 are green

#### Search Tab - Trade Signals Section

The Search tab includes a Trade Signals section with filtering capabilities and market status indicators:

**Market Status Display:**
- Market status chip in filter area showing current state
- Color-coded indicators:
  - Green with clock icon: "Market Open • [Interval]"
  - Blue with calendar icon: "After Hours • [Interval]"
- Real-time updates during market open/close transitions
- Displays currently selected interval (15m, 1h, Daily)

**Filter UI:**
- FilterChips for signal types: All, BUY, SELL, HOLD
- Color-coded selection:
  - BUY: Green background with green checkmark
  - SELL: Red background with red checkmark
  - HOLD: Grey background with grey checkmark
- "All" filter now correctly includes HOLD signals
- Manual refresh button (icon button with refresh icon)
- Empty state messages when no signals match filters

**Signal Display:**
- Grid layout with trade signal cards
- Each card shows:
  - Symbol and company name
  - Signal type badge (BUY/SELL/HOLD)
  - Date and timestamp
  - Signal reason
  - Color-coded borders matching signal type
- Sorted by timestamp (newest first)

**State Synchronization:**
- Regenerating a signal in Instrument View automatically updates Search View
- No manual pull-to-refresh required
- Both `_tradeSignal` (single) and `_tradeSignals` (list) stay synchronized
- Maintains timestamp ordering after updates

## Automated Execution (Cron Jobs)

### Daily Cron Job

File: `functions/src/agentic-trading-cron.ts`

**Schedule:** Every weekday at 4:00 PM ET (after market close)

**Process:**
1. Scans all documents in `agentic_trading` collection
2. For each `chart_{SYMBOL}` document:
   - Loads configuration
   - Calls `performTradeProposal()` with symbol and `interval: '1d'`
   - Multi-indicator evaluation runs
   - Trade executed if all indicators are green and risk check passes
3. Results stored in `agentic_trading/signals_{SYMBOL}`

### Intraday Cron Jobs

File: `functions/src/agentic-trading-intraday-cron.ts`

**Hourly Schedule:** `30 9-16 * * mon-fri` (every hour at 30 minutes past, during market hours)

**15-Minute Schedule:** `15,30,45,0 9-16 * * mon-fri` (every 15 minutes during market hours)

**Process:**
1. Scans all documents in `agentic_trading` collection
2. For each `chart_{SYMBOL}` document:
   - Loads configuration
   - Calls `performTradeProposal()` with symbol and appropriate interval
   - Multi-indicator evaluation runs
   - Trade executed if all indicators are green and risk check passes
3. Results stored in `agentic_trading/signals_{SYMBOL}_{INTERVAL}`

**Deployment:**
```bash
cd src/robinhood_options_mobile/functions
firebase deploy --only functions:agenticTradingIntradayCronJob,functions:agenticTrading15mCronJob
```

**Monitoring:**
- Check Firebase Functions logs
- View `agentic_trading/signals_{SYMBOL}` and `signals_{SYMBOL}_{INTERVAL}` documents
- Review trade proposals in mobile app
- Monitor real-time signal updates in Search tab

## Testing

### Manual Testing via Mobile App

1. Navigate to Agentic Trading Settings
2. Enable "Enable Agentic Trading"
3. Configure parameters (optional)
4. Tap "Initiate Test Trade Proposal"
5. Review indicator status display
6. Check if all 9 indicators are green

### Testing Individual Indicators

You can test individual indicators by:

1. **Price Movement**: Review 20+ periods of price data
2. **Momentum**: Check RSI calculation with 14+ periods
3. **Market Direction**: Verify MA crossovers on SPY/QQQ
4. **Volume**: Analyze volume relative to 20-period average

### Example Test Scenarios

**Scenario 1: Strong Bullish Signal**
- Price breaks out above 20-day MA
- RSI < 30 (oversold)
- SPY 10-day MA crosses above 30-day MA
- Volume spike with price increase
- **Expected Result:** All 9 indicators BUY → Trade executed

**Scenario 2: Mixed Signals**
- Price in consolidation
- RSI = 50 (neutral)
- SPY trending sideways
- Low volume
- **Expected Result:** HOLD → No trade

**Scenario 3: Bearish Signal**
- Price breaks down below MAs
- RSI > 70 (overbought)
- SPY 10-day MA crosses below 30-day MA
- Volume spike with price decrease
- **Expected Result:** All 9 indicators SELL → Potential short (if enabled)

## Best Practices

### Configuration Tuning

1. **Conservative Approach:**
   - RSI period: 14-20 (longer period = smoother)
   - SMA fast/slow: 10/30 or 20/50
   - Requires strong signals from all indicators

2. **Aggressive Approach:**
   - RSI period: 7-10 (shorter period = more sensitive)
   - SMA fast/slow: 5/15 or 8/21
   - More frequent signals but higher false positives

3. **Market Index Selection:**
   - Use **SPY** for broad market correlation
   - Use **QQQ** for tech-heavy portfolios

### Risk Management

The multi-indicator system works best when combined with:
- Position sizing rules (maxPositionSize)
- Portfolio concentration limits (maxPortfolioConcentration)
- RiskGuard agent assessment
- Stop-loss orders (implement separately)

### Monitoring

Regularly review:
- Signal frequency (how often all 9 align)
- False positive rate
- Trade win/loss ratio
- Indicator individual performance

## Troubleshooting

### No Trades Being Generated

**Check:**
1. Is agentic trading enabled in settings?
2. Are all 9 indicators rarely aligning?
3. Review Firestore `signals_{SYMBOL}` for indicator status
4. Check Firebase Functions logs for errors
5. Verify market data is being fetched (Yahoo Finance API working)
6. Ensure Firestore indexes are deployed for signal queries

### Signals Not Showing in Search View

**Check:**
1. Verify signals exist in Firestore `agentic_trading/signals_{SYMBOL}`
2. Check if filters are too restrictive (try "All" filter)
3. Verify `fetchAllTradeSignals()` is being called
4. Check provider is properly connected with Consumer widget
5. Review Firebase Functions logs for query errors
6. Ensure Firestore indexes are deployed and active

### Too Many False Signals

**Solutions:**
1. Increase RSI period for smoother signals
2. Increase SMA periods for market direction
3. Add additional filters (e.g., minimum price change threshold)
4. Tighten volume requirements

### Indicators Not Updating

**Check:**
1. Firebase Functions are deployed and running
2. Cron job is executing (check logs)
3. Yahoo Finance API is accessible
4. Firestore has chart data cached

## Future Enhancements

Potential improvements:
1. **Additional Indicators:**
   - ✅ MACD (Moving Average Convergence Divergence) - **IMPLEMENTED**
   - ✅ Bollinger Bands - **IMPLEMENTED**
   - ✅ Stochastic Oscillator - **IMPLEMENTED**
   - ✅ ATR (Average True Range) - **IMPLEMENTED**
   - ✅ OBV (On-Balance Volume) - **IMPLEMENTED**
   - ADX (Average Directional Index)
   - Ichimoku Cloud
   - Fibonacci Retracements

2. **Machine Learning:**
   - Pattern recognition using historical data
   - Adaptive indicator weighting
   - Predictive models for indicator correlation

3. **Backtesting:**
   - Historical performance analysis
   - Strategy optimization
   - Parameter tuning based on past data

4. **Advanced Risk Management:**
   - Dynamic position sizing
   - Correlation analysis across portfolio
   - Volatility-adjusted indicators

5. **Real-time Monitoring:**
   - Intraday signal generation
   - WebSocket connections for live data
   - Push notifications for trade signals

## References

- **Chart Patterns:** [BabyPips Chart Patterns Cheat Sheet](https://www.babypips.com/learn/forex/chart-patterns-cheat-sheet)
- **RSI:** Classic Relative Strength Index by J. Welles Wilder
- **Moving Averages:** Technical analysis fundamentals
- **Volume Analysis:** Price-volume relationship principles

## Support

For questions or issues:
1. Check Firebase Functions logs
2. Review Firestore documents
3. Test individual indicators manually
4. Consult the codebase:
   - `functions/src/technical-indicators.ts`
   - `functions/src/alpha-agent.ts`
   - `functions/src/agentic-trading.ts`
