import 'prediction_engine_model.dart';

class IotDataModel {
  final double temperature;
  final int humidity;
  final bool leafWet;
  final double lwdHours;

  final bool hasTemperature;
  final bool hasHumidity;
  final bool hasLeafWet;
  final bool hasLwdHours;

  final PredictionEngineModel prediction;
  final String esp32Status;
  final String sensorStatus;
  final String relayStatus;
  final String pumpStatus;
  final DateTime lastUpdate;

  const IotDataModel({
    required this.temperature,
    required this.humidity,
    required this.leafWet,
    required this.lwdHours,
    required this.hasTemperature,
    required this.hasHumidity,
    required this.hasLeafWet,
    required this.hasLwdHours,
    required this.prediction,
    required this.esp32Status,
    required this.sensorStatus,
    required this.relayStatus,
    required this.pumpStatus,
    required this.lastUpdate,
  });
}
