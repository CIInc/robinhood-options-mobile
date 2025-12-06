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
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Create a new investor group to share portfolios and collaborate with other investors.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Group Information',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'e.g., Tech Investors, Day Traders',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.groups,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'What is this group about?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.description,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              Text(
                'Privacy Settings',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  title: const Text(
                    'Private Group',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
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
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
          'is_private': _isPrivate.toString(),
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
