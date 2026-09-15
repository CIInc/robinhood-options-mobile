# Shareholder Say Q&A Engagement

## Overview

Robinhood acquired **Say Technologies** to empower retail shareholders with direct participation in corporate governance and earnings calls. Through Say Technologies integration, retail investors can:
1. **View Upcoming & Active Q&A Events**: Discover upcoming earnings calls, annual shareholder meetings, and investor day events for held and watched companies.
2. **Submit Questions**: Verified shareholders who own equity in a company can directly post questions to be asked of corporate leadership (CEOs, CFOs, IR teams).
3. **Vote with Share-Weighting**: Every upvote is weighted by the voter's verified share ownership, giving retail shareholders collective bargaining power to push critical questions to the top of executive agendas.
4. **Read Executive Answers**: Review transcribed and audio/video timestamped answers provided directly by executive management (e.g., Tim Cook, Elon Musk, Jensen Huang) during live calls.

---

## Architecture & Data Flow

### 1. Data Models (`lib/model/shareholder_qa_event.dart`)

The feature is built on four core immutable data structures:

- **`ShareholderAnswer`**:
  - Encapsulates executive responses provided during or after earnings calls.
  - Fields: `id`, `answerText`, `answeredBy` (e.g., "Tim Cook"), `answeredByTitle` (e.g., "CEO"), `answeredAt`, `videoTimestampSeconds` (with formatted `mm:ss` timestamp), and `sourceUrl`.

- **`ShareholderQuestion`**:
  - Individual questions submitted by verified shareholders.
  - Fields: `id`, `eventId`, `text`, `status` (`approved`, `answered`, `pending`), `authorDisplayName`, `isVerifiedShareholder`, `votesCount`, `sharesRepresented`, `percentageOfTotalShares`, `isUserVoted`, `createdAt`, and `answer`.
  - Helper getters: `isAnswered`, `formattedVotes` (`1.4K`), and `formattedShares` (`2.5M`).

- **`ShareholderQaEvent`**:
  - An earnings call or shareholder meeting event accepting questions and votes.
  - Fields: `id`, `title`, `eventType`, `status`, `companyName`, `symbol`, `instrumentId`, `eventDate`, `submissionDeadline`, `votingDeadline`, `description`, `webcastUrl`, `totalQuestionsCount`, `totalVotesCount`, `totalSharesRepresented`, `userSharesRepresented`, `isUserVerified`, and `questions`.
  - Helper getters: `isOpen`, `isVotingOpen`, `isSubmissionOpen`, `formattedEventDate`, `formattedDeadline`, and compact number formatters.

- **`ShareholderQaSection`**:
  - Container representing the complete Q&A status for an instrument.
  - Fields: `instrumentId`, `symbol`, and `events`.
  - Helper getters: `hasEvents`, `activeEvent`.

---

## Service Layer (`IBrokerageService`)

The brokerage abstraction in `lib/services/` provides consistent interfaces across providers:

```dart
// Fetch all Q&A events and questions for an instrument
Future<dynamic> getShareholderQaEvents(BrokerageUser user, String instrumentId);

// Typed section model accessor
Future<ShareholderQaSection?> getShareholderQaSectionModel(
    BrokerageUser user, String instrumentId, {String? symbol});

// Upvote or retract vote on a question
Future<bool> upvoteQuestion(BrokerageUser user, String instrumentId,
    String eventId, String questionId);

// Submit a new verified shareholder question
Future<ShareholderQuestion?> submitQuestion(BrokerageUser user,
    String instrumentId, String eventId, String questionText);
```

### Endpoints
- **Robinhood API (`RobinhoodService`)**:
  - Events & Questions: `GET /instruments/{instrument_id}/qa/events-section/` via Bonfire API.
  - Upvote: `POST /qa/events/{event_id}/questions/{question_id}/upvote/`
  - Question Submission: `POST /qa/events/{event_id}/questions/`
- **Demo Mode (`DemoService`)**:
  - Realistic mock data for AAPL, TSLA, NVDA, and a dynamic procedural fallback for any stock ticker.
  - Full in-memory mutation state: upvoting toggles question vote counts and share weighting, and new submissions appear immediately at the top of the event question queue.

---

## User Interface & Experience

### 1. Embedded Card: `ShareholderQaCard` (`lib/widgets/shareholder_qa_widget.dart`)
- Positioned inside the **Financials** section of `InstrumentWidget` for equity instruments.
- Displays the active event badge, event title, the #1 top-voted question, total vote and share statistics, and a one-tap call to action to open the full dashboard.

### 2. Full Dashboard: `ShareholderQaWidget` (`lib/widgets/shareholder_qa_widget.dart`)
- **Event Header**:
  - Event title, company name, date & time, and status badge (`Open for Voting`, `Upcoming`, `Concluded`).
- **Verified Shareholder Banner**:
  - Prominently informs the user of their verified shareholder status, number of shares owned, and their voting weight in the event.
- **Search & Filter Controls**:
  - Instant text search across all questions and answers.
  - Filter chips: `Top (Shares)`, `Most Votes`, `Answered`, and `My Votes`.
- **Question Cards**:
  - Rank number, question text, verified author label.
  - Metric badges showing total votes and total shares represented.
  - Interactive **Upvote** toggle with immediate optimistic UI feedback and confirmation snackbars.
  - **Executive Answer Callout**: Highlighting responses from leadership with speaker avatars, titles, and video/audio seek timestamps.
- **Question Submission Bottom Sheet**:
  - Modal sheet with character validation (10 - 280 characters), verified share acknowledgement, and instant submission.

### 3. Entry Points
- **Instrument Detail Page**: `ShareholderQaCard` inside `InstrumentWidget` slivers.
- **User Profile Page**: "Shareholder Q&A (Say)" row in `UserWidget` under "Profile & Community".
- **User Info Page**: Feature badge chip in `UserInfoWidget`.

---

## Testing & Validation

- **Unit Tests (`test/shareholder_qa_test.dart`)**:
  - JSON serialization and parsing of `ShareholderAnswer`, `ShareholderQuestion`, `ShareholderQaEvent`, and `ShareholderQaSection`.
  - Formatting helpers (compact numbers, date strings, timestamps).
  - `DemoService` operations: Q&A section retrieval, upvote toggling, question submissions, and dynamic symbol fallback.
- **Widget Tests (`test/shareholder_qa_widget_test.dart`)**:
  - Component rendering of header, shareholder banner, filter chips, question cards, and answer quotes.
  - Filter interaction by "Answered".
  - Upvote button interaction.
  - Modal bottom sheet opening and dismissal for question submission.
  - `ShareholderQaCard` rendering and navigation callback.
