class PredictionEngineModel {
  final String riskLevel;
  final List<String> reasons;
  final String recommendation;
  final String smartInsight;
  final DateTime lastEvaluated;

  final int riskScore;
  final String riskExplanation;
  final String recommendedAction;

  final bool hasScoreBreakdown;

  final int temperatureScore;
  final int humidityScore;
  final int wetnessStatusScore;
  final int wetnessDurationScore;
  final int persistenceScore;

  PredictionEngineModel({
    required this.riskLevel,
    required this.reasons,
    required this.recommendation,
    required this.smartInsight,
    required this.lastEvaluated,
    required this.riskScore,
    required this.riskExplanation,
    required this.recommendedAction,

    required this.hasScoreBreakdown,

    required this.temperatureScore,
    required this.humidityScore,
    required this.wetnessStatusScore,
    required this.wetnessDurationScore,
    required this.persistenceScore,
  });

  factory PredictionEngineModel.fromMap(Map<String, dynamic> map) {
    return PredictionEngineModel(
      riskLevel: map['riskLevel'] ?? 'LOW',

      reasons: List<String>.from(map['reasons'] ?? []),

      recommendation: map['recommendation'] ?? map['recommendedAction'] ?? '',

      smartInsight: map['smartInsight'] ?? '',

      lastEvaluated: map['lastEvaluated'] is DateTime
          ? map['lastEvaluated'] as DateTime
          : DateTime.fromMillisecondsSinceEpoch(0),

      riskScore: (map['riskScore'] as num?)?.round() ?? 0,

      riskExplanation: map['riskExplanation'] ?? '',

      recommendedAction: map['recommendedAction'] ?? '',

      temperatureScore: (map['temperatureScore'] as num?)?.round() ?? 0,

      humidityScore: (map['humidityScore'] as num?)?.round() ?? 0,

      wetnessStatusScore: (map['wetnessStatusScore'] as num?)?.round() ?? 0,

      wetnessDurationScore: (map['wetnessDurationScore'] as num?)?.round() ?? 0,

      persistenceScore: (map['persistenceScore'] as num?)?.round() ?? 0,

      hasScoreBreakdown:
          map.containsKey('temperatureScore') &&
          map.containsKey('humidityScore') &&
          map.containsKey('wetnessStatusScore') &&
          map.containsKey('wetnessDurationScore') &&
          map.containsKey('persistenceScore'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'riskLevel': riskLevel,
      'reasons': reasons,

      'recommendation': recommendation,

      'smartInsight': smartInsight,

      'lastEvaluated': lastEvaluated,

      'riskScore': riskScore,

      'riskExplanation': riskExplanation,

      'recommendedAction': recommendedAction,

      'temperatureScore': temperatureScore,

      'humidityScore': humidityScore,

      'wetnessStatusScore': wetnessStatusScore,

      'wetnessDurationScore': wetnessDurationScore,

      'persistenceScore': persistenceScore,

      'hasScoreBreakdown': hasScoreBreakdown,
    };
  }
}
