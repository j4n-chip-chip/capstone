import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class DashboardErrorState extends StatelessWidget {
  const DashboardErrorState({super.key,required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 56,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Unable to Load Dashboard',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The app could not load sensor or device data. Please check the connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textLight, height: 1.4),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}