import 'package:flutter/material.dart';
import 'settings_tile.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.onChangePassword,
    required this.onRiskGuide,
  });

  final VoidCallback onChangePassword;
  final VoidCallback onRiskGuide;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          SettingsTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update account password',
            onTap: onChangePassword,
          ),
          const Divider(height: 1),
          SettingsTile(
            icon: Icons.help_outline,
            title: 'Risk Level Guide',
            subtitle: 'Understand LOW, MODERATE, HIGH, VERY HIGH',
            onTap: onRiskGuide,
          ),
        ],
      ),
    );
  }
}
