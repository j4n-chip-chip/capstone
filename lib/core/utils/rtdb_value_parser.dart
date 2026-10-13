double? readRtdbDouble(Map<String, dynamic> value, String key) {
  final raw = value[key];

  if (raw is num) {
    return raw.toDouble();
  }

  return double.tryParse(raw?.toString() ?? '');
}

int? readRtdbInt(Map<String, dynamic> value, String key) {
  final raw = value[key];

  if (raw is num) {
    return raw.toInt();
  }

  return int.tryParse(raw?.toString() ?? '');
}

String? readRtdbUpperString(Map<String, dynamic> value, String key) {
  final raw = value[key];

  final text = raw?.toString().trim().toUpperCase();

  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}
