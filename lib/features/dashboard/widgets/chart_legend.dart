import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key,required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textLight, fontSize: 12),
        ),
      ],
    );
  }
}