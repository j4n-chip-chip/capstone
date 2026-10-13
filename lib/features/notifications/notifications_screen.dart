import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/alert_model.dart';
import '../../core/services/realtime_database_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.isVisible = true});

  final bool isVisible;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  bool _appResumed = true;
  late Stream<String?> authorizedDeviceIdStream;
  late final int rtaSessionStartedEpochMs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appResumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    rtaSessionStartedEpochMs = DateTime.now().millisecondsSinceEpoch;

    final user = FirebaseAuth.instance.currentUser;

    authorizedDeviceIdStream = user == null
        ? Stream.value(null)
        : realtimeDatabaseService.authorizedDeviceIdStream(user.uid);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted)
      setState(() => _appResumed = state == AppLifecycleState.resumed);
  }

  Color severityColor(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return AppColors.veryHighRisk;
      case 'WARNING':
        return AppColors.warning;
      case 'INFO':
      default:
        return AppColors.primaryGreen;
    }
  }

  IconData typeIcon(String type) {
    switch (type) {
      case 'RISK':
        return Icons.warning_amber_rounded;
      case 'SPRAY':
        return Icons.water_drop;
      case 'DEVICE':
        return Icons.memory;
      case 'REMINDER':
        return Icons.agriculture_outlined;
      case 'SYSTEM':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user logged in.')));
    }

    return StreamBuilder<String?>(
      stream: authorizedDeviceIdStream,
      builder: (context, deviceSnapshot) {
        if (deviceSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (deviceSnapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to verify your assigned device.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final deviceId = deviceSnapshot.data ?? '';

        if (deviceId.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text(AppStrings.notificationsTitle)),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No authorized BananaDoctor device is assigned to this account.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return StreamBuilder(
          stream: realtimeDatabaseService.alertsStream(deviceId),
          builder: (context, alertSnapshot) {
            if (alertSnapshot.hasError) {
              return const Scaffold(
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Unable to load notifications. '
                      'Check your internet connection and try again.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            if (!alertSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final rawValue = alertSnapshot.data!.snapshot.value;
            final alerts = <AlertModel>[];

            if (rawValue is Map) {
              final rawAlerts = Map<String, dynamic>.from(rawValue);

              for (final entry in rawAlerts.entries) {
                if (entry.value is! Map) continue;

                final data = Map<String, dynamic>.from(entry.value as Map);

                alerts.add(
                  AlertModel.fromMap(
                    data,
                    alertId: entry.key,
                    deviceId: deviceId,
                  ),
                );
              }

              alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            }

            final unread = alerts.where((alert) => !alert.isRead).toList();

            final read = alerts.where((alert) => alert.isRead).toList();

            return Scaffold(
              appBar: AppBar(title: const Text(AppStrings.notificationsTitle)),
              body: alerts.isEmpty
                  ? const _EmptyNotificationsState()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (unread.isNotEmpty) ...[
                          const _SectionTitle(AppStrings.newNotifications),
                          const SizedBox(height: 8),

                          ...unread.map(
                            (alert) => _NotificationCard(
                              key: ValueKey(
                                '${alert.deviceId}/${alert.alertId}',
                              ),
                              isVisible: widget.isVisible && _appResumed,
                              alert: alert,
                              icon: typeIcon(alert.type),
                              color: severityColor(alert.severity),
                              rtaSessionStartedEpochMs:
                                  rtaSessionStartedEpochMs,
                              onTap: () async {
                                await realtimeDatabaseService.markAlertAsRead(
                                  deviceId: alert.deviceId,
                                  alertId: alert.alertId,
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 18),
                        ],

                        if (read.isNotEmpty) ...[
                          const _SectionTitle(AppStrings.earlierNotifications),
                          const SizedBox(height: 8),

                          ...read.map(
                            (alert) => _NotificationCard(
                              key: ValueKey(
                                '${alert.deviceId}/${alert.alertId}',
                              ),
                              isVisible: widget.isVisible && _appResumed,
                              alert: alert,
                              icon: typeIcon(alert.type),
                              color: severityColor(alert.severity),
                              rtaSessionStartedEpochMs:
                                  rtaSessionStartedEpochMs,
                              onTap: () async {},
                            ),
                          ),
                        ],
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.textLight,
        letterSpacing: 1,
      ),
    );
  }
}

class _NotificationCard extends StatefulWidget {
  const _NotificationCard({
    super.key,
    required this.isVisible,
    required this.alert,
    required this.icon,
    required this.color,
    required this.rtaSessionStartedEpochMs,
    required this.onTap,
  });

  final bool isVisible;
  final AlertModel alert;
  final IconData icon;
  final Color color;
  final int rtaSessionStartedEpochMs;
  final VoidCallback onTap;

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _measurementScheduled = false;
  int _measurementGeneration = 0;
  ScrollPosition? _scrollPosition;
  AlertModel get alert => widget.alert;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachScrollListener();
    _scheduleRiskToAlertMeasurementIfNeeded();
  }

  void _attachScrollListener() {
    final position = alert.responseTimeTest
        ? Scrollable.maybeOf(context)?.position
        : null;
    if (identical(position, _scrollPosition)) return;
    _scrollPosition?.removeListener(_scheduleRiskToAlertMeasurementIfNeeded);
    _scrollPosition = position;
    position?.addListener(_scheduleRiskToAlertMeasurementIfNeeded);
  }

  @override
  void didUpdateWidget(covariant _NotificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alert.alertId != alert.alertId ||
        oldWidget.alert.testTrialId != alert.testTrialId) {
      _measurementGeneration++;
      _measurementScheduled = false;
    }
    _attachScrollListener();
    _scheduleRiskToAlertMeasurementIfNeeded();
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_scheduleRiskToAlertMeasurementIfNeeded);
    super.dispose();
  }

  bool _visibleInViewport() {
    if (!widget.isVisible || ModalRoute.of(context)?.isCurrent != true)
      return false;
    final box = context.findRenderObject();
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox ||
        viewport is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        !viewport.attached ||
        !viewport.hasSize)
      return false;
    final cardRect = box.localToGlobal(Offset.zero) & box.size;
    final viewRect = viewport.localToGlobal(Offset.zero) & viewport.size;
    return cardRect.overlaps(viewRect);
  }

  void _scheduleRiskToAlertMeasurementIfNeeded() {
    final measuredAlert = alert;
    final trialId = measuredAlert.testTrialId;
    final generated = measuredAlert.riskGeneratedEpochMs;
    if (!widget.isVisible ||
        !measuredAlert.responseTimeTest ||
        trialId == null ||
        trialId.isEmpty ||
        generated == null ||
        generated <= 0 ||
        generated < widget.rtaSessionStartedEpochMs ||
        measuredAlert.alertDisplayedEpochMs != null ||
        measuredAlert.riskToAlertMs != null ||
        _measurementScheduled)
      return;

    _measurementScheduled = true;
    final generation = _measurementGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (generation != _measurementGeneration) return;
      if (!mounted ||
          alert.alertId != measuredAlert.alertId ||
          alert.testTrialId != trialId ||
          !_visibleInViewport()) {
        _measurementScheduled = false;
        return;
      }
      final displayed = DateTime.now().millisecondsSinceEpoch;
      final elapsed = displayed - generated;
      if (elapsed < 0) {
        _measurementScheduled = false;
        return;
      }
      try {
        await realtimeDatabaseService.recordRiskToAlertMeasurement(
          deviceId: measuredAlert.deviceId,
          alertId: measuredAlert.alertId,
          testTrialId: trialId,
          alertDisplayedEpochMs: displayed,
          riskToAlertMs: elapsed,
        );
      } catch (_) {
        if (generation == _measurementGeneration) _measurementScheduled = false;
        debugPrint('Unable to save the visible alert timing measurement.');
      }
    });
  }

  String formattedDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) {
      return 'Time unavailable';
    }

    return '${date.month}/${date.day}/${date.year} • '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: alert.isRead
                  ? Colors.transparent
                  : widget.color.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: widget.color.withValues(alpha: 0.12),
                    child: Icon(widget.icon, color: widget.color),
                  ),
                  if (!alert.isRead)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        height: 9,
                        width: 9,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      alert.message,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formattedDate(alert.createdAt),
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                alert.severity,
                style: TextStyle(
                  color: widget.color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.notifications_none,
              size: 56,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 12),

            const Text(
              AppStrings.noNotifications,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Risk alerts, spray updates, and device warnings will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
