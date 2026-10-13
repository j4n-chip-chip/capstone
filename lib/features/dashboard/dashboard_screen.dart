import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/iot_data_model.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/prediction_engine_model.dart';
import '../../core/services/realtime_database_service.dart';
import '../../core/utils/device_heartbeat.dart';

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
  DateTime? lastRtdbCleanupTime;
  bool isRtdbCleanupRunning = false;
  bool isDeviceOffline(bool deviceOnline) {
    return !deviceOnline;
  }

  late Future<String?> authorizedDeviceIdFuture;

  double? readDouble(Map data, String key) {
    final value = data[key];

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  bool? readBool(Map data, String key) {
    final value = data[key];

    if (value is bool) {
      return value;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();

      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }

    return null;
  }

  DateTime readWallClockDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is num && value >= 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value.round());
    }

    // ESP32 millis() is uptime, not a real calendar timestamp.
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  IotDataModel mapRealtimeDataToIotData(
      Map<String, dynamic> status,
      Map<String, dynamic> prediction,
      ) {
    return IotDataModel(
      temperature: readDouble(status, 'temperature') ?? 0.0,
      humidity: (readDouble(status, 'humidity') ?? 0.0).round(),
      leafWet: readBool(status, 'leafWet') ?? false,
      lwdHours: readDouble(status, 'lwdHours') ?? 0.0,

      hasTemperature:
      readBool(status, 'temperatureAvailable') == true &&
          readDouble(status, 'temperature') != null,

      hasHumidity:
      readBool(status, 'humidityAvailable') == true &&
          readDouble(status, 'humidity') != null,

      hasLeafWet:
      readBool(status, 'leafWetAvailable') == true &&
          readBool(status, 'leafWet') != null,

      hasLwdHours:
      readBool(status, 'leafWetAvailable') == true &&
          readDouble(status, 'lwdHours') != null,

      esp32Status: status['esp32Status'] ?? 'OFFLINE',
      sensorStatus: status['sensorStatus'] ?? 'Unavailable',
      relayStatus: status['relayStatus'] ?? 'Unavailable',
      pumpStatus: status['pumpStatus'] ?? 'Disabled',
      lastUpdate: readWallClockDateTime(status['lastUpdate']),
      prediction: PredictionEngineModel(
        riskLevel:
        prediction['riskLevel']?.toString().trim().toUpperCase() ?? 'LOW',
        reasons: List<String>.from(prediction['reasons'] ?? []),
        recommendation:
        prediction['recommendation'] ??
            prediction['recommendedAction'] ??
            '',
        smartInsight: prediction['smartInsight'] ?? '',
        lastEvaluated: readWallClockDateTime(prediction['lastEvaluated']),
        riskScore: (prediction['riskScore'] as num?)?.round() ?? 0,
        riskExplanation: prediction['riskExplanation'] ?? '',
        recommendedAction: prediction['recommendedAction'] ?? '',

        hasScoreBreakdown:
        prediction.containsKey('temperatureScore') &&
            prediction.containsKey('humidityScore') &&
            prediction.containsKey('wetnessStatusScore') &&
            prediction.containsKey('wetnessDurationScore') &&
            prediction.containsKey('persistenceScore'),

        temperatureScore:
        (prediction['temperatureScore'] as num?)?.round() ?? 0,
        humidityScore: (prediction['humidityScore'] as num?)?.round() ?? 0,
        wetnessStatusScore:
        (prediction['wetnessStatusScore'] as num?)?.round() ?? 0,
        wetnessDurationScore:
        (prediction['wetnessDurationScore'] as num?)?.round() ?? 0,
        persistenceScore:
        (prediction['persistenceScore'] as num?)?.round() ?? 0,
      ),
    );
  }

  Future<void> runRtdbCleanupIfNeeded(String deviceId) async {
    if (isRtdbCleanupRunning) return;

    final now = DateTime.now();

    if (lastRtdbCleanupTime != null &&
        now.difference(lastRtdbCleanupTime!).inMinutes < 5) {
      return;
    }

    isRtdbCleanupRunning = true;

    try {
      await realtimeDatabaseService.cleanupOldSensorHistory(deviceId);
      await realtimeDatabaseService.cleanupOldCommands(deviceId);
      await realtimeDatabaseService.cleanupOldAlerts(deviceId);

      lastRtdbCleanupTime = now;
    } finally {
      isRtdbCleanupRunning = false;
    }
  }

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    authorizedDeviceIdFuture = user == null
        ? Future.value(null)
        : realtimeDatabaseService.getAuthorizedDeviceId(user.uid);

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

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firestoreService.userStream(user.uid),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return DashboardErrorState(
            onRetry: () {
              setState(() {});
            },
          );
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return FutureBuilder<String?>(
          future: authorizedDeviceIdFuture,
          builder: (context, deviceSnapshot) {
            if (deviceSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (deviceSnapshot.hasError) {
              return DashboardErrorState(
                onRetry: () {
                  setState(() {});
                },
              );
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
                    appBar: AppBar(
                      title: const Text(AppStrings.dashboardTitle),
                    ),
                    body: DashboardErrorState(
                      onRetry: () {
                        setState(() {});
                      },
                    ),
                  );
                }

                if (!heartbeatSnapshot.hasData ||
                    heartbeatSnapshot.data!.snapshot.value == null) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final deviceInfo = Map<String, dynamic>.from(
                  heartbeatSnapshot.data!.snapshot.value as Map,
                );

                final deviceOnline = isDeviceHeartbeatAlive(deviceInfo);

                return Scaffold(
                  appBar: AppBar(title: const Text(AppStrings.dashboardTitle)),
                  body: StreamBuilder(
                    stream: realtimeDatabaseService.statusRef(deviceId).onValue,
                    builder: (context, statusSnapshot) {
                      if (statusSnapshot.hasError) {
                        return DashboardErrorState(
                          onRetry: () {
                            setState(() {});
                          },
                        );
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
                        stream: realtimeDatabaseService
                            .predictionRef(deviceId)
                            .onValue,
                        builder: (context, predictionSnapshot) {
                          if (predictionSnapshot.hasError) {
                            return DashboardErrorState(
                              onRetry: () {
                                setState(() {});
                              },
                            );
                          }

                          if (!predictionSnapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
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

                          final statusData = Map<String, dynamic>.from(
                            statusSnapshot.data!.snapshot.value as Map,
                          );

                          final predictionData = Map<String, dynamic>.from(
                            predictionSnapshot.data!.snapshot.value as Map,
                          );

                          final data = mapRealtimeDataToIotData(
                            statusData,
                            predictionData,
                          );

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            runRtdbCleanupIfNeeded(deviceId);
                          });

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
                                  riskColor: riskColor(
                                    data.prediction.riskLevel,
                                  ),
                                  reasons: data.prediction.reasons,
                                  recommendation:
                                  data.prediction.recommendation,
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
                                  riskExplanation:
                                  data.prediction.riskExplanation,
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
                                        value:
                                        deviceOnline && data.hasTemperature
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
      },
    );
  }
}
