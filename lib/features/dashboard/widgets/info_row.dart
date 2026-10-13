import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class InfoRow extends StatelessWidget {
  const InfoRow(
      this.label,
      this.value, {super.key,});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Text('$label:', style: const TextStyle(color: AppColors.textLight)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}