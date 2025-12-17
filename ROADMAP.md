
# Roadmap

This document outlines the planned features and enhancements for RealizeAlpha.

## Summary

**RealizeAlpha** is a comprehensive mobile trading platform with advanced AI-powered features. This roadmap tracks both completed achievements and planned enhancements across 18 major categories.

### Quick Stats
- **Completed Features**: 9 major categories (60+ items)
- **Planned Enhancements**: 15 categories (140+ items)
- **Open GitHub Issues**: 12 tracked features
- **Focus Areas**: Advanced trading strategies, brokerage integrations, security, social features

### Key Highlights
- ✅ **Completed**: Investor Groups, AI Trade Signals, Copy Trading, Futures Trading, Firestore Persistence, Portfolio Visualization, **Agentic Trading with Advanced Analytics**, **Backtesting Engine**, **Advanced Signal Filtering**, **Advanced Risk Controls**
- 🔥 **In Progress**: Copy Trading Auto-Execute
- 🎯 **Upcoming**: Strategy Templates, Partial Exits, Plaid/Schwab/Fidelity/Interactive Brokers Integrations

## Release Versions & Timeline

Mapping features to specific versions helps users anticipate releases and understand what's coming:

### v0.18.0 ✅ (Released Dec 13, 2025)
**Agentic Trading v1.3 - Paper Trading & Advanced Analytics**
- Paper Trading Mode (risk-free testing)
- 9 Advanced Analytics cards (Sharpe Ratio, Profit Factor, Expectancy, etc.)
- Trailing Stop Loss support
- Indicator Combination Analysis
- Performance filtering (paper vs real)

### v0.19.0 ✅ (Released Dec 15, 2025)
**Backtesting & Strategy Validation**
- ✅ Backtesting Interface (test strategies on historical data)
- ✅ 3-tab backtesting UI (Run, History, Templates)
- ✅ Interactive equity curve with trade markers
- ✅ Strategy Templates (save and reuse configurations)
- ✅ Performance metrics (Sharpe, drawdown, profit factor)
- ✅ Multiple time intervals (15m, 1h, 1d)
- ✅ Export and share backtest results

### v0.20.0 ✅ (Released Dec 16, 2025)
**Advanced Signal Filtering & 12-Indicator System**
- ✅ Advanced Trade Signal Filtering (Strength, 4-Way Filters)
- ✅ Dedicated Search Widgets (Screener, Presets)
- ✅ 12-Indicator System (Added VWAP, ADX, Williams %R)
- ✅ In-App Indicator Documentation
- ✅ Server-Side Filtering Performance Improvements

### v0.20.1 ✅ (Released Dec 16, 2025)
**Generative Actions & Instrument Charting**
- ✅ Generative Actions Widget (AI-driven actions and insights)
- ✅ Instrument Chart Widget (Enhanced charting capabilities)
- ✅ Instrument Widget Refactoring (Performance improvements)
- ✅ UI Consistency Improvements (Font sizes, bold styling)

### v0.20.2 ✅ (Released Dec 17, 2025)
**Watchlist Management & Risk Controls**
- ✅ Watchlist Management (Create, Add/Remove, UI enhancements)
- ✅ Advanced Risk Controls (Sector Limits, Correlation Checks, Volatility Filters, Drawdown Protection)
- ✅ Order Approval Workflow (Review pending orders)
- ✅ App Icon Badging (Notification indicators)
- ✅ Navigation Improvements (Bottom bar refactoring)

### v0.21.0 (Late December 2025)
**Copy Trading & Signal Optimization**
- Signal Optimization (ML-powered improvements)
- Custom Indicators (create your own indicators)
- UI improvements & bug fixes

### v0.22.0 (Q1 2026 - Early January)
**Copy Trading Enhancement**
- Auto-Execute for Copy Trading
- Partial Position Exits (take profit in stages)
- Time-Based Exits (auto-close after X hours/days)
- Copy Trade Performance Dashboard
- Approval workflow for automated copying

### v0.23.0 (Q1 2026 - Late January)
**Strategy Optimization & Custom Indicators**
- Signal Optimization (ML-powered improvements)
- Custom Indicators (create your own indicators)
- Strategy Templates library expansion
- Trade Approval Workflow
- Advanced backtesting filters

### v0.24.0 (Q2 2026 - Mid February)
**Schwab API Integration - Phase 1**
- Portfolio & position streaming from Schwab
- Market data & quotes integration
- Account aggregation with Robinhood
- Multi-brokerage account switching
- Firestore sync for Schwab positions
- Order history from Schwab

### v0.25.0 (Q2 2026 - Late March)
**Schwab API Integration - Phase 2 & Futures**
- Options order placement on Schwab
- Futures trading UI & order placement
- Futures charts & historical data
- Futures analytics (Greeks, term structure)
- Cross-brokerage order management
- Schwab market data quality improvements

### v0.26.0 (Q2 2026 - Late April)
**Fidelity API Integration & Multi-Leg Orders**
- Fidelity account integration
- Multi-leg options (spreads, complex strategies)
- Stock order placement (currently options-only)
- Advanced order types (trailing stops, conditional)
- Order Templates (save & reuse orders)
- Portfolio aggregation across 3 brokerages

### v0.27.0 (Q2-Q3 2026 - Late May)
**Crypto & Forex Trading**
- Crypto asset class support
- Forex trading (currency pairs)
- Real-time crypto quotes & charts
- Forex charting & analysis
- Multi-asset portfolio allocation
- Crypto/Forex analytics

### v0.28.0 (Q3 2026 - Mid June)
**AI Assistant & Advanced Analytics**
- Generative AI Assistant (natural language queries)
- AI-powered portfolio insights
- AI summaries & recommendations
- Advanced portfolio analytics (Sharpe, alpha, beta)
- Risk exposure heatmaps
- Dividend projection & tracking

### v0.29.0 (Q3 2026 - Late July)
**Investor Groups Enhancement & Chat**
- Group chat (real-time messaging)
- Activity feeds (member trade tracking)
- Performance leaderboards
- Shared watchlists
- Group settings & administration
- Real-time member notifications

### v0.30.0 (Q3 2026 - Late August)
**Real-Time Alerts & Monitoring**
- Custom price/volume/volatility alerts
- Rich push notifications with data
- Alert history & management
- Email/SMS alert channels
- Earnings calendar alerts
- Options expiration alerts
- Unusual activity detection

### v0.31.0 (Q3 2026 - Late September)
**Social Platform Foundation**
- Follow portfolios
- Portfolio comparison tools
- Comment system
- Top portfolios leaderboard
- User reputation system
- Achievement badges
- Social feed

### v0.32.0 (Q4 2026 - Late October)
**Security & Compliance**
- Biometric authentication (FaceID/TouchID)
- Two-factor authentication (2FA)
- End-to-end encryption
- Session management & auto-logout
- Compliance automation
- Security audit implementation
- Regulatory documentation

### v0.33.0 (Q4 2026 - Late November)
**Mobile Experience & Polish**
- Deep linking support
- Home screen widgets
- Offline mode
- Landscape mode support
- Tablet optimization
- Dark mode enhancements
- Performance optimizations

### v0.34.0 (Q4 2026 - Late December)
**Advanced Social & Community**
- Group analytics & insights
- Advanced search & filtering
- Community trade ideas voting
- Social sentiment analysis
- Influencer following features
- Community marketplace

### v0.35.0 (2027 Q1)
**Compliance & Regulatory**
- Full SEC/FINRA compliance
- Regulatory reporting (Form 3, etc.)
- Compliance audit trail
- Audit reports
- Legal documentation
- Multi-jurisdiction support

### Version Statistics
- **Current**: v0.20.0 (Released Dec 16, 2025)
- **Planned Releases**: 14+ versions through 2027
- **Features Per Release**: 5-8 per minor version
- **Release Cadence**: Monthly in 2026, bi-weekly starting 2027
- **Major Features**: Trading, Brokerages, Analytics, Social, Security

### Feature Maturity by Version
| Feature | v0.19 | v0.20 | v0.21 | v0.22 | v0.23 | v0.24 | v0.25 | v0.26+ |
|---------|-------|-------|-------|-------|-------|-------|-------|--------|
| Agentic Trading | ✅ Complete | ✅ Enhanced | Stable | Stable | Stable | Stable | Stable | Mature |
| Copy Trading | ✅ Manual | ✅ Manual | Approval | Auto | Auto | Auto | Auto | Mature |
| Backtesting | ✅ Complete | ✅ Stable | Enhanced | Enhanced | Stable | Stable | Stable | Mature |
| Multi-Brokerage | Robinhood | Robinhood | Robinhood | Robinhood | Schwab+RH | Schwab+RH | 3 Brokers | Mature |
| Analytics | ✅ Advanced | ✅ Filtered | Advanced | Advanced | Advanced | Advanced | AI+Adv | Mature |
| Futures | Enriched | Enriched | Enriched | Trading | Trading | Trading | Stable | Mature |
| Crypto/Forex | — | — | — | — | — | — | ✅ Launch | Mature |
| AI Assistant | — | — | — | — | — | — | — | ✅ Launch |
| Social | — | — | — | — | — | — | — | ✅ Launch |



### Trading Automation & Execution
- **Core Trading**: Stock Orders, Multi-Leg Options, Futures Trading, Crypto/Forex Trading
- **Automated Execution**: Agentic Trading (✅), Copy Trading Auto-Execute, Trade Approval Workflow (✅)
- **Advanced Orders**: Trailing Stops, Conditional Orders, Order Templates, Time-Based Exits
- **Risk Management**: Advanced Risk Controls (✅), Take Profit/Stop Loss (✅), Trailing Stops, Partial Position Exits

### Strategy Development & Optimization
- **Signal Analysis**: 12-Indicator System (✅), Signal Strength Filtering (✅), Custom Indicators, Signal Optimization
- **Strategy Management**: Strategy Templates (✅), Social Signal Sharing, Indicator Combo Performance (✅)
- **Execution Validation**: Backtesting Interface (✅), Trade Approval Workflow (✅), Paper Trading Mode (✅)

### Multi-Brokerage & Asset Coverage
- **Brokerage Integration**: Schwab, Fidelity, Plaid, Interactive Brokers
- **Asset Classes**: Stocks, Options, Futures (✅), Crypto, Forex, ETFs
- **Account Management**: Multi-Brokerage Support, Multi-Account Aggregation, Import/Export, Bank Linking

### Analytics & Performance Intelligence
- **Trade Analytics**: Trade Breakdown, Best/Worst Trades, Trade History, Performance by Symbol (✅)
- **Advanced Metrics**: Sharpe Ratio (✅), Profit Factor (✅), Expectancy (✅), Max Drawdown (✅)
- **Portfolio Analytics**: Advanced Portfolio Analytics, Risk Exposure Heatmaps, Benchmark Comparison
- **Performance Tracking**: Performance by Time of Day (✅), Performance by Indicator Combo (✅), Win Rate Analysis
- **Income Tracking**: Dividend Tracking, Dividend History, Income Chart, Income Interest List

### Real-Time Monitoring & Alerts
- **Notification System**: Custom Alerts, Rich Notifications, Notification History, Alert Customization
- **Alert Types**: Price Alerts, Volume Alerts, Earnings Alerts, Options Expiration Alerts, News Alerts
- **Real-Time Data**: WebSocket Infrastructure, Live Quotes (✅), Market Status Indicators (✅)

### AI & Insights
- **AI Assistant**: Generative AI Assistant, Natural Language Portfolio Queries, Investment Thesis Generation
- **AI Analysis**: AI Summaries, AI-powered Price Targets, Sentiment Analysis, Insider Tracking
- **ML Optimization**: Signal Optimization, Custom Indicator Learning, Strategy Backtesting with ML
- **Data Intelligence**: Correlation Analysis, Options Flow Analysis, Volatility Overlays

### Social & Community
- **Investor Groups** (✅): Group Management, Member Roles, Public/Private Groups, Portfolio Sharing (✅)
- **Group Features**: Group Chat, Activity Feed, Shared Watchlists, Performance Leaderboards
- **Social Platform**: Follow Portfolios, Portfolio Comparison, User Profiles, Reputation System
- **Engagement**: Achievement Badges, Comment System, Social Feed, Community Trade Ideas
- **Integrations**: Reddit Integration, Twitter Sentiment, Community Insights

### Security & Compliance
- **Authentication**: User Authentication (✅), Biometric Authentication, Two-Factor Authentication, OAuth2 Refresh (✅)
- **Data Protection**: End-to-End Encryption, Secure Token Storage, Session Management, Rate Limiting
- **Compliance**: SEC/Regulatory Compliance, Audit Logging, Compliance Automation, Legal Review
- **Security Testing**: Security Audit, Penetration Testing, Vulnerability Scanning

### Mobile Experience & Platform
- **Mobile Features**: Deep Linking, Home Screen Widgets, Offline Mode, Landscape Mode, Tablet Support
- **Voice & Gestures**: Siri/Google Assistant, Haptic Feedback, 3D Touch/Long Press
- **Platform Support**: iOS Entitlements (✅), Apple Silicon Support (✅), Android Optimization, Web Support
- **Theme Support**: Dark Mode Customization, Dynamic Colors, Accessibility Features

### Infrastructure & Developer Experience
- **Testing & Quality**: Unit Tests, Integration Tests, Widget Tests, Performance Testing, Snapshot Testing
- **CI/CD & Deployment**: CI/CD Pipeline, Automated Testing, Build Automation, Deployment Pipeline
- **Code Quality**: Linting Rules, Code Coverage, Performance Budgets, Technical Debt Management
- **Developer Tools**: API Documentation, Developer Guide, Architecture Records, Mock Services
- **Data & Integration**: Historical Data Exports, API Access, Webhook Notifications, Third-Party Integrations

### Capability Maturity by Q

| Capability | Q1 2026 | Q2 2026 | Q3 2026 | Q4 2026 | Status |
|------------|---------|---------|---------|---------|--------|
| Trading Automation | Advanced | Advanced | Advanced | Mature | 🟢 |
| Multi-Brokerage | Foundation | Advanced | Mature | Mature | 🟡 |
| Analytics | Advanced | Mature | Mature | Mature | 🟢 |
| Real-Time Monitoring | Foundation | Advanced | Advanced | Mature | 🟡 |
| AI & Insights | Foundation | Advanced | Mature | Mature | 🟡 |
| Social & Community | Foundation | Foundation | Advanced | Mature | 🔴 |
| Security & Compliance | Foundation | Foundation | Advanced | Mature | 🔴 |
| Mobile Experience | Advanced | Advanced | Mature | Mature | 🟢 |

## Feature Dependencies & Critical Path

Understanding dependencies helps with sprint planning and resource allocation. Below are key dependencies that affect the critical path:

### Critical Dependencies by Priority

**Priority 1 Dependencies:**
- **Backtesting Interface (✅)** ← Requires: Agentic Trading (✅), Trade Signals (✅), Historical Data Access
- **Signal Optimization** ← Requires: Backtesting Interface (✅), Performance Analytics
- **Custom Indicators** ← Requires: 12-Indicator System (✅), Signal Analysis Infrastructure
- **Trade Approval Workflow (✅)** ← Requires: Agentic Trading (✅), Order Execution Framework
- **Advanced Risk Controls (✅)** ← Requires: Agentic Trading (✅), Portfolio State Management (✅)
- **Copy Trading Auto-Execute** ← Requires: Copy Trading Manual (✅), WebSocket/Real-time Updates

**Priority 2 Dependencies:**
- **Schwab/Fidelity/Plaid/Interactive Brokers APIs** ← Requires: OAuth 2.0 Infrastructure, Multi-Brokerage Architecture
- **Multi-Brokerage Support** ← Requires: Account Aggregation, Data Normalization Layer
- **Crypto Trading** ← Requires: Multi-Brokerage Foundation, Asset Type Abstraction
- **Forex Trading** ← Requires: Multi-Brokerage Foundation, FX-Specific Price Data
- **Stock Orders** ← Requires: Basic Brokerage Integration (✅), Order Validation
- **Multi-Leg Options** ← Requires: Options Chain UI (✅), Order Composition UI

**Priority 3 Dependencies:**
- **Generative AI Assistant** ← Requires: Firebase AI Integration, Portfolio Data API, User Context Threading
- **Advanced Portfolio Analytics** ← Requires: Historical P&L Tracking, Multi-Position Calculations
- **Custom Alerts** ← Requires: WebSocket/Real-time Data, Notification Infrastructure (✅)
- **Risk Exposure Heatmaps** ← Requires: Advanced Analytics, Position Risk Calculations

**Priority 4 Dependencies:**
- **Group Chat** ← Requires: Investor Groups (✅), Real-time Messaging Infrastructure
- **Social Platform** ← Requires: Group Features (✅), User Profiles, Activity Tracking
- **Performance Leaderboards** ← Requires: Performance Analytics (✅), User Comparison Framework

**Priority 5 Dependencies:**
- **Biometric Authentication** ← Requires: Secure Storage (Flutter Secure Storage ✅), Auth Infrastructure
- **End-to-End Encryption** ← Requires: Security Foundation, Key Management, Encryption Library
- **CI/CD Pipeline** ← Requires: Testing Framework, Build Infrastructure, GitHub Actions Setup
- **Compliance Automation** ← Requires: Legal Framework, Regulatory Database, Audit Logging

### Blocking Issues & Critical Path

**Current Blockers:**
- None identified - all critical path items are unblocked

**Critical Path Timeline:**
1. **Q1 2026**: Complete Backtesting (enables Signal Optimization, Strategy Validation)
2. **Q2 2026**: Complete Brokerage Integrations (enables Multi-Asset Class Trading)
3. **Q3 2026**: Complete AI Assistant + Social Platform (enables Community Features)
4. **Q4 2026**: Security & Compliance (enables App Store Release)

### Dependency Legend
- ✅ = Already Completed
- → = Depends On / Requires
- Large blocks can start in parallel once dependencies are met

## Risks & Blockers

### Known Technical Challenges

**High Risk 🔴**

1. **Brokerage API Rate Limits & Complexity** (Impacts: Q2 2026 - Priority 2)
   - **Challenge**: Each brokerage (Schwab, Fidelity, Plaid, Interactive Brokers) has different API designs, rate limits, and data models
   - **Mitigation**: Build abstraction layer early, create adapter pattern for brokerage integration
   - **Timeline Impact**: Could add 2-3 weeks to integration schedule per brokerage
   - **Mitigation Owner**: Backend Engineering Team

2. **Real-Time Data Infrastructure** (Impacts: Q2-Q3 2026 - Priorities 2-3)
   - **Challenge**: WebSocket scalability for 1000+ concurrent users with real-time quote updates
   - **Mitigation**: Use Firebase Realtime Database or Firestore snapshot listeners; implement data throttling
   - **Timeline Impact**: Could delay Custom Alerts by 2-4 weeks if not architected correctly
   - **Mitigation Owner**: Backend + DevOps Team

3. **Machine Learning Signal Optimization** (Impacts: Q1 2026 - Priority 1, 5-8 weeks)
   - **Challenge**: Building effective ML models requires significant historical data and tuning
   - **Mitigation**: Start with simple statistical models; consider Firebase ML or TensorFlow Lite; A/B test
   - **Timeline Impact**: Could slip 2-3 weeks due to model training/validation cycles
   - **Mitigation Owner**: Data Science + AI Engineering Team

4. **Regulatory Compliance & Legal Review** (Impacts: Q4 2026 - Priority 5)
   - **Challenge**: Different jurisdictions have different requirements for trading apps; SEC/FINRA compliance
   - **Mitigation**: Engage legal team early; implement compliance audit logging; document all trades
   - **Timeline Impact**: Could delay Q4 release by 4-8 weeks if not started in Q3
   - **Mitigation Owner**: Legal + Compliance + Product Team

**Medium Risk 🟡**

5. **Firebase Quotas & Costs** (Impacts: Q2-Q4 2026 - All Priorities)
   - **Challenge**: Heavy use of Firestore, Functions, and Realtime could exceed Firebase quotas/costs
   - **Mitigation**: Implement caching layer; batch writes; monitor usage; optimize queries
   - **Timeline Impact**: Could require architecture refactoring (1-2 weeks) mid-project
   - **Mitigation Owner**: Backend Engineering + DevOps

6. **Cross-Platform Testing (iOS/Android/Web)** (Impacts: Q3-Q4 2026 - All Priorities)
   - **Challenge**: Ensuring features work correctly on 3+ platforms with platform-specific code
   - **Mitigation**: Establish CI/CD early; use feature flags for platform-specific features
   - **Timeline Impact**: Could add 1-2 weeks of testing per major feature
   - **Mitigation Owner**: QA + Mobile Engineering

7. **Generative AI Hallucinations** (Impacts: Q3 2026 - Priority 3)
   - **Challenge**: Firebase AI (Vertex AI) models may provide incorrect financial advice
   - **Mitigation**: Implement answer validation; add disclaimers; human review layer; extensive testing
   - **Timeline Impact**: Could add 2-3 weeks of validation/testing
   - **Mitigation Owner**: AI Engineering + Product + Legal

8. **Copy Trading Execution Latency** (Impacts: Q1 2026 - Priority 1)
   - **Challenge**: Copying trades in sub-second requires low-latency architecture
   - **Mitigation**: Use WebSocket for real-time signals; optimize order placement; local processing
   - **Timeline Impact**: Could add 1-2 weeks of performance optimization
   - **Mitigation Owner**: Backend + Mobile Engineering

**Low Risk 🟢**

9. **Third-Party API Changes** (Impacts: All Quarters)
   - **Challenge**: Brokerage/market data APIs may change without notice
   - **Mitigation**: Monitor API changelogs; implement feature detection; maintain multiple API versions
   - **Timeline Impact**: Could require quick fixes (1-3 days) but won't block main roadmap

10. **Team Scaling** (Impacts: Q2-Q4 2026)
    - **Challenge**: Growing from current team to support 4-5 parallel development streams
    - **Mitigation**: Hire early; document onboarding; establish code review process
    - **Timeline Impact**: New team members may reduce velocity by 20% for 2-4 weeks

### Resource Constraints

**Team Requirements by Priority:**
- **Q1 2026 (Priority 1)**: 3-4 backend engineers, 2-3 frontend engineers, 1 data scientist
- **Q2 2026 (Priority 2)**: 5-6 backend engineers (brokerage integrations), 3-4 frontend engineers
- **Q3 2026 (Priority 3-4)**: 4-5 backend engineers, 3-4 frontend engineers, 1 AI engineer, 1 DevOps
- **Q4 2026 (Priority 5)**: 3-4 backend engineers, 2-3 frontend engineers, 1 QA engineer, 1 security engineer

**Infrastructure Limitations:**
- Current Firebase tier may need upgrade for Priority 2-3 (estimated cost: $500-1500/month additional)
- CI/CD pipeline not yet established (needs implementation in Q1 or early Q2)
- No staging environment - consider setting up in Q1

### Mitigation Strategies

**Proactive Measures:**
1. ✅ Start legal/compliance review in Q4 2025 (before Q4 2026 deadline)
2. ✅ Build abstraction layer for brokerage integration in late Q1 2026
3. ✅ Establish performance budgets and monitoring in Q1 2026
4. ✅ Create feature flags early for A/B testing and gradual rollout
5. ✅ Set up comprehensive error tracking and logging NOW

**Fallback Plans:**
- If brokerage integration slips: Pivot to more comprehensive Robinhood API features (already available)
- If ML optimization delays: Launch with template-based strategies instead of ML
- If compliance delays Q4: Release to limited jurisdictions first (CA, NY); expand in 2027
- If Firebase costs spike: Migrate specific services to self-hosted alternatives

### Success Metrics & Monitoring

**Track These KPIs Monthly:**
- Development velocity (story points/sprint)
- Unresolved technical debt count
- Average PR review time
- Test coverage percentage (target: >80%)
- Firebase cost vs budget
- API response time P95
- App crash rate (target: <0.1%)

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
- [x] **Agentic Trading** ([#126](https://github.com/CIInc/robinhood-options-mobile/issues/126)):
    - [x] Fully autonomous execution with 5-minute periodic checks
    - [x] Trade-level TP/SL tracking with entry price accuracy
    - [x] Firebase persistence for cross-device continuity
    - [x] Emergency stop for immediate halt
    - [x] UI for configuring agentic trading parameters
    - [x] Risk management controls (daily limit, cooldown, loss threshold)
- [x] **Advanced Performance Analytics** ([#131](https://github.com/CIInc/robinhood-options-mobile/pull/131)):
    - [x] 9 comprehensive analytics cards (overview, P&L, breakdown, best/worst, advanced metrics, risk metrics, time-of-day, indicator combo, symbol)
    - [x] Sharpe Ratio calculation (risk-adjusted returns)
    - [x] Profit Factor analysis (gross profit / gross loss)
    - [x] Expectancy calculation (expected profit per trade)
    - [x] Max Drawdown tracking (peak-to-trough decline)
    - [x] Win/Loss streak monitoring
    - [x] Performance by time of day analysis
    - [x] Performance by indicator combination analysis
    - [x] Performance by symbol tracking (top 10)
- [x] **Paper Trading Mode** ([#131](https://github.com/CIInc/robinhood-options-mobile/pull/131)):
    - [x] Risk-free strategy testing with simulated execution
    - [x] Paper vs real trade filtering and comparison
    - [x] Visual indicators (PAPER badges throughout UI)
- [x] **Trailing Stop Loss** ([#131](https://github.com/CIInc/robinhood-options-mobile/pull/131)):
    - [x] Dynamic stop loss adjustment as profit increases
    - [x] Peak price tracking for each trade
    - [x] Configurable trailing distance

### Backtesting
- [x] **Backtesting Engine** ([#84](https://github.com/CIInc/robinhood-options-mobile/issues/84)):
    - [x] 3-tab interface (Run, History, Templates)
    - [x] Historical data testing (5 days to 5 years)
    - [x] Multiple time intervals (15m, 1h, 1d)
    - [x] All 9 technical indicators supported
    - [x] Advanced risk parameters (TP, SL, Trailing Stop)
    - [x] Comprehensive performance metrics (Sharpe, drawdown, profit factor)
    - [x] Interactive equity curve with trade markers
    - [x] 4-tab result page (Overview, Trades, Equity, Details)
    - [x] Template system to save/reuse configurations
    - [x] Export and share backtest results
    - [x] Real-time Firestore integration
    - [x] User backtest history (last 50 runs)
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

### Priority 1: Core Trading Features (Q1 2026 - Jan-Mar 2026)

**Target:** Enhance autonomous trading with backtesting, advanced risk controls, and improved copy trading

**Why This Priority Matters:**
Q1 2026 focuses on deepening the trading capability that differentiates RealizeAlpha. Backtesting is the foundation that enables users to validate strategies before risking capital—this is critical for user trust and retention. Copy trading automation transforms it from manual to truly autonomous, increasing engagement and feature stickiness. Advanced risk controls address the #1 user concern: "How do I manage risk?" These features directly impact user DAU and retention metrics. Strategic importance: **User Trust & Differentiation**

**Business Impact:**
- Backtesting reduces user churn (less losses = more engagement)
- Copy Trading Auto-Execute increases daily active users
- Advanced Risk Controls reduce support tickets
- Combined: Expected 40% increase in feature adoption

**Technical Complexity:** High (ML models, backtesting engine, complex calculations)
**User Impact:** Very High (core trading experience)
**Revenue Impact:** Medium (foundational for premium features)

#### Advanced Agentic Trading ([Tracking: #112](https://github.com/CIInc/robinhood-options-mobile/issues/112))
- [x] **Backtesting Interface**: Backtest strategies with historical data ([#84](https://github.com/CIInc/robinhood-options-mobile/issues/84)) - ✅ **Completed v0.19.0**
- [x] **Strategy Templates**: Save and reuse backtest configurations - ✅ **Completed v0.19.0**
- [x] **Trade Approval Workflow**: Review-before-execute mode for semi-automatic trading - ✅ **Completed v0.20.2**
- [x] **Advanced Risk Controls**: Sector limits, correlation checks, volatility filters, drawdown protection - ✅ **Completed v0.20.2**
- [ ] **Partial Position Exits**: Take profit in stages (e.g., 50% at +5%, 50% at +10%) - **Medium** (2-3 weeks)
- [ ] **Time-Based Exits**: Auto-close positions after X hours/days - **Small** (1-2 weeks)
- [ ] **Signal Optimization**: Machine learning-based signal optimization - **Large** (5-8 weeks)
- [ ] **Custom Indicators**: Custom indicator creation - **Large** (4-6 weeks)
- [ ] **Enhanced Strategy Templates**: Pre-built strategy library expansion - **Medium** (2-4 weeks)
- [ ] **Social Signal Sharing**: Share strategies with community - **Medium** (2-3 weeks)

#### Copy Trading Enhancements ([Tracking: #110](https://github.com/CIInc/robinhood-options-mobile/issues/110))
- [ ] **Auto-Execute**: Client-side automatic execution for flagged copy trades ([#66](https://github.com/CIInc/robinhood-options-mobile/issues/66)) - **Large** (3-4 weeks)
- [ ] **Dashboard**: View history of all copied trades ([#71](https://github.com/CIInc/robinhood-options-mobile/issues/71)) - **Small** (1-2 weeks)
- [ ] **Approval Workflow**: Review and approve auto-copied trades ([#97](https://github.com/CIInc/robinhood-options-mobile/issues/97)) - **Medium** (2-3 weeks)
- [ ] **Performance Tracking**: Track success rate of copied trades ([#98](https://github.com/CIInc/robinhood-options-mobile/issues/98)) - **Small** (1-2 weeks)
- [ ] **Partial Copying**: Support copying a percentage of the original trade ([#99](https://github.com/CIInc/robinhood-options-mobile/issues/99)) - **Small** (1 week)
- [ ] **Advanced Filtering**: Filter by symbol, time, or sector ([#101](https://github.com/CIInc/robinhood-options-mobile/issues/101)) - **Small** (1-2 weeks)
- [ ] **Exit Strategy**: Automatically copy stop loss/take profit ([#100](https://github.com/CIInc/robinhood-options-mobile/issues/100)) - **Medium** (2-3 weeks)
- [ ] **Inverse Copying**: Contra-trading functionality ([#110](https://github.com/CIInc/robinhood-options-mobile/issues/110)) - **Small** (1-2 weeks)

#### Futures Positions ([Tracking: #111](https://github.com/CIInc/robinhood-options-mobile/issues/111))
- [ ] **Margin & Risk**: SPAN-style margin metrics and risk layer ([#67](https://github.com/CIInc/robinhood-options-mobile/issues/67)) - **Large** (4-6 weeks)
- [ ] **P&L Tracking**: Realized P&L and Day P&L using settlement price ([#102](https://github.com/CIInc/robinhood-options-mobile/issues/102)) - **Medium** (2-3 weeks)
- [ ] **Roll Assistant**: Alerts near expiration and auto-suggest roll strikes ([#103](https://github.com/CIInc/robinhood-options-mobile/issues/103)) - **Medium** (2-3 weeks)
- [ ] **Futures Detail Page**: Navigate to individual futures contract details ([#104](https://github.com/CIInc/robinhood-options-mobile/issues/104)) - **Small** (1 week)
- [ ] **Futures Trading**: Place futures orders directly from the app ([#72](https://github.com/CIInc/robinhood-options-mobile/issues/72)) - **Large** (3-4 weeks)
- [ ] **Futures Charts**: Historical price charts for futures contracts ([#106](https://github.com/CIInc/robinhood-options-mobile/issues/106)) - **Medium** (2-3 weeks)
- [ ] **Analytics**: Greeks, term structure, and volatility surfaces ([#105](https://github.com/CIInc/robinhood-options-mobile/issues/105)) - **Large** (4-6 weeks)
- [ ] **Seasonality**: Volatility overlays and seasonal tendencies ([#111](https://github.com/CIInc/robinhood-options-mobile/issues/111)) - **Large** (3-4 weeks)
- [ ] **Portfolio Risk**: Aggregated VaR and expected shortfall ([#111](https://github.com/CIInc/robinhood-options-mobile/issues/111)) - **Large** (4-5 weeks)

### Priority 2: Brokerage Integration (Q2 2026 - Apr-Jun 2026)

**Target:** Expand to multiple brokerages and asset classes (stocks, crypto, forex)

**Why This Priority Matters:**
Q2 is the critical expansion phase. Currently locked to Robinhood, we're missing ~70% of market. Schwab/Fidelity/Plaid/Interactive Brokers integration opens enterprise users and wealth management firms. Multi-asset support (crypto/forex) addresses trending asset classes and younger users. This is also the highest engineering effort—starting early ensures Q2 delivery. Strategic importance: **Market Expansion & Revenue Growth**

**Business Impact:**
- Schwab integration: 5M+ potential users
- Fidelity integration: 10M+ potential users
- Crypto/Forex: Captures trending assets
- Expected TAM expansion: 300% increase

**Technical Complexity:** Very High (API differences, data normalization, account linking)
**User Impact:** Very High (enables Schwab/Fidelity users to adopt)
**Revenue Impact:** Very High (unlocks enterprise partnerships)

#### Brokerage Expansion
- [ ] **Plaid Integration**: Connect bank accounts for cash transfers ([#117](https://github.com/CIInc/robinhood-options-mobile/issues/117)) - **Large** (3-4 weeks)
- [ ] **Schwab API Integration**: Native Schwab brokerage support ([#120](https://github.com/CIInc/robinhood-options-mobile/issues/120)) - **Large** (4-6 weeks)
- [ ] **Fidelity API Integration**: Native Fidelity brokerage support ([#120](https://github.com/CIInc/robinhood-options-mobile/issues/120)) - **Large** (4-6 weeks)
- [ ] **Interactive Brokers Integration**: Native Interactive Brokers API support ([#30](https://github.com/CIInc/robinhood-options-mobile/issues/30)) - **Large** (4-6 weeks)
- [ ] **Multi-Brokerage**: Trade across multiple brokerage accounts - **Large** (3-4 weeks)
- [ ] **Crypto Trading**: Crypto trading integration ([#116](https://github.com/CIInc/robinhood-options-mobile/issues/116)) - **Large** (4-5 weeks)
- [ ] **Forex Trading** ([#116](https://github.com/CIInc/robinhood-options-mobile/issues/116)): - **Large** (4-5 weeks)
    - [ ] Implement `getForexQuote` and `getForexHistoricals`
    - [ ] Implement `getForexPositions`
    - [ ] Add Forex trading UI and order placement

#### Trading Orders & Execution
- [ ] **Stock Orders**: Place stock orders directly from the app ([#107](https://github.com/CIInc/robinhood-options-mobile/issues/107)) - **Medium** (2-3 weeks)
- [ ] **Multi-Leg Options**: Support for spreads and complex strategies ([#68](https://github.com/CIInc/robinhood-options-mobile/issues/68)) - **Large** (4-5 weeks)
- [ ] **Advanced Orders**: Trailing stops, conditional orders ([#108](https://github.com/CIInc/robinhood-options-mobile/issues/108)) - **Medium** (2-3 weeks)
- [ ] **Option Screener**: Advanced option filtering and screening ([#12](https://github.com/CIInc/robinhood-options-mobile/issues/12)) - **Large** (3-4 weeks)
- [ ] **Order Templates**: Save and reuse order templates - **Small** (1 week)

### Priority 3: Portfolio & Analysis (Q2-Q3 2026 - Apr-Sep 2026)

**Target:** Advanced analytics, AI insights, and comprehensive alert system

**Why This Priority Matters:**
Q2-Q3 shift focus from execution to intelligence. Advanced analytics + AI Assistant transforms RealizeAlpha into an AI-powered advisor, not just a broker. Users value insights above features (studies show 3x engagement with AI insights). Alerts are the #1 requested feature across brokerage apps. This priority targets user satisfaction and NPS improvement. Strategic importance: **User Intelligence & Satisfaction**

**Business Impact:**
- AI Assistant: 80% user engagement expected
- Advanced Analytics: 60% increase in session time
- Custom Alerts: Reduces support requests by 40%
- Combined NPS impact: +20 points

**Technical Complexity:** High (AI integration, real-time data, complex calculations)
**User Impact:** Very High (daily use features)
**Revenue Impact:** High (AI insights enable premium tier)

#### Portfolio Management ([Tracking: #114](https://github.com/CIInc/robinhood-options-mobile/issues/114))
- [ ] **Advanced Portfolio Analytics**: Sharpe ratio, alpha, beta calculations - **Medium** (2-3 weeks)
- [ ] **Risk Exposure Heatmaps**: Visualize portfolio risk distribution - **Medium** (2-3 weeks)
- [ ] **Dividend Tracking**: Track and project dividend income - **Small** (1-2 weeks)
- [ ] **Tax Loss Harvesting**: Tax optimization suggestions - **Medium** (2-3 weeks)
- [ ] **Portfolio Rebalancing**: Rebalancing recommendations - **Medium** (2-3 weeks)
- [ ] **Multi-Account Aggregation**: View all accounts together - **Medium** (2-3 weeks)
- [ ] **Import/Export**: Import from other brokerages, export to Excel/CSV - **Small** (1-2 weeks)
- [ ] **Automated DRIP with Threshold** ([#23](https://github.com/CIInc/robinhood-options-mobile/issues/23)): Dividend reinvestment at price thresholds - **Small** (1 week)
- [ ] **Benchmark Comparison** ([#18](https://github.com/CIInc/robinhood-options-mobile/issues/18)): Compare against market indices - **Small** (1 week)
- [ ] **Income View NAV** ([#20](https://github.com/CIInc/robinhood-options-mobile/issues/20)): Net Asset Value tracking - **Small** (1 week)
- [ ] **Income Chart** ([#17](https://github.com/CIInc/robinhood-options-mobile/issues/17)): Portfolio income visualization - **Small** (1 week)
- [ ] **Dividend History** ([#3](https://github.com/CIInc/robinhood-options-mobile/issues/3)): Historical dividend tracking - **Small** (1 week)
- [ ] **Income Interest List** ([#6](https://github.com/CIInc/robinhood-options-mobile/issues/6)): Interest payment tracking - **Small** (1 week)

#### Analytics & Insights ([Tracking: #118](https://github.com/CIInc/robinhood-options-mobile/issues/118))
- [ ] **Generative AI Assistant**: Natural language portfolio insights ([#74](https://github.com/CIInc/robinhood-options-mobile/issues/74))
    - [x] Integrate `firebase_ai` for natural language queries
    - [x] Implement portfolio insights and summaries (via GenerativeActionsWidget)
    - [ ] Add chat interface for market questions
    - [ ] Implement `generateInvestmentThesis`

#### Notifications & Alerts ([Tracking: #115](https://github.com/CIInc/robinhood-options-mobile/issues/115))
- [ ] **Rich Notifications**: Charts and data in push notifications ([#80](https://github.com/CIInc/robinhood-options-mobile/issues/80))
- [ ] **Custom Alerts**: Price, volume, and volatility alerts ([#81](https://github.com/CIInc/robinhood-options-mobile/issues/81))
- [ ] **Notification History**: In-app log of past notifications ([#82](https://github.com/CIInc/robinhood-options-mobile/issues/82))
- [ ] **Email/SMS Channels**: Critical signal notifications via multiple channels
- [ ] **Alert Customization**: Custom sounds and per-signal preferences
- [ ] **Earnings Calendar Notifications**: Earnings date alerts
- [ ] **Options Expiration Alerts**: Contract expiration reminders
- [ ] **News Alerts**: News notifications for holdings
- [ ] **Unusual Activity Alerts**: Unusual volume/price movement detection
- [ ] **Group Activity Notifications**: Investor group trade updates

### Priority 4: Investor Groups & Social (Q3 2026 - Jul-Sep 2026)

**Target:** Community features with chat, leaderboards, and social engagement

**Why This Priority Matters:**
Q3 launches the social/community ecosystem. Investor Groups already exist (✅), but lack engagement (chat, leaderboards, shared content). Social features are viral growth drivers—users share app with friends/family, creating network effects. Leaderboards gamify the experience, increasing daily engagement. This priority targets growth and retention. Strategic importance: **Viral Growth & Network Effects**

**Business Impact:**
- Group Chat: 5x message frequency expected
- Leaderboards: 3x daily active group members
- Social Sharing: 2-3x referral rate
- Expected MAU growth: 200%+ from social features

**Technical Complexity:** Medium (real-time messaging, social APIs)
**User Impact:** High (engagement features)
**Revenue Impact:** High (network effects drive adoption)

#### Investor Groups ([Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- [ ] **Group Chat**: Real-time messaging within groups ([#76](https://github.com/CIInc/robinhood-options-mobile/issues/76)) - **Large** (3-4 weeks)
- [ ] **Performance Analytics**: Group leaderboards and performance tracking ([#77](https://github.com/CIInc/robinhood-options-mobile/issues/77)) - **Medium** (2-3 weeks)
- [ ] **Activity Feed**: Real-time feed of member trades ([#78](https://github.com/CIInc/robinhood-options-mobile/issues/78)) - **Medium** (2-3 weeks)
- [ ] **Shared Watchlists**: Collaborative watchlists for groups ([#79](https://github.com/CIInc/robinhood-options-mobile/issues/79)) - **Small** (1-2 weeks)

#### Social & Community ([Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- [ ] **Follow Portfolios** ([#27](https://github.com/CIInc/robinhood-options-mobile/issues/27)): Follow other users' portfolios - **Small** (1-2 weeks)
- [ ] **Portfolio Comparison Tools**: Compare performance with other users - **Medium** (2-3 weeks)
- [ ] **Top Portfolios Leaderboard** ([#26](https://github.com/CIInc/robinhood-options-mobile/issues/26)): Showcase top-performing portfolios - **Medium** (2-3 weeks)
- [ ] **Comment System**: Comment on shared portfolios - **Small** (1-2 weeks)
- [ ] **Social Feed**: Trade notifications and portfolio updates - **Medium** (2-3 weeks)
- [ ] **User Reputation System**: Community credibility tracking - **Medium** (2-3 weeks)
- [ ] **Achievement Badges**: Gamification elements - **Small** (1 week)
- [ ] **Reddit Integration**: Trending ticker information - **Small** (1-2 weeks)
- [ ] **Twitter Sentiment**: Market sentiment tracking - **Medium** (2-3 weeks)
- [ ] **Community Trade Ideas**: Crowdsourced trade suggestions - **Small** (1-2 weeks)
- [ ] **RealizeAlpha Social Platform** ([#24](https://github.com/CIInc/robinhood-options-mobile/issues/24)): Comprehensive social features - **Large** (4-5 weeks)
- [ ] **Share Portfolio** ([#25](https://github.com/CIInc/robinhood-options-mobile/issues/25)): Share portfolio performance - **Small** (1 week)

### Priority 5: Mobile Experience & Infrastructure (Q3-Q4 2026 - Jul-Dec 2026)

**Target:** Polish UI/UX, enhance security, and prepare for app store releases

**Why This Priority Matters:**
Q3-Q4 transitions from feature development to polish and compliance. Security is non-negotiable for financial apps (prevents app store rejection + data breaches). Performance optimization is critical pre-launch (app store reviews focus on speed/stability). CI/CD infrastructure improves team velocity by 50%+. This priority enables production readiness and regulatory approval. Strategic importance: **Production Readiness & App Store Launch**

**Business Impact:**
- Security compliance: Mandatory for app store release
- Performance: 4.7+ star rating requires <0.1% crash rate
- CI/CD: 50% faster deployments
- Mobile polish: 3-5 star rating difference

**Technical Complexity:** High (security, compliance, infrastructure)
**User Impact:** Critical (required for launch)
**Revenue Impact:** Critical (app store release enables monetization)

#### Mobile Experience ([Tracking: #117](https://github.com/CIInc/robinhood-options-mobile/issues/117))
- [ ] **Deep Linking**: Handle deep links for navigation and sharing ([#85](https://github.com/CIInc/robinhood-options-mobile/issues/85)) - **Small** (1 week)
- [ ] **Home Screen Widgets**: iOS and Android home screen widgets ([#86](https://github.com/CIInc/robinhood-options-mobile/issues/86)) - **Medium** (2-3 weeks)
- [ ] **Offline Mode**: View cached data without internet ([#87](https://github.com/CIInc/robinhood-options-mobile/issues/87)) - **Medium** (2-3 weeks)
- [ ] **Siri/Google Assistant**: Voice command integration - **Medium** (2-3 weeks)
- [ ] **Dark Mode Customization**: Advanced theme controls - **Small** (1 week)
- [ ] **Tablet Optimization**: Optimized layouts for tablets - **Medium** (2-3 weeks)
- [ ] **Landscape Mode**: Full landscape support - **Medium** (2-3 weeks)
- [ ] **Haptic Feedback**: Vibration feedback for actions - **Small** (1 week)
- [ ] **3D Touch/Long Press**: Gesture shortcuts - **Small** (1 week)

#### Infrastructure & Security
- [ ] **Testing Framework**: Comprehensive unit and integration tests - **Large** (4-6 weeks)
- [ ] **Security Audit**: Third-party security assessment - **Medium** (2-3 weeks)
- [ ] **Biometric Authentication**: Face/fingerprint login - **Small** (1-2 weeks)
- [ ] **End-to-End Encryption**: Sensitive data encryption - **Medium** (2-3 weeks)
- [ ] **Compliance**: SEC/regulatory compliance automation - **Large** (4-6 weeks)
- [ ] **CI/CD Pipeline**: Automated testing and deployment - **Large** (3-4 weeks)
- [ ] **Performance Optimization**: App size and speed improvements - **Medium** (2-3 weeks)
- [ ] **Mock Brokerage Service** ([#5](https://github.com/CIInc/robinhood-options-mobile/issues/5)): Demo and testing service - **Medium** (2-3 weeks)
- [x] **Generative AI Assistant**: Natural language portfolio insights ([#74](https://github.com/CIInc/robinhood-options-mobile/issues/74)) - **Large** (4-5 weeks)
- [ ] **AI Summaries** ([#21](https://github.com/CIInc/robinhood-options-mobile/issues/21)): AI-driven portfolio summaries - **Medium** (2-3 weeks)
- [ ] AI-powered price targets
- [ ] Fair value calculations
- [ ] Technical analysis tools
- [ ] Sentiment analysis dashboard
- [ ] Insider trading activity tracking
- [ ] Institutional ownership changes
- [ ] Options flow analysis
- [ ] Correlation analysis

### Education & Learning ([Tracking: #119](https://github.com/CIInc/robinhood-options-mobile/issues/119))
- [ ] Investment strategy guides - **Medium** (2-3 weeks)
- [ ] Options education modules - **Medium** (2-3 weeks)
- [ ] Interactive tutorials - **Medium** (2-3 weeks)
- [ ] Video explanations - **Large** (3-4 weeks)
- [ ] Glossary of terms - **Small** (1 week)
- [ ] Market hours info - **Small** (1 week)
- [ ] FAQ section - **Small** (1 week)
- [ ] Webinar integration - **Large** (3-4 weeks)

### Monetization ([Tracking: #120](https://github.com/CIInc/robinhood-options-mobile/issues/120))
- [ ] **AdMob Integration**: - **Medium** (2-3 weeks)
    - [ ] Enable banner ads for non-premium users (mobile only)
    - [ ] Implement interstitial ads for specific flows

### Data & Integration ([Tracking: #121](https://github.com/CIInc/robinhood-options-mobile/issues/121))
- [ ] Multiple brokerage support - **Large** (4-5 weeks)
- [ ] Bank account linking - **Medium** (2-3 weeks)
- [ ] Plaid integration expansion - **Medium** (2-3 weeks)
- [ ] Real-time market data subscriptions - **Large** (3-4 weeks)
- [ ] Historical data exports - **Small** (1-2 weeks)
- [ ] API access for developers - **Large** (4-5 weeks)
- [ ] Webhook notifications - **Medium** (2-3 weeks)
- [ ] Third-party app integrations - **Large** (4-6 weeks)
- [ ] **Yahoo Finance Integration**: - **Large** (3-4 weeks)
    - [x] Implement `getChartData` for advanced charting
    - [ ] Implement `getNews` for real-time market news
    - [ ] Implement `getSummary` for stock details

### Brokerage Integration ([Tracking: #121](https://github.com/CIInc/robinhood-options-mobile/issues/121))
- [ ] **Schwab Integration**: - **Large** (4-6 weeks)
    - [ ] **Portfolio**: Portfolio retrieval and position streaming ([#91](https://github.com/CIInc/robinhood-options-mobile/issues/91))
    - [ ] **Market Data**: Quotes and fundamentals ([#93](https://github.com/CIInc/robinhood-options-mobile/issues/93))
    - [ ] Option order placement ([#122](https://github.com/CIInc/robinhood-options-mobile/issues/122))
- [ ] **Plaid Integration**: - **Large** (4-5 weeks)
    - [ ] **Options**: Full options support ([#92](https://github.com/CIInc/robinhood-options-mobile/issues/92))
    - [ ] Transaction history sync ([#123](https://github.com/CIInc/robinhood-options-mobile/issues/123))
- [ ] **Fidelity Integration** ([#33](https://github.com/CIInc/robinhood-options-mobile/issues/33)): Implement Fidelity API integration - **Large** (4-6 weeks)
- [ ] **Interactive Brokers Integration** ([#30](https://github.com/CIInc/robinhood-options-mobile/issues/30)): Implement Interactive Brokers API integration - **Large** (4-6 weeks)
- [ ] **Robinhood Crypto** ([#65](https://github.com/CIInc/robinhood-options-mobile/issues/65)): Crypto trading support - **Medium** (2-3 weeks)

### Technical Debt & UI Improvements ([Tracking: #124](https://github.com/CIInc/robinhood-options-mobile/issues/124))
- [ ] **Web Support**: Introduce web banners across widgets (Home, Search, UserInfo, etc.) - **Medium** (2-3 weeks)
- [ ] **Performance**: Optimize market data batch calls in `InstrumentOptionChainWidget` - **Small** (1-2 weeks)
- [ ] **State Management**: Fix `setState` usage in position widgets (`ForexPositions`, `OptionPositions`, `InstrumentPositions`) - **Medium** (2-3 weeks)
- [ ] **Charts**: Fix viewport and selection issues in `IncomeTransactionsWidget` - **Small** (1-2 weeks)
- [ ] **Chart Value Display** ([#19](https://github.com/CIInc/robinhood-options-mobile/issues/19)): Combine $ and % values in bar charts - **Small** (1 week)
- [ ] **Animated Price Updates** ([#9](https://github.com/CIInc/robinhood-options-mobile/issues/9)): Animate price change labels on market data refresh - **Small** (1 week)
- [ ] **Synchronized Scroll** ([#7](https://github.com/CIInc/robinhood-options-mobile/issues/7)): Synchronize scrolling of portfolio position rows - **Small** (1 week)

### Code Quality & Maintenance ([Tracking: #125](https://github.com/CIInc/robinhood-options-mobile/issues/125))
- [ ] **Code Quality**: - **Medium** (2-3 weeks)
    - [ ] Enable stricter linting rules in `analysis_options.yaml`
    - [ ] Resolve `deprecated_member_use` warnings (e.g., `marketValue` in `InstrumentPosition`)
    - [ ] Migrate deprecated API endpoints (e.g., Robinhood search)

### Testing & Quality Assurance
- [ ] **Testing**: - **Large** (6-8 weeks)
    - [ ] Increase unit test coverage for models and services
    - [ ] **Integration Tests**: End-to-end testing of critical flows ([#75](https://github.com/CIInc/robinhood-options-mobile/issues/75))
    - [ ] **Widget Tests**: Comprehensive UI component testing ([#90](https://github.com/CIInc/robinhood-options-mobile/issues/90))
    - [ ] **CI/CD Pipeline**: Automated build and test pipeline ([#70](https://github.com/CIInc/robinhood-options-mobile/issues/70))
    - [ ] Add performance testing for data-heavy widgets
    - [ ] Implement snapshot testing for UI consistency

### Security & Privacy
- [ ] **Security**: - **Large** (6-8 weeks)
    - [ ] **Biometric Auth**: FaceID/TouchID integration ([#69](https://github.com/CIInc/robinhood-options-mobile/issues/69))
    - [x] **Secure Storage**: Secure storage for OAuth tokens ([#88](https://github.com/CIInc/robinhood-options-mobile/issues/88))
    - [ ] **2FA**: Two-factor authentication support ([#89](https://github.com/CIInc/robinhood-options-mobile/issues/89))
    - [ ] Implement certificate pinning for API calls
    - [ ] Add data encryption at rest
    - [ ] Security audit and penetration testing
    - [ ] Implement rate limiting for API calls
- [ ] Add session timeout and auto-logout - **Small** (1 week)
- [x] **User Authentication** ([#22](https://github.com/CIInc/robinhood-options-mobile/issues/22)): Robust user authentication system - **Medium** (2-3 weeks)
- [x] **OAuth2 Refresh** ([#14](https://github.com/CIInc/robinhood-options-mobile/issues/14)): Handle token refresh seamlessly - **Small** (1 week)

### Platform & Build
- [x] **Apple Silicon Support** ([#11](https://github.com/CIInc/robinhood-options-mobile/issues/11)): Fix ITMS-90899 for Macs with Apple silicon - **Small** (1 week)
- [x] **iOS Entitlements** ([#10](https://github.com/CIInc/robinhood-options-mobile/issues/10)): Fix ITMS-90078 missing potentially required entitlement - **Small** (1 week)

### Documentation
- [ ] **API Documentation**: Comprehensive API reference ([#94](https://github.com/CIInc/robinhood-options-mobile/issues/94)) - **Medium** (2-3 weeks)
- [ ] **Developer Guide**: Onboarding guide for new contributors ([#95](https://github.com/CIInc/robinhood-options-mobile/issues/95)) - **Medium** (2-3 weeks)
- [ ] **ADRs**: Architecture Decision Records ([#96](https://github.com/CIInc/robinhood-options-mobile/issues/96)) - **Small** (1-2 weeks)

