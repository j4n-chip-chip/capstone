import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../models/risk_breakdown_item.dart';

class RiskPredictionCard extends StatelessWidget {
  const RiskPredictionCard({
    super.key,
    required this.riskLevel,
    required this.riskColor,
    required this.riskScore,
    required this.riskExplanation,
    required this.recommendedAction,
    required this.reasons,
    required this.recommendation,
    required this.smartInsight,
    required this.isOnline,
    required this.temperatureScore,
    required this.humidityScore,
    required this.wetnessStatusScore,
    required this.wetnessDurationScore,
    required this.persistenceScore,
    required this.hasScoreBreakdown,
  });

  final String riskLevel;
  final Color riskColor;
  final List<String> reasons;
  final String recommendation;
  final String smartInsight;
  final int riskScore;

  final int temperatureScore;
  final int humidityScore;
  final int wetnessStatusScore;
  final int wetnessDurationScore;
  final int persistenceScore;

  final bool hasScoreBreakdown;

  final String riskExplanation;
  final String recommendedAction;
  final bool isOnline;

  List<RiskBreakdownItem> buildRiskBreakdown() {
    return [
      RiskBreakdownItem(
        label: 'Temperature',
        score: temperatureScore,
        maxScore: 4,
      ),
      RiskBreakdownItem(label: 'Humidity', score: humidityScore, maxScore: 4),
      RiskBreakdownItem(
        label: 'Leaf Wetness',
        score: wetnessStatusScore,
        maxScore: 2,
      ),
      RiskBreakdownItem(
        label: 'Wetness Duration',
        score: wetnessDurationScore,
        maxScore: 5,
      ),
      RiskBreakdownItem(
        label: 'Risk Persistence',
        score: persistenceScore,
        maxScore: 3,
      ),
    ];
  }

  String get riskMessage {
    switch (riskLevel) {
      case 'LOW':
        return 'Current environmental conditions are not favorable for Black Sigatoka development.';

      case 'MODERATE':
        return 'Some environmental conditions may support Black Sigatoka development. Continue monitoring and inspect leaves.';

      case 'HIGH':
        return 'Temperature, humidity, and leaf wetness are favorable for Black Sigatoka development. Preventive action is recommended.';

      case 'VERY HIGH':
        return 'Conditions are strongly favorable and persistent. Preventive spraying may be recommended if Auto Mode and safety checks are enabled.';

      default:
        return 'Risk status is currently unavailable.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final breakdown = buildRiskBreakdown();
    final riskAvailable =
        isOnline &&
        const {'LOW', 'MODERATE', 'HIGH', 'VERY HIGH'}.contains(riskLevel);
    final displayedRiskLevel = riskAvailable ? riskLevel : 'UNAVAILABLE';

    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: riskColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.riskPrediction,
              style: TextStyle(color: AppColors.textLight, fontSize: 14),
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: riskColor.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        !riskAvailable
                            ? Icons.help_outline
                            : riskLevel == 'LOW'
                            ? Icons.check_circle
                            : riskLevel == 'MODERATE'
                            ? Icons.info
                            : riskLevel == 'HIGH'
                            ? Icons.warning_amber_rounded
                            : Icons.dangerous,
                        color: riskColor,
                        size: 36,
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          displayedRiskLevel,
                          style: TextStyle(
                            color: riskColor,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(
                    isOnline ? riskMessage : 'Current Black Sigatoka risk cannot be confirmed until new sensor data is received.',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    riskAvailable
                        ? 'Risk Score: $riskScore / 18'
                        : 'Risk Score: Unavailable',
                    style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  if (!isOnline) ...[
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.wifi_off),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'The farm device is offline. Prediction data may be unavailable or outdated.',
                              style: TextStyle(
                                color: AppColors.textDark,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (riskAvailable) ...[
                    const SizedBox(height: 10),

                    LinearProgressIndicator(
                      value: (riskScore / 18).clamp(0.0, 1.0),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(20),
                      backgroundColor: AppColors.background,
                      color: riskColor,
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Environmental Risk Indicators',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: hasScoreBreakdown
                          ? Column(
                              children: breakdown.map((item) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.label,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${item.score} / ${item.maxScore}',
                                            style: TextStyle(
                                              color: riskColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      LinearProgressIndicator(
                                        value: item.score / item.maxScore,
                                        minHeight: 6,
                                        borderRadius: BorderRadius.circular(20),
                                        backgroundColor: AppColors.background,
                                        color: riskColor,
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            )
                          : const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: AppColors.textLight,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Detailed risk indicators are not available yet. '
                                    'They will update when the farm device sends a new prediction.',
                                    style: TextStyle(
                                      color: AppColors.textLight,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ],
              ),
            ),

            if (riskAvailable) ...[
              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Detailed risk factors, recommended actions, and prediction insights '
                  'will update when the farm device sends a new prediction.',
                  style: TextStyle(color: AppColors.textLight, height: 1.4),
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'Environmental Risk Factors',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),

              const SizedBox(height: 8),

              if (riskExplanation.isNotEmpty) ...[
                Text(
                  riskExplanation,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 8),
              ],

              if (reasons.isEmpty)
                const Text(
                  'No environmental risk factors available.',
                  style: TextStyle(color: AppColors.textLight, height: 1.4),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reasons
                      .map(
                        (reason) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: riskColor.withValues(alpha: 0.20),
                            ),
                          ),
                          child: Text(
                            reason,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textDark,
                              height: 1.3,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),

              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: riskColor, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Recommended Action',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Text(
                      recommendedAction.isNotEmpty
                          ? recommendedAction
                          : recommendation,
                      style: TextStyle(
                        color: riskColor,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Prediction Insight',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),

              const SizedBox(height: 6),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.psychology_alt_outlined,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        smartInsight.isNotEmpty
                            ? smartInsight
                            : 'Prediction insight is currently unavailable.',
                        style: const TextStyle(
                          color: AppColors.textDark,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
