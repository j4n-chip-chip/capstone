// Standalone edge-case checks: dart test/edge_cases.dart
// These exercise production Dart logic without Flutter, Firebase, or a device.
import 'dart:async';
import 'dart:io';

import '../lib/core/models/iot_data_model.dart';
import '../lib/core/models/prediction_engine_model.dart';
import '../lib/core/utils/command_submission_coordinator.dart';
import '../lib/core/utils/device_heartbeat.dart';
import '../lib/core/utils/notification_policy.dart';
import '../lib/core/utils/rtdb_value_parser.dart';
import '../lib/core/utils/sprayer_safety.dart';

int checked = 0;
int failed = 0;

void expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void expectArgumentError(void Function() action) {
  try {
    action();
  } on ArgumentError {
    return;
  }
  throw StateError('Invalid command was accepted.');
}

void expectStateError(void Function() action) {
  try {
    action();
  } on StateError {
    return;
  }
  throw StateError('Invalid concurrent submission was accepted.');
}

Future<void> edge(String label, FutureOr<void> Function() body) async {
  checked++;
  resetDeviceHeartbeatTracker();
  try {
    await body();
    stdout.writeln('PASS: $label');
  } catch (error, stack) {
    failed++;
    stderr.writeln('FAIL: $label -- $error\n$stack');
  }
}

Map<String, dynamic> heartbeat(int value) => {
  'online': true,
  'lastHeartbeat': value,
};

const idleStatus = {
  'esp32Status': 'ONLINE',
  'pumpStatus': 'OFF',
  'cooldownActive': false,
};

String? blocked({
  String command = 'START_SPRAY',
  bool connected = true,
  bool alive = true,
  bool known = true,
  Map<String, dynamic> status = idleStatus,
  Map<String, dynamic> active = const {},
}) => sprayerCommandBlockReason(
  command: command,
  connected: connected,
  heartbeatAlive: alive,
  status: status,
  activeCommand: active,
  commandStateKnown: known,
);

Future<void> main() async {
  await edge(
    'Duplicate normal and stop requests do not get a second reservation',
    () {
      final coordinator = CommandSubmissionCoordinator();
      coordinator.begin('A', isStop: false);
      expectStateError(() => coordinator.begin('A', isStop: false));
      coordinator.begin('A', isStop: true);
      expectStateError(() => coordinator.begin('A', isStop: true));
    },
  );
  await edge(
    'A stop supersedes a start that is still checking prerequisites',
    () {
      final coordinator = CommandSubmissionCoordinator();
      final start = coordinator.begin('A', isStop: false);
      final stop = coordinator.begin('A', isStop: true);
      expectStateError(() => coordinator.requireCurrent(start));
      coordinator.requireCurrent(stop);
    },
  );
  await edge('A failed stop does not permanently lock future submissions', () {
    final coordinator = CommandSubmissionCoordinator();
    final old = coordinator.begin('A', isStop: false);
    final stop = coordinator.begin('A', isStop: true);
    coordinator.complete(stop);
    expectStateError(() => coordinator.requireCurrent(old));
    coordinator.complete(old);
    coordinator.requireCurrent(coordinator.begin('A', isStop: false));
  });
  await edge(
    'A stale completion cannot release a newer command reservation',
    () {
      final coordinator = CommandSubmissionCoordinator();
      final old = coordinator.begin('A', isStop: false);
      coordinator.complete(old);
      coordinator.begin('A', isStop: false);
      coordinator.complete(old);
      expectStateError(() => coordinator.begin('A', isStop: false));
    },
  );
  await edge(
    'Logout invalidates a pending operation even if the same account returns',
    () {
      final coordinator = CommandSubmissionCoordinator();
      final old = coordinator.begin('A', isStop: false);
      coordinator.invalidateSession();
      expectStateError(() => coordinator.requireCurrent(old));
      coordinator.complete(old);
      coordinator.requireCurrent(coordinator.begin('A', isStop: false));
    },
  );
  await edge(
    'A stop on one device cannot cancel another device submission',
    () {
      final coordinator = CommandSubmissionCoordinator();
      final other = coordinator.begin('B', isStop: false);
      coordinator.begin('A', isStop: true);
      coordinator.requireCurrent(other);
    },
  );
  await edge('A cached first heartbeat cannot establish liveness', () {
    expect(
      !isDeviceHeartbeatAlive(heartbeat(500), deviceId: 'A'),
      'Cached heartbeat enabled controls.',
    );
  });
  await edge('Expired A cannot be revived by advancing B', () async {
    const timeout = Duration(milliseconds: 5);
    isDeviceHeartbeatAlive(heartbeat(500), deviceId: 'A', timeout: timeout);
    expect(
      isDeviceHeartbeatAlive(heartbeat(501), deviceId: 'A', timeout: timeout),
      'Advancing heartbeat precondition failed.',
    );
    await Future<void>.delayed(const Duration(milliseconds: 25));
    isDeviceHeartbeatAlive(heartbeat(900), deviceId: 'B');
    isDeviceHeartbeatAlive(heartbeat(901), deviceId: 'B');
    expect(
      !isDeviceHeartbeatAlive(heartbeat(501), deviceId: 'A', timeout: timeout),
      'B revived the expired heartbeat of A.',
    );
  });
  await edge('Repeated snapshots cannot refresh a timeout', () async {
    const timeout = Duration(milliseconds: 5);
    isDeviceHeartbeatAlive(heartbeat(50), deviceId: 'A', timeout: timeout);
    isDeviceHeartbeatAlive(heartbeat(51), deviceId: 'A', timeout: timeout);
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(
      !isDeviceHeartbeatAlive(heartbeat(51), deviceId: 'A', timeout: timeout),
      'Rebuilding with cached data refreshed the heartbeat.',
    );
  });
  await edge('Reboot/backward heartbeat requires another advance', () {
    isDeviceHeartbeatAlive(heartbeat(500), deviceId: 'A');
    isDeviceHeartbeatAlive(heartbeat(501), deviceId: 'A');
    expect(
      !isDeviceHeartbeatAlive(heartbeat(5), deviceId: 'A'),
      'Backward heartbeat was immediately trusted.',
    );
    expect(
      !isDeviceHeartbeatAlive(heartbeat(5), deviceId: 'A'),
      'Repeated reboot snapshot was trusted.',
    );
  });
  await edge('Offline transition clears previously observed liveness', () {
    isDeviceHeartbeatAlive(heartbeat(500), deviceId: 'A');
    isDeviceHeartbeatAlive(heartbeat(501), deviceId: 'A');
    isDeviceHeartbeatAlive({
      'online': false,
      'lastHeartbeat': 501,
    }, deviceId: 'A');
    expect(
      !isDeviceHeartbeatAlive(heartbeat(501), deviceId: 'A'),
      'Reconnect reused stale liveness.',
    );
  });
  for (final value in [-1, double.nan, double.infinity, 'NaN', null, 1.5]) {
    await edge('Invalid heartbeat $value cannot enable controls', () {
      expect(
        !isDeviceHeartbeatAlive({
          'online': true,
          'lastHeartbeat': value,
        }, deviceId: 'A'),
        'Invalid heartbeat enabled controls.',
      );
    });
  }
  await edge('Logout reset prevents reuse of a previous session heartbeat', () {
    isDeviceHeartbeatAlive(heartbeat(500), deviceId: 'A');
    isDeviceHeartbeatAlive(heartbeat(501), deviceId: 'A');
    resetDeviceHeartbeatTracker();
    expect(
      !isDeviceHeartbeatAlive(heartbeat(501), deviceId: 'A'),
      'Previous session liveness survived reset.',
    );
  });
  await edge('Uptime is never formatted as a 1970 wall-clock time', () {
    expect(
      formatHeartbeatValue(60000) == 'Device uptime: 0h 1m',
      'Device uptime was rendered as a calendar time.',
    );
  });

  for (final value in [
    'NaN',
    'Infinity',
    double.nan,
    double.infinity,
    true,
    {},
  ]) {
    await edge('Non-numeric/non-finite reading $value is unavailable', () {
      expect(
        readRtdbDouble({'sensor': value}, 'sensor') == null,
        'Invalid sensor value was accepted.',
      );
    });
  }
  for (final value in [double.infinity, double.nan, 1.5, 1e20]) {
    await edge('Invalid integer $value is rejected without throwing', () {
      expect(
        readRtdbInt({'timestamp': value}, 'timestamp') == null,
        'Invalid integer was accepted.',
      );
    });
  }
  for (final value in [1e20, double.infinity, 'NaN', -1, 12345]) {
    await edge('Invalid calendar timestamp $value becomes unavailable', () {
      expect(
        readRtdbDateTime(value).millisecondsSinceEpoch == 0,
        'Invalid timestamp was treated as a calendar date.',
      );
    });
  }
  await edge('Calendar upper boundary does not overflow', () {
    expect(
      readRtdbDateTime(maxCalendarEpochMs).millisecondsSinceEpoch ==
          maxCalendarEpochMs,
      'Maximum supported epoch was rejected.',
    );
    expect(
      readRtdbDateTime(maxCalendarEpochMs + 1).millisecondsSinceEpoch == 0,
      'Epoch beyond the supported range was accepted.',
    );
  });
  await edge('Malformed snapshot roots do not cause a cast error', () {
    expect(
      readRtdbMap(['unexpected']).isEmpty,
      'List was treated as an object.',
    );
    expect(
      readRtdbMap({0: 'unexpected'}).isEmpty,
      'Non-string key was accepted.',
    );
  });
  for (final value in ['NaN', double.infinity, -1, 101]) {
    await edge('Invalid humidity $value cannot crash or appear available', () {
      final mapped = IotDataModel.fromRealtimeData(
        {'humidity': value, 'humidityAvailable': true},
        {'riskLevel': 'HIGH', 'riskScore': 12},
      );
      expect(!mapped.hasHumidity, 'Invalid humidity was marked available.');
    });
  }
  await edge('Numeric string risk score is parsed consistently', () {
    final model = IotDataModel.fromRealtimeData({}, {
      'riskLevel': 'HIGH',
      'riskScore': '12',
    });
    expect(
      model.prediction.riskScore == 12 && model.prediction.hasValidRisk,
      'Numeric string score broke model parsing.',
    );
  });
  await edge('Partial prediction cannot produce reassuring LOW risk', () {
    final model = PredictionEngineModel.fromMap({'smartInsight': 'pending'});
    expect(
      model.riskLevel == 'UNKNOWN' && !model.hasValidRisk,
      'Missing risk data was reported as LOW.',
    );
  });
  for (final value in [-1, 19, 12.5, 'NaN', null]) {
    await edge('Invalid risk score $value cannot be presented as measured', () {
      final model = PredictionEngineModel.fromMap({
        'riskLevel': 'HIGH',
        'riskScore': value,
      });
      expect(!model.hasValidRisk, 'Invalid risk was accepted.');
    });
  }
  await edge('Zero and maximum risk-score boundaries remain valid', () {
    expect(
      PredictionEngineModel.fromMap({'riskLevel': 'LOW', 'riskScore': 0})
          .hasValidRisk,
      'Measured zero risk was confused with missing data.',
    );
    expect(
      PredictionEngineModel.fromMap({'riskLevel': 'VERY HIGH', 'riskScore': 18})
          .hasValidRisk,
      'Maximum valid risk was rejected.',
    );
  });
  await edge('Null breakdown fields are not measured zeroes', () {
    final model = PredictionEngineModel.fromMap({
      'riskLevel': 'HIGH',
      'riskScore': 12,
      'temperatureScore': null,
      'humidityScore': null,
      'wetnessStatusScore': null,
      'wetnessDurationScore': null,
      'persistenceScore': null,
    });
    expect(
      !model.hasScoreBreakdown,
      'Null components formed a complete breakdown.',
    );
  });
  await edge('Malformed reason-list entries cannot cause type errors', () {
    final model = PredictionEngineModel.fromMap({
      'riskLevel': 'HIGH',
      'riskScore': 12,
      'reasons': ['Wet leaves', null, 7],
    });
    expect(model.reasons.length == 1, 'Invalid reason entries were retained.');
  });

  for (final state in ['PENDING', 'ACK_RECEIVED', 'RUNNING', 'UNRECOGNIZED']) {
    await edge('Active command state $state blocks another start', () {
      expect(
        blocked(active: {'status': state}) != null,
        'A second command could overwrite the current command.',
      );
    });
  }
  await edge('Missing command status is fail-closed', () {
    expect(
      blocked(active: {'command': 'START_SPRAY'}) != null,
      'Unknown command state enabled a start.',
    );
  });
  await edge('Initial command stream loading cannot enable controls', () {
    expect(
      blocked(known: false) != null,
      'Loading command state enabled controls.',
    );
  });
  await edge(
    'Cooldown activated during a safety dialog blocks confirmation',
    () {
      expect(
        blocked(status: {...idleStatus, 'cooldownActive': true}) != null,
        'Changed cooldown was not enforced.',
      );
    },
  );
  await edge(
    'Emergency activated during a safety dialog blocks confirmation',
    () {
      expect(
        blocked(status: {...idleStatus, 'esp32Status': 'EMERGENCY_STOP'}) !=
            null,
        'Changed emergency state was not enforced.',
      );
    },
  );
  await edge('Offline app cannot queue a start or stop', () {
    expect(blocked(connected: false) != null, 'Offline start was allowed.');
    expect(
      blocked(command: 'EMERGENCY_STOP', connected: false) != null,
      'Offline stop was presented as deliverable.',
    );
  });
  await edge('An expired farm heartbeat blocks starting', () {
    expect(
      blocked(alive: false) != null,
      'Expired heartbeat enabled controls.',
    );
  });
  for (final status in [
    <String, dynamic>{},
    {'esp32Status': 'ONLINE'},
    {...idleStatus, 'pumpStatus': 'UNKNOWN'},
    {...idleStatus, 'cooldownActive': null},
  ]) {
    await edge('Incomplete safety state $status cannot enable a start', () {
      expect(
        blocked(status: status) != null,
        'Incomplete safety state enabled controls.',
      );
    });
  }
  await edge('Emergency stop remains available without normal telemetry', () {
    expect(
      blocked(
            command: 'EMERGENCY_STOP',
            alive: false,
            status: {},
            known: false,
            active: {'status': 'RUNNING'},
          ) ==
          null,
      'Normal safety gates prevented emergency stop.',
    );
  });
  await edge('Reset is blocked outside an emergency stop', () {
    expect(
      blocked(command: 'RESET_SYSTEM') != null,
      'Reset was available during normal operation.',
    );
  });
  for (final duration in [-1, 0, 29, 61, '30']) {
    await edge('Invalid spray duration $duration is rejected', () {
      expectArgumentError(
        () => validateSprayerCommand({
          'command': 'START_SPRAY',
          'trigger': 'MANUAL',
          'cycles': 1,
          'durationSec': duration,
        }),
      );
    });
  }
  for (final cycles in [0, 3, 1.5, '1']) {
    await edge('Invalid spray cycle count $cycles is rejected', () {
      expectArgumentError(
        () => validateSprayerCommand({
          'command': 'START_SPRAY',
          'trigger': 'MANUAL',
          'cycles': cycles,
          'durationSec': 30,
        }),
      );
    });
  }
  await edge('Unsupported command and excessive test spray are rejected', () {
    expectArgumentError(() => validateSprayerCommand({'command': 'UNKNOWN'}));
    expectArgumentError(
      () => validateSprayerCommand({
        'command': 'TEST_SPRAYER',
        'trigger': 'TEST',
        'cycles': 2,
        'durationSec': 30,
      }),
    );
  });
  await edge('Manual spray bounds accept both endpoint values', () {
    validateSprayerCommand({
      'command': 'START_SPRAY',
      'trigger': 'MANUAL',
      'cycles': 1,
      'durationSec': 30,
    });
    validateSprayerCommand({
      'command': 'START_SPRAY',
      'trigger': 'MANUAL',
      'cycles': 2,
      'durationSec': 60,
    });
  });

  await edge(
    'Signed-out and logging-out sessions cannot display private alerts',
    () {
      expect(
        notificationForSession(
              currentUid: null,
              suspended: false,
              data: {'recipientUid': 'A'},
              body: 'Private farm data',
            ) ==
            null,
        'Signed-out session displayed an alert.',
      );
      expect(
        notificationForSession(
              currentUid: 'A',
              suspended: true,
              data: {'recipientUid': 'A'},
              body: 'Private farm data',
            ) ==
            null,
        'Logging-out session displayed an alert.',
      );
    },
  );
  await edge('A delayed previous-account notification is dropped', () {
    expect(
      notificationForSession(
            currentUid: 'B',
            suspended: false,
            data: {'recipientUid': 'A'},
            body: 'Private farm data',
          ) ==
          null,
      'Previous-account data was displayed.',
    );
  });
  await edge('Unscoped legacy alerts cannot reveal private payloads', () {
    final result = notificationForSession(
      currentUid: 'B',
      suspended: false,
      data: {},
      title: 'Private farm name',
      body: 'Private farm data',
    );
    expect(
      result != null &&
          result.title != 'Private farm name' &&
          result.body != 'Private farm data',
      'Legacy notification leaked its payload.',
    );
  });

  stdout.writeln('RESULT: $checked edge cases, $failed failures.');
  exitCode = failed == 0 ? 0 : 1;
}
