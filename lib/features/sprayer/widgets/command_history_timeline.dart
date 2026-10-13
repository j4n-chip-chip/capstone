import '../../../core/utils/rtdb_value_parser.dart';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/realtime_database_service.dart';
import 'info_row.dart';

class CommandHistoryTimeline extends StatelessWidget {
  CommandHistoryTimeline({super.key, required this.deviceId});

  final String deviceId;

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: realtimeDatabaseService.commandHistoryStream(deviceId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const SizedBox.shrink();
        }

        final rawData = readRtdbMap(snapshot.data?.snapshot.value);

        final commands =
            rawData.entries.where((entry) => entry.value is Map).toList()
              ..sort((a, b) {
                final aTime =
                    readRtdbInt(readRtdbMap(a.value), 'createdAt') ?? 0;
                final bTime =
                    readRtdbInt(readRtdbMap(b.value), 'createdAt') ?? 0;
                return bTime.compareTo(aTime);
              });

        final recentCommands = commands.take(3).toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Commands',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),

                ...recentCommands.map((entry) {
                  final data = readRtdbMap(entry.value);
                  final command =
                      readRtdbUpperString(data, 'command') ?? 'UNKNOWN';
                  final status =
                      readRtdbUpperString(data, 'status') ?? 'UNKNOWN';
                  final result = data['result'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InfoRow(
                      commandLabel(command),
                      result.toString().isNotEmpty && result != 'WAITING'
                          ? '${statusLabel(status)} • $result'
                          : statusLabel(status),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
