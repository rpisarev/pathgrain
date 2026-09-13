import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/surface_journal.dart';
import 'package:pathgrain/walks/analysis/route_matcher.dart';
import 'package:pathgrain/walks/analysis/walk_surface_summary.dart';
import 'package:pathgrain/walks/surface_route_geojson.dart';

import 'support/analysis_fixtures.dart';
import 'support/surface_fixtures.dart';

void main() {
  test('every barefoot category renders with its own style and original edge geometry', () {
    final labels = CanonicalSurface.values;
    final automatic = AutomaticSurfaceSnapshot.fromSummary(
      WalkSurfaceSummary.fromAnalysis(surfaceAnalysis(labels)),
    );
    final journal = SurfaceJournal(automatic, [
      for (var i = 0; i < labels.length; i += 2)
        SurfaceCorrection(
          startEdgeIndex: i,
          endEdgeIndex: i + 1,
          surface: labels[(i + 1) % labels.length],
        ),
    ]);
    for (final summary in [
      SurfaceJournal(automatic, const []).effective,
      journal.effective,
    ]) {
      final data = SurfaceRouteGeoJson.build(summary);
      expect(data, SurfaceRouteGeoJson.build(summary));
      final features = data['features'] as List;
      expect(features, hasLength(labels.length));
      for (var i = 0; i < features.length; i++) {
        final surface = summary.segments[i].surface;
        expect(features[i]['properties'], {
          'surface': surface.name,
          'color': SurfaceRouteGeoJson.color(surface),
          'startEdge': i,
          'endEdge': i + 1,
          'corrected': summary.segments[i].isCorrected,
        });
        expect(features[i]['geometry']['coordinates'], [
          for (final p in summary.points.getRange(i, i + 2))
            [p.longitude, p.latitude],
        ]);
        expect(
          SurfaceRouteGeoJson.color(surface),
          matches(RegExp(r'^#[0-9A-F]{6}$')),
        );
      }
      expect(
        summary.distanceBySurface.values.fold<double>(0, (a, b) => a + b),
        closeTo(summary.totalDistanceMeters, 1e-6),
      );
    }
    expect(SurfaceRouteGeoJson.color(CanonicalSurface.unknown), '#C62828');
  });

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
    final data = SurfaceRouteGeoJson.build(
      SurfaceJournal(
        AutomaticSurfaceSnapshot.fromSummary(summary),
        const [],
      ).effective,
    );
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
    expect(
      SurfaceRouteGeoJson.build(
        SurfaceJournal(
          AutomaticSurfaceSnapshot.fromSummary(summary),
          const [],
        ).effective,
      )['features'],
      isEmpty,
    );
    expect(
      CanonicalSurface.values.map(SurfaceRouteGeoJson.color).toSet(),
      hasLength(CanonicalSurface.values.length),
    );
  });
}
