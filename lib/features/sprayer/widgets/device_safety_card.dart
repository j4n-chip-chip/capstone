import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'status_row.dart';

class DeviceSafetyCard extends StatelessWidget {
  const DeviceSafetyCard({
    super.key,
    required this.isEmergencyStop,
    required this.esp32Status,
    required this.deviceOnline,
    required this.lastHeartbeat,
  });

  final bool isEmergencyStop;
  final String esp32Status;
  final bool deviceOnline;
  final dynamic lastHeartbeat;

  String get connectionText {
    return deviceOnline ? 'Connected' : 'Offline';
  }

  String get safeStateText {
    if (!deviceOnline) {
      return 'Device offline. Sprayer controls are disabled.';
    }

    if (isEmergencyStop) {
      return 'Emergency stop is active. Reset is required before spraying.';
    }

    return 'System ready. Manual and test controls are available.';
  }

  String formatStatus(String value) {
    if (value.isEmpty) return value;

    return value
        .toLowerCase()
        .split('_')
        .map(
          (word) =>
              word.isEmpty ? word : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final connectionOk = deviceOnline;
    final emergencyOk = !isEmergencyStop;
    final esp32Ok = deviceOnline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Safety Pre-Check',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 12),

            StatusRow('Farm Device Connection', connectionText, connectionOk),

            StatusRow(
              'Device State',
              deviceOnline ? formatStatus(esp32Status) : 'Offline',
              esp32Ok,
            ),

            StatusRow(
              'Emergency Stop',
              isEmergencyStop ? 'Emergency Active' : 'Clear',
              emergencyOk,
            ),
            const Divider(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  deviceOnline && !isEmergencyStop
                      ? Icons.verified_user_outlined
                      : Icons.warning_amber_rounded,
                  color: deviceOnline && !isEmergencyStop
                      ? AppColors.primaryGreen
                      : AppColors.danger,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    safeStateText,
                    style: TextStyle(
                      color: deviceOnline && !isEmergencyStop
                          ? AppColors.primaryGreen
                          : AppColors.danger,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
