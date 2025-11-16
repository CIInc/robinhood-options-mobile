import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

class InvestorGroupCreateWidget extends StatefulWidget {
  final FirestoreService firestoreService;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  const InvestorGroupCreateWidget({
    super.key,
    required this.firestoreService,
    required this.analytics,
    required this.observer,
  });

  @override
  State<InvestorGroupCreateWidget> createState() =>
      _InvestorGroupCreateWidgetState();
}

class _InvestorGroupCreateWidgetState extends State<InvestorGroupCreateWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPrivate = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Investor Group'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create a new investor group to share portfolios and collaborate with other investors.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'e.g., Tech Investors, Day Traders',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.groups),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a group name';
                  }
                  if (value.length < 3) {
                    return 'Group name must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'What is this group about?',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              Card(
                child: SwitchListTile(
                  title: const Text('Private Group'),
                  subtitle: const Text(
                    'Private groups require approval to join. Public groups are open to everyone.',
                  ),
                  value: _isPrivate,
                  onChanged: (value) {
                    setState(() {
                      _isPrivate = value;
                    });
                  },
                  secondary: Icon(
                    _isPrivate ? Icons.lock : Icons.public,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createGroup,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.add),
                  label: Text(_isLoading ? 'Creating...' : 'Create Group'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to create a group')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final group = InvestorGroup(
        id: '', // Will be set by Firestore
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        createdBy: auth.currentUser!.uid,
        members: [auth.currentUser!.uid], // Creator is automatically a member
        admins: [auth.currentUser!.uid], // Creator is automatically an admin
        dateCreated: DateTime.now(),
        isPrivate: _isPrivate,
      );

      await widget.firestoreService.createInvestorGroup(group);

      // Log analytics event
      await widget.analytics.logEvent(
        name: 'create_investor_group',
        parameters: {
          'group_name': group.name,
          'is_private': _isPrivate,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
