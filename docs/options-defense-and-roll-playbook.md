# Multi-Leg Options Defense & Roll Playbook

The **Multi-Leg Options Defense & Roll Playbook** (`OptionDefensePlaybookWidget`, [#158](https://github.com/CIInc/robinhood-options-mobile/issues/158)) is an institutional-grade threat detection engine and tactical advisory system for managing tested options positions, short legs, and credit spreads.

It systematically diagnoses position vulnerability and generates actionable, mathematically sound defensive adjustments (rolling out in time, widening spreads, inverted strangles, converting vertical spreads to iron condors) with seamless 1-tap transfer to the [Options Strategy Roll Assistant](options-strategy-roll-assistant.md).

---

## The Strategic Problem

Options sellers and credit traders generate income by capturing theta time decay. However, when an underlying equity makes a sharp directional move:
- **Short Calls / Covered Calls** are tested when the underlying rallies past the strike price.
- **Short Puts / Cash-Secured Puts** are tested when the underlying plummets below the strike price.
- **Credit Spreads** suffer accelerated delta and gamma risk as the tested short strike is approached or breached.

Without mechanical rules, retail traders frequently make fatal errors:
1. **Freezing**: Allowing an assignment or full max-loss breach without defending.
2. **Rolling for a Debit**: Paying money to roll a losing trade further in time, drastically increasing capital at risk.
3. **Over-defending inside 0-3 DTE**: Waiting until gamma swings make rolling for credit impossible.

The **Options Defense & Roll Playbook** solves this by establishing systematic, automated threat classification and prescriptive tactical maneuvers based on institutional Tastytrade and quantitative market-maker playbooks.

---

## Threat Classification Engine

The analysis engine evaluates the position's strike price, underlying spot price, days to expiration (DTE), delta ($\Delta$), and option moneyness:

| Threat Level | Status Badge | Condition | Tactical Prescription |
|---|---|---|---|
| **SAFE** | `SAFE` | Spot is > 2.5% OTM, $\Delta < 0.35$, DTE > 14 | Hold position, capture theta decay, manage at 50% profit target. |
| **CAUTION** | `CAUTION` | Spot within 2.5% of short strike, $\Delta \ge 0.35$, or DTE $\le 14$ | Proactive roll: Roll Out in Time or Roll Away & Out before gamma accelerates. |
| **BREACHED** | `BREACHED` | Spot crosses short strike (ITM), or $\Delta \ge 0.50$ | Active defense: Roll Strike Away (Up & Out / Down & Out) or Roll Out in Time for credit; convert to Iron Condor if credit spread. |
| **CRITICAL** | `CRITICAL` | Spot breached by > 3.0%, DTE $\le 3$ with strike breached, Ex-Dividend early assignment hazard, or 0DTE/1DTE Pin Risk | High-urgency defense: Roll Out in Time for credit, roll ahead of ex-dividend, or close position to prevent uncapped tail risk or margin shock. |

---

## Ex-Dividend Early Assignment & Pin Risk Guardrails

### 1. Ex-Dividend Early Assignment Hazard Guard
Counterparties holding deep in-the-money or low-extrinsic call options have a strong economic incentive to exercise early on the day immediately preceding the ex-dividend date to capture the upcoming cash dividend payout.

- **Trigger Condition**: Short call position where $\text{Remaining Extrinsic Value} \le 1.25 \times \text{Upcoming Dividend}$ within 7 calendar days ($\le 5$ trading days) of the scheduled ex-dividend date.
- **Diagnostics**: Computes exact mark price, intrinsic value ($\max(0, \text{Spot} - \text{Strike})$), and remaining extrinsic value ($\max(0, \text{Mark} - \text{Intrinsic})$).
- **Tactical Prescription**:
  - Pre-populates `RollPreset.rollUpAndOut` to move short strike OTM and past ex-dividend cutoff.
  - Generates critical Action Center alert `opt-exdiv-assignment-{id}` targeting `PortfolioAlertTarget.strategies`.
  - Displays high-visibility `EX-DIV HAZARD` card on `OptionDefensePlaybookWidget`.

### 2. 0DTE / 1DTE Pin Risk & Margin Shock Engine
Expiring short options that trade at-the-money create severe assignment uncertainty because long holders can submit exercise notices up to 5:30 PM ET after market close regardless of the 4:00 PM settlement price.

- **Trigger Condition**: 0DTE or 1DTE short legs or credit spreads trading within $\pm 1.0\%$ of the strike price ($|\text{Spot} - \text{Strike}| / \text{Strike} \le 0.01$).
- **Notional Obligation & Margin Shock**:
  - Calculates total notional equity obligation: $100 \times \text{Strike} \times \text{Contracts}$.
  - Evaluates notional obligation against available buying power (`UnifiedAccount.buyingPower` / `Account.buyingPower`).
  - When assignment obligation exceeds buying power, flags a critical **Margin Shock Deficit** ($\text{Deficit} = \text{Obligation} - \text{Buying Power}$), surfacing immediate liquidation warnings.
- **Tactical Prescription**:
  - Highlights `MARGIN SHOCK` or `PIN RISK DEFENSE` cards with 1-tap position closure before the 4:00 PM ET cutoff.
  - Displays `⚠️ Pin Risk` badges directly on the position card in `OptionInstrumentWidget`.
  - Dispatches critical Action Center alert `opt-pin-risk-{id}` with emergency close actions.

---

## Tactical Playbook Maneuvers

```mermaid
flowchart TD
    A["Open Option Position"] --> B{"Threat Engine\n(OptionDefensePlaybook.analyze)"}
    B -->|Safe: Far OTM| C["Hold / 50% Profit Rule\n(Theta Decay Working)"]
    B -->|Caution: Approaching Strike| D["Proactive Roll\n(Roll Out 30-45 DTE)"]
    B -->|Breached: ITM| E{"Strategy Type?"}
    E -->|Single Leg / Covered| F["Roll Strike Away & Out\n- Calls: Roll Up & Out\n- Puts: Roll Down & Out"]
    E -->|Single Leg Alternative| G["Roll Out in Time\n(Same Strike, +Credit)"]
    E -->|Vertical Credit Spread| H["Convert to Iron Condor\n(Sell Opposing Spread, $0 Extra Margin)"]
    B -->|Critical: Deep ITM / 0-3 DTE| I{"Net Credit Viable?"}
    I -->|Yes| J["Roll Out (Same Strike, 45-60 DTE)"]
    I -->|No / Fundamental Shift| K["Close Position\n(Capital Preservation)"]
```

### 1. Roll Out in Time (Duration Defense)
- **Objective**: Extend expiration by 21-45 days at the identical strike price.
- **Rationale**: Captures additional extrinsic value to lower the effective breakeven point and gives the underlying asset time to mean-revert.
- **Execution**: Automatically pre-selects `RollPreset.rollOut` in the Roll Assistant.

### 2. Roll Away & Out (Strike Defense)
- **Objective**: Move the short strike further away from the spot price (Roll Up & Out for Calls, Roll Down & Out for Puts) at a later expiration.
- **Rationale**: Lowers directional delta exposure and probability of expiring in-the-money, while using extended duration to finance the strike move.
- **Execution**: Automatically pre-selects `RollPreset.rollUpAndOut` or `RollPreset.rollDownAndOut`.

### 3. Convert to Iron Condor (Opposing Spread Defense)
- **Objective**: Sell an out-of-the-money credit spread on the untested side of the market (e.g., sell a Bear Call Spread if your Bull Put Spread is breached).
- **Rationale**: Brokerages only require margin for the wider side of an iron condor. Selling the opposing spread collects immediate net credit to cushion the tested spread's loss without increasing margin requirements.
- **Execution**: Direct navigation to trade options chain for opposing leg entry.

### 4. Close Position & Preserve Capital (Risk Control)
- **Objective**: Cut losses before terminal assignment or capital destruction occurs.
- **Rationale**: If the underlying asset's core thesis is invalidated or rolling for a net credit is mathematically impossible, closing limits losses to defined bounds.

---

## Institutional Defense Rules

The Playbook embeds core rules drawn from professional derivatives trading:

1. **Always Roll for Credit**: Never pay a net debit to defend a short option. Paying debits increases your maximum capital at risk on a losing trade.
2. **Defend at 21 DTE Benchmark**: Gamma risk accelerates exponentially inside 21 DTE. Defend or extend duration before rapid gamma swings amplify losses.
3. **Zero-Margin Opposing Spread**: When converting a tested credit spread into an Iron Condor, the new credit collected directly offsets losses with zero additional margin.
4. **Know When to Cut Losses**: If the short strike is breached by > 3% and cannot be rolled out for a net credit, close the position and reallocate capital.

---

## User Interface & Integration

1. **`OptionDefensePlaybookWidget`**:
   - **Header Threat Banner**: Color-coded threat indicator (Green, Amber, Orange, Red) displaying current status, distance to strike, short strike, spot price, DTE, and delta.
   - **Threat Diagnostics**: Concrete bullet points highlighting what triggered the alert.
   - **Tactical Playbook Actions**: Actionable cards with "⭐ RECOMMENDED DEFENSE", "ZERO MARGIN CREDIT", and "STRIKE DEFENSE" badges.
   - **1-Tap Roll Execution**: Pushes `OptionRollAssistantWidget` with the corresponding preset pre-selected.

2. **Access Points**:
   - **Option Instrument Details (`OptionInstrumentWidget`)**: Dedicated "Defense" tonal action button next to "Roll" and "Trade Option".
   - **Option Positions List (`OptionPositionsWidget`)**: Long-press bottom sheet offering direct navigation to "Defense Playbook" or "Roll Assistant".
   - **Roll Assistant (`OptionRollAssistantWidget`)**: AppBar action icon (`Icons.shield_outlined`) allowing instant review of tactical recommendations while crafting a roll.

---

## Verification & Testing

- **Unit Tests** ([`test/option_defense_models_test.dart`](../src/robinhood_options_mobile/test/option_defense_models_test.dart)):
  - Tested and breached Covered Call / Short Call ($\Delta > 0.50$, spot > strike).
  - Critical Cash-Secured Put (spot deep below strike with short DTE).
  - Caution Cash-Secured Put (approaching strike within 2% distance).
  - Safe OTM Position (unthreatened, hold/profit recommendation).
  - Vertical Credit Spread conversion to Iron Condor.
- **Widget Tests** ([`test/option_defense_playbook_widget_test.dart`](../src/robinhood_options_mobile/test/option_defense_playbook_widget_test.dart)):
  - Validates threat status banner, diagnostics findings, metrics grid, recommended playbook cards, and institutional rule accordions.
