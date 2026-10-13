import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/farmer_profile_model.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.farmer});

  final FarmerProfileModel farmer;

  @override
  Widget build(BuildContext context) {
    final initial = farmer.name.isNotEmpty ? farmer.name[0].toUpperCase() : 'F';

    return Card(
      color: AppColors.primaryGreen,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    farmer.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    farmer.email,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  SizedBox(height: 4),
                  Text(
                    farmer.role,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}