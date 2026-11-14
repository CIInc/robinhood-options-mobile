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
- **Risk Guardian & Capital Safeguards** *(v0.52.0)*:
  - **Max Allocation Per Trade**: Dollar cap bounding the maximum capital committed to any single copied order. Automatically clamps share/contract quantity down to avoid exceeding limit.
  - **Max Equity Allocation %**: Percent cap of the follower's total portfolio equity (e.g., 5%). Clamps orders dynamically according to real-time portfolio balance.
  - **Max Slippage Abort Threshold (bps)**: Maximum unfavorable price slippage allowed before aborting order execution (e.g., 50 bps = 0.50%, 75 bps = 0.75%). If real-time quote slips unfavorably relative to leader fill price, the trade is aborted to protect follower capital.
  - **Auto-Disconnect on Leader Drawdown & Divergence**: Automatically trips circuit breaker and ceases copy-trading if leader drawdown exceeds threshold (e.g., 15%) or cumulative return divergence exceeds threshold (e.g., 5%).
  - **Circuit Trip & Reset Protection**: Once tripped, pending/incoming copy executions are blocked until the follower explicitly reviews telemetry and taps "Reset Guardian & Reconnect".
  - **Defined-Risk Inverse Option Guardrails** *(v0.61.6)*: Hard safety rule enforced on both backend (`buildCopyOptionOrderPlan` in `functions/src/copy-trading.ts`) and client (`CopyTradeRiskGuardianService.evaluateInverseOptionGuardrail`) preventing `inverse: true` mode from generating naked short options. Single-leg long options are automatically mapped to defined-risk opposite-direction long contracts (`Buy Call` $\leftrightarrow$ `Buy Put`), multi-leg inverse spreads must retain protective long legs on every short strike (otherwise uncovered short legs are flipped to defined-risk long options), and all inverse/adapted option trades require manual review (`pending_approval`).
  - **Small-Account Option Contract Adapter** *(v0.61.6)*: When 1 contract of the leader's option exceeds `maxAllocationPerTrade` (or `maxAmount`), flags the record with `needsContractAdaptation: true` and uses `CopyTradeRiskGuardianService.suggestOptionAdaptations` to rank cheaper liquid OTM single-leg strikes and defined-risk vertical debit spreads within the follower's budget.
- **Override Price**: Use current market price instead of the copied trade's price
- **Inverse Copying**: Copy trades in the opposite direction (e.g., buy when the leader sells; single-leg long options are automatically adapted into defined-risk opposite-direction long contracts via `Buy Call` $\leftrightarrow$ `Buy Put`). Useful for hedging or contrarian strategies.
- **Exit Strategies**:
  - **Copy Stop Loss**: Automatically copy stop loss orders placed by the leader.
  - **Stop Loss Adjustment**: Adjust the copied stop loss percentage (e.g., -1% to tighten, +1% to loosen).
  - **Copy Take Profit**: Automatically copy take profit orders placed by the leader.
  - **Take Profit Adjustment**: Adjust the copied take profit percentage.
  - **Copy Trailing Stop**: Automatically copy trailing stop orders.

### 2. Copy Trading Dashboard

> **New in v0.22.0, Enhanced in v0.24.0**

A centralized hub for managing all copy trading activities:

- **Trade History**: View a comprehensive list of all copied trades with status indicators.
- **Filtering**: Filter trades by status (Pending, Approved, Rejected, Completed), date range, and symbol.
- **Performance Metrics**: Track the performance of copied trades (P&L, win rate).
- **Risk Guardian Telemetry Card** *(v0.52.0)*: Real-time status display of capital guardrails (max allocation cap, max slippage bps, auto-disconnect triggers), active circuit breaker trips with 1-tap "Reset Guardian & Reconnect", and a count of protected aborted orders.
- **Side-by-Side Multi-Trader Portfolio Comparison** *(v0.52.0)*: Full-screen interactive comparison of 2 to 4 potential leaders or active copy targets across standardized timeframes (`1W`, `1M`, `3M`, `1Y`, `ALL`). Evaluates risk-adjusted metrics (Return, Win Rate, Profit Factor, Return/Drawdown ratio, Max Drawdown, Sharpe Ratio, Activity, and Reputation score), highlights category winners, visualizes 5-dimensional relative strengths, and preserves portfolio privacy via audited percentages and dollar balance masking (`$***`). Accessible from the Copy Trading Dashboard, Top Portfolios Leaderboard (multi-select compare mode), and Trader Profiles.
- **Time-Based Analysis**: Visualize cumulative P&L growth over time.
- **Request Management**: Review and act on pending copy trade requests.
- **Export**: Share trade history and performance reports as a named CSV file attachment.

### 3. Approval Workflow

> **New in v0.22.0, Enhanced in v0.61.4**

When "Auto-Execute" is enabled, trades may require approval before execution based on configuration:

- **Request System**: New trades from the target user generate a "Copy Trade Request".
- **Notification**: You receive a push notification to review the request with full trade details and leader attribution.
- **Deep Linking to Request Details (`CopyTradeRequestDetailWidget`)**: Tapping the notification opens the dedicated request detail view directly (placing the requests list in the back-stack):
  - **Comprehensive Parameters:** Symbol, side (Buy/Sell), inverse copying badge (if applicable), order quantity, signal price, stop price, and total estimated order value.
  - **Options Leg Breakdown:** For multi-leg or single options trades, inspect strike prices, expiration dates, call/put types, and leg ratios.
  - **Leader Identity:** Shows the leader's display name (`sourceUserName`) instead of raw IDs.
  - **Execution Audit:** Review submission timestamps, current status (Pending, Approved, Rejected, Completed), and execution IDs.
  - **Interactive Actions:** Direct 1-tap **Approve Request** (with client-side `RiskGuard` allocation and balance validation) or **Reject Request** buttons, alongside an **Inspect Chart** shortcut. When `needsContractAdaptation` or an inverse option guardrail applies, `CopyTradeRequestDetailWidget` renders inverse guardrail banners, interactive **Option Contract Adapter** cards (`OptionContractAdaptation` single-leg OTM strikes or vertical debit spreads), and one-tap **Approve Adapted** submission via `CopyTradingProvider.approveAdaptedRequest` / `applyDefinedRiskInverse`.
- **Interactive Requests List (`CopyTradeRequestsWidget`)**: Single-tapping any pending or historical request card opens the detailed inspection screen.
- **Execution**: Approved requests are submitted immediately via the connected brokerage API.

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

### 4. Notifications (Rich Push & Deep Linking)

> **Enhanced in v0.31.7, Deep Linking & Channels Hardened in v0.61.4**

Users receive **Rich Push Notifications** containing actionable data when copy trades occur:

- **Rich Content**: Visual charts, trend context, and trade details (Leader Name via `sourceUserName`, Symbol, Quantity, Side, Price).
- **Action Buttons & Intent Matching**: Tapping a notification directly dispatches an intent with `click_action: "FLUTTER_NOTIFICATION_CLICK"` and payload `recordId` routing straight to `CopyTradeRequestDetailWidget` without landing on the generic home page.
- **Dedicated Android Notification Channel**: High-priority `copy_trades` notification channel registered with vibration, sound, and lighting to ensure timely delivery of perishable trade proposals.
- **Cold-Start Resilience**: Message taps while the app process is suspended or killed are deferred until post-frame rendering via `WidgetsBinding.instance.addPostFrameCallback`, guaranteeing mounted navigation contexts.
- **Triggers**:
  - A trader they're copying places a trade.
  - A new Copy Trade Request requires approval.
  - An auto-executed trade is filled.

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
  // Risk Guardian & Capital Safeguards (v0.52.0)
  double? maxAllocationPerTrade;      // Dollar cap per trade
  double? maxAllocationPct;           // Portfolio equity % cap (e.g., 5.0%)
  double? maxSlippageBps;             // Slippage abort threshold (e.g., 75 bps)
  bool? autoDisconnectOnDivergence;   // Auto-disconnect circuit breaker toggle
  double? maxLeaderDrawdownPct;       // Drawdown trigger (e.g., 15.0%)
  double? maxReturnDivergencePct;     // Divergence trigger (e.g., 5.0%)
  bool? isRiskGuardianTripped;        // Live trip status flag
  String? riskGuardianTripReason;     // Trip reason
  DateTime? riskGuardianTrippedAt;    // Trip timestamp
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
  sourceUserName?: string;
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
  needsContractAdaptation?: boolean; // Set when 1 contract exceeds allocation cap
  inverseAdaptation?: string; // e.g., 'defined_risk_opposite_option', 'defined_risk_long_flip', 'defined_risk_spread_flip', 'uncovered_short_blocked'
  timestamp: Timestamp;
  executed: boolean;
  status?: 'pending' | 'approved' | 'pending_approval' | 'rejected' | 'completed' | 'failed' | 'aborted';
  executionResult?: 'executed' | 'skipped_max_amount' | 'skipped_max_quantity' | 'aborted_max_slippage' | 'aborted_allocation_limit' | 'aborted_risk_guardian_tripped';
}
```

### Backend Functions

#### onInstrumentOrderCreated

Triggered when a new instrument (stock/ETF) order is created:

1. Checks if the order is filled
2. Finds all investor groups the user belongs to
3. Identifies members who are copying from this user
4. Applies quantity and amount limits
5. Creates copy trade records (capturing `docRef.id` as `recordId`)
6. **Sends push notifications** to target users with trade details, `recordId`, and deep-linking action intents

#### onOptionOrderCreated

Triggered when a new option order is created:

1. Checks if the order is filled
2. Finds all investor groups the user belongs to
3. Identifies members who are copying from this user
4. Validates contract sizing, defined-risk inverse guardrails, and small-account contract-adaptation triggers via `buildCopyOptionOrderPlan` (accounting for 100 shares per contract and enforcing `pending_approval` review when inverse or contract adaptation applies)
5. Creates copy trade records (capturing `docRef.id` as `recordId`)
6. **Sends push notifications** to target users with trade details, `recordId`, and deep-linking action intents

#### Notification System

Push notifications are sent using Firebase Cloud Messaging (FCM):

- Fetches user's FCM tokens from registered devices
- Sends multicast notification to all user devices
- Attaches `recordId`, `sourceUserName`, and `click_action: "FLUTTER_NOTIFICATION_CLICK"` in notification data
- Configures Android `clickAction: "FLUTTER_NOTIFICATION_CLICK"` and APNs category `"COPY_TRADE"`
- Routes directly to `copy_trades` Android notification channel
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

### Unit & Widget Tests

Tests are included across Flutter and Cloud Functions:

- `test/investor_group_model_test.dart`: CopyTradeSettings serialization/deserialization, InvestorGroup copy trade methods, settings storage and retrieval
- `test/copy_trade_risk_guardian_service_test.dart`: Defined-risk inverse option guardrail validation, small-account OTM strike and vertical debit spread suggestions (`OptionContractAdaptation`)
- `test/copy_trade_request_detail_test.dart`: Request detail inspection, inverse guardrail banner rendering, and interactive Contract Adapter card selection
- `functions/tests/copy-trading.test.ts`: Backend `buildCopyOptionOrderPlan` defined-risk inverse mapping and `needsContractAdaptation` gating

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
