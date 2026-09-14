# Combo Orders (Stock + Option Packages)

RealizeAlpha v0.44.0 introduces end-to-end support for **Combo Orders**, enabling traders to execute, monitor, and manage complex multi-leg packages combining equity and option legs (such as Covered Calls, Collars, and Married Puts) as a single atomic transaction through Robinhood's `/combo/orders/` API.

---

## Overview

A combo order is a multi-leg package where equity shares and one or more option contracts are submitted and filled atomically. This eliminates execution leg risk (the danger that one leg fills while the other fails or moves against the trader).

### Supported Package Types

1. **Covered Call**:
   - Buy (or hold) 100 shares of underlying equity.
   - Sell (write) 1 call option against the position for income/premium generation.
2. **Collar**:
   - Long 100 shares of equity.
   - Long 1 protective put option (limiting downside risk).
   - Short 1 covered call option (funding or subsidizing the put premium).
3. **Married Put**:
   - Buy 100 shares of equity.
   - Buy 1 protective put option for defined-risk downside insurance.
4. **Custom Multi-Leg Packages**:
   - Arbitrary combinations of equity and option legs with customizable ratios and position effects (`open` / `close`).

---

## Architecture & Implementation

### 1. Domain Models (`lib/model/combo_order.dart`)

- **`ComboOrder`**: Represents the complete combo order package, containing metadata (id, refId, state, price, quantity, direction, openingStrategy, createdAt, updatedAt) and its child legs.
- **`ComboLeg`**: Defines an individual leg within the combo:
  - `legType`: `ComboLegType.equity` or `ComboLegType.option`.
  - `symbol`, `side` (`buy` / `sell`), `positionEffect` (`open` / `close`).
  - `ratioQuantity`: Integer ratio of shares or contracts per package unit.
  - Option parameters: `strikePrice`, `expirationDate`, `optionType` (`call` / `put`).
- **`ComboLegExecution`**: Captures fill executions for a specific leg (id, price, quantity, settlementDate, timestamp).
- **Helpers**:
  - `packageTypeDisplay`: Human-readable package strategy name (synthesizing from leg definitions if `openingStrategy` is unspecified).
  - `summaryTitle`: Primary symbol combined with the strategy name (e.g., `AAPL Covered Call`).
  - `isFilled`, `isOpen`, `canCancel`: Lifecycle inspection flags.
  - `netAmount`, `netDisplayPrice`: Net credit/debit calculation.
  - `toCsvRow()`: CSV serialization for tax and trade journaling exports.

### 2. State Management (`lib/model/combo_order_store.dart`)

- `ComboOrderStore` provides reactive state management via `ChangeNotifier`:
  - `items`: List of current combo orders.
  - `setItems(List<ComboOrder>)`: Batch load and refresh.
  - `addOrUpdate(ComboOrder)`: Upsert orders into the store.
  - `remove(String id)`: Order deletion handling.
  - `bySymbol(String symbol)`: Filter combo orders for an underlying asset.
  - `openOrders` & `completedOrders`: Filtered views based on order lifecycle states (`queued`, `confirmed`, `filled`, `cancelled`, `rejected`).
- Registered in `main.dart` with `MultiProvider`.

### 3. Brokerage Integration (`lib/services/`)

- **`IBrokerageService`**: Extended with:
  - `getComboOrders(BrokerageUser, {bool nonzero, String? state})`
  - `streamComboOrders(BrokerageUser)`
  - `placeComboOrder(BrokerageUser, Map<String, dynamic>)`
  - `cancelComboOrder(BrokerageUser, String cancelUrl)`
- **`RobinhoodService`**:
  - Connects to `https://api.robinhood.com/combo/orders/`.
  - Supports polling with pagination and real-time streaming updates.
  - Implements combo order placement and cancellation.
  - Caches orders in Cloud Firestore via `FirestoreService.upsertComboOrders`.
- **`DemoService` & `PaperService`**:
  - Seeded realistic mock combo packages (`AAPL Covered Call`, `TSLA Collar`, `NVDA Married Put`).
  - Allows full simulation of combo order placement, fills, and cancellation without risking real capital.

### 4. User Interface (`lib/widgets/`)

- **`ComboOrdersWidget` (`lib/widgets/combo_orders_widget.dart`)**:
  - Sliver-based sticky header with total net premium balance indicator.
  - Filter chips: `All`, `Filled`, `Queued`, `Confirmed`, `Cancelled`, `Rejected`.
  - Responsive list cards displaying symbol avatar, strategy type, execution date, leg count badge, and net credit/debit.
- **`ComboOrderWidget` (`lib/widgets/combo_order_widget.dart`)**:
  - Comprehensive detail view including order status banner with color-coded chip.
  - Package strategy summary with net amount, quantity, and limit price.
  - Multi-leg breakdown card illustrating each leg's side, ratio quantity, strike, expiration, and fill executions.
  - Real-time order cancellation dialog for open (`canCancel`) orders.
- **Screen Integrations**:
  - **`HistoryWidget` (`lib/widgets/history_widget.dart`)**: Added dedicated `Combos` tab alongside Stocks, Options, Dividends, and Interests.
  - **`InstrumentWidget` (`lib/widgets/instrument_widget.dart`)**: Added dedicated combo orders section in stock detail activity slivers.

---

## Verification & Testing

The combo order suite includes comprehensive automated tests:
- `test/combo_order_test.dart`: Serialization, deserialization, helper getters, collar/covered-call synthesis, CSV export.
- `test/combo_order_store_test.dart`: Reactive notifications, upserts, deletions, symbol and status filtering.
- `test/combo_order_widget_test.dart`: UI rendering of lists, filter chips, detail pages, leg breakdowns, and cancellation dialog interactions.
