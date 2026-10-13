import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class StatusRow extends StatelessWidget {
  const StatusRow(this.label, this.value, this.isOk, {
    super.key,
  });

  final String label;
  final String value;
  final bool isOk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.error,
            color: isOk ? AppColors.lowRisk : AppColors.danger,
            size: 20,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textDark),
            ),
          ),

          const SizedBox(width: 12),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              softWrap: true,
              overflow: TextOverflow.fade,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}