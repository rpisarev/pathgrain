import 'dart:math' as math;

import '../../walks/walk_models.dart';
import 'geographic_cell.dart';
import 'osm_evidence.dart';

/// Local presentation only. None of these GeoJSON collections enter the
/// evidence provider or its HTTP request builder.
abstract final class EvidenceGeoJson {
  static Map<String, dynamic> collection(
    Iterable<Map<String, dynamic>> features,
  ) => {'type': 'FeatureCollection', 'features': features.toList()};

  static Map<String, dynamic> _feature(
    String type,
    Object coordinates,
    Map<String, dynamic> properties,
  ) => {
    'type': 'Feature',
    'properties': properties,
    'geometry': {'type': type, 'coordinates': coordinates},
  };

  static Map<String, dynamic> osm(Iterable<OsmFeature> features) => collection(
    features.expand((feature) {
      final properties = {
        'evidenceKey': feature.key,
        'color': _debugColor(feature),
        'relation': feature.type == OsmElementType.relation,
      };
      if (feature.geometryKind == OsmGeometryKind.closedArea) {
        return [
          _feature('Polygon', [
            feature.parts.single.map((p) => p.geoJson).toList(),
          ], properties),
        ];
      }
      return feature.parts.map(
        (part) => part.length == 1
            ? _feature('Point', part.single.geoJson, properties)
            : _feature(
                'LineString',
                part.map((p) => p.geoJson).toList(),
                properties,
              ),
      );
    }),
  );

  static String _debugColor(OsmFeature feature) {
    if (feature.type == OsmElementType.relation) return '#7B1FA2';
    if (feature.isArea) return '#00796B';
    return switch (feature.tags['highway']) {
      'footway' ||
      'path' ||
      'pedestrian' ||
      'steps' ||
      'crossing' ||
      'cycleway' ||
      'bridleway' => '#2E7D32',
      _ => '#EF6C00',
    };
  }

  static Map<String, dynamic> route(List<WalkPoint> points) => collection([
    if (points.length >= 2)
      _feature(
        'LineString',
        points.map((point) => [point.longitude, point.latitude]).toList(),
        const {},
      ),
  ]);

  static Map<String, dynamic> samples(List<WalkPoint> points) => collection(
    points.map(
      (point) => _feature(
        'Point',
        [point.longitude, point.latitude],
        {'sequence': point.sequence},
      ),
    ),
  );

  static Map<String, dynamic> accuracy(List<WalkPoint> points) => collection([
    for (final point in points)
      if (point.accuracyMeters.isFinite && point.accuracyMeters > 0)
        _feature('Polygon', [accuracyRing(point)], const {}),
  ]);

  /// Spherical destination formula; meter-radius polygons, independent of
  /// map zoom. They illustrate reported accuracy, not a matched confidence.
  static List<List<double>> accuracyRing(WalkPoint point) {
    const radiusMeters = 6371000.0;
    const vertices = 48;
    final angularRadius = point.accuracyMeters / radiusMeters;
    final latitude = point.latitude * math.pi / 180;
    final longitude = point.longitude * math.pi / 180;
    final ring = <List<double>>[];
    for (var i = 0; i < vertices; i++) {
      final bearing = 2 * math.pi * i / vertices;
      final targetLatitude = math.asin(
        (math.sin(latitude) * math.cos(angularRadius) +
                math.cos(latitude) *
                    math.sin(angularRadius) *
                    math.cos(bearing))
            .clamp(-1.0, 1.0),
      );
      final targetLongitude =
          longitude +
          math.atan2(
            math.sin(bearing) * math.sin(angularRadius) * math.cos(latitude),
            math.cos(angularRadius) -
                math.sin(latitude) * math.sin(targetLatitude),
          );
      // Keep longitudes continuous around the center across the dateline.
      ring.add(
        GeoCoordinate(
          targetLatitude * 180 / math.pi,
          targetLongitude * 180 / math.pi,
        ).geoJson,
      );
    }
    ring.add(List.of(ring.first));
    return ring;
  }
}
