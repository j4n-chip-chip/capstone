import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class AutoModeControlCard extends StatelessWidget {
  const AutoModeControlCard({
    super.key,
    required this.autoMode,
    required this.deviceOnline,
    required this.isEmergencyStop,
    required this.onChanged,
  });

  final bool autoMode;
  final bool deviceOnline;
  final bool isEmergencyStop;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final canChangeMode = deviceOnline && !isEmergencyStop;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              autoMode ? Icons.auto_mode : Icons.pan_tool_alt_outlined,
              color: autoMode ? AppColors.primaryGreen : AppColors.textLight,
              size: 30,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    autoMode ? 'Auto Mode Enabled' : 'Manual Mode Active',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    autoMode
                        ? 'The system can automatically trigger preventive spraying when high-risk conditions are detected.'
                        : 'Automatic spraying is disabled. The farmer controls the sprayer manually.',
                    style: const TextStyle(
                      color: AppColors.textLight,
                      height: 1.4,
                    ),
                  ),

                  if (!deviceOnline || isEmergencyStop) ...[
                    const SizedBox(height: 8),
                    Text(
                      !deviceOnline
                          ? 'Auto mode cannot be changed while the farm device is offline.'
                          : 'Auto mode cannot be changed during emergency stop.',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Switch(
              value: autoMode,
              onChanged: canChangeMode ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
