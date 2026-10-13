import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../core/services/firestore_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/realtime_database_service.dart';
import '../../core/utils/device_heartbeat.dart';

import 'widgets/sprayer_status_card.dart';
import 'widgets/spray_settings_card.dart';
import 'widgets/sprayer_activity_timeline.dart';
import 'widgets/command_history_timeline.dart';
import 'widgets/action_buttons.dart';
import 'widgets/cooldown_card.dart';
import 'widgets/auto_mode_control_card.dart';
import 'widgets/device_safety_card.dart';
import 'widgets/active_command_card.dart';
import 'widgets/device_offline_sprayer_warning_card.dart';

class SprayerControlScreen extends StatefulWidget {
  const SprayerControlScreen({super.key});

  @override
  State<SprayerControlScreen> createState() => _SprayerControlScreenState();
}

class _SprayerControlScreenState extends State<SprayerControlScreen> {
  Timer? heartbeatCheckTimer;
  Map<String, dynamic> latestHeartbeatData = {};

  late Future<String?> authorizedDeviceIdFuture;

  int cycles = 1;
  int durationSec = 45;
  bool safetyChecklistCompleted = false;

  String formatLastHeartbeat(Map<String, dynamic> heartbeatData) {
    final lastHeartbeat = heartbeatData['lastHeartbeat'];

    if (lastHeartbeat is! num) {
      return 'Unavailable';
    }

    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      lastHeartbeat.toInt(),
    ).toLocal();

    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return 'Last heartbeat: $hour:$minute $period';
  }

  bool canSendSprayerCommand() {
    return isDeviceHeartbeatAlive(latestHeartbeatData);
  }

  void showOfflineCommandBlockedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Command cancelled. The farm device is offline.'),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  void showSafetyChecklistDialog(BuildContext context, String deviceId) {
    bool tankFilled = false;
    bool noPeopleNearby = false;
    bool pumpChecked = false;
    bool correctMixture = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Safety Checklist'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Confirm all safety conditions before starting manual spray.',
                    ),

                    const SizedBox(height: 12),

                    CheckboxListTile(
                      value: tankFilled,
                      activeColor: AppColors.primaryGreen,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tank is filled with fungicide'),
                      onChanged: (value) {
                        setDialogState(() {
                          tankFilled = value ?? false;
                        });
                      },
                    ),

                    CheckboxListTile(
                      value: noPeopleNearby,
                      activeColor: AppColors.primaryGreen,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('No people near sprayer area'),
                      onChanged: (value) {
                        setDialogState(() {
                          noPeopleNearby = value ?? false;
                        });
                      },
                    ),

                    CheckboxListTile(
                      value: pumpChecked,
                      activeColor: AppColors.primaryGreen,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pump and relay have been checked'),
                      onChanged: (value) {
                        setDialogState(() {
                          pumpChecked = value ?? false;
                        });
                      },
                    ),

                    CheckboxListTile(
                      value: correctMixture,
                      activeColor: AppColors.primaryGreen,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Correct chemical mixture prepared'),
                      onChanged: (value) {
                        setDialogState(() {
                          correctMixture = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () {
                    final allChecked =
                        tankFilled &&
                            noPeopleNearby &&
                            pumpChecked &&
                            correctMixture;

                    if (!allChecked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Complete safety checklist before starting sprayer.',
                          ),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context);

                    startManualSpray(deviceId);
                  },
                  child: const Text('Start Spray'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> resetSystem(String deviceId) async {
    if (!isDeviceHeartbeatAlive(latestHeartbeatData)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Command cancelled. The farm device is offline.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    await realtimeDatabaseService.sendCommand(
      deviceId: deviceId,
      commandData: {
        'command': 'RESET_SYSTEM',
        'trigger': 'manual',
        'cycles': 0,
        'durationSec': 0,
      },
    );
  }

  Future<void> startManualSpray(String deviceId) async {
    if (!canSendSprayerCommand()) {
      showOfflineCommandBlockedMessage();
      return;
    }

    await realtimeDatabaseService.sendCommand(
      deviceId: deviceId,
      commandData: {
        'command': 'START_SPRAY',
        'trigger': 'MANUAL',
        'cycles': cycles,
        'durationSec': durationSec,
      },
    );
  }

  Future<void> testSprayer(String deviceId) async {
    if (!isDeviceHeartbeatAlive(latestHeartbeatData)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Command cancelled. The farm device is offline.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    await realtimeDatabaseService.sendCommand(
      deviceId: deviceId,
      commandData: {
        'command': 'TEST_SPRAYER',
        'trigger': 'TEST',
        'cycles': 1,
        'durationSec': 3,
      },
    );
  }

  Future<void> confirmEmergencyStop(String deviceId) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Emergency Stop'),

          content: const Text(
            'This will immediately stop the pump and override all spraying operations.',
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),

              onPressed: () async {
                Navigator.pop(context);

                await realtimeDatabaseService.sendCommand(
                  deviceId: deviceId,
                  commandData: {
                    'command': 'EMERGENCY_STOP',
                    'trigger': 'MANUAL',
                  },
                );
              },

              child: const Text('Stop Now'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    authorizedDeviceIdFuture = user == null
        ? Future.value(null)
        : realtimeDatabaseService.getAuthorizedDeviceId(user.uid);

    heartbeatCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    heartbeatCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user logged in.')));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firestoreService.userStream(user.uid),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load your account information. '
                      'Check your internet connection and try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return FutureBuilder<String?>(
          future: authorizedDeviceIdFuture,
          builder: (context, deviceSnapshot) {
            if (deviceSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (deviceSnapshot.hasError) {
              return const Scaffold(
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Unable to verify your assigned device.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            final deviceId = deviceSnapshot.data ?? '';

            if (deviceId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'No authorized BananaDoctor device is assigned to this account.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return StreamBuilder(
              stream: realtimeDatabaseService.heartbeatStream(deviceId),
              builder: (context, heartbeatSnapshot) {
                if (heartbeatSnapshot.hasError) {
                  return const Scaffold(
                    body: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Unable to check the farm device connection. '
                              'Check your internet connection and try again.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }

                if (!heartbeatSnapshot.hasData ||
                    heartbeatSnapshot.data!.snapshot.value == null) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final heartbeatData = Map<String, dynamic>.from(
                  heartbeatSnapshot.data!.snapshot.value as Map,
                );

                latestHeartbeatData = heartbeatData;

                final deviceOnline = isDeviceHeartbeatAlive(heartbeatData);

                final lastHeartbeat = formatLastHeartbeat(heartbeatData);

                return StreamBuilder(
                  stream: realtimeDatabaseService.statusRef(deviceId).onValue,

                  builder: (context, statusSnapshot) {
                    if (statusSnapshot.hasError) {
                      return const Scaffold(
                        body: Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Unable to load the farm device status. '
                                  'Check your internet connection and try again.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }

                    if (!statusSnapshot.hasData ||
                        statusSnapshot.data!.snapshot.value == null) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final statusData = Map<String, dynamic>.from(
                      statusSnapshot.data!.snapshot.value as Map,
                    );

                    final cooldownActive = statusData['cooldownActive'] == true;

                    final cooldownRemainingSec =
                        statusData['cooldownRemainingSec'] ?? 0;

                    final esp32Status = statusData['esp32Status'] ?? 'UNKNOWN';

                    final currentSprayCycle =
                        (statusData['currentSprayCycle'] as num?)?.toInt() ?? 0;

                    final totalSprayCycles =
                        (statusData['totalSprayCycles'] as num?)?.toInt() ?? 0;

                    final sprayCycleRemainingSec =
                        (statusData['sprayCycleRemainingSec'] as num?)
                            ?.toInt() ??
                            0;

                    final sprayTrigger = (statusData['sprayTrigger'] ?? 'NONE')
                        .toString()
                        .toUpperCase();

                    return StreamBuilder(
                      stream: realtimeDatabaseService.settingsStream(deviceId),
                      builder: (context, settingsSnapshot) {
                        if (settingsSnapshot.hasError) {
                          return const Scaffold(
                            body: Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Unable to load sprayer settings. '
                                      'Check your internet connection and try again.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                        }

                        if (!settingsSnapshot.hasData) {
                          return const Scaffold(
                            body: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final settingsData =
                            settingsSnapshot.data?.snapshot.value;

                        final settings = settingsData is Map
                            ? Map<String, dynamic>.from(settingsData)
                            : <String, dynamic>{};

                        final autoMode = settings['autoMode'] == true;

                        return StreamBuilder(
                          stream: realtimeDatabaseService.activeCommandStream(
                            deviceId,
                          ),

                          builder: (context, commandSnapshot) {
                            if (commandSnapshot.hasError) {
                              return const Scaffold(
                                body: Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'Unable to check the current sprayer command. '
                                          'For safety, sprayer controls are temporarily unavailable.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              );
                            }

                            Map<String, dynamic>? activeCommand;

                            if (commandSnapshot.hasData &&
                                commandSnapshot.data!.snapshot.value != null) {
                              activeCommand = Map<String, dynamic>.from(
                                commandSnapshot.data!.snapshot.value as Map,
                              );
                            }
                            final isEmergencyStop =
                                esp32Status == 'EMERGENCY_STOP';

                            final pumpStatus =
                            (statusData['pumpStatus'] ?? 'OFF')
                                .toString()
                                .toUpperCase();

                            final isSpraying =
                                pumpStatus == 'ON' || pumpStatus == 'RUNNING';

                            final commandStatus =
                                activeCommand?['status'] ?? 'IDLE';

                            final commandType =
                                activeCommand?['command'] ?? 'NONE';

                            final commandTrigger =
                            (activeCommand?['trigger'] ?? '')
                                .toString()
                                .toUpperCase();

                            final isStartSprayCommand =
                                commandType == 'START_SPRAY';

                            final isManualCommand =
                                isStartSprayCommand &&
                                    commandTrigger == 'MANUAL';

                            final isAutoCommand =
                                isStartSprayCommand && commandTrigger == 'AUTO';

                            final isTestCommand = commandType == 'TEST_SPRAYER';

                            final triggerType = isSpraying
                                ? sprayTrigger == 'AUTO'
                                ? 'Automatic Spray'
                                : sprayTrigger == 'TEST'
                                ? 'Test Sprayer'
                                : sprayTrigger == 'MANUAL'
                                ? 'Manual Spray'
                                : 'Spraying'
                                : isTestCommand
                                ? 'Test Sprayer'
                                : isAutoCommand
                                ? 'Automatic Spray'
                                : isManualCommand
                                ? 'Manual Spray'
                                : 'None';
                            final latestSprayerMessage = isSpraying
                                ? 'Sprayer is currently running.'
                                : cooldownActive
                                ? 'Cooldown active. Sprayer is temporarily locked.'
                                : commandStatus == 'CANCELLED'
                                ? 'Last command was cancelled.'
                                : commandStatus == 'COMPLETED'
                                ? 'Last command completed successfully.'
                                : 'Sprayer is idle and ready.';

                            final displayCycle = isSpraying
                                ? currentSprayCycle
                                : 0;

                            final displayTotalCycles = isSpraying
                                ? totalSprayCycles
                                : 0;

                            final displayRemainingSec = isSpraying
                                ? sprayCycleRemainingSec
                                : 0;
                            return Scaffold(
                              appBar: AppBar(
                                title: const Text('Sprayer Control'),
                              ),
                              body: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    if (!deviceOnline) ...[
                                      DeviceOfflineSprayerWarningCard(
                                        lastHeartbeat: lastHeartbeat,
                                      ),

                                      const SizedBox(height: 16),
                                    ],

                                    AutoModeControlCard(
                                      autoMode: autoMode,
                                      deviceOnline: deviceOnline,
                                      isEmergencyStop: isEmergencyStop,
                                      onChanged: (enabled) async {
                                        await realtimeDatabaseService
                                            .updateAutoMode(
                                          deviceId: deviceId,
                                          enabled: enabled,
                                        );
                                      },
                                    ),

                                    const SizedBox(height: 16),

                                    DeviceSafetyCard(
                                      isEmergencyStop: isEmergencyStop,
                                      esp32Status: esp32Status,
                                      deviceOnline: deviceOnline,
                                      lastHeartbeat: lastHeartbeat,
                                    ),

                                    if (cooldownActive) ...[
                                      const SizedBox(height: 16),

                                      CooldownCard(
                                        remainingSec: cooldownRemainingSec,
                                      ),
                                    ],

                                    const SizedBox(height: 16),

                                    SprayerStatusCard(
                                      statusText: isEmergencyStop
                                          ? 'Emergency stopped'
                                          : isSpraying
                                          ? 'Sprayer running'
                                          : cooldownActive
                                          ? 'Cooldown active'
                                          : commandStatus == 'COMPLETED'
                                          ? 'Spraying completed'
                                          : 'Sprayer idle',

                                      statusColor: isEmergencyStop
                                          ? AppColors.danger
                                          : isSpraying
                                          ? AppColors.primaryGreen
                                          : cooldownActive
                                          ? AppColors.warning
                                          : commandStatus == 'COMPLETED'
                                          ? AppColors.lowRisk
                                          : AppColors.textLight,
                                      isSpraying: isSpraying || isManualCommand,
                                      currentCycle: displayCycle,
                                      totalCycles: displayTotalCycles,
                                      remainingSec: displayRemainingSec,
                                      triggerType: triggerType,
                                      latestMessage: latestSprayerMessage,
                                    ),

                                    const SizedBox(height: 16),

                                    SpraySettingsCard(
                                      cycles: cycles,
                                      durationSec: durationSec,
                                      isLocked: isSpraying,
                                      onCyclesChanged: (value) {
                                        setState(() {
                                          cycles = value;
                                        });
                                      },
                                      onDurationChanged: (value) {
                                        setState(() {
                                          durationSec = value;
                                        });
                                      },
                                    ),

                                    const SizedBox(height: 16),

                                    ActionButtons(
                                      isSpraying: isSpraying,
                                      cooldownActive: cooldownActive,
                                      isEmergencyStop: isEmergencyStop,

                                      onManualSpray:
                                      isEmergencyStop ||
                                          !deviceOnline ||
                                          cooldownActive ||
                                          isSpraying
                                          ? null
                                          : () => showSafetyChecklistDialog(
                                        context,
                                        deviceId,
                                      ),

                                      onTestSprayer:
                                      isEmergencyStop ||
                                          !deviceOnline ||
                                          cooldownActive ||
                                          isSpraying
                                          ? null
                                          : () => testSprayer(deviceId),

                                      onStop: () =>
                                          confirmEmergencyStop(deviceId),

                                      onResetSystem:
                                      isEmergencyStop && deviceOnline
                                          ? () => resetSystem(deviceId)
                                          : null,
                                    ),

                                    if (commandType != 'NONE') ...[
                                      const SizedBox(height: 16),

                                      ActiveCommandCard(
                                        commandType: commandType,
                                        commandStatus: commandStatus,
                                      ),

                                      const SizedBox(height: 16),

                                      SprayerActivityTimeline(
                                        deviceId: deviceId,
                                      ),
                                    ],

                                    const SizedBox(height: 16),

                                    ExpansionTile(
                                      tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      title: const Text(
                                        'Advanced Details',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      subtitle: const Text(
                                        'View technical command history and system state.',
                                        style: TextStyle(
                                          color: AppColors.textLight,
                                        ),
                                      ),
                                      children: [
                                        CommandHistoryTimeline(
                                          deviceId: deviceId,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
