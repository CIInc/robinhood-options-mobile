import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';

/// Shared widget for displaying technical indicator documentation
/// with expandable technical details section.
class IndicatorDocumentationWidget extends StatelessWidget {
  final String indicatorKey;
  final bool showContainer;

  const IndicatorDocumentationWidget({
    super.key,
    required this.indicatorKey,
    this.showContainer = false,
  });

  @override
  Widget build(BuildContext context) {
    final docInfo = TradeSignalsProvider.indicatorDocumentation(indicatorKey);
    final title = docInfo['title'] ?? '';
    final description = docInfo['description'] ?? '';
    final technicalDetails = docInfo['technicalDetails'] ?? '';

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(fontSize: 14),
        ),
        if (technicalDetails.isNotEmpty) ...[
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
              title: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Technical Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: MarkdownBody(
                    data: technicalDetails,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                      ),
                      listBullet: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      code: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    if (showContainer) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: content,
    );
  }
}
