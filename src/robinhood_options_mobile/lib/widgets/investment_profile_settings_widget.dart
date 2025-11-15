import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investment Profile'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              'Configure your investment profile to receive personalized AI portfolio recommendations.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _investmentGoalsController,
              decoration: const InputDecoration(
                labelText: 'Investment Goals',
                hintText: 'e.g., Retirement, Education, Wealth Building',
                helperText: 'What are your primary investment objectives?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedTimeHorizon,
              decoration: const InputDecoration(
                labelText: 'Time Horizon',
                helperText: 'How long do you plan to invest?',
                border: OutlineInputBorder(),
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
              decoration: const InputDecoration(
                labelText: 'Risk Tolerance',
                helperText: 'How comfortable are you with market volatility?',
                border: OutlineInputBorder(),
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _totalPortfolioValueController,
              decoration: const InputDecoration(
                labelText: 'Total Portfolio Value (Optional)',
                hintText: '0.00',
                helperText: 'Current total value of your investment portfolio',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
              ),
              child: const Text('Save Investment Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
