# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.24.0] - 2025-12-23

### Added
- **Automated Trading:**
  - **Emergency Stop:** Added "Emergency Stop" button for immediate cessation of automated trading.
  - **Status Display:** Updated auto-trade status display for better visibility of system state.
- **Benchmark Chart:**
  - **Date Range Selection:** Added ability to select different date ranges (1W, 1M, 3M, YTD, 1Y, ALL) for benchmark performance comparison.
- **Copy Trading Enhancements:**
  - **Inverse Copying:** Added option to copy trades in the opposite direction (e.g., buy when the leader sells).
  - **Exit Strategies:** Implemented exit strategies for copied trades to manage risk and profit taking.
  - **Copy Percentage:** Added ability to set a specific percentage of the portfolio or trade amount to allocate for copy trading.
  - **Advanced Filtering:** Enhanced copy trade settings with more granular filtering options.
  - **Performance Dashboard:** Updated dashboard with performance tracking and trader comparison features.
- **Trade Signals:**
  - **Enhanced Handling:** Improved trade signal processing with new sorting options and better error management.
  - **Navigation Integration:** Direct integration of trade signals into the navigation widget for seamless instrument display.

### Changed
- **Instrument Chart:** Improved robustness of the instrument chart widget when handling historical data.
- **Documentation:** Updated documentation for Advanced Order Types.

## [0.23.0] - 2025-12-22

### Added
- **Option Chain Screener:**
  - Advanced filtering capabilities for option chains including Delta, Theta, Gamma, Vega, Implied Volatility, and more.
  - Support for saving, loading, and resetting filter presets.
  - AI-powered "Find Best Contract" feature that analyzes the chain and suggests options based on risk tolerance and strategy.
- **Strategy Builder:**
  - New multi-leg options strategy builder supporting Spreads, Straddles, Iron Condors, and custom combinations.
  - Visual payoff diagrams and risk/reward analysis for complex strategies.
- **Advanced Order Types:**
  - Added support for Trailing Stop and Stop-Limit orders for both stocks and options.
  - Added Time in Force options: GTC (Good Till Cancelled), GFD (Good For Day), IOC (Immediate Or Cancel), OPG (At The Open).
- **Stock Orders:**
  - Enabled direct stock order placement from the new trading UI.
- **Trading UI:**
  - Completely refactored trading widgets with improved order preview and placement flow.
  - Enhanced "Reset" functionality in filter options to correctly clear selected presets.

### Changed
- **AI Recommendations:** Improved robustness of AI response parsing for option suggestions, ensuring reliable JSON extraction and better error handling.
- **User Feedback:** Added clearer notifications (SnackBars) when AI recommendations are found or if no options match criteria.

## [0.22.0] - 2025-12-20

### Added
- **Copy Trading:**
  - Implemented full copy trading functionality with order execution and data models.
  - Added Copy Trading Dashboard with trade history and filtering options.
  - Implemented copy trade request approval and rejection workflow with UI integration.
- **Backtesting:**
  - Added new default backtest templates for various trading strategies.
- **Agentic Trading:**
  - Added signal strength and individual indicator performance cards to the performance widget.

## [0.21.0] - 2025-12-19

### Added
- **Custom Indicators:** Added support for defining and using custom indicators within the Agentic Trading system.
- **ML Optimization:** Integrated Machine Learning models to optimize trade signals and improve decision accuracy.
- **Advanced Exit Strategies:**
  - **Partial Exits:** Configure multiple exit stages with specific profit targets and quantity percentages.
  - **Time-Based Exits:** Option to close positions after a specific duration.
  - **Market Close Exits:** Automatically close positions a set number of minutes before market close.
- **Backtesting Templates:** Added ability to save, load, and manage custom backtesting configurations as templates.
- **AI Enhancements:** Improved AI response handling with editing capabilities and better prompt management.

### Changed
- **App Badging:** Migrated from `flutter_app_badger` to `app_badge_plus` for improved reliability and platform support.
- **Login Flow:** Updated login challenge handling to support prompt-based challenges and improved long-running session maintenance.
- **Performance:** Optimized agentic trading cron jobs with batch processing and better config fetching.

### Removed
- **AI Prompt:** Removed the manual AI prompt input field from Agentic Trading settings to streamline the configuration interface.

## [0.20.2] - 2025-12-17

### Added
- **Advanced Risk Controls:** Introduced `RiskGuardAgent` with configurable limits for sector exposure, correlation checks, volatility filters, and drawdown protection.
- **Order Approval Workflow:** Added `requireApproval` setting to `AgenticTradingConfig`, allowing manual review of agent-generated orders before execution.
- **Watchlist Management:** Implemented comprehensive watchlist features including creating new lists, adding/removing instruments, and improved list display UI.
- **App Badging:** Integrated `flutter_app_badger` to support app icon badges for notifications or status updates.

### Changed
- **Trade Signals:** Enhanced `TradeSignalsProvider` with improved query handling and subscription management for better performance.
- **Navigation:** Refactored `NavigationStatefulWidget` and bottom navigation bar for improved user experience and responsiveness.
- **UI Consistency:** Enhanced various widgets for better visual consistency and functionality.

## [0.20.1] - 2025-12-16

### Added
- **Generative Actions:** Added `GenerativeActionsWidget` to provide AI-driven actions and insights directly within the UI.
- **Instrument Charting:** Introduced `InstrumentChartWidget` for enhanced charting capabilities on instrument details.
- **Firestore Indexes:** Updated Firestore indexes to support new query patterns and improve performance.

### Changed
- **Instrument Details:** Major refactoring of `InstrumentWidget` to improve performance and maintainability.
- **Home Screen:** Enhanced `HomeWidget` for better UI consistency and data presentation.
- **Agentic Trading Settings:** Updated `AgenticTradingSettingsWidget` with improved configuration options.
- **AI Utilities:** Enhanced `utils/ai.dart` to support new generative features.
- **Error Handling:** Improved error handling in `RobinhoodService` for more robust data fetching.

### Removed
- **SliverAppBarWidget:** Removed obsolete `SliverAppBarWidget` in favor of standard app bar implementations.

## [0.20.0] - 2025-12-15

### Added
- **Advanced Trade Signal Filtering:**
  - **Signal Strength Filters:** Filter signals by Strong (75-100), Moderate (50-74), or Weak (0-49) categories.
  - **4-Way Indicator Filters:** Granular control for each of the 12 indicators (Off, BUY, SELL, HOLD).
  - **Exclusive Filtering:** Smart logic prevents conflicting queries by toggling between strength and indicator modes.
- **Dedicated Search Widgets:**
  - **ScreenerWidget:** Standalone widget for fundamental stock screening (Market Cap, P/E, etc.).
  - **PresetsWidget:** Standalone widget for Yahoo Finance preset screeners.
  - **SearchWidget:** Streamlined UI with navigation to new screener widgets.
- **Performance Improvements:**
  - **Server-Side Filtering:** Moved all trade signal filtering to Firestore for faster results and reduced data usage.
  - **Optimized Querying:** Removed real-time subscriptions for search queries to improve UI responsiveness.
  - **Composite Indexes:** Added new Firestore indexes to support complex multi-factor queries.

### Changed
- **Search UI:** Reorganized Search tab to feature "Stock Screener" and "Presets" buttons instead of inline lists.
- **TradeSignalsProvider:** Refactored to support server-side filtering and single-fetch queries.
- **Documentation:** Updated Agentic Trading and Multi-Indicator Trading docs with new filtering capabilities.

### Fixed
- **Initial Load:** Fixed issue where trade signals wouldn't appear on first load due to loading state logic.
- **Error Handling:** Improved error messaging when trade signal fetching fails.

    - SELL signal when %R > -20 (overbought) or -80 ≤ %R < -50 (bearish momentum)
    - Provides early reversal signals and complements RSI analysis

- **Indicator Documentation Widget:** New in-app technical reference system
  - Comprehensive documentation for all 12 indicators accessible from settings
  - Each indicator page includes: purpose, signals (BUY/SELL/HOLD), configuration, technical details
  - Interactive help icon in indicator toggle cards links to full documentation
  - Educational resource for understanding each indicator's role in the trading system
  - Helps users make informed decisions about which indicators to enable

- **Enhanced Signal Strength Display:** Improved visualization of trade signal quality
  - Signal strength score (0-100) now prominently displayed with color-coded visual indicators
  - Strength categories: Strong (75-100, green), Moderate (50-74, orange), Weak (0-49, red)
  - Filter trade signals by minimum strength threshold in Search widget
  - Signal strength chip with icon and percentage in Instrument widget
  - Better understanding of signal confidence before entering trades

### Changed
- **Updated Trade Signal System:** All references to indicator count updated from 9 to 12
  - Search widget now shows "12 indicators must align" in filter descriptions
  - Agentic trading settings updated to reflect 12-indicator system
  - Performance analytics updated to track 12 indicators in combination analysis
  - Backtesting configuration supports all 12 indicators
- **Improved Indicator Display:** Enhanced settings UI for better indicator management
  - Alphabetical sorting option for indicator list (Price patterns always first)
  - Help icons link to indicator documentation for each toggle card
  - More compact spacing between indicator cards
  - Better visual hierarchy in settings sections

### Technical
- **Backend Enhancements:**
  - `evaluateVWAP()` function in `technical-indicators.ts` for VWAP calculations
  - `evaluateADX()` function with +DI/-DI directional movement analysis
  - `evaluateWilliamsR()` function for Williams %R momentum oscillator
  - Updated `evaluateAllIndicators()` to include all 12 indicators
- **Model Updates:**
  - `AgenticTradingConfig` model expanded with `vwapEnabled`, `adxEnabled`, `williamsREnabled` fields
  - `BacktestConfig` model supports new indicators for historical testing
  - `TradeSignal` model tracks all 12 indicator states
- **Widget Updates:**
  - New `IndicatorDocumentationWidget` for in-app technical reference
  - Enhanced `AgenticTradingSettingsWidget` with help icons and documentation links
  - Updated `SearchWidget` with signal strength filtering and improved display
  - Enhanced `InstrumentWidget` with signal strength chip and reorganized layout
  - Updated `BacktestingWidget` to configure all 12 indicators
  - Enhanced `AgenticTradingPerformanceWidget` to track 12-indicator combinations

### Performance
- Optimized indicator calculation pipeline for 12 indicators without performance degradation
- Efficient VWAP calculation using cumulative volume-weighted price sums
- ADX uses 14-period smoothing for accurate trend strength measurement
- Williams %R leverages existing price data structures for fast computation

## [0.19.0] - 2025-12-15

### Added
- **Backtesting Interface:** Comprehensive strategy testing on historical data
  - 3-tab interface: Run (configure & execute), History (view past results), Templates (save/reuse)
  - Support for multiple time intervals: Daily (1d), Hourly (1h), 15-minute (15m)
  - Date range selection (5 days to 5 years) for historical data access
  - Configure all 9 technical indicators with same parameters as live trading
  - Advanced risk parameters: Take Profit %, Stop Loss %, Trailing Stop %
  - Comprehensive performance metrics:
    - Returns: Total return in dollars and percentage, final capital
    - Trade Statistics: Total trades, winning/losing trades, win rate percentage
    - Risk Metrics: Sharpe ratio (risk-adjusted returns), maximum drawdown, profit factor
    - Trade Analysis: Average win/loss, largest win/loss, average hold time
  - Visual Results Page with 4 tabs:
    - Overview: Key metrics cards (total return, win rate, Sharpe ratio, profit factor, max drawdown)
    - Trades: Complete trade-by-trade breakdown with entry/exit details and reasons
    - Equity: Interactive equity curve chart with trade markers and statistics list
    - Details: Configuration, enabled indicators, performance by indicator, additional stats
  - Interactive equity curve visualization with clickable trade markers
  - Trade marker system (BUY in blue, SELL in orange) overlaid on equity curve
  - Template system to save and reuse backtest configurations
  - Performance comparison features to analyze multiple backtest runs
  - Export results as JSON for external analysis
  - Share backtest results via system share sheet
  - Quick access buttons in Home widget and Instrument trade signal view
  - Seamless integration with live trading indicator configuration
  - User backtest history persisted in Firestore (last 50 runs)
  - Real-time Firestore updates for templates and history

### Changed
- Improved spacing in Agentic Trading Settings (reduced SizedBox heights from 24 to 16/8)
- Reordered Notification Settings section to appear after Technical Indicators in settings
- Enhanced home widget with prominent "Automated Trading & Backtesting" promotion card
- Added "Run Backtest" button to Instrument widget trade signal view
- Added "Backtest" menu item to User Settings for quick access
- Moved Agentic Trading settings button to Trade Signal title trailing area in Instrument view
- Reorganized Trade Signal interval selector from segmented button to popup menu with status chip
- Fixed null-safe type casting in home_widget market data calculations
- Improved null handling in home widget index mapping operations

### Technical
- New Firebase Function: `runBacktest` for backend backtest execution
- New Dart models: `BacktestConfig`, `BacktestTrade`, `BacktestResult`, `BacktestTemplate`
- New Provider: `BacktestingProvider` for state management and Firestore integration
- New Widget: `BacktestingWidget` with 3-tab interface and result page
- Firestore collections: `backtest_history` and `backtest_templates` per user
- Firestore security rules: Added read/write permissions for backtest collections
- Timestamp tracking added to market data for accurate historical bar indexing
- Bar-by-bar historical simulation with indicator evaluation
- Equity curve tracking and performance metric calculations
- Performance by indicator analysis (signal counts and win rates)

## [0.18.0] - 2025-12-13

### Added
- **Paper Trading Mode:** Risk-free strategy testing with simulated trade execution
  - Toggle in Auto-Trade Configuration section
  - Simulates order responses without calling broker API
  - Tracks paper trades identically to real trades with all analytics
  - Visual PAPER badges throughout UI
  - Filter performance by paper vs real trades
  - Perfect for validating strategies before risking capital

- **Advanced Performance Analytics Dashboard:** 9 comprehensive analytics cards in Performance Widget
  - **Performance Overview:** Total trades, success rate, win/loss counts
  - **Profit & Loss:** Total P&L, average per trade, breakdown
  - **Trade Breakdown:** Entry/exit counts by type (Buy, Take Profit, Stop Loss, Trailing Stop)
  - **Best & Worst Trades:** Highlights with P&L details
  - **Advanced Analytics (4 metrics):**
    - Sharpe Ratio: Risk-adjusted returns (Good >1, Fair 0-1, Poor <0)
    - Average Hold Time: Position duration in hours and minutes
    - Profit Factor: Gross profit / Gross loss ratio (Profitable >1)
    - Expectancy: Expected profit per trade in dollars
  - **Risk Metrics:**
    - Longest Win Streak: Best consecutive winning trades
    - Longest Loss Streak: Worst consecutive losing trades
    - Max Drawdown: Peak to trough decline in equity
  - **Performance by Time of Day:** Win rates across market hours (Morning/Afternoon/Late Day)
  - **Performance by Indicator Combo:** Tracks which indicator combinations perform best
  - **Performance by Symbol:** Stock-specific win rates (top 10)

- **Indicator Combination Tracking:** Stores active indicators with each automated trade
  - Snapshot of enabled indicators preserved in trade records
  - Win/loss tracking for each unique indicator combination
  - Top 8 combinations displayed with win rates
  - Helps identify optimal indicator configurations
  - Abbreviated indicator names (Price, RSI, Market, MACD, BB, Stoch, ATR, OBV)

- **Trailing Stop Loss:** Dynamic stop loss that adjusts with profits
  - Automatically raises stop loss as position becomes profitable
  - Locks in gains while allowing further upside
  - Configurable trailing distance (default 3%)
  - Tracks highest price (peak) for each automated trade
  - Exits when price drops specified % from peak
  - Separate tracking from fixed stop loss

### Changed
- **Moved Paper Trading Mode** from Automated Trading section to Auto-Trade Configuration section for better logical grouping
- **Enhanced Trade Records** to include `enabledIndicators` snapshot and `paperMode` flag
- **Improved Performance Widget** with filter chips to view All/Paper/Real trades separately
- **Enhanced Trade Cards** with PAPER badges for simulated trades
- **Updated AgenticTradingConfig** model with `paperTradingMode` field

### Performance
- **Comprehensive Analytics:** Real-time calculation of 20+ trading performance metrics
- **Streak Tracking:** Monitors consecutive wins and losses for behavioral insights
- **Drawdown Monitoring:** Tracks maximum equity decline for risk assessment
- **Hold Time Analysis:** Calculates average position duration
- **Time-Based Performance:** Win rates by market hours (morning/afternoon/late day)
- **Indicator Effectiveness:** Win rates by active indicator combinations

### Technical Details
- **Files Changed:** 
  - `lib/model/agentic_trading_config.dart` - Added paperTradingMode field
  - `lib/model/agentic_trading_provider.dart` - Added paper trade simulation, indicator snapshots, trailing stop, advanced metrics
  - `lib/widgets/agentic_trading_settings_widget.dart` - Added Paper Trading Mode toggle in config section
  - `lib/widgets/agentic_trading_performance_widget.dart` - Added 9 analytics cards with filters and comprehensive metrics
- **New Methods:**
  - `_simulatePaperOrder()` - Generates realistic simulated order responses
  - `_filterHistory()` - Filters trades by paper/real mode
  - `_buildFilterChips()` - UI for trade mode filtering
  - `_buildAdvancedAnalyticsCard()` - 4-metric grid (Sharpe, Hold Time, Profit Factor, Expectancy)
  - `_buildRiskMetricsCard()` - Streaks and drawdown display
  - `_buildTimeOfDayCard()` - Win rates by market hours
  - `_buildIndicatorComboCard()` - Performance by indicator combinations
  - `_buildMetricBox()` - Reusable metric display component
- **Config Fields Added:**
  - `paperTradingMode: bool` (default: false)
  - `trailingStopEnabled: bool` (default: false) 
  - `trailingStopPercent: double` (default: 3.0)
- **Trade Record Fields Added:**
  - `enabledIndicators: List<String>` - Active indicators at execution time
  - `paperMode: bool` - Tracks if trade was simulated
  - `highestPrice: double` - Peak price for trailing stop tracking
- **Statistics Tracked:**
  - `profitFactor`, `expectancy`, `longestWinStreak`, `longestLossStreak`, `maxDrawdown`
  - `avgHoldTimeMinutes`, `timeOfDayStats`, `indicatorComboStats`

## [0.17.6] - 2025-12-06

### Changed
- **UI Improvements and Fixes:** Enhanced visual consistency across the application by updating widget styles to use theme colors, improving button designs, dropdown borders, and layout structures for better user experience and accessibility.

### Technical Details
- **Files Changed:** 31 widget files updated with theme-consistent styling and UI improvements:
  - `lib/enums.dart`
  - `lib/widgets/agentic_trading_settings_widget.dart`
  - `lib/widgets/chart_time_series_widget.dart`
  - `lib/widgets/forex_instrument_widget.dart`
  - `lib/widgets/forex_positions_page_widget.dart`
  - `lib/widgets/forex_positions_widget.dart`
  - `lib/widgets/history_widget.dart`
  - `lib/widgets/home_widget.dart`
  - `lib/widgets/income_transactions_widget.dart`
  - `lib/widgets/instrument_option_chain_widget.dart`
  - `lib/widgets/instrument_positions_page_widget.dart`
  - `lib/widgets/instrument_positions_widget.dart`
  - `lib/widgets/instrument_widget.dart`
  - `lib/widgets/investor_group_create_widget.dart`
  - `lib/widgets/investor_groups_widget.dart`
  - `lib/widgets/list_widget.dart`
  - `lib/widgets/lists_widget.dart`
  - `lib/widgets/login_widget.dart`
  - `lib/widgets/more_menu_widget.dart`
  - `lib/widgets/navigation_widget.dart`
  - `lib/widgets/option_instrument_widget.dart`
  - `lib/widgets/option_order_widget.dart`
  - `lib/widgets/option_orders_widget.dart`
  - `lib/widgets/option_positions_page_widget.dart`
  - `lib/widgets/option_positions_widget.dart`
  - `lib/widgets/position_order_widget.dart`
  - `lib/widgets/search_widget.dart`
  - `lib/widgets/trade_instrument_widget.dart`
  - `lib/widgets/user_info_widget.dart`
  - `lib/widgets/user_widget.dart`
  - `lib/widgets/users_widget.dart`

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

