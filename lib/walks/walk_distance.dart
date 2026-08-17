import 'dart:math' as math;

import 'walk_models.dart';

abstract final class WalkDistance {
  static const double _earthRadiusMeters = 6371000;

  static double betweenCoordinates({
    required double latitudeA,
    required double longitudeA,
    required double latitudeB,
    required double longitudeB,
  }) {
    final latitudeDelta = _toRadians(latitudeB - latitudeA);
    final longitudeDelta = _toRadians(longitudeB - longitudeA);
    final latitudeARadians = _toRadians(latitudeA);
    final latitudeBRadians = _toRadians(latitudeB);

    final haversine =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(latitudeARadians) *
            math.cos(latitudeBRadians) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    final clampedHaversine = haversine.clamp(0.0, 1.0);
    final angle =
        2 *
        math.atan2(
          math.sqrt(clampedHaversine),
          math.sqrt(1 - clampedHaversine),
        );
    return _earthRadiusMeters * angle;
  }

  static double total(Iterable<WalkPoint> points) {
    WalkPoint? previous;
    var distanceMeters = 0.0;

    for (final point in points) {
      if (previous != null) {
        distanceMeters += betweenCoordinates(
          latitudeA: previous.latitude,
          longitudeA: previous.longitude,
          latitudeB: point.latitude,
          longitudeB: point.longitude,
        );
      }
      previous = point;
    }

    return distanceMeters;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}
