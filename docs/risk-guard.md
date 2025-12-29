# RiskGuard

## Overview

RiskGuard is RealizeAlpha's advanced risk management engine designed to protect capital by enforcing portfolio-level safety rules. Originally developed for the Agentic Trading system, RiskGuard now extends its protection to manual trading, providing a safety net against impulsive or high-risk decisions.

## Manual Trading Protection

RiskGuard integrates directly into the manual trading workflows for **Stocks**, **Options**, and **Crypto**. Before an order is previewed, the system validates the proposed trade against a set of risk rules defined in the backend.

### Workflow

1.  **Validation**: When a user attempts to preview an order, the app calls the `validateTrade` Cloud Function.
2.  **Risk Assessment**: The backend evaluates the trade against current portfolio state, checking for:
    *   **Concentration Risk**: Preventing over-exposure to a single asset.
    *   **Sector Risk**: Limiting exposure to a specific market sector.
    *   **Drawdown Protection**: Restricting trading during significant portfolio drawdowns.
    *   **Volatility Checks**: Warning against trading in extreme volatility conditions.
3.  **User Feedback**:
    *   **Safe**: If the trade passes all checks, the order preview proceeds normally.
    *   **Risk Detected**: If a risk is identified, a **Warning Dialog** appears, detailing the specific risk (e.g., "Portfolio concentration for AAPL exceeds 20%").

### Override Capability

RiskGuard for manual trading is designed to be advisory, not blocking.
*   **Proceed Anyway**: Users can acknowledge the warning and choose to proceed with the trade.
*   **Cancel**: Users can back out to adjust their order quantity or strategy.

### Persistent Awareness

If a user chooses to override a RiskGuard warning:
*   A **Warning Banner** (amber color) appears at the top of the order form, reminding the user of the active risk alert (e.g., "RiskGuard Warning: High Concentration").
*   This banner persists until the order is placed or the screen is reset.

### Analytics & Auditing

To improve risk models and track user safety:
*   **Override Logging**: Every time a user overrides a RiskGuard warning, an event (`risk_guard_override`) is logged to Firebase Analytics.
*   **Data Points**: The log includes the symbol, the specific risk reason, and the order type.

## Automated Trading Protection

For the **Agentic Trading** system, RiskGuard acts as a hard gatekeeper.
*   **Strict Enforcement**: Unlike manual trading, automated agents *cannot* override RiskGuard. If a trade fails validation, it is rejected immediately.
*   **Configuration**: Risk parameters for automated trading are configurable in the [Agentic Trading Settings](agentic-trading.md).

## Architecture

RiskGuard logic is centralized in the Firebase Cloud Functions (`functions/src/riskguard-agent.ts`), ensuring consistent rule application across all trading interfaces (Mobile App, Web, Automated Agents).
