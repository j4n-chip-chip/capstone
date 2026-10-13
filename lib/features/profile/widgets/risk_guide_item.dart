import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class RiskGuideItem extends StatelessWidget {
  const RiskGuideItem({
    super.key,
    required this.level,
    required this.color,
    required this.description,
    required this.action,
  });

  final String level;
  final Color color;
  final String description;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            level,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: AppColors.textDark, height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            'Action: $action',
            style: const TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
