# Top Portfolios Leaderboard

The Top Portfolios feature provides a comprehensive leaderboard system that showcases top-performing portfolios in the community, enabling users to discover and follow successful traders.

## Features

### Performance Rankings
- **Real-time leaderboard**: Dynamic rankings based on portfolio performance metrics
- **Multiple time periods**: Filter by 1D, 1W, 1M, 3M, 1Y, or All Time
- **Rank changes**: Visual indicators showing rank improvements or declines
- **Detailed metrics**: View comprehensive performance statistics for each portfolio

### Privacy Controls
- **Public/Private toggle**: Users control whether their portfolio appears on the leaderboard
- **Opt-in system**: Portfolios are private by default
- **Selective sharing**: Performance metrics are public, but specific holdings remain private

### Social Features
- **Follow system**: Follow top performers to track their performance
- **Filtered views**: Toggle to show only followed portfolios
- **User profiles**: View detailed performance metrics and trading statistics

### Performance Metrics

Each leaderboard entry displays:
- **Returns**: Absolute and percentage returns across all time periods
- **Portfolio value**: Current total value
- **Trading stats**: Total trades, win rate, winning/losing trades
- **Risk metrics**: Sharpe ratio and maximum drawdown
- **Rank**: Current position and rank change indicator

## Architecture

### Data Models

#### PortfolioPerformance
Stores comprehensive performance metrics for each user:
- User identification (ID, name, avatar)
- Return values for all time periods (day, week, month, 3-month, year, all-time)
- Trading statistics (total trades, wins, losses, win rate)
- Risk metrics (Sharpe ratio, max drawdown)
- Privacy settings (isPublic flag)
- Ranking information (current rank, previous rank)

#### LeaderboardTimePeriod
Enum defining available time periods:
- Day (1D)
- Week (1W)
- Month (1M)
- Three Months (3M)
- Year (1Y)
- All Time (All)

#### FollowStatus
Tracks follow relationships between users:
- Follower ID
- Followee ID
- Follow timestamp

### Firebase Functions

#### calculateLeaderboard (Scheduled)
- **Schedule**: Daily at 6 PM ET
- **Purpose**: Calculate and update all leaderboard rankings
- **Process**:
  1. Fetch all users with public portfolios
  2. Calculate performance metrics for each user
  3. Compute returns for all time periods
  4. Calculate trading statistics and risk metrics
  5. Rank portfolios by return percentage
  6. Store results in `portfolio_leaderboard` collection

#### calculateLeaderboardManual (Callable)
- **Purpose**: Admin-triggered manual leaderboard calculation
- **Authentication**: Requires authenticated user
- **Usage**: For testing or immediate updates

#### updatePortfolioPublicStatus (Callable)
- **Purpose**: Toggle portfolio public/private status
- **Parameters**: `isPublic` (boolean)
- **Process**:
  1. Update user's `portfolioPublic` flag
  2. If making private, remove from leaderboard
  3. Next scheduled run will add public portfolios

### State Management

#### LeaderboardStore
Provider managing leaderboard state and operations:
- **Real-time subscriptions**: Listens to Firestore for live updates
- **Filtering**: Supports time period and followed-only filters
- **Follow management**: Follow/unfollow operations
- **Rankings**: Dynamic re-ranking based on selected period
- **Error handling**: Graceful error states and user feedback

Key methods:
- `setTimePeriod(period)`: Change time filter and re-rank
- `toggleShowOnlyFollowed()`: Filter for followed users only
- `followUser(userId)`: Follow a user
- `unfollowUser(userId)`: Unfollow a user
- `toggleFollow(userId)`: Toggle follow state
- `updatePortfolioPublicStatus(isPublic)`: Update privacy setting
- `calculateLeaderboard()`: Trigger manual calculation (admin)

### UI Components

#### LeaderboardWidget
Main leaderboard interface:
- **Time period chips**: Horizontal filter bar for period selection
- **Leaderboard list**: ScrollView with performance cards
- **Entry cards**: Display rank, user info, performance metrics, follow button
- **Detail dialog**: Modal with comprehensive metrics and follow action
- **Settings dialog**: Portfolio privacy configuration
- **Error banner**: User-friendly error messages
- **Empty states**: Guidance when no data available

Features:
- Pull-to-refresh for manual updates
- Visual rank change indicators (up/down arrows)
- Color-coded performance (green for positive, red for negative)
- Rank badges with movement indicators
- Follow/unfollow buttons with heart icons

## Firestore Structure

### Collections

#### `portfolio_leaderboard/{userId}`
Stores calculated performance metrics:
```
{
  userName: string
  userAvatarUrl: string?
  totalReturn: number
  returnPercentage: number
  portfolioValue: number
  dayReturn: number
  dayReturnPercentage: number
  weekReturn: number
  weekReturnPercentage: number
  monthReturn: number
  monthReturnPercentage: number
  threeMonthReturn: number
  threeMonthReturnPercentage: number
  yearReturn: number
  yearReturnPercentage: number
  allTimeReturn: number
  allTimeReturnPercentage: number
  totalTrades: number
  winningTrades: number
  losingTrades: number
  winRate: number
  sharpeRatio: number
  maxDrawdown: number
  isPublic: boolean
  lastUpdated: timestamp
  rank: number
  previousRank: number?
}
```

#### `portfolio_follows/{followerId}_{followeeId}`
Tracks follow relationships:
```
{
  followerId: string
  followeeId: string
  followedAt: timestamp
}
```

#### `portfolio_historicals/{userId}_{date}`
Stores daily portfolio snapshots for performance calculations:
```
{
  userId: string
  date: timestamp
  equity: number
  adjustedCloseEquity: number
  updatedAt: timestamp
}
```

**Data Flow**:
- Client app fetches portfolio historicals from brokerage API
- `PortfolioHistoricalsStore` processes the data
- When values change, latest snapshot is saved to Firestore
- Backend functions query this collection for performance calculations
- Document ID format: `{userId}_{YYYY-MM-DD}` ensures one entry per user per day

**Purpose**:
- Enables backend functions to calculate returns across time periods
- Provides historical data for Sharpe ratio and max drawdown calculations
- Automatically populated when users refresh their portfolio data
- No manual intervention required after initial app usage

#### `users/{userId}` (extended)
Additional fields for leaderboard:
```
{
  portfolioPublic: boolean
  portfolioPublicUpdatedAt: timestamp
  portfolioValue: number (current value, auto-updated)
  portfolioValueUpdatedAt: timestamp
}
```

**Auto-sync**: `portfolioValue` is automatically updated whenever portfolio historicals are refreshed in the app, ensuring leaderboard always has current values.

### Security Rules

#### portfolio_leaderboard
- **Read**: Anyone can read public entries (`isPublic == true`)
- **Write**: Only backend functions can write
- **Purpose**: Ensures data integrity and prevents tampering

#### portfolio_follows
- **Read**: Users can read their own follows
- **Create**: Users can create follows for themselves
- **Delete**: Users can delete their own follows
- **Update**: Not allowed
- **Purpose**: Users control their own follow lists

#### portfolio_historicals
- **Read**: Users can read their own historical data; admins can read all
- **Create/Update**: Users can write their own historical data points
- **Delete**: Only admins can delete
- **Purpose**: 
  - Users' app automatically populates data when refreshing portfolios
  - Backend functions (with admin privileges) access all data for leaderboard calculations
  - Prevents unauthorized access to users' historical performance data

## User Flows

### Making Portfolio Public
1. User opens leaderboard
2. Clicks settings icon in app bar
3. Views privacy dialog explaining public visibility
4. Clicks "Make Public" button
5. System updates `users/{uid}.portfolioPublic = true`
6. Next scheduled run includes portfolio in leaderboard

### Following a Top Performer
1. User views leaderboard
2. Scrolls to find interesting portfolio
3. Taps heart icon or entry card
4. For entry card: Detail dialog opens with comprehensive metrics
5. Clicks follow button
6. System creates `portfolio_follows/{followerId}_{followeeId}` document
7. Follow status updates in real-time

### Viewing Detailed Metrics
1. User taps on leaderboard entry
2. Detail dialog displays:
   - User avatar and name
   - Current rank
   - Portfolio value
   - Performance across all time periods
   - Trading statistics
   - Risk metrics
   - Last updated timestamp
3. User can follow/unfollow from dialog

### Filtering by Time Period
1. User views leaderboard
2. Taps time period chip (1D, 1W, 1M, 3M, 1Y, All)
3. System re-ranks portfolios based on selected period return
4. Leaderboard updates with new rankings
5. Rank changes reflect movement for selected period

### Viewing Followed Portfolios
1. User taps heart icon in app bar
2. System filters leaderboard to show only followed users
3. Rankings adjust to reflect followed users only
4. Tap again to show all public portfolios

## Performance Calculations

### Return Calculations
For each time period:
1. Find historical portfolio value at period start date
2. Calculate absolute return: `currentValue - startValue`
3. Calculate percentage return: `(absolute / startValue) * 100`
4. Store both values for display flexibility

### Trading Statistics
- **Total Trades**: Count of filled orders
- **Winning Trades**: Trades with positive P&L
- **Losing Trades**: Trades with negative P&L
- **Win Rate**: `(winningTrades / totalTrades) * 100`

### Risk Metrics
- **Sharpe Ratio**: Annualized risk-adjusted return
  - Calculate daily returns from portfolio historicals
  - Compute mean and standard deviation
  - Formula: `(avgReturn / stdDev) * sqrt(252)`
- **Max Drawdown**: Largest peak-to-trough decline
  - Track peak portfolio value
  - Calculate drawdown at each point
  - Return maximum observed drawdown percentage

## Integration Points

### Navigation
- Accessible from main drawer menu as "Top Portfolios"
- Icon: leaderboard icon
- Tab index: 5 (after Investor Groups)

### Providers
- `LeaderboardStore` added to MultiProvider in main.dart
- Initialized with Firebase instances
- Real-time subscriptions active throughout app lifecycle

### Dependencies
- Firebase Functions (scheduled and callable)
- Firestore (real-time subscriptions)
- Firebase Auth (user identification)
- Cloud Functions (backend processing)
- FirestoreService (portfolio historical data persistence)

### Data Synchronization
- **Automatic**: Portfolio historicals sync happens automatically when users refresh their portfolio data
- **Implementation**: `PortfolioHistoricalsStore` triggers `FirestoreService.savePortfolioHistorical()` when data changes
- **Frequency**: Updates occur whenever the app fetches new portfolio data (pull-to-refresh, app resume, periodic updates)
- **No User Action**: Historical data population requires no user intervention beyond normal app usage
- **Storage**: One document per user per day, using merge to avoid duplicates

## Development Notes

### Testing
- Use `calculateLeaderboardManual` callable for immediate testing
- Set `portfolioPublic = true` on test users in Firestore
- Portfolio historicals automatically populate when users refresh portfolio data in app
- To manually add test data: create `portfolio_historicals/{userId}_{YYYY-MM-DD}` documents
- Test with various time periods and ranking scenarios
- Verify automatic sync by checking Firestore after portfolio refresh

### Performance Considerations
- Scheduled function runs once daily to minimize costs
- Client uses real-time subscriptions for instant updates
- Rankings computed on-demand based on selected period
- Indexes required:
  - `portfolio_leaderboard`: filtered by `isPublic`, sorted by return percentages
  - `portfolio_historicals`: `userId` (asc), `date` (asc) for time-series queries
- Historical data storage: ~365 documents per user per year (one per day)

### Future Enhancements
- Leaderboard for specific strategies (options, stocks, etc.)
- Regional/country-based leaderboards
- Friend-only leaderboards
- Achievement badges for milestones
- Historical rank tracking over time
- Portfolio comparison tools
- Notification when followed traders make moves

## Maintenance

### Monitoring
- Check Cloud Functions logs for calculation errors
- Monitor Firestore read/write costs
- Track leaderboard engagement metrics with Firebase Analytics

### Updates
- Backend calculations in `functions/src/leaderboard.ts`
- Client state in `lib/model/leaderboard_store.dart`
- UI in `lib/widgets/leaderboard_widget.dart`
- Rules in `firebase/firestore.rules`

## Privacy & Security

- Holdings and specific trades never exposed
- Only aggregate performance metrics are public
- Users must explicitly opt-in to appear on leaderboard
- Follow relationships are private (only visible to follower)
- Backend functions prevent data manipulation
- Security rules enforce read/write permissions
