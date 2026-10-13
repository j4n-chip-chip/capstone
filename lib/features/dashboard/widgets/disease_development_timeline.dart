import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/rtdb_value_parser.dart';
import '../../../core/services/realtime_database_service.dart';
import '../models/risk_timeline_item.dart';

class DiseaseDevelopmentTimeline extends StatefulWidget {
  const DiseaseDevelopmentTimeline({super.key, required this.deviceId});

  final String deviceId;

  @override
  State<DiseaseDevelopmentTimeline> createState() =>
      _DiseaseDevelopmentTimelineState();
}

class _DiseaseDevelopmentTimelineState
    extends State<DiseaseDevelopmentTimeline> {
  late Query _timelineQuery;
  late Stream<DatabaseEvent> _timelineStream;

  @override
  void initState() {
    super.initState();

    _timelineQuery = realtimeDatabaseService
        .predictionHistoryRef(widget.deviceId)
        .orderByChild('timestamp')
        .limitToLast(5);

    _timelineStream = _timelineQuery.onValue;
  }

  @override
  void didUpdateWidget(covariant DiseaseDevelopmentTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.deviceId != widget.deviceId) {
      _timelineQuery = realtimeDatabaseService
          .predictionHistoryRef(widget.deviceId)
          .orderByChild('timestamp')
          .limitToLast(5);

      _timelineStream = _timelineQuery.onValue;
    }
  }

  Color riskColor(String riskLevel) {
    switch (riskLevel) {
      case 'LOW':
        return AppColors.lowRisk;
      case 'MODERATE':
        return AppColors.moderateRisk;
      case 'HIGH':
        return AppColors.highRisk;
      case 'VERY HIGH':
        return AppColors.veryHighRisk;
      default:
        return AppColors.textLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _timelineStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Disease Development Timeline',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Unable to load disease development history. '
                    'Check your internet connection and try again.',
                    style: TextStyle(color: AppColors.textLight, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const SizedBox.shrink();
        }

        final raw = readRtdbMap(snapshot.data?.snapshot.value);

        final entries =
            raw.entries.where((entry) => entry.value is Map).toList()
              ..sort((a, b) {
                final aValue = Map<String, dynamic>.from(a.value as Map);
                final bValue = Map<String, dynamic>.from(b.value as Map);

                final aTime = readRtdbInt(aValue, 'timestamp') ?? 0;
                final bTime = readRtdbInt(bValue, 'timestamp') ?? 0;

                return aTime.compareTo(bTime);
              });

        final items = <RiskTimelineItem>[];

        for (final entry in entries) {
          final value = Map<String, dynamic>.from(entry.value as Map);

          final riskLevel = readRtdbUpperString(value, 'riskLevel');
          final riskScore = readRtdbInt(value, 'riskScore');
          final timestamp = readRtdbInt(value, 'timestamp');

          if (riskLevel == null ||
              riskScore == null ||
              timestamp == null ||
              timestamp <= 0) {
            continue;
          }

          const validRiskLevels = {'LOW', 'MODERATE', 'HIGH', 'VERY HIGH'};

          if (!validRiskLevels.contains(riskLevel)) {
            continue;
          }

          if (riskScore < 0 || riskScore > 18) {
            continue;
          }

          items.add(
            RiskTimelineItem(
              riskLevel: riskLevel,
              riskScore: riskScore,
              timestamp: timestamp,
            ),
          );
        }

        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        final firstScore = items.first.riskScore;
        final lastScore = items.last.riskScore;

        final trendText = lastScore > firstScore
            ? 'Increasing Risk'
            : lastScore < firstScore
            ? 'Decreasing Risk'
            : 'Stable Risk';

        final trendIcon = lastScore > firstScore
            ? Icons.trending_up
            : lastScore < firstScore
            ? Icons.trending_down
            : Icons.trending_flat;

        final trendColor = lastScore > firstScore
            ? AppColors.danger
            : lastScore < firstScore
            ? AppColors.lowRisk
            : AppColors.textLight;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Disease Development Timeline',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Recent environmental risk movement based on prediction history.',
                  style: TextStyle(color: AppColors.textLight, height: 1.4),
                ),

                const SizedBox(height: 16),

                ...items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isLast = index == items.length - 1;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: riskColor(item.riskLevel),
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (!isLast)
                            Container(
                              width: 2,
                              height: 32,
                              color: AppColors.textLight.withValues(
                                alpha: 0.25,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.riskLevel,
                                  style: TextStyle(
                                    color: riskColor(item.riskLevel),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                '${item.riskScore} / 18',
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),

                const Divider(height: 24),

                Row(
                  children: [
                    Icon(trendIcon, color: trendColor),
                    const SizedBox(width: 8),
                    Text(
                      trendText,
                      style: TextStyle(
                        color: trendColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
