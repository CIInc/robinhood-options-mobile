# Social Discussion & Comment Threads

> Introduced in **v0.52.0** ([Tracking: #113](https://github.com/CIInc/robinhood-options-mobile/issues/113)). Provides granular community discussions on shared trade ideas and public portfolios, complete with author-pinned comments, community sentiment polling, comment upvoting, and moderation reporting.

## Overview

The Social Discussion & Comment Threads system enhances RealizeAlpha's social foundation by enabling interactive, structured dialogue across investment theses, trade ideas, and public trader portfolios. Users can critique setups, discuss market catalysts, and participate in community consensus polling while authors and moderators maintain high-quality discussions through pinning and reporting guardrails.

## Features

### 1. Community Sentiment Polling
- **Interactive Sentiment Voting**: Group members and followers can cast their market sentiment (`Bullish`, `Neutral`, or `Bearish`) on shared trade ideas and public portfolios.
- **Segmented Visual Distribution**: Multi-color progress bars reflect real-time percentages and vote tallies across each sentiment bucket.
- **Atomic Vote Toggling**: Tap a sentiment option to vote, or tap the same option again to withdraw your vote.
- **Consensus Comparison**: Directly contrast the thesis author's outlook against community sentiment.

### 2. Author-Pinned Comments
- **Elevated Visibility**: Authors of investment theses and owners of public portfolios (as well as group/platform admins) can pin high-value comments to the top of the discussion thread.
- **Visual Distinction**: Pinned comments display a clear `📌 Pinned by author` badge with a highlighted primary-container background border.
- **Dynamic Pin/Unpin**: Toggled seamlessly via the comment action menu.

### 3. Comment Upvoting
- **Like / Upvote Counter**: Community members can upvote helpful responses, questions, and insights.
- **Atomic Toggle**: Tapping the upvote button increments or decrements the count and updates the user's active state.
- **Leaderboard Reputation**: Top upvoted comments help surface expert commentary and peer consensus.

### 4. Moderation & Safety Reporting
- **Community Reporting**: Any member can flag a comment for moderation via a contextual modal dialog.
- **Standardized Categories**:
  - *Spam or advertising*
  - *Misinformation / Market manipulation*
  - *Harassment or hate speech*
  - *Inappropriate or offensive content*
- **Reported Content Protection**: Comments reported by the current user are collapsed behind a protective banner (`Comment reported by you under review`), with a tap-to-reveal toggle.
- **Admin Moderation & Deletion**: Authors of comments, thesis authors, portfolio owners, and group admins have direct deletion privileges to enforce community standards.

### 5. Shared Portfolio Q&A & Discussion
- **Public Trader Profiles**: Added directly to public portfolios on `TraderProfileWidget`.
- **Trader Community Outlook**: Visitors can vote on their market outlook for the trader's asset allocation.
- **Direct Engagement**: Followers can ask strategy questions, clarify entry logic, and receive pinned guidance from verified leaders.
- **Privacy Enforcement**: Discussion is automatically hidden when a trader configures their portfolio as private.

## Architecture & Data Model

### `GroupAnalysisComment`
```dart
class GroupAnalysisComment {
  final String id;
  final String analysisId; // Post ID or Target User ID
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String content;
  final bool isPinned;
  final List<String> likes;
  final bool isReported;
  final String? reportReason;
  final List<String> reportedBy;
  final DateTime createdAt;
}
```

### Firestore Paths
- **Investor Group Analyses**: `investor_groups/{groupId}/analyses/{analysisId}/comments/{commentId}`
  - Pinned comments and comment likes stored in the comment document.
  - Sentiment votes stored on the post: `investor_groups/{groupId}/analyses/{analysisId}` (`sentimentVotes: Map<String, String>`).
- **Shared Portfolios**: `user/{userId}/portfolio_comments/{commentId}`
  - Portfolio sentiment votes stored on user profile: `user/{userId}` (`portfolioSentimentVotes: Map<String, String>`).
