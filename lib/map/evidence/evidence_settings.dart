/// Provisional values for manual MVP 0.1-A field tests, not production policy.
abstract final class EvidenceSettings {
  static const int cellZoom = 15;
  static const double cellPaddingMeters = 30;
  static const String queryVersion = 'highways-raw-geometry-v1';
  static const String endpoint = 'https://overpass-api.de/api/interpreter';
  static const String userAgent = 'Pathgrain/0.1-A (development OSM evidence)';
  static const int queryTimeoutSeconds = 25;
  static const int queryMaxSizeBytes = 16 * 1024 * 1024;
  static const Duration httpTimeout = Duration(seconds: 45);
  static const Duration requestInterval = Duration(seconds: 1);
  static const Duration failureCooldown = Duration(seconds: 30);
  static const int maximumResponseBytes = 2 * 1024 * 1024;
}
