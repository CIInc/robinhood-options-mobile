# Investment Profile Feature

## Overview
This feature adds investment profile configuration to user settings, allowing users to specify their investment goals, time horizon, risk tolerance, and portfolio value. These preferences are then integrated into AI Portfolio Recommendations to provide personalized financial advice.

## Components

### 1. User Model Changes (`lib/model/user.dart`)
Added four optional fields to the `User` class:
- `investmentGoals` (String?): User's investment objectives (e.g., "Retirement", "Education", "Wealth Building")
- `timeHorizon` (String?): Investment time horizon (e.g., "Short-term (< 1 year)", "Long-term (> 10 years)")
- `riskTolerance` (String?): User's comfort with market volatility (e.g., "Conservative", "Moderate", "Aggressive")
- `totalPortfolioValue` (double?): Current total portfolio value

#### Data Persistence
- All fields are stored in Firestore as part of the user document
- Fields are optional for backward compatibility with existing user data
- Serialization/deserialization handled via `toJson()` and `fromJson()` methods

### 2. Investment Profile Settings Widget (`lib/widgets/investment_profile_settings_widget.dart`)
A dedicated settings screen for users to configure their investment profile.

#### Features:
- **Investment Goals**: Multi-line text field for detailed goal description
- **Time Horizon**: Dropdown with predefined options
  - Short-term (< 1 year)
  - Medium-term (1-5 years)
  - Long-term (5-10 years)
  - Very long-term (> 10 years)
- **Risk Tolerance**: Dropdown with predefined options
  - Conservative
  - Moderate
  - Aggressive
  - Very Aggressive
- **Total Portfolio Value**: Optional numeric field with validation

#### Navigation:
- Accessible from User Info page under "Investment Profile" section
- Requires Firebase authentication
- Automatically saves to Firestore on form submission

### 3. AI Integration Changes

#### GenerativeService (`lib/services/generative_service.dart`)
Enhanced to include investment profile context in AI prompts:
- Modified `portfolioPrompt()` to accept user parameter
- Adds investment profile section to prompt when user data is available
- Updates both server-side and local inference methods

#### Example Prompt Enhancement:
```
This is my portfolio data:

## Investment Profile
**Investment Goals:** Retirement planning and wealth building
**Time Horizon:** Long-term (5-10 years)
**Risk Tolerance:** Moderate
**Total Portfolio Value:** $100K

[Portfolio positions table...]
```

#### AI Utilities (`lib/utils/ai.dart`)
Updated `generateContent()` and `showAIResponse()` functions to:
- Accept optional user parameter
- Pass user data through the AI generation pipeline
- Maintain backward compatibility when user is not provided

### 4. User Interface Integration

#### Home Widget (`lib/widgets/home_widget.dart`)
Updated all AI recommendation button handlers to pass user data:
- Portfolio Summary
- Portfolio Recommendations (primary use case)
- Market Summary
- Market Predictions
- Ask a question

#### User Info Widget (`lib/widgets/user_info_widget.dart`)
Added new "Investment Profile" section with:
- Icon-based navigation
- Descriptive subtitle explaining the feature
- Navigation to Investment Profile Settings widget

## Usage

### For Users:
1. Navigate to account settings/user info page
2. Select "Investment Profile Settings"
3. Fill in your investment preferences
4. Save settings
5. Use AI Portfolio Recommendations to get personalized advice

### For Developers:

#### Accessing User Investment Profile:
```dart
// Get user document from Firestore
final userDoc = await firestoreService.userCollection.doc(userId).get();
final user = userDoc.data();

// Access investment profile fields
String? goals = user.investmentGoals;
String? timeHorizon = user.timeHorizon;
String? riskTolerance = user.riskTolerance;
double? portfolioValue = user.totalPortfolioValue;
```

#### Using in AI Recommendations:
```dart
await generateContent(
  generativeProvider,
  generativeService,
  prompt,
  context,
  stockPositionStore: stockPositionStore,
  optionPositionStore: optionPositionStore,
  forexHoldingStore: forexHoldingStore,
  user: user, // Pass user data for personalized recommendations
);
```

## Testing

### Unit Tests (`test/user_model_test.dart`)
Comprehensive tests covering:
- Serialization and deserialization of investment profile fields
- Null handling for optional fields
- Backward compatibility with existing user documents
- Missing field handling

#### Run Tests:
```bash
cd src/robinhood_options_mobile
flutter test test/user_model_test.dart
```

## Security & Privacy

### Data Protection:
- Investment profile data is stored in Firestore with proper authentication
- Users can only access and modify their own investment profile
- All fields are optional and can be left blank
- No sensitive financial account data is stored in these fields

### Input Validation:
- Portfolio value validated to be positive numeric value
- All text fields have reasonable length limits
- Dropdown selections ensure data consistency

## Backward Compatibility

- All new fields are optional (nullable)
- Existing user documents work without any migration
- AI recommendations work with or without investment profile data
- Missing fields gracefully handled in all code paths

## Future Enhancements

Potential improvements:
1. Add more granular risk tolerance options
2. Support multiple investment goals with priorities
3. Include asset allocation preferences
4. Add automatic portfolio value calculation from positions
5. Historical tracking of profile changes
6. Goal progress tracking
7. Personalized asset allocation suggestions based on profile

## Technical Notes

### Dependencies:
- No new external dependencies added
- Uses existing Firebase Firestore infrastructure
- Leverages existing AI/ML capabilities

### Performance:
- Minimal impact on app performance
- Investment profile data loaded with user document
- No additional network calls for AI recommendations

### Maintenance:
- Self-contained feature with minimal cross-cutting concerns
- Clear separation between UI, data model, and AI integration
- Well-tested and documented

## Support

For issues or questions:
1. Check unit tests for usage examples
2. Review code comments in modified files
3. Refer to existing Firebase/Firestore documentation
4. Contact development team for feature-specific questions
