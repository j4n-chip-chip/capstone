import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/farmer_profile_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/realtime_database_service.dart';

import 'widgets/profile_header.dart';
import 'widgets/device_info_card.dart';
import 'widgets/settings_card.dart';
import 'widgets/system_info_card.dart';
import 'widgets/risk_guide_item.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onLogout,
  });

  final VoidCallback onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<String?> authorizedDeviceIdFuture;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    authorizedDeviceIdFuture = user == null
        ? Future.value(null)
        : realtimeDatabaseService.getAuthorizedDeviceId(user.uid);
  }

  void showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature will be available soon.'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  Future<void> showChangePasswordDialog(BuildContext context) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submitChangePassword() async {
              final currentPassword =
              currentPasswordController.text.trim();

              final newPassword =
              newPasswordController.text.trim();

              final confirmPassword =
              confirmPasswordController.text.trim();

              if (currentPassword.isEmpty ||
                  newPassword.isEmpty ||
                  confirmPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please complete all password fields.',
                    ),
                    backgroundColor: AppColors.danger,
                  ),
                );
                return;
              }

              if (newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'New password must be at least 6 characters.',
                    ),
                    backgroundColor: AppColors.danger,
                  ),
                );
                return;
              }

              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'New password and confirmation do not match.',
                    ),
                    backgroundColor: AppColors.danger,
                  ),
                );
                return;
              }

              try {
                final user = FirebaseAuth.instance.currentUser;

                if (user == null || user.email == null) {
                  throw FirebaseAuthException(
                    code: 'no-user',
                    message: 'No authenticated user found.',
                  );
                }

                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: currentPassword,
                );

                await user.reauthenticateWithCredential(
                  credential,
                );

                await user.updatePassword(newPassword);

                if (!context.mounted) return;

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Password updated successfully.',
                    ),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
              } on FirebaseAuthException catch (e) {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.message ?? 'Failed to update password.',
                    ),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Change Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        prefixIcon:
                        const Icon(Icons.lock_outline),
                        hintText: 'Current password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrent
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureCurrent =
                              !obscureCurrent;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        prefixIcon:
                        const Icon(Icons.lock_reset),
                        hintText: 'New password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureNew = !obscureNew;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.verified_user_outlined,
                        ),
                        hintText: 'Confirm new password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureConfirm =
                              !obscureConfirm;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitChangePassword,
                  child: const Text('Update Password'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      currentPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  }

  void showRiskGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Risk Level Guide'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RiskGuideItem(
                  level: 'LOW (0–5)',
                  color: AppColors.lowRisk,
                  description:
                  'Current conditions are not favorable for Black Sigatoka development.',
                  action:
                  'No spraying needed. Continue monitoring.',
                ),

                SizedBox(height: 12),

                RiskGuideItem(
                  level: 'MODERATE (6–10)',
                  color: AppColors.moderateRisk,
                  description:
                  'Humidity is increasing or conditions may become favorable.',
                  action:
                  'Monitor closely. No automatic spraying yet.',
                ),

                SizedBox(height: 12),

                RiskGuideItem(
                  level: 'HIGH (11–15)',
                  color: AppColors.highRisk,
                  description:
                  'Conditions are favorable for Black Sigatoka development.',
                  action:
                  'Preventive spraying may activate if Auto Mode is enabled.',
                ),

                SizedBox(height: 12),

                RiskGuideItem(
                  level: 'VERY HIGH (16–18)',
                  color: AppColors.veryHighRisk,
                  description:
                  'Critical conditions detected: high humidity, suitable temperature, and long leaf wetness duration.',
                  action:
                  'Automatic preventive spraying is strongly recommended.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to logout from BananaDoctor?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onLogout();
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('No user logged in.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: firestoreService.userStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Failed to load profile.'),
            );
          }

          if (!snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data!.data()!;

          final farmer =
          FarmerProfileModel.fromMap(data);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProfileHeader(
                farmer: farmer,
              ),

              const SizedBox(height: 16),

              FutureBuilder<String?>(
                future: authorizedDeviceIdFuture,
                builder: (context, deviceSnapshot) {
                  if (deviceSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (deviceSnapshot.hasError) {
                    return const Text(
                      'Unable to verify assigned device.',
                      textAlign: TextAlign.center,
                    );
                  }

                  final deviceId =
                      deviceSnapshot.data ?? '';

                  return DeviceInfoCard(
                    deviceId: deviceId,
                  );
                },
              ),

              const SizedBox(height: 16),

              SettingsCard(
                onChangePassword: () =>
                    showChangePasswordDialog(context),
                onRiskGuide: () =>
                    showRiskGuideDialog(context),
              ),

              const SizedBox(height: 16),

              SystemInfoCard(),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () =>
                    confirmLogout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          );
        },
      ),
    );
  }
}