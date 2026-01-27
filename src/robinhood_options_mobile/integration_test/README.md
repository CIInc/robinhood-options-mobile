# Integration Tests

This directory contains integration tests for the Robinhood Options Mobile app.

## Running Tests

To run the integration tests, use the following command:

```bash
flutter test integration_test/app_test.dart
```

To run the comprehensive smoke test:

```bash
flutter test integration_test/smoke_test.dart
```

This will run the tests on the connected device or emulator.

To run against a local Firestore emulator (requires configuring `main.dart` or passing build args):

```bash
flutter test integration_test/app_test.dart --dart-define=USE_FIRESTORE_EMULATOR=true
```

## Test Coverage

Currently, the test suite covers:
- App launch smoke test
- Verification of main navigation widget presence
- Initial "Authentication Required" lock screen interaction
- Verifying "Unlock" functionality (assuming biometrics disabled in test env)
- **Conditional Logic for Session State**:
  - **Not Logged In (Guest Mode)**:
    - Validation of "Welcome" screen content on Home/Portfolio tab.
    - Restricted access to History tab (shows Welcome screen).
    - Access to Search tab and Search Bar interaction.
    - Restricted access to Trade Signals tab (Login prompt).
    - Access to Investor Groups tab (Discover public groups) but restricted "My Groups".
  - **Logged In (Partial/Full)**:
    - Handles existing Firebase session states by adapting expectations.
  - **Auth Entry Points**:
    - "Link Brokerage Account" button navigation to Login.
    - Profile Icon navigation to Auth/User Profile modal.
  - **Login Widget & Execution**:
    - **Demo Login Flow**:
      - Switch brokerage source to "Demo".
      - Tap "Open Demo Account".
      - Verify successful login and navigation back to Home.
    - Validate absence of "Welcome" screen after login.
  - **Post-Login Verification**:
    - **History Tab**: Verify access granted (Welcome screen gone).
    - **Search Tab**: Verify search interaction in authenticated context.
  - **Market Assistant**:
    - Tap Floating Action Button.

### Smoke Test (`smoke_test.dart`)

New comprehensive smoke test covering:
- **Navigation Integrity**: Cycles through all main tabs (Portfolio, History, Search, Signals, Investors).
- **Demo Login**: Verifies the full end-to-end demo login flow.
- **Widget Verification**: Checks for key indicators on each page to ensure correct loading.
    - Verify Chat UI (Title, Welcome Message, Input Field).
    - Basic interaction test (Enter Text).
    - Navigation to "Login" screen via "Link Brokerage Account" button
    - Navigation back to Home screen
  - **Logged In** (if session persists):
    - Verification that Welcome screen is NOT present
    - Basic navigation interaction (switching tabs)

## Future Improvements

To fully test authentication and trading flows, the following changes are recommended:
1. Refactor `main.dart` to allow dependency injection for `FirebaseAuth` and `FirebaseFirestore`.
2. Create specific test configurations that use the Firestore Emulator and Firebase Auth Emulator.
3. Use a test account or mocked auth provider to bypass the login screen programmatically.
