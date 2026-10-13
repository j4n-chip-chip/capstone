int? _lastHeartbeatValue;
DateTime? _lastHeartbeatReceivedAt;

bool isDeviceHeartbeatAlive(
    Map<String, dynamic> heartbeatData, {
      Duration timeout = const Duration(seconds: 60),
    }) {
  final online = heartbeatData['online'] == true;
  final heartbeat = heartbeatData['lastHeartbeat'];

  if (!online || heartbeat is! num) {
    return false;
  }

  final heartbeatValue = heartbeat.toInt();
  final now = DateTime.now();

  // First heartbeat seen by the app.
  if (_lastHeartbeatValue == null) {
    _lastHeartbeatValue = heartbeatValue;
    _lastHeartbeatReceivedAt = now;
    return true;
  }

  // Firebase received a new heartbeat from the ESP32.
  if (heartbeatValue != _lastHeartbeatValue) {
    _lastHeartbeatValue = heartbeatValue;
    _lastHeartbeatReceivedAt = now;
  }

  if (_lastHeartbeatReceivedAt == null) {
    return false;
  }

  // Use LOCAL elapsed time since the app actually observed
  // a new heartbeat. Do not compare the phone clock directly
  // against Firebase server timestamps.
  final elapsed = now.difference(_lastHeartbeatReceivedAt!);

  return elapsed <= timeout;
}

void resetDeviceHeartbeatTracker() {
  _lastHeartbeatValue = null;
  _lastHeartbeatReceivedAt = null;
}