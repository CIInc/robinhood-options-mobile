# Copy Trading Feature

## Overview

The Copy Trading feature allows members of investor groups to automatically or manually copy trades from other group members. This feature supports both stock/ETF trades and options trades.

## Features

### 1. Copy Trade Settings

Members can configure copy trading settings for each investor group they belong to:

- **Enable/Disable**: Turn copy trading on or off
- **Select Target User**: Choose which group member's trades to copy
- **Auto-Execute**: Automatically execute trades without manual confirmation
- **Max Quantity**: Limit the maximum number of shares/contracts to copy
- **Max Amount**: Limit the maximum dollar amount per trade
- **Override Price**: Use current market price instead of the copied trade's price

### 2. Manual Copy Trading

When viewing another member's portfolio in a private group:

- A copy button appears next to each filled order (stocks, ETFs, and options)
- Clicking the button shows a confirmation dialog with trade details
- Settings are applied automatically (quantity/amount limits)
- User confirms before the trade is executed
- **Orders are immediately placed** via the brokerage service
- Success/error feedback shown with color-coded messages

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

1. ~~**Actual Order Execution**: Implement the brokerage API integration to execute copied orders~~ ✅ **COMPLETED**
2. ~~**Notifications**: Notify users when trades are copied~~ ✅ **COMPLETED**
3. **Copy Trade Dashboard**: View history of all copied trades
4. **Approval Workflow**: Review and approve auto-copied trades before execution
5. **Auto-Execute for Copy Trades**: Implement client-side automatic execution for flagged copy trades

### Medium Priority

5. **Performance Tracking**: Track success rate of copied trades
6. **Partial Copying**: Support copying a percentage of the original trade
7. **Time-based Filtering**: Only copy trades during specific hours
8. **Symbol Filtering**: Allow/block specific symbols or sectors
9. **Copy Stop Loss/Take Profit**: Automatically copy exit strategies

### Low Priority

10. **Social Features**: See which members are most copied
11. **Copy Trade Templates**: Save and reuse configuration presets
12. **Multi-user Copying**: Copy from multiple users simultaneously
13. **Inverse Copying**: Do the opposite of what someone else does
14. **Copy Trading Groups**: Create groups specifically for copy trading

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
- [ ] Click copy button on a trade
- [ ] Verify confirmation dialog shows correct details
- [ ] Verify limits are applied correctly
- [ ] Confirm the order is placed successfully
- [ ] Check order appears in your account
- [ ] Test with both stock and option orders
- [ ] Verify error handling for failed orders

### Backend Function Testing

1. Deploy functions: `firebase deploy --only functions`
2. Create test orders in user collections
3. Verify copy trade records are created
4. Check logs for errors
5. Verify security rules prevent unauthorized access

## Deployment

### Frontend Changes

The Flutter app changes are automatically included in the normal app build process.

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

## Limitations

1. ~~**No Actual Execution**: The current implementation creates copy trade records but doesn't execute orders.~~ ✅ **FIXED** - Manual copy trades now execute immediately via brokerage API.

2. **Auto-Execute Not Implemented**: While manual copy trades work, automatic execution when auto-execute is enabled still requires implementation.

3. **Single Target**: Users can only copy from one member per group at a time.

4. **No Inverse Copying**: Cannot automatically do the opposite of another user's trades.

5. **No Filtering**: Cannot filter by symbol, time, or other criteria (yet).

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
