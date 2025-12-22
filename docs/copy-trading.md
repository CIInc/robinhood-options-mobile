# Copy Trading Feature

> Introduced in **v0.16.0** and significantly enhanced in **v0.22.0**. Features manual and automated execution, a dedicated dashboard, approval workflows, and comprehensive audit trails.

## Overview

The Copy Trading feature allows members of investor groups to automatically or manually copy trades from other group members. This feature supports both stock/ETF trades and options trades.

## Features

### 1. Copy Trade Settings

Members can configure copy trading settings for each investor group they belong to:

- **Enable/Disable**: Turn copy trading on or off
- **Select Target User**: Choose which group member's trades to copy
- **Auto-Execute**: Automatically execute trades (subject to approval workflow)
- **Copy Percentage**: Copy a percentage of the original trade size (e.g., 50%). Supports fractional shares for stocks and rounds down to nearest integer for options (min 1 contract).
- **Max Quantity**: Limit the maximum number of shares/contracts to copy
- **Max Amount**: Limit the maximum dollar amount per trade
- **Override Price**: Use current market price instead of the copied trade's price

### 2. Copy Trading Dashboard

> **New in v0.22.0**

A centralized hub for managing all copy trading activities:

- **Trade History**: View a comprehensive list of all copied trades with status indicators.
- **Filtering**: Filter trades by status (Pending, Approved, Rejected, Completed), date range, and symbol.
- **Performance Metrics**: Track the performance of copied trades (P&L, win rate).
- **Trader Comparison**: Compare performance across different traders you are copying.
- **Time-Based Analysis**: Visualize cumulative P&L growth over time.
- **Request Management**: Review and act on pending copy trade requests.
- **Export**: Download trade history and performance reports as CSV.

### 3. Approval Workflow

> **New in v0.22.0**

When "Auto-Execute" is enabled, trades may require approval before execution based on configuration:

- **Request System**: New trades from the target user generate a "Copy Trade Request".
- **Notification**: You receive a notification to review the request.
- **Action**: Approve or Reject the request directly from the Dashboard or notification.
- **Execution**: Approved requests are executed immediately via the brokerage API.

### 4. Manual Copy Trading

> **Updated in v0.17.2:** Selection-based workflow with single and batch copy modes.

When viewing another member's portfolio in a private group, you can copy trades using two modes:

#### Single-Trade Copy (Default)

- **Tap** a filled order (stock/ETF or option) to select it
- Selected row highlights with tinted background, border, and check icons
- Press the floating **"Copy Trade"** button at the bottom
- A confirmation dialog appears with **instrument-specific details**:
  - **Stocks/ETFs:** Symbol, side (buy/sell), type, state, original quantity, adjusted quantity (if limited), limit price, estimated total
  - **Options:** Chain symbol, option type (call/put), expiration date, strike price, leg side, direction (credit/debit), original contracts, adjusted contracts (if limited), limit price, estimated total
- Quantity and amount limits from your Copy Trade Settings are **automatically applied** before confirmation
- Confirm to **immediately place the order** via the brokerage API
- Success or error feedback shown via SnackBars with color coding

#### Batch Copy (Multi-Select Mode)

- **Long-press** any filled order to enable multi-select mode
- **Tap** additional filled orders to add them to your selection (mix options and stocks/ETFs freely)
- Selected rows are **visually highlighted** (tint, elevated border, check icons)
- The floating button updates to show total count: **"Copy (5)"**
- Press the button to see a **batch confirmation dialog** summarizing:
  - Total number of trades selected
  - Breakdown: Options count vs Stocks/ETFs count
  - Sample symbols (first 3 of each type)
- On confirmation, all trades are **copied sequentially**:
  - Per-trade confirmation dialogs are **skipped** for efficiency
  - Quantity/amount settings are **applied individually** to each trade
  - Progress SnackBar shows "Copying N trades..."
  - Completion SnackBar confirms "Batch copy completed (N trades)"
- Clear selection at any time with the **X icon** in the AppBar
- Toggle back to single-select mode using the **checkbox icon** in the AppBar

**Note:** Selection state persists across screen updates thanks to model equality improvements in v0.17.2.

### 3. Automated Copy Trading

When auto-execute is enabled:

- Backend Firebase functions monitor new trades from the target user
- Trades are automatically filtered based on your settings
- Copy trade records are created for audit purposes
- **Push notifications sent** to your device when copy trades are detected
- Notifications include trader name, symbol, quantity, and side
- **Note**: Automatic order execution requires client-side implementation for security
- Users will need to review and execute pending copy trades manually

### 4. Notifications

Users receive push notifications when:

- A trader they're copying places a trade (if auto-execute is enabled)
- Notification shows: trader name, symbol, quantity, and buy/sell side
- Separate notifications for stocks/ETFs and options
- Notifications only sent if user has valid FCM tokens registered

### 5. Selection-Based UI

> **New in v0.17.2**

The member detail portfolio screen supports a selection-driven copy trading workflow:

- **Single tap** selects one trade; triggers full confirmation dialog with instrument-specific details
- **Long press** enables multi-select mode; selected rows are visually highlighted:
  - Tinted background (primary color at 8% opacity)
  - Elevated card border (1.2px, primary color)
  - Check circle icon replaces quantity in leading CircleAvatar
  - Trailing check icon badge appears next to amount
- **Floating Action Button** adapts label:
  - Single selection: "Copy Trade"
  - Multi-selection: "Copy (N)" where N is the total selected count
- **Batch Confirmation Dialog** uses a compact summary to reduce confirmation fatigue:
  - Total trade count, option vs instrument breakdown, sample symbols
  - No per-trade dialogs during batch execution
- **Equality Overrides:** `OptionOrder` and `InstrumentOrder` models implement `==` operator and `hashCode` based on `id` field:
  - Ensures selection persists across Firestore stream rebuilds
  - Set-based selection state works correctly with object identity

This approach consolidates multiple copy buttons into a single contextual action, improving clarity and scalability for users managing many trades.

## User Interface

### Accessing Copy Trade Settings

1. Navigate to an investor group
2. If you're a member, click the "Copy Trade Settings" button
3. Enable copy trading and configure your preferences
4. Select which member's trades you want to copy
5. Set your limits and save

### Manual Copying a Trade

1. Navigate to an investor group
2. Click on a member's portfolio
3. Find a filled order you want to copy
4. Click the copy icon next to the order
5. Review the trade details and confirm

## Implementation Details

### Data Model

#### CopyTradeSettings

```dart
class CopyTradeSettings {
  bool enabled;
  String? targetUserId;
  bool autoExecute;
  double? maxQuantity;
  double? maxAmount;
  bool? overridePrice;
}
```

Stored in `InvestorGroup.memberCopyTradeSettings` as a map:

```dart
Map<String, CopyTradeSettings>? memberCopyTradeSettings;
```

#### Copy Trade Records

Created by backend functions in Firestore collection `copy_trades`:

```typescript
{
  sourceUserId: string;
  targetUserId: string;
  groupId: string;
  orderType: 'instrument' | 'option';
  originalOrderId: string;
  symbol: string;
  side: string;
  originalQuantity: number;
  copiedQuantity: number;
  price: number;
  strategy?: string; // For options
  timestamp: Timestamp;
  executed: boolean;
}
```

### Backend Functions

#### onInstrumentOrderCreated

Triggered when a new instrument (stock/ETF) order is created:

1. Checks if the order is filled
2. Finds all investor groups the user belongs to
3. Identifies members who are copying from this user
4. Applies quantity and amount limits
5. Creates copy trade records
6. **Sends push notifications** to target users with trade details

#### onOptionOrderCreated

Triggered when a new option order is created:

1. Checks if the order is filled
2. Finds all investor groups the user belongs to
3. Identifies members who are copying from this user
4. Applies quantity and amount limits (accounting for 100 shares per contract)
5. Creates copy trade records
6. **Sends push notifications** to target users with trade details

#### Notification System

Push notifications are sent using Firebase Cloud Messaging (FCM):

- Fetches user's FCM tokens from registered devices
- Sends multicast notification to all user devices
- Includes trade details (symbol, side, quantity, order type)
- High priority notifications with sound and badge
- Handles notification failures gracefully with logging

### Security Rules

Firestore rules for `copy_trades` collection:

```
- Users can read their own copy trades (as source or target)
- Only backend functions can create copy trades
- Target users can update to mark as executed/rejected
- Admins can delete records
```

## Future Enhancements

### High Priority

1. **Auto-Execute for Copy Trades**: Implement client-side automatic execution for flagged copy trades without manual approval (fully autonomous).
2. **Performance Tracking**: Track success rate of copied trades.

### Medium Priority

3. **Partial Copying**: Support copying a percentage of the original trade.
4. **Time-based Filtering**: Only copy trades during specific hours.
5. **Symbol Filtering**: Allow/block specific symbols or sectors.
6. **Copy Stop Loss/Take Profit**: Automatically copy exit strategies.

### Low Priority

7. **Social Features**: See which members are most copied.
8. **Copy Trade Templates**: Save and reuse configuration presets.
9. **Multi-user Copying**: Copy from multiple users simultaneously.
10. **Inverse Copying**: Do the opposite of what someone else does.
11. **Copy Trading Groups**: Create groups specifically for copy trading.

## Testing

### Unit Tests

Tests are included in `test/investor_group_model_test.dart`:

- CopyTradeSettings serialization/deserialization
- InvestorGroup copy trade methods
- Settings storage and retrieval

### Manual Testing Checklist

- [ ] Create an investor group
- [ ] Add multiple members to the group
- [ ] Configure copy trade settings
- [ ] Verify settings are saved correctly
- [ ] View another member's portfolio
- [ ] **Single-Select Mode:**
  - [ ] Tap a filled order to select it
  - [ ] Verify visual highlighting (tint, border, check icons)
  - [ ] Press floating "Copy Trade" button
  - [ ] Verify confirmation dialog shows correct instrument-specific details
  - [ ] Verify quantity/amount limits are applied
  - [ ] Confirm and verify order is placed successfully
  - [ ] Check order appears in your account
- [ ] **Multi-Select Mode:**
  - [ ] Long-press a filled order to enable multi-select
  - [ ] Tap additional orders to build selection (mix options and stocks)
  - [ ] Verify floating button shows "Copy (N)" with correct count
  - [ ] Verify all selected rows are highlighted
  - [ ] Press floating button and review batch confirmation dialog
  - [ ] Verify summary shows correct counts and sample symbols
  - [ ] Confirm batch copy and verify progress/completion SnackBars
  - [ ] Verify all orders are placed successfully
  - [ ] Check all orders appear in your account
  - [ ] Test clearing selection with X icon
  - [ ] Test toggling between single/multi-select modes
- [ ] Test with both stock and option orders
- [ ] Verify error handling for failed orders
- [ ] Verify selection persists during screen updates (stream rebuilds)

### Backend Function Testing

1. Deploy functions: `firebase deploy --only functions`
2. Create test orders in user collections
3. Verify copy trade records are created
4. Check logs for errors
5. Verify security rules prevent unauthorized access

## Deployment

### Frontend Changes

The Flutter app includes a selection-based copy trading UI:

- **`investor_groups_member_detail_widget.dart`:** Implements single & multi-select logic, batch confirmation dialog, visual row highlighting, and floating action button adaptation
- **`copy_trade_button_widget.dart`:** Shows differentiated confirmation dialog content for options vs instruments; supports `skipInitialConfirmation` parameter for batch operations
- **Model Overrides:** `option_order.dart` and `instrument_order.dart` include equality operators for Set-based selection

These changes are included in standard build artifacts; no special build steps required.

### Backend Functions

Deploy the Firebase functions:

```bash
cd src/robinhood_options_mobile/functions
npm install
firebase deploy --only functions
```

### Firestore Rules

Deploy the security rules:

```bash
firebase deploy --only firestore:rules
```

### 6. Copy Trading Dashboard

> **New in v0.22.0**

A dedicated dashboard for managing copy trading activities:

- **Trade History**: View a comprehensive list of all copied trades.
- **Filtering**: Filter trades by status (Pending, Approved, Rejected, Completed), date range, and symbol.
- **Performance Metrics**: Track the performance of copied trades (P&L, win rate).

### 7. Approval Workflow

> **New in v0.22.0**

When "Auto-Execute" is enabled, trades may require approval before execution based on configuration:

- **Request System**: New trades from the target user generate a "Copy Trade Request".
- **Notification**: You receive a notification to review the request.
- **Action**: Approve or Reject the request from the Dashboard.
- **Execution**: Approved requests are executed immediately via the brokerage API.

## Limitations

1. ~~**No Actual Execution**: The current implementation creates copy trade records but doesn't execute orders.~~ ✅ **FIXED** - Manual copy trades now execute immediately via brokerage API.

2. **Auto-Execute Client-Side**: Fully automated execution without user intervention requires the app to be running or a background service (planned). Currently uses the Approval Workflow.

3. **Single Target**: Users can only copy from one member per group at a time.

4. **No Inverse Copying**: Cannot automatically do the opposite of another user's trades.

5. ~~**No Filtering**: Cannot filter by symbol, time, or other criteria (yet).~~ ✅ **FIXED** - Dashboard provides filtering.

6. **Manual Price Override**: The "override price" setting requires fetching current quotes, not yet implemented.

## Security Considerations

1. **User Consent**: Users must explicitly enable copy trading
2. **Limits**: Quantity and amount limits protect users from over-exposure
3. **Audit Trail**: All copy trades are logged for compliance
4. **Access Control**: Only group members can copy from each other
5. **Firestore Rules**: Backend-only creation prevents abuse

## Support

For issues or questions about copy trading:

1. Check this documentation
2. Review the code in:
   - `lib/model/investor_group.dart`
   - `lib/widgets/copy_trade_settings_widget.dart`
   - `lib/widgets/copy_trade_button_widget.dart`
   - `functions/src/copy-trading.ts`
3. Contact the development team

## License

This feature is part of the RealizeAlpha project and subject to the same license terms.
