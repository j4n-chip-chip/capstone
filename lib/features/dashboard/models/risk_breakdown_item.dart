class RiskBreakdownItem {
  const RiskBreakdownItem({
    required this.label,
    required this.score,
    required this.maxScore,
  });

  final String label;
  final int score;
  final int maxScore;
}