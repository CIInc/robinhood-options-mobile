# AI Trade Post-Mortem & Behavioral Journal Auto-Tagger

## Overview

The **AI Trade Post-Mortem & Behavioral Journal Auto-Tagger** (`TradePostMortemAnalysis`, `TradePostMortemSheet`, `analyzeTradePostMortem`) provides an automated, objective diagnostic review immediately upon closing an equity or options position. It evaluates trade execution quality independently of P&L outcome, identifies cognitive biases, catalogs execution mistakes, generates actionable tactical lessons, and auto-tags entries directly into the trader's Firestore-backed **Emotion Journal**.

By distinguishing between "Good Wins" (disciplined execution, sound thesis) and "Bad Wins" (lucky execution that broke rules), as well as "Good Losses" (proper risk management, adhered to invalidation) and "Bad Losses" (bag-holding, averaging down against rules), the post-mortem engine protects traders from outcome bias and reinforces systematic consistency.

---

## Core Capabilities

### 1. Execution Quality vs. Outcome Matrix
- **Execution Grade (A–F)** & **Score (0–100)**: Quantitative measure of adherence to trading plan, risk parameters, and execution discipline.
- **Outcome Verdict**:
  - `goodWin`: Well-planned thesis, proper sizing, followed take-profit plan.
  - `badWin`: Unplanned gamble or held past invalidation, saved only by market luck.
  - `goodLoss`: Proper thesis, cut promptly at predefined stop-loss / invalidation level.
  - `badLoss`: Moved stops, bag-holding, revenge-sized, or failed to honor trade invalidation.
  - `breakEven` / `scratch`: Controlled flat exit with preserved capital.
- **Thesis Alignment (0%–100%)**: Evaluates how closely the trade execution followed the original plan.

### 2. Cognitive Bias Detection & Antidotes
Analyzes the trade narrative and execution data against a comprehensive behavioral finance taxonomy:
- **Disposition Effect**: Selling winners too quickly while holding losers too long.
- **FOMO (Fear of Missing Out)**: Entering late near resistance or peak momentum.
- **Revenge Trading**: Immediate oversized re-entry following a loss.
- **Loss Aversion & Sunk Cost**: Refusing to take an invalidation stop-loss.
- **Outcome Bias**: Judging trade quality solely by dollar gain/loss.
- **Overconfidence**: Excessive position sizing following winning streaks.
- **Anchoring**: Fixating on cost basis rather than changing market conditions.

For each detected bias, the AI delivers a concrete, actionable **Cognitive Antidote** (e.g., *"Set bracket orders with mechanical take-profit limit orders upon entry"*).

### 3. Execution Flaws Catalog
Identifies specific operational mistakes with impact severity (`minor`, `moderate`, `severe`):
- High slippage on market orders in illiquid strikes.
- Exiting prematurely before reaching profit target.
- Holding through earnings / binary catalyst without hedge.
- Position sizing violation relative to account equity.

### 4. Automated Emotion Journal Auto-Tagger
- One-tap commit to the user's Firestore `users/{uid}/emotion_logs` collection.
- Automatically generates standardized categorization hashtags: `#PostMortem`, `#AAPL`, `#GoodLoss`, `#LossAversion`, `#ExecutionDiscipline`, etc.
- Seamlessly updates the trader's **Trading Psychology** dashboard and coaching analytics.

---

## Architecture & Integration

```
Robinhood Options Mobile
├── lib/model/trade_post_mortem_model.dart        # TradePostMortemAnalysis & ExecutionFlaw models
├── lib/widgets/trade_post_mortem_sheet.dart       # Interactive diagnostic bottom sheet UI
├── lib/services/generative_service.dart          # Client callable invoker (analyzeTradePostMortem)
├── functions/src/gemini.ts                       # Backend Cloud Function with Gemini 3.1 Flash-Lite
├── lib/widgets/position_order_widget.dart        # Launch action from stock order view
├── lib/widgets/option_order_widget.dart          # Launch action from option order view
├── lib/widgets/personalized_coaching_widget.dart # Launch action from coaching activity stream
└── lib/widgets/trading_psychology_widgets.dart   # Journal entry card tag chip rendering
```

### Backend Cloud Function (`analyzeTradePostMortem`)
- **File**: `src/robinhood_options_mobile/functions/src/gemini.ts`
- **Security**: Enforces mandatory `request.auth` authentication verification.
- **Model**: Utilizes `gemini-3.1-flash-lite` with fallback to `gemini-2.5-flash-lite`.
- **Structured Schema**: Guaranteed JSON response matching the post-mortem taxonomy:
  - `executionScore` (0–100 number)
  - `executionGrade` ("A" | "B" | "C" | "D" | "F")
  - `outcomeVerdict` ("goodWin" | "badWin" | "goodLoss" | "badLoss" | "breakEven" | "scratch")
  - `thesisAlignment` (0.0–1.0 number)
  - `detectedBiases` (array of `{ bias, evidence, antidote }`)
  - `executionFlaws` (array of `{ flaw, severity, correctiveAction }`)
  - `tacticalLessons` (array of strings)
  - `autoTags` (array of strings with `#` prefix)
  - `coachSummary` (string)

---

## User Experience Flow

1. **Trade Close Event**: A stock or option closing order fills, or the user reviews completed trades in the Order Details or AI Coaching screen.
2. **Launch Post-Mortem**: Tapping the **"Post-Mortem Analysis"** button (`Icons.fact_check_outlined`) opens `TradePostMortemSheet`.
3. **Review Diagnostic**:
   - High-contrast execution score & letter grade card.
   - Outcome verdict badge ("Good Loss", "Bad Win", etc.).
   - Coach summary synthesis.
   - Thesis adherence progress bar.
   - Detected biases with cognitive antidotes.
   - Execution flaw warning cards.
   - Tactical lessons bullet points.
4. **Auto-Tag & Save**: Tapping **"Auto-Tag Journal"** saves an `EmotionLog` to Firestore with generated tags and displays a success confirmation.

---

## Automated Test Coverage

- **Backend Jest Tests**: `functions/tests/gemini.test.ts`
  - Verifies rejection of unauthenticated requests (`unauthenticated`).
  - Verifies rejection of requests with missing symbol or required parameters.
- **Model Unit Tests**: `test/trade_post_mortem_model_test.dart`
  - Verifies JSON deserialization and serialization round-trip.
  - Verifies grade and score helper color and label mappings.
  - Verifies outcome verdict formatting and fallback defaults.
- **Widget Tests**: `test/trade_post_mortem_sheet_test.dart`
  - Verifies diagnostic sheet layout, score cards, and antidote pills.
  - Verifies 1-tap journal auto-tagging saves `EmotionLog` to fake Firestore instance.
