import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/institutional_ownership.dart';

class InstitutionalOwnershipWidget extends StatelessWidget {
  final InstitutionalOwnership? ownership;
  final double? currentPrice;

  const InstitutionalOwnershipWidget(
      {super.key, this.ownership, this.currentPrice});

  @override
  Widget build(BuildContext context) {
    if (ownership == null) {
      return const SizedBox.shrink();
    }

    final double percentage = ownership!.percentageHeld ?? 0;
    // Calculate max shares for relative bar sizing (top 5 only for the card view)
    final holders = ownership!.topHolders;
    final displayHolders = holders.take(5).toList();
    final double maxShares = displayHolders.isNotEmpty
        ? displayHolders
            .map((h) => h.sharesHeld)
            .reduce((a, b) => a > b ? a : b)
        : 0;

    final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 0);
    final percentFormat = NumberFormat.decimalPercentPattern(decimalDigits: 2);
    final shareFormat = NumberFormat.compact();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: percentage,
                        strokeWidth: 8,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    Text(
                      percentFormat.format(percentage),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Institutional Ownership',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'of outstanding shares',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (ownership!.floatPercentageHeld != null ||
                ownership!.insidersPercentageHeld != null ||
                ownership!.institutionCount != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (ownership!.floatPercentageHeld != null)
                    Column(
                      children: [
                        Text(
                          percentFormat.format(ownership!.floatPercentageHeld!),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '% of Float',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  if (ownership!.insidersPercentageHeld != null)
                    Column(
                      children: [
                        Text(
                          percentFormat
                              .format(ownership!.insidersPercentageHeld!),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '% Insiders',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  if (ownership!.institutionCount != null)
                    Column(
                      children: [
                        Text(
                          NumberFormat.decimalPattern()
                              .format(ownership!.institutionCount!),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Institutions',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Top Holders',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (currentPrice != null)
                  Text(
                    'Est. Value',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (holders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Theme.of(context).disabledColor),
                    const SizedBox(width: 8),
                    const Text('No holder data available.'),
                  ],
                ),
              )
            else
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: displayHolders.length,
                separatorBuilder: (context, index) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final holder = displayHolders[index];
                  // percentageChange here is actually % Held from API mapping, not change.
                  final pctHeld = holder.percentageChange ?? 0;
                  final value = currentPrice != null
                      ? holder.sharesHeld * currentPrice!
                      : null;
                  final double relativeSize =
                      maxShares > 0 ? holder.sharesHeld / maxShares : 0;

                  return Stack(
                    children: [
                      // Background relative bar
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: relativeSize * 0.95, // Max 95% width
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4), // Small padding for text
                        dense: true,
                        minVerticalPadding: 0,
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          holder.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                            '${shareFormat.format(holder.sharesHeld)} shares ${pctHeld > 0 ? '(${percentFormat.format(pctHeld)})' : ''}'),
                        trailing: value != null
                            ? Text(
                                currencyFormat.format(value),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                    ],
                  );
                },
              ),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showAllHolders(context, holders),
                child: const Text('View All Institutions'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllHolders(
      BuildContext context, List<InstitutionalHolder> holders) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 0);
          final percentFormat =
              NumberFormat.decimalPercentPattern(decimalDigits: 2);
          final shareFormat = NumberFormat.decimalPattern();

          // Calculate max shares for the full list relative bars
          final double maxListShares = holders.isNotEmpty
              ? holders.map((h) => h.sharesHeld).reduce((a, b) => a > b ? a : b)
              : 0;

          return Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Institutional Holders',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${holders.length} Institutions',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (ownership?.floatPercentageHeld != null)
                          Text(
                            '${percentFormat.format(ownership!.floatPercentageHeld)} Float',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (ownership?.insidersPercentageHeld != null)
                          Text(
                            '${percentFormat.format(ownership!.insidersPercentageHeld)} Insiders',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                        child: Text('Institution',
                            style: Theme.of(context).textTheme.labelMedium)),
                    Text('Holdings',
                        style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: holders.isEmpty
                    ? const Center(child: Text('No data available'))
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: holders.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final holder = holders[index];
                          final pctHeld = holder.percentageChange ?? 0;
                          final value = currentPrice != null
                              ? holder.sharesHeld * currentPrice!
                              : null;
                          final double relativeSize = maxListShares > 0
                              ? holder.sharesHeld / maxListShares
                              : 0;

                          return Stack(
                            children: [
                              Positioned.fill(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: relativeSize * 0.95,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                title: Text(
                                  holder.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  'Reported: ${holder.dateReported != null ? DateFormat.yMMMd().format(holder.dateReported!) : 'N/A'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${shareFormat.format(holder.sharesHeld)} shares',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    if (value != null)
                                      Text(
                                        currencyFormat.format(value),
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontSize: 12),
                                      )
                                    else if (pctHeld > 0)
                                      Text(
                                        '${percentFormat.format(pctHeld)} Portfolio',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
