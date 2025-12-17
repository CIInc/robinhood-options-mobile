# RealizeAlpha

## Use Cases
- A better options UI view for Robinhood users.
- Ability to make better trades.
- Price target recommendations.
- Enhanced portfolio management with advanced analytics.
- Simplified trading for beginners with guided workflows.
- Centralized view for stocks, options, and crypto assets.
- Integration with brokerage accounts for real-time data.
- AI-driven insights and recommendations.
  - Note: AI portfolio prompts now include per-account cash and a total cash summary when available.
- Historical data analysis for informed decision-making.
- Cross-platform access for iOS and Android users.
- Community-driven features for shared insights and discussions.
- Enhanced security and privacy for user data.
- **Watchlist Management:** Comprehensive tools to create, edit, and manage custom watchlists with real-time data tracking.
- Advanced charting tools for technical analysis.
- **Generative Actions:** AI-driven actions and insights directly within the UI for enhanced decision making.
- **Instrument Charting:** Advanced charting capabilities on instrument details pages.
- Multi-indicator correlated trade signals (12 indicators: Price Movement, RSI with divergence, Market Direction, Volume, MACD, Bollinger Bands, Stochastic, ATR, OBV, VWAP, ADX, Williams %R) with confidence-scored pattern detection and signal strength visualization.
- Integration with social media for sentiment analysis.
- Futures position monitoring with enriched contract/product metadata and real-time Open P&L calculation.

## Investment Profile Feature

This feature adds investment profile configuration to user settings, allowing users to specify their investment goals, time horizon, risk tolerance, and portfolio value. These preferences are then integrated into AI Portfolio Recommendations to provide personalized financial advice.

### Model changes
- Added optional fields on the `User` model: `investmentGoals`, `timeHorizon`, `riskTolerance`, `totalPortfolioValue`.

### AI integration
- `GenerativeService.portfolioPrompt()` now accepts a `user` parameter and includes an "Investment Profile" section when available.
- The prompt also includes per-account cash (`portfolioCash`) and an aggregated total cash across accounts when `user.accounts` is present.

### UI
- New `Investment Profile Settings` widget under user settings for editing goals, time horizon, risk tolerance, and portfolio value.

### Developer notes
- The AI generation pipelines accept an optional `user` parameter and pass it through to `generateContent()`.
- When `user` is not provided, behavior is backward compatible.

## Trade Signals Feature

The Trade Signals feature provides AI-powered automatic trading capabilities using agentic trading with multi-indicator correlation and risk assessment.

### Key Components
- **Multi-Indicator Correlation:** Analyzes 12 technical indicators (Price Movement, RSI, Market Direction, Volume, MACD, Bollinger Bands, Stochastic, ATR, OBV, VWAP, ADX, Williams %R) to generate high-confidence trade signals
- **Signal Strength Visualization:** Color-coded signal strength scores (0-100) with filtering by minimum strength threshold
- **Indicator Documentation Widget:** In-app technical reference for all 12 indicators with detailed explanations of signals, configuration, and technical details
- **Intraday Trading:** Support for multiple time intervals (15-minute, hourly, daily) for different trading strategies
- **Real-Time Updates:** Firestore snapshot listeners provide automatic signal refresh without manual polling
- **Market Hours Intelligence:** Automatically shows intraday signals during market hours and daily signals after hours
  - DST-aware market status detection
  - Intelligent default interval selection based on trading hours
  - Automatic switching between signal types
- **Market Status Indicators:** Visual feedback showing current market state
  - Market status chip in Search widget filter area
  - Market status banner in Instrument widget above interval selector
  - Color-coded states: Green (Market Open), Blue (After Hours)
  - Real-time updates for market open/close transitions
- **Agentic Trading:** Automated agents (Alpha Agent, Risk Guard) monitor markets and execute trades
- **Risk Assessment:** Comprehensive risk analysis before trade execution with portfolio-aware decision making
- **Signal Display:** Trade signals appear prominently in Search and Instrument widgets with interval labels, dates, and confidence scores
- **Server-Side Filtering:** Efficient signal filtering by type (BUY/SELL/HOLD), date range, symbols, and interval with Firestore queries
  - Increased daily signal query limit to 500 to handle mixed interval data
  - "All" filter now correctly includes HOLD signals
- **State Synchronization:** Real-time updates across Instrument View and Search View when signals are regenerated
- **Manual Execution:** Ad-hoc cron endpoint for manual signal generation via callable/HTTP function

### Signal Filtering & Search
- **Filter UI:** FilterChips in Search tab for quick filtering by signal type (All/BUY/SELL/HOLD)
- **Color-Coded Filters:** Green (BUY), red (SELL), grey (HOLD) for visual clarity
- **Server-Side Queries:** Optimized Firestore queries with indexed fields reduce network payload
- **Performance:** Default limit of 50 signals with configurable parameters
- **Manual Refresh:** Refresh button to reload signals with current filters
- **Empty States:** Clear messages when no signals match selected filters

### Configuration
- Users can enable/disable agentic trading in settings
- Configurable watchlist for symbols to monitor
- Risk parameters and portfolio integration
- Trade signal history and results tracking
- Optional filtering parameters: signal type, date range, symbols, limit
- **Automated Trading:** Full auto-trade capabilities with risk controls (see [Agentic Trading](agentic-trading.md))
  - Daily trade limits and cooldown periods
  - Emergency stop functionality
  - Position size and portfolio concentration limits
  - Real-time status monitoring and trade history

### Technical Details
- Firestore integration for signal storage: `agentic_trading/signals_{SYMBOL}`
- Firebase Functions for scheduled agent execution
- Provider pattern (AgenticTradingProvider) for state management
- Real-time signal updates and notifications
- Composite Firestore indexes for optimized queries
- State synchronization between single signal and signal list

For detailed technical documentation:
- [Multi-Indicator Trading System](multi-indicator-trading.md) - Signal generation and analysis
- [Agentic Trading](agentic-trading.md) - Autonomous trade execution and risk management
- [Backtesting](backtesting.md) - Test strategies on historical data

## Backtesting Interface

The Backtesting Interface enables users to test trading strategies on historical data using the same multi-indicator system as live trading. This feature allows strategy validation, parameter optimization, and performance analysis before committing capital.

### Key Features
- **Historical Data Access:** Fetch OHLCV data for any symbol with multiple intervals (daily, hourly, 15-min)
- **Strategy Builder:** Configure all 9 technical indicators with the same parameters as live trading
- **Performance Metrics:** Comprehensive analysis including Sharpe ratio, max drawdown, win rate, profit factor
- **Visual Results:** Trade-by-trade breakdown with entry/exit reasons and equity curves
- **Template System:** Save and reuse backtest configurations
- **Export Reports:** Save results as JSON for external analysis
- **Result Comparison:** Compare multiple backtests side-by-side

### Architecture
- **Frontend:** Flutter UI with 3-tab interface (Run, History, Templates)
- **Backend:** Firebase Functions for backtest execution using existing market data infrastructure
- **Storage:** Firestore for backtest history and templates (last 50 runs per user)
- **Integration:** Uses exact same `evaluateAllIndicators()` logic as live trading for consistency

### Usage Flow
1. Navigate to User Settings → Backtesting
2. Configure symbol, date range, interval, and capital
3. Enable desired indicators and set risk parameters (TP/SL/trailing stop)
4. Run backtest to simulate historical trades
5. Review results with key metrics and trade details
6. Save configuration as template for future use
7. Compare multiple backtests to optimize strategy

For complete documentation, see [Backtesting](backtesting.md).

## Futures Positions Feature

The Futures Positions feature enriches raw futures holdings with contract & product metadata (root symbol, expiration, currency, multiplier) and real-time last trade prices to compute transparent Open P&L per contract.

### Key Components
- **Metadata Enrichment:** Contract and product details fetched before quote integration.
- **Live Quotes:** Last trade price used for immediate Open P&L visibility.
- **Open P&L Calculation:** `(lastTradePrice - avgTradePrice) * quantity * multiplier` per position.
- **UI Display:** Color-coded Open P&L and concise contract summary in the positions widget.
- **Service-Oriented:** Logic contained in service layer; no secrets moved client-side.

### Limitations (Initial Version)
- No realized or day P&L yet.
- No margin requirement or leverage analytics.
- No contract roll alerts or calendar spread tracking.
- No Greeks or term structure metrics.

### Roadmap
- Margin & risk metrics (SPAN-style), realized/day P&L, roll detection, Greeks & volatility surfaces, contract seasonality analytics, VAR integration.

See [Futures Positions](futures.md) for full details.

## Investor Groups Feature

The Investor Groups feature enables collaborative portfolio sharing and community building among investors.

### Key Components
- **Group Creation:** Create public or private investor groups with customizable settings
- **Member Management:** Join, leave, and manage group memberships with comprehensive invitation system
  - Send invitations to users by searching for them in real-time
  - Accept or decline invitations from dedicated "Invitations" tab
  - Cancel pending invitations before they're accepted
  - View all pending invitations in one place
- **Admin Controls:** Group creators and admins can manage members with full control
  - Promote members to admin role
  - Demote admins back to regular members
  - Remove members from groups
  - Send and manage invitations
  - Edit group details and settings
- **Portfolio Sharing:** View portfolios shared within your groups
- **Private Group Portfolio Viewing:** Tap any member in a private group to view their shared portfolio including stocks, ETFs, and options orders
- **Discovery:** Browse and join public groups or search for specific communities

### User Interface
- **InvestorGroupsWidget:** Main interface with "My Groups", "Invitations", and "Discover" tabs
  - **My Groups:** View all groups you're a member of
  - **Invitations:** Dedicated tab showing all pending invitations with accept/decline actions
  - **Discover:** Browse public groups and join new communities
- **Group Details:** View member lists with avatars, group information, and tappable members for portfolio viewing (private groups only)
- **Portfolio Navigation:** Seamless navigation from member list to SharedPortfolioWidget showing real-time orders and transactions
- **Member Management:** Comprehensive 3-tab admin interface
  - **Members Tab:** View all members, promote/demote admins, remove members
  - **Pending Tab:** View and cancel pending invitations
  - **Invite Tab:** Search users in real-time and send invitations
- **Creation Form:** Simple form with name, description, and privacy toggle

### Technical Implementation
- **InvestorGroup Model:** Full serialization support with member/admin/invitation tracking
  - `id`, `name`, `description`, `isPrivate` fields
  - `members`, `admins`, `pendingInvitations` arrays
  - `createdBy`, `createdAt`, `updatedAt` timestamps
- **Firestore Integration:** 15+ service methods for comprehensive functionality
  - CRUD: `createInvestorGroup`, `getInvestorGroup`, `updateInvestorGroup`, `deleteInvestorGroup`
  - Membership: `joinInvestorGroup`, `leaveInvestorGroup`, `addGroupAdmin`, `removeGroupAdmin`
  - Invitations: `inviteUserToGroup`, `acceptGroupInvitation`, `declineGroupInvitation`, `getUserPendingInvitations`
  - Discovery: `getUserInvestorGroups`, `getPublicInvestorGroups`, `searchInvestorGroups`
  - Management: `removeMemberFromGroup`
- **Security Rules:** Firestore rules enforce proper access control
  - Read access for public groups or members/invitees of private groups
  - Create access for authenticated users
  - Update access for creators, admins, or users accepting invitations
  - Delete access for creators only
- **State Management:** InvestorGroupStore ChangeNotifier integrated with Provider pattern

### Integration Points
- **Shared Portfolios:** New "Groups" tab shows portfolios from members in your groups
- **Direct Portfolio Access:** Tap member in private group detail view to navigate to SharedPortfolioWidget
- **Navigation:** Access via drawer menu under "Investor Groups"
- **Real-Time Updates:** StreamBuilder for Firestore user documents ensures live portfolio data

### Security
- Private groups visible only to members and invitees
- Public groups discoverable by all users
- Only group creator and admins can edit/delete groups
- Only group creator and admins can send invitations
- Member operations properly authenticated
- Invitation access controlled via Firestore security rules

For implementation details, see:
- `lib/model/investor_group.dart` - Data model with member/admin/invitation tracking
- `lib/model/investor_group_store.dart` - State management
- `lib/services/firestore_service.dart` - Backend operations (15+ methods)
- `lib/widgets/investor_groups_widget.dart` - Main UI with 3-tab layout
- `lib/widgets/investor_group_detail_widget.dart` - Group details with member list and portfolio navigation
- `lib/widgets/investor_group_create_widget.dart` - Group creation form
- `lib/widgets/investor_group_manage_members_widget.dart` - Admin member management interface with 3 tabs
- `lib/widgets/shared_portfolio_widget.dart` - Portfolio display widget
- `firebase/firestore.rules` - Security rules
- `test/investor_group_model_test.dart` - Unit tests (230+ lines)

## Requirements

### Tabs

- Portfolio tab
  - Portfolio section
    - [x] Portfolio historical chart with filters  
      _Visualize portfolio value over time with customizable date ranges and chart types (line, candlestick, etc.)._
    - [x] Portfolio summary breakdown view  
      _See allocation by asset class, sector, or custom tags._
  - Options section
    - [x] Options summary with bar chart  
      _Quickly assess open options positions by type, expiry, or strategy._
    - [x] Options list with filters and grouping  
      _Filter by expiry, strike, underlying, or strategy (e.g., spreads, covered calls)._
    - [x] Option detail view with market data (see Option view)  
      _Access Greeks, IV, open interest, and historical performance._
  - Stocks section
    - [x] Stock summary with bar chart  
      _Visualize holdings by ticker, sector, or performance._
    - [x] Stock list with filters  
      _Filter by gainers, losers, sector, or watchlist._
    - [x] Stock detail view with market data (see Stock view)  
      _Access fundamentals, news, analyst ratings, and earnings._
  - Crypto section
    - [x] Crypto holdings  
      _Track balances and performance for supported cryptocurrencies._
    - [x] Crypto detail view with market data (see Crypto view)  
      _View price charts, news, and on-chain analytics._
    - [ ] Crypto sentiment analysis  
      _Gauge market sentiment from social media and news sources._

- Transactions tab
  - [x] Position order list  
    _Review all past and open orders for stocks, options, and crypto._
  - [x] Option order list  
    _Track option-specific orders and their outcomes._
    - [x] Integrated option event list  
      _See assignment, exercise, and expiration events._
  - [x] Balances and order counts  
    _Monitor cash, margin, and buying power._
  - [x] Share orders  
    _Track fractional and whole share purchases and sales._
  - [ ] Transaction analytics  
    _Break down profits, losses, and fees by trade type or asset._

- Search tab
  - [x] Search companies by name or symbol  
    _Find stocks, options, or crypto quickly._
  - [x] Trade Signals  
    _View AI-generated trade signals with multi-indicator correlation and confidence scores._
    - [x] Signal cards with BUY/SELL/HOLD recommendations
    - [x] Risk Guard integration for trade validation
    - [x] Prominent date and reason display
    - [x] Color-coded borders and badges
    - [x] Server-side filtering by signal type, date range, and symbols
    - [x] Filter UI with color-coded chips (All/BUY/SELL/HOLD)
    - [x] Real-time synchronization between Instrument and Search views
  - [x] S&P movers, losers, and gainers  
    _See daily market leaders and laggards._
  - [x] Top 100 stocks  
    _Browse the most popular or highest-volume stocks._
  - [x] Stock Screener  
    _Filter stocks by sector, market cap, P/E ratio, dividend yield, price, and volume._
    - [x] Quick presets (High Dividend, Growth, Value, Large Cap)
    - [x] Yahoo Finance screener integration
    - [x] Sortable results
  - [ ] Undervalued/Overvalued (Fair value evaluation)  
    _Identify potential bargains or overpriced assets using valuation models._

- Lists tab
  - [x] View your lists and its stocks  
    _Organize watchlists and custom groups._
    - [ ] List sort order maintenance  
      _Drag and drop to reorder lists._
    - [ ] List item sort order maintenance  
      _Reorder items within a list._
  - [x] View RobinHood lists  
    _Access default lists like "Top Movers" or "Most Popular."_
  - [ ] Create new list  
    _Add custom watchlists for tracking ideas._
  - [ ] Edit list  
    _Rename, reorder, or delete lists._
  - [ ] Add symbol to list  
    _Quickly add stocks, options, or crypto to any list._
  - [ ] Collaborative lists  
    _Share and manage lists with friends or the community._

### Views

- Stock view
  - [x] Instrument (Stock) view  
    _Comprehensive overview of a stock, including price, news, and performance._
    - [x] AI-generated trend analysis  
      _Get insights on price trends and patterns._
    - [ ] AI-generated price target  
      _Get a recommended price target based on AI analysis._
    - [ ] AI-generated news sentiment analysis
      _Analyze news sentiment and its potential impact on stock price._
    - [x] Position detail with orders  
      _See all trades and open positions for a stock._
    - [x] Options list with orders  
      _View all options trades related to the stock._
    - [x] Fundamentals view  
      _Access key financial metrics and ratios._
    - [x] Historical chart with filters  
      _Analyze price trends over different periods._
    - [x] Related lists view  
      _See which lists the stock appears in._
    - [x] News view  
      _Stay updated with the latest headlines._
    - [x] Ratings view  
      _See analyst recommendations and target prices._
    - [x] Earnings view  
      _Review past and upcoming earnings reports._
    - [x] Similar view  
      _Discover similar stocks based on sector or performance._
    - [ ] Splits & Corporate Actions view  
      _Track splits, dividends, and other events._
    - [ ] Insider trading activity view  
      _Monitor insider buys and sells._
  - [x] Option chain view  
    _Browse available options contracts and strategies._
    - [x] Show current price list divider with scroll-to function  
      _Quickly jump to at-the-money options._

- Option view
  - [x] Option greeks view  
    _Analyze delta, gamma, theta, vega, and rho._
    - [x] AI-generate contract selection  
      _Get recommendations on which options to trade._
    - [ ] Risk analysis with charts  
      _Visualize risk/reward and breakeven points._
    - [ ] Probability of profit (POP) calculator  
      _Estimate the likelihood of a profitable outcome._

- Crypto view
  - [x] Crypto historical chart with filters  
    _Analyze price trends and volatility._
  - [ ] Crypto staking rewards tracker  
    _Track earned rewards from staking._
  - [ ] Crypto wallet integration  
    _Connect external wallets for a unified view._

- Trading view
  - [ ] Place stock order  
    _Buy or sell stocks directly from the app._
  - [x] Place option order  
    _Trade single-leg and multi-leg options._
    - [ ] buy-to-close, sell-to-open, limit, time-in-force  
      _Support advanced order types._
    - [ ] Multi-leg strategies  
      _Trade spreads, straddles, and more._
      - [ ] Call/Put debit/credit spreads
      - [ ] Synthetic long/short
      - [ ] Calendar/diagonal spreads
    - [ ] Price spread selector (bid/ask analysis for low-volume options)  
      _Find optimal entry/exit points._
  - [ ] Place crypto order  
    _Trade supported cryptocurrencies._
  - [ ] Cancel pending order  
    _Easily cancel open orders._
  - [ ] Replace order  
    _Modify existing orders without canceling._
  - [ ] Trade simulator (practice trading with virtual money)  
    _Test strategies risk-free._

- Account view
  - [ ] Manage multiple accounts on the trading platform  
    _Switch between accounts without logging out._
  - [ ] Account performance analytics (e.g., CAGR, Sharpe ratio)  
    _Track long-term performance and risk-adjusted returns._

### Future Feature Suggestions

- **Social Integration**
  - [x] Investor Groups for collaborative portfolio sharing
    - Create public or private investor groups
    - Join and leave groups with member management
    - View shared portfolios within groups
    - Group admin controls
  - [ ] Reddit integration for trending tickers and sharing results.
  - [ ] Twitter sentiment tracking and sharing.
  - [ ] Community-driven trade ideas and discussions.

- **Machine Learning & Analytics**
  - [ ] AI-powered price target and trade recommendations.
  - [ ] Portfolio optimization using machine learning.
  - [ ] Sentiment analysis for news and social media.
  - [ ] Risk exposure and sector allocation heatmaps.

- **Notifications & Alerts**
  - [ ] Custom price alerts for stocks, options, and crypto.
  - [ ] Earnings and dividend notifications.
  - [ ] News alerts for portfolio holdings.

- **Mobile & Usability Enhancements**
  - [ ] Offline mode for portfolio and charts.
  - [ ] Push notifications for trade execution and alerts.
  - [ ] Home screen widgets for quick updates.

- **Collaboration & Sharing**
  - [x] Investor Groups with portfolio sharing
  - [ ] Shared watchlists with friends.
  - [ ] Group discussions for specific assets.
  - [ ] Public leaderboards for portfolio performance.

---

- [App Launcher Icon](https://icon.kitchen/i/H4sIAAAAAAAAAz2PQQvCMAyF%2F8vzuoswQXrdH%2FCwm4h0a9oVu2V0rSJj%2F910ipfk8RLyvax46pBpgVphdHy0A40EZXVYqIJ1TfCzjqmMF5IGQ1bnkFDB9zyJkSJNxk%2FunmdsFTrXvme5gJ4DR1nrXLMrhUNdn7W14qVCMVAp5p1y0aacKJTEM9TxVCF6NwiwyI5T4vGrA9ndFZT9o34hxRvZ5FDeuUJPJrI3JSkvUl%2FU4bZ9AAfiKa7xAAAA)

## Testing

- Run unit tests for the app:

```bash
cd src/robinhood_options_mobile
flutter test
```

- Run a single test file (example):

```bash
flutter test test/user_model_test.dart
```

## Developer Reference

- Key files:
  - `lib/main.dart` - App entrypoint and provider wiring
  - `lib/model/user.dart` - User model and investment profile fields
  - `lib/services/generative_service.dart` - AI prompt generation and `portfolioPrompt()`
  - `lib/widgets/investment_profile_settings_widget.dart` - Investment profile UI
  - `functions/` - Server-side Firebase Functions and helpers

## Future Enhancements

This project is actively evolving. For a comprehensive roadmap of planned features and enhancements, see [ROADMAP.md](../ROADMAP.md).


## Support

- For issues related to investment profile behavior or AI prompts:
  1. Check `lib/services/generative_service.dart` for prompt construction
  2. Review unit tests under `test/`
  3. Use Firebase emulator for local testing of functions
  4. Contact the development team with reproducible steps and sample user data