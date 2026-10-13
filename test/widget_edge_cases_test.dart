import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/constants/app_colors.dart';
import '../lib/core/models/iot_data_model.dart';
import '../lib/core/models/prediction_engine_model.dart';
import '../lib/core/utils/stream_for_each_listener.dart';
import '../lib/features/dashboard/widgets/device_health_card.dart';
import '../lib/features/dashboard/widgets/risk_prediction_card.dart';
import '../lib/features/sprayer/widgets/spray_settings_card.dart';
import '../lib/features/sprayer/widgets/auto_mode_control_card.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

RiskPredictionCard riskCard(PredictionEngineModel prediction) =>
    RiskPredictionCard(
      riskLevel: prediction.riskLevel,
      riskColor: AppColors.textLight,
      riskScore: prediction.riskScore,
      riskExplanation: prediction.riskExplanation,
      recommendedAction: prediction.recommendedAction,
      reasons: prediction.reasons,
      recommendation: prediction.recommendation,
      smartInsight: prediction.smartInsight,
      isOnline: true,
      temperatureScore: prediction.temperatureScore,
      humidityScore: prediction.humidityScore,
      wetnessStatusScore: prediction.wetnessStatusScore,
      wetnessDurationScore: prediction.wetnessDurationScore,
      persistenceScore: prediction.persistenceScore,
      hasScoreBreakdown: prediction.hasScoreBreakdown,
    );

void main() {
  testWidgets(
    'Shared assignment streams survive simultaneous views and tab remounts',
    (tester) async {
      var current = 1;
      var cancelled = 0;
      final sources = <StreamController<int>>[];
      final stream = streamForEachListener<int>(() {
        late StreamController<int> source;
        source = StreamController<int>(
          onListen: () => source.add(current),
          onCancel: () => cancelled++,
        );
        sources.add(source);
        return source.stream;
      }).map((value) => 'device-$value');
      Widget views({bool firstVisible = true}) => host(
        Column(
          children: [
            if (firstVisible)
              StreamBuilder<String>(
                key: const ValueKey('first-view'),
                stream: stream,
                builder: (_, snapshot) =>
                    Text('first: ${snapshot.data ?? "loading"}'),
              ),
            StreamBuilder<String>(
              key: const ValueKey('second-view'),
              stream: stream,
              builder: (_, snapshot) =>
                  Text('second: ${snapshot.data ?? "loading"}'),
            ),
          ],
        ),
      );

      await tester.pumpWidget(views());
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('first: device-1'), findsOneWidget);
      expect(find.text('second: device-1'), findsOneWidget);
      await tester.pumpWidget(views());
      expect(sources, hasLength(2)); // Timer rebuilds keep both subscriptions.

      await tester.pumpWidget(views(firstVisible: false));
      expect(cancelled, 1);
      current = 2;
      for (final source in sources) {
        if (source.hasListener) source.add(current);
      }
      await tester.pump();
      expect(find.text('second: device-2'), findsOneWidget);

      await tester.pumpWidget(views());
      await tester.pump();
      expect(find.text('first: device-2'), findsOneWidget);
      expect(find.text('second: device-2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(cancelled, sources.length);
    },
  );

  testWidgets(
    'A one-shot connection check does not steal a mounted view subscription',
    (tester) async {
      var cancelled = 0;
      final sources = <StreamController<bool>>[];
      final connections = streamForEachListener<bool>(() {
        late StreamController<bool> source;
        source = StreamController<bool>(
          onListen: () => source.add(true),
          onCancel: () => cancelled++,
        );
        sources.add(source);
        return source.stream;
      });
      await tester.pumpWidget(
        host(
          StreamBuilder<bool>(
            stream: connections,
            builder: (_, snapshot) => Text('connected: ${snapshot.data}'),
          ),
        ),
      );
      await tester.pump();
      final connected = await tester.runAsync(() => connections.first);
      expect(connected, isTrue);
      expect(find.text('connected: true'), findsOneWidget);
      expect(cancelled, 1);
      for (final source in sources) {
        if (source.hasListener) source.add(false);
      }
      await tester.pumpAndSettle();
      expect(find.text('connected: false'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(cancelled, sources.length);
    },
  );

  testWidgets(
    'Firebase factory errors reach the error UI and a remounted view can retry',
    (tester) async {
      var denied = true;
      final stream = streamForEachListener<int>(() {
        if (denied) throw StateError('permission-denied');
        return Stream.value(3);
      });
      Widget view(int generation) => host(
        StreamBuilder<int>(
          key: ValueKey(generation),
          stream: stream,
          builder: (_, snapshot) => Text(
            snapshot.hasError
                ? 'Unable to load device'
                : 'device: ${snapshot.data}',
          ),
        ),
      );
      await tester.pumpWidget(view(0));
      await tester.pump();
      expect(find.text('Unable to load device'), findsOneWidget);
      expect(tester.takeException(), isNull);
      denied = false;
      await tester.pumpWidget(view(1));
      await tester.pump();
      expect(find.text('device: 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Auto Mode can be disabled during emergency stop', (
    tester,
  ) async {
    bool? requested;
    await tester.pumpWidget(
      host(
        AutoModeControlCard(
          autoMode: true,
          deviceOnline: true,
          isEmergencyStop: true,
          canEnable: false,
          onChanged: (value) => requested = value,
        ),
      ),
    );
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
    await tester.tap(find.byType(Switch));
    expect(requested, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A pending mode update is locked without claiming the device is offline',
    (tester) async {
      await tester.pumpWidget(
        host(
          AutoModeControlCard(
            autoMode: false,
            deviceOnline: true,
            isEmergencyStop: false,
            isUpdating: true,
            onChanged: (_) =>
                throw StateError('Pending setting should be locked.'),
          ),
        ),
      );
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      expect(find.text('Saving Auto Mode...'), findsOneWidget);
      expect(find.textContaining('farm device is offline'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Online device with incomplete prediction does not display LOW or a zero score',
    (tester) async {
      await tester.pumpWidget(
        host(
          riskCard(PredictionEngineModel.fromMap({'smartInsight': 'pending'})),
        ),
      );
      expect(find.text('UNAVAILABLE'), findsOneWidget);
      expect(find.text('LOW'), findsNothing);
      expect(find.text('Risk Score: Unavailable'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('An out-of-range risk score cannot display a measured score', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        riskCard(
          PredictionEngineModel.fromMap({'riskLevel': 'HIGH', 'riskScore': 19}),
        ),
      ),
    );
    expect(find.text('UNAVAILABLE'), findsOneWidget);
    expect(find.text('Risk Score: 19 / 18'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Unknown or pending command state locks both spray-setting sliders',
    (tester) async {
      var changed = false;
      await tester.pumpWidget(
        host(
          SpraySettingsCard(
            cycles: 1,
            durationSec: 30,
            isLocked: true,
            onCyclesChanged: (_) => changed = true,
            onDurationChanged: (_) => changed = true,
          ),
        ),
      );
      final sliders = tester.widgetList<Slider>(find.byType(Slider));
      expect(sliders, hasLength(2));
      expect(sliders.every((slider) => slider.onChanged == null), isTrue);
      await tester.tap(find.byType(Slider).first);
      expect(changed, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Short device uptime is displayed as uptime, not an epoch time', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DeviceHealthCard(
          data: IotDataModel.fromRealtimeData({}, {}),
          deviceInfo: const {'lastHeartbeat': 60000},
          isOnline: true,
        ),
      ),
    );
    expect(find.text('Device uptime: 0h 1m'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
