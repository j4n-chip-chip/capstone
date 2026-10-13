import 'package:flutter/material.dart';
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

  final Future<void> Function() onLogout;

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
  int _refreshGeneration = 0;
  late Stream<String?> authorizedDeviceIdStream;

  List<Widget> get screens => [
    DashboardScreen(key: ValueKey('dashboard/$_refreshGeneration')),
    SprayerControlScreen(key: ValueKey('sprayer/$_refreshGeneration')),
    HistoryScreen(key: ValueKey('history/$_refreshGeneration')),
    NotificationsScreen(
      key: ValueKey('alerts/$_refreshGeneration'),
      isVisible: currentIndex == 3,
    ),
    ProfileScreen(
      key: ValueKey('profile/$_refreshGeneration'),
      onLogout: widget.onLogout,
      onRefresh: refreshData,
    ),
  ];

  void _bindDevice() {
    final user = FirebaseAuth.instance.currentUser;
    authorizedDeviceIdStream = user == null
        ? Stream.value(null)
        : realtimeDatabaseService.authorizedDeviceIdStream(user.uid);
  }

  void refreshData() {
    realtimeDatabaseService.clearStreamCache();
    firestoreService.clearStreamCache();
    setState(() {
      _refreshGeneration++;
      _bindDevice();
    });
  }

  @override
  void initState() {
    super.initState();
    _bindDevice();
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Scaffold(body: Center(child: Text('No user logged in.')));
    }
    // Account/device errors must not hide navigation or the logout action.
    return StreamBuilder<String?>(
      stream: authorizedDeviceIdStream,
      builder: (context, deviceSnapshot) {
        final deviceId = deviceSnapshot.hasError
            ? ''
            : deviceSnapshot.data ?? '';
        return Scaffold(
          body: IndexedStack(index: currentIndex, children: screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentIndex,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
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
                selectedIcon: _AlertNavIcon(deviceId: deviceId, selected: true),
                label: 'Alerts',
              ),

              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person, color: AppColors.primaryGreen),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
