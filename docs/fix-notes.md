# BananaDoctor source fixes

The changes preserve the existing command names, payload fields, device paths,
and `user_fcm_tokens/$uid/current` sender contract. They update the uploaded
Flutter source; they do not deploy Firebase rules, backend functions, or ESP32
firmware.

Implemented changes:

- Heartbeat tracking is isolated by device and reset on logout. An initial
  cached value, a reboot, or an invalid heartbeat cannot establish liveness;
  controls wait for an advancing heartbeat. Elapsed time uses a monotonic clock.
  ESP32 uptime is displayed as uptime rather than a 1970 calendar time.
- Command submissions reject invalid durations/cycle counts, pending work,
  unavailable safety state, cooldown, and emergency state. The service rereads
  account assignment and device state before publishing. Local duplicate starts
  are blocked, and command history plus `active_command` are published in one
  atomic update. The Emergency Stop button is hidden when the app is disconnected
  or the device heartbeat is unavailable, offline, or expired. Confirming a dialog
  after connectivity is lost is blocked too. With a live device connection,
  emergency stop remains available when normal sprayer telemetry fails.
- Client-side deletion of command, alert, and sensor history is removed.
  Command views explicitly request the latest 50 commands. Unread alerts remain
  available; no arbitrary alert limit hides old unread warnings.
- Telemetry parsing rejects non-finite numbers, invalid humidity, invalid
  scores, and out-of-range dates. Missing risk data is `UNKNOWN`, and the risk
  card displays an unavailable score rather than reassuring `LOW / 0` data.
  Valid zero scores remain distinguishable from missing data.
- Device assignment is observed continuously. Cached stream wrappers create
  an independent Firebase subscription for every listener, including remounted
  tabs and one-shot connection checks. Stable wrapper identities avoid
  subscription churn during timer rebuilds. Environmental history is ordered by
  timestamp before selecting the latest 20 records.
- Logout has a bounded token-cleanup wait. Foreground alerts are suppressed
  during logout, delayed messages for another account are dropped, and unscoped
  legacy messages display generic content. Conditional token removal preserves
  another installation's current token. Existing local notifications are cleared.
- Registration dialog handling follows the dialog lifecycle rather than its
  disposed login screen. Submissions cannot be duplicated or dismissed while
  pending. Password changes preserve spaces and disable overlapping requests.
  Navigation and toolbar logout remain available when profile loading fails.
- Research timing runs only for an active, resumed Alerts tab and a card within
  its viewport. Measurements are persisted with a transaction that checks the
  trial ID and preserves the first measurement.

Run the production-logic regression checks with the Dart SDK:

```sh
dart test/edge_cases.dart
dart test/stream_edge_cases.dart
```

Run widget regressions after restoring the original Flutter project manifest,
lockfile, and its `flutter_test` SDK development dependency:

```sh
flutter pub get
flutter analyze
flutter test test/widget_edge_cases_test.dart
```

The upload currently omits `pubspec.yaml`, `pubspec.lock`, platform projects,
backend functions, database security rules, and ESP32 firmware. Source analysis
and widget checks in an inferred-manifest validation project cannot certify the
original application's dependency versions, native configuration, backend
permissions, or physical sprayer behavior.

Checks executed for this change: 82 standalone logic edge cases and 10 stream
edge cases passed with Dart 3.13.5; source/test analysis reported no issues and
nine widget edge cases passed with Flutter 3.44.0 / Dart 3.12.0 in a separate
project with inferred dependencies.
That validation resolved firebase_core 4.15.0, firebase_auth 6.7.0,
cloud_firestore 6.10.0, firebase_database 12.6.0, firebase_messaging 16.7.0,
flutter_local_notifications 22.3.2, shared_preferences 2.5.6, and fl_chart 1.2.0.
No production Firebase endpoint or physical sprayer was exercised.

### 🚨 [Bug Severity: High] - Cached streams crash with multiple screen listeners

* **The Problem:** The previous fix cached raw Firebase streams. Native database
  streams can accept only one subscription, while the app shell and its screens
  all listen to the cached assignment, alert, and command streams. Subsequent
  listeners throw `Bad state: Stream has already been listened to`.
* **The Impact:** Multiple screens fail to render. Reopening a view or checking
  the connection before a command can also attempt to reuse a consumed stream.
* **The Fix:** Cache `streamForEachListener(() => query.onValue)` in
  `RealtimeDatabaseService` and
  `streamForEachListener(() => users.doc(userId).snapshots())` in
  `FirestoreService`. The helper calls the Firebase getter separately for each
  subscription, forwards data/errors/completion, and cancels only that listener's
  source. Each listener receives Firebase's initial snapshot without waiting for
  another write. Stream and widget regressions cover simultaneous listeners,
  remounts, connection checks, independent cancellation, and error recovery.

### 🚨 [Bug Severity: High] - Cross-client command arbitration remains unresolved
* **The Problem:** Client validation and atomic publication cannot serialize two
  separate phones. A Firebase write may remain queued after a timeout; a client
  timeout does not cancel it.
* **The Impact:** Another client can replace the active command, and an old
  command can arrive after connectivity returns. Local guards do not establish
  reliable emergency-stop priority across clients.
* **The Fix:** Add a trusted command submission endpoint. Verify authenticated
  membership against `user_devices/$uid/$deviceId`, validate allowed command
  parameters, and transactionally check authoritative device freshness,
  cooldown, pump state, and pending/running work. Deduplicate an immutable
  request ID, set a server-issued execution deadline, and have firmware reject
  expired or repeated commands. Emergency stop must set a separate persistent
  latch that ordinary starts cannot clear; an explicit acknowledged reset clears
  it. Restrict direct client writes with Firebase rules. Preserve this protocol
  jointly in the sender, database rules, and firmware.

### 🚨 [Bug Severity: High] - System-rendered background notifications need a sender migration
* **The Problem:** The app can gate foreground display, but the operating system
  renders FCM notification payloads in the background without running that gate.
  One `$uid/current` token also cannot represent multiple installations.
* **The Impact:** Delayed background payloads may expose a previous account's
  information, and simultaneous phone registrations can overwrite one another.
* **The Fix:** Migrate the sender and rules to
  `user_fcm_tokens/$uid/installations/$installationId`. Bind each installation
  to its active account, revoke its prior binding on logout/account change, and
  send data-only messages with `recipientUid`. Implement an authenticated,
  account-scoped background display handler before switching the sender to
  data-only messages. The current background handler initializes Firebase only.

### 🚨 [Bug Severity: Medium] - Retention requires a trusted backend policy
* **The Problem:** Removing destructive client pruning preserves pending work
  and unread warnings, but no backend retention implementation was uploaded.
* **The Impact:** History storage can grow without a documented archival policy.
* **The Fix:** Add a scheduled backend job that archives eligible data and keeps
  all unread alerts, nonterminal commands, and the active command. Prune only
  archived, read/terminal records, rechecking eligibility before deletion.
  Merge `.indexOn: ["createdAt"]` for commands and `.indexOn: ["timestamp"]`
  for sensor/prediction history into existing rules without replacing their
  authorization policy. Add pagination and an authoritative unread aggregate
  before limiting alert reads.

### 🚨 [Bug Severity: Medium] - Research latency needs synchronized clocks
* **The Problem:** The latency formula subtracts an ESP32-generated epoch from
  the phone's display epoch. Viewport gating fixes false visibility, but cannot
  correct an unknown difference between those clocks.
* **The Impact:** Stored measurements can include clock offset rather than
  exclusively measuring risk-to-alert delivery.
* **The Fix:** Generate the risk timestamp in an authoritative time domain and
  calibrate the display clock against that domain, recording the offset and
  uncertainty for each trial. Enforce membership, immutable trial metadata, and
  first-write measurement ownership in the backend rules/functions before using
  these values as final research results.
