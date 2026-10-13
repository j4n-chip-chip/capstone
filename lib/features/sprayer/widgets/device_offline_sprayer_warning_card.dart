import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class DeviceOfflineSprayerWarningCard extends StatelessWidget {
  const DeviceOfflineSprayerWarningCard({
    super.key,
    required this.lastHeartbeat,
  });

  final String lastHeartbeat;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.danger.withValues(alpha: 0.08),

      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.wifi_off, color: AppColors.danger),

                SizedBox(width: 10),

                Expanded(
                  child: Text(
                    'Farm Device Offline',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const Text(
              'Spraying controls are temporarily unavailable because the farm device is not responding. Check the device power and connection before trying again.',
              style: TextStyle(color: AppColors.textDark),
            ),

            const SizedBox(height: 12),

            Text(
              'Last heartbeat response: $lastHeartbeat',
              style: const TextStyle(color: AppColors.textLight, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
