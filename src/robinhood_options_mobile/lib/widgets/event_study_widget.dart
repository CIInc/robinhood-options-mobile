import 'package:cloud_functions/cloud_functions.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class _RollingPoint {
  const _RollingPoint(this.date, this.value);

  final DateTime date;
  final double value;
}

class EventStudyWidget extends StatefulWidget {
  const EventStudyWidget(
      {super.key, this.initialSymbol, this.initialEventDate});

  final String? initialSymbol;
  final DateTime? initialEventDate;

  @override
  State<EventStudyWidget> createState() => _EventStudyWidgetState();
}

class _EventStudyWidgetState extends State<EventStudyWidget> {
  late final TextEditingController _symbolController;
  final _benchmarkController = TextEditingController(text: 'SPY');
  final _preWindowController = TextEditingController(text: '10');
  final _postWindowController = TextEditingController(text: '10');
  final _rollingWindowController = TextEditingController(text: '30');
  late DateTime _eventDate;
  String _eventType = 'Earnings';
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _symbolController = TextEditingController(
        text: widget.initialSymbol?.toUpperCase() ?? 'AAPL');
    final today = DateTime.now();
    final requestedEventDate =
        widget.initialEventDate ?? today.subtract(const Duration(days: 7));
    _eventDate = requestedEventDate.isAfter(today) ? today : requestedEventDate;
    if (widget.initialSymbol != null && widget.initialEventDate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runStudy();
      });
    }
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _benchmarkController.dispose();
    _preWindowController.dispose();
    _postWindowController.dispose();
    _rollingWindowController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected != null) setState(() => _eventDate = selected);
  }

  Future<void> _runStudy() async {
    final symbol = _symbolController.text.trim().toUpperCase();
    final benchmark = _benchmarkController.text.trim().toUpperCase();
    final preWindow = int.tryParse(_preWindowController.text);
    final postWindow = int.tryParse(_postWindowController.text);
    final rollingWindow = int.tryParse(_rollingWindowController.text);
    if (symbol.isEmpty ||
        benchmark.isEmpty ||
        preWindow == null ||
        postWindow == null ||
        rollingWindow == null ||
        preWindow < 1 ||
        postWindow < 1 ||
        rollingWindow < 5 ||
        rollingWindow > 120) {
      setState(() => _error =
          'Enter event windows of at least 1 day and a rolling window from 5 to 120 days.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('analyzeEventStudy');
      final response = await callable.call({
        'symbol': symbol,
        'benchmark': benchmark,
        'eventType': _eventType,
        'eventDate': DateFormat('yyyy-MM-dd').format(_eventDate),
        'preWindow': preWindow,
        'postWindow': postWindow,
        'rollingWindow': rollingWindow,
      });
      if (mounted) {
        setState(
            () => _result = Map<String, dynamic>.from(response.data as Map));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _percent(dynamic value) =>
      '${(double.parse(value.toString()) * 100).toStringAsFixed(2)}%';

  void _setWindow(int preWindow, int postWindow) {
    setState(() {
      _preWindowController.text = preWindow.toString();
      _postWindowController.text = postWindow.toString();
    });
  }

  Widget _windowPreset(String label, int preWindow, int postWindow) {
    final isSelected = _preWindowController.text == preWindow.toString() &&
        _postWindowController.text == postWindow.toString();
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _setWindow(preWindow, postWindow),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Event Study Analyzer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Measure the market reaction around a known event.',
              style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Choose the date the market learned about the event. Weekend and holiday dates use the nearest trading session.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: _symbolController,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9.^=-]')),
                              ],
                              decoration: const InputDecoration(
                                  labelText: 'Stock',
                                  prefixIcon: Icon(Icons.show_chart)))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                              controller: _benchmarkController,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9.^=-]')),
                              ],
                              decoration: const InputDecoration(
                                  labelText: 'Benchmark'))),
                    ]),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _eventType,
                      decoration:
                          const InputDecoration(labelText: 'Event type'),
                      items: const [
                        'Earnings',
                        'FDA decision',
                        'Product launch',
                        'Guidance',
                        'Other'
                      ]
                          .map((type) =>
                              DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _eventType = value ?? 'Other'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event),
                        title: const Text('Event date'),
                        subtitle: Text(DateFormat.yMMMMd().format(_eventDate)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _pickDate),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: _preWindowController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Days before'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                              controller: _postWindowController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Days after'))),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _rollingWindowController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Rolling statistics window',
                        helperText: '5-120 trading days',
                        suffixText: 'days',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Window presets', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        _windowPreset('5 / 5', 5, 5),
                        _windowPreset('10 / 10', 10, 10),
                        _windowPreset('20 / 20', 20, 20),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                            onPressed: _isLoading ? null : _runStudy,
                            icon: const Icon(Icons.insights),
                            label: Text(_isLoading
                                ? 'Analyzing...'
                                : 'Run event study'))),
                  ]),
            ),
          ),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!,
                    style: TextStyle(color: theme.colorScheme.error))),
          if (_isLoading)
            const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator())),
          if (_result != null) ..._buildResults(theme),
        ],
      ),
    );
  }

  List<Widget> _buildResults(ThemeData theme) {
    final result = _result!;
    final points = (result['points'] as List).cast<Map>();
    return [
      const SizedBox(height: 20),
      Text('${result['symbol']} around ${result['eventType']}',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold)),
      Text(
          'Trading event date: ${result['tradingEventDate']}  |  ${result['sampleSize']} observations',
          style: theme.textTheme.bodySmall),
      const SizedBox(height: 12),
      _buildReactionSummary(result, theme),
      const SizedBox(height: 12),
      _buildMetricGrid(result, theme),
      const SizedBox(height: 16),
      _buildEventPath(points, result, theme),
      const SizedBox(height: 16),
      _buildRollingDashboard(result, theme),
    ];
  }

  Widget _buildRollingDashboard(Map<String, dynamic> result, ThemeData theme) {
    final stats = (result['rollingStats'] as List? ?? [])
        .map((point) => Map<String, dynamic>.from(point as Map))
        .toList();
    if (stats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Rolling statistics need at least ${result['rollingWindow']} aligned trading days.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    final latest = stats.last;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Rolling statistics',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('${result['rollingWindow']}-day window',
                    style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                'Annualized volatility, market sensitivity, and co-movement with ${result['benchmark']}.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _metric(
                        'Volatility', _percent(latest['volatility']), theme)),
                const SizedBox(width: 8),
                Expanded(
                    child: _metric('Beta', _number(latest['beta']), theme)),
                const SizedBox(width: 8),
                Expanded(
                    child: _metric(
                        'Correlation', _number(latest['correlation']), theme)),
              ],
            ),
            const SizedBox(height: 14),
            _rollingChart(
                'Volatility', stats, 'volatility', Colors.orange, theme),
            const SizedBox(height: 14),
            _rollingChart('Beta', stats, 'beta', Colors.blue, theme),
            const SizedBox(height: 14),
            _rollingChart(
                'Correlation', stats, 'correlation', Colors.green, theme),
            const SizedBox(height: 4),
            Text(
                'Latest observation: ${latest['date']}  |  ${latest['sampleSize']} daily returns',
                style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _rollingChart(String title, List<Map<String, dynamic>> stats,
      String key, Color color, ThemeData theme) {
    final points = stats
        .map((point) => _RollingPoint(
              DateTime.parse(point['date'].toString()),
              (point[key] as num).toDouble(),
            ))
        .toList();
    final series = charts.Series<_RollingPoint, DateTime>(
      id: title,
      data: points,
      domainFn: (point, _) => point.date,
      measureFn: (point, _) => point.value,
      colorFn: (_, __) => charts.ColorUtil.fromDartColor(color),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelLarge),
        SizedBox(
          height: 150,
          child: charts.TimeSeriesChart(
            [series],
            animate: false,
            defaultRenderer: charts.LineRendererConfig(
              includeArea: true,
              areaOpacity: 35,
              strokeWidthPx: 2,
            ),
            domainAxis: const charts.DateTimeAxisSpec(
              renderSpec: charts.NoneRenderSpec(),
            ),
            behaviors: const [],
          ),
        ),
      ],
    );
  }

  String _number(double value) => value.toStringAsFixed(2);

  Widget _buildReactionSummary(Map<String, dynamic> result, ThemeData theme) {
    final abnormalReturn =
        (result['eventDayAbnormalReturn'] as num?)?.toDouble() ?? 0;
    final isPositive = abnormalReturn >= 0;
    final color = isPositive ? Colors.green : Colors.red;
    final label =
        isPositive ? 'Positive market reaction' : 'Negative market reaction';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(isPositive ? Icons.trending_up : Icons.trending_down,
              color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.bold)),
          ),
          Text(_percent(abnormalReturn),
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEventPath(
      List<Map> points, Map<String, dynamic> result, ThemeData theme) {
    if (points.isEmpty) return const SizedBox.shrink();
    final maxMagnitude = points.fold<double>(0, (current, point) {
      final value = (point['abnormalReturn'] as num).toDouble().abs();
      return value > current ? value : current;
    });
    final scale = maxMagnitude == 0 ? 1.0 : maxMagnitude;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event window',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Relative performance versus the selected benchmark.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            ...points.map((point) {
              final value = (point['abnormalReturn'] as num).toDouble();
              final color = value >= 0 ? Colors.green : Colors.red;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                        width: 42,
                        child: Text(point['offset'] == 0
                            ? 'Event'
                            : 'T${point['offset']}')),
                    Expanded(
                      child: Align(
                        alignment: value >= 0
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: FractionallySizedBox(
                          widthFactor: (value.abs() / scale).clamp(0.02, 1.0),
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 58, child: Text(_percent(value))),
                  ],
                ),
              );
            }),
            const Divider(height: 20),
            Text('Trading-day details',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Returns are normalized to the first day of the window.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            ...points.map((point) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: SizedBox(
                      width: 42,
                      child: Text(
                          point['offset'] == 0
                              ? 'Event'
                              : 'T${point['offset']}',
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                  title: Text(point['date'].toString()),
                  trailing: Text(_percent(point['abnormalReturn']),
                      style: TextStyle(
                          color: (point['abnormalReturn'] as num) >= 0
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      'Stock ${_percent(point['assetReturn'])}  |  ${result['benchmark']} ${_percent(point['benchmarkReturn'])}'),
                )),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, ThemeData theme) => Container(
        width: double.infinity,
        height: 78,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(value,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold))
          ],
        ),
      );

  Widget _buildMetricGrid(Map<String, dynamic> result, ThemeData theme) {
    final metrics = [
      _metric(
          'Event-day return', _percent(result['eventDayAssetReturn']), theme),
      _metric(
          'Market return', _percent(result['eventDayBenchmarkReturn']), theme),
      _metric('Event-day abnormal', _percent(result['eventDayAbnormalReturn']),
          theme),
      _metric(
          'Window return', _percent(result['cumulativeAssetReturn']), theme),
      _metric('Window abnormal', _percent(result['cumulativeAbnormalReturn']),
          theme),
    ];
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      mainAxisExtent: 78,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: metrics,
    );
  }
}
