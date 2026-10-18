import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

typedef ErrorCallback = void Function(String error);

class GroupWatchlistCreateWidget extends StatefulWidget {
  final String groupId;
  final String userId;
  final VoidCallback onCreated;
  final ErrorCallback? onError;

  const GroupWatchlistCreateWidget({
    super.key,
    required this.groupId,
    required this.userId,
    required this.onCreated,
    this.onError,
  });

  @override
  State<GroupWatchlistCreateWidget> createState() =>
      _GroupWatchlistCreateWidgetState();
}

class _GroupWatchlistCreateWidgetState
    extends State<GroupWatchlistCreateWidget> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createWatchlist() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Watchlist name is required');
      return;
    }

    if (_nameController.text.length > 100) {
      setState(() => _error = 'Watchlist name must be 100 characters or less');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final functions = FirebaseFunctions.instance;
      final result =
          await functions.httpsCallable('createGroupWatchlist').call({
        'groupId': widget.groupId,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
      });

      if (result.data['success'] == true) {
        widget.onCreated();
      }
    } on FirebaseFunctionsException catch (e) {
      final errorCode = e.code;
      String userMessage = e.message ?? 'Failed to create watchlist';

      // Provide more helpful error messages based on error codes
      if (errorCode == 'permission-denied') {
        userMessage =
            'You don\'t have permission to create watchlists in this group.\n\n'
            'Make sure you are a member of the group.';
      } else if (errorCode == 'not-found') {
        userMessage = 'Group not found.\n\nThe group may have been deleted.';
      } else if (errorCode == 'unauthenticated') {
        userMessage = 'You must be logged in to create watchlists.';
      } else if (errorCode == 'invalid-argument') {
        userMessage = 'Please fill in all required fields.';
      }

      setState(() => _error = userMessage);
      widget.onError?.call(userMessage);
    } catch (e) {
      final error = 'An error occurred: ${e.toString()}';
      setState(() => _error = error);
      widget.onError?.call(error);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.bookmark_outline,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Create Watchlist'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Watchlist Name',
                hintText: 'e.g., Tech Stocks, Growth Stocks',
                prefixIcon: const Icon(Icons.bookmark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                errorMaxLines: 2,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              enabled: !_isLoading,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Watchlist name is required';
                }
                if (value.length > 100) {
                  return 'Name must be 100 characters or less';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'What is this watchlist for?',
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                errorMaxLines: 2,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: 3,
              enabled: !_isLoading,
              validator: (value) {
                if (value != null && value.length > 500) {
                  return 'Description must be 500 characters or less';
                }
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.error.withOpacity(0.15)
                      : Theme.of(context).colorScheme.error.withOpacity(0.1),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red[900],
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _createWatchlist,
          icon: _isLoading ? null : const Icon(Icons.add),
          label: _isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                )
              : const Text('Create Watchlist'),
        ),
      ],
    );
  }
}
