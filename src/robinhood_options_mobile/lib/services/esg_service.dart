import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/esg_score.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';

class ESGService {
  // Cache to store fetched scores
  final Map<String, ESGScore> _cache = {};
  final YahooService _yahooService = YahooService();

  Future<ESGScore?> getESGScore(String symbol) async {
    if (_cache.containsKey(symbol)) {
      return _cache[symbol]!;
    }

    try {
      var response = await _yahooService.getESGScores(symbol);
      if (response != null &&
          response['quoteSummary'] != null &&
          response['quoteSummary']['result'] != null &&
          (response['quoteSummary']['result'] as List).isNotEmpty) {
        var result = response['quoteSummary']['result'][0];
        if (result['esgScores'] != null) {
          var esg = result['esgScores'];

          // Yahoo provides Risk Scores (Lower is Better).
          // We convert to a 0-100 "Goodness" score for the UI (Higher is Better).
          // Risk 0 -> Score 100
          // Risk 50 -> Score 50
          // Risk 100 -> Score 0

          double totalRisk = (esg['totalEsg']?['raw'] as num?)?.toDouble() ?? 0;
          double envRisk =
              (esg['environmentScore']?['raw'] as num?)?.toDouble() ?? 0;
          double socRisk =
              (esg['socialScore']?['raw'] as num?)?.toDouble() ?? 0;
          double govRisk =
              (esg['governanceScore']?['raw'] as num?)?.toDouble() ?? 0;

          // Normalize to 0-100 scale where 100 is best
          // Assuming max risk is around 50-60 usually, but can go higher.
          // We'll use 100 - Risk.

          double totalScore = (100 - totalRisk).clamp(0, 100);
          double envScore =
              (100 - envRisk * 3).clamp(0, 100); // Component risks are smaller
          double socScore = (100 - socRisk * 3).clamp(0, 100);
          double govScore = (100 - govRisk * 3).clamp(0, 100);

          // Or better, just use the percentile if available?
          // Yahoo provides 'percentile' sometimes.
          // Let's stick to 100 - Risk for Total.
          // For components, they sum up to Total.
          // So if Total Risk = 20, Env=5, Soc=10, Gov=5.
          // If we want component scores to look like 0-100:
          // We can't easily convert component risk to component score without a baseline.
          // Let's just use 100 - (Risk * 2) for components to make them look comparable?
          // No, let's just use 100 - Risk for everything, but components are small numbers.
          // Maybe we should just display the Risk Score in the UI?
          // But the user asked for "Improve".
          // Let's try to map it to a rating.

          String rating = "N/A";
          if (totalRisk < 10) {
            rating = "AAA"; // Negligible Risk
          } else if (totalRisk < 20)
            rating = "AA"; // Low Risk
          else if (totalRisk < 30)
            rating = "A"; // Medium Risk
          else if (totalRisk < 40)
            rating = "BBB"; // High Risk
          else
            rating = "CCC"; // Severe Risk

          // For the UI bars (0-100), we need a "Score".
          // Let's use a relative score.
          // If Total Risk is 20, Score is 80.
          // If Env Risk is 5, and it contributes to Total, maybe we can just show the contribution?
          // Or we can scale them.
          // Let's just use 100 - Risk for Total.
          // For components, let's use 100 - (Risk * 3) as a heuristic, or just leave them as is and let the UI handle it?
          // The UI expects 0-100.
          // Let's use: Score = 100 - Risk.
          // For components, since they are smaller, 100 - Risk will be very high (e.g. 95).
          // This might be misleading if 5 is actually a "Medium" risk for a component.
          // Let's just use 100 - Risk for Total, and for components, maybe scale them up?
          // Actually, let's just use 100 - Risk for all. It's consistent.

          String description =
              "ESG Risk Rating: ${totalRisk.toStringAsFixed(1)}";
          if (esg['peerGroup'] != null) {
            description += "\nPeer Group: ${esg['peerGroup']}";
          }
          if (esg['highestControversy'] != null) {
            description +=
                "\nHighest Controversy: ${esg['highestControversy']}";
          }
          if (esg['relatedControversy'] != null &&
              (esg['relatedControversy'] as List).isNotEmpty) {
            description +=
                "\nRelated Controversies: ${(esg['relatedControversy'] as List).join(', ')}";
          }

          var scoreObj = ESGScore(
            symbol: symbol,
            totalScore: totalScore,
            environmentalScore: envScore,
            socialScore: socScore,
            governanceScore: govScore,
            rating: rating,
            description: description,
          );

          _cache[symbol] = scoreObj;
          return scoreObj;
        }
      }
    } catch (e) {
      debugPrint("Error fetching ESG for $symbol: $e");
    }

    return null;
  }

  Future<List<ESGScore?>> getESGScores(List<String> symbols) async {
    // Fetch in parallel
    var futures = symbols.map((symbol) => getESGScore(symbol));
    return await Future.wait(futures);
  }

}
