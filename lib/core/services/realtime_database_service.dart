import '../utils/command_submission_coordinator.dart';

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../utils/device_heartbeat.dart';
import '../utils/rtdb_value_parser.dart';
import '../utils/sprayer_safety.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class RealtimeDatabaseService {
  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://bananadoctor-72ea5-default-rtdb.asia-southeast1.firebasedatabase.app/',
  );

  DatabaseReference deviceRef(String deviceId) {
    return _db.ref('devices/$deviceId');
  }

  DatabaseReference userDevicesRef(String uid) {
    return _db.ref('user_devices/$uid');
  }

  final Map<String, Stream<DatabaseEvent>> _streams = {};
  final Map<String, Stream<String?>> _assignments = {};
  final CommandSubmissionCoordinator _submissions =
      CommandSubmissionCoordinator();

  void invalidateCommandSession() => _submissions.invalidateSession();

  Stream<DatabaseEvent> _cached(String key, Query query) =>
      _streams.putIfAbsent(key, () => query.onValue);

  void clearStreamCache() {
    _streams.clear();
    _assignments.clear();
  }

  String? _assignedDevice(Object? value) {
    for (final entry in readRtdbMap(value).entries) {
      if (entry.value == true) return entry.key;
    }
    return null;
  }

  Future<String?> getAuthorizedDeviceId(String uid) async {
    return _assignedDevice((await userDevicesRef(uid).get()).value);
  }

  Stream<String?> authorizedDeviceIdStream(String uid) =>
      _assignments.putIfAbsent(
        uid,
        () => _cached(
          'assignment/$uid',
          userDevicesRef(uid),
        ).map((event) => _assignedDevice(event.snapshot.value)),
      );

  Stream<DatabaseEvent> statusStream(String deviceId) =>
      _cached('status/$deviceId', statusRef(deviceId));

  Stream<DatabaseEvent> predictionStream(String deviceId) =>
      _cached('prediction/$deviceId', predictionRef(deviceId));

  Stream<DatabaseEvent> sensorHistoryStream(String deviceId) => _cached(
    'sensors/$deviceId',
    sensorHistoryRef(deviceId).orderByChild('timestamp').limitToLast(20),
  );

  Stream<DatabaseEvent> predictionHistoryStream(String deviceId) => _cached(
    'predictions/$deviceId',
    predictionHistoryRef(deviceId).orderByChild('timestamp').limitToLast(20),
  );

  Stream<DatabaseEvent> get connectionStream =>
      _cached('connection', _db.ref('.info/connected'));

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
    return _cached('heartbeat/$deviceId', heartbeatRef(deviceId));
  }

  Stream<DatabaseEvent> commandHistoryStream(String deviceId) {
    return _cached(
      'commands/$deviceId',
      commandsRef(deviceId).orderByChild('createdAt').limitToLast(50),
    );
  }

  DatabaseReference activeCommandRef(String deviceId) {
    return _db.ref('devices/$deviceId/active_command');
  }

  Stream<DatabaseEvent> activeCommandStream(String deviceId) {
    return _cached('active/$deviceId', activeCommandRef(deviceId));
  }

  DatabaseReference sensorHistoryRef(String deviceId) {
    return _db.ref('devices/$deviceId/sensor_history');
  }

  DatabaseReference settingsRef(String deviceId) {
    return deviceRef(deviceId).child('settings');
  }

  Stream<DatabaseEvent> settingsStream(String deviceId) {
    return _cached('settings/$deviceId', settingsRef(deviceId));
  }

  DatabaseReference predictionHistoryRef(String deviceId) {
    return _db.ref('devices/$deviceId/prediction_history');
  }

  DatabaseReference alertsRef(String deviceId) {
    return _db.ref('devices/$deviceId/alerts');
  }

  Stream<DatabaseEvent> alertsStream(String deviceId) {
    return _cached('alerts/$deviceId', alertsRef(deviceId));
  }

  Future<void> markAlertAsRead({
    required String deviceId,
    required String alertId,
  }) async {
    await alertsRef(deviceId).child(alertId).update({'isRead': true});
  }

  Future<bool> recordRiskToAlertMeasurement({
    required String deviceId,
    required String alertId,
    required String testTrialId,
    required int alertDisplayedEpochMs,
    required int riskToAlertMs,
  }) async {
    if (riskToAlertMs < 0 || alertDisplayedEpochMs <= 0) return false;
    final result = await alertsRef(deviceId)
        .child(alertId)
        .runTransaction((value) {
          final alert = readRtdbMap(value);
          if (alert['responseTimeTest'] != true ||
              alert['testTrialId'] != testTrialId ||
              alert['responseTimeMeasured'] == true ||
              alert['alertDisplayedEpochMs'] != null ||
              alert['riskToAlertMs'] != null ||
              readRtdbInt(alert, 'riskGeneratedEpochMs') !=
                  alertDisplayedEpochMs - riskToAlertMs) {
            return Transaction.abort();
          }
          return Transaction.success({
            ...alert,
            'alertDisplayedEpochMs': alertDisplayedEpochMs,
            'riskToAlertMs': riskToAlertMs,
            'responseTimeMeasured': true,
            'measuredTestTrialId': testTrialId,
          });
        }, applyLocally: false)
        .timeout(const Duration(seconds: 5));
    return result.committed;
  }

  Future<void> updateAutoMode({
    required String deviceId,
    required bool enabled,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await _requireDeviceAccess(deviceId);
    if (enabled) {
      final snapshots = await Future.wait([
        heartbeatRef(deviceId).get(),
        statusRef(deviceId).get(),
        activeCommandRef(deviceId).get(),
      ]).timeout(const Duration(seconds: 5));
      final reason = sprayerCommandBlockReason(
        command: 'START_SPRAY',
        connected: true,
        heartbeatAlive: isDeviceHeartbeatAlive(
          readRtdbMap(snapshots[0].value),
          deviceId: deviceId,
        ),
        status: readRtdbMap(snapshots[1].value),
        activeCommand: readRtdbMap(snapshots[2].value),
        commandStateKnown:
            snapshots[2].value == null || snapshots[2].value is Map,
      );
      if (reason != null) throw StateError(reason);
    }
    if (uid == null || FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Your account changed. Change Auto Mode again.');
    }
    await settingsRef(deviceId)
        .update({'autoMode': enabled})
        .timeout(const Duration(seconds: 8));
  }

  Future<Map<String, dynamic>?> getLatestAutoSprayCommand(
    String deviceId,
  ) async {
    final snapshot = await commandsRef(deviceId)
        .orderByChild('createdAt')
        .limitToLast(50)
        .get();

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

  Future<void> _requireDeviceAccess(String deviceId) async {
    if (deviceId.isEmpty || deviceId.contains('/') || deviceId.contains('..')) {
      throw ArgumentError('Invalid device identifier.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in before controlling a device.');
    final connected = await connectionStream.first.timeout(
      const Duration(seconds: 5),
    );
    if (connected.snapshot.value != true)
      throw StateError('Reconnect before sending commands.');
    final permission = await userDevicesRef(user.uid)
        .child(deviceId)
        .get()
        .timeout(const Duration(seconds: 5));
    if (permission.value != true ||
        FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw StateError('This device is not assigned to your account.');
    }
  }

  Future<void> sendCommand({
    required String deviceId,
    required Map<String, dynamic> commandData,
  }) async {
    validateSprayerCommand(commandData);
    final command = commandData['command'] as String;
    final stop = command == 'EMERGENCY_STOP';
    final submission = _submissions.begin(deviceId, isStop: stop);
    var publicationStarted = false;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await _requireDeviceAccess(deviceId);
      if (!stop) {
        final snapshots = await Future.wait([
          heartbeatRef(deviceId).get(),
          statusRef(deviceId).get(),
          activeCommandRef(deviceId).get(),
        ]).timeout(const Duration(seconds: 5));
        final reason = sprayerCommandBlockReason(
          command: command,
          connected: true,
          heartbeatAlive: isDeviceHeartbeatAlive(
            readRtdbMap(snapshots[0].value),
            deviceId: deviceId,
          ),
          status: readRtdbMap(snapshots[1].value),
          activeCommand: readRtdbMap(snapshots[2].value),
          commandStateKnown:
              snapshots[2].value == null || snapshots[2].value is Map,
        );
        if (reason != null) throw StateError(reason);
      }
      if (uid == null || FirebaseAuth.instance.currentUser?.uid != uid) {
        throw StateError('Your account changed. Submit the command again.');
      }

      _submissions.requireCurrent(submission);
      final commandId = commandsRef(deviceId).push().key;
      if (commandId == null)
        throw StateError('Unable to create a command identifier.');
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
      final publication = deviceRef(deviceId)
          .update({'commands/$commandId': payload, 'active_command': payload});
      publicationStarted = true;
      // A timeout cannot cancel an offline Firebase write. Keep the local
      // start lock until the original write completes or fails.
      unawaited(
        publication.then<void>(
          (_) {
            _submissions.complete(submission);
          },
          onError: (Object error, StackTrace stack) {
            _submissions.complete(submission);
          },
        ),
      );
      await publication.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException(
            'Command delivery is not confirmed. Check its status before retrying.',
          );
        },
      );
    } finally {
      if (!publicationStarted) _submissions.complete(submission);
    }
  }
}

final realtimeDatabaseService = RealtimeDatabaseService();
