import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/iot_data_model.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/realtime_database_service.dart';
import '../../core/utils/device_heartbeat.dart';
import '../../core/utils/rtdb_value_parser.dart';

import 'widgets/system_status_banner.dart';
import 'widgets/header_card.dart';
import 'widgets/risk_prediction_card.dart';
import 'widgets/prediction_history_chart.dart';
import 'widgets/disease_development_timeline.dart';
import 'widgets/sensor_card.dart';
import 'widgets/device_health_card.dart';
import 'widgets/device_offline_warning_card.dart';
import 'widgets/environmental_trends_chart.dart';
import 'widgets/dashboard_error_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? heartbeatCheckTimer;
  late Stream<String?> authorizedDeviceIdStream;

  IotDataModel mapRealtimeDataToIotData(
    Map<String, dynamic> status,
    Map<String, dynamic> prediction,
  ) => IotDataModel.fromRealtimeData(status, prediction);

  void retryData() {
    final user = FirebaseAuth.instance.currentUser;
    realtimeDatabaseService.clearStreamCache();
    firestoreService.clearStreamCache();
    setState(() {
      authorizedDeviceIdStream = user == null
          ? Stream.value(null)
          : realtimeDatabaseService.authorizedDeviceIdStream(user.uid);
    });
  }

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    authorizedDeviceIdStream = user == null
        ? Stream.value(null)
        : realtimeDatabaseService.authorizedDeviceIdStream(user.uid);

    heartbeatCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    heartbeatCheckTimer?.cancel();
    super.dispose();
  }

  Color riskColor(String risk) {
    switch (risk) {
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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user logged in.')));
    }

    return StreamBuilder<String?>(
      stream: authorizedDeviceIdStream,
      builder: (context, deviceSnapshot) {
        if (deviceSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (deviceSnapshot.hasError) {
          return DashboardErrorState(onRetry: retryData);
        }

        final deviceId = deviceSnapshot.data ?? '';

        if (deviceId.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No authorized BananaDoctor device is assigned to this account.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return StreamBuilder(
          stream: realtimeDatabaseService.heartbeatStream(deviceId),
          builder: (context, heartbeatSnapshot) {
            if (heartbeatSnapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text(AppStrings.dashboardTitle)),
                body: DashboardErrorState(onRetry: retryData),
              );
            }

            if (heartbeatSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final deviceInfo = readRtdbMap(
              heartbeatSnapshot.data?.snapshot.value,
            );

            final deviceOnline = isDeviceHeartbeatAlive(
              deviceInfo,
              deviceId: deviceId,
            );

            return Scaffold(
              appBar: AppBar(title: const Text(AppStrings.dashboardTitle)),
              body: StreamBuilder(
                stream: realtimeDatabaseService.statusStream(deviceId),
                builder: (context, statusSnapshot) {
                  if (statusSnapshot.hasError) {
                    return DashboardErrorState(onRetry: retryData);
                  }

                  if (!statusSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (statusSnapshot.data!.snapshot.value == null) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Device status is not available yet. '
                          'Check that the farm device is powered and connected.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return StreamBuilder(
                    stream: realtimeDatabaseService.predictionStream(deviceId),
                    builder: (context, predictionSnapshot) {
                      if (predictionSnapshot.hasError) {
                        return DashboardErrorState(onRetry: retryData);
                      }

                      if (!predictionSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (predictionSnapshot.data!.snapshot.value == null) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Prediction data is not available yet. '
                              'BananaDoctor will update this section after the farm device sends new sensor readings.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final statusData = readRtdbMap(
                        statusSnapshot.data!.snapshot.value,
                      );

                      final predictionData = readRtdbMap(
                        predictionSnapshot.data!.snapshot.value,
                      );

                      final data = mapRealtimeDataToIotData(
                        statusData,
                        predictionData,
                      );

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HeaderCard(),

                            const SizedBox(height: 16),

                            SystemStatusBanner(
                              esp32Status: data.esp32Status,
                              riskLevel: data.prediction.riskLevel,
                              isDeviceOffline: !deviceOnline,
                            ),

                            if (!deviceOnline) ...[
                              const SizedBox(height: 16),
                              const DeviceOfflineWarningCard(),
                            ],

                            const SizedBox(height: 16),

                            RiskPredictionCard(
                              riskLevel: data.prediction.riskLevel,
                              riskColor: riskColor(data.prediction.riskLevel),
                              reasons: data.prediction.reasons,
                              recommendation: data.prediction.recommendation,
                              smartInsight: data.prediction.smartInsight,
                              riskScore: data.prediction.riskScore,
                              temperatureScore:
                                  data.prediction.temperatureScore,
                              humidityScore: data.prediction.humidityScore,
                              wetnessStatusScore:
                                  data.prediction.wetnessStatusScore,
                              wetnessDurationScore:
                                  data.prediction.wetnessDurationScore,
                              persistenceScore:
                                  data.prediction.persistenceScore,
                              hasScoreBreakdown:
                                  data.prediction.hasScoreBreakdown,
                              riskExplanation: data.prediction.riskExplanation,
                              recommendedAction:
                                  data.prediction.recommendedAction,
                              isOnline: deviceOnline,
                            ),

                            const SizedBox(height: 16),

                            PredictionHistoryChart(deviceId: deviceId),

                            const SizedBox(height: 16),

                            DiseaseDevelopmentTimeline(deviceId: deviceId),

                            EnvironmentalTrendsChart(deviceId: deviceId),

                            const SizedBox(height: 16),

                            const Text(
                              AppStrings.sensorReadings,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  child: SensorCard(
                                    icon: Icons.thermostat,
                                    label: 'Temperature',
                                    value: deviceOnline && data.hasTemperature
                                        ? '${data.temperature}°C'
                                        : 'Unavailable',
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: SensorCard(
                                    icon: Icons.water_drop_outlined,
                                    label: 'Humidity',
                                    value: deviceOnline && data.hasHumidity
                                        ? '${data.humidity}%'
                                        : 'Unavailable',
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: SensorCard(
                                    icon: Icons.grass,
                                    label: 'Leaf Wetness Duration',
                                    value: deviceOnline && data.hasLwdHours
                                        ? '${data.lwdHours} hrs'
                                        : 'Unavailable',
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: SensorCard(
                                    icon: !deviceOnline || !data.hasLeafWet
                                        ? Icons.help_outline
                                        : data.leafWet
                                        ? Icons.water
                                        : Icons.dry,
                                    label: 'Leaf Status',
                                    value: deviceOnline && data.hasLeafWet
                                        ? data.leafWet
                                              ? 'Wet'
                                              : 'Dry'
                                        : 'Unavailable',
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            DeviceHealthCard(
                              data: data,
                              deviceInfo: deviceInfo,
                              isOnline: deviceOnline,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
