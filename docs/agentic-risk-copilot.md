# Autonomous Agentic Risk Copilot

## Overview

The **Autonomous Agentic Risk Copilot** (`RiskCopilotService`) provides continuous portfolio surveillance across three core danger vectors:
1. **Overnight Gap Risk**: Assesses after-hours and weekend price vulnerability on broad indices, high-beta single stocks, leveraged ETFs (e.g., TQQQ, SOXL), and short option contracts.
2. **Earnings Hazard Warnings**: Cross-references held positions against the upcoming earnings calendar and quantitative IV crush models, warning of 40%–70% extrinsic value collapse on long options and explosive gamma tail jumps on short options.
3. **Suggested Delta Hedges**: Quantifies directional delta exposure (\$ move per 1% underlying shift) and computes precise share hedges and option protective structures (protective puts, covered collars, delta rebalancing) through deep integration with `DeltaNeutralService`.

The engine generates an actionable **Safety Score (0–100)**, an overall **Risk Severity (`normal`, `elevated`, `high`, `critical`)**, and a prioritized **Mitigation Action Checklist** with one-tap deep-linking directly into relevant trading tools.

---

## Features & Analytical Capabilities

### 1. Overnight Gap Risk Engine
- **Heuristic & Statistical Shock Model**: Evaluates asset beta (\(\beta\)) and leverage factor multipliers to simulate potential overnight gaps (\(3\% \times \beta \times \text{leverage}\)).
- **Short Option Jump Risk Escalator**: Penalizes naked short calls and short puts which face uncapped or severe tail gaps without underlying share coverage.
- **Exposure Sizing & Severity Matrix**:
  - `critical`: Unhedged naked short options, potential gap loss exceeding 7.5% of portfolio equity, or leveraged ETF holdings exceeding 20% of equity.
  - `high`: Leveraged ETF positions exceeding 10% of equity, or potential gap loss exceeding 4.5% of equity.
  - `elevated`: High-beta holdings (\(\beta > 1.4\)) or potential gap loss exceeding 2% of equity.
  - `normal`: Well-diversified, hedged holdings within standard tolerance.

### 2. Earnings Hazard Warning System
- **Calendar & Expiration Cross-Referencing**: Matches held stock and option positions against scheduled earnings events within a 14-day lookahead window.
- **Hazard Type Classification**:
  - `ivCrush`: Flags long calls and puts held across earnings releases, predicting extrinsic volatility deflation post-announcement.
  - `gammaTailRisk`: Flags short options facing explosive gamma jumps and assignment risk if the underlying blows through the expected move.
  - `earningsGap`: Directional stock gap exposure prior to announcement.
- **Timing & Urgency Escalation**:
  - \(\le 2\text{ days}\) with option contracts: `critical` severity. Recommends closing long contracts or converting short legs to defined-risk iron condors before market close.
  - \(\le 5\text{ days}\) with options: `high` severity. Recommends rolling out in cycle or establishing collars.
  - \(> 5\text{ days}\): `elevated` severity with proactive volatility expansion monitoring.

### 3. Suggested Delta Hedges Engine
- **Net Greek Aggregation**: Integrates seamlessly with `DeltaNeutralService.importExistingPositions` and `DeltaNeutralService.computeAnalysis`.
- **Directional Sensitivity**: Computes net position delta and exact dollar PnL impact per 1% change in spot price (\(\text{Net Delta} \times \text{Spot} \times 0.01\)).
- **Concrete Actionable Hedges**:
  - Exact shares to buy/sell to achieve target neutrality (\(\Delta = 0\)).
  - Precise option structures (e.g. "Buy 2x ATM Put" or "Collar with OTM Call") to hedge net long or short exposure.
  - Distinguishes between active options structures (strict delta tolerance) and standard diversified equity investments to prevent false alarms.

### 4. Prioritized Mitigation Action Checklist
- Compiles cross-hazard mitigation recommendations into a unified, prioritized task list sorted by urgency (`critical` \(\to\) `high` \(\to\) `elevated`).
- Each mitigation action features:
  - Clear diagnosis and risk rationale.
  - Concrete mitigation directive (e.g., "Close or collar naked short options before 4:00 PM EST close").
  - Seamless deep-linking target route (`instrument`, `delta_neutral`, or `earnings_calendar`).

---

## Domain Architecture

```
lib/model/risk_copilot_model.dart
├── RiskCopilotSeverity (normal, elevated, high, critical)
├── EarningsHazardType (ivCrush, gammaTailRisk, earningsGap)
├── GapRiskAssessment
├── EarningsHazardAssessment
├── DeltaHedgeAssessment
├── RiskCopilotMitigationAction
└── RiskCopilotReport (JSON serialization, metrics, safety score)
```

### Key Interfaces

```dart
class RiskCopilotReport {
  final DateTime generatedAt;
  final RiskCopilotSeverity overallSeverity;
  final double overallScore; // 0 - 100
  final String statusHeadline;
  final String summary;
  final double totalOvernightGapExposure;
  final double portfolioNetDelta;
  final List<GapRiskAssessment> gapRisks;
  final List<EarningsHazardAssessment> earningsHazards;
  final List<DeltaHedgeAssessment> deltaHedges;
  final List<RiskCopilotMitigationAction> mitigationActions;
}
```

---

## UI Components & Navigation

1. **`AgenticRiskCopilotCard` (`lib/widgets/portfolio/agentic_risk_copilot_card.dart`)**:
   - Progressive-disclosure analytics card embedded directly on the **Portfolio > Risk** section page (`RiskSectionPage`).
   - Displays live Safety Score (with color-coded gauge), critical hazard badges, top mitigation actions, and an expandable preview.
   - Includes a "View Full Copilot Report" CTA navigating to `RiskCopilotWidget`.

2. **`RiskCopilotWidget` (`lib/widgets/risk_copilot_widget.dart`)**:
   - Comprehensive full-screen copilot dashboard.
   - Header summary banner with safety score gauge, risk badge, and executive summary.
   - Key metric pills: Overnight Gap Risk, Net Delta, and Imminent Earnings countdown.
   - Interactive checklist of prioritized mitigation actions with direct action buttons.
   - Three tab views:
     - **Overnight Gap**: Position notional, beta, estimated gap %, and dollar exposure breakdown.
     - **Earnings Hazards**: Implied moves, crush probabilities, and position warnings.
     - **Delta Hedges**: Net delta, dollar move per 1%, share hedge suggestions, and option hedge recommendations.

3. **Action Center Integration (`PortfolioAlertService`)**:
   - Evaluates copilot report and generates actionable alerts with `PortfolioAlertTarget.riskCopilot`.
   - Critical alerts (`risk-copilot-critical-gap`, `risk-copilot-earnings-iv-crush`) trigger high-visibility alerts with direct navigation into the Risk Copilot view.
   - Normal portfolios suppress noise to maintain high signal-to-noise ratio.

---

## Verification & Testing

- **Engine Unit Tests (`test/risk_copilot_service_test.dart`)**:
  - Comprehensive model JSON serialization round-trips.
  - Overnight gap risk detection across leveraged ETFs (`TQQQ`, `SOXL`) and unhedged short options.
  - Imminent earnings IV crush hazard detection and countdown tracking.
  - Directional delta imbalance analysis and hedge recommendations.
  - Prioritized mitigation checklist generation and routing targets.
  - Action Center alert integration and clean-state suppression.
- **Static Analysis**: Verified with `flutter analyze` with 0 warnings or errors across all added and updated library files.
