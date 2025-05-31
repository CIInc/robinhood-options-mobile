import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

/// Widget for managing portfolio sharing settings (users, groups, public)
class SharePortfolioWidget extends StatefulWidget {
  final String userId;
  final List<String>? initialSharedWith;
  final List<String>? initialSharedGroups;
  final bool? initialIsPublic;
  final FirestoreService firestoreService;
  final Future<void> Function(
          List<String> sharedWith, List<String> sharedGroups, bool isPublic)?
      onSharingChanged;

  const SharePortfolioWidget({
    super.key,
    required this.userId,
    required this.firestoreService,
    this.initialSharedWith,
    this.initialSharedGroups,
    this.initialIsPublic,
    this.onSharingChanged,
  });

  @override
  State<SharePortfolioWidget> createState() => _SharePortfolioWidgetState();
}

class _SharePortfolioWidgetState extends State<SharePortfolioWidget> {
  late List<String> sharedWith;
  late List<String> sharedGroups;
  late bool isPublic;
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _groupController = TextEditingController();

  @override
  void initState() {
    super.initState();
    sharedWith = List<String>.from(widget.initialSharedWith ?? []);
    sharedGroups = List<String>.from(widget.initialSharedGroups ?? []);
    isPublic = widget.initialIsPublic ?? false;
  }

  Future<void> _saveSharing() async {
    if (widget.onSharingChanged != null) {
      await widget.onSharingChanged!(sharedWith, sharedGroups, isPublic);
    } else {
      await widget.firestoreService.setPortfolioSharing(
        widget.userId,
        sharedWithUserIds: sharedWith,
        sharedGroups: sharedGroups,
        isPublic: isPublic,
      );
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Sharing settings updated!')),
      //   );
      // }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          //leading: Icon(Icons.functions),
          title: const Text("Public"),
          subtitle: const Text("Anyone can view"),
          value: isPublic, // user.persistToFirebase,
          onChanged: (val) async {
            setState(() => isPublic = val);
            await _saveSharing();
          },
          secondary: const Icon(Icons.public_outlined),
        ),
        ListTile(
          title: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userController,
                  decoration:
                      const InputDecoration(labelText: 'Add user by ID'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  if (_userController.text.isNotEmpty) {
                    setState(() {
                      sharedWith.add(_userController.text);
                      _userController.clear();
                    });
                    await _saveSharing();
                  }
                },
              ),
            ],
          ),
        ),
        Wrap(
          children: sharedWith
              .map((user) => Chip(
                    label: Text(user),
                    onDeleted: () async {
                      setState(() => sharedWith.remove(user));
                      await _saveSharing();
                    },
                  ))
              .toList(),
        ),
        ListTile(
          title: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _groupController,
                  decoration:
                      const InputDecoration(labelText: 'Add group by ID'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  if (_groupController.text.isNotEmpty) {
                    setState(() {
                      sharedGroups.add(_groupController.text);
                      _groupController.clear();
                    });
                    await _saveSharing();
                  }
                },
              ),
            ],
          ),
        ),
        Wrap(
          children: sharedGroups
              .map((group) => Chip(
                    label: Text(group),
                    onDeleted: () async {
                      setState(() => sharedGroups.remove(group));
                      await _saveSharing();
                    },
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
