# Options Collateral & Tier Upgrades

## Overview

RealizeAlpha provides chain-level options collateral visibility and options tier upgrade management. By interfacing directly with Robinhood's options collateral endpoint (`/options/chains/{chainId}/collateral/`) and upgrade eligibility service (`/options/should_show_options_upgrade_on_sdp/`), traders gain transparency into how their cash and underlying shares are locked across active positions and open orders, as well as their pathway to upgrading from Level 2 to Level 3 multi-leg spread trading.

---

## Key Endpoints

### 1. Options Chain Collateral
- **Endpoint**: `GET /options/chains/{chainId}/collateral/?account_number={account}`
- **Purpose**: Retrieves the exact amount of cash and underlying shares held as collateral for option positions and open orders associated with a specific options chain.
- **Payload Structure**:
  ```json
  {
    "collateral": {
      "cash": {
        "amount": "3250.0000",
        "direction": "debit",
        "infinite": false
      },
      "equities": [
        {
          "quantity": "100.00000000",
          "direction": "debit",
          "instrument": "https://api.robinhood.com/instruments/943c5009-a0bb-4665-8cf4-a95dab5874e4/",
          "symbol": "GOOG"
        }
      ]
    },
    "collateral_held_for_orders": {
      "cash": {
        "amount": "650.0000",
        "direction": "debit",
        "infinite": false
      },
      "equities": [
        {
          "quantity": "0E-8",
          "direction": "debit",
          "instrument": "https://api.robinhood.com/instruments/943c5009-a0bb-4665-8cf4-a95dab5874e4/",
          "symbol": "GOOG"
        }
      ]
    }
  }
  ```

### 2. Options Upgrade Eligibility
- **Endpoint**: `GET /options/should_show_options_upgrade_on_sdp/?account_number={account}`
- **Purpose**: Determines whether the account is eligible for options tier upgrades (e.g., Level 2 to Level 3 multi-leg spread permissions) and provides the application URL and required criteria.
- **Key Fields**:
  - `should_show_options_upgrade`: Boolean indicating whether the user can apply for a tier upgrade.
  - `option_level`: Current account options level (`option_level_1`, `option_level_2`, `option_level_3`).
  - `target_tier`: Target level (typically Level 3).
  - `upgrade_title`: Descriptive upgrade header.
  - `upgrade_url`: Direct link to the brokerage tier application flow.

---

## Options Tiers & Capability Matrix

| Tier | Name | Allowed Strategies | Account Requirement | Collateral Rule |
|---|---|---|---|---|
| **Level 1** | Covered Only | Covered Calls, Cash-Secured Puts | Cash or Margin | 100 shares per Call; 100% strike cash per Put |
| **Level 2** | Standard Options | Long Calls, Long Puts, Covered Calls, Cash-Secured Puts | Cash or Margin | 100% premium paid for long; full collateral for short |
| **Level 3** | Multi-Leg & Spreads | Debit Spreads, Credit Spreads, Iron Condors, Straddles, Strangles, Calendars | Margin or Limited-Margin | Max spread width × 100 minus net credit |

---

## Architecture & Integration

### Data Models (`lib/model/option_collateral.dart`)
- **`OptionCollateralCash`**: Tracks cash amount, direction (`debit` / `credit`), and infinite liability flag.
- **`OptionCollateralEquity`**: Tracks locked underlying shares, symbol, direction, and instrument URL.
- **`OptionCollateralBreakdown`**: Groups cash and equity components for active positions or pending orders.
- **`OptionChainCollateral`**: Aggregates total cash locked, total shares locked, and provides formatted currency helpers.
- **`OptionUpgradeStatus`**: Contains tier metadata, requirements checklist, feature breakdown, and upgrade CTA links.

### Service Layer (`IBrokerageService`)
- Added `getOptionChainCollateral(user, chainId, accountNumber)` and `getOptionsUpgradeStatus(user, accountNumber)` to `IBrokerageService`.
- Concrete implementations across `RobinhoodService`, `DemoService`, `FidelityService`, `SchwabService`, `PaperService`, and `PlaidService`.
- Typed helper methods `getOptionChainCollateralModel` and `getOptionsUpgradeStatusModel` on `RobinhoodService`.

### User Interface (`lib/widgets/option_collateral_widget.dart`)
- **Header & Metric Cards**: Displays total locked cash, total shares held, positions vs orders breakdown.
- **Collateral Breakdown Section**: Clear cards separating active positions collateral from pending order reservations.
- **Tier Upgrades Tab**:
  - Current tier badge and target tier indicator.
  - Feature comparison matrix between Level 2 and Level 3.
  - Eligibility checklist (margin account, options agreements).
  - "Apply for Level 3 Upgrade" action button with external link launch or in-app application confirmation.
- **Entry Points**:
  - **Option Chain Widget (`option_chain_widget.dart`)**: Quick shield icon (`Icons.shield_outlined`) in the SliverAppBar actions.
  - **User Info Widget (`user_info_widget.dart`)**: "Options Tiers & Collateral" / "Options L3 Active" actionable chip in the account badge row.
