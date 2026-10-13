import '../utils/rtdb_value_parser.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String alertId;
  final String deviceId;

  final String type;
  final String title;
  final String message;
  final String severity;

  final bool isRead;
  final DateTime createdAt;

  // Temporary Risk-to-Alert research timing metadata.
  final bool responseTimeTest;
  final int? testTrialNumber;
  final String? testTrialId;
  final int? riskGeneratedEpochMs;
  final int? riskScore;
  final String? riskLevel;
  final int? alertDisplayedEpochMs;
  final int? riskToAlertMs;

  AlertModel({
    required this.alertId,
    required this.deviceId,
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    required this.isRead,
    required this.createdAt,
    this.responseTimeTest = false,
    this.testTrialNumber,
    this.testTrialId,
    this.riskGeneratedEpochMs,
    this.riskScore,
    this.riskLevel,
    this.alertDisplayedEpochMs,
    this.riskToAlertMs,
  });

  factory AlertModel.fromMap(
    Map<String, dynamic> map, {
    required String alertId,
    required String deviceId,
  }) {
    return AlertModel(
      alertId: alertId,
      deviceId: deviceId,
      type: readRtdbString(map, 'type', fallback: 'SYSTEM'),
      title: readRtdbString(map, 'title', fallback: ''),
      message: readRtdbString(map, 'message', fallback: ''),
      severity: readRtdbString(map, 'severity', fallback: 'INFO'),
      isRead: readRtdbBool(map, 'isRead') ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : readRtdbDateTime(map['createdAt']),
      responseTimeTest: map['responseTimeTest'] == true,
      testTrialNumber: readRtdbInt(map, 'testTrialNumber'),
      testTrialId: map['testTrialId']?.toString(),
      riskGeneratedEpochMs: readRtdbInt(map, 'riskGeneratedEpochMs'),
      riskScore: readRtdbInt(map, 'riskScore'),
      riskLevel: map['riskLevel']?.toString(),
      alertDisplayedEpochMs: readRtdbInt(map, 'alertDisplayedEpochMs'),
      riskToAlertMs: readRtdbInt(map, 'riskToAlertMs'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
      'message': message,
      'severity': severity,
      'isRead': isRead,
      'createdAt': createdAt,
      'responseTimeTest': responseTimeTest,
      'testTrialNumber': testTrialNumber,
      'testTrialId': testTrialId,
      'riskGeneratedEpochMs': riskGeneratedEpochMs,
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'alertDisplayedEpochMs': alertDisplayedEpochMs,
      'riskToAlertMs': riskToAlertMs,
    };
  }
}
