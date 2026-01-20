# AI-Driven Asset Allocation with Risk Profiling

This feature leverages Generative AI (Gemini 2.5) to provide personalized portfolio allocation recommendations based on the user's risk profile.

## Overview

The AI-Driven Asset Allocation tool is integrated into the **Portfolio Rebalancing** widget. It allows users to:
1.  Define their **Investor Profile** including:
    *   **Risk Tolerance** (Conservative, Moderate, Growth, Aggressive, Speculative)
    *   **Time Horizon** (Short, Medium, Long Term)
    *   **Investment Goal** (Preservation, Income, Growth, Speculation)
2.  Receive **AI-generated allocation targets** for Asset Classes and Sectors with a **contextual explanation**.
3.  Preview the strategy and explanation before applying it.

## Workflow

1.  **Access**: Navigate to the Portfolio Rebalancing tool.
2.  **Trigger**: Tap the "AI Optimization" (sparkles) icon in the app bar.
3.  **Profile Definition**: A dialog appears pre-filled with existing profile data. Select values for Risk, Horizon, and Goal.
4.  **Generation**: The app shows a loading indicator while calling the `generateContent25` Cloud Function.
    *   *Prompt*: "Acting as a senior portfolio manager... for an investor with Risk: [Risk], Horizon: [Horizon], Goal: [Goal]..."
5.  **Review**: A result dialog displays:
    *   **AI Explanation**: A concise rationale for the suggested mix.
    *   **Asset Allocation Preview**: Proposed percentages.
    *   **Sector Allocation Preview**: Proposed percentages.
6.  **Application**: Tap "Apply Strategy" to update the rebalancing interface, or "Dismiss" to discard.
7.  **Finalize**: Tap **Save** (disk icon) to persist the new targets and profile settings.

## Technical Details

-   **Frontend**: `RebalancingWidget` handles the multi-step UI (Form Dialog -> Loading -> Result Dialog).
-   **State Management**: Updates `User` model (`InvestmentProfile`) locally and in Firestore immediately upon form submission.
-   **Backend**: Uses `generateContent25` (Gemini 2.5 Flash Lite) for high-performance inference.
-   **Schema**: AI returns JSON with `explanation`, `assets`, and `sectors`.

## Future Enhancements

-   Include current portfolio composition in the prompt for "migration" advice (e.g., "sell X to buy Y").
-   Add "Excluded Sectors" preference (e.g., for ESG or personal preference).
