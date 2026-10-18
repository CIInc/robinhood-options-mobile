import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';

/// Calendar of month-by-month returns, promoted to sit directly under the
/// performance chart.
class MonthlyReturnsCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const MonthlyReturnsCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) => _monthlyReturns(context, data);

  Widget _monthlyReturns(BuildContext context, Map<String, dynamic> data) {
    if (!data.containsKey('monthlyReturns')) return const SizedBox.shrink();

    Map<int, Map<int, double>> monthlyReturns = data['monthlyReturns'];
    if (monthlyReturns.isEmpty) return const SizedBox.shrink();

    List<int> years = monthlyReturns.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return AnalyticsStyleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text('Monthly Returns',
                  style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          // Build Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
                defaultColumnWidth: const FixedColumnWidth(55),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder(
                    horizontalInside: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.3),
                        width: 1)),
                children: [
                  // Header Row
                  TableRow(children: [
                    const SizedBox(
                        height: 30,
                        child: Center(
                            child: Text('Year',
                                style:
                                    TextStyle(fontWeight: FontWeight.bold)))),
                    ...List.generate(
                        12,
                        (index) => Center(
                            child: Text(
                                DateFormat('MMM')
                                    .format(DateTime(2000, index + 1)),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)))),
                    const Center(
                        child: Text('YTD',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ]),
                  // Data Rows
                  ...years.map((year) {
                    Map<int, double> months = monthlyReturns[year] ?? {};
                    double ytd = 1.0;
                    int validMonths = 0;
                    for (int m = 1; m <= 12; m++) {
                      if (months.containsKey(m)) {
                        ytd *= (1 + months[m]!);
                        validMonths++;
                      }
                    }
                    ytd -= 1.0;

                    if (validMonths == 0) return const TableRow(children: []);

                    return TableRow(children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('$year',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                      ...List.generate(12, (index) {
                        int month = index + 1;
                        double? ret = months[month];
                        Color? bgColor;
                        Color? textColor;

                        if (ret != null) {
                          if (ret >= 0) {
                            bgColor = Colors.green.withValues(
                                alpha: 0.1 + (ret * 5).clamp(0.0, 0.4));
                            textColor = Colors.green;
                          } else {
                            bgColor = Colors.red.withValues(
                                alpha: 0.1 + (ret.abs() * 5).clamp(0.0, 0.4));
                            textColor = Colors.red;
                          }
                        }

                        return Container(
                          height: 30, // Fixed height for cells
                          margin:
                              const EdgeInsets.all(1), // Margin for grid effect
                          decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(4)),
                          child: Center(
                              child: Text(
                            ret == null
                                ? '-'
                                : '${(ret * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontSize: 10,
                                color: textColor,
                                fontWeight: FontWeight.bold),
                          )),
                        );
                      }),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                            child: Text('${(ytd * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        ytd >= 0 ? Colors.green : Colors.red))),
                      )
                    ]);
                  })
                ]),
          )
        ],
      ),
    );
  }
}
