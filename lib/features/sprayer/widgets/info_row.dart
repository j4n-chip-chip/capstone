import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            softWrap: true,
            style: const TextStyle(color: AppColors.textLight, fontSize: 13),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            softWrap: true,
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
