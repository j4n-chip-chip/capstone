import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class SliderBlock extends StatelessWidget {
  const SliderBlock({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label),
            const Spacer(),
            Text(
              valueLabel,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppColors.primaryGreen,
          onChanged: onChanged,
        ),
      ],
    );
  }
}