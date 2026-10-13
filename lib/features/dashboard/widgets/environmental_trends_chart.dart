import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/realtime_database_service.dart';
import '../../../core/utils/rtdb_value_parser.dart';
import '../models/sensor_point.dart';
import 'chart_legend.dart';

class EnvironmentalTrendsChart extends StatelessWidget {
  const EnvironmentalTrendsChart({super.key, required this.deviceId});

  final String deviceId;

  double getMaxY(List<SensorPoint> points) {
    if (points.isEmpty) return 100;

    final maxValue = points
        .map(
          (e) => [
            e.temperature,
            e.humidity,
            e.lwdHours,
          ].reduce((a, b) => a > b ? a : b),
        )
        .reduce((a, b) => a > b ? a : b);

    if (maxValue <= 50) return 60;
    if (maxValue <= 100) return 100;

    return maxValue + 20;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: realtimeDatabaseService
          .sensorHistoryRef(deviceId)
          .limitToLast(20)
          .onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Unable to load environmental trends. '
                'Check your internet connection and try again.',
                style: TextStyle(color: AppColors.textLight, height: 1.4),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Environmental trends will appear after sensor history is recorded.',
                style: TextStyle(color: AppColors.textLight),
              ),
            ),
          );
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

        final points = <SensorPoint>[];

        for (final entry in entries) {
          final value = Map<String, dynamic>.from(entry.value as Map);

          final temperature = readRtdbDouble(value, 'temperature');

          final humidity = readRtdbDouble(value, 'humidity');

          final lwdHours = readRtdbDouble(value, 'lwdHours');

          final timestamp = readRtdbInt(value, 'timestamp');

          if (temperature == null ||
              humidity == null ||
              lwdHours == null ||
              timestamp == null ||
              timestamp <= 0) {
            continue;
          }

          points.add(
            SensorPoint(
              index: points.length.toDouble(),
              temperature: temperature,
              humidity: humidity,
              lwdHours: lwdHours,
            ),
          );
        }

        if (points.length < 2) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Collecting more sensor records for trend visualization.',
                style: TextStyle(color: AppColors.textLight),
              ),
            ),
          );
        }

        final maxY = getMaxY(points);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Environmental Trends',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Recent temperature, humidity, and leaf wetness duration patterns.',
                  style: TextStyle(color: AppColors.textLight, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 260,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (points.length - 1).toDouble(),
                      minY: 0,
                      maxY: maxY,
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) {
                            return spots.map((spot) {
                              final label = spot.barIndex == 0
                                  ? 'Temp'
                                  : spot.barIndex == 1
                                  ? 'Humidity'
                                  : 'LWD';

                              final suffix = spot.barIndex == 0
                                  ? '°C'
                                  : spot.barIndex == 1
                                  ? '%'
                                  : ' scaled';

                              return LineTooltipItem(
                                '$label: '
                                '${spot.y.toStringAsFixed(1)}'
                                '$suffix',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 20,
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
                            reservedSize: 42,
                            interval: 20,
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
                              .map((e) => FlSpot(e.index, e.temperature))
                              .toList(),
                          isCurved: true,
                          curveSmoothness: 0.25,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.danger.withValues(alpha: 0.06),
                          ),
                          color: AppColors.danger,
                        ),
                        LineChartBarData(
                          spots: points
                              .map((e) => FlSpot(e.index, e.humidity))
                              .toList(),
                          isCurved: true,
                          curveSmoothness: 0.25,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primaryGreen.withValues(
                              alpha: 0.06,
                            ),
                          ),
                          color: AppColors.primaryGreen,
                        ),
                        LineChartBarData(
                          spots: points
                              .map((e) => FlSpot(e.index, e.lwdHours))
                              .toList(),
                          isCurved: true,
                          curveSmoothness: 0.25,
                          dashArray: [7, 4],
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    ChartLegend(
                      color: AppColors.danger,
                      label: 'Temperature °C',
                    ),
                    ChartLegend(
                      color: AppColors.primaryGreen,
                      label: 'Humidity %',
                    ),
                    ChartLegend(color: AppColors.warning, label: 'LWD hours'),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Leaf wetness duration is shown in hours.',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
