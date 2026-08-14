import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
    _eventDate = widget.initialEventDate ??
        DateTime.now().subtract(const Duration(days: 7));
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
    if (symbol.isEmpty ||
        benchmark.isEmpty ||
        preWindow == null ||
        postWindow == null ||
        preWindow < 1 ||
        postWindow < 1) {
      setState(() => _error = 'Enter symbols and windows of at least 1 day.');
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
      });
      if (mounted)
        setState(
            () => _result = Map<String, dynamic>.from(response.data as Map));
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
                      value: _eventType,
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
    ];
  }

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
