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

### 2. Behavioral Tilt & Overtrading Safeguards (`enableTiltSafeguards`)
- **Pure Software-Based Detection**: Replaces fragile, permission-heavy biometric sensors (e.g. HealthKit heart-rate monitors) with zero-permission behavioral heuristics analyzed directly in-app.
- **Rapid Cancel/Replace Loop Detection**: Monitors frantic order modifications within a rolling window (`rapidCancelWindowMinutes`, default 5m). If cancellations or replacements reach `maxRapidCancels` (default 4), execution is halted with trigger type `rapid_cancels` to break emotional thrashing.
- **Revenge-Trading Sizing Spike Blocker**: Automatically tracks a rolling baseline average trade size (`baselineTradeSize`) across the last 10 executions. If a trader experiences consecutive losses (`currentConsecutiveLosses > 0`) and attempts to submit an order exceeding `revengeSizingMultiplier` (default 2.5x) times baseline, the order is blocked with trigger type `revenge_sizing`.
- **Integrated Action Center Proximity Alerts**: `PortfolioAlertService` warns traders when rapid cancellations approach the limit (`risk-tilt-rapid-cancels-near`) or when loss streaks elevate revenge trading tilt risk (`risk-tilt-revenge-trading-risk`).

### 3. Guarded Order Execution Integration
- In `TradeOptionWidget._placeOrder()`:
  - Loads the latest persisted circuit breaker configuration.
  - Verifies whether execution is currently blocked via `config.isExecutionBlocked`.
  - Evaluates prospective order notional against `evaluateOrderSize()` to block revenge-trading sizing spikes following losses.
  - If tripped or within cooling-off, halts order placement immediately and presents an informative dialog explaining the trip reason and remaining time.
  - Records analytics events (`risk_guard_override` / `circuit_breaker_blocked`).
- Order cancellation and replacement flows in `OptionOrderWidget` and `PositionOrderWidget` trigger `recordOrderCancelledOrReplaced()` to detect rapid thrashing loops.

### 4. Action Center & Real-Time Alerts
- Integrated with `PortfolioAlertService.evaluateAlerts()`:
  - **Critical Alert (`circuit-breaker-tripped` / `cooling-off`)**: Surfaces prominently when trading is locked or cooling off, displaying the exact cause and end time.
  - **Warning Alert (`circuit-breaker-near-limit`)**: Alerts the user when daily losses cross 80% of their configured threshold.
  - **Warning Alert (`risk-tilt-rapid-cancels-near`)**: Alerts the user when cancellations in the last 5 minutes are within 1 of tripping the cooling-off lock.
  - **Warning Alert (`risk-tilt-revenge-trading-risk`)**: Alerts the user after consecutive losses to adhere to disciplined position sizing.

### 5. Interactive Configuration UI (`RiskCircuitBreakerSettingsWidget`)
- Accessible from **User Profile (`UserWidget`) > Risk Circuit Breakers & Tilt Guardrails**.
- **Live Status Header**: Visual badge and countdown timer indicating whether safety guardrails are Active, Cooling Off, or Tripped.
- **Configuration Sliders & Preset Chips**: Intuitive chip selectors and granular sliders for loss amounts, drawdown percentages, cooling-off duration, rapid cancel limits (2, 4, 6, 8, Disabled), and revenge sizing multipliers (1.5x, 2.0x, 2.5x, 3.0x, Disabled).
- **Simulation & Testing**: "Simulate 2-Min Trip" and "Simulate Rapid Cancel Loop Trip" buttons for traders to verify order lockouts safely without financial loss.
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
  final bool enableTiltSafeguards;
  final int? maxRapidCancels;
  final int rapidCancelWindowMinutes;
  final double? revengeSizingMultiplier;
  final double? baselineTradeSize;
  final List<DateTime> recentCancelTimestamps;
  final List<double> recentTradeSizes;

  bool get isInCoolingOff => coolingOffUntil != null && DateTime.now().isBefore(coolingOffUntil!);
  bool get isExecutionBlocked => enabled && (isTripped || isInCoolingOff);
  int get activeRapidCancelCount => ...;
}
```

## Testing & Quality Assurance

- **Unit Tests**: `test/risk_circuit_breaker_test.dart` covers serialization, threshold calculations, drawdown tracking, consecutive losses, rapid cancel loop detection, revenge sizing spike evaluation, and `PortfolioAlertService` alerts.
- **Widget Tests**: `test/risk_circuit_breaker_widget_test.dart` verifies toggle switches, chip selectors, sliders, status cards, simulation buttons, and reset dialogs.
