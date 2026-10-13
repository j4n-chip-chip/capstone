import 'rtdb_value_parser.dart';

class DeviceHeartbeatTracker {
  int? _lastValue;
  bool _observedAdvance = false;
  final Stopwatch _elapsed = Stopwatch();

  bool observe(
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 60),
  }) {
    final beat = readRtdbInt(data, 'lastHeartbeat');
    if (data['online'] != true || beat == null || beat < 0) {
      reset();
      return false;
    }

    if (_lastValue == null || beat < _lastValue!) {
      // A cached initial value, reboot, or out-of-order value does not
      // prove liveness. Wait for an advancing heartbeat for this device.
      _lastValue = beat;
      _observedAdvance = false;
      _elapsed
        ..reset()
        ..stop();
      return false;
    }
    if (beat > _lastValue!) {
      _lastValue = beat;
      _observedAdvance = true;
      _elapsed
        ..reset()
        ..start();
    }
    return _observedAdvance && _elapsed.elapsed <= timeout;
  }

  void reset() {
    _lastValue = null;
    _observedAdvance = false;
    _elapsed
      ..reset()
      ..stop();
  }
}

final Map<String, DeviceHeartbeatTracker> _trackers = {};

bool isDeviceHeartbeatAlive(
  Map<String, dynamic> data, {
  required String deviceId,
  Duration timeout = const Duration(seconds: 60),
}) {
  if (deviceId.isEmpty) return false;
  return _trackers
      .putIfAbsent(deviceId, DeviceHeartbeatTracker.new)
      .observe(data, timeout: timeout);
}

void resetDeviceHeartbeatTracker({String? deviceId}) {
  if (deviceId == null) {
    _trackers.clear();
  } else {
    _trackers.remove(deviceId);
  }
}

String formatHeartbeatValue(Object? raw) {
  final beat = readRtdbInt({'beat': raw}, 'beat');
  if (beat == null || beat < 0) return 'Unavailable';
  if (beat < minWallClockEpochMs) {
    final uptime = Duration(milliseconds: beat);
    return 'Device uptime: ${uptime.inHours}h '
        '${uptime.inMinutes.remainder(60)}m';
  }
  final date = readRtdbDateTime(beat).toLocal();
  if (date.millisecondsSinceEpoch == 0) return 'Unavailable';
  return '${date.month}/${date.day}/${date.year} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}
