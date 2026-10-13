import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/services/realtime_database_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/constants/app_colors.dart';
import '../dashboard/dashboard_screen.dart';
import '../history/history_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../sprayer/sprayer_control_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AlertNavIcon extends StatelessWidget {
  const _AlertNavIcon({required this.deviceId, required this.selected});

  final String deviceId;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (deviceId.isEmpty) {
      return Icon(
        selected ? Icons.notifications : Icons.notifications_outlined,
        color: selected ? AppColors.primaryGreen : null,
      );
    }

    return StreamBuilder(
      stream: realtimeDatabaseService.alertsStream(deviceId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Icon(
            selected ? Icons.notifications : Icons.notifications_outlined,
            color: selected ? AppColors.primaryGreen : null,
          );
        }

        int unreadCount = 0;

        final rawValue = snapshot.data?.snapshot.value;

        if (rawValue is Map) {
          final alerts = Map<String, dynamic>.from(rawValue);

          unreadCount = alerts.values.where((value) {
            if (value is! Map) return false;

            final alert = Map<String, dynamic>.from(value);

            return alert['isRead'] != true;
          }).length;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              selected ? Icons.notifications : Icons.notifications_outlined,
              color: selected ? AppColors.primaryGreen : null,
            ),
            if (unreadCount > 0)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AppShellState extends State<AppShell> {
  int currentIndex = 0;

  late Stream<DocumentSnapshot<Map<String, dynamic>>> userProfileStream;

  late Future<String?> authorizedDeviceIdFuture;

  late final List<Widget> screens = [
    const DashboardScreen(),
    const SprayerControlScreen(),
    const HistoryScreen(),
    const NotificationsScreen(),
    ProfileScreen(onLogout: widget.onLogout),
  ];

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    authorizedDeviceIdFuture = user == null
        ? Future.value(null)
        : realtimeDatabaseService.getAuthorizedDeviceId(user.uid);

    if (user != null) {
      userProfileStream = firestoreService.userStream(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user logged in.')));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userProfileStream,
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load your account information. '
                  'Check your internet connection and try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Your farmer profile could not be found.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return FutureBuilder<String?>(
          future: authorizedDeviceIdFuture,
          builder: (context, deviceSnapshot) {
            if (deviceSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (deviceSnapshot.hasError) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Unable to verify your assigned device.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final deviceId = deviceSnapshot.data ?? '';

            return Scaffold(
              body: IndexedStack(index: currentIndex, children: screens),
              bottomNavigationBar: NavigationBar(
                selectedIndex: currentIndex,
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                backgroundColor: Colors.white,
                indicatorColor: AppColors.lightGreen,
                onDestinationSelected: (index) {
                  setState(() {
                    currentIndex = index;
                  });
                },
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(
                      Icons.dashboard,
                      color: AppColors.primaryGreen,
                    ),
                    label: 'Dashboard',
                  ),

                  const NavigationDestination(
                    icon: Icon(Icons.water_drop_outlined),
                    selectedIcon: Icon(
                      Icons.water_drop,
                      color: AppColors.primaryGreen,
                    ),
                    label: 'Sprayer',
                  ),

                  const NavigationDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(
                      Icons.history,
                      color: AppColors.primaryGreen,
                    ),
                    label: 'Logs',
                  ),

                  NavigationDestination(
                    icon: _AlertNavIcon(deviceId: deviceId, selected: false),
                    selectedIcon: _AlertNavIcon(
                      deviceId: deviceId,
                      selected: true,
                    ),
                    label: 'Alerts',
                  ),

                  const NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(
                      Icons.person,
                      color: AppColors.primaryGreen,
                    ),
                    label: 'Profile',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
