# UI Improvements

## Completed Improvements

### Navigation Bar Upgrade (v0.27.0)
- **Component**: Updated `BottomNavigationBar` to Material 3 `NavigationBar`.
- **Benefits**:
  - Improved UI consistency with Material 3 design guidelines.
  - Better responsiveness and touch targets.
  - Enhanced visual feedback for selected items.

### Ad Integration (v0.27.0)
- **Component**: Integrated ad banners into `OptionOrderWidget`.
- **Features**:
  - Non-intrusive ad placement.
  - Seamless integration with the order flow.

### Watchlist Stream (v0.27.0)
- **Component**: Added watchlist stream functionality in `SearchWidget`.
- **Features**:
  - Real-time updates of user watchlists.
  - Direct display of watchlist items in the search interface.

### Option Instrument Position UI (v0.27.7)
- **Component**: Redesigned position card in `OptionInstrumentWidget`.
- **Features**:
  - **ITM/OTM Badges**: Clear visual indication of In-The-Money or Out-Of-The-Money status.
  - **P&L Visibility**: Large, color-coded P&L display (Open & Day) for instant assessment.
  - **Comprehensive Statistics**: Grid layout showing Break-Even Price, Days to Expiration, Collateral, and Greeks (Delta, Theta, Gamma, Vega, Rho, Implied Volatility).
  - **Enhanced Layout**: Improved data density and readability using badges and organized metrics.

### Navigation Bar Upgrade (v0.21.1)
- **Component**: Replaced `BottomNavigationBar` (Material 2) with `NavigationBar` (Material 3).
- **Benefits**:
  - Modern Material 3 design.
  - Better accessibility with larger touch targets.
  - Smoother animations.
  - Consistent styling with the rest of the app (which uses `useMaterial3: true`).
- **Configuration**:
  - Labels are configured to `alwaysShow` in `main.dart` theme.
  - Uses the app's color scheme for the indicator and icons.

### Risk Heatmap Widget
- **Component**: New interactive Treemap visualization for portfolio risk.
- **Features**:
  - **Treemap Layout**: Size represents equity, color represents performance.
  - **Smart Grouping**: Automatically groups smaller positions into an "Others" category to reduce clutter.
  - **Multi-View**: Toggle between Sector and Symbol views.
  - **Multi-Metric**: Toggle between Daily Change and Total Return.
  - **Drill-Down**: Tap to view detailed position lists for any sector or the "Others" group.

### Portfolio Analytics Widget
- **Component**: Comprehensive dashboard for advanced portfolio metrics.
- **Features**:
  - **Risk-Adjusted Returns**: Sharpe, Sortino, Treynor, Calmar, Omega, Information Ratio.
  - **Market Comparison**: Alpha, Beta, Excess Return vs SPY/QQQ/DIA.
  - **Risk Metrics**: Max Drawdown, Volatility, VaR (95%).
  - **Integration**: Embeds the Risk Heatmap for visual context.

### Option Instrument Position UI
- **Component**: Redesigned Position Card in `OptionInstrumentWidget`.
- **Features**:
  - **Header**: Clear "Position" label with quantity, position type (e.g., "10x long"), and color-coded ITM/OTM badge.
  - **P&L Display**: Prominent, large-format display for both Total Return and Today's Return with visual separation.
  - **Stats Grid**: Organized 3-column layout showing Market Value, Avg Price, Total Cost, Break Even, Expiration (with red warning < 5 days), and Collateral (for short positions).
  - **Position Greeks**: (Note: Capability added but optionally disabled) Aggregate Greeks calculation for the entire position.

## Future UI Improvement Ideas

### Typography
- [ ] Review font sizes and weights for consistency across all screens.
- [ ] Consider using a custom font that aligns with the brand identity.

### Color Scheme
- [ ] Refine the Dark Mode color scheme to ensure sufficient contrast.
- [ ] Verify that the `seedColor` generates a palette that works well for all components.

### Components
- [ ] **Cards**: Standardize card elevation and padding.
- [ ] **Buttons**: Ensure consistent button styles (Filled, Outlined, Text) are used appropriately.
- [ ] **Dialogs**: Update dialogs to use standard Material 3 dialogs.

### Layout
- [ ] **Padding**: Audit screens for consistent padding (e.g., 16dp standard).
- [ ] **Lists**: Ensure list items have consistent height and spacing.

### Feedback
- [ ] **Loading States**: Replace generic circular progress indicators with skeleton loaders where appropriate.
- [ ] **Error States**: Improve error messages with actionable steps and better visuals.

### Accessibility
- [ ] **Touch Targets**: Ensure all interactive elements have a minimum size of 48x48dp.
- [ ] **Contrast**: Verify text contrast ratios meet WCAG guidelines.
