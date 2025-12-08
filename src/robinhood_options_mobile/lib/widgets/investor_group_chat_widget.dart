import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/group_message.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:intl/intl.dart';

class InvestorGroupChatWidget extends StatefulWidget {
  final InvestorGroup group;
  final FirestoreService firestoreService;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  const InvestorGroupChatWidget({
    super.key,
    required this.group,
    required this.firestoreService,
    required this.analytics,
    required this.observer,
  });

  @override
  State<InvestorGroupChatWidget> createState() =>
      _InvestorGroupChatWidgetState();
}

class _InvestorGroupChatWidgetState extends State<InvestorGroupChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  GroupMessage? _editingMessage;

  @override
  void initState() {
    super.initState();
    widget.analytics.logScreenView(screenName: 'InvestorGroupChat');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder(
            stream: widget.firestoreService.getGroupMessages(widget.group.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data?.docs ?? [];

              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('No messages yet. Start the conversation!',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                reverse: true,
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index].data();
                  final isMe = message.senderId == auth.currentUser?.uid;
                  final showHeader = index == messages.length - 1 ||
                      messages[index + 1].data().senderId != message.senderId;

                  return _buildMessageBubble(message, isMe, showHeader);
                },
              );
            },
          ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageBubble(GroupMessage message, bool isMe, bool showHeader) {
    final isAdmin =
        auth.currentUser != null && widget.group.isAdmin(auth.currentUser!.uid);
    final isCreator = widget.group.createdBy == auth.currentUser?.uid;
    final canEdit = isMe;
    final canDelete = isMe || isAdmin || isCreator;

    return GestureDetector(
      onLongPress: () {
        if (canEdit || canDelete) {
          _showMessageOptions(context, message, canEdit, canDelete);
        }
      },
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showHeader && !isMe) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (message.senderPhotoUrl != null)
                  CircleAvatar(
                    radius: 12,
                    backgroundImage:
                        CachedNetworkImageProvider(message.senderPhotoUrl!),
                  )
                else
                  const CircleAvatar(
                    radius: 12,
                    child: Icon(Icons.person, size: 16),
                  ),
                const SizedBox(width: 8),
                Text(
                  message.senderName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat.jm().format(message.timestamp),
                  style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (showHeader && isMe) const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
                bottomRight: isMe ? Radius.zero : const Radius.circular(20),
              ),
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    color: isMe
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isMe && showHeader)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      DateFormat.jm().format(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withOpacity(0.7),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -1),
            blurRadius: 5,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_editingMessage != null)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _editingMessage = null;
                    _messageController.clear();
                  });
                },
              ),
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _editingMessage != null
                      ? 'Edit message...'
                      : 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                minLines: 1,
                maxLines: 5,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _editingMessage != null ? Icons.check : Icons.send,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context, GroupMessage message,
      bool canEdit, bool canDelete) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _editMessage(GroupMessage message) {
    setState(() {
      _editingMessage = message;
      _messageController.text = message.text;
    });
  }

  Future<void> _deleteMessage(GroupMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.firestoreService
            .deleteGroupMessage(widget.group.id, message.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting message: $e')),
          );
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || auth.currentUser == null) return;

    setState(() => _isSending = true);

    try {
      if (_editingMessage != null) {
        final updatedMessage = GroupMessage(
          id: _editingMessage!.id,
          senderId: _editingMessage!.senderId,
          senderName: _editingMessage!.senderName,
          senderPhotoUrl: _editingMessage!.senderPhotoUrl,
          text: text,
          timestamp: _editingMessage!.timestamp,
          type: _editingMessage!.type,
        );
        await widget.firestoreService
            .updateGroupMessage(widget.group.id, updatedMessage);
        setState(() {
          _editingMessage = null;
        });
      } else {
        final user = auth.currentUser!;
        final message = GroupMessage(
          id: '', // Will be set by Firestore
          senderId: user.uid,
          senderName: user.displayName ?? 'User',
          senderPhotoUrl: user.photoURL,
          text: text,
          timestamp: DateTime.now(),
        );

        await widget.firestoreService
            .sendGroupMessage(widget.group.id, message);
      }
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }
}
