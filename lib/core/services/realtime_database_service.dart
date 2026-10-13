import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class RealtimeDatabaseService {
  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
    'https://bananadoctor-72ea5-default-rtdb.asia-southeast1.firebasedatabase.app/',
  );

  DatabaseReference deviceRef(String deviceId) {
    return _db.ref('devices/$deviceId');
  }

  DatabaseReference userDevicesRef(String uid) {
    return _db.ref('user_devices/$uid');
  }

  Future<String?> getAuthorizedDeviceId(String uid) async {
    final snapshot = await userDevicesRef(uid).get();

    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final devices = Map<String, dynamic>.from(snapshot.value as Map);

    for (final entry in devices.entries) {
      if (entry.value == true) {
        return entry.key;
      }
    }

    return null;
  }

  DatabaseReference statusRef(String deviceId) {
    return _db.ref('devices/$deviceId/current/status');
  }

  DatabaseReference predictionRef(String deviceId) {
    return _db.ref('devices/$deviceId/prediction_engine/current');
  }

  DatabaseReference commandsRef(String deviceId) {
    return _db.ref('devices/$deviceId/commands');
  }

  DatabaseReference heartbeatRef(String deviceId) {
    return _db.ref('devices/$deviceId/heartbeat');
  }

  Stream<DatabaseEvent> heartbeatStream(String deviceId) {
    return heartbeatRef(deviceId).onValue;
  }

  Stream<DatabaseEvent> commandHistoryStream(String deviceId) {
    return commandsRef(deviceId).onValue;
  }

  DatabaseReference activeCommandRef(String deviceId) {
    return _db.ref('devices/$deviceId/active_command');
  }

  Stream<DatabaseEvent> activeCommandStream(String deviceId) {
    return activeCommandRef(deviceId).onValue;
  }

  DatabaseReference sensorHistoryRef(String deviceId) {
    return _db.ref('devices/$deviceId/sensor_history');
  }

  DatabaseReference settingsRef(String deviceId) {
    return deviceRef(deviceId).child('settings');
  }

  Stream<DatabaseEvent> settingsStream(String deviceId) {
    return settingsRef(deviceId).onValue;
  }

  DatabaseReference predictionHistoryRef(String deviceId) {
    return _db.ref('devices/$deviceId/prediction_history');
  }

  DatabaseReference alertsRef(String deviceId) {
    return _db.ref('devices/$deviceId/alerts');
  }

  Stream<DatabaseEvent> alertsStream(String deviceId) {
    return alertsRef(deviceId).onValue;
  }

  Future<void> markAlertAsRead({
    required String deviceId,
    required String alertId,
  }) async {
    await alertsRef(deviceId).child(alertId).update({
      'isRead': true,
    });
  }

  Future<void> recordRiskToAlertMeasurement({
    required String deviceId,
    required String alertId,
    required String testTrialId,
    required int alertDisplayedEpochMs,
    required int riskToAlertMs,
  }) async {
    await alertsRef(deviceId).child(alertId).update({
      'alertDisplayedEpochMs': alertDisplayedEpochMs,
      'riskToAlertMs': riskToAlertMs,
      'responseTimeMeasured': true,
      'measuredTestTrialId': testTrialId,
    });
  }

  Future<void> updateAutoMode({
    required String deviceId,
    required bool enabled,
  }) async {
    await settingsRef(deviceId).update({'autoMode': enabled});
  }

  Future<void> cleanupOldCommands(
      String deviceId, {
        int keepLatest = 50,
      }) async {
    final snapshot = await commandsRef(
      deviceId,
    ).orderByChild('createdAt').get();

    if (!snapshot.exists || snapshot.value == null) return;

    final rawData = Map<String, dynamic>.from(snapshot.value as Map);

    if (rawData.length <= keepLatest) return;

    final entries = rawData.entries.toList()
      ..sort((a, b) {
        final aTime = a.value['createdAt'] ?? 0;
        final bTime = b.value['createdAt'] ?? 0;
        return aTime.compareTo(bTime);
      });

    final deleteCount = rawData.length - keepLatest;
    final updates = <String, Object?>{};

    for (final entry in entries.take(deleteCount)) {
      updates[entry.key] = null;
    }

    await commandsRef(deviceId).update(updates);
  }

  Future<void> cleanupOldAlerts(
      String deviceId, {
        int keepLatest = 100,
      }) async {
    final snapshot = await alertsRef(
      deviceId,
    ).orderByChild('createdAt').get();

    if (!snapshot.exists || snapshot.value == null) return;

    final rawData = Map<String, dynamic>.from(snapshot.value as Map);

    if (rawData.length <= keepLatest) return;

    final entries = rawData.entries.toList()
      ..sort((a, b) {
        final aTime = a.value['createdAt'] ?? 0;
        final bTime = b.value['createdAt'] ?? 0;
        return aTime.compareTo(bTime);
      });

    final deleteCount = rawData.length - keepLatest;
    final updates = <String, Object?>{};

    for (final entry in entries.take(deleteCount)) {
      updates[entry.key] = null;
    }

    await alertsRef(deviceId).update(updates);
  }

  Future<void> cleanupOldSensorHistory(
      String deviceId, {
        int keepLatest = 100,
      }) async {
    final snapshot = await sensorHistoryRef(
      deviceId,
    ).orderByChild('timestamp').get();

    if (!snapshot.exists || snapshot.value == null) return;

    final rawData = Map<String, dynamic>.from(snapshot.value as Map);

    if (rawData.length <= keepLatest) return;

    final entries = rawData.entries.toList()
      ..sort((a, b) {
        final aTime = a.value['timestamp'] ?? 0;
        final bTime = b.value['timestamp'] ?? 0;
        return aTime.compareTo(bTime);
      });

    final deleteCount = rawData.length - keepLatest;
    final updates = <String, Object?>{};

    for (final entry in entries.take(deleteCount)) {
      updates[entry.key] = null;
    }

    await sensorHistoryRef(deviceId).update(updates);
  }

  Future<Map<String, dynamic>?> getLatestAutoSprayCommand(
      String deviceId,
      ) async {
    final snapshot = await commandsRef(
      deviceId,
    ).orderByChild('createdAt').limitToLast(50).get();

    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final rawData = Map<String, dynamic>.from(snapshot.value as Map);

    final entries = rawData.entries.toList()
      ..sort((a, b) {
        final aData = Map<String, dynamic>.from(a.value as Map);
        final bData = Map<String, dynamic>.from(b.value as Map);

        final aTime = (aData['createdAt'] as num?)?.toInt() ?? 0;
        final bTime = (bData['createdAt'] as num?)?.toInt() ?? 0;

        return bTime.compareTo(aTime);
      });

    for (final entry in entries) {
      final data = Map<String, dynamic>.from(entry.value as Map);

      if (data['command'] == 'START_SPRAY' && data['trigger'] == 'AUTO') {
        return data;
      }
    }

    return null;
  }

  Future<void> sendCommand({
    required String deviceId,
    required Map<String, dynamic> commandData,
  }) async {
    final commandRef = commandsRef(deviceId).push();
    final commandId = commandRef.key;

    if (commandId == null) return;

    final payload = {
      ...commandData,
      'commandId': commandId,
      'status': 'PENDING',
      'executed': false,
      'deviceId': deviceId,
      'executedAt': null,
      'result': 'WAITING',
      'errorMessage': '',
      'createdAt': ServerValue.timestamp,
    };

    await commandRef.set(payload);

    await deviceRef(deviceId).child('active_command').set(payload);

    await cleanupOldCommands(deviceId);
  }
}

final realtimeDatabaseService = RealtimeDatabaseService();
