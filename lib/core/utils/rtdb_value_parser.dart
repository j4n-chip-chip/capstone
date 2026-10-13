const maxExactRtdbInteger = 9007199254740991;
const maxCalendarEpochMs = 8640000000000000;
const minWallClockEpochMs = 1000000000000;

Map<String, dynamic> readRtdbMap(Object? value) {
  if (value is! Map) return {};
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

double? readRtdbDouble(Map<String, dynamic> value, String key) {
  final raw = value[key];
  final number = raw is num
      ? raw.toDouble()
      : raw is String
      ? double.tryParse(raw)
      : null;
  return number != null && number.isFinite ? number : null;
}

int? readRtdbInt(Map<String, dynamic> value, String key) {
  final number = readRtdbDouble(value, key);
  if (number == null ||
      number.abs() > maxExactRtdbInteger ||
      number != number.truncateToDouble())
    return null;
  return number.toInt();
}

bool? readRtdbBool(Map<String, dynamic> value, String key) {
  final raw = value[key];
  if (raw is bool) return raw;
  if (raw is String) {
    switch (raw.trim().toLowerCase()) {
      case 'true':
        return true;
      case 'false':
        return false;
    }
  }
  return null;
}

String readRtdbString(
  Map<String, dynamic> value,
  String key, {
  String fallback = '',
}) {
  return value[key] is String ? value[key] as String : fallback;
}

String? readRtdbUpperString(Map<String, dynamic> value, String key) {
  final text = readRtdbString(value, key).trim().toUpperCase();
  return text.isEmpty ? null : text;
}

DateTime readRtdbDateTime(Object? raw) {
  if (raw is DateTime) return raw;
  final epoch = readRtdbInt({'epoch': raw}, 'epoch');
  // ESP32 millis() is uptime, not a calendar date.
  if (epoch == null ||
      epoch < minWallClockEpochMs ||
      epoch > maxCalendarEpochMs) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(epoch);
}
