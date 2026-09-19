# Autonomous Account Risk Circuit Breakers & Tilt Guardrails

## Overview

The **Autonomous Account Risk Circuit Breaker & Tilt Guardrail Engine** (`RiskCircuitBreakerService`) provides automated, capital-preserving protection against emotional trading, revenge trading ("tilt"), unexpected intraday portfolio volatility, and margin compression.

Unlike passive alerts, the risk circuit breaker actively locks order execution within order entry views (such as `TradeOptionWidget`) when user-defined safety boundaries are breached, and enforces a mandatory cooling-off period before trading may resume.

## Features & Capabilities

### 1. User-Configurable Thresholds (`RiskCircuitBreakerConfig`)
- **Daily Loss Limits**: Configurable both in absolute dollar amounts (e.g., \$250, \$500, \$1,000, \$2,500) and percentage of start-of-day portfolio equity (1%–20%).
- **Peak-to-Trough Drawdown Limit**: Real-time tracking of portfolio high-water mark (`peakPortfolioEquity`), triggering a trip if current equity falls below the threshold (e.g. 5%–30%).
- **Consecutive Loss Streak Lockout**: Tracks consecutive losing closed positions and trips when the limit (e.g. 2, 3, 5, or 7 consecutive losses) is reached, combating revenge trading.
- **Minimum Margin Buffer Cushion**: Ensures a safety reserve on margin accounts (e.g., 10%–50% margin cushion) to prevent margin calls and forced liquidations.
- **Mandatory Cooling-Off Period**: Enforces a temporary trading lock (e.g., 15 minutes, 30 minutes, 1 hour, 2 hours, 4 hours, or 1 market day) during which new orders are blocked.

### 2. Guarded Order Execution Integration
- In `TradeOptionWidget._placeOrder()`:
  - Loads the latest persisted circuit breaker configuration.
  - Verifies whether execution is currently blocked via `config.isExecutionBlocked`.
  - If tripped or within cooling-off, halts order placement immediately and presents an informative dialog explaining the trip reason and remaining time.
  - Records analytics events (`risk_guard_override` / `circuit_breaker_blocked`).

### 3. Action Center & Real-Time Alerts
- Integrated with `PortfolioAlertService.evaluateAlerts()`:
  - **Critical Alert (`circuit-breaker-tripped`)**: Surfaces prominently when trading is locked or cooling off, displaying the exact cause and end time.
  - **Warning Alert (`circuit-breaker-near-limit`)**: Alerts the user when daily losses cross 75% of their configured threshold, encouraging risk reduction before a trip occurs.

### 4. Interactive Configuration UI (`RiskCircuitBreakerSettingsWidget`)
- Accessible from **User Profile (`UserWidget`) > Risk Circuit Breakers**.
- **Live Status Header**: Visual badge and countdown timer indicating whether safety guardrails are Active, Cooling Off, or Tripped.
- **Configuration Sliders & Preset Chips**: Intuitive chip selectors and granular sliders for loss amounts, drawdown percentages, and cooling-off duration.
- **Simulation & Testing**: "Simulate 2-Min Trip" button for traders to verify order lockouts safely without financial loss.
- **Emergency Manual Reset**: Confirmation modal to clear tripped status or early-terminate cooling-off with user acknowledgement.

## Domain Models

### `RiskCircuitBreakerConfig`
```dart
class RiskCircuitBreakerConfig {
  final bool enabled;
  final double? maxDailyLossAmount;
  final double? maxDailyLossPercent;
  final double? maxDrawdownPercent;
  final int? maxConsecutiveLosses;
  final double? minMarginBufferPercent;
  final int coolingOffDurationMinutes;
  final DateTime? coolingOffUntil;
  final bool isTripped;
  final String? tripReason;
  final double? peakPortfolioEquity;
  final int currentConsecutiveLosses;
  
  bool get isInCoolingOff => coolingOffUntil != null && DateTime.now().isBefore(coolingOffUntil!);
  bool get isExecutionBlocked => enabled && (isTripped || isInCoolingOff);
}
```

## Testing & Quality Assurance

- **Unit Tests**: `test/risk_circuit_breaker_test.dart` covers serialization, threshold calculations, drawdown tracking, consecutive losses, and `PortfolioAlertService` integration.
- **Widget Tests**: `test/risk_circuit_breaker_widget_test.dart` verifies toggle switches, chip selectors, sliders, status cards, simulation buttons, and reset dialogs.
