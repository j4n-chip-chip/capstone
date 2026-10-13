import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dart:async';

import '../../core/constants/app_colors.dart';
import '../../core/services/realtime_database_service.dart';
import '../../core/utils/device_heartbeat.dart';
import '../../core/utils/rtdb_value_parser.dart';
import '../../core/utils/sprayer_safety.dart';

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

  late Stream<String?> authorizedDeviceIdStream;

  int cycles = 1;
  int durationSec = 45;
  String latestDeviceId = '';
  bool appConnected = false;
  bool commandStateKnown = false;
  bool commandInFlight = false;
  bool stopInFlight = false;
  bool settingsInFlight = false;
  Map<String, dynamic> latestStatusData = {};
  Map<String, dynamic> latestActiveCommand = {};

  String formatLastHeartbeat(Map<String, dynamic> data) =>
      formatHeartbeatValue(data['lastHeartbeat']);

  Future<void> submitCommand(String deviceId, Map<String, dynamic> data) async {
    final command = data['command'] as String;
    final stop = command == 'EMERGENCY_STOP';
    if ((stop && stopInFlight) || (!stop && commandInFlight)) return;
    final reason = sprayerCommandBlockReason(
      command: command,
      connected: appConnected,
      heartbeatAlive: isDeviceHeartbeatAlive(
        latestHeartbeatData,
        deviceId: deviceId,
      ),
      status: latestStatusData,
      activeCommand: latestActiveCommand,
      commandStateKnown: commandStateKnown,
    );
    if (reason != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(reason)));
      return;
    }
    setState(() {
      if (stop) {
        stopInFlight = true;
      } else {
        commandInFlight = true;
      }
    });
    try {
      await realtimeDatabaseService.sendCommand(
        deviceId: deviceId,
        commandData: data,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Command sent. Waiting for the farm device to confirm.',
            ),
          ),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is TimeoutException || error is StateError
                  ? error.toString()
                  : 'Unable to send the command. Check your connection and device access.',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
    } finally {
      if (mounted)
        setState(() {
          if (stop) {
            stopInFlight = false;
          } else {
            commandInFlight = false;
          }
        });
    }
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

  Future<void> resetSystem(String deviceId) => submitCommand(deviceId, {
    'command': 'RESET_SYSTEM',
    'trigger': 'MANUAL',
    'cycles': 0,
    'durationSec': 0,
  });

  Future<void> startManualSpray(String deviceId) => submitCommand(deviceId, {
    'command': 'START_SPRAY',
    'trigger': 'MANUAL',
    'cycles': cycles,
    'durationSec': durationSec,
  });

  Future<void> testSprayer(String deviceId) => submitCommand(deviceId, {
    'command': 'TEST_SPRAYER',
    'trigger': 'TEST',
    'cycles': 1,
    'durationSec': 3,
  });

  Future<void> confirmEmergencyStop(String deviceId) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Emergency Stop'),

          content: const Text(
            'Request an emergency stop. Check that the farm device confirms the stop before approaching the sprayer.',
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

                await submitCommand(deviceId, {
                  'command': 'EMERGENCY_STOP',
                  'trigger': 'MANUAL',
                });
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

    authorizedDeviceIdStream = user == null
        ? Stream.value(null)
        : realtimeDatabaseService.authorizedDeviceIdStream(user.uid);

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
    if (FirebaseAuth.instance.currentUser == null) {
      return const Scaffold(body: Center(child: Text('No user logged in.')));
    }
    return StreamBuilder<String?>(
      stream: authorizedDeviceIdStream,
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

        if (latestDeviceId != deviceId) {
          latestDeviceId = deviceId;
          latestHeartbeatData = {};
          latestStatusData = {};
          latestActiveCommand = {};
          commandStateKnown = false;
        }
        return StreamBuilder(
          stream: realtimeDatabaseService.connectionStream,
          builder: (context, connectionSnapshot) {
            appConnected =
                !connectionSnapshot.hasError &&
                connectionSnapshot.connectionState == ConnectionState.active &&
                connectionSnapshot.data?.snapshot.value == true;
            return StreamBuilder(
              stream: realtimeDatabaseService.heartbeatStream(deviceId),
              builder: (context, heartbeatSnapshot) {
                if (heartbeatSnapshot.hasError) {
                  latestHeartbeatData = {};
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

                if (heartbeatSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  latestHeartbeatData = {};
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final heartbeatData = readRtdbMap(
                  heartbeatSnapshot.data?.snapshot.value,
                );

                latestHeartbeatData =
                    heartbeatSnapshot.connectionState == ConnectionState.active
                    ? heartbeatData
                    : {};

                final deviceOnline = isDeviceHeartbeatAlive(
                  latestHeartbeatData,
                  deviceId: deviceId,
                );

                final lastHeartbeat = formatLastHeartbeat(heartbeatData);

                return Scaffold(
                  floatingActionButton: deviceOnline && appConnected
                      ? FloatingActionButton.extended(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          onPressed: stopInFlight
                              ? null
                              : () => confirmEmergencyStop(deviceId),
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Emergency Stop'),
                        )
                      : null,
                  body: StreamBuilder(
                    stream: realtimeDatabaseService.statusStream(deviceId),

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

                      if (statusSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final statusData = readRtdbMap(
                        statusSnapshot.data?.snapshot.value,
                      );
                      latestStatusData = statusData;

                      final cooldownActive =
                          statusData['cooldownActive'] == true;

                      final cooldownRemainingSec =
                          readRtdbInt(statusData, 'cooldownRemainingSec') ?? 0;

                      final esp32Status =
                          readRtdbUpperString(statusData, 'esp32Status') ??
                          'UNKNOWN';

                      final currentSprayCycle =
                          readRtdbInt(statusData, 'currentSprayCycle') ?? 0;

                      final totalSprayCycles =
                          readRtdbInt(statusData, 'totalSprayCycles') ?? 0;

                      final sprayCycleRemainingSec =
                          readRtdbInt(statusData, 'sprayCycleRemainingSec') ??
                          0;

                      final sprayTrigger =
                          (statusData['sprayTrigger'] ?? 'NONE')
                              .toString()
                              .toUpperCase();

                      return StreamBuilder(
                        stream: realtimeDatabaseService.settingsStream(
                          deviceId,
                        ),
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

                              final rawCommand =
                                  commandSnapshot.data?.snapshot.value;
                              commandStateKnown =
                                  commandSnapshot.hasData &&
                                  (rawCommand == null || rawCommand is Map);
                              final activeCommand = readRtdbMap(rawCommand);
                              latestActiveCommand = activeCommand;
                              final startBlocked =
                                  commandInFlight ||
                                  stopInFlight ||
                                  sprayerCommandBlockReason(
                                        command: 'START_SPRAY',
                                        connected: appConnected,
                                        heartbeatAlive: deviceOnline,
                                        status: statusData,
                                        activeCommand: activeCommand,
                                        commandStateKnown: commandStateKnown,
                                      ) !=
                                      null;
                              final isEmergencyStop =
                                  esp32Status == 'EMERGENCY_STOP';

                              final pumpStatus =
                                  (statusData['pumpStatus'] ?? 'OFF')
                                      .toString()
                                      .toUpperCase();

                              final isSpraying =
                                  pumpStatus == 'ON' || pumpStatus == 'RUNNING';

                              final commandStatus =
                                  readRtdbUpperString(
                                    activeCommand,
                                    'status',
                                  ) ??
                                  'IDLE';

                              final commandType =
                                  readRtdbUpperString(
                                    activeCommand,
                                    'command',
                                  ) ??
                                  'NONE';

                              final commandTrigger =
                                  (activeCommand['trigger'] ?? '')
                                      .toString()
                                      .toUpperCase();

                              final isStartSprayCommand =
                                  commandType == 'START_SPRAY';

                              final isManualCommand =
                                  isStartSprayCommand &&
                                  commandTrigger == 'MANUAL';

                              final isAutoCommand =
                                  isStartSprayCommand &&
                                  commandTrigger == 'AUTO';

                              final isTestCommand =
                                  commandType == 'TEST_SPRAYER';

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
                              final latestSprayerMessage =
                                  hasBusyCommand(activeCommand) && !isSpraying
                                  ? 'Waiting for the device to finish the current command.'
                                  : startBlocked && !isSpraying
                                  ? 'Sprayer controls are unavailable until the device is ready.'
                                  : isSpraying
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
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    100,
                                  ),
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
                                        deviceOnline:
                                            deviceOnline && appConnected,
                                        isUpdating: settingsInFlight,
                                        canEnable: !startBlocked,
                                        isEmergencyStop: isEmergencyStop,
                                        onChanged: (enabled) async {
                                          if (settingsInFlight) return;
                                          setState(
                                            () => settingsInFlight = true,
                                          );
                                          try {
                                            await realtimeDatabaseService
                                                .updateAutoMode(
                                                  deviceId: deviceId,
                                                  enabled: enabled,
                                                );
                                          } catch (_) {
                                            if (mounted)
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Unable to change Auto Mode. Check the device status and connection.',
                                                      ),
                                                    ),
                                                  );
                                          } finally {
                                            if (mounted)
                                              setState(
                                                () => settingsInFlight = false,
                                              );
                                          }
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
                                        isSpraying:
                                            isSpraying || isManualCommand,
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
                                        isLocked: startBlocked,
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

                                        onManualSpray: startBlocked
                                            ? null
                                            : () => showSafetyChecklistDialog(
                                                context,
                                                deviceId,
                                              ),

                                        onTestSprayer: startBlocked
                                            ? null
                                            : () => testSprayer(deviceId),

                                        onResetSystem:
                                            isEmergencyStop &&
                                                deviceOnline &&
                                                appConnected &&
                                                !commandInFlight &&
                                                !hasBusyCommand(activeCommand)
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
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
