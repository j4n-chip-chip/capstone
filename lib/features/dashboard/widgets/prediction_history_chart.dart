import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/realtime_database_service.dart';
import '../../../core/utils/rtdb_value_parser.dart';
import '../models/prediction_history_point.dart';

class PredictionHistoryChart extends StatelessWidget {
  const PredictionHistoryChart({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: realtimeDatabaseService
          .predictionHistoryRef(deviceId)
          .orderByChild('timestamp')
          .limitToLast(20)
          .onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prediction History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Unable to load prediction history. '
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

        final raw = Map<String, dynamic>.from(
          snapshot.data!.snapshot.value as Map,
        );

        final entries =
        raw.entries.where((entry) => entry.value is Map).toList()
          ..sort((a, b) {
            final aValue = Map<String, dynamic>.from(a.value as Map);

            final bValue = Map<String, dynamic>.from(b.value as Map);

            final aTime = readRtdbInt(aValue, 'timestamp') ?? 0;

            final bTime = readRtdbInt(bValue, 'timestamp') ?? 0;

            return aTime.compareTo(bTime);
          });

        final points = <PredictionHistoryPoint>[];

        for (final entry in entries) {
          final value = Map<String, dynamic>.from(entry.value as Map);

          final riskScore = readRtdbDouble(value, 'riskScore');

          final timestamp = readRtdbInt(value, 'timestamp');

          if (riskScore == null || timestamp == null || timestamp <= 0) {
            continue;
          }

          points.add(
            PredictionHistoryPoint(
              index: points.length.toDouble(),
              riskScore: riskScore,
              timestamp: timestamp,
            ),
          );
        }

        if (points.length < 2) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prediction History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Recent Black Sigatoka environmental risk score trend.',
                  style: TextStyle(color: AppColors.textLight, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (points.length - 1).toDouble(),
                      minY: 0,
                      maxY: 18,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 5,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: AppColors.textLight.withValues(alpha: 0.12),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            interval: 5,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 11,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            interval: 5,
                            getTitlesWidget: (value, meta) {
                              if (value == 0 ||
                                  value == points.length - 1 ||
                                  value % 5 == 0) {
                                return Text(
                                  '${value.toInt() + 1}',
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 11,
                                  ),
                                );
                              }

                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: points
                              .map(
                                (e) => FlSpot(
                              e.index,
                              e.riskScore.clamp(0, 18).toDouble(),
                            ),
                          )
                              .toList(),
                          isCurved: true,
                          curveSmoothness: 0.25,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primaryGreen.withValues(
                              alpha: 0.08,
                            ),
                          ),
                          color: AppColors.primaryGreen,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
