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
- **Challenge Tracking:** You can mark challenges as **Completed** directly in the app.
- **Memory & Feedback:** The AI remembers your previous score and whether you completed your challenge. It will explicitly praise improvements or call out regression in the next session.

### 4. Scoring Breakdown
Get a granular view of your performance with three sub-scores:
- **Discipline:** Adherence to plans and avoidance of impulsive behavior.
- **Risk Management:** Proper sizing, use of stops, and avoiding "lotto" tickets.
- **Consistency:** Regularity in strategy application.

## How to Use

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
