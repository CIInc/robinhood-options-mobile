# Multi-Indicator Automatic Trading System

## Overview

The multi-indicator automatic trading system correlates **19 technical indicators** to generate trade signals.

This system provides a comprehensive multi-factor analysis approach combining price action, momentum, trend, volume, and volatility indicators. It uses a **Weighted Signal Strength system** where indicators are weighted by importance (Price Movement > Momentum/Trend > Others) to calculate a final **Signal Strength score (0-100)**.

## Signal Discovery & Filtering

Users can explore trade signals in the **Search** tab using advanced filtering options:

1.  **Signal Strength**: Filter by **Strong** (75-100), **Moderate** (50-74), or **Weak** (0-49) signals.
2.  **Indicator States**: Filter by specific indicator states using a 4-way toggle (Off/BUY/SELL/HOLD). For example, you can search for "RSI: BUY" and "MACD: BUY" to find specific momentum setups.
3.  **Sorting**: Sort results by **Signal Strength** (default) or **Timestamp** to find the most relevant or most recent signals.

*Note: Signal Strength and Indicator filters are exclusive. Selecting one type clears the other to ensure clear, non-conflicting results.*

## Signal Strength Calculation

The system uses a weighted scoring model to determine the overall strength of a trade signal. Not all indicators are created equal; some provide earlier or more reliable signals than others.

**Weight Distribution:**

1.  **High Impact (Weight 1.5):**
    *   **Price Movement**: Patterns and candlestick formations are the most direct reflection of market sentiment and often precede other indicators.

2.  **Medium Impact (Weight 1.2):**
    *   **Momentum**: RSI, Stochastic (Leading indicators).
    *   **Trend**: MACD, ADX, Market Direction (Trend confirmation).
    *   **Support/Resistance**: Fibonacci Retracements, VWAP.

3.  **Standard Impact (Weight 1.0):**
    *   **Volume/Volatility**: Volume, Bollinger Bands, ATR, OBV, Chaikin Money Flow, Williams %R, Ichimoku Cloud, CCI, Parabolic SAR, ROC.

The final score (0-100) reflects the net positive influence of all indicators. A score > 75 is considered a **Strong BUY**, while a score < 25 is a **Strong SELL**.

## The 18 Technical Indicators

### 1. Price Movement (Multi-Pattern Detection)

**Purpose:** Identifies and scores multiple bullish and bearish chart patterns (classic and candlestick) from recent price action to produce a directional signal with confidence.

**Implementation:** `detectChartPattern()` in `technical-indicators.ts`

**Supported Patterns:**
- **Classic:**
  - Bullish: Breakout, Double Bottom, Ascending Triangle, Cup & Handle, Bull Flag
  - Bearish: Breakdown, Double Top, Head & Shoulders, Descending Triangle, Bear Flag
- **Candlestick (New):**
  - Bullish: Bullish Engulfing, Hammer
  - Bearish: Bearish Engulfing, Shooting Star

**Signals:**
- **BUY**: Highest-confidence bullish pattern reaches action threshold (≥ 0.60)
- **SELL**: Highest-confidence bearish pattern reaches action threshold (≥ 0.60)
- **HOLD**: No qualifying pattern or only emerging (confidence < 0.60)

**Confidence Scoring:** Each detected pattern is assigned a `confidence` (0–1). Candlestick patterns like Engulfing and Hammer/Shooting Star are assigned high confidence (0.60-0.65) as they often signal immediate reversals.

**Key Heuristics:**
- Moving averages (5/10/20 SMA) establish trend context
- Breakout/Breakdown requires price displacement vs 20 SMA ±2%
- Double Top/Bottom similarity tolerance ~1%
- Head & Shoulders shoulder symmetry tolerance ~2%
- Triangles require flat highs/lows plus rising/falling opposing side
- Cup & Handle recovery >5% from handle low with short-term momentum; **edge-case guard** when handle window < 5 bars
- Flags require prior impulsive move (>6%) followed by tight consolidation (<1.5% range)
- **Improved (v2)**: Linear regression slope now properly mean-centered on price (uses `yMean`) instead of anchoring to last price for accurate trend calculation

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

**Purpose:** Measures the momentum and identifies overbought/oversold conditions, with divergence detection for early reversal signals.

**Implementation:** `evaluateMomentum()` and `computeRSI()` in `technical-indicators.ts`

**Signals:**
- **BUY**: RSI < 30 (oversold), 60 < RSI ≤ 70 (strong bullish momentum), or **bullish divergence** (RSI rising while price falling)
- **SELL**: RSI > 70 (overbought), 30 ≤ RSI < 40 (bearish momentum), or **bearish divergence** (RSI falling while price rising)
- **HOLD**: 40 ≤ RSI ≤ 60 (neutral zone)

**Configuration:**
- Default RSI period: 14
- Configurable via `rsiPeriod` parameter

**Technical Details:**
- Classic RSI formula with smoothed averages
- Oversold threshold: 30
- Overbought threshold: 70
- Neutral range: 40-60
- **Divergence Detection (v3)**: Compares RSI trend vs price trend over 10 periods
  - Bullish divergence: Price declining >1% while RSI rising >3 points
  - Bearish divergence: Price rising >1% while RSI falling >3 points
- Divergence signals take priority over standard threshold signals

### 3. Market Direction (Moving Average Crossovers)

**Purpose:** Evaluates overall market trend using SPY or QQQ index.

**Implementation:** `evaluateMarketDirection()` in `technical-indicators.ts`

**Signals:**
- **BUY**: Fast SMA (10) > Slow SMA (30) (Bullish trend)
- **SELL**: Fast SMA (10) < Slow SMA (30) (Bearish trend)
- **HOLD**: SMAs are equal or insufficient data

**Configuration:**
- Default Fast SMA: 10
- Default Slow SMA: 30
- Default Index: SPY
- Configurable via `fastSmaPeriod`, `slowSmaPeriod`, and `marketIndex` parameters

### 4. Volume (Volume Oscillator)

**Purpose:** Confirms price moves with volume analysis.

**Implementation:** `evaluateVolume()` in `technical-indicators.ts`

**Signals:**
- **BUY**: Volume > 120% of 20-period average (Strong buying pressure)
- **SELL**: Volume > 150% of 20-period average on down day (Panic selling)
- **HOLD**: Volume within normal range

### 5. MACD (Moving Average Convergence Divergence)

**Purpose:** Trend-following momentum indicator.

**Implementation:** `evaluateMACD()` in `technical-indicators.ts`

**Signals:**
- **BUY**: MACD line crosses above Signal line (Bullish crossover)
- **SELL**: MACD line crosses below Signal line (Bearish crossover)
- **HOLD**: No crossover

### 6. Bollinger Bands

**Purpose:** Measures volatility and potential overbought/oversold conditions.

**Implementation:** `evaluateBollingerBands()` in `technical-indicators.ts`

**Signals:**
- **BUY**: Price touches or crosses below Lower Band (Oversold/Bounce candidate)
- **SELL**: Price touches or crosses above Upper Band (Overbought/Reversal candidate)
- **HOLD**: Price within bands

### 7. Stochastic Oscillator

**Purpose:** Momentum indicator comparing a particular closing price of a security to a range of its prices over a certain period of time.

**Implementation:** `evaluateStochastic()` in `technical-indicators.ts`

**Signals:**
- **BUY**: %K crosses above %D and both are < 20 (Oversold crossover)
- **SELL**: %K crosses below %D and both are > 80 (Overbought crossover)
- **HOLD**: No crossover or within neutral range

### 8. ATR (Average True Range)

**Purpose:** Measures market volatility.

**Implementation:** `evaluateATR()` in `technical-indicators.ts`

**Signals:**
- **BUY**: ATR is increasing (Volatility expansion, often accompanies trend starts)
- **SELL**: ATR is extremely high (Potential exhaustion)
- **HOLD**: ATR is stable or decreasing

### 9. OBV (On-Balance Volume)

**Purpose:** Uses volume flow to predict changes in stock price.

**Implementation:** `evaluateOBV()` in `technical-indicators.ts`

**Signals:**
- **BUY**: OBV is rising (Volume confirming price increase)
- **SELL**: OBV is falling (Volume confirming price decrease)
- **HOLD**: OBV is flat

### 10. VWAP (Volume Weighted Average Price)

**Purpose:** Provides the average price a stock has traded at throughout the day, based on both volume and price.

**Implementation:** `evaluateVWAP()` in `technical-indicators.ts`

**Signals:**
- **BUY**: Price crosses above VWAP (Bullish sentiment)
- **SELL**: Price crosses below VWAP (Bearish sentiment)
- **HOLD**: Price near VWAP

### 11. ADX (Average Directional Index)

**Purpose:** Measures the strength of a trend.

**Implementation:** `evaluateADX()` in `technical-indicators.ts`

**Signals:**
- **BUY**: ADX > 25 and +DI > -DI (Strong Bullish Trend)
- **SELL**: ADX > 25 and -DI > +DI (Strong Bearish Trend)
- **HOLD**: ADX < 25 (Weak or No Trend)

### 12. Williams %R

**Purpose:** Momentum indicator that measures overbought and oversold levels.

**Implementation:** `evaluateWilliamsR()` in `technical-indicators.ts`

**Signals:**
- **BUY**: %R < -80 (Oversold)
- **SELL**: %R > -20 (Overbought)
- **HOLD**: %R between -20 and -80

### 13. Ichimoku Cloud

**Purpose:** Comprehensive indicator that defines support and resistance, identifies trend direction, gauges momentum, and provides trading signals.

**Implementation:** `evaluateIchimokuCloud()` in `technical-indicators.ts`

**Signals:**
- **BUY**: Price > Cloud AND Conversion Line > Base Line (TK Cross Bullish) AND Cloud is Green (Span A > Span B).
- **SELL**: Price < Cloud AND Conversion Line < Base Line (TK Cross Bearish) AND Cloud is Red (Span A < Span B).
- **HOLD**: Price inside Cloud or mixed signals.

### 14. CCI (Commodity Channel Index)

**Purpose:** Momentum-based oscillator used to identify cyclical trends and overbought/oversold levels.

**Implementation:** `evaluateCCI()` in `technical-indicators.ts`

**Signals:**
- **BUY**: CCI < -100 (Oversold rebound) or crosses above 100 (Trend strength).
- **SELL**: CCI > 100 (Overbought reversal) or crosses below -100 (Trend weakness).
- **HOLD**: CCI between -100 and 100 (Neutral).

### 15. Parabolic SAR (Stop and Reverse)

**Purpose:** Trend-following indicator that highlights potential reversals and sets trailing stop levels.

**Implementation:** `evaluateParabolicSAR()` in `technical-indicators.ts`

**Signals:**
- **BUY**: Price crosses above the SAR dots (Bullish reversal).
- **SELL**: Price crosses below the SAR dots (Bearish reversal).
- **HOLD**: Trend continuation (dots remain on same side).

### 16. ROC (Rate of Change)

**Purpose:** Momentum oscillator measuring the percentage change in price over a given period.

**Implementation:** `evaluateROC()` in `technical-indicators.ts`

**Parameters:**
- Period: `9 bars` (default)

**Signals:**
- **BUY**: ROC > 5% (Strong Upward Momentum).
- **SELL**: ROC < -5% (Strong Downward Momentum).
- **HOLD**: -5% ≤ ROC ≤ 5% (Neutral momentum).

### 17. Chaikin Money Flow (CMF)

**Purpose:** Combines price and volume to measure buying and selling pressure.

**Implementation:** `evaluateChaikinMoneyFlow()` in `technical-indicators.ts`

**Signals:**
- **BUY**: CMF > 0.05 (Buying Pressure)
- **SELL**: CMF < -0.05 (Selling Pressure)
- **HOLD**: Neutral

### 18. Fibonacci Retracements

**Purpose:** Identifies potential support and resistance levels based on recent high/low range.

**Implementation:** `evaluateFibonacciRetracements()` in `technical-indicators.ts`

**Signals:**
- **BUY**: Price bounces off support level (e.g., 61.8% or 50% retracement in uptrend)
- **SELL**: Price rejects resistance level (in downtrend)
- **HOLD**: No significant interaction

### 19. Pivot Points

**Purpose:** Uses the previous period's high, low, and close to project support and resistance levels (Standard method).

**Implementation:** `evaluatePivotPoints()` in `technical-indicators.ts`

**Signals:**
- **BUY**: Price > Pivot Point (Bullish Bias)
- **SELL**: Price < Pivot Point (Bearish Bias)
- **HOLD**: Price at Pivot Point

## Signal Strength Score

**Purpose:** Quantifies overall indicator alignment on a 0-100 scale.

**Calculation:**
```
signalStrength = ((buyCount - sellCount + totalIndicators) / (2 × totalIndicators)) × 100
```

**Interpretation:**
- **100**: All 19 indicators are BUY (perfect bullish alignment)
- **75-99**: Strong bullish bias, most indicators aligned
- **50**: Neutral (equal BUY and SELL signals, or all HOLD)
- **25-49**: Strong bearish bias
- **0**: All 19 indicators are SELL (perfect bearish alignment)

**Use Cases:**
- Filter signals by strength threshold (e.g., only act on strength > 75)
- Gauge confidence in trade setup
- Track signal strength trends over time

## How It Works

### Signal Generation Flow

1. **Data Collection**
   - Fetch historical prices and volumes for the target symbol
   - Fetch market index (SPY/QQQ) data
   - Minimum 30-60 periods of data required

2. **Indicator Evaluation**
   - Each of the 19 indicators is evaluated independently
   - Each returns: `{ signal: "BUY"|"SELL"|"HOLD", reason: string, value: number }`

3. **Multi-Indicator Correlation**
   - Function: `evaluateAllIndicators()` in `technical-indicators.ts`
   - Checks if ALL 19 indicators signal BUY
   - Returns `allGreen: true` only when all 19 are BUY

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
    ┌────┴────┬────────┬───────────┬──────────┬───────────┐
    ↓         ↓        ↓           ↓          ↓           ↓
  Price   Momentum  Market     Volume     MACD      Bollinger
Movement  (RSI+Div) Direction                        Bands
    ↓         ↓        ↓           ↓          ↓           ↓
    └────┬────┴────────┴───────────┴──────────┴───────────┘
         ↓
    ┌────┴────┬─────────┬────────┬────────┬────────┐
    ↓         ↓         ↓        ↓        ↓        ↓
Stochastic  ATR       OBV      VWAP     ADX   Williams%R
    ↓         ↓         ↓        ↓        ↓        ↓
    └────┬────┴─────────┴────────┴────────┴────────┘
         ↓
   All 12 Green? + Signal Strength Score
         ↓
    Yes → Trade Proposal → RiskGuard → Execute
    No  → HOLD (with strength score for analytics)
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
  "reason": "All 12 indicators are GREEN - Strong BUY signal",
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
- Overall signal status with highlighting when all 12 are green

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
6. Check if all 12 indicators are green

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
- **Expected Result:** All 12 indicators BUY → Trade executed

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
- **Expected Result:** All 12 indicators SELL → Potential short (if enabled)

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
- Signal frequency (how often all 12 align)
- False positive rate
- Trade win/loss ratio
- Indicator individual performance

## Troubleshooting

### No Trades Being Generated

**Check:**
1. Is agentic trading enabled in settings?
2. Are all 12 indicators rarely aligning?
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
   - ✅ VWAP (Volume Weighted Average Price) - **IMPLEMENTED v3**
   - ✅ ADX (Average Directional Index) - **IMPLEMENTED v3**
   - ✅ Williams %R - **IMPLEMENTED v3**
   - ✅ RSI Divergence Detection - **IMPLEMENTED v3**
   - ✅ Ichimoku Cloud - **IMPLEMENTED**
   - ✅ Fibonacci Retracements - **IMPLEMENTED**
   - ✅ Parabolic SAR - **IMPLEMENTED**
   - ✅ Chaikin Money Flow - **IMPLEMENTED**
   - ✅ Rate of Change (ROC) - **IMPLEMENTED**

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

## Recent Improvements (v2)

The technical indicators module has been improved for accuracy, robustness, and edge-case handling:

### Bollinger Bands Precision
- **Change**: Now uses sample standard deviation (N−1) instead of population (N)
- **Benefit**: Produces band widths matching industry-standard implementations (TradingView, etc.)
- **Impact**: More accurate volatility measurement and overbought/oversold threshold detection
- **Formula**: `variance = sum(squared_diffs) / (period - 1)` when period > 1

### OBV Robustness
- **Change 1**: OBV initialization now starts at 0 instead of first volume value
  - **Benefit**: Eliminates first-bar scale bias that could skew trend calculations
  - **Impact**: More consistent divergence detection across all symbols regardless of volume scale
- **Change 2**: Division-by-zero guard added for trend calculation
  - **Benefit**: Prevents infinite/NaN values when older OBV average ≈ 0
  - **Guard**: Returns `obvTrend = 0` if denominator < 1e-9
  - **Impact**: Handles near-zero volume periods gracefully

### Pattern Detection Accuracy
- **Chart Pattern - Cup & Handle**: Edge-case guard prevents errors with insufficient lookback bars
  - **Guard**: Validates handle window length > 0 before computing minimum
  - **Benefit**: Graceful handling of early-bar scenarios or short price histories
  
- **Price Movement - Linear Regression**: Slope calculation now properly mean-centered
  - **Change**: Uses mean-centered Y values (`yMean`) instead of anchoring to last price
  - **Formula**: `slope = sum((x - xMean) * (y - yMean)) / sum((x - xMean)²)`
  - **Benefit**: Mathematically correct trend estimation independent of ending price level
  - **Impact**: More reliable slope for market context in pattern metadata

### Code Quality
- All changes lint-compliant and pass TypeScript strict mode
- Builds successfully with no errors
- Backward-compatible API (no breaking changes)

## Recent Improvements (v3)

### New Indicators Added

#### VWAP (Volume Weighted Average Price)
- **Purpose**: Identifies fair value based on volume-weighted price distribution
- **Signals**: Uses ±1σ and ±2σ bands from VWAP
- **Benefit**: Institutional-grade price level analysis for better entry/exit points
- **Formula**: VWAP = Σ(Typical Price × Volume) / Σ(Volume)

#### ADX (Average Directional Index)
- **Purpose**: Measures trend strength regardless of direction
- **Signals**: ADX > 25 with +DI/-DI crossovers for directional trades
- **Benefit**: Filters out range-bound markets, focuses on trending opportunities
- **Implementation**: Full Wilder's smoothing with +DI, -DI, and DX calculation

#### Williams %R
- **Purpose**: Momentum oscillator with overbought/oversold detection
- **Signals**: %R ≤ -80 (oversold buy), %R ≥ -20 (overbought sell)
- **Benefit**: Faster reversal signals with momentum confirmation
- **Enhancement**: Detects rising/falling momentum from extreme zones

### Enhanced RSI with Divergence Detection
- **Change**: RSI now detects bullish and bearish divergences
- **Bullish Divergence**: RSI rising while price falling (early buy signal)
- **Bearish Divergence**: RSI falling while price rising (early sell signal)
- **Impact**: Earlier reversal detection before price confirms the move
- **Threshold**: Price trend >1%, RSI trend >3 points in opposite directions

### Signal Strength Scoring System
- **New Feature**: 0-100 score quantifying indicator alignment
- **Formula**: `((buyCount - sellCount + total) / (2 × total)) × 100`
- **Use Cases**:
  - Filter trades by minimum strength threshold
  - Gauge confidence in setups
  - Track signal quality over time
- **Output**: Added `signalStrength` field to `MultiIndicatorResult`

### System Expansion
- **Indicators**: Expanded from 12 to 15 indicators (added Ichimoku Cloud, CCI, Parabolic SAR)
- **Interface**: Updated `MultiIndicatorResult` with new indicator fields
- **Logging**: Enhanced logging includes all 15 indicator signals
- **Backward Compatibility**: API remains compatible, existing integrations work unchanged

### Code Quality
- All new functions include comprehensive JSDoc documentation
- Proper null handling and edge-case guards
- Consistent metadata output format across all indicators
- TypeScript strict mode compliant

## Custom Indicators

The system now supports **Custom Indicators**, allowing users to extend the analysis capabilities beyond the core 12 indicators.

- **Definition:** Users can define custom logic using available market data (price, volume, etc.).
- **Integration:** Custom indicators are evaluated alongside standard indicators and contribute to the overall signal generation.
- **Weighting:** Custom indicators can be assigned weights to influence the Signal Strength score.
- **Flexibility:** Enables the implementation of proprietary or niche trading strategies.

## Support

For questions or issues:
1. Check Firebase Functions logs
2. Review Firestore documents
3. Test individual indicators manually
4. Consult the codebase:
   - `functions/src/technical-indicators.ts`
   - `functions/src/alpha-agent.ts`
   - `functions/src/agentic-trading.ts`
