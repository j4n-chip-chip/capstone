import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

enum DeviceStatusState {
  ok,
  warning,
  error,
}

class StatusRow extends StatelessWidget {
  const StatusRow(
      this.label,
      this.value,
      this.state, {
        super.key,
      });

  final String label;
  final String value;
  final DeviceStatusState state;

  @override
  Widget build(BuildContext context) {
    final icon = switch (state) {
      DeviceStatusState.ok => Icons.check_circle,
      DeviceStatusState.warning => Icons.warning_amber_rounded,
      DeviceStatusState.error => Icons.error,
    };

    final color = switch (state) {
      DeviceStatusState.ok => AppColors.lowRisk,
      DeviceStatusState.warning => AppColors.moderateRisk,
      DeviceStatusState.error => AppColors.danger,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}