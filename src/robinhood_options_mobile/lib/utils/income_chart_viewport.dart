bool shouldUseAutomaticIncomeChartViewport({
  required String dateFilter,
  required Iterable<DateTime> incomeDates,
}) {
  if (dateFilter == 'All') return true;

  final dates = incomeDates.toList();
  if (dates.length < 2) return false;

  dates.sort();
  return dates.last.difference(dates.first).inDays < 365;
}
