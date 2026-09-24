import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/group_analysis.dart';

/// Renders a single discussion comment with author-pinned status,
/// upvoting, and moderation reporting options.
class SocialCommentItemWidget extends StatefulWidget {
  final GroupAnalysisComment comment;
  final String? currentUserId;
  final bool canPin;
  final bool canDelete;
  final VoidCallback? onToggleLike;
  final VoidCallback? onTogglePin;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onReport;

  const SocialCommentItemWidget({
    super.key,
    required this.comment,
    this.currentUserId,
    this.canPin = false,
    this.canDelete = false,
    this.onToggleLike,
    this.onTogglePin,
    this.onDelete,
    this.onReport,
  });

  @override
  State<SocialCommentItemWidget> createState() =>
      _SocialCommentItemWidgetState();
}

class _SocialCommentItemWidgetState extends State<SocialCommentItemWidget> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.comment;
    final isLiked =
        widget.currentUserId != null && c.isLikedBy(widget.currentUserId!);
    final isReportedByMe = widget.currentUserId != null &&
        c.isReportedBy(widget.currentUserId!);

    if (isReportedByMe && !_revealed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.flag_outlined, size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Comment reported by you under review',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _revealed = true),
              child: const Text('Show', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.isPinned
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.isPinned
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: c.isPinned ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pinned badge if pinned
          if (c.isPinned) ...[
            Row(
              children: [
                Icon(Icons.push_pin,
                    size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Pinned by author',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          // Header: Avatar, Name, Timestamp, Actions Menu
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: c.authorPhotoUrl != null
                    ? CachedNetworkImageProvider(c.authorPhotoUrl!)
                    : null,
                child: c.authorPhotoUrl == null
                    ? Text(
                        c.authorName.isNotEmpty
                            ? c.authorName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 11),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      DateFormat.MMMd().add_jm().format(c.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Upvote Button
              InkWell(
                onTap: widget.onToggleLike,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLiked
                            ? Icons.thumb_up_rounded
                            : Icons.thumb_up_outlined,
                        size: 15,
                        color: isLiked ? theme.colorScheme.primary : null,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${c.upvotesCount}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isLiked ? FontWeight.bold : FontWeight.normal,
                          color: isLiked ? theme.colorScheme.primary : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Overflow Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 16),
                padding: EdgeInsets.zero,
                tooltip: 'More options',
                onSelected: (value) {
                  if (value == 'pin') {
                    widget.onTogglePin?.call();
                  } else if (value == 'delete') {
                    widget.onDelete?.call();
                  } else if (value == 'report') {
                    _showReportDialog(context);
                  }
                },
                itemBuilder: (context) => [
                  if (widget.canPin)
                    PopupMenuItem(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(
                            c.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(c.isPinned ? 'Unpin Comment' : 'Pin Comment'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'report',
                    child: const Row(
                      children: [
                        Icon(Icons.flag_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Report Comment'),
                      ],
                    ),
                  ),
                  if (widget.canDelete)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Comment',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Content
          SelectableText(
            c.content,
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    const reasons = [
      'Spam or advertising',
      'Misinformation / Market manipulation',
      'Harassment or hate speech',
      'Inappropriate or offensive content',
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.flag_outlined, size: 20),
            SizedBox(width: 8),
            Text('Report Comment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a reason for reporting this comment to moderators:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...reasons.map(
              (r) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.circle_outlined, size: 16),
                title: Text(r, style: const TextStyle(fontSize: 13)),
                onTap: () {
                  Navigator.pop(dialogCtx);
                  widget.onReport?.call(r);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Report submitted: $r'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
