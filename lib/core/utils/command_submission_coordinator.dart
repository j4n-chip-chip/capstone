// Coordinates requests from this app process. Backend arbitration and firmware
// expiry are still required to protect requests from separate clients.
class CommandSubmission {
  CommandSubmission(
    this.deviceId,
    this.isStop,
    this.stopGeneration,
    this.session,
  );
  final String deviceId;
  final bool isStop;
  final int stopGeneration;
  final int session;
}

class CommandSubmissionCoordinator {
  final Map<String, CommandSubmission> _normal = {};
  final Map<String, CommandSubmission> _stops = {};
  final Map<String, int> _stopGenerations = {};
  int _session = 0;

  CommandSubmission begin(String deviceId, {required bool isStop}) {
    if (_stops.containsKey(deviceId) ||
        (!isStop && _normal.containsKey(deviceId))) {
      throw StateError('A command is already being submitted for this device.');
    }
    var generation = _stopGenerations[deviceId] ?? 0;
    if (isStop) _stopGenerations[deviceId] = ++generation;
    final submission = CommandSubmission(
      deviceId,
      isStop,
      generation,
      _session,
    );
    (isStop ? _stops : _normal)[deviceId] = submission;
    return submission;
  }

  void requireCurrent(CommandSubmission submission) {
    if (submission.session != _session) {
      throw StateError(
        'Your account session changed. Submit the command again.',
      );
    }
    if (submission.stopGeneration !=
        (_stopGenerations[submission.deviceId] ?? 0)) {
      throw StateError('An emergency stop superseded this command.');
    }
  }

  void complete(CommandSubmission submission) {
    final pending = submission.isStop ? _stops : _normal;
    if (identical(pending[submission.deviceId], submission)) {
      pending.remove(submission.deviceId);
    }
  }

  void invalidateSession() => _session++;
}
