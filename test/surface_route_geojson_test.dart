import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/route_matcher.dart';
import 'package:pathgrain/walks/analysis/walk_surface_summary.dart';
import 'package:pathgrain/walks/surface_route_geojson.dart';

import 'support/analysis_fixtures.dart';
import 'support/surface_fixtures.dart';

void main() {
  test('map lines use ordered original slices, including UNKNOWN', () {
    final points = straight(count: 6, north: 12);
    final summary = WalkSurfaceSummary.fromAnalysis(
      surfaceAnalysis([
        CanonicalSurface.asphalt,
        CanonicalSurface.asphalt,
        CanonicalSurface.unknown,
        CanonicalSurface.grass,
        CanonicalSurface.grass,
      ], points: points),
    );
    final data = SurfaceRouteGeoJson.build(summary);
    final features = data['features'] as List;
    expect(features, hasLength(3));
    final reconstructedEdges = <Object?>[];
    for (var i = 0; i < features.length; i++) {
      final segment = summary.segments[i];
      final coordinates = features[i]['geometry']['coordinates'] as List;
      expect(
        coordinates,
        points
            .sublist(segment.startEdgeIndex, segment.endEdgeIndex + 1)
            .map((p) => [p.longitude, p.latitude])
            .toList(),
      );
      for (var j = 1; j < coordinates.length; j++) {
        reconstructedEdges.add([coordinates[j - 1], coordinates[j]]);
      }
    }
    expect(reconstructedEdges, [
      for (var i = 1; i < points.length; i++)
        [
          [points[i - 1].longitude, points[i - 1].latitude],
          [points[i].longitude, points[i].latitude],
        ],
    ]);
    expect(features[1]['properties']['surface'], 'unknown');
    expect(
      features[1]['properties']['color'],
      SurfaceRouteGeoJson.color(CanonicalSurface.unknown),
    );
    final serialized = jsonEncode(data);
    expect(serialized, isNot(contains('recordedAt')));
    expect(serialized, isNot(contains('way/')));
    expect(serialized, isNot(contains('accuracy')));
  });
  test('empty collection and distinct colors for all categories', () {
    final summary = WalkSurfaceSummary.fromAnalysis(
      RouteMatcher.analyze([], []),
    );
    expect(SurfaceRouteGeoJson.build(summary)['features'], isEmpty);
    expect(
      CanonicalSurface.values.map(SurfaceRouteGeoJson.color).toSet(),
      hasLength(CanonicalSurface.values.length),
    );
  });
}
