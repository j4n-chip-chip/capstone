import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/realtime_database_service.dart';

class SprayerActivityTimeline extends StatelessWidget {
  SprayerActivityTimeline({
    super.key,
    required this.deviceId});

  final String deviceId;

  final RealtimeDatabaseService realtimeDatabaseService =
  RealtimeDatabaseService();

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

  String triggerLabel(String trigger) {
    switch (trigger) {
      case 'AUTO':
        return 'Automatic';
      case 'MANUAL':
        return 'Manual';
      case 'TEST':
        return 'Test';
      case 'SYSTEM':
        return 'System';
      default:
        return trigger.replaceAll('_', ' ');
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

        final raw = Map<String, dynamic>.from(
          snapshot.data!.snapshot.value as Map,
        );

        final entries = raw.entries.toList()
          ..sort((a, b) {
            final aTime = a.value['createdAt'] ?? 0;
            final bTime = b.value['createdAt'] ?? 0;
            return bTime.compareTo(aTime);
          });

        final latest = entries.take(5).toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sprayer Activity Timeline',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),

                ...latest.map((entry) {
                  final data = Map<String, dynamic>.from(entry.value);
                  final command = data['command'] ?? 'UNKNOWN';
                  final status = data['status'] ?? 'PENDING';
                  final trigger = data['trigger'] ?? 'SYSTEM';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          status == 'COMPLETED'
                              ? Icons.check_circle
                              : status == 'FAILED'
                              ? Icons.error
                              : Icons.sync,
                          color: status == 'COMPLETED'
                              ? AppColors.primaryGreen
                              : status == 'FAILED'
                              ? AppColors.danger
                              : AppColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${triggerLabel(trigger)} • ${commandLabel(command)} • ${statusLabel(status)}',
                            softWrap: true,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
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
