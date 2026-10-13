import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import 'info_row.dart';

class SystemInfoCard extends StatelessWidget {
  const SystemInfoCard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Application Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            InfoRow('App Name', AppStrings.appName),
            InfoRow('Version', '1.0.0'),
            InfoRow('System Type', 'IoT Risk Prediction'),
            InfoRow('User Role', AppStrings.farmerRole),
          ],
        ),
      ),
    );
  }
}