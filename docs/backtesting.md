# Backtesting Interface

Comprehensive backtesting interface for testing trading strategies on historical data using the same multi-indicator system as live trading.

## Features

### Historical Data Access
- Fetch historical price data (OHLCV) for any symbol
- Support for multiple intervals: Daily (1d), Hourly (1h), 15-minute (15m)
- Date range selection (5 days to 5 years)
- Market index data for correlation analysis (SPY/QQQ)

### Strategy Builder
- Configure all 15 technical indicators independently (Price Movement, RSI, Market Direction, Volume, MACD, Bollinger Bands, Stochastic, ATR, OBV, VWAP, ADX, Williams %R, Ichimoku Cloud, CCI, Parabolic SAR)
- Match live trading configuration exactly
- **Default Templates**: Access a library of pre-configured strategies (e.g., "Momentum Master", "Trend Follower") to get started quickly.
- Advanced parameter tuning:
  - RSI period
  - Fast/Slow SMA periods
  - Market index symbol
  - Take Profit %
  - Stop Loss %
  - Trailing Stop %

### Performance Metrics
- **Returns**: Total return, return %, final capital
- **Trade Statistics**: Total trades, winning/losing trades, win rate
- **Risk Metrics**: 
  - Sharpe ratio (risk-adjusted returns)
  - Maximum drawdown
  - Profit factor (total wins / total losses)
- **Trade Analysis**:
  - Average win/loss
  - Largest win/loss
  - Average hold time
- **Equity Curve**: Track capital over time

### Enhanced Pattern Detection
- **Candlestick Patterns**: The backtesting engine now recognizes Bullish/Bearish Engulfing, Hammer, and Shooting Star patterns.
- **Weighted Scoring**: Signals are evaluated using the live Weighted Signal Strength system (Price Action weighted 1.5x) for realistic simulation.

### Visual Results
- **Visual Charts**:
  - Interactive Equity Curve
  - Drawdown Chart (new)
  - Buy & Hold comparison line
- **Trade-by-trade breakdown** with entry/exit reasons
- **Performance Metrics**:
  - Sortino Ratio and Calmar Ratio
  - Expectancy
- **Empty State**: Friendly "No trades executed" message when no trades occur
- Visual indicators for configured strategies in the Details tab

### Enhanced Reporting
- **Details Tab**: Now shows full configuration:
  - Partial exit stages
  - Detailed custom indicator cards with signal logic
- **Consistent Formatting**:
  - Dates formatted as `MMM dd, yyyy` (e.g., Jan 19, 2026) in headers and dialogs
  - Chart axis formatted compactly as `MM/dd` for mobile readability
- **Template Management**: dynamic title updates when templates are saved

### Export Reports
- Export results as JSON
- Export results as CSV (new)
- Save backtest configurations as templates
- Compare multiple backtest runs
- Historical backtest storage (last 50 runs)
- Share visual result summaries

## Architecture

### Frontend (Flutter/Dart)

#### Models (`lib/model/backtesting_models.dart`)
- `BacktestConfig`: Configuration for a backtest run
- `BacktestTrade`: Individual trade record
- `BacktestResult`: Complete backtest results with metrics
- `BacktestTemplate`: Saved configuration template

#### Provider (`lib/model/backtesting_provider.dart`)
- `BacktestingProvider`: State management for backtesting
  - Run backtest via Firebase Function
  - Manage backtest history
  - Save/load templates
  - Export results

#### UI (`lib/widgets/backtesting_widget.dart`)
- **3-Tab Interface**:
  1. **Run Tab**: Configure and execute new backtests
  2. **History Tab**: View past backtest results
  3. **Templates Tab**: Save and load configurations

### Backend (Firebase Functions)

#### Function (`functions/src/backtesting.ts`)
- `runBacktest`: Cloud function for backtest execution
  - Fetch historical data using existing `getMarketData`
  - Simulate trades using multi-indicator system
  - Calculate performance metrics
  - Return comprehensive results

## Usage

### Running a Backtest

1. Navigate to User Settings → Backtesting
2. Configure backtest parameters:
   - **Symbol**: Stock ticker (e.g., AAPL, TSLA)
   - **Date Range**: Start and end dates
   - **Interval**: 1d, 1h, or 15m
   - **Capital**: Initial investment amount
   - **Trade Quantity**: Shares per trade
   - **Risk Management**: TP/SL percentages
5. Enable desired indicators (default: all 12 enabled)
4. Optionally configure advanced settings
5. Click "Run Backtest"

### Viewing Results

Results show:
- Total Return ($ and %)
- Win Rate and trade breakdown
- Sharpe Ratio (risk-adjusted performance)
- Profit Factor and Max Drawdown
- Full trade list with entry/exit details

### Saving Templates

Save frequently used configurations:
1. Configure desired settings
2. After running backtest, save as template
3. Access templates from Templates tab
4. Load template to quickly run similar backtests

### Comparing Results

1. Run multiple backtests with different configurations
2. View results in History tab
3. Use comparison feature to analyze differences:
   - Return differences
   - Win rate differences
   - Risk metric comparisons

## Technical Details

### Backtest Simulation Logic

The backtest simulation follows this flow:

1. **Data Preparation**
   - Fetch historical OHLCV data for symbol and market index
   - Determine start/end indices based on date range
   - Prepare data arrays for indicator calculation

2. **Bar-by-Bar Processing**
   For each historical bar:
   - Calculate indicators using data up to current point
   - Evaluate all enabled indicators via `evaluateAllIndicators()`
   - Check exit conditions for open positions (TP/SL/trailing stop)
   - Check entry conditions if no position open (all indicators BUY)
   - Record trades and update equity curve

3. **Position Management**
   - **Entry**: When all enabled indicators signal BUY
   - **Exit**: 
     - Take Profit: Price increases by TP%
     - Stop Loss: Price decreases by SL%
     - Trailing Stop: Price drops TS% from highest point
   - **End of Backtest**: Close any open positions

4. **Metrics Calculation**
   - Calculate trade statistics (wins, losses, averages)
   - Calculate risk metrics (Sharpe ratio, max drawdown)
   - Build equity curve for visualization
   - Compute hold times and other analytics

### Integration with Live Trading

The backtesting system uses the **exact same logic** as live trading:
- Same `evaluateAllIndicators()` function from `technical-indicators.ts`
- Same indicator parameters (RSI period, SMA periods, etc.)
- Same signal generation logic (all indicators must agree)
- Same entry/exit criteria

This ensures backtest results accurately reflect live trading performance.

### Firebase Function Parameters

The `runBacktest` function accepts:
```typescript
{
  symbol: string;
  startDate: string;  // ISO 8601
  endDate: string;    // ISO 8601
  initialCapital: number;
  interval: '1d' | '1h' | '15m';
  enabledIndicators: { [key: string]: boolean };
  tradeQuantity: number;
  takeProfitPercent: number;
  stopLossPercent: number;
  trailingStopEnabled: boolean;
  trailingStopPercent: number;
  rsiPeriod: number;
  smaPeriodFast: number;
  smaPeriodSlow: number;
  marketIndexSymbol: string;
}
```

Returns:
```typescript
{
  config: BacktestConfig;
  trades: BacktestTrade[];
  finalCapital: number;
  totalReturn: number;
  totalReturnPercent: number;
  totalTrades: number;
  winningTrades: number;
  losingTrades: number;
  winRate: number;
  averageWin: number;
  averageLoss: number;
  largestWin: number;
  largestLoss: number;
  profitFactor: number;
  sharpeRatio: number;
  maxDrawdown: number;
  maxDrawdownPercent: number;
  averageHoldTimeSeconds: number;
  totalDurationSeconds: number;
  equityCurve: { timestamp: string; equity: number }[];
  performanceByIndicator: { [key: string]: any };
}
```

## Firestore Structure

### Backtest History
```
users/{userId}/backtest_history/{backtestId}
  - result: BacktestResult
  - createdAt: Timestamp
```

### Templates
```
users/{userId}/backtest_templates/{templateId}
  - id: string
  - name: string
  - description: string
  - config: BacktestConfig
  - createdAt: string
  - lastUsedAt: string
```

## Best Practices

### Choosing Date Ranges
- **Short-term (< 3 months)**: Use 1h or 15m intervals for intraday strategies
- **Medium-term (3-12 months)**: Use 1d intervals
- **Long-term (> 1 year)**: Use 1d intervals with extended data

### Indicator Selection
- Start with all 12 indicators enabled
- Incrementally disable indicators to test sensitivity
- Compare results to find optimal indicator combinations
- Document findings in template descriptions

### Risk Management
- Test multiple TP/SL combinations
- Compare results with and without trailing stops
- Adjust based on symbol volatility
- Consider market conditions during backtest period

### Result Interpretation
- **Win Rate**: > 50% is generally good, but profit factor matters more
- **Sharpe Ratio**: > 1.0 is good, > 2.0 is excellent
- **Profit Factor**: > 1.5 indicates solid strategy
- **Max Drawdown**: Keep < 20% for acceptable risk

### Avoiding Overfitting
- Test across multiple time periods
- Test on different symbols
- Don't over-optimize parameters
- Consider forward testing after backtesting

## Limitations

### Current Limitations
1. **Commission**: Currently set to $0 (can be added per trade)
2. **Slippage**: Not simulated (assumes fills at close price)
3. **Liquidity**: Doesn't account for order book depth
4. **Market Impact**: Assumes no price impact from orders
5. **Splits/Dividends**: Not currently handled

### Data Limitations
- Historical data from Yahoo Finance API
- Limited to symbols supported by Yahoo Finance
- Data quality depends on Yahoo Finance reliability
- Cache system may cause slight delays for real-time data

## Future Enhancements

### Planned Features
- [x] Visual equity curve charts
- [x] Drawdown charts
- [x] Export to CSV
- [x] Share backtest results
- [ ] Monte Carlo simulation for confidence intervals
- [ ] Walk-forward analysis for robustness testing
- [ ] Portfolio backtesting (multiple symbols)
- [ ] Custom commission models
- [ ] Benchmark comparison metrics
- [ ] Optimization algorithms for parameter tuning

### Advanced Analytics
- [ ] Win/loss distribution analysis
- [ ] Consecutive wins/losses tracking
- [ ] Time-of-day performance (for intraday)
- [ ] Indicator contribution analysis
- [ ] Correlation with market indices
- [ ] Volatility-adjusted returns

## Troubleshooting

### Backtest Fails to Run
**Check:**
1. Symbol is valid and supported by Yahoo Finance
2. Date range contains sufficient data
3. Start date is before end date
4. Internet connection is stable
5. Firebase Functions are deployed correctly

*Note: The system now automatically handles `NaN` and `Infinity` values in underlying calculations to prevent data transmission errors.*

### No Trades Generated
**Likely causes:**
1. No periods where all indicators align
2. Indicator parameters too restrictive
3. Insufficient capital for trade quantity
4. Date range too short

**Solutions:**
- Reduce number of enabled indicators
- Adjust indicator parameters (RSI period, SMA periods)
- Increase date range
- Check indicator signals in live trading first

### Unrealistic Results
**Consider:**
1. Commission and slippage not included
2. Perfect fill assumptions
3. Look-ahead bias if using future data
4. Overfitting to specific time period

**Solutions:**
- Add manual commission adjustments to results
- Test across multiple time periods
- Compare with live trading results
- Use out-of-sample testing

### Slow Performance
**Optimization:**
1. Reduce date range for initial tests
2. Use daily interval instead of intraday
3. Limit enabled indicators for faster computation
4. Cache results for repeated tests

## Integration Points

### With Live Trading
- Uses same `AgenticTradingConfig` model
- Same technical indicator parameters
- Same multi-indicator evaluation logic
- Can export backtest config to live trading

### With Trade Signals
- Backtest uses same signal generation
- Compare backtest signals with live signals
- Validate indicator behavior
- Test signal filtering logic

### With Firebase
- Stores history in Firestore
- Uses Firebase Functions for computation
- Analytics tracking for backtest runs
- Secure user data isolation

## Support

For issues or questions:
1. Review this documentation
2. Check Firebase Functions logs for errors
3. Verify historical data availability
4. Test with shorter date ranges first
5. File a GitHub issue with backtest configuration and error details

## Related Documentation
- [Multi-Indicator Trading System](multi-indicator-trading.md)
- [Agentic Trading](agentic-trading.md)
- [Trade Signal Notifications](trade-signal-notifications.md)
