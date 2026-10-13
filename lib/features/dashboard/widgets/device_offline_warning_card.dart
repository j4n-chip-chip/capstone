import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class DeviceOfflineWarningCard extends StatelessWidget {
  const DeviceOfflineWarningCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.danger.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.wifi_off, color: AppColors.danger, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${AppStrings.deviceOffline}\n'
                'The farm device is not sending sensor data. Live monitoring and spraying controls are temporarily unavailable until the device reconnects.',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
