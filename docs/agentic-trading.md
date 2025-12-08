# Agentic Trading Documentation

## Overview

The Agentic Trading system provides autonomous, AI-powered trading capabilities for RealizeAlpha. It combines multi-indicator technical analysis with risk management controls to execute trades automatically based on qualified trading signals.

## Architecture

### Components

1. **AgenticTradingConfig** (`lib/model/agentic_trading_config.dart`)
   - User configuration model
   - Stores all trading parameters and risk controls
   - Persisted in Firestore User documents

2. **AgenticTradingProvider** (`lib/model/agentic_trading_provider.dart`)
   - Core state management and trading logic
   - Implements `ChangeNotifier` for reactive UI updates
   - Manages trade execution and safety checks

3. **AgenticTradingSettingsWidget** (`lib/widgets/agentic_trading_settings_widget.dart`)
   - User interface for configuration
   - Real-time status monitoring
   - Emergency controls

4. **Backend Functions** (`functions/src/`)
   - `initiateTradeProposal`: AI-powered trade evaluation
   - `riskguardTask`: Risk assessment and validation
   - Trade signal generation cron jobs

## Features

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

### Risk Management Controls

#### Daily Trade Limit
- **Config Field**: `dailyTradeLimit` (default: 5)
- **Purpose**: Prevents over-trading and excessive market exposure
- **Reset**: Automatically resets at market open each trading day

#### Cooldown Period
- **Config Field**: `autoTradeCooldownMinutes` (default: 60)
- **Purpose**: Enforces minimum time between trades
- **Behavior**: Trades are blocked until cooldown expires

#### Maximum Daily Loss
- **Config Field**: `maxDailyLossPercent` (default: 2.0%)
- **Purpose**: Stops trading if losses exceed threshold
- **Status**: Configuration field available; enforcement requires portfolio P&L tracking integration (planned enhancement)

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
tradeQuantity: 1            // Shares per trade
autoTradeEnabled: false     // Master auto-trade switch
dailyTradeLimit: 5          // Max trades per day
autoTradeCooldownMinutes: 60 // Minutes between trades
```

#### Risk Controls
```dart
maxPositionSize: 100                // Max shares per position
maxPortfolioConcentration: 0.5      // Max 50% in single position
maxDailyLossPercent: 2.0            // Stop at 2% daily loss
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

## User Interface

### Settings Screen

Access via: User Menu → Agentic Trading Settings

**Sections:**
1. **Master Toggle**
   - Enable/disable agentic trading system
   - Shows current status

2. **Automated Trading**
   - Auto-trade toggle
   - Status indicators (active, daily count, last trade time)
   - Emergency stop button

3. **Auto-Trade Configuration**
   - Daily trade limit
   - Cooldown period
   - Max daily loss percentage

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
- Automatic DST adjustment
- Only trades during regular market hours (9:30 AM - 4:00 PM ET)
- Weekend trading blocked

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

**Coverage:**
- Configuration serialization/deserialization
- State management
- Risk control enforcement
- Emergency stop functionality
- Daily limit tracking

**Run Tests:**
```bash
flutter test test/agentic_trading_config_test.dart
flutter test test/agentic_trading_provider_test.dart
```

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

### Trade Execution
- Server-side validation required
- Risk assessment before execution
- Emergency stop accessible from client

### Rate Limiting
- Backend rate limiting on Cloud Functions
- Client-side cooldowns
- Daily limits prevent runaway trading

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

#### `autoTrade({required Map<String, dynamic> portfolioState})`
Executes automatic trading based on current signals.

**Returns:** `Map<String, dynamic>`
- `success`: bool - Whether any trades were executed
- `tradesExecuted`: int - Number of trades completed
- `message`: String - Status message
- `trades`: List - Details of executed trades

#### `activateEmergencyStop()`
Immediately halts all auto-trading.

#### `deactivateEmergencyStop()`
Resumes auto-trading functionality.

#### `toggleAgenticTrading(bool? value)`
Enables/disables the agentic trading system.

#### `loadConfigFromUser(dynamic agenticTradingConfig)`
Loads configuration from User model.

#### `updateConfig(Map<String, dynamic> newConfig, DocumentReference userDocRef)`
Updates configuration and saves to Firestore.

### Static Methods

#### `AgenticTradingProvider.indicatorDocumentation(String key)`
Returns documentation for a given indicator.

**Parameters:**
- `key`: Indicator identifier (e.g., 'priceMovement', 'momentum')

**Returns:** `Map<String, String>`
- `title`: Display name
- `documentation`: Detailed description

## Support

For issues or questions:
1. Review this documentation
2. Check unit tests for examples
3. Consult `multi-indicator-trading.md` for signal details
4. Review Firebase Analytics for system events
5. File a GitHub issue with detailed logs

## Version History

- **v1.0** (2025-12-08): Initial implementation
  - Core auto-trade logic
  - Risk management controls
  - Settings UI
  - Unit tests
