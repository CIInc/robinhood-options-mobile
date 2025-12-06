# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.17.5] - 2025-12-05

### Added
- **User Document Reference Threading:** Enhanced widget parameter passing to include `DocumentReference<User>?` (Firestore user document reference) alongside authentication user context. Enables better integration with user-specific settings and features throughout the navigation hierarchy.
- **Indicator Toggle Enhancements:** Improved indicator toggle functionality in agentic trading with dynamic settings display, providing more intuitive control over trade signal indicators.

### Changed
- **Widget User Parameter Refactoring:** Refactored user handling across 14+ navigation widgets to properly use `brokerageUser` for brokerage operations and `userDocRef` for Firestore user document references. Improves code clarity and type safety:
  - `instrument_positions_widget.dart` and related position widgets
  - `option_positions_widget.dart` and option chain widgets
  - `option_order_widget.dart` and order tracking widgets
  - `instrument_widget.dart` and navigation chain
  - `history_widget.dart` and other entry points
- **Code Readability:** Improved code readability in multiple widgets by replacing `forEach` loops with standard `for` loops, enhancing maintainability and consistency.
- **Cache Handling:** Updated cache handling logic in market data functions for improved clarity and consistency.

### Fixed
- **Whitespace Cleanup:** Cleaned up unnecessary whitespace in `handleAlphaTask` function for improved code formatting.

### Technical Details
- **Files Changed:** 14+ widget files updated with improved user context parameter handling:
  - `lib/widgets/history_widget.dart`
  - `lib/widgets/instrument_option_chain_widget.dart`
  - `lib/widgets/instrument_positions_page_widget.dart`
  - `lib/widgets/instrument_positions_widget.dart`
  - `lib/widgets/instrument_widget.dart`
  - `lib/widgets/list_widget.dart`
  - `lib/widgets/lists_widget.dart`
  - `lib/widgets/option_instrument_widget.dart`
  - `lib/widgets/option_order_widget.dart`
  - `lib/widgets/option_orders_widget.dart`
  - `lib/widgets/option_positions_page_widget.dart`
  - `lib/widgets/option_positions_widget.dart`
  - `lib/widgets/position_order_widget.dart`
  - `lib/widgets/navigation_widget.dart`
- **Navigation Integration:** User document references now properly threaded from `SearchWidget` and `NavigationStatefulWidget` entry points through all navigation chains.
- **Type Safety Improvements:** Consistent use of `DocumentReference<User>?` across widgets for proper Firebase Firestore type handling.

## [0.17.4] - 2025-11-30

### Added
- **Portfolio Position Diversification Chart:** New pie chart in the portfolio allocation carousel that displays diversification by individual stock positions. Shows top 5 holdings with remaining positions grouped as "Others". Users can now visualize portfolio concentration across positions, sectors, and industries.
- **Carousel Page Indicators:** Added visual dot indicators below the allocation carousel to show which chart page is currently active (Asset, Position, Sector, or Industry).

### Fixed
- **Pie Chart Slice Highlighting:** Fixed interactive highlighting in allocation pie charts. Clicking on pie chart slices now properly highlights both the slice and corresponding legend entry. Clicking legend entries now selects and highlights the corresponding pie slice.
- **Selection Model Configuration:** Reordered chart behaviors to place `SelectNearest()` and `DomainHighlighter()` before `DatumLegend` for proper bidirectional selection between chart and legend.
- **Null Selection Handling:** Added null checks in `onSelected` callbacks to prevent `NoSuchMethodError` when selections are cleared or deselected.

### Changed
- **Position Chart Display:** Reduced maximum positions shown from 8 to 5 to better fit available screen space and improve readability.
- **Position Percentage Calculation:** Position percentages now calculated relative to total portfolio value instead of just stock positions, providing more accurate allocation representation.
- **Carousel State Management:** Replaced `setState` with `ValueNotifier` for carousel page indicators to avoid rebuilding the entire home widget on page changes, improving performance.

### Technical Details
- **Files Changed:**
  - `lib/widgets/home_widget.dart`:
    - Added `ValueNotifier<int>` for carousel page tracking
    - Implemented carousel scroll listener with viewport-based page calculation
    - Added null-safe `onSelected` callbacks for all pie charts
    - Reordered behaviors: `SelectNearest()`, `DomainHighlighter()`, then `legendBehavior`
    - Added percentage labels to position diversification matching Asset allocation format
    - Changed `maxPositions` constant from 8 to 5
    - Used `fold` instead of `reduce` for safer aggregation with empty data handling

## [0.17.3] - 2025-11-26

### Added
- **Enhanced Firebase Authentication UX:**
  - Password visibility toggle with eye icon for better usability
  - Real-time email format validation with user-friendly error messages
  - Enhanced phone number input with country code guidance and validation
  - Improved SMS verification code dialog with larger input, number keyboard, and helper text
  - Success feedback with checkmark snackbar on successful sign-in
  - Loading state improvements with "Signing in..." text and properly sized spinner
- **Keyboard-Responsive Bottom Sheet:** Authentication modal now dynamically adjusts height when keyboard appears, ensuring input fields remain visible and accessible above the keyboard

### Changed
- **Improved Error Messages:** Firebase authentication errors now display contextual, actionable messages:
  - `user-not-found` → "No account found with this email. Please check or register."
  - `wrong-password` → "Incorrect password. Please try again or reset your password."
  - `email-already-in-use` → "This email is already registered. Try signing in instead."
  - `weak-password` → "Password is too weak. Please use at least 6 characters."
  - `invalid-email` → "Invalid email format. Please check your email address."
  - `network-request-failed` → "Network error. Please check your connection and try again."
  - `too-many-requests` → "Too many attempts. Please wait a moment and try again."
- **Enhanced Password Reset Dialog:** Pre-fills email, includes validation, descriptive instructions, and better button labels ("Send Reset Email" vs "Send")
- **Password Requirements:** Registration now validates minimum 6 characters with clear error guidance
- **Visual Improvements:** Added icon prefixes to all input fields (email, phone, password, SMS) for better visual clarity

### Fixed
- **SnackBar Styling Consistency:** Trade Signal Notification Settings now use default styling without custom background colors and include floating behavior, matching app-wide conventions used in `auth_widget.dart`, `utils/auth.dart`, `agentic_trading_settings_widget.dart`, and `investment_profile_settings_widget.dart`.
- **Daily Cron Job:** Fixed issues with the daily end-of-day cron job execution to ensure reliable trade signal generation.
- **Authentication Form UX:** Removed autofocus from email and phone text fields in authentication form to prevent keyboard from auto-showing on load and hiding the Phone/Email mode selector, improving initial form visibility and user navigation.
- **Bottom Sheet Keyboard Overlap:** Authentication fields no longer hidden behind keyboard; bottom sheet expands dynamically using `MediaQuery.viewInsets.bottom` with additional padding

### Technical Details
- **Files Changed:**
  - `lib/widgets/trade_signal_notification_settings_widget.dart`: Removed `backgroundColor: Colors.green` and added `behavior: SnackBarBehavior.floating` to success and error notifications
  - `functions/src/agentic-trading-cron.ts`: Enhanced error handling and execution reliability
  - `lib/widgets/auth_widget.dart`: 
    - Added `_obscurePassword` state variable for password visibility toggle
    - Implemented `MediaQuery.of(context).viewInsets.bottom` for keyboard-responsive padding
    - Added `resizeToAvoidBottomInset: true` to Scaffold
    - Enhanced all text field decorations with icons and improved validation
    - Improved error handling with user-friendly messages via FirebaseAuthException switch cases
    - Enhanced SMS code dialog with styled input (24pt font, 8px letter spacing, bold, number keyboard, 6-char limit)
    - Improved password reset dialog with Form validation and pre-filled email
    - Added success snackbar with checkmark on successful authentication
  - `lib/widgets/auth_widget.dart`: Removed `autofocus: true` from email field (line 214) and phone field (line 242)
- **UI/UX Improvements:** 
  - Users now see the full authentication form including mode selector before keyboard interaction, preventing navigation controls from being obscured
  - Password toggle provides visibility control for verification
  - Email regex validation: `^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$`
  - Phone validation ensures "+" prefix and minimum 10 characters
  - All dialogs follow Material Design 3 patterns with consistent styling

## [0.17.2] - 2025-11-24

### Added
- **Selection-Based Batch Copy Trading:** Redesigned copy trading workflow with single and multi-select modes:
  - **Single-Select Mode:** Tap a filled order to select; floating action button triggers copy with full confirmation dialog
  - **Multi-Select Mode:** Long-press to enable; tap additional orders to build batch selection (options, stocks/ETFs, or mixed)
  - **Batch Confirmation Dialog:** Summarizes total trade count, option vs instrument breakdown, and sample symbols before execution
  - **Visual Selection Highlighting:** Selected rows show tinted background, elevated borders, check icons in leading avatar, and trailing check badges
  - Toggle between single/multi-select via AppBar checkbox icon; clear selection with X button
- **Enhanced Confirmation Dialogs:** Instrument-specific and option-specific trade details:
  - **Stock/ETF Dialog:** Shows symbol, side, type, state, original/adjusted quantity, limit price, estimated total
  - **Option Dialog:** Displays chain symbol, option type, expiration date, strike price, leg side, direction (credit/debit), original/adjusted contracts, limit price, estimated total
  - Date formatting with `intl` package for readable expiration display
- **Model Equality Overrides:** Implemented `==` operator and `hashCode` based on `id` field for `OptionOrder` and `InstrumentOrder`:
  - Fixes selection persistence across Firestore stream rebuilds
  - Set-based selection state now correctly identifies orders by ID rather than object identity
- **Stock Quantity Formatting:** CircleAvatar in instrument orders shows signed quantity (+/− prefix) with decimal precision (max 2 places, integers display without decimals)
- **Theme-Aware Text Colors:** Member count text in Investor Groups now uses `Colors.grey[700]` on light theme for improved contrast (retains secondary color on dark theme)

### Changed
- **Removed Per-Row Copy Buttons:** Consolidated from individual copy buttons per order to unified selection + floating action button workflow
- **Floating Action Button Adaptation:** Label updates dynamically:
  - Single selection: "Copy Trade"
  - Multi-selection: "Copy (N)" where N is total selected count
- **Batch Copy Workflow:** Sequential execution with `skipInitialConfirmation` flag passed to `showCopyTradeDialog`:
  - Per-trade confirmation dialogs skipped during batch
  - Quantity/amount limits applied individually per trade
  - Progress SnackBar shown during batch execution; completion SnackBar on finish
- **Widget Conversion:** `InvestorGroupsMemberDetailWidget` converted from Stateless to StatefulWidget to manage selection state
- **Selection State Management:** Uses `Set<OptionOrder>` and `Set<InstrumentOrder>` for selected items; supports toggle between single/multi-select with automatic collapse to single item when exiting multi-select

### Fixed
- **Selection State Persistence:** `isSelected` now updates correctly after stream rebuilds thanks to model equality overrides
- **UI Contrast:** Member count and secondary text more readable on light themes
- **Decimal Overflow:** Stock quantity display limits length to 6 characters to prevent avatar overflow

### Technical Details
- **Files Changed:**
  - `lib/widgets/investor_groups_member_detail_widget.dart`: Added selection state, batch logic, highlighting UI
  - `lib/widgets/copy_trade_button_widget.dart`: Enhanced dialog with type-specific content, added `skipInitialConfirmation` parameter
  - `lib/model/option_order.dart`, `lib/model/instrument_order.dart`: Added equality/hashCode overrides
  - `lib/widgets/investor_groups_widget.dart`: Theme-aware text colors
- **State Management:** Selection sets cleared on mode toggle, navigation exit, or post-copy
- **Batch Execution:** Iterates `_selectedOptionOrders` then `_selectedInstrumentOrders` with mounted checks; sequential `await` ensures order
- **Visual Feedback:** Card elevation increases (6 vs 1), border width 1.2px, primary color tint at 8% opacity, leading avatar background at 18% opacity

### Performance
- Reduced widget complexity by removing individual copy button widgets per row
- Set-based lookups (`contains()`) efficient for selection checks during list builds
- Equality override enables O(1) set membership tests instead of linear scans

## [0.17.1] - 2025-11-23

### Changed
- Modernized UI for instrument, history, list, and lists widgets:
  - Consistent card styling, improved alignment, and color-coded badges.
  - "Show All" toggle for similar instruments in instrument widget.
  - Responsive grid layouts for watchlists and lists.

### Fixed
- Trading signal indicator display issues:
  - Corrected logic to show/hide based on user settings.
  - Improved formatting and organization of indicator details.

## [0.17.0] - 2025-11-22

### Added
- **Expanded Multi-Indicator System:** Increased from 4 to 9 technical indicators for more comprehensive market analysis:
  - **New Indicators:** MACD (Moving Average Convergence Divergence), Bollinger Bands, Stochastic Oscillator, ATR (Average True Range), and OBV (On-Balance Volume)
  - **Existing Indicators:** Price Movement (multi-pattern detection), Momentum (RSI), Market Direction, and Volume
  - All 9 indicators must signal BUY for automatic trade execution
- **User-Configurable Trading Settings:**
  - New `AgenticTradingConfig` model stored in user profile
  - Configurable parameters: RSI period, market index symbol (SPY/QQQ), SMA periods, trade quantity, position limits
  - Settings persist across sessions and sync via Firestore
  - UI integration in `AgenticTradingSettingsWidget` for easy configuration
- **Indicator Filtering & Customization:**
  - Filter trade signals by specific indicators in search interface
  - Enable/disable individual indicators to customize signal generation
  - View individual indicator signals with detailed reasoning
  - Overall signal now reflects only enabled indicators
- **Enhanced Indicator Documentation:**
  - Comprehensive documentation for each technical indicator accessible via info buttons
  - Detailed explanations of signal logic, thresholds, and interpretations
  - Consistent documentation display in both settings and instrument detail views
  - Educational content helps users understand indicator behavior
- **Trade Signal Notifications:**
  - User-configurable push notification settings for BUY/SELL/HOLD signals
  - Per-interval notification preferences (daily, hourly, 15-minute)
  - Firestore-backed notification preferences with real-time sync
  - FCM integration for reliable cross-platform delivery

### Changed
- **Enhanced Signal Representation:**
  - Instrument widget now displays enabled indicators and their individual signals
  - Color-coded indicator status (green=BUY, red=SELL, gray=HOLD/DISABLED)
  - Visual feedback shows which indicators are active vs disabled
  - Overall signal message reflects enabled indicator consensus
- **Improved Data Quality:**
  - Market data fetching now filters out null values for OHLC prices
  - Enhanced data validation in cron jobs
  - Better error handling for incomplete market data
- **Optimized Cron Job Performance:**
  - Refined document filtering to exclude 15m and 1h intraday charts from daily EOD processing
  - Improved query efficiency by filtering at query level rather than post-processing
- **UI/UX Improvements:**
  - Refined indicator display with better visual hierarchy
  - Improved interval label formatting in instrument widget
  - Enhanced settings interface with clearer configuration options

### Fixed
- **Data Consistency:** Resolved issues with null OHLC values causing calculation errors
- **Signal Accuracy:** Improved overall signal calculation to respect enabled/disabled indicator states
- **Display Bugs:** Fixed indicator visibility and color coding in various UI states

### Technical Details
- **9-Indicator System Architecture:**
  - `technical-indicators.ts` expanded with 5 new indicator evaluation functions
  - Each indicator returns structured data: signal (BUY/SELL/HOLD), value, reason, and metadata
  - `evaluateAllIndicators()` aggregates results and determines `allGreen` status
  - Frontend receives complete indicator breakdown for granular UI display
- **Configuration Model:**
  - `AgenticTradingConfig` class with JSON serialization in `lib/model/agentic_trading_config.dart`
  - Stored in `User.agenticTradingConfig` field
  - Includes: `enabled`, `smaPeriodFast`, `smaPeriodSlow`, `tradeQuantity`, `maxPositionSize`, `maxPortfolioConcentration`, `rsiPeriod`, `marketIndexSymbol`, `enabledIndicators` map
  - Default values: RSI period 14, market index SPY, fast/slow MAs 10/30
- **Indicator Details:**
  - **MACD:** Tracks momentum using 12/26/9 EMA configuration, crossover signals
  - **Bollinger Bands:** Volatility bands with 2 std dev, identifies overbought/oversold at band extremes
  - **Stochastic:** Oscillator comparing close to price range, 80/20 thresholds
  - **ATR:** Measures volatility, high/rising ATR indicates trending markets
  - **OBV:** Cumulative volume flow, divergences signal potential reversals
- **Data Model Changes:**
  - Added `enabledIndicators` map to `AgenticTradingConfig` for per-indicator toggle
  - Extended `multiIndicatorResult` in Firestore signal documents with 9 indicators
  - Backward compatible with existing 4-indicator signals

### Documentation
- **Updated `docs/multi-indicator-trading.md`:**
  - Expanded from 4 to 9 indicators with detailed descriptions
  - Added configuration section for new user settings
  - Documented indicator filtering and customization features
  - Included technical formulas and thresholds for each indicator
  - Added troubleshooting guidance for common issues
- **Updated README.md:**
  - Revised Trade Signals feature description to reflect 9-indicator system
  - Added mention of user-configurable settings
  - Updated technical details to reference new indicators
- **Updated `.github/copilot-instructions.md`:**
  - Added `AgenticTradingConfig` model reference
  - Documented new indicator filtering capabilities
  - Updated architecture notes with 9-indicator system details
  - Added file references for new configuration UI components

### Migration Notes
- Existing users will receive default configuration values on first app launch post-update
- Historical 4-indicator signals remain valid and displayable
- No data migration required; new config auto-initializes
- All 9 indicators enabled by default for consistent behavior

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
- Intraday trade signal generation with multiple time intervals:
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
- Stale signal data in Search View when regenerating Trade Signal in Instrument View
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

