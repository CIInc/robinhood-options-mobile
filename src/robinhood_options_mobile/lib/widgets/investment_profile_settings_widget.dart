import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

final formatCurrency = NumberFormat.simpleCurrency();

class InvestmentProfileSettingsWidget extends StatefulWidget {
  const InvestmentProfileSettingsWidget({
    super.key,
    required this.user,
    required this.firestoreService,
  });

  final User user;
  final FirestoreService firestoreService;

  @override
  State<InvestmentProfileSettingsWidget> createState() =>
      _InvestmentProfileSettingsWidgetState();
}

class _InvestmentProfileSettingsWidgetState
    extends State<InvestmentProfileSettingsWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _investmentGoalsController;
  late TextEditingController _totalPortfolioValueController;
  String? _selectedTimeHorizon;
  String? _selectedRiskTolerance;

  final List<String> _timeHorizons = [
    'Short-term (< 1 year)',
    'Medium-term (1-5 years)',
    'Long-term (5-10 years)',
    'Very long-term (> 10 years)',
  ];

  final List<String> _riskTolerances = [
    'Conservative',
    'Moderate',
    'Aggressive',
    'Very Aggressive',
  ];

  @override
  void initState() {
    super.initState();
    _investmentGoalsController =
        TextEditingController(text: widget.user.investmentGoals ?? '');
    _totalPortfolioValueController = TextEditingController(
        text: widget.user.totalPortfolioValue?.toString() ?? '');
    _selectedTimeHorizon = widget.user.timeHorizon;
    _selectedRiskTolerance = widget.user.riskTolerance;
  }

  void _autoImportPortfolioValue() {
    try {
      // Access stores using Provider.of with listen: false
      final portfolioStore =
          Provider.of<PortfolioStore>(context, listen: false);
      final stockPositionStore =
          Provider.of<InstrumentPositionStore>(context, listen: false);
      final optionPositionStore =
          Provider.of<OptionPositionStore>(context, listen: false);
      final forexHoldingStore =
          Provider.of<ForexHoldingStore>(context, listen: false);

      // Try to get the account from user's accounts list
      Account? account;
      if (widget.user.accounts.isNotEmpty) {
        account = widget.user.accounts[0]; // Use first account
      }

      // Calculate portfolio value using the same logic as home_widget.dart
      double portfolioValue = 0;
      if (portfolioStore.items.isNotEmpty && account != null) {
        portfolioValue = account.portfolioCash! +
            stockPositionStore.equity +
            optionPositionStore.equity +
            forexHoldingStore.equity;
      } else if (portfolioStore.items.isNotEmpty) {
        // Fallback: use equity from portfolio store if account is not available
        portfolioValue =
            (portfolioStore.items[0].equity ?? 0) + forexHoldingStore.equity;
      }

      // Update the text field with the calculated value
      setState(() {
        _totalPortfolioValueController.text = portfolioValue.toStringAsFixed(2);
      });

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Portfolio value imported: ${formatCurrency.format(portfolioValue)}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Handle error gracefully if stores are not available
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Unable to auto-import portfolio value. Please enter manually.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _investmentGoalsController.dispose();
    _totalPortfolioValueController.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      // Update user object
      widget.user.investmentGoals = _investmentGoalsController.text.isNotEmpty
          ? _investmentGoalsController.text
          : null;
      widget.user.timeHorizon = _selectedTimeHorizon;
      widget.user.riskTolerance = _selectedRiskTolerance;
      widget.user.totalPortfolioValue =
          _totalPortfolioValueController.text.isNotEmpty
              ? double.tryParse(_totalPortfolioValueController.text)
              : null;

      var usersCollection = widget.firestoreService.userCollection;
      var userDocumentReference =
          usersCollection.doc(fb_auth.FirebaseAuth.instance.currentUser!.uid);
      widget.firestoreService.updateUser(userDocumentReference, widget.user);
      // // Save to Firestore
      // final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
      // if (currentUser != null) {
      //   final userDocRef =
      //       widget.firestoreService.userCollection.doc(currentUser.uid);
      //   await widget.firestoreService.updateUser(userDocRef, widget.user);
      // }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Investment profile saved!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investment Profile'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              elevation: 0,
              color: colorScheme.primaryContainer.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Configure your investment profile to receive personalized AI portfolio recommendations.',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Investment Goals',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _investmentGoalsController,
              decoration: InputDecoration(
                hintText: 'e.g., Retirement, Education, Wealth Building',
                helperText: 'What are your primary investment objectives?',
                border: const OutlineInputBorder(),
                prefixIcon:
                    Icon(Icons.flag_outlined, color: colorScheme.primary),
                filled: true,
                fillColor: colorScheme.surface,
              ),
              maxLines: 3,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 24),
            Text(
              'Investment Timeline & Risk',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedTimeHorizon,
              decoration: InputDecoration(
                labelText: 'Time Horizon',
                helperText: 'How long do you plan to invest?',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule, color: colorScheme.primary),
                filled: true,
                fillColor: colorScheme.surface,
              ),
              items: _timeHorizons.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedTimeHorizon = newValue;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRiskTolerance,
              decoration: InputDecoration(
                labelText: 'Risk Tolerance',
                helperText: 'How comfortable are you with market volatility?',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.speed, color: colorScheme.primary),
                filled: true,
                fillColor: colorScheme.surface,
              ),
              items: _riskTolerances.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedRiskTolerance = newValue;
                });
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Portfolio Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _totalPortfolioValueController,
                    decoration: InputDecoration(
                      labelText: 'Total Portfolio Value (Optional)',
                      hintText: '0.00',
                      helperText:
                          'Current total value of your investment portfolio',
                      border: const OutlineInputBorder(),
                      prefixText: '\$ ',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined,
                          color: colorScheme.primary),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        if (double.parse(value) < 0) {
                          return 'Value must be positive';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56, // Match the height of the TextFormField
                  child: ElevatedButton.icon(
                    onPressed: _autoImportPortfolioValue,
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Auto-fill'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Investment Profile'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
