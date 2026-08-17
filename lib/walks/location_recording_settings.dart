import 'package:geolocator/geolocator.dart';

/// Device-test tuning values for the initial walk-recording slice.
///
/// Keep these values together and simple. They are expected to change after
/// the first physical-device walks; this is intentionally not a configuration
/// system.
abstract final class LocationRecordingSettings {
  static const LocationAccuracy requestedAccuracy = LocationAccuracy.high;
  static const int distanceFilterMeters = 5;
  static const Duration androidUpdateInterval = Duration(seconds: 5);
  static const double maximumAcceptedAccuracyMeters = 50;
  static const double minimumAcceptedDisplacementMeters = 3;
  static const double maximumPlausibleSpeedMetersPerSecond = 8;
}
