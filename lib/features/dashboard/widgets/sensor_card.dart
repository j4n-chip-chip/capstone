import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class SensorCard extends StatelessWidget {
  const SensorCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primaryGreen),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(color: AppColors.textLight, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}