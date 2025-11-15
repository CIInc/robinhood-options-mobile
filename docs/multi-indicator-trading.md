# Multi-Indicator Automatic Trading System

## Overview

The multi-indicator automatic trading system correlates 4 technical indicators to generate trade signals. **All 4 indicators must be "green" (BUY signal) to trigger an automatic trade.**

This system replaces the previous simple SMA crossover strategy with a more robust multi-factor analysis approach.

## The 4 Technical Indicators

### 1. Price Movement (Chart Patterns)

**Purpose:** Identifies bullish or bearish chart patterns based on price action.

**Implementation:** `detectChartPattern()` in `technical-indicators.ts`

**Signals:**
- **BUY**: Bullish patterns detected (breakout above moving averages, cup & handle formation)
- **SELL**: Bearish patterns detected (breakdown below moving averages)
- **HOLD**: No clear pattern

**Technical Details:**
- Uses 5, 10, and 20-period simple moving averages
- Detects breakouts when price moves 2% above the 20-period MA
- Identifies cup & handle pattern when price recovers 5% from recent lows
- Analyzes the last 20 price periods

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

## How It Works

### Signal Generation Flow

1. **Data Collection**
   - Fetch historical prices and volumes for the target symbol
   - Fetch market index (SPY/QQQ) data
   - Minimum 30-60 periods of data required

2. **Indicator Evaluation**
   - Each indicator is evaluated independently
   - Each returns: `{ signal: "BUY"|"SELL"|"HOLD", reason: string, value: number }`

3. **Multi-Indicator Correlation**
   - Function: `evaluateAllIndicators()` in `technical-indicators.ts`
   - Checks if ALL 4 indicators signal BUY
   - Returns `allGreen: true` only when all 4 are BUY

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
agentic-trading.ts (getMarketData)
         ↓
alpha-agent.ts (handleAlphaTask)
         ↓
technical-indicators.ts (evaluateAllIndicators)
         ↓
    ┌────┴────┬────────┬───────────┐
    ↓         ↓        ↓           ↓
  Price   Momentum  Market     Volume
Movement    (RSI)  Direction
    ↓         ↓        ↓           ↓
    └────┬────┴────────┴───────────┘
         ↓
   All 4 Green?
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

## Monitoring Trade Signals

### Firebase Firestore

Trade signals are stored in: `agentic_trading/signals_{SYMBOL}`

Document structure:
```json
{
  "timestamp": 1234567890000,
  "signal": "BUY" | "SELL" | "HOLD",
  "reason": "All 4 indicators are GREEN - Strong BUY signal",
  "multiIndicatorResult": {
    "allGreen": true,
    "overallSignal": "BUY",
    "indicators": {
      "priceMovement": {
        "signal": "BUY",
        "reason": "Bullish pattern detected: Breakout...",
        "value": 1,
        "metadata": { ... }
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

### Mobile App UI

The Agentic Trading Settings screen displays:
- Current configuration values
- Latest trade proposal (if any)
- Multi-indicator breakdown with visual status:
  - ✓ Green arrow up = BUY signal
  - ✓ Red arrow down = SELL signal
  - ✓ Gray horizontal line = HOLD signal
- Overall signal status with highlighting when all 4 are green

## Automated Execution (Cron Job)

File: `functions/src/agentic-trading-cron.ts`

**Schedule:** Every weekday at 4:00 PM (after market close)

**Process:**
1. Scans all documents in `agentic_trading` collection
2. For each `chart_{SYMBOL}` document:
   - Loads configuration
   - Calls `performTradeProposal()` with symbol
   - Multi-indicator evaluation runs
   - Trade executed if all indicators are green and risk check passes
3. Results stored in Firestore

**Monitoring:**
- Check Firebase Functions logs
- View `agentic_trading/signals_{SYMBOL}` documents
- Review trade proposals in mobile app

## Testing

### Manual Testing via Mobile App

1. Navigate to Agentic Trading Settings
2. Enable "Enable Agentic Trading"
3. Configure parameters (optional)
4. Tap "Initiate Test Trade Proposal"
5. Review indicator status display
6. Check if all 4 indicators are green

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
- **Expected Result:** All 4 indicators BUY → Trade executed

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
- **Expected Result:** All 4 indicators SELL → Potential short (if enabled)

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
- Signal frequency (how often all 4 align)
- False positive rate
- Trade win/loss ratio
- Indicator individual performance

## Troubleshooting

### No Trades Being Generated

**Check:**
1. Is agentic trading enabled in settings?
2. Are all 4 indicators rarely aligning?
3. Review Firestore `signals_{SYMBOL}` for indicator status
4. Check Firebase Functions logs for errors
5. Verify market data is being fetched (Yahoo Finance API working)

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
   - MACD (Moving Average Convergence Divergence)
   - Bollinger Bands
   - Stochastic Oscillator
   - ADX (Average Directional Index)

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
