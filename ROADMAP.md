
# Roadmap

This document outlines the planned features and enhancements for RealizeAlpha.

## Summary

**RealizeAlpha** is a comprehensive mobile trading platform with advanced AI-powered features. This roadmap tracks both completed achievements and planned enhancements across 18 major categories.

### Quick Stats
- **Completed Features**: 5 major categories (25+ items)
- **Planned Enhancements**: 18 categories (165+ items)
- **Open GitHub Issues**: 12 tracked features
- **Focus Areas**: Trading automation, social features, brokerage integrations, security

### Key Highlights
- ✅ **Completed**: Investor Groups, AI Trade Signals, Copy Trading, Futures Trading, Firestore Persistence
- 🔥 **In Progress**: Agentic Trading, Plaid/Schwab/Fidelity Integrations
- 🎯 **Upcoming**: Option Screener, Social Platform, Testing & Security Infrastructure

## Completed Features ✅

### Investor Groups
- [x] Create and manage investor groups
- [x] Public and private group options
- [x] Portfolio sharing within groups
- [x] Admin controls and member management
- [x] Invitation system with accept/decline workflow
- [x] Direct portfolio viewing for private group members
- [x] Member list with avatars and role indicators

### Trade Signals & AI Trading
- [x] Multi-indicator correlation system ([#32](https://github.com/CIInc/robinhood-options-mobile/issues/32))
- [x] Intraday signals - 15m, 1h, daily ([#48](https://github.com/CIInc/robinhood-options-mobile/issues/48))
- [x] Server-side filtering for trade signals ([#46](https://github.com/CIInc/robinhood-options-mobile/issues/46))
- [x] On-demand trade signal generation
### Copy Trading
- [x] Manual order execution for copied trades
- [x] Push notifications for copyable trades
- [x] Selection-based UI for batch copying
- [x] Quantity and amount limits

### Futures Trading
- [x] Futures accounts handling and UI integration ([#39](https://github.com/CIInc/robinhood-options-mobile/issues/39))
- [x] Live futures position enrichment with contract metadata
- [x] Real-time quote integration and Open P/L calculation

### Data Persistence
- [x] Firestore persisted portfolios, positions, and transactions ([#29](https://github.com/CIInc/robinhood-options-mobile/issues/29))

## Planned Enhancements 🚀

### Copy Trading
- [ ] **Auto-Execute**: Client-side automatic execution for flagged copy trades
- [ ] **Dashboard**: View history of all copied trades
- [ ] **Approval Workflow**: Review and approve auto-copied trades
- [ ] **Performance Tracking**: Track success rate of copied trades
- [ ] **Partial Copying**: Support copying a percentage of the original trade
- [ ] **Advanced Filtering**: Filter by symbol, time, or sector
- [ ] **Exit Strategy**: Automatically copy stop loss/take profit
- [ ] **Inverse Copying**: Contra-trading functionality

### Futures Positions
- [ ] **Margin & Risk**: SPAN-style margin metrics and risk layer
- [ ] **P&L Tracking**: Realized P&L and Day P&L using settlement price
- [ ] **Roll Assistant**: Alerts near expiration and auto-suggest roll strikes
- [ ] **Analytics**: Greeks, term structure, and volatility surfaces
- [ ] **Seasonality**: Volatility overlays and seasonal tendencies
- [ ] **Portfolio Risk**: Aggregated VaR and expected shortfall
- [ ] **Futures Detail Page**: Navigate to individual futures contract details
- [ ] **Futures Trading**: Place futures orders directly from the app
- [ ] **Futures Charts**: Historical price charts for futures contracts

### Investor Groups
- [ ] Group chat/messaging functionality
- [ ] Group performance analytics and leaderboards
- [ ] Activity feed for group trades
- [ ] Group-based watchlists

### Trade Signals & AI Trading
- [ ] Machine learning-based signal optimization
- [ ] Backtesting interface for strategies
- [ ] Custom indicator creation
- [ ] Strategy templates and presets
- [ ] Social signal sharing
- [ ] Performance tracking dashboard
- [ ] Paper trading mode
- [ ] **Agentic Trading**:
    - [ ] Implement `autoTrade` logic in `AgenticTradingProvider`
    - [ ] Add UI for configuring agentic trading parameters
    - [ ] Implement risk management controls for automated trading

### Social & Community
- [ ] Follow other users and their portfolios
- [ ] Comment system on shared portfolios
- [ ] Reddit integration for trending tickers
- [ ] Twitter sentiment tracking
- [ ] Community-driven trade ideas
- [ ] Portfolio comparison tools
- [ ] Social feed with trade notifications
- [ ] User reputation system
- [ ] Achievement badges
- [ ] **Follow Portfolio** ([#27](https://github.com/CIInc/robinhood-options-mobile/issues/27)): Follow other users' portfolios
- [ ] **Top Portfolios Leaderboard** ([#26](https://github.com/CIInc/robinhood-options-mobile/issues/26)): Showcase top-performing portfolios
- [ ] **RealizeAlpha Social Platform** ([#24](https://github.com/CIInc/robinhood-options-mobile/issues/24)): Enhanced social features

### Portfolio Management
- [ ] Advanced portfolio analytics (Sharpe ratio, alpha, beta)
- [ ] Risk exposure heatmaps
- [ ] Sector allocation visualization
- [ ] Dividend tracking and projections
- [ ] Tax loss harvesting suggestions
- [ ] Portfolio rebalancing recommendations
- [ ] Multi-account aggregation
- [ ] Import from other brokerages
- [ ] Export data to Excel/CSV
- [ ] **Automated DRIP with Threshold** ([#23](https://github.com/CIInc/robinhood-options-mobile/issues/23)): Dividend reinvestment when price reaches threshold

### Notifications & Alerts
- [ ] **Rich Notifications**: Charts and graphs in push notifications
- [ ] **History**: In-app notification logs
- [ ] **Channels**: Email and SMS notifications for critical signals
- [ ] **Customization**: Custom sounds and per-signal preferences
- [ ] **Grouping**: Group notifications by symbol or interval
- [ ] Custom price alerts with conditions
- [ ] Earnings calendar notifications
- [ ] Dividend payment reminders
- [ ] Options expiration alerts
- [ ] News alerts for holdings
- [ ] Unusual volume/price movement alerts
- [ ] Group activity notifications

### Trading Features
- [ ] Place stock orders directly
- [ ] Multi-leg options strategies
- [ ] Crypto trading integration
- [ ] Paper trading simulator
- [ ] Limit/stop-loss orders
- [ ] Trailing stop orders
- [ ] Advanced order types
- [ ] Order templates
- [ ] **Forex Trading**:
    - [ ] Implement `getForexQuote` and `getForexHistoricals`
    - [ ] Implement `getForexPositions`
    - [ ] Add Forex trading UI and order placement
- [ ] **Option Screener** ([#12](https://github.com/CIInc/robinhood-options-mobile/issues/12)): Advanced option filtering and screening

### Mobile Experience
- [ ] **Deep Linking**:
    - [ ] Implement `app_links` for seamless app opening
    - [ ] Handle login callbacks and referral links
- [ ] Offline mode for portfolio viewing
- [ ] Home screen widgets
- [ ] Siri/Google Assistant integration
- [ ] Dark mode customization
- [ ] Tablet-optimized layouts
- [ ] Landscape mode support
- [ ] Haptic feedback
- [ ] 3D Touch/Long press shortcuts

### Analytics & Insights
- [ ] **Generative AI Assistant**:
    - [ ] Integrate `firebase_ai` for natural language queries
    - [ ] Implement portfolio insights and summaries
    - [ ] Add chat interface for market questions
    - [ ] Implement `generateInvestmentThesis`
    - [ ] Implement `generateStockSummary`
    - [ ] Implement `generatePortfolioAnalysis`
    - [ ] Integrate `firebase_vertexai` (migration from `firebase_ai`)
- [ ] AI-powered price targets
- [ ] Fair value calculations
- [ ] Technical analysis tools
- [ ] Sentiment analysis dashboard
- [ ] Insider trading activity tracking
- [ ] Institutional ownership changes
- [ ] Options flow analysis
- [ ] Correlation analysis

### Education & Learning
- [ ] Investment strategy guides
- [ ] Options education modules
- [ ] Interactive tutorials
- [ ] Video explanations
- [ ] Glossary of terms
- [ ] Market hours info
- [ ] FAQ section
- [ ] Webinar integration

### Monetization
- [ ] **AdMob Integration**:
    - [ ] Enable banner ads for non-premium users (mobile only)
    - [ ] Implement interstitial ads for specific flows

### Data & Integration
- [ ] Multiple brokerage support
- [ ] Bank account linking
- [ ] Plaid integration expansion
- [ ] Real-time market data subscriptions
- [ ] Historical data exports
- [ ] API access for developers
- [ ] Webhook notifications
- [ ] Third-party app integrations
- [ ] **Yahoo Finance Integration**:
    - [ ] Implement `getChartData` for advanced charting
    - [ ] Implement `getNews` for real-time market news
    - [ ] Implement `getSummary` for stock details

### Brokerage Integration
- [ ] **Schwab Integration**:
    - [ ] Implement `getPortfolios`
    - [ ] Implement `getInstrumentBySymbol` and `getOptionInstrumentByIds`
    - [ ] Implement `getOptionMarketDataByIds`
    - [ ] Implement streaming services (dividends, lists, position orders)
    - [ ] Implement `refreshPositionQuote` and `getFundamentalsById`
- [ ] **Plaid Integration**:
    - [ ] Implement `getPortfolios` and `getNummusHoldings`
    - [ ] Implement instrument retrieval (`getInstrumentBySymbol`, `getInstrument`)
    - [ ] Implement option support (`getOptionChains`, `getOptionPositions`, `placeOptionsOrder`)
    - [ ] Implement market data (`getQuote`, `getHistoricals`, `getNews`)
    - [ ] Implement streaming services (`streamQuotes`, `streamOrders`)
- [ ] **Fidelity Integration** ([#33](https://github.com/CIInc/robinhood-options-mobile/issues/33)): Implement Fidelity API integration
- [ ] **Interactive Brokers Integration** ([#30](https://github.com/CIInc/robinhood-options-mobile/issues/30)): Implement Interactive Brokers API integration

### Technical Debt & UI Improvements
- [ ] **Web Support**: Introduce web banners across widgets (Home, Search, UserInfo, etc.)
- [ ] **Performance**: Optimize market data batch calls in `InstrumentOptionChainWidget`
- [ ] **State Management**: Fix `setState` usage in position widgets (`ForexPositions`, `OptionPositions`, `InstrumentPositions`)
- [ ] **Charts**: Fix viewport and selection issues in `IncomeTransactionsWidget`
- [ ] **Chart Value Display** ([#19](https://github.com/CIInc/robinhood-options-mobile/issues/19)): Combine $ and % values in bar charts
- [ ] **Animated Price Updates** ([#9](https://github.com/CIInc/robinhood-options-mobile/issues/9)): Animate price change labels on market data refresh

### Code Quality & Maintenance
- [ ] **Code Quality**:
    - [ ] Enable stricter linting rules in `analysis_options.yaml`
    - [ ] Resolve `deprecated_member_use` warnings (e.g., `marketValue` in `InstrumentPosition`)
    - [ ] Migrate deprecated API endpoints (e.g., Robinhood search)

### Testing & Quality Assurance
- [ ] **Testing**:
    - [ ] Increase unit test coverage for models and services
    - [ ] Add widget tests for critical UI components
    - [ ] Implement integration tests for trading flows
    - [ ] Add end-to-end tests for authentication
    - [ ] Set up continuous integration (CI) pipeline
    - [ ] Add performance testing for data-heavy widgets
    - [ ] Implement snapshot testing for UI consistency

### Security & Privacy
- [ ] **Security**:
    - [ ] Implement secure storage for OAuth tokens
    - [ ] Add biometric authentication support (Face ID/Touch ID/Fingerprint)
    - [ ] Implement certificate pinning for API calls
    - [ ] Add data encryption at rest
    - [ ] Security audit and penetration testing
    - [ ] Implement rate limiting for API calls
    - [ ] Add session timeout and auto-logout
    - [ ] Two-factor authentication (2FA) support

### Platform & Build
- [ ] **Apple Silicon Support** ([#11](https://github.com/CIInc/robinhood-options-mobile/issues/11)): Fix ITMS-90899 for Macs with Apple silicon
- [ ] **iOS Entitlements** ([#10](https://github.com/CIInc/robinhood-options-mobile/issues/10)): Fix ITMS-90078 missing potentially required entitlement

### Documentation
- [ ] **Documentation**:
    - [ ] API documentation for services
    - [ ] Architecture decision records (ADRs)
    - [ ] User guide and tutorials
    - [ ] Developer onboarding guide
    - [ ] Contribution guidelines
    - [ ] Code documentation and inline comments
    - [ ] Deployment and CI/CD documentation


