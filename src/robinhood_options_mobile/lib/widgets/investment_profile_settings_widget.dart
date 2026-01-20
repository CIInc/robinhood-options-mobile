import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/investment_profile.dart';
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
  bool _isSaving = false;
  late TextEditingController _totalPortfolioValueController;
  String? _selectedInvestmentGoal;
  String? _selectedTimeHorizon;
  String? _selectedRiskTolerance;
  bool _hasChanges = false;

  final List<String> _investmentGoals = InvestmentProfile.investmentGoalOptions;
  final List<String> _timeHorizons = InvestmentProfile.timeHorizonOptions;
  final List<String> _riskTolerances = InvestmentProfile.riskToleranceOptions;

  @override
  void initState() {
    super.initState();
    _totalPortfolioValueController = TextEditingController();
    _totalPortfolioValueController.addListener(_checkForChanges);
    _loadSettings();
  }

  void _checkForChanges() {
    final original = widget.user.investmentProfile;
    final currentVal =
        double.tryParse(_totalPortfolioValueController.text) ?? 0.0;
    final originalVal = original?.totalPortfolioValue ?? 0.0;

    final hasChanges = _selectedInvestmentGoal != original?.investmentGoals ||
        _selectedTimeHorizon != original?.timeHorizon ||
        _selectedRiskTolerance != original?.riskTolerance ||
        (currentVal - originalVal).abs() > 0.01;

    if (_hasChanges != hasChanges) {
      if (mounted) {
        setState(() {
          _hasChanges = hasChanges;
        });
      }
    }
  }

  void _loadSettings() {
    if (!mounted) return;
    setState(() {
      _totalPortfolioValueController.text =
          widget.user.investmentProfile?.totalPortfolioValue?.toString() ?? '';

      final loadedGoal = widget.user.investmentProfile?.investmentGoals;
      _selectedInvestmentGoal =
          _investmentGoals.contains(loadedGoal) ? loadedGoal : null;

      final loadedHorizon = widget.user.investmentProfile?.timeHorizon;
      _selectedTimeHorizon =
          _timeHorizons.contains(loadedHorizon) ? loadedHorizon : null;

      final loadedRisk = widget.user.investmentProfile?.riskTolerance;
      _selectedRiskTolerance =
          _riskTolerances.contains(loadedRisk) ? loadedRisk : null;

      _hasChanges = false;
    });
  }

  void _autoImportPortfolioValue() {
    try {
      final portfolioStore =
          Provider.of<PortfolioStore>(context, listen: false);
      final stockPositionStore =
          Provider.of<InstrumentPositionStore>(context, listen: false);
      final optionPositionStore =
          Provider.of<OptionPositionStore>(context, listen: false);
      final forexHoldingStore =
          Provider.of<ForexHoldingStore>(context, listen: false);

      Account? account;
      if (widget.user.allAccounts.isNotEmpty) {
        account = widget.user.allAccounts[0];
      }

      double portfolioValue = 0;
      if (portfolioStore.items.isNotEmpty && account != null) {
        portfolioValue = (account.portfolioCash ?? 0) +
            stockPositionStore.equity +
            optionPositionStore.equity +
            forexHoldingStore.equity;
      } else if (portfolioStore.items.isNotEmpty) {
        portfolioValue =
            (portfolioStore.items[0].equity ?? 0) + forexHoldingStore.equity;
      }

      // Update text. Listener will trigger _checkForChanges
      _totalPortfolioValueController.text = portfolioValue.toStringAsFixed(2);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Portfolio value imported: ${formatCurrency.format(portfolioValue)}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Unable to auto-import portfolio value. Please enter manually.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _totalPortfolioValueController.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });
      try {
        widget.user.investmentProfile ??= InvestmentProfile();

        widget.user.investmentProfile!.investmentGoals =
            _selectedInvestmentGoal;
        widget.user.investmentProfile!.timeHorizon = _selectedTimeHorizon;
        widget.user.investmentProfile!.riskTolerance = _selectedRiskTolerance;
        widget.user.investmentProfile!.totalPortfolioValue =
            _totalPortfolioValueController.text.isNotEmpty
                ? double.tryParse(_totalPortfolioValueController.text)
                : null;

        var usersCollection = widget.firestoreService.userCollection;
        var userDocumentReference =
            usersCollection.doc(fb_auth.FirebaseAuth.instance.currentUser!.uid);
        await widget.firestoreService
            .updateUser(userDocumentReference, widget.user);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Investment profile saved!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Manually reset state before popping to allow PopScope to pass
          setState(() {
            _hasChanges = false;
            _isSaving = false;
          });
          Navigator.pop(context);
        }
      } finally {
        if (mounted && _isSaving) {
          setState(() {
            _isSaving = false;
          });
        }
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_isSaving || !_hasChanges) ? null : _saveSettings,
        backgroundColor:
            _hasChanges ? null : theme.colorScheme.surfaceContainerHighest,
        foregroundColor: _hasChanges ? null : theme.colorScheme.outline,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save),
        label: const Text('Save'),
      ),
      body: PopScope(
        canPop: !_hasChanges && !_isSaving,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final bool? shouldPop = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Discard Changes?'),
              content: const Text(
                  'You have unsaved changes. Are you sure you want to leave without saving?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          if (shouldPop == true && context.mounted) {
            Navigator.pop(context);
          }
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
            children: [
              Card(
                elevation: 0,
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
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
                            color: colorScheme.onSurface.withValues(alpha: 0.8),
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
              DropdownButtonFormField<String>(
                key: ValueKey('goal_$_selectedInvestmentGoal'),
                initialValue: _selectedInvestmentGoal,
                decoration: InputDecoration(
                  labelText: 'Investment Goal',
                  helperText: 'What are your primary investment objectives?',
                  border: const OutlineInputBorder(),
                  prefixIcon:
                      Icon(Icons.flag_outlined, color: colorScheme.primary),
                  filled: true,
                  fillColor: colorScheme.surface,
                ),
                items: _investmentGoals.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedInvestmentGoal = newValue;
                    _checkForChanges();
                  });
                },
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
                key: ValueKey('time_$_selectedTimeHorizon'),
                initialValue: _selectedTimeHorizon,
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
                    _checkForChanges();
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('risk_$_selectedRiskTolerance'),
                initialValue: _selectedRiskTolerance,
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
                    _checkForChanges();
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
                            horizontal: 16, vertical: 0),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
