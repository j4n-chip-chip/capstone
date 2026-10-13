import '../utils/rtdb_value_parser.dart';
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

  factory IotDataModel.fromRealtimeData(
    Map<String, dynamic> status,
    Map<String, dynamic> prediction,
  ) {
    final temperature = readRtdbDouble(status, 'temperature');
    final rawHumidity = readRtdbDouble(status, 'humidity');
    final humidity =
        rawHumidity != null && rawHumidity >= 0 && rawHumidity <= 100
        ? rawHumidity
        : null;
    final rawDuration = readRtdbDouble(status, 'lwdHours');
    final duration = rawDuration != null && rawDuration >= 0
        ? rawDuration
        : null;
    final wet = readRtdbBool(status, 'leafWet');
    return IotDataModel(
      temperature: temperature ?? 0,
      humidity: humidity?.round() ?? 0,
      leafWet: wet ?? false,
      lwdHours: duration ?? 0,
      hasTemperature:
          readRtdbBool(status, 'temperatureAvailable') == true &&
          temperature != null,
      hasHumidity:
          readRtdbBool(status, 'humidityAvailable') == true && humidity != null,
      hasLeafWet:
          readRtdbBool(status, 'leafWetAvailable') == true && wet != null,
      hasLwdHours:
          readRtdbBool(status, 'leafWetAvailable') == true && duration != null,
      esp32Status: readRtdbString(status, 'esp32Status', fallback: 'UNKNOWN'),
      sensorStatus: readRtdbString(
        status,
        'sensorStatus',
        fallback: 'Unavailable',
      ),
      relayStatus: readRtdbString(
        status,
        'relayStatus',
        fallback: 'Unavailable',
      ),
      pumpStatus: readRtdbString(status, 'pumpStatus', fallback: 'Disabled'),
      lastUpdate: readRtdbDateTime(status['lastUpdate']),
      prediction: PredictionEngineModel.fromMap(prediction),
    );
  }
}
