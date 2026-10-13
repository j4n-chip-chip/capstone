class RiskTimelineItem {
  const RiskTimelineItem({
    required this.riskLevel,
    required this.riskScore,
    required this.timestamp,
  });

  final String riskLevel;
  final int riskScore;
  final int timestamp;
}