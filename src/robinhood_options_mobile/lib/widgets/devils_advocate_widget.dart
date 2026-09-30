import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/devils_advocate_model.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';

class DevilsAdvocateWidget extends StatefulWidget {
  final String symbol;
  final GenerativeService? generativeService;
  final String initialDirection;
  final String? initialThesis;
  final double? currentPrice;
  final DevilsAdvocateAnalysis? preloadedAnalysis;
  final bool isModal;

  const DevilsAdvocateWidget({
    super.key,
    required this.symbol,
    this.generativeService,
    this.initialDirection = 'Bullish',
    this.initialThesis,
    this.currentPrice,
    this.preloadedAnalysis,
    this.isModal = false,
  });

  @override
  State<DevilsAdvocateWidget> createState() => _DevilsAdvocateWidgetState();
}

class _DevilsAdvocateWidgetState extends State<DevilsAdvocateWidget> {
  late String _direction;
  String? _customThesis;
  Future<DevilsAdvocateAnalysis?>? _future;
  int _selectedTab =
      0; // 0: Counter-Arguments, 1: Skew Traps, 2: Event Hazards, 3: Stress Scenarios
  final TextEditingController _thesisController = TextEditingController();
  bool _showCustomThesisInput = false;

  final DateFormat _dateFormat = DateFormat('MMM d, yyyy h:mm a');

  @override
  void initState() {
    super.initState();
    _direction = widget.initialDirection;
    _customThesis = widget.initialThesis;
    if (_customThesis != null) {
      _thesisController.text = _customThesis!;
    }
    if (widget.preloadedAnalysis != null) {
      _future = Future.value(widget.preloadedAnalysis);
    } else {
      _loadData();
    }
  }

  @override
  void didUpdateWidget(covariant DevilsAdvocateWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.preloadedAnalysis != widget.preloadedAnalysis) {
      if (widget.preloadedAnalysis != null) {
        _future = Future.value(widget.preloadedAnalysis);
      } else {
        _loadData();
      }
    }
  }

  @override
  void dispose() {
    _thesisController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _future = widget.generativeService?.analyzeDevilsAdvocate(
        widget.symbol,
        direction: _direction,
        thesis: _customThesis,
        currentPrice: widget.currentPrice,
      );
    });
  }

  Color _getResilienceColor(double score, ThemeData theme) {
    if (score >= 75) {
      return Colors.green.shade600;
    } else if (score >= 50) {
      return Colors.orange.shade700;
    } else {
      return theme.colorScheme.error;
    }
  }

  Color _getSeverityColor(String severity, ThemeData theme) {
    switch (severity.toLowerCase()) {
      case 'high':
        return theme.colorScheme.error;
      case 'medium':
        return Colors.orange.shade700;
      case 'low':
      default:
        return Colors.blue.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<DevilsAdvocateAnalysis?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: const SizedBox(
                height: 140,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'Stress-testing trade thesis...',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: ListTile(
                leading:
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                title: const Text('Devil\'s Advocate analysis unavailable'),
                subtitle: Text('${snapshot.error}'),
                trailing: IconButton(
                  tooltip: 'Retry analysis',
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                ),
              ),
            ),
          );
        }

        final analysis = snapshot.data;
        if (analysis == null) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: ListTile(
                leading: const Icon(Icons.psychology_alt_outlined),
                title: Text('No stress test data for ${widget.symbol}'),
                subtitle:
                    const Text('Tap refresh to run an adversarial critique'),
                trailing: IconButton(
                  tooltip: 'Run stress test',
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                ),
              ),
            ),
          );
        }

        final resilienceColor =
            _getResilienceColor(analysis.resilienceScore, theme);

        return Padding(
          padding: widget.isModal
              ? const EdgeInsets.all(16.0)
              : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Card(
            elevation: 1.5,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, analysis, resilienceColor),
                _buildDirectionSelector(theme),
                if (_showCustomThesisInput) _buildCustomThesisInput(theme),
                _buildKillerQuestionBanner(theme, analysis),
                _buildSummary(theme, analysis),
                _buildSectionSelector(theme, analysis),
                _buildSelectedSectionContent(theme, analysis),
                _buildFooter(theme, analysis),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    DevilsAdvocateAnalysis analysis,
    Color resilienceColor,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: resilienceColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.psychology_alt,
              color: resilienceColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      'AI Devil\'s Advocate',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Adversarial',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Thesis Stress Test · ${widget.symbol}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: resilienceColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: resilienceColor.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${analysis.resilienceScore.toStringAsFixed(0)} / 100',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: resilienceColor,
                  ),
                ),
                Text(
                  '${analysis.verdict} Resilience',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: resilienceColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Proposed Thesis Direction:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: Icon(
                  _showCustomThesisInput
                      ? Icons.close
                      : Icons.edit_note_outlined,
                  size: 16,
                ),
                label: Text(
                  _showCustomThesisInput ? 'Hide Thesis' : 'Custom Thesis',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () {
                  setState(() {
                    _showCustomThesisInput = !_showCustomThesisInput;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildDirectionChip(
                  'Bullish', Icons.trending_up, Colors.green, theme),
              _buildDirectionChip(
                  'Bearish', Icons.trending_down, Colors.red, theme),
              _buildDirectionChip(
                  'Neutral', Icons.swap_horiz, Colors.blue, theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionChip(
    String label,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    final isSelected = _direction.toLowerCase() == label.toLowerCase();
    return FilterChip(
      selected: isSelected,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isSelected ? theme.colorScheme.onSecondaryContainer : color,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        if (selected && _direction.toLowerCase() != label.toLowerCase()) {
          setState(() {
            _direction = label;
          });
          _loadData();
        }
      },
    );
  }

  Widget _buildCustomThesisInput(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _thesisController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Enter your trade rationale to stress test...',
              labelText: 'Trader\'s Thesis Note',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.psychology, size: 16),
              label: const Text('Critique Custom Thesis',
                  style: TextStyle(fontSize: 12)),
              onPressed: () {
                setState(() {
                  _customThesis = _thesisController.text.trim();
                });
                _loadData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKillerQuestionBanner(
    ThemeData theme,
    DevilsAdvocateAnalysis analysis,
  ) {
    if (analysis.killerQuestion.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: theme.colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KILLER QUESTION (STRESS POINT)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    analysis.killerQuestion,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(
    ThemeData theme,
    DevilsAdvocateAnalysis analysis,
  ) {
    if (analysis.summary.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        analysis.summary,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildSectionSelector(
    ThemeData theme,
    DevilsAdvocateAnalysis analysis,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabChip(
                0,
                'Counter-Arguments (${analysis.counterArguments.length})',
                Icons.gavel,
                theme),
            const SizedBox(width: 6),
            _buildTabChip(1, 'Skew Traps (${analysis.skewTraps.length})',
                Icons.show_chart, theme),
            const SizedBox(width: 6),
            _buildTabChip(2, 'Event Hazards (${analysis.eventHazards.length})',
                Icons.event_busy, theme),
            const SizedBox(width: 6),
            _buildTabChip(
                3,
                'Stress Scenarios (${analysis.stressScenarios.length})',
                Icons.analytics_outlined,
                theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(
      int index, String title, IconData icon, ThemeData theme) {
    final isSelected = _selectedTab == index;
    return ChoiceChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(title, style: const TextStyle(fontSize: 11)),
        ],
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedTab = index;
          });
        }
      },
    );
  }

  Widget _buildSelectedSectionContent(
    ThemeData theme,
    DevilsAdvocateAnalysis analysis,
  ) {
    switch (_selectedTab) {
      case 0:
        return _buildCounterArgumentsList(theme, analysis);
      case 1:
        return _buildSkewTrapsList(theme, analysis);
      case 2:
        return _buildEventHazardsList(theme, analysis);
      case 3:
      default:
        return _buildStressScenariosList(theme, analysis);
    }
  }

  Widget _buildCounterArgumentsList(
    ThemeData theme,
    DevilsAdvocateAnalysis analysis,
  ) {
    if (analysis.counterArguments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No counter-arguments identified.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: analysis.counterArguments.map((arg) {
          final color = _getSeverityColor(arg.severity, theme);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        arg.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${arg.severity} Risk',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  arg.argument,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSkewTrapsList(
    ThemeData theme,
    DevilsAdvocateAnalysis analysis,
  ) {
    if (analysis.skewTraps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No volatility skew traps detected.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: analysis.skewTraps.map((trap) {
          final color = _getSeverityColor(trap.severity, theme);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt, size: 16, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        trap.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        trap.severity,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  trap.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEventHazardsList(
    ThemeData theme,
    DevilsAdvocateAnalysis analysis,
  ) {
    if (analysis.eventHazards.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No imminent event hazards noted.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: analysis.eventHazards.map((hazard) {
          final color = _getSeverityColor(hazard.hazardLevel, theme);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_note, size: 16, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hazard.event,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        hazard.timing,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  hazard.risk,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStressScenariosList(
    ThemeData theme,
    DevilsAdvocateAnalysis analysis,
  ) {
    if (analysis.stressScenarios.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No stress scenarios modeled.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: analysis.stressScenarios.map((scenario) {
          final isNegative = scenario.projectedImpact.startsWith('-');
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        scenario.scenario,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isNegative
                            ? Colors.red.withValues(alpha: 0.15)
                            : Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        scenario.projectedImpact,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isNegative
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  scenario.assessment,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, DevilsAdvocateAnalysis analysis) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              analysis.lastUpdated != null
                  ? 'Updated ${_dateFormat.format(analysis.lastUpdated!.toLocal())}'
                  : 'Real-time AI stress test',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Re-run stress test',
            visualDensity: VisualDensity.compact,
            onPressed: _loadData,
          ),
        ],
      ),
    );
  }
}
