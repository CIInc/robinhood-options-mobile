# Trade Signal Filter UI - Visual Description

## UI Layout

The filter chips are displayed above the Trade Signals grid in the Search tab.

```
┌─────────────────────────────────────────────────────────────┐
│ Trade Signals                                               │
│                                                             │
│ ┌─────┐ ┌─────┐ ┌──────┐ ┌──────┐ ┌───┐                  │
│ │ All │ │ BUY │ │ SELL │ │ HOLD │ │ ⟳ │                  │
│ └─────┘ └─────┘ └──────┘ └──────┘ └───┘                  │
│   (selected)  (green)   (red)    (grey)  (refresh)       │
│                                                             │
│ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐              │
│ │ AAPL   │ │ GOOGL  │ │ TSLA   │ │ MSFT   │              │
│ │  BUY   │ │  SELL  │ │  HOLD  │ │  BUY   │              │
│ │ Nov 15 │ │ Nov 14 │ │ Nov 13 │ │ Nov 12 │              │
│ │ Strong │ │ Weak   │ │ Neutral│ │ Growth │              │
│ │ signal │ │ trend  │ │ market │ │ signal │              │
│ └────────┘ └────────┘ └────────┘ └────────┘              │
│                                                             │
│ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐              │
│ │ AMZN   │ │ META   │ │ NVDA   │ │ AMD    │              │
│ │  BUY   │ │  BUY   │ │  SELL  │ │  HOLD  │              │
│ │ Nov 11 │ │ Nov 10 │ │ Nov 9  │ │ Nov 8  │              │
│ └────────┘ └────────┘ └────────┘ └────────┘              │
└─────────────────────────────────────────────────────────────┘
```

## Filter States

### 1. All Signals (Default)
```
┌─────────┐ ┌─────┐ ┌──────┐ ┌──────┐ ┌───┐
│ ✓ All   │ │ BUY │ │ SELL │ │ HOLD │ │ ⟳ │
└─────────┘ └─────┘ └──────┘ └──────┘ └───┘
```
Shows all trade signals (BUY, SELL, HOLD)

### 2. BUY Signals Only
```
┌─────┐ ┌───────────┐ ┌──────┐ ┌──────┐ ┌───┐
│ All │ │ ✓ BUY     │ │ SELL │ │ HOLD │ │ ⟳ │
└─────┘ └───────────┘ └──────┘ └──────┘ └───┘
        (green background)
```
Shows only BUY signals with green highlighting

### 3. SELL Signals Only
```
┌─────┐ ┌─────┐ ┌────────────┐ ┌──────┐ ┌───┐
│ All │ │ BUY │ │ ✓ SELL     │ │ HOLD │ │ ⟳ │
└─────┘ └─────┘ └────────────┘ └──────┘ └───┘
                 (red background)
```
Shows only SELL signals with red highlighting

### 4. HOLD Signals Only
```
┌─────┐ ┌─────┐ ┌──────┐ ┌────────────┐ ┌───┐
│ All │ │ BUY │ │ SELL │ │ ✓ HOLD     │ │ ⟳ │
└─────┘ └─────┘ └──────┘ └────────────┘ └───┘
                          (grey background)
```
Shows only HOLD signals with grey highlighting

## Color Scheme

### Filter Chips
- **All**: Default Material chip color (unselected)
- **BUY**: 
  - Selected background: `Colors.green.withOpacity(0.3)`
  - Checkmark: `Colors.green`
- **SELL**: 
  - Selected background: `Colors.red.withOpacity(0.3)`
  - Checkmark: `Colors.red`
- **HOLD**: 
  - Selected background: `Colors.grey.withOpacity(0.3)`
  - Checkmark: `Colors.grey`

### Signal Cards
- **BUY signals**: 
  - Border: `Colors.green.withOpacity(0.3)` (1.5px)
  - Badge background: `Colors.green.withOpacity(0.15)`
  - Badge text: `Colors.green`
  - Icon: `Icons.trending_up` (green)

- **SELL signals**: 
  - Border: `Colors.red.withOpacity(0.3)` (1.5px)
  - Badge background: `Colors.red.withOpacity(0.15)`
  - Badge text: `Colors.red`
  - Icon: `Icons.trending_down` (red)

- **HOLD signals**: 
  - Border: `Colors.grey.withOpacity(0.2)` (1.5px)
  - Badge background: `Colors.grey.withOpacity(0.15)`
  - Badge text: `Colors.grey`
  - Icon: `Icons.trending_flat` (grey)

## User Interaction Flow

1. **Initial Load**: 
   - All filter chip selected by default
   - Shows 50 most recent trade signals (all types)

2. **Filter Selection**:
   - User taps "BUY" filter chip
   - Chip becomes selected with green highlight
   - Grid updates to show only BUY signals
   - Network request fetches filtered data from Firestore

3. **Deselection**:
   - User taps "BUY" again (or taps "All")
   - Filter resets to show all signals
   - Grid updates with all signal types

4. **Manual Refresh**:
   - User taps refresh button (⟳)
   - Current filter is maintained
   - Data is refreshed from Firestore

## Responsive Behavior

- Filter chips wrap to multiple lines on narrow screens
- Grid maintains `maxCrossAxisExtent: 220.0`
- Cards resize based on available width
- Maintains `childAspectRatio: 1.3`

## Accessibility

- Filter chips have proper labels
- Color coding is supplemented with icons
- Refresh button has tooltip: "Refresh"
- All interactive elements are tappable with proper touch targets

## Empty States

When no signals match the filter:
```
┌─────────────────────────────────────────────────────────────┐
│ Trade Signals                                               │
│                                                             │
│ ┌─────┐ ┌─────────┐ ┌──────┐ ┌──────┐ ┌───┐              │
│ │ All │ │ ✓ BUY   │ │ SELL │ │ HOLD │ │ ⟳ │              │
│ └─────┘ └─────────┘ └──────┘ └──────┘ └───┘              │
│         (green background)                                  │
│                                                             │
│ (Grid section is hidden - no signals to display)           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

The Trade Signals section becomes invisible when empty, maintaining a clean UI.

## Performance Indicators

When filtering is in progress (brief moment during network request):
- Filter chips may show a subtle loading state
- Grid maintains previous content until new data arrives
- Smooth transition between filtered states

## Future UI Enhancements

Potential future additions (not implemented yet):

1. **Date Range Picker**:
```
┌─────┐ ┌─────┐ ┌──────┐ ┌──────┐ ┌───────────┐ ┌───┐
│ All │ │ BUY │ │ SELL │ │ HOLD │ │ Last 7 Days ▼│ │ ⟳ │
└─────┘ └─────┘ └──────┘ └──────┘ └───────────┘ └───┘
```

2. **Symbol Search**:
```
┌──────────────────────────────────────┐
│ 🔍 Filter by symbol...               │
└──────────────────────────────────────┘
```

3. **Signal Count Badge**:
```
┌─────────┐ ┌──────────┐ ┌───────────┐ ┌───────────┐
│ All(50) │ │ BUY(23) │ │ SELL(15) │ │ HOLD(12) │
└─────────┘ └──────────┘ └───────────┘ └───────────┘
```
