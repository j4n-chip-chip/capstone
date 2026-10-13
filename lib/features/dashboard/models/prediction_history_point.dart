class PredictionHistoryPoint {
  const PredictionHistoryPoint({
    required this.index,
    required this.riskScore,
    required this.timestamp,
  });

  final double index;
  final double riskScore;
  final int timestamp;
}