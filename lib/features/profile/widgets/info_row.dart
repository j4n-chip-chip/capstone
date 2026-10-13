import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key,});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(color: AppColors.textLight),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
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