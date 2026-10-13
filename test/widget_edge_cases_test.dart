import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/constants/app_colors.dart';
import '../lib/core/models/iot_data_model.dart';
import '../lib/core/models/prediction_engine_model.dart';
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
