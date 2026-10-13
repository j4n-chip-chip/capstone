class SessionNotification {
  const SessionNotification(this.title, this.body);
  final String title;
  final String body;
}

SessionNotification? notificationForSession({
  required String? currentUid,
  required bool suspended,
  required Map<String, dynamic> data,
  String? title,
  String? body,
}) {
  if (suspended || currentUid == null) return null;
  final recipient = data['recipientUid'];
  if (recipient is String && recipient.isNotEmpty) {
    if (recipient != currentUid) return null;
    return SessionNotification(
      title ?? data['title']?.toString() ?? 'BananaDoctor',
      body ?? data['body']?.toString() ?? 'A new farm update is available.',
    );
  }
  // Legacy senders do not identify the account. Preserve an alert without
  // displaying potentially private content from a previous account.
  return const SessionNotification(
    'BananaDoctor',
    'Open BananaDoctor to check your farm updates.',
  );
}
