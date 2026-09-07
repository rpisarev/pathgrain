import 'dart:math' as math;

import '../../map/evidence/geographic_cell.dart';
import '../../map/evidence/osm_evidence.dart';
import '../walk_distance.dart';
import '../walk_models.dart';
import 'analysis_settings.dart';

class GeometryHit {
  const GeometryHit(
    this.distance,
    this.bearing,
    this.supported,
    this.insideArea,
    this.boundaryDistance,
  );
  final double distance;
  final double? bearing;
  final bool supported;
  final bool insideArea;
  final double boundaryDistance;
}

/// Local meter-plane calculations only; no snapping or geometry repair.
abstract final class RouteGeometry {
  static GeoCoordinate coordinate(WalkPoint p) =>
      GeoCoordinate(p.latitude, p.longitude);
  static bool valid(WalkPoint p) =>
      coordinate(p).isValid &&
      p.latitude.abs() <= AnalysisSettings.maximumLatitude;

  static double distance(WalkPoint a, WalkPoint b) =>
      WalkDistance.betweenCoordinates(
        latitudeA: a.latitude,
        longitudeA: a.longitude,
        latitudeB: b.latitude,
        longitudeB: b.longitude,
      );

  static math.Point<double> project(GeoCoordinate p, GeoCoordinate origin) {
    final longitudeDelta = (p.longitude - origin.longitude + 540) % 360 - 180;
    const radians = math.pi / 180;
    const radius = 6371000.0;
    return math.Point(
      longitudeDelta * radians * radius * math.cos(origin.latitude * radians),
      (p.latitude - origin.latitude) * radians * radius,
    );
  }

  static double bearing(WalkPoint a, WalkPoint b) {
    final delta = project(coordinate(b), coordinate(a));
    return math.atan2(delta.y, delta.x);
  }

  static double directionDifference(double a, double b) =>
      math.acos(math.cos(a - b).abs().clamp(0.0, 1.0)) * 180 / math.pi;

  static double segmentDistance(
    math.Point<double> p,
    math.Point<double> a,
    math.Point<double> b,
  ) {
    final delta = b - a;
    final lengthSquared = delta.x * delta.x + delta.y * delta.y;
    if (lengthSquared == 0) return p.distanceTo(a);
    final offset = p - a;
    final t = ((offset.x * delta.x + offset.y * delta.y) / lengthSquared).clamp(
      0.0,
      1.0,
    );
    return p.distanceTo(a + delta * t);
  }

  static double lateralOffset(WalkPoint a, WalkPoint b, WalkPoint c) {
    final origin = coordinate(a);
    return segmentDistance(
      project(coordinate(b), origin),
      const math.Point(0.0, 0.0),
      project(coordinate(c), origin),
    );
  }

  static GeometryHit inspect(OsmFeature feature, GeoCoordinate point) {
    const zero = math.Point(0.0, 0.0);
    var distance = double.infinity;
    double? bearing;
    var local =
        point.isValid &&
        point.latitude.abs() <= AnalysisSettings.maximumLatitude;
    final parts = <List<math.Point<double>>>[];
    for (final part in feature.parts) {
      final projected = <math.Point<double>>[];
      for (final p in part) {
        if (!p.isValid) {
          local = false;
          continue;
        }
        final xy = project(p, point);
        if (xy.magnitude > AnalysisSettings.maximumLocalGeometryMeters) {
          local = false;
        }
        projected.add(xy);
      }
      parts.add(projected);
      if (projected.length == 1) {
        distance = math.min(distance, projected.single.magnitude);
      }
      for (var i = 1; i < projected.length; i++) {
        final a = projected[i - 1];
        final b = projected[i];
        if (a == b) continue;
        final d = segmentDistance(zero, a, b);
        if (d < distance) {
          distance = d;
          bearing = math.atan2(b.y - a.y, b.x - a.x);
        }
      }
    }
    var supported =
        local &&
        feature.type == OsmElementType.way &&
        feature.limitations.isEmpty &&
        parts.length == 1 &&
        bearing != null;
    var inside = false;
    if (feature.isArea) {
      supported =
          supported &&
          feature.geometryKind == OsmGeometryKind.closedArea &&
          _convex(parts.single);
      if (supported) inside = _insideConvex(parts.single, zero);
    } else {
      supported = supported && feature.geometryKind == OsmGeometryKind.line;
    }
    return GeometryHit(
      inside ? 0 : distance,
      feature.isArea ? null : bearing,
      supported,
      inside,
      distance,
    );
  }

  static double _cross(
    math.Point<double> a,
    math.Point<double> b,
    math.Point<double> c,
  ) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);

  // Every vertex must be on the same side of each edge. Deliberately reject
  // concave rings, self-intersecting stars and duplicate vertices.
  static bool _convex(List<math.Point<double>> ring) {
    if (ring.length < 4 ||
        ring.first != ring.last ||
        ring.length > AnalysisSettings.maximumAreaVertices + 1) {
      return false;
    }
    final vertices = ring.sublist(0, ring.length - 1);
    if (vertices.toSet().length != vertices.length) return false;
    var sign = 0;
    for (var i = 1; i < ring.length; i++) {
      for (final vertex in vertices) {
        final cross = _cross(ring[i - 1], ring[i], vertex);
        if (cross.abs() < 1e-6) continue;
        final next = cross > 0 ? 1 : -1;
        if (sign != 0 && sign != next) return false;
        sign = next;
      }
    }
    return sign != 0;
  }

  static bool _insideConvex(
    List<math.Point<double>> ring,
    math.Point<double> p,
  ) {
    var sign = 0;
    for (var i = 1; i < ring.length; i++) {
      final cross = _cross(ring[i - 1], ring[i], p);
      if (cross.abs() < 1e-6) continue;
      final next = cross > 0 ? 1 : -1;
      if (sign != 0 && sign != next) return false;
      sign = next;
    }
    return true;
  }
}
