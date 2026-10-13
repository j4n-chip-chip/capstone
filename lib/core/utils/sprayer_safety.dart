import 'rtdb_value_parser.dart';

const busyCommandStatuses = {'PENDING', 'ACK_RECEIVED', 'RUNNING'};

bool hasBusyCommand(Map<String, dynamic> command) =>
    busyCommandStatuses.contains(readRtdbUpperString(command, 'status'));

String? sprayerCommandBlockReason({
  required String command,
  required bool connected,
  required bool heartbeatAlive,
  required Map<String, dynamic> status,
  required Map<String, dynamic> activeCommand,
  bool commandStateKnown = true,
}) {
  if (!connected)
    return 'The app is offline. Reconnect before sending a command.';
  if (!heartbeatAlive) return 'Waiting for a fresh farm-device heartbeat.';
  if (command == 'EMERGENCY_STOP') return null;
  if (!commandStateKnown) return 'The current command state is unavailable.';
  if (hasBusyCommand(activeCommand))
    return 'A sprayer command is already pending or running.';
  final activeState = readRtdbUpperString(activeCommand, 'status');
  if (activeCommand.isNotEmpty &&
      !const {
        'IDLE',
        'COMPLETED',
        'CANCELLED',
        'FAILED',
      }.contains(activeState)) {
    return 'The current command state is unavailable.';
  }
  final state = readRtdbUpperString(status, 'esp32Status');
  if (state == null ||
      const {'UNKNOWN', 'OFFLINE', 'ERROR', 'UNAVAILABLE'}.contains(state)) {
    return 'The farm-device status is unavailable.';
  }
  if (command == 'RESET_SYSTEM') {
    return state == 'EMERGENCY_STOP'
        ? null
        : 'Reset is available only during emergency stop.';
  }
  if (state == 'EMERGENCY_STOP')
    return 'Emergency stop is active. Reset the system first.';
  final cooldown = readRtdbBool(status, 'cooldownActive');
  if (cooldown == null) return 'The cooldown state is unavailable.';
  if (cooldown) return 'The sprayer cooldown is active.';
  final pump = readRtdbUpperString(status, 'pumpStatus');
  if (pump == 'ON' || pump == 'RUNNING')
    return 'The sprayer is already running.';
  if (pump != 'OFF' && pump != 'IDLE') return 'The pump is not ready.';
  return null;
}

void validateSprayerCommand(Map<String, dynamic> data) {
  final command = data['command'];
  if (!const {
    'START_SPRAY',
    'TEST_SPRAYER',
    'EMERGENCY_STOP',
    'RESET_SYSTEM',
  }.contains(command)) {
    throw ArgumentError('Unsupported sprayer command.');
  }
  if (command == 'START_SPRAY') {
    final cycles = data['cycles'];
    final seconds = data['durationSec'];
    if (data['trigger'] != 'MANUAL' ||
        cycles is! int ||
        cycles < 1 ||
        cycles > 2 ||
        seconds is! int ||
        seconds < 30 ||
        seconds > 60) {
      throw ArgumentError('Manual spray requires 1–2 cycles of 30–60 seconds.');
    }
  }
  if (command == 'TEST_SPRAYER' &&
      (data['trigger'] != 'TEST' ||
          data['cycles'] != 1 ||
          data['durationSec'] != 3)) {
    throw ArgumentError('A sprayer test must use one three-second cycle.');
  }
}
