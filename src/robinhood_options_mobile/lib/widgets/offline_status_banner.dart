import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/services/offline_sync_service.dart';

/// A prominent, elegant status banner notifying the user that they are in Offline Mode
/// and displaying cached portfolio data with timestamps and refresh controls.
class OfflineStatusBanner extends StatelessWidget {
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry padding;

  const OfflineStatusBanner({
    super.key,
    this.onRetry,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineSyncService>(
      builder: (context, syncService, child) {
        if (!syncService.isOffline && !syncService.isShowingCachedData) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final isStale = syncService.isDataStale;
        final syncTime = syncService.syncDateTimeLabel;
        final freshness = syncService.freshnessLabel;
        final isSyncing = syncService.isSyncing;

        final badgeColor = isStale ? Colors.amber.shade700 : Colors.green.shade600;
        final badgeText = isStale ? 'Stale Data' : 'Cached Snapshot';

        return Padding(
          padding: padding,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_off_rounded,
                    color: theme.colorScheme.error,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            syncService.isOffline ? 'Offline Mode' : 'Viewing Cached Data',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: badgeColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Synced $syncTime ($freshness)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isSyncing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  TextButton.icon(
                    onPressed: onRetry ?? () => syncService.triggerSync(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
