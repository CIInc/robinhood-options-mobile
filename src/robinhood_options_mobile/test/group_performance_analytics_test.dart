import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/group_performance_analytics.dart';

void main() {
  test('decodes integer-valued numeric analytics fields', () {
    final member = MemberPerformanceMetrics.fromJson({
      'memberId': 'member-1',
      'memberName': 'Member One',
      'totalReturnPercent': 0,
      'totalReturnDollars': 0,
      'winRate': 0,
      'totalTrades': 0,
      'winningTrades': 0,
      'losingTrades': 0,
      'averageWin': 0,
      'averageLoss': 0,
      'profitFactor': 0,
      'sharpeRatio': 0,
      'maxDrawdownPercent': 0,
      'avgHoldTimeHours': 0,
    });
    final group = GroupPerformanceMetrics.fromJson({
      'groupId': 'group-1',
      'groupTotalReturnPercent': 0,
      'groupTotalReturnDollars': 0,
      'groupAverageReturnPercent': 0,
      'groupAverageReturnDollars': 0,
      'totalMembersTraded': 0,
      'totalGroupTrades': 0,
      'groupWinRate': 0,
      'groupAverageSharpeRatio': 0,
      'topPerformerReturnPercent': 0,
      'membersWithPositiveReturn': 0,
      'membersWithNegativeReturn': 0,
    });

    expect(member.totalReturnPercent, 0.0);
    expect(member.avgHoldTimeHours, 0.0);
    expect(group.groupTotalReturnPercent, 0.0);
    expect(group.groupAverageSharpeRatio, 0.0);
  });
}
