# AI Trading Coach

The **AI Trading Coach** is a sophisticated behavioral analysis tool designed to improve your trading discipline, risk management, and consistency. Unlike traditional analytics that focus on P&L, the Coach focuses on *behavior* and *psychology*.

## Overview

The AI Coach analyzes your recent trade execution history to identify psychological pitfalls such as overtrading, revenge trading, lack of discipline, or gambling behavior. It assigns you a **Trader Archetype**, a **Discipline Score**, and provides actionable challenges to help you improve.

## Feature Highlights

### 1. Deep Behavioral Analysis
The system analyzes up to **180 days** of trading history, looking at:
- **Execution Quality:** Are you using Limit orders (disciplined) or Market orders (impulsive)?
- **Risk Management:** Are you using Stop Loss or Stop Limit triggers?
- **Trade Frequency:** Patterns of overtrading or "revenge trading" (chasing losses).
- **Option Specifics:** Analysis of 0DTE (Zero Days to Expiration) usage and OTM (Out of The Money) gambling.

### 2. Personalized Coaching Personas
Choose the coaching style that motivates you best:
- **Balanced Coach:** Constructive, professional, and direct.
- **Drill Sergeant:** Harsh, strict, and focused purely on discipline. Uses military metaphors.
- **Zen Master:** Calm, philosophical, focusing on mindfulness and "flow".
- **Wall St. Veteran:** Cynical, risk-focused, and no-nonsense.

### 3. The "Accountability Loop"
The Coach doesn't just analyze; it tracks your progress over time.
- **Next Session Challenge:** At the end of every analysis, the AI assigns a specific, actionable goal (e.g., *"Do not take any 0DTE trades tomorrow"* or *"Use a stop loss on every trade"*).
- **Challenge Adherence Verification:** The system automatically analyzes your trading activity since the last session to verify if you adhered to the assigned challenge.
- **Memory & Feedback:** The AI remembers your previous score and challenge performance. It will explicitly praise improvements or call out regression in the next session.

### 4. Hidden Risks Detection
The system goes beyond obvious metrics to find subtle risks:
- **Correlated Exposure:** Detects if multiple positions are betting on the same outcome (e.g., Tech sector concentration).
- **Hidden Leverage:** Identifies excessive risk-taking through high-delta options or margin usage.
- **Dark Mode Support:** The analysis insights are presented in a UI that adapts seamlessly to both light and dark themes.

### 5. Scoring Breakdown
Get a granular view of your performance with three sub-scores:
- **Discipline:** Adherence to plans and avoidance of impulsive behavior.
- **Risk Management:** Proper sizing, use of stops, and avoiding "lotto" tickets.
- **Consistency:** Regularity in strategy application.

### 6. Trading Psychology Score & 4-Pillar Breakdown
The dedicated **Trading Psychology Score** (0-100) measures your mental resilience and behavioral temperament:
- **Emotional Stability:** Tilt resistance and composure during market drawdowns.
- **Discipline & Patience:** Waiting for defined, high-probability setups and using Limit orders rather than market chasing.
- **Bias Resistance:** Overcoming cognitive pitfalls like FOMO, revenge trading, and loss aversion.
- **Risk Temperament:** Stop-loss acceptance and rational, non-catastrophic position sizing.
- **Psychological Health Verdict:** Categorized as *Zen Master Trader* (85-100), *Disciplined Operator* (70-84), *Developing Mindset* (50-69), or *Emotionally Vulnerable* (<50).

### 7. Behavioral Bias Detection & Antidotes
The system diagnoses specific cognitive biases from execution history and attaches tailored behavioral frameworks:
- **FOMO (Fear of Missing Out):** Chasing extended momentum without technical setups. *Antidote: Wait for pullback to defined support/VWAP.*
- **Revenge Trading & Tilt:** Successive trades placed rapidly after losing trades. *Antidote: Mandatory 30-minute cool-down period.*
- **Disposition Effect (Loss Aversion):** Holding losing trades significantly longer than winning trades. *Antidote: Enforce bracketed Stop Loss orders at entry.*
- **Overconfidence & Sizing Creep:** Expanding trade size aggressively following win streaks. *Antidote: Cap max risk per position at 1-2% of total portfolio equity.*
- **Gambler's Fallacy:** Anticipating counter-trend reversals purely due to consecutive green or red bars. *Antidote: Trade market structure and trend confirmation.*

### 8. Emotion Tracking & Mindset Journal
Log emotional states to uncover psychological correlation with trading outcomes:
- **8 Emotional States:** Calm & Centered 🧘, Confident 🎯, Disciplined 🛡️, Anxious 😰, FOMO 🤑, Euphoric 🚀, Frustrated 🤬, Fearful 😨.
- **Multi-Factor Ratings:** 1-5 slider ratings for Energy Level and Confidence Level, plus Market Sentiment (Bullish/Neutral/Bearish) and Session Timing (Pre-Market, Entry, Exit, Post-Market, Review).
- **Persistent Storage:** Stored in Firestore under `trading_journal` and automatically cross-referenced in subsequent AI coaching sessions.
- **Emotional Composure Analytics:** Tracks the percentage of trading sessions conducted in constructive vs reactive emotional states.

### 9. Personalized Pattern Analysis
- **Holding Time Asymmetry Ratio:** Calculates the ratio of average holding time for losing trades vs winning trades. Ratios > 1.5x flag loss aversion and disposition risk.
- **Trade Clustering / Rapid-Fire Bursts:** Identifies trades placed within 10 minutes of each other as potential revenge trading or impatience episodes.
- **Limit vs. Market:** Execution quality indicator showing patience vs impulsiveness.
- **Protection Rate:** Percentage of trades executed with attached stop triggers.

1.  **Navigate** to the "Coach" tab in the app.
2.  **Configure** your analysis:
    *   **Lookback:** Select 30, 60, 90, or 180 days.
    *   **Filter:** Choose to analyze "All", "Stocks", or "Options".
    *   **Style:** Select your preferred coaching persona.
3.  **Tap "Start AI Analysis"**.
4.  **Review** your Score, Archetype, and Sub-scores.
5.  **Accept the Challenge** displayed at the top of the results.
6.  **Mark it Complete** when you've achieved the goal to build your streak.

## Technical Details

- **Privacy:** Trade data is anonymized and sent to a secure Firebase Function for analysis.
- **Models:** Uses Google's **Gemini Flash 2.0** for high-speed, high-context analysis.
- **Context Window:** Can analyze up to 300 recent trades in a single pass to detect complex patterns.

### 5. Challenge Categorization
Every challenge is tagged with a specific category to help you understand your weak points:
- **Risk:** Challenges focused on position sizing and stop losses.
- **Discipline:** Challenges focused on patience and reducing overtrading.
- **Psychology:** Challenges focused on mindset and emotional control.
- **Execution:** Challenges focused on order types and timing.

### 6. Quantitative Insights
Beyond the AI text analysis, the Coach provides hard data on your execution:
- **Limit vs. Market:** A visual breakdown of your order types. High market order usage often indicates impatience.
- **Protection Rate:** The percentage of your trades that had Stop Loss or Stop Limit protection attached.
- **Time of Day Analysis:** A histogram showing when you trade most proficiently.
