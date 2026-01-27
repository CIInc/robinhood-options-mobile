import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/group_message.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/model/user.dart';
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
                          size: 64,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('No messages yet. Start the conversation!',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
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

                  // Check if date changed compared to next message (which is physically below in list but newer in time?)
                  // NO, list is reverse: true.
                  // Index 0: Newest message (Bottom of screen)
                  // Index N: Oldest message (Top of screen)

                  // We want to show date header ABOVE the message if the message ABOVE it (older) is from a different day.
                  // Message "above" it in UI is at index + 1 in the list.

                  bool showDateHeader = false;
                  if (index == messages.length - 1) {
                    // Oldest message, always show date
                    showDateHeader = true;
                  } else {
                    final nextMessage = messages[index + 1].data();
                    if (!_isSameDay(message.timestamp, nextMessage.timestamp)) {
                      showDateHeader = true;
                    }
                  }

                  // Mark as read if it's not my message and I haven't read it yet
                  if (!isMe &&
                      auth.currentUser != null &&
                      !message.readBy.containsKey(auth.currentUser!.uid)) {
                    // Use microtask or just call it. Since it returns Future, it's async enough.
                    // To avoid spamming while scrolling, maybe check if it's visible?
                    // But ListView.builder only builds visible items.
                    widget.firestoreService.markGroupMessageAsRead(
                        widget.group.id, message.id, auth.currentUser!.uid);
                  }

                  return Column(
                    children: [
                      if (showDateHeader) _buildDateHeader(message.timestamp),
                      _buildMessageBubble(message, isMe, showHeader),
                    ],
                  );
                },
              );
            },
          ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String text;
    if (messageDate == today) {
      text = 'Today';
    } else if (messageDate == yesterday) {
      text = 'Yesterday';
    } else {
      text = DateFormat.yMMMd().format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(GroupMessage message, bool isMe, bool showHeader) {
    final isAdmin =
        auth.currentUser != null && widget.group.isAdmin(auth.currentUser!.uid);
    final isCreator = widget.group.createdBy == auth.currentUser?.uid;
    final canEdit = isMe;
    final canDelete = isMe || isAdmin || isCreator;

    // Read receipts info
    int readCount = message.readBy.length;
    bool isRead = readCount > 0;

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
                  style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                if (isMe)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat.jm().format(message.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withValues(alpha: 0.7),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            isRead ? Icons.done_all : Icons.done,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withValues(alpha: isRead ? 1.0 : 0.7),
                          ),
                          if (isRead && readCount > 0)
                            GestureDetector(
                              onTap: () {
                                _showReadReceipts(context, message);
                              },
                              child: Text(
                                ' $readCount',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            )
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReadReceipts(BuildContext context, GroupMessage message) {
    if (message.readBy.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Read by',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...message.readBy.entries.map((entry) {
            final userId = entry.key;
            final time = entry.value;
            // Fetch user info or use just ID if extensive, but here we likely want names.
            // Since we don't have user names readily available in message.readBy map,
            // we can try to look it up from group members helper if available, or just
            // show "User matching ID" or fetch.
            // For now, let's use StreamBuilder or FutureBuilder to fetch specific user name?
            // Or just check group.members to see if we have names cached?
            // InvestorGroup stores Member IDs.
            // We'll use a FutureBuilder to fetch basic user info.

            return FutureBuilder<DocumentSnapshot<User>>(
                future: widget.firestoreService.getUser(userId).first,
                builder: (context, snapshot) {
                  final user = snapshot.data?.data();
                  final name = user?.name ?? 'Unknown User';
                  final photoUrl = user?.photoUrl;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: photoUrl != null
                          ? CachedNetworkImageProvider(photoUrl)
                          : null,
                      child: photoUrl == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(name),
                    subtitle: Text(DateFormat.jm().format(time)),
                  );
                });
          }),
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
            color: Colors.black.withValues(alpha: 0.05),
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
