import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'info_row.dart';

class DeviceInfoCard extends StatelessWidget {
  const DeviceInfoCard({super.key, required this.deviceId});

  final String deviceId;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assigned IoT Device',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            InfoRow(
              'Device ID',
              deviceId.isEmpty ? 'No device assigned' : deviceId,
            ),
            const InfoRow('Device Type', 'BananaDoctor Farm Device'),
          ],
        ),
      ),
    );
  }
}
