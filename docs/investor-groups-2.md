# Investor Groups 2.0 & Collaborative Analytics

Enable rich collaborative social trading within investor groups, featuring real-time trade activity feeds, in-app messaging, collaborative investment analysis boards, and audited verified track records for group leaders.

## Overview

Investor Groups 2.0 transforms community groups into a collaborative trading ecosystem. Members can follow peers' trading activity in real time, engage in threaded group discussions, publish and critique deep investment theses with calculated risk/reward profiles, and review cryptographic and brokerage-audited track records for group leaders.

## Features

### 1. Real-Time Group Activity Feed ([#78](https://github.com/CIInc/robinhood-options-mobile/issues/78), [Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- **Live Stream**: Instant broadcast of member actions including stock, option, and crypto trades, order executions, group joins/leaves, watchlist edits, and milestones.
- **Filtering & Search**: Segment feed by event type (`All`, `Trades`, `Watchlists`, `Members`) or filter by specific group members.
- **Trade Inspection Modal**: Bottom sheet displaying full trade execution metrics, contract details (strike, expiration, call/put), execution price, quantity, and direct actions ("Copy Trade" or "View Instrument").
- **Privacy Controls**: Granular per-group privacy settings allowing members to toggle:
  - `shareTrades`: Enable or pause trade broadcasting to the group.
  - `showTradeAmounts`: Mask dollar amounts and share sizes while showing percentage/direction.
  - `anonymous`: Broadcast actions as "A member" without revealing user identity.

### 2. Group Chat & Real-Time Messaging ([#76](https://github.com/CIInc/robinhood-options-mobile/issues/76), [Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- **In-App Group Messaging**: Real-time Firestore streaming timeline with chat bubbles, relative timestamps, sender avatars, and system announcements.
- **Read Receipts & Unread Counters**: Track unread messages with dynamic badge indicators on group hubs.
- **Message Moderation**: Author and group admin capabilities to delete messages.

### 3. Shared Analysis Boards & Collaborative Theses ([#77](https://github.com/CIInc/robinhood-options-mobile/issues/77), [Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- **Structured Investment Theses**: Publish trade ideas specifying:
  - Symbol and Asset Type (Stock, Option, Crypto).
  - Sentiment (`Bullish`, `Bearish`, `Neutral`).
  - Time Horizon (`Day Trade`, `Swing Trade`, `Short Term`, `Medium Term`, `Long Term`).
  - Entry Price, Target Price, and Stop Loss.
  - Automated calculations for Potential Return % and Risk/Reward Ratio.
- **Discussion & Engagement (Enhanced v0.52.0)**:
  - **Community Sentiment Polling**: Interactive Bullish, Bearish, and Neutral sentiment voting with real-time percentage distribution bars.
  - **Author-Pinned Comments**: Authors and group admins can pin critical comments/guidelines to the top with a distinct `📌 Pinned by author` badge.
  - **Comment Upvoting**: Atomic upvote/like button on individual comments.
  - **Moderation & Reporting**: Flag inappropriate comments with standardized report reasons (spam, manipulation, harassment, offensive) and protective collapse banners.
- **Pinned Theses**: Group admins can pin top research ideas to the top of the analysis board.

### 4. Verified Track Records for Group Leaders ([Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113))
- **Brokerage-Audited Performance**: Dynamic audit engine evaluating realized trades from group activities and brokerage transaction history.
- **Leader Tiers**:
  - **Verified Trader**: Verified brokerage connection and completed trades.
  - **Verified Leader**: Win rate >= 55%, total return >= 10%, minimum 10 trades.
  - **Top Performer**: Win rate >= 60%, total return >= 25%, Sharpe ratio >= 1.2, minimum 20 trades.
  - **Master Trader**: Win rate >= 65%, total return >= 50%, Sharpe ratio >= 1.8, minimum 30 trades.
- **Trust Badges & Audit Sheets**: Verified badges displayed on public group discovery cards and group headers, opening an audit sheet disclosing verified return %, win rate %, Sharpe ratio, profit factor, total trades, and audit date.

## Data Model & Firestore Architecture

```
investor_groups/{groupId}/
  activities/{activityId}
    - id: string
    - groupId: string
    - userId: string
    - userName: string
    - userProfileUrl: string?
    - type: "trade" | "order" | "memberJoined" | "memberLeft" | "watchlistUpdated" | "milestone"
    - timestamp: timestamp
    - title: string
    - description: string?
    - symbol: string?
    - side: "buy" | "sell"?
    - quantity: number?
    - price: number?
    - orderType: string?
    - assetType: "stock" | "option" | "crypto"?
    - strikePrice: number?
    - expirationDate: string?
    - optionType: "call" | "put"?
    - hideAmounts: boolean
    - isAnonymous: boolean

  member_privacy/{userId}
    - shareTrades: boolean (default: true)
    - showTradeAmounts: boolean (default: true)
    - anonymous: boolean (default: false)
    - updatedAt: timestamp

  analyses/{analysisId}
    - id: string
    - groupId: string
    - authorId: string
    - authorName: string
    - symbol: string
    - title: string
    - thesis: string
    - sentiment: "bullish" | "bearish" | "neutral"
    - timeHorizon: "dayTrade" | "swingTrade" | "shortTerm" | "mediumTerm" | "longTerm"
    - entryPrice: number?
    - targetPrice: number?
    - stopLossPrice: number?
    - riskRewardRatio: number?
    - potentialReturnPercent: number?
    - likesCount: number
    - likedBy: string[]
    - isPinned: boolean
    - sentimentVotes: map<string, string> (userId -> "bullish" | "bearish" | "neutral")
    - createdAt: timestamp
    - updatedAt: timestamp

    comments/{commentId}
      - id: string
      - analysisId: string
      - authorId: string
      - authorName: string
      - content: string
      - isPinned: boolean
      - likes: string[]
      - isReported: boolean
      - reportReason: string?
      - reportedBy: string[]
      - createdAt: timestamp

  messages/{messageId}
    - id: string
    - senderId: string
    - senderName: string
    - message: string
    - timestamp: timestamp
    - readBy: string[]

verified_track_records/{userId}
  - userId: string
  - userName: string
  - isVerified: boolean
  - verifiedReturnPercent: number
  - winRatePercent: number
  - totalTrades: number
  - profitableTrades: number
  - sharpeRatio: number?
  - profitFactor: number?
  - tier: "verifiedTrader" | "verifiedLeader" | "topPerformer" | "masterTrader"
  - auditedAt: timestamp
  - verificationSignature: string?
```

## Security Rules & Indexes

- **Group Privacy & Access**: Only authenticated group members can read group activities, chat messages, and shared analysis boards.
- **Admin Privileges**: Only group creators/admins can pin analysis posts.
- **Leader Track Records**: Publicly readable across all authenticated users to facilitate trustworthy discovery in public group listings, while updates are restricted to the audit engine or owner.
- **Composite Indexes**:
  - `investor_groups/{groupId}/activities`: `timestamp` DESC.
  - `investor_groups/{groupId}/analyses`: `isPinned` DESC, `createdAt` DESC.
  - `investor_groups/{groupId}/messages`: `timestamp` DESC.

## UI Integration

- **`InvestorGroupDetailWidget`**: Central hub embedding:
  - Verified leader tier badge and interactive audit details sheet.
  - Real-time Group Activity Feed preview card with live count and recent trade ticker.
  - Shared Analysis Board card with active post counters and navigation.
  - Group Chat quick access with unread count badges.
- **`InvestorGroupsWidget`**: Displays verified leader badges (`Verified Leader +28%`, `Top Performer +64%`) on public group cards to guide user discovery.
- **`InvestorGroupAnalysisBoardWidget`**: Full-screen thesis workspace with sentiment filter chips, risk/reward preview cards, thesis drafting modal, and threaded comment bottom sheet.
