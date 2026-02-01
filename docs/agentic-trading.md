# Agentic Trading Documentation

## Overview

The Agentic Trading system provides autonomous, AI-powered trading capabilities for RealizeAlpha. It combines multi-indicator technical analysis with risk management controls to execute trades automatically based on qualified trading signals.

**Auto-Execution:** The system includes a built-in timer that automatically checks for trading opportunities every 5 minutes when auto-trading is enabled. No manual intervention is required - simply enable auto-trading in settings and the system will monitor and execute trades autonomously.

## Architecture

### Components

1. **AgenticTradingConfig** (`lib/model/agentic_trading_config.dart`)
   - User configuration model
   - Stores all trading parameters and risk controls
   - Persisted in Firestore User documents

2. **AgenticTradingProvider** (`lib/model/agentic_trading_provider.dart`)
   - Core state management and trading execution logic
   - Implements `ChangeNotifier` for reactive UI updates
   - Manages trade execution, TP/SL monitoring, and safety checks
   - Handles automated buy trades tracking and Firebase persistence
   - Loads auto-trade history from Firestore ensuring persistence across app restarts

3. **TradeSignalsProvider** (`lib/model/trade_signals_provider.dart`) *[NEW]*
   - Centralized trade signal management
   - Fetches signals from Firestore with real-time listeners
   - Provides indicator documentation for all 19 indicators (Price Movement, RSI, Market Direction, Volume, MACD, Bollinger Bands, Stochastic, ATR, OBV, VWAP, ADX, Williams %R, Ichimoku Cloud, CCI, Parabolic SAR, ROC, Chaikin Money Flow, Fibonacci Retracements, Pivot Points)
   - Used across InstrumentWidget, SearchWidget for consistent signal display
   - Separates signal management from execution logic

4. **MarketHours Utility** (`lib/utils/market_hours.dart`) *[NEW]*
   - Reusable DST-aware market hours checking
   - Handles Eastern Time conversion (EDT/EST)
   - Comprehensive debug logging for troubleshooting
   - Used by providers and widgets for consistent market status

5. **AgenticTradingSettingsWidget** (`lib/widgets/agentic_trading_settings_widget.dart`)
   - User interface for configuration
   - Real-time status monitoring with countdown timer, market analysis status, and emergency stop indicators
   - Auto-save functionality (no manual save button)
   - **Manual Execution:** Use the "Run Now" button to immediately trigger a market analysis and trade execution cycle.
   - **Emergency Stop:** Use the "Emergency Stop" button to immediately stop all automated trading activities. You can also **long-press the auto-trade status badge** in the app bar to quickly toggle the emergency stop.
   - Integration with both AgenticTradingProvider and TradeSignalsProvider
   - **Paper Trading:** Expanded paper trading functionality allows validatation of strategies across various widgets without risking real capital. Supports TP/SL monitoring in paper mode.

6. **Backend Functions** (`functions/src/`)
   - `riskguardTask`: Advanced risk assessment and validation engine (powers both Agentic and [Manual Trading](risk-guard.md) protection)
   - `RiskGuardAgent`: Implements sector limits, correlation checks, and volatility filters
   - `MacroAssessment`: Integrates broader market conditions into trading logic for enhanced decision making
   - Trade signal generation cron jobs (daily, hourly, 15-min)
   - `seedAgenticTrading` function: Initializes monitored stocks (supports batch processing)
   - `stock-list.ts`: Source of S&P 500 symbols

7. **TradeSignalsWidget** (`lib/widgets/trade_signals_widget.dart`) *[NEW]*
   - Dedicated home screen widget for trade signals
   - Provides a streamlined view of active auto-trading signals
   - Supports filtering by signal source (Strategy vs. Indicator)
   - Direct navigation to instrument details

8. **Search & Discovery Widgets** (`lib/widgets/search_widget.dart`, `screener_widget.dart`, `presets_widget.dart`) *[NEW]*
   - **SearchWidget**: Main entry point for trade signal discovery. Features advanced filtering for signal strength and individual indicators.
   - **ScreenerWidget**: Dedicated stock screener interface for fundamental analysis (Market Cap, P/E, Dividend, etc.).
   - **PresetsWidget**: Quick access to pre-defined Yahoo Finance screeners (e.g., "Undervalued Growth", "Day Gainers").

## Stock Universe & Seeding

The system monitoring is driven by a seeded list of documents in the `agentic_trading` collection.

### Seeding the Database
To initialize or expand the list of monitored stocks, use the `seedAgenticTrading` Firebase Cloud Function.

**Usage:**
Call the function with a JSON body to seed the `agentic_trading` collection.

**Options:**
- **Default (Popular Only):**
  ```json
  {}
  ```
  Seeds only the default popular symbols (Indices + High Volume: SPY, QQQ, NVDA, TSLA, AAPL, etc.).

- **Full S&P 500:**
  ```json
  {
    "full": true
  }
  ```
  Seeds the full S&P 500 list plus popular symbols (approx. 500+ stocks).
  *Note: The function processes writes in batches of 50 to respect Firestore limits.*

- **Custom List:**
  ```json
  {
    "symbols": ["AAPL", "MSFT", "GOOGL"]
  }
  ```
  Seeds only the specified symbols.

## Features

### Trade Signals Widget

The dedicated **Trade Signals Widget** offers a focused view of all active trading signals generated by the system.

- **Unified View**: See all BUY/SELL signals in one place.
- **Source Filtering**: Toggle between signals generated by **Strategies** or individual **Indicators**.
- **Real-Time Updates**: Signals update automatically as market conditions change.
- **Quick Navigation**: Tap any signal to jump to the instrument details for in-depth analysis.

### Trade Signal Discovery

The Search tab provides powerful tools to discover and filter trade signals generated by the Agentic Trading system.

**Filtering Capabilities:**
- **Signal Strength Filtering:** Filter signals by overall strength category:
  - **Strong (75-100):** High-confidence setups with multiple confirming indicators.
  - **Moderate (50-74):** Good setups with solid support but fewer confirmations.
  - **Weak (0-49):** Low-confidence or conflicting signals (often used for contrarian analysis).
- **Strategy Template Filtering:** Filter signals to only show those that align with specific pre-defined strategies (e.g., "Momentum Master", "Mean Reversion").
  - This allows you to focus on signals that match your preferred trading style.
- **Indicator-Specific Filtering:** Granular control over all 15 indicators. Each indicator chip supports a 4-way toggle:
  - **Off:** No filter applied.
  - **BUY:** Show only signals where this indicator is bullish.
  - **SELL:** Show only signals where this indicator is bearish.
  - **HOLD:** Show only signals where this indicator is neutral.

**Exclusive Filtering Logic:**
To prevent conflicting queries, the system enforces exclusivity between high-level strength filters and granular indicator filters:
- Selecting a **Signal Strength** category (e.g., "Strong") automatically clears any active indicator filters.
- Activating an **Indicator Filter** (e.g., "RSI: BUY") automatically clears the Signal Strength selection.

**Performance Optimization:**
- **Server-Side Filtering:** All filtering logic (strength ranges, indicator states, date ranges) is executed on Firestore to minimize data transfer and client-side processing.
- **Efficient Indexing:** Custom composite indexes support complex queries like "Show me all signals where RSI is BUY and MACD is BUY, sorted by time."

### Signal Processing & Deduplication

To ensure reliability and prevent duplicate trades, the system implements robust signal processing logic:

- **Local Persistence:** The IDs of processed signals are saved locally to the device. This ensures that even if the app is restarted, the system remembers which signals have already been acted upon (or rejected) for the current day.
- **Server-Side Safety:** When the auto-trading system checks for signals, it uses a special flag (`skipSignalUpdate`) to prevent the server from updating the timestamp of existing signals. This ensures that the "freshness" of a signal is preserved based on its original generation time, not the time it was last checked.
- **Detailed Inspection:** You can view the history of processed signals in the **Agentic Trading Settings**. Tapping on any processed signal reveals a detailed dialog showing:
  - The full AI reasoning for the decision.
  - Specific rejection reasons (if applicable).
  - Timestamp of processing.

### Paper Trading Mode

The system includes a fully functional **Paper Trading Mode** for risk-free strategy testing and validation.

**Key Features:**
- **Risk-Free Simulation:** Execute trades without using real capital or making broker API calls.
- **Realistic Execution:** Simulates realistic order responses, including fills and status updates.
- **Identical Analytics:** Paper trades are tracked with the same precision as real trades, allowing for direct performance comparison.
- **Visual Indicators:** "PAPER" badges appear on trade cards and in analytics to clearly distinguish simulated trades.
- **Separate Tracking:** Paper trades are stored with a `paperMode: true` flag, allowing them to be filtered separately in the analytics dashboard.
- **Strategy Validation:** Perfect for testing new indicator combinations or risk parameters before going live.

**How to Enable:**
1. Go to **Agentic Trading Settings**.
2. Toggle **Paper Trading Mode** to ON.
3. Configure your trading parameters as usual.
4. Enable **Auto-Trade**.

*Note: When Paper Trading is enabled, NO real orders will be sent to your brokerage.*

### Trading Strategy Management

> **New in v0.28.1**

The system now offers centralized management for trading strategies, allowing users to switch between different trading styles and risk profiles instantly.

**Strategies Page:**
- **Access:** Navigate to the new "Trading Strategies" page from the Agentic Trading Settings.
- **Library:** Browse a collection of pre-defined strategies (e.g., "Momentum Master", "Mean Reversion", "Conservative Income").
- **Search:** Quickly find strategies by name or description.
- **Activation:** Tap "Use Template" to instantly apply the strategy's configuration (indicators, intervals, risk settings) to your active trading agent.

**Entry Strategies:**
- **Visual Configuration:** New dedicated UI for configuring entry conditions.
- **Pattern Recognition:** Toggle specific chart patterns and entry triggers directly.
- **Integration:** Seamlessly integrated with the main configuration flow.

**Default Strategies:**
The system comes with a library of professionally designed templates to get you started:

1.  **Momentum Master** (Trend): Captures strong price moves by combining RSI and CCI momentum with MACD confirmation and Volume validation.
2.  **Mean Reversion** (Reversal): Identifies overbought/oversold reversals using Bollinger Bands, CCI, and RSI extremes.
3.  **Trend Follower** (Swing): Rides established trends using Moving Averages, Ichimoku Cloud, ADX trend strength, and OBV flow.
4.  **Volatility Breakout (1h)** (Intraday): Exploits explosive moves from squeeze conditions using Bollinger Bands, CCI, ATR, and VWAP.
5.  **Intraday Scalper (15m)** (Scalping): Short-term scalping via CCI/Stochastic with strict risk management (partial exits, tight stops).
6.  **Custom EMA Trend** (Custom): Automatically engages when Price crosses above the 21-period EMA.
7.  **Crypto Proxy Momentum** (Crypto): High-volatility momentum strategy (CCI, RSI) designed for crypto-correlated stocks.
8.  **Golden Cross & RSI Filter** (Classic): Classic 50/200 SMA Cross combined with RSI < 70 to avoid buying tops.
9.  **Range Bound Income** (Income): Ideal for sideways markets. Profitable when Price Movement and CCI Impulse are low.
10. **Strict Confluence** (Conservative): High conviction entries requiring ALL enabled indicators (Momentum, Moving Avg, MACD) to agree.
11. **Risk-Managed Growth** (Position Sizing): Uses dynamic position sizing to risk exactly 1% of account equity per trade.
12. **MACD Histogram Reversal** (Reversal): Trades when MACD histogram flips positive while RSI is oversold (< 40).
13. **Bollinger Band Squeeze** (Breakout): Breakout strategy. Low volatility period (ATR) followed by price piercing Upper Band.
14. **VWAP Pullback Entry** (Intraday): Intraday trend is UP (Price > SMA), but entry is a pullback to VWAP.
15. **0DTE Scalper (5m)** (High Frequency): SPY 5m chart, riding rapid momentum (CCI/RSI) bursts with tight risk.
16. **Tech Sector Swing** (Sector): Trend following on XLK (Tech Sector). Captures multi-day moves.
17. **Defensive Value** (Low Beta): Low-beta strategy on SCHD. Buys dips (RSI < 30) in uptrends with CCI oversold confirmation.
18. **Ichimoku Cloud Breakout** (Trend): Trend-following strategy utilizing the Ichimoku Cloud for support/resistance.
19. **Triple Screen Simulation** (System): Simulates Elder's Triple Screen: Trend (MACD/SMA) + Oscillator (Stochastic/Williams) + Breakout.
20. **Opening Range Breakout** (Morning): Exploits early market volatility (9:30-10:30 AM). Uses VWAP as anchor.
21. **Turtle Trend Follower** (Long Term): Long-term breakout strategy inspired by Turtle Traders. Buys new highs.
22. **RSI Fade** (Contrarian): Fades overextended moves. Sells when RSI > 75 and price hits upper Bollinger Band.

### Automatic Execution

The system automatically executes trades when auto-trading is enabled:

**Timer-Based Execution:**
- Periodic checks every 5 minutes
- Automatically starts when app loads with user data
- Runs continuously while app is active
- Checks `autoTradeEnabled` configuration flag
- Only executes during market hours (validated via MarketHours utility)
- Real-time countdown timer displayed in settings UI

**Execution Cycle:**
1. Timer triggers every 5 minutes
2. Checks if auto-trading is enabled in config
3. Validates market hours using MarketHours.isMarketOpen()
4. Validates required data (user, account, portfolio)
5. Builds current portfolio state
6. Calls `autoTrade()` with all parameters
7. Calls `monitorTakeProfitStopLoss()` for automated trades
8. Updates countdown timer for next cycle
9. Logs execution results

**Location:** `AgenticTradingProvider` (`lib/model/agentic_trading_provider.dart`) - Centralized provider managing trading state and execution logic.

**UI Integration:**
- Settings widget shows real-time countdown to next check
- App bar displays auto-trade status badge when active
- Status updates propagate via ChangeNotifier pattern

### Auto-Trade Logic

The `autoTrade()` method orchestrates automatic trade execution:

```dart
Future<Map<String, dynamic>> autoTrade({
  required Map<String, dynamic> portfolioState,
}) async
```

**Process Flow:**
1. **Pre-flight Checks** (`_canAutoTrade()`)
   - Verify auto-trade is enabled
   - Check emergency stop status
   - Validate market hours
   - Enforce daily trade limit
   - Verify cooldown period has elapsed
   - Check daily loss limit

2. **Signal Processing**
   - Fetch current trade signals from Firestore
   - Filter for BUY signals
   - Validate signal quality

3. **Trade Execution**
   - Call `initiateTradeProposal()` for each qualified signal
   - Assess risk with `riskguardTask`
   - Track execution history
   - Update counters and timestamps

4. **Post-Trade Actions**
   - Log analytics events
   - Update UI state
   - Enforce rate limiting between trades
   - **Record enabledIndicators snapshot for performance analysis**
   - **Mark trade as real or paper mode**

### Advanced Risk Controls

The system now includes a sophisticated `RiskGuardAgent` that enforces portfolio-level risk management rules before any trade is executed. These controls are configurable in the Agentic Trading Settings.

**Partial Position Exits:**
- **Staged Profit Taking:** Configure multiple exit stages to lock in profits incrementally.
- **Flexible Configuration:** Define profit targets (e.g., +5%, +10%) and the percentage of the position to sell at each stage (e.g., 50%).
- **Example Strategy:** Sell 50% of position at +5% profit, then sell the remaining 50% at +10% profit.
- **Persistence:** Partial exit state is saved to Firestore, ensuring stages are tracked correctly even if the app is restarted.
- **Legacy Support:** Works seamlessly with existing positions (backfills tracking data).

**Stop Loss & Take Profit:**
- **Stop Loss:** Automatically sells position if loss exceeds configured percentage (e.g., -5%).
- **Take Profit:** Automatically sells position if profit exceeds configured percentage (e.g., +10%).
- **Trailing Stop Loss:** Optional dynamic stop loss that follows the price up. If enabled, the stop price is calculated as `Highest Price - Trailing %`. Locks in profits as the stock rises.

**Advanced Risk Controls:**
- **Sector Exposure Limits:** Cap allocation to specific sectors (e.g., max 20% in Technology).
- **Correlation Checks:** Prevent opening new positions that are highly correlated with existing holdings (max correlation coefficient 0.7).
- **Volatility Filters:** Filter trades based on Implied Volatility (IV) rank (min/max thresholds).
- **Drawdown Protection:** Halt trading if portfolio drawdown exceeds a specified percentage.

**Safety Checks:**
- **Daily Trade Limit:** Maximum number of automated trades per day.
- **Cooldown Period:** Minimum time between trades (default 60 mins).
- **Max Daily Loss:** Stops trading if daily loss exceeds threshold.
- **Emergency Stop:** Manual override to immediately halt all auto-trading.
- **Market Hours:** Only trades during regular market hours (9:30 AM - 4:00 PM ET).

**Key Risk Features:**
- **Sector Exposure Limits:** Prevents over-concentration in a single sector.
  - Configurable `maxSectorExposure` (default 20%).
  - Checks current portfolio allocation before approving new trades.
- **Correlation Checks:** Avoids adding positions that are highly correlated with existing holdings.
  - Configurable `maxCorrelation` coefficient (default 0.7).
  - Helps maintain portfolio diversification.
- **Volatility Filters:** Ensures trades are only taken within acceptable volatility ranges.
  - Configurable `minVolatility` and `maxVolatility` (IV Rank).
  - Prevents trading in extremely low or high volatility environments.
- **Drawdown Protection:** Halts trading if the portfolio experiences significant drawdown.
  - Configurable `maxDrawdown` percentage.
  - Acts as a circuit breaker for the entire trading system.

### Custom Indicators

Users can now define their own technical indicators to be used alongside the standard 15-indicator system.

- **Creation:** Define custom logic based on price action, volume, or other available data points.
- **Integration:** Custom indicators are evaluated as part of the signal generation process.
- **Weighting:** Assign specific weights to custom indicators to influence the overall signal strength.
- **Flexibility:** Supports a wide range of mathematical functions and logic operators.

### ML Optimization

Machine Learning models are integrated to continuously optimize trade signals, leveraging Google's **Vertex AI Gemini 1.5 Flash** model for high-speed, cost-effective analysis.

- **Signal Refinement:** ML algorithms analyze historical performance to adjust indicator weights and thresholds.
- **Accuracy Improvement:** Reduces false positives by learning from past market conditions.
- **Adaptive Logic:** The system adapts to changing market volatility and trends.
- **Continuous Learning:** The models are retrained periodically with new market data to ensure relevance.
- **Cost Efficiency:**
  - **Signal Gating:** Intelligent filtering only invokes AI optimization for high-potential setups (Signal Strength > 25), significantly reducing API costs by skipping analysis of weak signals.
  - **Optimized Prompts:** Utilizes minified and structured prompts to minimize token usage while maintaining analytical depth.
  - **Model Selection:** Uses the `gemini-1.5-flash-001` model, which offers a 10x cost reduction compared to Pro models without compromising on structured analysis capabilities.

### Advanced Exit Strategies

In addition to standard Stop Loss and Take Profit, the system supports sophisticated exit strategies:

- **Partial Exits:** Configure multiple exit targets (e.g., sell 50% at +10% profit, sell remaining 50% at +20%). This allows locking in profits while keeping a portion of the position open for potential further gains.
- **Time-Based Exits:** Automatically close positions after a specified duration (e.g., 2 hours) if profit targets haven't been met. This helps free up capital from stagnant trades.
- **Market Close Exits:** Automatically liquidate positions a set number of minutes before the market closes to avoid overnight risk (gap risk).

### Order Approval Workflow

For users who want the benefits of AI signal generation but prefer manual control over execution, the system offers an **Order Approval Workflow**.

**How it works:**
1. **Enable Approval:** Toggle `requireApproval` in Agentic Trading Settings.
2. **Signal Generation:** The system generates trade proposals as usual based on signals and risk checks.
3. **Pending State:** Instead of executing immediately, orders are placed in a "Pending Approval" queue.
4. **Notification:** The user receives a notification about the pending order.
5. **Review & Action:**
   - Users can review pending orders in the Agentic Trading Settings.
   - **Approve:** The order is sent to the brokerage for execution.
   - **Reject:** The order is discarded.
   - **Timeout:** Pending orders may expire if not acted upon within a certain timeframe (configurable).

### Advanced Performance Analytics

The `AgenticTradingPerformanceWidget` provides comprehensive trading insights across 9 analytics cards:

**1. Performance Overview**
- Total trades executed
- Win/loss counts and success rate
- Average P&L per trade
- Total P&L summary

**2. Profit & Loss**
- Total P&L amount
- Average P&L per trade
- Winning trades total
- Losing trades total
- Breakdown by entry/exit type

**3. Trade Breakdown**
- Entry counts (BUY orders)
- Take Profit exits
- Stop Loss exits
- **Trailing Stop exits**
- Distribution visualization

**4. Best & Worst Trades**
- Best performing trade details
- Worst performing trade details
- P&L amounts
- Entry/exit prices
- Hold duration

**5. Advanced Analytics (4-Metric Grid)**
- **Sharpe Ratio**: Risk-adjusted returns (Good >1, Fair 0-1, Poor <0)
  - Calculates annualized return / volatility
  - Indicates quality of returns per unit of risk
- **Average Hold Time**: Position duration in hours and minutes
  - Tracks from BUY to SELL
  - Helps optimize exit timing strategies
- **Profit Factor**: Gross profit / Gross loss ratio
  - Values > 1 indicate profitable system
  - Higher values show better profitability
- **Expectancy**: Expected profit per trade (in dollars)
  - Formula: (Avg Win × Win Rate) - (Avg Loss × Loss Rate)
  - Critical metric for strategy validation

**6. Risk Metrics**
- **Longest Win Streak**: Best consecutive winning trades
- **Longest Loss Streak**: Worst consecutive losing trades  
- **Max Drawdown**: Peak-to-trough equity decline
  - Helps assess portfolio risk
  - Important for risk management

**7. Performance by Time of Day**
- Morning (9am-12pm): Win rates, trade counts, avg P&L
- Afternoon (12pm-3pm): Win rates, trade counts, avg P&L
- Late Day (3pm-4pm): Win rates, trade counts, avg P&L
- **Color-coded**: Green (≥60%), Orange (40-59%), Red (<40%)
- Helps identify optimal trading windows

**8. Performance by Indicator Combo** *(v1.3)*
- Tracks active indicators at execution time
- Groups trades by unique indicator combination
- Win/loss rate for each combination
- Shows which indicator sets are most effective
- Top 8 combinations displayed
- Abbreviated names: Price, RSI, Market, Volume, MACD, BB, Stoch, ATR, OBV
- Enables strategy optimization

**9. Performance by Symbol**
- Top 10 traded symbols
- Win rate per symbol
- Trade counts
- Total P&L by symbol
- Average hold time
- Identifies best and worst performing stocks

**Paper vs Real Performance Tracking** *(v1.3)*
- **Filter chips**: All Trades / Paper Mode / Real Trades
- **Paper trades**: Simulated execution without broker API calls
- **Real trades**: Actual executed orders
- **Same analytics**: Both modes calculated identically
- **Comparison**: Validate strategies in paper mode before going live
- **Visual indicators**: PAPER badges on paper mode trades

**Key Metrics Explained:**

*Sharpe Ratio*
- Measures return vs volatility
- Higher = better risk-adjusted returns
- Used to compare different strategies fairly
- Good >1, Fair 0-1, Poor <0

*Profit Factor*
- Simple profitability measure
- PF > 1 = profitable
- PF > 2 = excellent (2:1 or better win/loss)
- PF < 1 = money losing strategy

*Expectancy*
- Average profit per trade
- Positive expectancy = strategy is profitable
- Crucial for validating trading system
- (Winning trades × Win rate) - (Losing trades × Loss rate)

*Max Drawdown*
- Largest peak-to-trough decline
- Important risk metric
- Helps set stop-loss levels
- Shows portfolio volatility

The `monitorTakeProfitStopLoss()` method automatically exits positions when targets are met:

```dart
Future<Map<String, dynamic>> monitorTakeProfitStopLoss({
  required List<dynamic> positions,
  required brokerageUser,
  required account,
  required brokerageService,
  required instrumentStore,
}) async
```

**Monitoring Flow:**
1. **Position Filtering**
   - Check only positions created by automated trading
   - Positions tracked in `_automatedBuyTrades` list
   - Manual trades and pre-existing positions are NOT monitored

2. **Position Analysis**
   - Iterate through automated trade records
   - Extract entry price and current price
   - Calculate profit/loss percentage using trade record's entry price
   - **Update highestPrice for trailing stop tracking**

3. **Threshold Checks**
   - If P/L >= `takeProfitPercent`: Trigger Take Profit exit
   - If P/L <= -`stopLossPercent`: Trigger Stop Loss exit
   - **If Trailing Stop enabled: Check if price dropped below (highestPrice - trailingStopPercent)**

4. **Order Execution**
   - **Check `paperTradingMode`: Simulate or execute real order**
   - Fetch instrument data for the symbol
   - Place SELL order through brokerage service (or simulate in paper mode)
   - Validate order response (200/201 status)
   - Remove trade record from `_automatedBuyTrades`
   - Track exit in history with reason and P/L%

5. **Analytics & Logging**
   - Log exit execution events
   - Track failures separately
   - Update trade history with paper/real indicator
   - Record exit reason (Take Profit/Stop Loss/Trailing Stop)

6. **Persistence**
   - **Save updated trades list to Firebase after exits**
   - Ensures accuracy across sessions

**Integration:**
- Runs every 5 minutes as part of auto-trade timer
- Executes after checking for new trade entry signals
- Only monitors positions opened by automated trading
- Manual trades remain under user control
- Positions opened before auto-trading was enabled are not affected

**Trade-Level Tracking:**
- When automated BUY order executes: Trade record added to `_automatedBuyTrades`
- Record contains: `{symbol, quantity, entryPrice, timestamp, enabledIndicators, paperMode, highestPrice}`
- When TP/SL/Trailing Stop exit executes: Specific trade record removed
- Manual trades: Never added to tracking, never monitored for TP/SL
- **Stored in Firebase**: `users/{userId}/automated_buy_trades` subcollection
- **Persists across**: App restarts and device changes

**Trailing Stop Loss:**
- **Activated when**: `trailingStopEnabled = true` and `trailingStopPercent` configured
- **Tracks**: `highestPrice` for each automated trade
- **Exits when**: Current price drops more than `trailingStopPercent` below peak
- **Benefit**: Locks in gains while allowing further upside
- **Example**: Entry $100, peak $120, trailing stop 5% → Exit trigger at $114

**Paper Trading Simulation:**
- **`paperTradingMode = true`**: Calls `_simulatePaperOrder()` instead of broker API
- **Creates realistic response**: With all expected fields (id, status, executions)
- **Tracks identically**: Same P/L, analytics, exit reasons
- **Persists to Firebase**: Marked with `paperMode: true` flag
- **Filtered in analytics**: Paper vs real trade comparison available

**Example - Automated Position:**
```
Auto-trade buys: 10 AAPL at $150 → Trade record created
Record: {symbol: 'AAPL', quantity: 10, entryPrice: 150.00, timestamp: '...', enabledIndicators: ['momentum', 'macd'], paperMode: false, highestPrice: 150.00}
Current price: $165 → highestPrice updated to 165.00
P/L = ((165 - 150) / 150) * 100 = 10%

Scenario 1 - Take Profit:
If takeProfitPercent = 10%: Trigger SELL 10 shares
After exit: Trade record removed, analytics updated

Scenario 2 - Trailing Stop:
If trailingStopEnabled = true, trailingStopPercent = 3%
Price rises to $170 (highestPrice = 170.00)
Price drops to $165 (drop = 2.9%, below 3% threshold)
No exit yet

Price drops to $164.80 (drop = 3.05%, exceeds 3% threshold)
Trigger SELL 10 shares at $164.80
Locked in profit from $150 to $164.80
```
````

**Example - Manual + Automated Same Symbol:**
```
User owns: 100 AAPL at $140 (manual, not tracked)
Auto-trade buys: 10 AAPL at $150 (tracked separately)
Current price: $165

For automated trade:
P/L = ((165 - 150) / 150) * 100 = 10%
Action: SELL 10 shares (from automated trade)
Result: Manual 100 shares @ $140 remain untouched
```

**Example - Multiple Automated Trades:**
```
Auto-trade 1: Buy 10 AAPL @ $150 (tracked)
Auto-trade 2: Buy 5 AAPL @ $160 (tracked separately)
Current price: $165

Trade 1 P/L: ((165-150)/150)*100 = 10% → Triggers TP, SELL 10 shares
Trade 2 P/L: ((165-160)/160)*100 = 3.1% → No trigger
Result: Two separate entries, tracked and managed independently
```

### Firebase Persistence

**Automated Buy Trades Storage:**
- **Collection Path**: `users/{userId}/automated_buy_trades`
- **Document Structure**: Each trade as a separate document
- **Fields**: 
  - `symbol`: Stock symbol (string)
  - `quantity`: Number of shares (int)
  - `entryPrice`: Entry price per share (double)
  - `timestamp`: Execution time (ISO string)
  - `enabledIndicators`: Active indicators at trade time (List<String>) *(v1.3)*
  - `paperMode`: Whether trade was simulated (bool) *(v1.3)*
  - `highestPrice`: Peak price for trailing stop tracking (double) *(v1.3)*
- **Security Rules**: Updated firestore.rules to allow read/write for authenticated users

**Automatic Saving:**
- Trades saved immediately after BUY order execution
- Trades removed immediately after TP/SL/Trailing Stop exit
- Ensures data integrity across app restarts
- Field validation on load for data integrity
- **Paper trades**: Persisted identically to real trades (marked with `paperMode: true`)

**Loading:**
- Trades loaded on user login (via `loadAutomatedBuyTradesFromFirestore`)
- Automatic sync across devices
- Enables continuous TP/SL monitoring across sessions
- Try-catch error handling for robustness
- Validates all required fields when loading

**Benefits:**
- **Persistence**: Survives app crashes and restarts
- **Cross-Device**: User logs in on different device, trades sync
- **Reliability**: Firebase ensures data availability
- **History**: Complete audit trail of automated trades
- **Security**: Firestore rules protect user data
- **Analytics**: enabledIndicators enable performance analysis by indicator combination
- **Paper Tracking**: Separates paper and real trades for comparison

**Example Workflow:**
```
Session 1:
- User enables auto-trading in Paper Mode
- Auto-trade buys 3 positions
- Trades saved to Firebase with paperMode: true and enabledIndicators snapshot

App restart:
- User logs in
- Trades loaded from Firebase automatically
- TP/SL monitoring resumes seamlessly
- Analytics filters show Paper trades separately

Switch to Real Mode:
- User disables Paper Mode
- Next trades execute with paperMode: false
- Analytics now show both paper and real performance
- Can compare strategy effectiveness

Device switch:
- User logs in on new device (tablet)
- All trades sync from Firebase
- Full functionality restored instantly
- Analytics updated with latest metrics
```

**Trade Record Example:**
```json
{
  "symbol": "AAPL",
  "quantity": 10,
  "entryPrice": 150.25,
  "timestamp": "2025-12-13T14:30:45.123Z",
  "enabledIndicators": ["momentum", "macd", "volume"],
  "paperMode": false,
  "highestPrice": 155.50
}
```

### Provider Architecture

**Separation of Concerns:**

The recent refactoring (commit 861f2bc) introduced a cleaner architecture with separated responsibilities:

1. **TradeSignalsProvider**:
   - **Purpose**: Centralized signal management
   - **Responsibilities**:
     - Fetch trade signals from Firestore
     - Real-time signal listeners
     - Provide indicator documentation
     - Market status checking
   - **Usage**: InstrumentWidget, SearchWidget, etc.

2. **AgenticTradingProvider**:
   - **Purpose**: Trade execution and automation
   - **Responsibilities**:
     - Auto-trade execution logic
     - TP/SL monitoring
     - Trade tracking (automated buy trades)
     - Firebase persistence
     - Risk management
   - **Usage**: NavigationWidget (timer), SettingsWidget

3. **MarketHours Utility**:
   - **Purpose**: Consistent market hours checking
   - **Functionality**:
     - DST-aware Eastern Time conversion
     - Weekend detection
     - Market hours validation (9:30 AM - 4:00 PM ET)
   - **Usage**: Both providers and widgets

**Benefits of Refactoring:**
- **Modularity**: Each provider has a single, clear purpose
- **Reusability**: TradeSignalsProvider used across multiple widgets
- **Maintainability**: Easier to modify signal fetching without affecting execution
- **Testability**: Unit test individual components in isolation
- **Performance**: Optimized signal subscriptions and market checks

### Risk Management Controls

#### Daily Trade Limit
- **Config Field**: `dailyTradeLimit` (default: 5)
- **Purpose**: Prevents over-trading and excessive market exposure
- **Reset**: Automatically resets at market open each trading day

#### Cooldown Period
- **Config Field**: `autoTradeCooldownMinutes` (default: 60)
- **Purpose**: Enforces minimum time between trades
- **Behavior**: Trades are blocked until cooldown expires

#### Emergency Stop
- **Activation**: Via UI button or API call
- **Effect**: Immediately halts all auto-trading
- **Persistence**: Remains active until manually deactivated
- **Use Case**: Market volatility, system issues, or user intervention

#### Position Size Limits
- **Config Field**: `maxPositionSize` (default: 100 shares)
- **Purpose**: Caps individual position sizes
- **Integration**: Used by risk assessment functions

#### Portfolio Concentration
- **Config Field**: `maxPortfolioConcentration` (default: 50%)
- **Purpose**: Prevents over-concentration in single positions
- **Calculation**: Position value / total portfolio value

#### Take Profit
- **Config Field**: `takeProfitPercent` (default: 10.0%)
- **Purpose**: Automatically exits positions when profit target is reached
- **Calculation**: `((currentPrice - entryPrice) / entryPrice) * 100`
- **Behavior**: When position P/L >= takeProfitPercent, system executes SELL order
- **Scope**: Only applies to positions opened by automated trading
- **Use Case**: Lock in profits automatically without manual monitoring

#### Stop Loss
- **Config Field**: `stopLossPercent` (default: 5.0%)
- **Purpose**: Automatically exits positions to limit losses
- **Calculation**: `((currentPrice - entryPrice) / entryPrice) * 100`
- **Behavior**: When position P/L <= -stopLossPercent, system executes SELL order
- **Scope**: Only applies to positions opened by automated trading
- **Use Case**: Protect capital by automatically cutting losing positions

### Configuration Parameters

#### Technical Analysis
```dart
smaPeriodFast: 10           // Fast moving average period
smaPeriodSlow: 30           // Slow moving average period
rsiPeriod: 14               // RSI calculation period
marketIndexSymbol: 'SPY'    // Reference market index
```

#### Trade Execution
```dart
autoTradeEnabled: false     // Master auto-trade switch
autoTradeCooldownMinutes: 60 // Minutes between trades

strategyConfig: {
  tradeQuantity: 1,           // Shares per trade
  dailyTradeLimit: 5,         // Max trades per day
  maxPositionSize: 100,       // Max shares per position
  maxPortfolioConcentration: 0.5, // Max 50% in single position
  takeProfitPercent: 10.0,    // Auto-exit at 10% profit
  stopLossPercent: 5.0,       // Auto-exit at 5% loss
  skipRiskGuard: false        // Optional: Skip risk checks for this agent
}
```

#### Indicators
```dart
enabledIndicators: {
  'priceMovement': true,      // Chart patterns & trends
  'momentum': true,           // RSI (overbought/oversold)
  'marketDirection': true,    // Market index trend
  'volume': true,             // Volume confirmation
  'macd': true,              // MACD crossovers
  'bollingerBands': true,    // Volatility bands
  'stochastic': true,        // Stochastic oscillator
  'atr': true,               // Average True Range
  'obv': true,               // On-Balance Volume
}
```

## Macro Assessment

The system integrates a high-level macroeconomic analysis engine to contextually adjust trading behavior. This ensures that the agent is not just reacting to individual stock charts but is aware of the broader economic environment.

### Core Metrics

*   **Risk Status:** The system determines a global state of `RISK_ON`, `RISK_OFF`, or `NEUTRAL`.
    *   **RISK_ON:** Favorable conditions (Good growth, low volatility). Position sizes may be increased.
    *   **RISK_OFF:** Dangerous conditions (High volatility, recession fears). Position sizes are reduced, and defensive sectors are prioritized.
*   **Yield Curve (10Y - 13W):** Monitors for inversion as a leading recession indicator.
*   **Sector Rotation:** Dynamically identifies which sectors are Bullish (e.g., Tech, Discretionary) vs Bearish (e.g., Utilities, Consumer Staples) based on momentum.
*   **Asset Allocation:** Provides a recommended split between Equity, Fixed Income, Cash, and Commodities based on the current cycle.

### Integration with Trading

*   **Position Sizing:** In `RISK_OFF` scenarios, the system automatically acts to preserve capital by reducing the size of new entries.
*   **Validation:** Trades in sectors currently flagged as "Bearish" by the macro model require higher conviction signals to be executed.

## User Interface

### Settings Screen

Access via: 
- User Menu → Automated Trading
- App Bar → Auto-trade status badge (when active)

**Recent UI Improvements (commit 861f2bc):**
- **Auto-Save**: Settings automatically saved on every change (no manual save button)
- **Countdown Timer**: Real-time countdown to next auto-trade check
- **Enhanced Status**: Daily count, last trade time, next trade time all displayed
- **App Bar Integration**: Status badge in SliverAppBar shows auto-trade active state
- **Better UX**: Cleaner layout, better visual feedback, intuitive controls

**Sections:**
1. **Master Toggle**
   - Enable/disable agentic trading system
   - Shows current status with descriptive subtitle
   - Auto-saves on toggle

2. **Automated Trading**
   - Auto-trade toggle
   - **Real-time countdown timer** (shows seconds until next check)
   - Status indicators (active, daily count, last trade time, next trade time)
   - Emergency stop button with confirmation dialog
   - Auto-saves on toggle

3. **Auto-Trade Configuration**
   - Daily trade limit (auto-saves on change)
   - Cooldown period (auto-saves on change)
   - Max daily loss percentage (auto-saves on change)
   - Take profit percentage (auto-saves on change)
   - Stop loss percentage (auto-saves on change)

4. **Risk Management Rules**
   - Trade quantity
   - Max position size
   - Portfolio concentration limit

5. **Technical Indicators**
   - Individual indicator toggles
   - Inline documentation
   - Configuration parameters (RSI period, SMA periods, etc.)

### Status Indicators

**Auto-Trading Active:**
```
🔄 Auto-trading in progress...
```

**Normal Status:**
```
Daily Trades: 3/5
Last Trade: 2h ago
```

**Emergency Stop:**
```
⚠️ Emergency Stop Activated [Resume]
```

## Integration Points

### Trade Signal Generation
- Backend cron jobs generate signals periodically
- Stored in Firestore `agentic_trading/` collection
- Support for multiple intervals (1d, 1h, 15m)
- Real-time updates via Firestore listeners

### Risk Assessment
- Cloud Function: `riskguardTask`
- Evaluates proposals against portfolio state
- Returns approval/rejection with reasoning

### Brokerage Integration
- Executes approved trades via brokerage service
- Supports multiple brokers (Robinhood, Plaid, Schwab)
- Handles order placement and tracking

## Safety Features

### Market Hours Detection
- **MarketHours Utility**: Centralized DST-aware market hours checking
- Automatic DST adjustment (EDT/EST conversion)
- Only trades during regular market hours (9:30 AM - 4:00 PM ET)
- Weekend trading blocked
- Comprehensive debug logging for troubleshooting
- Used consistently across all providers and widgets

### Rate Limiting
- 2-second delay between trade attempts
- Cooldown period enforcement
- Daily limit caps

### Error Handling
- Graceful degradation on API failures
- Comprehensive error logging
- Analytics tracking for all events

### Audit Trail
- Last 100 trades stored in memory
- Analytics events for all actions
- Timestamps and execution details

## Testing

### Unit Tests
Location: `test/agentic_trading_*_test.dart`

**Test Files:**
1. `agentic_trading_config_test.dart` - Configuration model tests
2. `agentic_trading_provider_test.dart` - Provider logic tests  
3. `agentic_trading_settings_widget_test.dart` - UI widget tests *[NEW]*

**Coverage:**
- Configuration serialization/deserialization
- Backward compatibility with old configs
- State management and change notifications
- Risk control enforcement (limits, cooldowns)
- Emergency stop functionality
- Daily limit tracking
- **Auto-save functionality in settings widget** *[NEW]*
- **Indicator toggle persistence** *[NEW]*
- **UI state updates and validation** *[NEW]*

**Run Tests:**
```bash
# All agentic trading tests
flutter test test/agentic_trading_config_test.dart
flutter test test/agentic_trading_provider_test.dart
flutter test test/agentic_trading_settings_widget_test.dart

# Or run all at once
flutter test test/ --name="agentic"
```

**New Widget Tests (commit 861f2bc):**
- Tests auto-save behavior when toggling indicators
- Validates settings persistence to Firestore
- Tests UI rendering with different provider states
- Validates form field updates and validation

### Integration Testing
Recommended approach:
1. Use paper trading mode
2. Test with small position sizes
3. Monitor execution closely
4. Validate risk controls
5. Test emergency stop

## Security Considerations

### Configuration Storage
- User configs stored in Firestore
- Access controlled by security rules
- No sensitive API keys in client code
- **Updated Firestore rules** for `automated_buy_trades` collection *[NEW]*

### Trade Execution
- Server-side validation required (initiateTradeProposal, riskguardTask)
- Risk assessment before execution
- Emergency stop accessible from client
- All trades authenticated and authorized

### Firebase Security Rules
```
// New rules for automated buy trades (commit 861f2bc)
match /users/{userId}/automated_buy_trades/{tradeId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

### Rate Limiting
- Backend rate limiting on Cloud Functions
- Client-side cooldowns (2-second delay between trades)
- Daily limits prevent runaway trading
- Market hours enforcement prevents off-hours trading

## Best Practices

### Initial Setup
1. Start with conservative limits (1-2 trades/day)
2. Use longer cooldown periods (60+ minutes)
3. Set tight loss limits (1-2%)
4. Monitor closely for first week

### Risk Management
1. Never risk more than 2% of portfolio per day
2. Keep position sizes small relative to portfolio
3. Maintain portfolio diversification
4. Use emergency stop if uncertain

### Monitoring
1. Check trade history daily
2. Review rejected proposals
3. Adjust indicators based on performance
4. Monitor analytics events

### Emergency Procedures
1. **Market Volatility**: Activate emergency stop
2. **System Issues**: Disable auto-trade, investigate
3. **Unexpected Behavior**: Stop immediately, review logs

## Analytics Events

The system logs the following events:

- `agentic_trading_toggled`: Master switch changed
- `agentic_trading_auto_executed`: Auto-trade completed
- `agentic_trading_auto_error`: Auto-trade failed
- `agentic_trading_auto_failed`: System error
- `agentic_trading_emergency_stop`: Emergency stop activated
- `agentic_trading_emergency_stop_deactivated`: Resumed
- `agentic_trading_trade_approved`: Manual proposal approved
- `agentic_trading_trade_rejected`: Manual proposal rejected

## Future Enhancements

### Planned Features
1. **Push Notifications**: Alert on auto-trade executions
2. **Performance Tracking**: Win/loss ratio, P&L analytics
3. **Backtesting**: Historical strategy simulation
4. **Machine Learning**: Adaptive indicator weighting
5. **Advanced Orders**: Stop-loss, take-profit automation
6. **Portfolio Rebalancing**: Automatic position adjustment

### Under Consideration
- Multi-asset support (options, crypto, futures)
- Strategy templates (conservative, aggressive, balanced)
- Social trading integration (copy successful traders)
- Custom indicator creation
- Strategy sharing with investor groups

## Troubleshooting

### Auto-Trade Not Executing

**Check:**
1. Is `autoTradeEnabled` true in settings?
2. Is emergency stop activated?
3. Is market currently open?
4. Have you reached daily trade limit?
5. Is cooldown period active?
6. Are there any BUY signals available?

**Debug Steps:**
1. Check provider state: `provider.isAutoTrading`
2. Review `_canAutoTrade()` conditions
3. Verify trade signals: `provider.tradeSignals`
4. Check analytics logs for error events

### Trades Being Rejected

**Common Causes:**
1. Risk assessment failure (position too large)
2. Portfolio concentration limit exceeded
3. Insufficient funds
4. Invalid price data
5. Brokerage API errors

**Resolution:**
1. Review `lastAssessment` for rejection reason
2. Adjust position sizes or limits
3. Check brokerage account status
4. Verify market data availability

### Emergency Stop Not Working

**Verification:**
1. Check `provider.emergencyStopActivated` state
2. Verify UI shows emergency status
3. Test with manual toggle in settings

**If Issue Persists:**
1. Restart app
2. Check Firestore config sync
3. Review error logs

## API Reference

### AgenticTradingProvider Methods

#### `autoTrade({required Map<String, dynamic> portfolioState, required brokerageUser, required account, required brokerageService, required instrumentStore})`
Executes automatic trading based on current signals and places orders through the brokerage.

**Parameters:**
- `portfolioState`: Current portfolio state for risk assessment
- `brokerageUser`: BrokerageUser instance for authentication
- `account`: Account to trade in
- `brokerageService`: IBrokerageService instance for order execution
- `instrumentStore`: InstrumentStore for fetching instrument data

**Returns:** `Map<String, dynamic>`
- `success`: bool - Whether any trades were executed
- `tradesExecuted`: int - Number of trades completed
- `message`: String - Status message
- `trades`: List - Details of executed trades including order responses

#### `activateEmergencyStop()`
Immediately halts all auto-trading.

#### `deactivateEmergencyStop()`
Resumes auto-trading functionality.

#### `loadConfigFromUser(dynamic agenticTradingConfig)`
Loads configuration from User model.

#### `updateConfig(Map<String, dynamic> newConfig, DocumentReference userDocRef)`
Updates configuration and saves to Firestore.

#### `monitorTakeProfitStopLoss({required List positions, required brokerageUser, required account, required brokerageService, required instrumentStore})`
Monitors positions and executes take profit or stop loss orders.

**Parameters:**
- `positions`: List of current InstrumentPosition objects
- `brokerageUser`: BrokerageUser instance for authentication
- `account`: Account to trade in
- `brokerageService`: IBrokerageService instance for order execution
- `instrumentStore`: InstrumentStore for fetching instrument data

**Returns:** `Map<String, dynamic>`
- `success`: bool - Whether any exits were executed
- `exitsExecuted`: int - Number of exit orders placed
- `message`: String - Status message
- `exits`: List - Details of executed exits with P/L% and reason

**Process:**
1. Calculates P/L percentage for each position
2. Triggers SELL when P/L >= takeProfitPercent
3. Triggers SELL when P/L <= -stopLossPercent
4. Places orders and tracks exits

### Static Methods

#### `TradeSignalsProvider.indicatorDocumentation(String key)` *[MOVED]*
Returns documentation for a given indicator.

**Note:** This method was moved from AgenticTradingProvider to TradeSignalsProvider in commit 861f2bc as part of the architecture refactoring.

**Parameters:**
- `key`: Indicator identifier (e.g., 'priceMovement', 'momentum')

**Returns:** `Map<String, String>`
- `title`: Display name
- `documentation`: Detailed description

**Usage:**
```dart
final docInfo = TradeSignalsProvider.indicatorDocumentation('priceMovement');
print(docInfo['title']);         // "Price Movement"
print(docInfo['documentation']); // Full description
```

## Support

For issues or questions:
1. Review this documentation
2. Check unit tests for examples
3. Consult `multi-indicator-trading.md` for signal details
4. Review Firebase Analytics for system events
5. File a GitHub issue with detailed logs

## Integration Examples

### Basic Setup (New Architecture)

**In main.dart:**
```dart
MultiProvider(
  providers: [
    // New: TradeSignalsProvider for signal management
    ChangeNotifierProvider(
      create: (context) => TradeSignalsProvider(),
    ),
    // Existing: AgenticTradingProvider for execution
    ChangeNotifierProvider(
      create: (context) => AgenticTradingProvider(),
    ),
    // ... other providers
  ],
  child: MaterialApp(/* ... */),
)
```

### Fetching Trade Signals (TradeSignalsProvider)

**In any widget:**
```dart
// Access the provider
final tradeSignalsProvider = Provider.of<TradeSignalsProvider>(context);

// Fetch signals for a symbol
await tradeSignalsProvider.fetchTradeSignals(
  symbol: 'AAPL',
  interval: '1d',
  userDocRef: userDocRef,
);

// Access the signals
final signals = tradeSignalsProvider.signals;
```

### Executing Auto-Trade (AgenticTradingProvider)

**From navigation widget (timer integration):**
```dart
final agenticProvider = Provider.of<AgenticTradingProvider>(context, listen: false);
final accountStore = Provider.of<AccountStore>(context, listen: false);
final instrumentStore = Provider.of<InstrumentStore>(context, listen: false);

final result = await agenticProvider.autoTrade(
  portfolioState: {
    'equity': portfolioStore.equity,
    'cash': accountStore.items.first.portfolioCash,
    // ... other portfolio data
  },
  brokerageUser: currentUser,
  account: accountStore.items.first,
  brokerageService: brokerageService,
  instrumentStore: instrumentStore,
  userDocRef: userDocRef,  // For Firebase persistence
);
```

### Monitoring TP/SL

**From navigation widget (timer integration):**
```dart
final positions = portfolioStore.positions;

final result = await agenticProvider.monitorTakeProfitStopLoss(
  positions: positions,
  brokerageUser: currentUser,
  account: accountStore.items.first,
  brokerageService: brokerageService,
  instrumentStore: instrumentStore,
  userDocRef: userDocRef,  // For Firebase persistence
);
```

### Checking Market Hours

**Using MarketHours utility:**
```dart
import 'package:robinhood_options_mobile/utils/market_hours.dart';

if (MarketHours.isMarketOpen()) {
  // Market is open, proceed with trading
  print('✅ Market is open');
} else {
  // Market is closed
  print('❌ Market is closed');
}
```

### Settings Widget Integration

**Navigate to settings:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => AgenticTradingSettingsWidget(
      user: currentUser,
      userDocRef: userDocRef,
    ),
  ),
);
```

**Settings now auto-save** - no manual save button needed. Every change is persisted immediately to Firestore.

### SliverAppBar Status Badge

**The refactored SliverAppBar now shows auto-trade status:**
```dart
// Automatically displays when auto-trading is active
// Shows countdown timer
// Tapping navigates to settings
// No manual integration needed - built into SliverAppBar
```

## Version History

- **v1.6** (2026-01-24): Strategy & Signal Enhancements
  - **Trade Signals Widget**: Dedicated interface for filtering and viewing signals.
  - **Strategy Templates**: Improved management and filtering by strategy configuration.
  - **Premium Access**: Integration with In-App Purchases for premium signal features.
  - **Custom Benchmarks**: Support for custom benchmarking in Portfolio Analytics.

- **v1.5** (2025-12-30): Intraday Data & Sorting Fixes
  - Enhanced market data fetching logic to ensure sufficient historical data for MACD.
  - Improved trade signal sorting functionality and reliability.

- **v1.5** (2026-01-29): Performance Optimization & Flow Filtering
  - Enhanced paper mode filtering in performance widget
  - Optimized backend cron jobs using listDocuments
  - Explicit paper trade indication in notifications

- **v1.4** (2025-12-19): Signal Performance Metrics
  - Added Signal Strength Performance Card (Win Rate by strength bucket)
  - Added Individual Indicator Performance Card (Win Rate by indicator)
  - Enhanced analytics calculation logic
  - Improved performance dashboard UI

- **v1.3** (2025-12-13): Advanced analytics and paper trading
  - Added Paper Trading Mode for risk-free strategy testing
  - Added 9 comprehensive analytics cards in Performance Widget
  - Added advanced metrics: Sharpe Ratio, Profit Factor, Expectancy
  - Added risk metrics: Win/Loss Streaks, Max Drawdown
  - Added Performance by Time of Day analysis
  - Added Performance by Indicator Combo tracking
  - Added trailing stop loss support
  - Added filter chips for paper vs real trade performance
  - Enhanced trade records with enabledIndicators snapshot
  - Color-coded performance indicators (green/orange/red)

- **v1.2** (2025-12-10): Architecture refactoring (commit 861f2bc)
  - Added TradeSignalsProvider for centralized signal management
  - Added MarketHours utility for DST-aware market checks
  - Enhanced settings UI with auto-save and countdown timer
  - Added unit tests for settings widget
  - Updated Firestore security rules
  - Integrated status display in SliverAppBar
  - Improved provider separation and modularity

- **v1.1** (2025-12-09): Trade-level tracking
  - Replaced symbol-based tracking with trade records
  - Added Firebase persistence for automated trades
  - Accurate P/L calculations using entry prices
  - Support for mixed manual + automated positions

- **v1.0** (2025-12-08): Initial implementation
  - Core auto-trade logic
  - Risk management controls
  - Settings UI
  - Unit tests
