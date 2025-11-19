# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Added
- Investor Groups feature for collaborative portfolio sharing:
  - Create public or private investor groups
  - Join and leave groups with member management
  - View group details, members, and portfolios
  - Group admin controls for editing and deleting groups
  - Integration with Shared Portfolios via new "Groups" tab
  - Firestore security rules for group access control
  - **Private Group Portfolio Viewing:**
    - Tap on member in private group to view their shared portfolio
    - Navigation to SharedPortfolioWidget showing stocks/ETFs and options orders
    - Consistent avatar display using CachedNetworkImageProvider
    - Privacy-aware: portfolio viewing only available in private groups
  - **Member Management & Invitations:**
    - Admin interface to manage group members with 3-tab layout (Members, Pending, Invite)
    - Real-time user search functionality to find and invite users
    - Send invitations to join groups
    - Accept or decline group invitations from dedicated "Invitations" tab
    - Promote/demote admin roles
    - Remove members from groups
    - View and cancel pending invitations
- InvestorGroup model with full serialization support including pending invitations tracking
- Comprehensive Firestore service methods for group CRUD operations and invitation management (15+ methods)
- Unit tests for InvestorGroup model functionality including invitation features (230+ lines)
- Navigation drawer menu item for accessing investor groups

### Technical Details
- **Files Changed:** 21 files, +2,418 lines
- **Models:** `InvestorGroup` with JSON serialization, member/admin/invitation tracking
- **State:** `InvestorGroupStore` ChangeNotifier integrated into MultiProvider
- **UI Widgets:** InvestorGroupsWidget, InvestorGroupDetailWidget, InvestorGroupCreateWidget, InvestorGroupManageMembersWidget
- **Backend:** 15+ Firestore service methods for CRUD, membership, invitations, and discovery
- **Security:** Enhanced Firestore rules for group access control including invitation access
- Placeholder for upcoming changes.

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

