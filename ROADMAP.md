
# Roadmap

This document outlines the planned features and enhancements for RealizeAlpha.

## Summary

**RealizeAlpha** is a comprehensive mobile trading platform with advanced AI-powered features. This roadmap tracks both completed achievements and planned enhancements across 18 major categories.

### Quick Stats
- **Completed Features**: 6 major categories (30+ items)
- **Planned Enhancements**: 18 categories (165+ items)
- **Open GitHub Issues**: 12 tracked features
- **Focus Areas**: Trading automation, social features, brokerage integrations, security

### Key Highlights
- ✅ **Completed**: Investor Groups, AI Trade Signals, Copy Trading, Futures Trading, Firestore Persistence, Portfolio Visualization
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

### Portfolio Visualization
- [x] Portfolio allocation pie charts (Asset, Position, Sector, Industry) ([#127](https://github.com/CIInc/robinhood-options-mobile/pull/127))
- [x] Interactive carousel with page indicators
- [x] Bidirectional highlighting between chart slices and legend entries
- [x] Top 5 holdings display with percentage labels
- [x] "Others" grouping for remaining positions

## Planned Enhancements 🚀

### Copy Trading ([Tracking: #110](https://github.com/CIInc/robinhood-options-mobile/issues/110))
- [ ] **Auto-Execute**: Client-side automatic execution for flagged copy trades ([#66](https://github.com/CIInc/robinhood-options-mobile/issues/66))
- [ ] **Dashboard**: View history of all copied trades ([#71](https://github.com/CIInc/robinhood-options-mobile/issues/71))
- [ ] **Approval Workflow**: Review and approve auto-copied trades ([#97](https://github.com/CIInc/robinhood-options-mobile/issues/97))
- [ ] **Performance Tracking**: Track success rate of copied trades ([#98](https://github.com/CIInc/robinhood-options-mobile/issues/98))
- [ ] **Partial Copying**: Support copying a percentage of the original trade ([#99](https://github.com/CIInc/robinhood-options-mobile/issues/99))
- [ ] **Advanced Filtering**: Filter by symbol, time, or sector ([#101](https://github.com/CIInc/robinhood-options-mobile/issues/101))
- [ ] **Exit Strategy**: Automatically copy stop loss/take profit ([#100](https://github.com/CIInc/robinhood-options-mobile/issues/100))
- [ ] **Inverse Copying**: Contra-trading functionality ([#110](https://github.com/CIInc/robinhood-options-mobile/issues/110))

### Futures Positions ([Tracking: #111](https://github.com/CIInc/robinhood-options-mobile/issues/111))
- [ ] **Margin & Risk**: SPAN-style margin metrics and risk layer ([#67](https://github.com/CIInc/robinhood-options-mobile/issues/67))
- [ ] **P&L Tracking**: Realized P&L and Day P&L using settlement price ([#102](https://github.com/CIInc/robinhood-options-mobile/issues/102))
- [ ] **Roll Assistant**: Alerts near expiration and auto-suggest roll strikes ([#103](https://github.com/CIInc/robinhood-options-mobile/issues/103))
- [ ] **Analytics**: Greeks, term structure, and volatility surfaces ([#105](https://github.com/CIInc/robinhood-options-mobile/issues/105))
- [ ] **Seasonality**: Volatility overlays and seasonal tendencies ([#111](https://github.com/CIInc/robinhood-options-mobile/issues/111))
- [ ] **Portfolio Risk**: Aggregated VaR and expected shortfall ([#111](https://github.com/CIInc/robinhood-options-mobile/issues/111))
- [ ] **Futures Detail Page**: Navigate to individual futures contract details ([#104](https://github.com/CIInc/robinhood-options-mobile/issues/104))
- [ ] **Futures Trading**: Place futures orders directly from the app ([#72](https://github.com/CIInc/robinhood-options-mobile/issues/72))
- [ ] **Futures Charts**: Historical price charts for futures contracts ([#106](https://github.com/CIInc/robinhood-options-mobile/issues/106))

### Investor Groups ([Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- [ ] **Group Chat**: Real-time messaging within groups ([#76](https://github.com/CIInc/robinhood-options-mobile/issues/76))
- [ ] **Performance Analytics**: Group leaderboards and performance tracking ([#77](https://github.com/CIInc/robinhood-options-mobile/issues/77))
- [ ] **Activity Feed**: Real-time feed of member trades ([#78](https://github.com/CIInc/robinhood-options-mobile/issues/78))
- [ ] **Shared Watchlists**: Collaborative watchlists for groups ([#79](https://github.com/CIInc/robinhood-options-mobile/issues/79))

### Trade Signals & AI Trading ([Tracking: #112](https://github.com/CIInc/robinhood-options-mobile/issues/112))
- [ ] **Signal Optimization**: Machine learning-based signal optimization ([#112](https://github.com/CIInc/robinhood-options-mobile/issues/112))
- [ ] **Backtesting Interface**: Backtesting interface for strategies ([#84](https://github.com/CIInc/robinhood-options-mobile/issues/84))
- [ ] **Custom Indicators**: Custom indicator creation ([#112](https://github.com/CIInc/robinhood-options-mobile/issues/112))
- [ ] **Strategy Templates**: Strategy templates and presets ([#112](https://github.com/CIInc/robinhood-options-mobile/issues/112))
- [ ] **Social Signal Sharing**: Social signal sharing ([#112](https://github.com/CIInc/robinhood-options-mobile/issues/112))
- [ ] **Performance Dashboard**: Performance tracking dashboard ([#112](https://github.com/CIInc/robinhood-options-mobile/issues/112))
- [ ] **Paper Trading Mode**: Paper trading mode ([#73](https://github.com/CIInc/robinhood-options-mobile/issues/73))
- [ ] **Agentic Trading** ([#126](https://github.com/CIInc/robinhood-options-mobile/issues/126)):
    - [ ] Implement `autoTrade` logic in `AgenticTradingProvider`
    - [ ] Add UI for configuring agentic trading parameters
    - [ ] Implement risk management controls for automated trading

### Social & Community ([Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
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
- [ ] **Share Portfolio** ([#25](https://github.com/CIInc/robinhood-options-mobile/issues/25)): Share portfolio performance with others

### Portfolio Management ([Tracking: #114](https://github.com/CIInc/robinhood-options-mobile/issues/114))
- [ ] Advanced portfolio analytics (Sharpe ratio, alpha, beta)
- [ ] Risk exposure heatmaps
- [ ] Dividend tracking and projections
- [ ] Tax loss harvesting suggestions
- [ ] Portfolio rebalancing recommendations
- [ ] Multi-account aggregation
- [ ] Import from other brokerages
- [ ] Export data to Excel/CSV
- [ ] **Automated DRIP with Threshold** ([#23](https://github.com/CIInc/robinhood-options-mobile/issues/23)): Dividend reinvestment when price reaches threshold
- [ ] **Stock Screener** ([#13](https://github.com/CIInc/robinhood-options-mobile/issues/13)): Filter stocks by technical and fundamental criteria
- [ ] **Income Chart** ([#17](https://github.com/CIInc/robinhood-options-mobile/issues/17)): Visualize portfolio income over time
- [ ] **Income Interest List** ([#6](https://github.com/CIInc/robinhood-options-mobile/issues/6)): Track interest payments
- [ ] **Dividend History** ([#3](https://github.com/CIInc/robinhood-options-mobile/issues/3)): View historical dividend payments
- [ ] **Benchmark Comparison** ([#18](https://github.com/CIInc/robinhood-options-mobile/issues/18)): Compare performance against market indices
- [ ] **Income View NAV** ([#20](https://github.com/CIInc/robinhood-options-mobile/issues/20)): Net Asset Value tracking

### Notifications & Alerts ([Tracking: #115](https://github.com/CIInc/robinhood-options-mobile/issues/115))
- [ ] **Rich Notifications**: Charts and data in push notifications ([#80](https://github.com/CIInc/robinhood-options-mobile/issues/80))
- [ ] **Custom Alerts**: Price, volume, and volatility alerts ([#81](https://github.com/CIInc/robinhood-options-mobile/issues/81))
- [ ] **Notification History**: In-app log of past notifications ([#82](https://github.com/CIInc/robinhood-options-mobile/issues/82))
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

### Trading Features ([Tracking: #116](https://github.com/CIInc/robinhood-options-mobile/issues/116))
- [ ] **Stock Orders**: Place stock orders directly from the app ([#107](https://github.com/CIInc/robinhood-options-mobile/issues/107))
- [ ] **Multi-Leg Options**: Support for spreads and complex strategies ([#68](https://github.com/CIInc/robinhood-options-mobile/issues/68))
- [ ] **Crypto Trading**: Crypto trading integration ([#116](https://github.com/CIInc/robinhood-options-mobile/issues/116))
- [ ] **Paper Trading**: Risk-free simulator for testing strategies ([#73](https://github.com/CIInc/robinhood-options-mobile/issues/73))
- [ ] **Advanced Orders**: Trailing stops, conditional orders ([#108](https://github.com/CIInc/robinhood-options-mobile/issues/108))
- [ ] Order templates ([#116](https://github.com/CIInc/robinhood-options-mobile/issues/116))
- [ ] **Forex Trading** ([#116](https://github.com/CIInc/robinhood-options-mobile/issues/116)):
    - [ ] Implement `getForexQuote` and `getForexHistoricals`
    - [ ] Implement `getForexPositions`
    - [ ] Add Forex trading UI and order placement
- [ ] **Option Screener** ([#12](https://github.com/CIInc/robinhood-options-mobile/issues/12)): Advanced option filtering and screening
- [ ] **Mock Brokerage Service** ([#5](https://github.com/CIInc/robinhood-options-mobile/issues/5)): Mock service for demos and testing

### Mobile Experience ([Tracking: #117](https://github.com/CIInc/robinhood-options-mobile/issues/117))
- [ ] **Deep Linking**: Handle deep links for navigation and sharing ([#85](https://github.com/CIInc/robinhood-options-mobile/issues/85))
- [ ] **Home Screen Widgets**: iOS and Android widgets for quick info ([#86](https://github.com/CIInc/robinhood-options-mobile/issues/86))
- [ ] **Offline Mode**: View cached data without internet connection ([#87](https://github.com/CIInc/robinhood-options-mobile/issues/87))
- [ ] Siri/Google Assistant integration
- [ ] Dark mode customization
- [ ] Tablet-optimized layouts
- [ ] Landscape mode support
- [ ] Haptic feedback
- [ ] 3D Touch/Long press shortcuts

### Analytics & Insights ([Tracking: #118](https://github.com/CIInc/robinhood-options-mobile/issues/118))
- [ ] **Generative AI Assistant**: Natural language portfolio insights ([#74](https://github.com/CIInc/robinhood-options-mobile/issues/74))
    - [ ] Integrate `firebase_ai` for natural language queries
    - [ ] Implement portfolio insights and summaries
    - [ ] Add chat interface for market questions
    - [ ] Implement `generateInvestmentThesis`
    - [ ] Implement `generateStockSummary`
    - [ ] Implement `generatePortfolioAnalysis`
    - [ ] Integrate `firebase_vertexai` (migration from `firebase_ai`)
- [ ] **AI Summaries** ([#21](https://github.com/CIInc/robinhood-options-mobile/issues/21)): AI-driven portfolio summaries
- [ ] AI-powered price targets
- [ ] Fair value calculations
- [ ] Technical analysis tools
- [ ] Sentiment analysis dashboard
- [ ] Insider trading activity tracking
- [ ] Institutional ownership changes
- [ ] Options flow analysis
- [ ] Correlation analysis

### Education & Learning ([Tracking: #119](https://github.com/CIInc/robinhood-options-mobile/issues/119))
- [ ] Investment strategy guides
- [ ] Options education modules
- [ ] Interactive tutorials
- [ ] Video explanations
- [ ] Glossary of terms
- [ ] Market hours info
- [ ] FAQ section
- [ ] Webinar integration

### Monetization ([Tracking: #120](https://github.com/CIInc/robinhood-options-mobile/issues/120))
- [ ] **AdMob Integration**:
    - [ ] Enable banner ads for non-premium users (mobile only)
    - [ ] Implement interstitial ads for specific flows

### Data & Integration ([Tracking: #121](https://github.com/CIInc/robinhood-options-mobile/issues/121))
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

### Brokerage Integration ([Tracking: #121](https://github.com/CIInc/robinhood-options-mobile/issues/121))
- [ ] **Schwab Integration**:
    - [ ] **Portfolio**: Portfolio retrieval and position streaming ([#91](https://github.com/CIInc/robinhood-options-mobile/issues/91))
    - [ ] **Market Data**: Quotes and fundamentals ([#93](https://github.com/CIInc/robinhood-options-mobile/issues/93))
    - [ ] Option order placement ([#122](https://github.com/CIInc/robinhood-options-mobile/issues/122))
- [ ] **Plaid Integration**:
    - [ ] **Options**: Full options support ([#92](https://github.com/CIInc/robinhood-options-mobile/issues/92))
    - [ ] Transaction history sync ([#123](https://github.com/CIInc/robinhood-options-mobile/issues/123))
- [ ] **Fidelity Integration** ([#33](https://github.com/CIInc/robinhood-options-mobile/issues/33)): Implement Fidelity API integration
- [ ] **Interactive Brokers Integration** ([#30](https://github.com/CIInc/robinhood-options-mobile/issues/30)): Implement Interactive Brokers API integration
- [ ] **Robinhood Crypto** ([#65](https://github.com/CIInc/robinhood-options-mobile/issues/65)): Crypto trading support

### Technical Debt & UI Improvements ([Tracking: #124](https://github.com/CIInc/robinhood-options-mobile/issues/124))
- [ ] **Web Support**: Introduce web banners across widgets (Home, Search, UserInfo, etc.)
- [ ] **Performance**: Optimize market data batch calls in `InstrumentOptionChainWidget`
- [ ] **State Management**: Fix `setState` usage in position widgets (`ForexPositions`, `OptionPositions`, `InstrumentPositions`)
- [ ] **Charts**: Fix viewport and selection issues in `IncomeTransactionsWidget`
- [ ] **Chart Value Display** ([#19](https://github.com/CIInc/robinhood-options-mobile/issues/19)): Combine $ and % values in bar charts
- [ ] **Animated Price Updates** ([#9](https://github.com/CIInc/robinhood-options-mobile/issues/9)): Animate price change labels on market data refresh
- [ ] **Synchronized Scroll** ([#7](https://github.com/CIInc/robinhood-options-mobile/issues/7)): Synchronize scrolling of portfolio position rows

### Code Quality & Maintenance ([Tracking: #125](https://github.com/CIInc/robinhood-options-mobile/issues/125))
- [ ] **Code Quality**:
    - [ ] Enable stricter linting rules in `analysis_options.yaml`
    - [ ] Resolve `deprecated_member_use` warnings (e.g., `marketValue` in `InstrumentPosition`)
    - [ ] Migrate deprecated API endpoints (e.g., Robinhood search)

### Testing & Quality Assurance
- [ ] **Testing**:
    - [ ] Increase unit test coverage for models and services
    - [ ] **Integration Tests**: End-to-end testing of critical flows ([#75](https://github.com/CIInc/robinhood-options-mobile/issues/75))
    - [ ] **Widget Tests**: Comprehensive UI component testing ([#90](https://github.com/CIInc/robinhood-options-mobile/issues/90))
    - [ ] **CI/CD Pipeline**: Automated build and test pipeline ([#70](https://github.com/CIInc/robinhood-options-mobile/issues/70))
    - [ ] Add performance testing for data-heavy widgets
    - [ ] Implement snapshot testing for UI consistency

### Security & Privacy
- [ ] **Security**:
    - [ ] **Biometric Auth**: FaceID/TouchID integration ([#69](https://github.com/CIInc/robinhood-options-mobile/issues/69))
    - [ ] **Secure Storage**: Secure storage for OAuth tokens ([#88](https://github.com/CIInc/robinhood-options-mobile/issues/88))
    - [ ] **2FA**: Two-factor authentication support ([#89](https://github.com/CIInc/robinhood-options-mobile/issues/89))
    - [ ] Implement certificate pinning for API calls
    - [ ] Add data encryption at rest
    - [ ] Security audit and penetration testing
    - [ ] Implement rate limiting for API calls
- [ ] Add session timeout and auto-logout
- [ ] **User Authentication** ([#22](https://github.com/CIInc/robinhood-options-mobile/issues/22)): Robust user authentication system
- [ ] **OAuth2 Refresh** ([#14](https://github.com/CIInc/robinhood-options-mobile/issues/14)): Handle token refresh seamlessly

### Platform & Build
- [ ] **Apple Silicon Support** ([#11](https://github.com/CIInc/robinhood-options-mobile/issues/11)): Fix ITMS-90899 for Macs with Apple silicon
- [ ] **iOS Entitlements** ([#10](https://github.com/CIInc/robinhood-options-mobile/issues/10)): Fix ITMS-90078 missing potentially required entitlement

### Documentation
- [ ] **API Documentation**: Comprehensive API reference ([#94](https://github.com/CIInc/robinhood-options-mobile/issues/94))
- [ ] **Developer Guide**: Onboarding guide for new contributors ([#95](https://github.com/CIInc/robinhood-options-mobile/issues/95))
- [ ] **ADRs**: Architecture Decision Records ([#96](https://github.com/CIInc/robinhood-options-mobile/issues/96))

