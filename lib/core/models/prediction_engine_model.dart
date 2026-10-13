import '../utils/rtdb_value_parser.dart';

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

  bool get hasValidRisk =>
      const {'LOW', 'MODERATE', 'HIGH', 'VERY HIGH'}.contains(riskLevel) &&
      riskScore >= 0 &&
      riskScore <= 18;

  factory PredictionEngineModel.fromMap(Map<String, dynamic> map) {
    final level = readRtdbUpperString(map, 'riskLevel');
    final score = readRtdbInt(map, 'riskScore');
    final validRisk =
        const {'LOW', 'MODERATE', 'HIGH', 'VERY HIGH'}.contains(level) &&
        score != null &&
        score >= 0 &&
        score <= 18;
    int? component(String key, int maximum) {
      final value = readRtdbInt(map, key);
      return value != null && value >= 0 && value <= maximum ? value : null;
    }

    final temperature = component('temperatureScore', 4);
    final humidity = component('humidityScore', 4);
    final wetness = component('wetnessStatusScore', 2);
    final duration = component('wetnessDurationScore', 5);
    final persistence = component('persistenceScore', 3);
    final reasons = map['reasons'];

    return PredictionEngineModel(
      riskLevel: validRisk ? level! : 'UNKNOWN',
      riskScore: validRisk ? score : 0,
      reasons: reasons is List ? reasons.whereType<String>().toList() : [],
      recommendation: readRtdbString(
        map,
        'recommendation',
        fallback: readRtdbString(map, 'recommendedAction'),
      ),
      smartInsight: readRtdbString(map, 'smartInsight'),
      lastEvaluated: readRtdbDateTime(map['lastEvaluated']),
      riskExplanation: readRtdbString(map, 'riskExplanation'),
      recommendedAction: readRtdbString(map, 'recommendedAction'),
      temperatureScore: temperature ?? 0,
      humidityScore: humidity ?? 0,
      wetnessStatusScore: wetness ?? 0,
      wetnessDurationScore: duration ?? 0,
      persistenceScore: persistence ?? 0,
      hasScoreBreakdown:
          validRisk &&
          temperature != null &&
          humidity != null &&
          wetness != null &&
          duration != null &&
          persistence != null,
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
