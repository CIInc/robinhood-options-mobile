# Robinhood Curated Screener Presets and Legend Service Support

RealizeAlpha integrates first-party Robinhood market data and trading workspace endpoints (`/screeners/presets/`, `/screeners`, `/hippo/bw/layouts`) to deliver server-side curated equity screeners in the mobile client. Legend workspace service support remains available for backend integrations, while its mobile UI is temporarily deferred.

## Overview

Finding high-conviction trading opportunities requires combining fundamental screening with responsive technical workspaces. Robinhood provides curated server-side screener presets tailored for income investors, growth seekers, momentum traders, and short-squeeze candidates, alongside multi-window Robinhood Legend desktop layouts that organize advanced trading tools into unified workstations.

## Features

### First-Party Endpoints
- **Curated Screener Presets**: `GET https://bonfire.robinhood.com/screeners/presets/` returns Robinhood server-side presets:
  - `display_name`: Preset title (e.g. `Daily price jumps`, `Highest dividend yield`, `Upcoming earnings`, `Analyst picks`, `Highest implied volatility`, `Highest options volume`, `New 52-week highs`, `New 52-week lows`).
  - `display_description`: Descriptive summary explaining target equities.
  - `icon_emoji`: Preset emoji badge (e.g. `💡`).
  - `sort_by` & `sort_direction`: Server-side sorting field (`1d_price_change`, `dividend_yield`, `upcoming_earnings`, `implied_volatility`, `options_volume`, `market_cap`) and direction (`DESC`, `ASC`).
  - `columns`: Display columns (`sparkline`, `price`, `1d_price_change`, `todays_volume`, `market_cap`, `upcoming_earnings`, `dividend_yield`, etc.).
  - `asset_urls`: CDN illustration images across viewports (`180x100`, `255x160`, `28x28`, `48x64`).
  - `hide_from_search` & `is_preset`: Visibility flags.
- **Available Screeners & Filters**: `GET https://bonfire.robinhood.com/screeners?include_filters=true` exposes available server-side screener configurations and filter definitions.
- **Legend Desktop Layouts**: `GET https://api.robinhood.com/hippo/bw/layouts` returns saved desktop trading workspaces and layouts.
- **Layout Definition & Widget Grid**: `GET https://api.robinhood.com/hippo/bw/layouts/{layoutId}` returns specific multi-panel workstation grid layouts with widget coordinates and configurations.

### Presets & Workspaces UI (`PresetsWidget`)
The `PresetsWidget` is accessible directly from the Search screen via the top app bar action and quick-access banner, organized into two tabs:

1. **Curated Presets Tab**:
   - **Strategy Themes**: Horizontal filter chips to filter presets by category (`All`, `Dividends`, `Growth`, `Value`, `Momentum`, `Short Squeeze`, `Active`).
   - **Preset Cards**: Detailed cards showing category badge, `FEATURED` stars, total result count, title, and descriptive summary.
   - **Filter Criteria Tags**: Compact chips illustrating underlying screening rules (e.g., `Market Cap ≥ $50B`, `Div Yield ≥ 3.0%`, `P/E ≤ 20`).
   - **Sample Symbols**: Direct-action ticker chips (e.g., `AAPL`, `MSFT`, `JNJ`, `GME`) that route immediately into the native `InstrumentWidget`.
   - **Open in Stock Screener**: One-tap action that automatically pre-populates all filtering criteria into `ScreenerWidget` and executes the query.

2. **Yahoo Presets Tab**:
   - Quick access to Yahoo Finance predefined screeners (`Undervalued Large Caps`, `Day Gainers`, `Growth Technology Stocks`, `Most Shorted Stocks`).

### Stock Screener Integration & Performance (`ScreenerWidget`)
- **Active Curated Screener Hero Banner**:
  - Displays preset category pill (e.g. `DIVIDENDS`, `MOVERS`, `VOLATILITY`), preset title, Robinhood CDN illustration thumbnail, emoji badge, and description.
  - Active criteria pills summarizing active thresholds (`Div Yield ≥ 5.0%`, `Top 1-Day Price Gainers`, `Market Cap ≥ $1B`).
  - Action buttons: "Filter Settings" (collapses/expands the filter panel), "Switch" (opens curated presets modal sheet), and "Reset" (clears screener).
  - App bar title and sticky header subtitle clearly display the active curated screener name and category.
- **High-Performance 200+ Results Virtualization**:
  - Eliminated repetitive $O(N^2 \log N)$ sorting during widget rendering by sorting results only once upon query completion or sort field modification into `sortedResults`.
  - Replaced unvirtualized `GridView(shrinkWrap: true)` inside `SliverList` with native `SliverGrid` and `SliverList` slivers inside `SliverStickyHeader`.
  - Enabled lazy viewport building: only the ~8-12 cards on screen are instantiated at a time, eliminating render freezes and memory pressure.
  - Implemented auto-pagination / display limits (60 initial cards, auto-loading 60 more on scroll, or "Show all" toggle).
  - Added view mode toggle: switch seamlessly between Grid view (card tiles with key metric tags) and List view (dense list tiles).
  - Fixed scroll behavior: positions view directly at top of results instead of dragging viewport to the bottom.

## Architecture & Integration

- **Models**:
  - `RobinhoodScreenerPreset` & `ScreenerPresetCriterion` in [src/robinhood_options_mobile/lib/model/screener_preset.dart](../src/robinhood_options_mobile/lib/model/screener_preset.dart).
  - `LegendLayout` & `LegendWidgetConfig` in [src/robinhood_options_mobile/lib/model/legend_layout.dart](../src/robinhood_options_mobile/lib/model/legend_layout.dart).
- **Service Layer**:
  - `IBrokerageService` defines:
    - `getScreenerPresets(BrokerageUser user)`
    - `getScreeners(BrokerageUser user, {bool includeFilters = false})`
    - `getLegendLayouts(BrokerageUser user)`
    - `getLegendLayout(BrokerageUser user, String layoutId)`
  - Overridden in `RobinhoodService` for live API queries.
  - Implemented in `DemoService` with high-conviction curated presets and Legend desktop workstations.
- **UI Widgets**:
  - [src/robinhood_options_mobile/lib/widgets/presets_widget.dart](../src/robinhood_options_mobile/lib/widgets/presets_widget.dart): Curated and Yahoo preset explorer. Legend workspace UI is deferred.
  - [src/robinhood_options_mobile/lib/widgets/screener_widget.dart](../src/robinhood_options_mobile/lib/widgets/screener_widget.dart): Integrated curated preset loader modal and initial preset parameter support.
  - [src/robinhood_options_mobile/lib/widgets/search_widget.dart](../src/robinhood_options_mobile/lib/widgets/search_widget.dart): App bar navigation and browse card entry points.
