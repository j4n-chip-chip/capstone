import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class AutoModeControlCard extends StatelessWidget {
  const AutoModeControlCard({
    super.key,
    required this.autoMode,
    required this.deviceOnline,
    required this.isEmergencyStop,
    required this.onChanged,
    this.isUpdating = false,
    this.canEnable = true,
  });

  final bool autoMode;
  final bool deviceOnline;
  final bool isEmergencyStop;
  final bool isUpdating;
  final bool canEnable;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final canChangeMode =
        deviceOnline &&
        !isUpdating &&
        (autoMode || (canEnable && !isEmergencyStop));
    final blockedReason = isUpdating
        ? 'Saving Auto Mode...'
        : !deviceOnline
        ? 'Auto mode cannot be changed while the farm device is offline.'
        : !autoMode && isEmergencyStop
        ? 'Auto mode cannot be enabled during emergency stop.'
        : !autoMode && !canEnable
        ? 'Auto Mode can be enabled when the device is idle and ready.'
        : null;

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

                  if (blockedReason != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      blockedReason,
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
