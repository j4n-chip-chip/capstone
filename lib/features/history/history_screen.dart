import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/realtime_database_service.dart';
import '../../core/utils/rtdb_value_parser.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

String commandLabel(String command) {
  switch (command) {
    case 'START_SPRAY':
      return 'Spray Command';
    case 'TEST_SPRAYER':
      return 'Sprayer Test';
    case 'EMERGENCY_STOP':
      return 'Emergency Stop';
    case 'RESET_SYSTEM':
      return 'System Reset';
    default:
      return command.replaceAll('_', ' ');
  }
}

String statusLabel(String status) {
  switch (status) {
    case 'PENDING':
      return 'Command Sent';
    case 'ACK_RECEIVED':
      return 'Device Responded';
    case 'RUNNING':
      return 'In Progress';
    case 'COMPLETED':
      return 'Completed';
    case 'CANCELLED':
      return 'Cancelled';
    case 'FAILED':
      return 'Failed';
    default:
      return status.replaceAll('_', ' ');
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String selectedFilter = 'All';

  late Stream<String?> authorizedDeviceIdStream;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    authorizedDeviceIdStream = user == null
        ? Stream.value(null)
        : realtimeDatabaseService.authorizedDeviceIdStream(user.uid);
  }

  String formatTime(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) {
      return 'Time unavailable';
    }

    return '${date.month}/${date.day}/${date.year} • '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  int countLogs(String filter, List<Map<String, dynamic>> logs) {
    if (filter == 'All') {
      return logs.length;
    }

    return logs.where((data) {
      final command = (data['command'] ?? '').toString().toUpperCase();
      final trigger = (data['trigger'] ?? '').toString().toUpperCase();

      if (filter == 'Manual') {
        return (command == 'START_SPRAY' && trigger == 'MANUAL') ||
            command == 'TEST_SPRAYER' ||
            trigger == 'TEST';
      }

      if (filter == 'Automatic') {
        return trigger == 'AUTO';
      }

      if (filter == 'Safety') {
        return command == 'EMERGENCY_STOP' || command == 'RESET_SYSTEM';
      }

      return false;
    }).length;
  }

  Color statusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return AppColors.lowRisk;

      case 'RUNNING':
      case 'ACK_RECEIVED':
        return AppColors.primaryGreen;

      case 'PENDING':
        return AppColors.warning;

      case 'CANCELLED':
      case 'FAILED':
        return AppColors.danger;

      default:
        return AppColors.textLight;
    }
  }

  IconData typeIcon(String trigger) {
    switch (trigger) {
      case 'MANUAL':
        return Icons.touch_app;

      case 'AUTO':
        return Icons.auto_mode;

      case 'TEST':
        return Icons.science_outlined;

      case 'SYSTEM':
        return Icons.settings;

      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user logged in.')));
    }

    final filters = ['All', 'Manual', 'Automatic', 'Safety'];

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

        return Scaffold(
          appBar: AppBar(title: const Text(AppStrings.logsTitle)),
          body: StreamBuilder(
            stream: realtimeDatabaseService.commandHistoryStream(deviceId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Unable to load command history. '
                      'Check your internet connection and try again.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final rawValue = snapshot.data!.snapshot.value;

              final logs = <Map<String, dynamic>>[];

              if (rawValue is Map) {
                final rawLogs = Map<String, dynamic>.from(rawValue);

                for (final entry in rawLogs.entries) {
                  if (entry.value is! Map) continue;

                  final data = Map<String, dynamic>.from(entry.value as Map);

                  logs.add(data);
                }
              }

              logs.sort((a, b) {
                final aTime = readRtdbInt(a, 'createdAt') ?? 0;
                final bTime = readRtdbInt(b, 'createdAt') ?? 0;

                return bTime.compareTo(aTime);
              });

              final filteredLogs = logs.where((data) {
                final command = (data['command'] ?? '')
                    .toString()
                    .toUpperCase();
                final trigger = (data['trigger'] ?? '')
                    .toString()
                    .toUpperCase();

                if (selectedFilter == 'All') {
                  return true;
                }

                if (selectedFilter == 'Manual') {
                  return (command == 'START_SPRAY' && trigger == 'MANUAL') ||
                      command == 'TEST_SPRAYER' ||
                      trigger == 'TEST';
                }

                if (selectedFilter == 'Automatic') {
                  return trigger == 'AUTO';
                }

                if (selectedFilter == 'Safety') {
                  return command == 'EMERGENCY_STOP' ||
                      command == 'RESET_SYSTEM';
                }

                return false;
              }).toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _SummaryCards(
                      total: logs.length,
                      automaticCount: logs.where((data) {
                        return (data['trigger'] ?? '')
                                .toString()
                                .toUpperCase() ==
                            'AUTO';
                      }).length,
                      sprayCount: logs.where((data) {
                        final command = (data['command'] ?? '').toString();

                        return command == 'START_SPRAY' ||
                            command == 'TEST_SPRAYER';
                      }).length,
                    ),
                  ),

                  SizedBox(
                    height: 46,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: filters.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final filter = filters[index];

                        final isSelected = selectedFilter == filter;

                        return ChoiceChip(
                          label: Text('$filter (${countLogs(filter, logs)})'),
                          selected: isSelected,
                          selectedColor: AppColors.lightGreen,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primaryGreen
                                : AppColors.textLight,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (_) {
                            setState(() {
                              selectedFilter = filter;
                            });
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: filteredLogs.isEmpty
                        ? const _EmptyLogsState()
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredLogs.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final log = filteredLogs[index];

                              final createdAtValue = log['createdAt'];

                              final createdAt = createdAtValue is Timestamp
                                  ? createdAtValue.toDate()
                                  : readRtdbDateTime(createdAtValue);

                              final command =
                                  readRtdbUpperString(log, 'command') ??
                                  'UNKNOWN';

                              final trigger =
                                  readRtdbUpperString(log, 'trigger') ??
                                  'SYSTEM';

                              final status =
                                  readRtdbUpperString(log, 'status') ??
                                  'UNKNOWN';

                              final errorMessage = (log['errorMessage'] ?? '')
                                  .toString()
                                  .trim();

                              final result = (log['result'] ?? '')
                                  .toString()
                                  .trim();

                              final details = errorMessage.isNotEmpty
                                  ? errorMessage
                                  : result.isNotEmpty && result != 'WAITING'
                                  ? result
                                  : 'No additional details.';

                              return _LogCard(
                                icon: typeIcon(trigger),
                                type: trigger,
                                title: commandLabel(command),
                                subtitle: details,
                                time: formatTime(createdAt),
                                status: statusLabel(status),
                                color: statusColor(status),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({
    required this.total,
    required this.automaticCount,
    required this.sprayCount,
  });

  final int total;
  final int automaticCount;
  final int sprayCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SummaryCard('Total Logs', '$total', Icons.history)),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            'Automatic Sprays',
            '$automaticCount',
            Icons.warning_amber_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard('Sprays', '$sprayCount', Icons.water_drop),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryGreen),
            const SizedBox(height: 8),

            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),

            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.icon,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.status,
    required this.color,
  });

  final IconData icon;
  final String type;
  final String title;
  final String subtitle;
  final String time;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Text(
          '$type • $time',
          style: const TextStyle(color: AppColors.textLight),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle,
                style: const TextStyle(color: AppColors.textLight, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLogsState extends StatelessWidget {
  const _EmptyLogsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 54, color: AppColors.textLight),
            const SizedBox(height: 12),

            const Text(
              AppStrings.noLogs,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Sprayer commands, automatic spray actions, emergency stops, and system reset actions will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
