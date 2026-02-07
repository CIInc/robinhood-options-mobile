# Group-Based Watchlists

Enable collaborative watchlists shared within investor groups, allowing members to collectively track symbols with real-time synchronization and price alerts.

## Overview

Group-Based Watchlists extend investor group functionality by enabling teams to create and manage shared watchlists within a group context. Members can collaborate on tracking securities, with role-based access control to manage permissions.

## Features

### Core Functionality

1. **Create Group Watchlists** - Group members can create watchlists within their group
   - Each watchlist has a name and description
   - Creator automatically becomes an editor
   - All other group members are automatically viewers by convention
   - New group members automatically have viewer access (no explicit storage needed)
   - Private to group members only

2. **Add/Remove Symbols** - Editors can manage watchlist contents
   - Add stocks, options, or other symbols
   - Remove symbols and associated alerts
   - Real-time sync across all members viewing the watchlist

3. **Member Permissions** - Role-based access control
   - **Editor**: Can add/remove symbols and create/manage price alerts (stored explicitly in permissions)
   - **Viewer**: Can view watchlist contents but cannot make modifications (membership determined by group membership, not stored)
   - Creator can promote group members to editors
   - Editors can change other members' permissions (except creator)
   - New group members automatically have viewer access without needing any updates

4. **Real-Time Synchronization** - Firestore listeners keep members in sync
   - Changes to watchlist contents appear instantly
   - New alerts are reflected across devices
   - Deletions are propagated in real-time

5. **Price Alerts** - Track price movements for watchlist symbols
   - **Price Above** - Alert when price crosses above a threshold
   - **Price Below** - Alert when price drops below a threshold
   - Alerts are active/inactive toggleable
   - Multiple alerts per symbol supported

## Data Model

```
investor_groups/{groupId}/
  watchlists/{watchlistId}/
    - name: string
    - description: string
    - createdBy: userId (creator/initial editor)
    - createdAt: timestamp
    - updatedAt: timestamp
    - permissions: {
        [userId]: "editor"  // Only contains explicit editors
      }
    // Note: All group members not in permissions are "viewers" by convention
    // This means new group members automatically have viewer access
    
    symbols/{symbolId}/
      - symbol: string (uppercase)
      - addedBy: userId
      - addedAt: timestamp
      
      alerts/{alertId}/
        - type: "price_above" | "price_below"
        - threshold: number
        - active: boolean
        - createdAt: timestamp
```

## Security Model

### Firestore Rules

Each watchlist enforces member-level permissions:

- **Read Access**: All group members can view watchlist (by convention, not explicitly stored)
- **Write Access**: Only editors (stored in permissions) and creators can modify
- **Permission Management**: Only creators and existing editors can grant/revoke editor permissions

Permissions logic:
- If user is in `permissions` map with "editor" role → editor access
- If user is in parent group but NOT in permissions → viewer access (by convention)
- No access if user is not in parent group

Rules validate at multiple levels:
- Parent group membership is verified
- Watchlist-specific permissions are checked for write operations
- Symbol-level access inherits watchlist permissions
- Alerts require editor access on parent watchlist

### Firebase Functions

All operations are protected with authentication checks:
- Functions verify user is authenticated
- User group membership is validated
- Permissions are enforced server-side (explicit editors) and by convention (viewers)
- Invalid operations return specific error messages

## APIs

### Backend Functions

```typescript
// Create watchlist
createGroupWatchlist(data: {
  groupId: string;
  name: string;
  description: string;
}): { success: boolean; watchlistId: string }

// Delete watchlist (creator only)
deleteGroupWatchlist(data: {
  groupId: string;
  watchlistId: string;
}): { success: boolean }

// Add symbol to watchlist
addSymbolToWatchlist(data: {
  groupId: string;
  watchlistId: string;
  symbol: string;
}): { success: boolean }

// Remove symbol from watchlist
removeSymbolFromWatchlist(data: {
  groupId: string;
  watchlistId: string;
  symbol: string;
}): { success: boolean }

// Create price alert
createPriceAlert(data: {
  groupId: string;
  watchlistId: string;
  symbol: string;
  type: "price_above" | "price_below";
  threshold: number;
}): { success: boolean; alertId: string }

// Delete price alert
deletePriceAlert(data: {
  groupId: string;
  watchlistId: string;
  symbol: string;
  alertId: string;
}): { success: boolean }

// Set member permission
setWatchlistMemberPermission(data: {
  groupId: string;
  watchlistId: string;
  memberId: string;
  permission: "editor" | "viewer";
}): { success: boolean }

// Remove member permission
removeWatchlistMemberPermission(data: {
  groupId: string;
  watchlistId: string;
  memberId: string;
}): { success: boolean }
```

### Service Layer

The `GroupWatchlistService` in `lib/services/group_watchlist_service.dart` provides:

```dart
// Streams
Stream<List<GroupWatchlist>> getGroupWatchlistsStream(String groupId)
Stream<GroupWatchlist?> getWatchlistStream({
  required String groupId,
  required String watchlistId,
})
Stream<List<WatchlistSymbol>> getWatchlistSymbolsStream({
  required String groupId,
  required String watchlistId,
})
Stream<List<WatchlistAlert>> getSymbolAlertsStream({
  required String groupId,
  required String watchlistId,
  required String symbol,
})

// CRUD Operations
Future<String> createGroupWatchlist({...})
Future<void> deleteGroupWatchlist({...})
Future<void> addSymbolToWatchlist({...})
Future<void> removeSymbolFromWatchlist({...})
Future<String> createPriceAlert({...})
Future<void> deletePriceAlert({...})
Future<void> updateWatchlist({...})
Future<void> setWatchlistMemberPermission({...})
Future<void> removeWatchlistMemberPermission({...})
```

## User Interface

### Widgets

1. **`GroupWatchlistsWidget`**
   - Parent widget showing all watchlists in a group
   - Lists watchlists with member count and permission level
   - Allows creating, editing, and deleting watchlists
   - Navigation to detail view

2. **`GroupWatchlistDetailWidget`**
   - Main detail view with 3 tabs:
     - **Symbols Tab**: View/manage watchlist symbols
     - **Alerts Tab**: View alerts per symbol, create new alerts
     - **Settings Tab**: Watchlist metadata and member permissions

3. **`GroupWatchlistCreateWidget`**
   - Dialog for creating new watchlist
   - Input fields for name and description
   - Error handling and loading states

### Integration Points

Add to investor group detail widget:
```dart
// In investor_group_detail_widget.dart
GroupWatchlistsWidget(
  brokerageUser: widget.brokerageUser,
  groupId: widget.groupId,
)
```

## Usage Flow

### Creating a Watchlist

1. User navigates to group's watchlist section
2. Clicks "Create Watchlist" button
3. Enters name and description
4. System creates watchlist with user as editor
5. User can immediately add symbols

### Adding Symbols

1. Open watchlist detail view
2. Go to "Symbols" tab
3. Click "Add Symbol" button (if editor)
4. Enter symbol (e.g., AAPL)
5. Symbol added and synced to other members in real-time

### Managing Alerts

1. Go to "Alerts" tab
2. Expand a symbol
3. Click "Add Alert"
4. Select alert type (Price Above/Below)
5. Enter threshold price
6. Alert created and monitored

### Configuring Permissions

1. Go to "Settings" tab
2. See all editors and viewers (viewers are group members not promoted to editors)
3. To make someone an editor, click menu on their name and select "Promote to Editor"
4. To make someone a viewer, click menu and select "Demote to Viewer"
5. New group members automatically have viewer access by convention

## Real-Time Synchronization

Watchlists use Firestore snapshot listeners for real-time updates:

- **Add Symbol**: All members viewing the watchlist see it instantly
- **Remove Symbol**: Deletion propagates across connected devices
- **Update Alert**: Alert status changes sync in real-time
- **Member Permissions**: Permission changes take effect immediately

## Error Handling

Functions return specific error messages:

- `unauthenticated` - User not logged in
- `not-found` - Watchlist, group, or member not found
- `permission-denied` - User lacks required permission
- `invalid-argument` - Invalid permission value or data

## Firestore Indexes

No additional indexes required. Queries use indexed fields:
- `investor_groups.members` (existing index)
- `createdAt` (compound with groupId)

## Deployment

### Functions

Deploy group watchlist functions with:
```bash
cd src/robinhood_options_mobile/functions
firebase deploy --only functions
```

### Security Rules

Update Firestore rules:
```bash
firebase deploy --only firestore:rules
```

## Future Enhancements

1. **Price Alert Notifications** - FCM push notifications when alerts trigger
2. **Multi-Symbol Alerts** - Alerts spanning multiple symbols
3. **Custom Indicators** - Technical analysis-based alerts
4. **Watchlist Templates** - Pre-built watchlists for common strategies
5. **Export/Import** - CSV export of watchlist contents
6. **Historical Tracking** - Track symbol additions/removals over time
7. **Performance Analytics** - Watchlist performance metrics vs benchmarks
8. **Collaboration Features** - Comments on watchlists and symbols

## Testing

Unit tests for the service layer:
```dart
// Example test
testWidgets('Add symbol to watchlist', (WidgetTester tester) async {
  final service = GroupWatchlistService();
  await service.addSymbolToWatchlist(
    groupId: 'test-group',
    watchlistId: 'test-list',
    symbol: 'AAPL',
    addedBy: 'user123',
  );
  // Stream should emit updated watchlist
});

testWidgets('Permission denied for viewers', (WidgetTester tester) async {
  // Test that viewers cannot add symbols
});
```

## Acceptance Criteria Met

- ✅ Create group watchlists
- ✅ Add/remove symbols  
- ✅ Member permissions (editor/viewer roles)
- ✅ Permission management (change/remove permissions)
- ✅ Automatic member access (all group members are viewers)
- ✅ Real-time sync via Firestore listeners
- ✅ Price alerts (above/below thresholds)

## Related Features

- [Investor Groups](./investor-groups.md) - Base group functionality
- [Copy Trading](./copy-trading.md) - Similar collaborative trading feature
- [Trade Signal Notifications](./trade-signal-notifications.md) - Alert notification system
