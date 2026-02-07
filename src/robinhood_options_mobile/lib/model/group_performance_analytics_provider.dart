import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/group_performance_analytics.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

/// Provider for managing group performance analytics state
class GroupPerformanceAnalyticsProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  GroupPerformanceAnalyticsProvider(this._firestoreService);

  // State variables
  GroupPerformanceMetrics? _groupMetrics;
  List<MemberPerformanceMetrics> _memberMetrics = [];
  TimePeriodFilter _selectedPeriod = TimePeriodFilter.oneMonth;
  String? _selectedGroupId;
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  // Getters
  GroupPerformanceMetrics? get groupMetrics => _groupMetrics;
  List<MemberPerformanceMetrics> get memberMetrics => _memberMetrics;
  List<MemberPerformanceMetrics> get sortedMemberMetrics {
    final sorted = List<MemberPerformanceMetrics>.from(_memberMetrics);
    sorted.sort((a, b) => b.totalReturnPercent.compareTo(a.totalReturnPercent));
    return sorted;
  }

  TimePeriodFilter get selectedPeriod => _selectedPeriod;
  String? get selectedGroupId => _selectedGroupId;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Safely notify listeners only if provider is not disposed
  void _notifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Load group performance analytics for a specific group
  Future<void> loadGroupPerformanceAnalytics(
    String groupId,
    TimePeriodFilter period,
  ) async {
    _selectedGroupId = groupId;
    _selectedPeriod = period;
    _isLoading = true;
    _error = null;
    _notifyListeners();

    try {
      final startDate = period.getStartDate();
      final endDate = DateTime.now();

      // Fetch group metrics
      final groupMetrics = await _firestoreService.getGroupPerformanceMetrics(
        groupId,
        startDate,
        endDate,
      );

      // Fetch member metrics
      final memberMetrics =
          await _firestoreService.getMembersPerformanceMetrics(
        groupId,
        startDate,
        endDate,
      );

      _groupMetrics = groupMetrics;
      _memberMetrics = memberMetrics;
      _isLoading = false;
      _notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _notifyListeners();
    }
  }

  /// Update selected time period and reload data
  Future<void> setTimePeriod(TimePeriodFilter period) async {
    if (_selectedGroupId != null) {
      await loadGroupPerformanceAnalytics(_selectedGroupId!, period);
    }
  }

  /// Export performance data as CSV
  String exportAsCSV() {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
        'Member Name,Total Return %,Total Return \$,Win Rate %,Total Trades,Sharpe Ratio,Max Drawdown %');

    // Member data
    for (final member in sortedMemberMetrics) {
      buffer.writeln(
          '${member.memberName},${member.totalReturnPercent.toStringAsFixed(2)},${member.totalReturnDollars.toStringAsFixed(2)},${member.winRate.toStringAsFixed(2)},${member.totalTrades},${member.sharpeRatio.toStringAsFixed(2)},${member.maxDrawdownPercent.toStringAsFixed(2)}');
    }

    return buffer.toString();
  }

  /// Get top performers
  List<MemberPerformanceMetrics> getTopPerformers({int limit = 5}) {
    return sortedMemberMetrics.take(limit).toList();
  }

  /// Get bottom performers
  List<MemberPerformanceMetrics> getBottomPerformers({int limit = 5}) {
    return sortedMemberMetrics.reversed.take(limit).toList();
  }

  /// Get high performers (return > threshold)
  List<MemberPerformanceMetrics> getHighPerformers(double threshold) {
    return sortedMemberMetrics
        .where((m) => m.totalReturnPercent > threshold)
        .toList();
  }

  /// Clear data
  void clear() {
    _groupMetrics = null;
    _memberMetrics = [];
    _selectedGroupId = null;
    _isLoading = false;
    _error = null;
    _notifyListeners();
  }
}
