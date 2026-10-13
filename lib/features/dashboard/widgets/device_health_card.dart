import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/iot_data_model.dart';
import 'info_row.dart';
import 'status_row.dart';

class DeviceHealthCard extends StatelessWidget {
  const DeviceHealthCard({
    super.key,
    required this.data,
    required this.deviceInfo,
    required this.isOnline,
  });

  final bool isOnline;
  final IotDataModel data;
  final Map<String, dynamic> deviceInfo;

  String formatHeartbeat(dynamic heartbeat) {
    if (!isOnline) {
      return 'No active heartbeat';
    }

    if (heartbeat is! num) {
      return 'Unavailable';
    }

    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      heartbeat.toInt(),
    );

    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  String formatStatus(String value) {
    if (value.isEmpty) return value;

    return value
        .toLowerCase()
        .split('_')
        .map(
          (word) =>
      word.isEmpty ? word : word[0].toUpperCase() + word.substring(1),
    )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final firmwareVersion = isOnline
        ? deviceInfo['firmwareVersion'] ?? 'Unknown'
        : 'Unavailable';

    final wifiSSID = isOnline
        ? deviceInfo['wifiSSID'] ?? 'Not available'
        : 'Unavailable';

    final ipAddress = isOnline
        ? deviceInfo['ipAddress'] ?? 'Not available'
        : 'Unavailable';

    final sensorStatus = data.sensorStatus.toUpperCase();
    final relayStatus = data.relayStatus.toUpperCase();
    final pumpStatus = data.pumpStatus.toUpperCase();

    final sensorReadingsAvailable =
        isOnline &&
            (sensorStatus == 'OK' ||
                sensorStatus == 'ONLINE' ||
                sensorStatus == 'CONNECTED');

    final relayOk =
        isOnline &&
            (relayStatus == 'READY' ||
                relayStatus == 'ON' ||
                relayStatus == 'ACTIVE' ||
                relayStatus == 'OFF');

    final pumpOk =
        isOnline &&
            (pumpStatus == 'IDLE' ||
                pumpStatus == 'RUNNING' ||
                pumpStatus == 'ON' ||
                pumpStatus == 'OFF');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 12),

            StatusRow(
              'Farm Device',
              isOnline ? 'Online' : 'Offline',
              isOnline ? DeviceStatusState.ok : DeviceStatusState.error,
            ),

            StatusRow(
              'Sensor Readings',
              !isOnline
                  ? 'Offline'
                  : sensorReadingsAvailable
                  ? 'Available'
                  : sensorStatus == 'UNAVAILABLE' || sensorStatus == 'UNKNOWN'
                  ? 'Unavailable'
                  : 'Reading Issue',
              !isOnline
                  ? DeviceStatusState.error
                  : sensorReadingsAvailable
                  ? DeviceStatusState.ok
                  : sensorStatus == 'UNAVAILABLE' || sensorStatus == 'UNKNOWN'
                  ? DeviceStatusState.warning
                  : DeviceStatusState.error,
            ),

            StatusRow(
              'Relay State',
              isOnline ? formatStatus(data.relayStatus) : 'Offline',
              !isOnline
                  ? DeviceStatusState.error
                  : relayOk
                  ? DeviceStatusState.ok
                  : relayStatus == 'UNAVAILABLE' || relayStatus == 'UNKNOWN'
                  ? DeviceStatusState.warning
                  : DeviceStatusState.error,
            ),

            StatusRow(
              'Pump State',
              isOnline ? formatStatus(data.pumpStatus) : 'Offline',
              !isOnline
                  ? DeviceStatusState.error
                  : pumpOk
                  ? DeviceStatusState.ok
                  : pumpStatus == 'UNAVAILABLE' ||
                  pumpStatus == 'UNKNOWN' ||
                  pumpStatus == 'DISABLED'
                  ? DeviceStatusState.warning
                  : DeviceStatusState.error,
            ),

            const Divider(height: 24),

            InfoRow('Firmware', firmwareVersion),
            InfoRow('WiFi SSID', wifiSSID),
            InfoRow('IP Address', ipAddress),
            InfoRow('Heartbeat', formatHeartbeat(deviceInfo['lastHeartbeat'])),
          ],
        ),
      ),
    );
  }
}
