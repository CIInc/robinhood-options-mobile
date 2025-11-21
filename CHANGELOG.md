# Changelog

All notable changes to this project will be documented in this file.

## [0.16.0] - 2025-11-21

### Added
- **Copy Trading (Investor Groups):** Manual execution of copied trades for stocks/ETFs and options with immediate brokerage order placement.
  - Per-member `CopyTradeSettings` (enable, target user, autoExecute flag, max quantity/amount, price override placeholder).
  - UI widgets: `CopyTradeSettingsWidget`, `CopyTradeButtonWidget` integrated into member portfolio views.
  - Backend Firebase Functions triggers (`functions/src/copy-trading.ts`) for instrument & option orders creating audit trail documents in `copy_trades` collection.
  - Push notifications (FCM) to copying members including symbol, side, quantity, order type.
- **Audit Trail:** Firestore `copy_trades` documents capture original vs copied quantities, execution status & timestamps for compliance.
- **Futures Positions:** Added real-time futures position enrichment with contract & product metadata (symbol root, expiration, currency, multiplier) and live quote integration (last trade price). Displays Open P&L per contract in UI using pricing multiplier.

### Changed
- Documentation expanded for Copy Trading workflow, limitations, and future roadmap.
- Investor Groups documentation cross-referenced with Copy Trading features.

### Fixed
- Clarified prior limitation: manual copy trade execution now implemented (previously placeholder).

### Technical Details
- **Data Model:** `CopyTradeSettings` stored in `InvestorGroup.memberCopyTradeSettings` map keyed by userId.
- **Functions:** Triggers differentiate instrument vs option orders; apply limits (quantity, amount) and option contract multiplier (100 shares per contract).
- **Notifications:** High-priority FCM multicast with graceful failure logging.
- **Security:** Firestore rules restrict creation to backend functions; users can read their own related records.
- **Futures Enrichment:** Service layer aggregates positions, fetches contract/product metadata (arsenal), and quotes (marketdata futures). Computed field `openPnlCalc = (lastTradePrice - avgTradePrice) * quantity * multiplier` attached per position. No realized or day P&L yet.

### Documentation
- Added/Updated `docs/copy-trading.md` with settings, triggers, notifications, limitations & roadmap.
- Updated README features list to include Copy Trading.
- Updated copilot instructions with architecture pointers for Copy Trading.
- Added `docs/futures.md` detailing enrichment sources, Open P&L formula, limitations, and roadmap. README and docs index updated with Futures feature bullet.

### Future (Planned)
- Auto-execute (client-side secure workflow), dashboard/history, approval step, advanced filtering (symbol/time), performance analytics.
- Futures roadmap: margin impact, realized P&L tracking, contract roll detection, risk metrics (VAR), day P&L derivation from settlement price, Greeks & term structure analytics.

## [0.15.0] - 2025-11-18

### Added
- **Investor Groups** - Complete collaborative portfolio sharing system:
  - Create public or private investor groups with admin controls
  - Join and leave groups with comprehensive member management
  - View group details, member lists with avatars, and shared portfolios
  - **Member Management & Invitations:**
    - Admin interface with 3-tab layout (Members, Pending, Invite)
    - Real-time user search to find and invite users
    - Send, accept, decline, and cancel invitations
    - Promote/demote admin roles and remove members
    - Dedicated "Invitations" tab for pending invitations
  - **Private Group Portfolio Viewing:**
    - Tap any member in private group to view their shared portfolio
    - Navigation to SharedPortfolioWidget showing stocks/ETFs and options orders
    - Privacy-aware: portfolio viewing only in private groups
  - Integration with Shared Portfolios via new "Groups" tab
  - InvestorGroup model with full JSON serialization
  - 15+ Firestore service methods for CRUD, membership, and discovery
  - Enhanced Firestore security rules for group access control
  - Unit tests for InvestorGroup model (230+ lines)
  - Navigation drawer menu item for accessing investor groups
- **Market Status Indicators** for trade signal clarity:
  - Market status chip in Search widget filter area
  - Market status banner in Instrument widget above interval selector
  - Color-coded visual states: Green (Market Open), Blue (After Hours)
  - DST-aware `isMarketOpen` logic in AgenticTradingProvider
- **Ad-hoc Cron Endpoint** - Manual execution via callable/HTTP endpoint (`runAgenticTradingCron`)
- **Code Refactoring:**
  - Extracted duplicated portfolio state building logic into `_buildPortfolioState()` helper method
  - Reduced code duplication by ~72 lines in instrument_widget.dart

### Changed
- **Trade Signal Query Limits:**
  - Increased daily signal query limit to 500 (from 200) to prevent truncation
  - Intraday signals remain at 200 document limit
- **Automatic Interval Selection:**
  - Intraday intervals (15m/1h) prioritized during market hours
  - Daily signals emphasized after market close
  - Intelligent default selection based on market status
- **"All" Filter Behavior:**
  - Now correctly includes HOLD signals alongside BUY and SELL
  - Consistent signal type display across all filters
- **Portfolio Cash Calculation:**
  - Uses actual `portfolioCash` from AccountStore for accuracy
  - Aligns with existing pattern used in Home widget
  - Fixed Risk Guard button calculation

### Fixed
- Missing daily signals when intraday signals filled query window (resolved by higher limit)
- Edge cases at DST boundaries causing incorrect market status display
- Portfolio state duplication in trade proposal and Risk Guard handlers
- Type safety in portfolio cash retrieval using proper AccountStore access

### Performance
- Fewer missed daily signals with increased retrieval limit
- Reduced unnecessary interval queries through explicit market status
- Centralized portfolio state logic for maintainability

### Technical Details
- **Files Changed:** 21 files for Investor Groups (+2,418 lines)
- **Models:** InvestorGroup with member/admin/invitation tracking
- **State:** InvestorGroupStore ChangeNotifier in MultiProvider
- **UI Widgets:** InvestorGroupsWidget, InvestorGroupDetailWidget, InvestorGroupCreateWidget, InvestorGroupManageMembersWidget
- **Backend:** FirestoreService with 15+ methods for groups
- **Security:** Firestore rules for public/private group access

### Documentation
- Updated multi-indicator-trading.md with market status features
- Added Investor Groups documentation to docs/index.md
- Enhanced copilot-instructions.md with group patterns

## 0.14.3 - 2025-11-18

### Added
- Market status indicator (chip/banner) reflecting open vs closed trading session.
- Daily trade signal query limit increased to reduce truncation when intraday intervals saturate results.
- Ad-hoc callable/HTTP endpoint for daily agentic trading cron (`runAgenticTradingCron`) enabling manual execution.
- DST-aware `isMarketOpen` logic exposed in `AgenticTradingProvider` for intelligent default interval selection.

### Changed
- Automatic interval selection: intraday (15m/1h) prioritized during market hours; daily signals emphasized after close.
- Corrected “All” filter behavior to include HOLD signals consistently alongside BUY and SELL.
- Improved daily retrieval strategy using higher limit to balance additional intraday volume.

### Fixed
- Missing daily signals due to prior low limit when intraday signals filled query window.
- Edge cases at DST boundaries causing incorrect open/close status display.

### Performance
- Fewer missed daily signals from increased retrieval limit.
- Reduced unnecessary interval queries through explicit market status state.

## 0.14.2 - 2025-11-18

### Added
- Intraday AI trade signal generation with multiple time intervals:
  - 15-minute signals for ultra-short-term trading
  - Hourly signals for short-term trading
  - Daily signals (existing functionality)
  - Interval selector UI with SegmentedButton (15m, 1h, Daily)
- Real-time trade signal updates using Firestore snapshot listeners:
  - Automatic signal refresh when backend updates Firestore
  - No manual refresh required after EOD cron jobs
  - StreamSubscription lifecycle management in `AgenticTradingProvider`
  - Server data prioritization with cache fallback
- Market hours detection for intelligent signal filtering:
  - Shows intraday signals (15m, 1h) during market hours
  - Shows daily signals after market hours
  - Automatic switching between signal types
- Two new Firebase Functions for intraday signal generation:
  - `agenticTradingIntradayCronJob`: Runs hourly during market hours (9:30 AM - 4:00 PM ET)
  - `agenticTrading15mCronJob`: Runs every 15 minutes during market hours
- Backend interval-specific caching with appropriate TTLs:
  - 15-minute cache for 15m intervals
  - 30-minute cache for 30m intervals
  - 1-hour cache for 1h intervals
  - End-of-day cache for daily intervals
- Firestore composite index for interval-based queries:
  - `interval` (ascending) + `timestamp` (descending)
  - Optimized server-side filtering by interval

### Changed
- `getMarketData()` now accepts `interval` and `range` parameters for flexible data fetching
- Yahoo Finance API calls updated to support intraday OHLCV data (15m, 30m, 1h)
- Signal storage schema extended:
  - Daily signals: `agentic_trading/signals_<SYMBOL>` (backward compatible)
  - Intraday signals: `agentic_trading/signals_<SYMBOL>_<INTERVAL>`
- `AgenticTradingProvider` methods updated to accept interval parameter:
  - `fetchTradeSignal(symbol, {interval})` 
  - `fetchAllTradeSignals({interval})`
  - `initiateTradeProposal({interval})`
- `alpha-agent.ts` now persists interval metadata in signal documents
- Signal cards display interval label (Daily, Hourly, 30-min, 15-min) with timestamp
- `fetchAllTradeSignals()` replaced one-time fetch with real-time snapshot listener
- Added `dispose()` method to `AgenticTradingProvider` for proper cleanup

### Fixed
- Stale trade signals in Search widget after EOD cron job updates
- Signal refresh now automatic when backend updates Firestore at market close
- Memory leaks from uncancelled Firestore subscriptions
- Cache staleness detection improved for intraday intervals

### Performance
- Real-time signal updates eliminate polling and manual refresh
- Interval-specific cache TTLs reduce unnecessary API calls
- Market hours logic reduces client-side filtering overhead
- Subscription management prevents memory leaks

## 0.14.1 - 2025-11-17

### Added
- Server-side filtering for trade signals with optional parameters:
  - Filter by signal type (BUY/SELL/HOLD)
  - Filter by date range (start/end dates)
  - Filter by specific symbols (max 30, with client-side fallback for larger lists)
  - Configurable result limit (default: 50)
- Trade signal filter UI in Search tab:
  - FilterChips for All/BUY/SELL/HOLD signal types
  - Color-coded filters (green for BUY, red for SELL, grey for HOLD)
  - Manual refresh button
  - Empty state messages for filtered results
- Firestore composite indexes for optimized trade signal queries:
  - `signal` (ascending) + `timestamp` (descending)
  - `timestamp` (descending) single-field index

### Changed
- `fetchAllTradeSignals()` now accepts optional filtering parameters for server-side queries
- Trade Signals section now shows filter chips in header
- Firestore queries use `.orderBy('timestamp', descending: true)` with server-side filtering
- Default limit of 50 results for trade signal queries to improve performance

### Fixed
- Trade signal state synchronization between Instrument View and Search View
- `fetchTradeSignal()` now updates both `_tradeSignal` and `_tradeSignals` list
- Stale signal data in Search View when regenerating AI Trade Signal in Instrument View
- Signal list now maintains timestamp ordering after updates
- Removed signals are properly cleaned from the `_tradeSignals` list

### Performance
- Reduced network payload by fetching only filtered results
- Lower Firestore read operations with server-side queries
- Scalable for growing signal datasets with indexed queries

## 0.14.0 - 2025-11-16

### Added
- Stock Screener with advanced filtering:
  - Sector, market cap, P/E ratio, dividend yield, price range, and volume filters
  - Quick presets: High Dividend, Growth Stocks, Value Stocks, Large Cap
  - Yahoo Finance screener integration (Day Gainers, Day Losers, Most Actives, etc.)
  - Sortable results by multiple criteria
  - Input validation for filter ranges
- Trade Signals UI improvements:
  - Signal-type badges with color-coded backgrounds (green for BUY, red for SELL)
  - Bordered cards matching signal type for visual distinction
  - Prominent date display with improved formatting
  - Enhanced reason text styling for better readability
  - Repositioned to top of Search tab for visibility
- Search Widget UI improvements:
  - Sticky search header
  - Enhanced card designs with rounded corners and elevation
  - Improved grid layouts and typography
  - Color-coded indicators
  - Better visual hierarchy

### Changed
- Search results moved to top of page
- Search field relocated to sticky header
- Trade signal cards with bordered designs
- Improved movers/losers card styling

## 0.13.0 - 2025-11-15
This release significantly enhances AI-powered features with investment profiles, streaming responses, and agentic trading capabilities. Major additions include comprehensive risk assessment integration, improved trade signal displays, and refined portfolio analysis using user investment profiles.

### Added
- Investment Profile settings screen enhancements: auto-fill total portfolio value using portfolio aggregation, new icons, section headers, Material Design 3 styling.
- AI Recommendations promotional card on Home screen with conditional disappearance after first recommendations usage.
- Immediate AI bottom sheet presentation with streaming incremental output for non-chat prompts (local inference model).
- Share actions for AI responses and conversations.
- Investment profile fields to User model with corresponding settings widget.
- Comprehensive unit tests for User model investment profile fields.
- Agentic trading functionality with risk assessment integration.
- Firestore rules for agentic trading document access.
- Trade signals display in instrument and search widgets with prominent dates.
- Risk Guard button integration with Firebase function on Trade Signal cards.
- Agentic trade results display in Trade Signals section.
- CI workflow enhancements with Flutter caching options.

### Changed
- AI bottom sheet visual design: rounded corners, themed surface colors, improved card layout and loading state.
- Portfolio prompt generation updated to leverage investment profile data.
- Firestore user update process streamlined for investment profiles.
- Agentic trading cron job enhanced with error handling and logging.
- Alpha agent task improved with clearer logging and robust SMA calculations.
- Risk Guard agent integrated with risk assessment functionality.
- Agentic Trading Settings relocated to User page with adjusted layout dimensions.
- Portfolio cash calculation uses AccountStore for accuracy (matching Home widget pattern).
- Grid item text alignment made consistent across trade signals, lists, and S&P movers.

### Fixed
- Promotional card hide logic after portfolio recommendations retrieval.
- iOS share dialog positioning using correct `sharePositionOrigin` bounds.
- Type safety issues: changed dynamic user parameter to User? in generative_service.dart and ai.dart.
- Null pointer exception with portfolioCash using null-aware operator.
- Overflow issues in trade signal cards.
- Portfolio cash calculation in Risk Guard to use actual account cash.

### Removed
- Dead code: commented blocks in home_widget.dart and unused Consumer5 widget.
- Outdated investment profile documentation (moved to docs directory).

## 0.12.0
Previous release - details to be documented.

