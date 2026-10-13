import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ActiveCommandCard extends StatelessWidget {
  const ActiveCommandCard({
    super.key,
    required this.commandType,
    required this.commandStatus,
  });

  final String commandType;
  final String commandStatus;

  String _commandLabel(String command) {
    switch (command) {
      case 'START_SPRAY':
        return 'Start Spraying';
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

  @override
  Widget build(BuildContext context) {
    final isCompleted = commandStatus == 'COMPLETED';
    final isFailed = commandStatus == 'FAILED';
    final isRunning = commandStatus == 'RUNNING';
    final isPending = commandStatus == 'PENDING';
    final isAck = commandStatus == 'ACK_RECEIVED';

    final color = isCompleted
        ? AppColors.primaryGreen
        : isFailed
        ? AppColors.danger
        : AppColors.warning;

    final icon = isCompleted
        ? Icons.check_circle_outline
        : isFailed
        ? Icons.error_outline
        : Icons.sync;

    final statusText = isPending
        ? 'Waiting for device response'
        : isAck
        ? 'Command received by device'
        : isRunning
        ? 'Sprayer operation in progress'
        : isCompleted
        ? 'Operation completed'
        : isFailed
        ? 'Operation failed'
        : commandStatus.replaceAll('_', ' ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),

            const SizedBox(height: 10),

            const Text(
              'Active Command',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              _commandLabel(commandType),
              softWrap: true,
              style: const TextStyle(color: AppColors.textLight),
            ),

            const SizedBox(height: 6),

            Text(
              statusText,
              softWrap: true,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
