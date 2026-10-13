import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class SystemStatusBanner extends StatelessWidget {
  const SystemStatusBanner({
    super.key,
    required this.esp32Status,
    required this.riskLevel,
    required this.isDeviceOffline,
  });

  final String esp32Status;
  final String riskLevel;
  final bool isDeviceOffline;

  @override
  Widget build(BuildContext context) {
    late Color bannerColor;
    late IconData bannerIcon;
    late String title;
    late String subtitle;

    final normalizedStatus = esp32Status.trim().toUpperCase();
    final normalizedRiskLevel = riskLevel.trim().toUpperCase();

    if (isDeviceOffline) {
      bannerColor = AppColors.danger;
      bannerIcon = Icons.wifi_off;
      title = 'Device Offline';
      subtitle =
          'The farm device is not responding. Live monitoring and spraying controls are temporarily unavailable.';
    } else if (normalizedStatus == 'EMERGENCY_STOP') {
      bannerColor = AppColors.danger;
      bannerIcon = Icons.warning_amber_rounded;
      title = 'Emergency Stop Active';
      subtitle = 'Spraying operations are locked until the system is reset.';
    } else if (normalizedRiskLevel == 'VERY HIGH' ||
        normalizedRiskLevel == 'HIGH') {
      bannerColor = AppColors.warning;
      bannerIcon = Icons.crisis_alert;
      title = 'High Disease Risk Detected';
      subtitle =
          'Current farm conditions indicate a high risk of Black Sigatoka. Check the recommended action before spraying.';
    } else {
      bannerColor = AppColors.primaryGreen;
      bannerIcon = Icons.check_circle_outline;
      title = 'Farm Monitoring Active';
      subtitle =
          'The farm device is connected and BananaDoctor is monitoring current field conditions.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bannerColor.withValues(alpha: 0.35)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(bannerIcon, color: bannerColor, size: 30),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: bannerColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  style: TextStyle(color: AppColors.textDark, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
