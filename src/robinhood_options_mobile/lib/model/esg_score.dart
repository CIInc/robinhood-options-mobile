class ESGScore {
  final String symbol;
  final double totalScore;
  final double environmentalScore;
  final double socialScore;
  final double governanceScore;
  final String rating; // e.g., "AAA", "AA", "A", "BBB", "BB", "B", "CCC"
  final String? description;

  ESGScore({
    required this.symbol,
    required this.totalScore,
    required this.environmentalScore,
    required this.socialScore,
    required this.governanceScore,
    required this.rating,
    this.description,
  });

  factory ESGScore.fromJson(Map<String, dynamic> json) {
    return ESGScore(
      symbol: json['symbol'],
      totalScore: (json['totalScore'] as num).toDouble(),
      environmentalScore: (json['environmentalScore'] as num).toDouble(),
      socialScore: (json['socialScore'] as num).toDouble(),
      governanceScore: (json['governanceScore'] as num).toDouble(),
      rating: json['rating'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'totalScore': totalScore,
      'environmentalScore': environmentalScore,
      'socialScore': socialScore,
      'governanceScore': governanceScore,
      'rating': rating,
      'description': description,
    };
  }
}
