# Real-Time Stream Throttling, Memory Optimization & Battery Conservation

This document details the architectural design and implementation of real-time streaming optimizations, memory efficiency, and battery conservation for **RealizeAlpha** (`robinhood-options-mobile`), resolving [#124](https://github.com/CIInc/robinhood-options-mobile/issues/124).

---

## 1. Overview & Problem Statement

Financial market streaming feeds (such as Charles Schwab WebSocket Level 1 quotes, option Greeks, futures, and forex) emit rapid, sub-millisecond price ticks during active market hours. Unchecked propagation of high-frequency quote ticks directly to the Flutter UI layer causes:
1. **Severe Frame Drops & UI Stutters**: Repeated rebuilds of complex widget trees (e.g. watchlist lists, order sheets, option chain grids) at 30-100Hz degrade animation fluidity below 60/120 FPS.
2. **Excessive Battery Consumption & Thermal Throttling**: Constant JSON decoding, state notification dispatching, and GPU rasterization drain mobile device battery and generate excessive thermal load.
3. **Cellular Bandwidth Exhaustion**: Indiscriminately subscribing to dozens of off-screen watchlist items or multi-broker feeds consumes unnecessary cellular data.
4. **Background Leaks**: Sockets continuing to stream while the app is in the background or locked exhaust OS resources and risk system termination.

---

## 2. Architecture & Components

```
                +------------------------------------+
                | SchwabStreamerService (WebSocket)  |
                +-----------------+------------------+
                                  |
                                  v
                   +-------------------------------+
                   |   StreamThrottleTransformer   |
                   | (Per-symbol leading/trailing) |
                   +---------------+---------------+
                                   |
                  +----------------+----------------+
                  |                                 |
                  v                                 v
    +---------------------------+     +---------------------------+
    |  ViewportStreamCoordinator|     | NavigationStatefulWidget  |
    |  - Max 15 active symbols  |     | - AppLifecycleState       |
    |  - Delta-diffing bounds   |     | - pauseAll() / resumeAll()|
    +---------------------------+     +---------------------------+
```

### A. StreamThrottleTransformer (`lib/utils/stream_throttle_transformer.dart`)
- **Key-Partitioned Throttling**: Ticks are keyed per financial symbol (e.g., `AAPL`, `MSFT`, `/ES`, `EUR/USD`) using a `keySelector` callback, ensuring one active stock tick never starves or delays updates for another ticker.
- **Leading & Trailing Window Dispatch**:
  - The first tick for a symbol in an idle window is emitted **immediately** ($0\text{ms}$ latency) for maximum UI responsiveness.
  - Subsequent ticks arriving during the throttle window (default $250\text{ms}$) are debounced.
  - Upon window expiration, the latest received tick is emitted as a trailing update if new data arrived.
- **Clean Disposal**: Canceling the downstream subscription immediately cancels all in-flight timers and clears memory maps.

### B. SchwabStreamerService Throttled Feeds (`lib/services/schwab_streamer_service.dart`)
Provides rate-limited convenience streams alongside raw streams:
- `throttledEquityQuotes`: Level 1 equities quote updates throttled to 250ms per ticker.
- `throttledOptionQuotes`: Options quotes with Greeks throttled to 250ms per contract.
- `throttledFuturesQuotes`: Futures quotes (`/ES`, `/NQ`, etc.) throttled to 250ms per contract.
- `throttledForexQuotes`: Forex quotes throttled to 250ms per currency pair.

### C. App Lifecycle Ingestion & Global Pausing
- **Static Registry**: `SchwabStreamerService` automatically tracks active instances in `_activeInstances` and removes them upon `dispose()`.
- **Global Lifecycle Coordination**:
  - `SchwabStreamerService.pauseAll()`: Invoked on `AppLifecycleState.paused` or inactive. Caches active subscriptions, sends `UNSUBS` commands to the remote gateway, sets `isPaused = true`, and silences incoming packets.
  - `SchwabStreamerService.resumeAll()`: Invoked on `AppLifecycleState.resumed`. Restores cached subscription sets, sets `isPaused = false`, and resubscribes all active feeds.
- **Wired in `NavigationStatefulWidget`**: Hooks directly into `didChangeAppLifecycleState(...)`.

### D. ViewportStreamCoordinator (`lib/services/viewport_stream_coordinator.dart`)
- **Bounded Capacity**: Caps active streaming subscriptions to the visible mobile viewport (default maximum of 15 symbols).
- **Delta-Diffing Algorithm**: When the user scrolls a watchlist or options list, `updateVisibleEquities(...)` calculates set differences:
  $$\Delta_{\text{unsub}} = \text{Visible}_{\text{prev}} \setminus \text{Visible}_{\text{curr}}$$
  $$\Delta_{\text{sub}} = \text{Visible}_{\text{curr}} \setminus \text{Visible}_{\text{prev}}$$
  Only off-screen symbols are unsubscribed, and newly visible symbols are subscribed, completely eliminating redundant WebSocket traffic.
- **Batch Cleanup**: `clearAll()` unsubscribes all feeds when navigating away from streaming screens.

---

## 3. Testing & Verification

Comprehensive automated test coverage verifies the throttling and lifecycle subsystems:
1. `test/stream_throttle_transformer_test.dart`:
   - Validates leading immediate emission and trailing debounced delivery.
   - Validates symbol partitioning (multiple symbols stream concurrently without crosstalk).
   - Validates memory cleanup on stream cancellation.
2. `test/schwab_streamer_service_lifecycle_test.dart`:
   - Validates registration and unregistration in `SchwabStreamerService.activeInstances`.
   - Validates `pauseStreaming()` sending `UNSUBS`, caching subscriptions, and dropping incoming data.
   - Validates `resumeStreaming()` restoring cached sets and issuing `SUBS` commands.
   - Validates multi-instance coordination via `pauseAll()` and `resumeAll()`.
3. `test/viewport_stream_coordinator_test.dart`:
   - Validates subscription truncation to `maxActiveSubscriptions`.
   - Validates viewport scroll deltas without redundant network calls.
   - Validates `clearAll()` unsubscription.
4. `test/schwab_streamer_test.dart`:
   - Validates end-to-end protocol parsing and integration without regressions (13/13 passing).
