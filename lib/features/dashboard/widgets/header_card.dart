import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class HeaderCard extends StatelessWidget {
  const HeaderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primaryGreen,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, Farmer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Black Sigatoka risk monitoring is active',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
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