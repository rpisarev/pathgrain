import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/route_matcher.dart';
import 'package:pathgrain/walks/analysis/surface_rules.dart';

import 'support/analysis_fixtures.dart';

void main() {
  const expected = {
    CanonicalSurface.asphalt: ['asphalt', 'chipseal'],
    CanonicalSurface.tile: ['paving_stones', 'bricks'],
    CanonicalSurface.cobblestone: ['sett', 'cobblestone', 'unhewn_cobblestone'],
    CanonicalSurface.concrete: ['concrete', 'concrete:plates'],
    CanonicalSurface.ground: [
      'ground',
      'dirt',
      'earth',
      'soil',
      'clay',
      'compacted',
    ],
    CanonicalSurface.sand: ['sand'],
    CanonicalSurface.stone: ['rock', 'stone', 'stepping_stones'],
    CanonicalSurface.fineGravel: ['fine_gravel', 'pebblestone'],
    CanonicalSurface.crushedStone: ['crushed_stone'],
    CanonicalSurface.grass: ['grass'],
    CanonicalSurface.artificialTurf: ['artificial_turf'],
    CanonicalSurface.rubber: ['rubber', 'tartan'],
    CanonicalSurface.wood: ['wood'],
    CanonicalSurface.metal: ['metal', 'metal_grid'],
  };
  const unsupported = [
    'gravel',
    'paved',
    'unpaved',
    'grass_paver',
    'plastic',
    'woodchips',
    'mud',
    'ice',
    'snow',
    'acrylic',
    'synthetic',
    'carpet',
    'shells',
    'salt',
    'arbitrary_unknown_value',
    'concrete:lanes',
    'concrete:invented',
    'paving_stones:lanes',
    'other',
    'asfalt',
    '',
  ];
  for (final entry in expected.entries) {
    for (final tag in entry.value) {
      test('$tag maps to ${entry.key.name} after geometric assignment', () {
        for (final raw in [tag, ' ${tag.toUpperCase()} ']) {
          final feature = straightPath(
            tags: {'highway': 'footway', 'surface': raw},
          );
          final result = SurfaceRules.derive(feature);
          expect(result.surface, entry.key);
          expect(result.assignment, SurfaceAssignment.direct);
          expect(result.reason, AnalysisReason.explicitSurface);
          expect(feature.tags['surface'], raw);
          expect(feature.raw['tags']['surface'], raw);
        }
        final route = RouteMatcher.analyze(straight(), [
          straightPath(tags: {'highway': 'footway', 'surface': tag}),
        ]);
        expect(route.samples[4].selected, isNotNull);
        expect(route.samples[4].surface.surface, entry.key);
        expect(route.edges[4].surface.surface, entry.key);
      });
    }
  }

  for (final tag in unsupported) {
    test('explicit $tag stays UNKNOWN with an unsupported-surface reason', () {
      final feature = straightPath(
        tags: {'highway': 'footway', 'surface': tag},
      );
      final result = SurfaceRules.derive(feature);
      expect(result.surface, CanonicalSurface.unknown);
      expect(result.assignment, SurfaceAssignment.unknown);
      expect(result.reason, AnalysisReason.unsupportedSurface);
      expect(feature.tags['surface'], tag);
      final route = RouteMatcher.analyze(straight(), [feature]);
      expect(route.samples[4].selected, isNotNull);
      expect(route.edges[4].surface.reason, AnalysisReason.unsupportedSurface);
    });
  }

  test('missing surface stays distinct; explicit unsupported tags block grass inference', () {
    expect(
      SurfaceRules.derive(straightPath(tags: {'highway': 'footway'})).reason,
      AnalysisReason.missingSurface,
    );
    for (final raw in <String?>[null, 'mud', 'ice', 'snow', 'gravel', '']) {
      final area = way(
        3,
        [(-30, -30), (150, -30), (150, 30), (-30, 30), (-30, -30)],
        tags: {
          'area:highway': 'pedestrian',
          'landcover': 'grass',
          'surface': ?raw,
        },
      );
      final result = SurfaceRules.derive(area);
      expect(
        result.surface,
        raw == null ? CanonicalSurface.grass : CanonicalSurface.unknown,
      );
      expect(
        result.assignment,
        raw == null ? SurfaceAssignment.inferred : SurfaceAssignment.unknown,
      );
      expect(
        result.reason,
        raw == null
            ? AnalysisReason.grassLandcover
            : AnalysisReason.unsupportedSurface,
      );
    }
  });

  test(
    'scoped tags, mixtures and conflicting same-area landcover stay UNKNOWN',
    () {
      for (final key in [
        'surface:conditional',
        'surface:forward',
        'surface:backward',
        'surface:lanes',
        'surface:left',
        'surface:right',
      ]) {
        final result = SurfaceRules.derive(
          straightPath(
            tags: {
              'highway': 'footway',
              'surface': 'paving_stones',
              key: 'sett',
            },
          ),
        );
        expect(result.reason, AnalysisReason.conflictingSurface);
        expect(result.assignment, SurfaceAssignment.unknown);
      }
      for (final raw in [
        'asphalt;grass',
        'fine_gravel;crushed_stone',
        'grass;grass',
      ]) {
        expect(
          SurfaceRules.derive(
            straightPath(tags: {'highway': 'footway', 'surface': raw}),
          ).reason,
          AnalysisReason.conflictingSurface,
        );
      }
      for (final raw in ['asphalt', 'artificial_turf']) {
        final area = way(
          3,
          [(0, 0), (100, 0), (100, 100), (0, 100), (0, 0)],
          tags: {
            'area:highway': 'pedestrian',
            'landcover': 'grass',
            'surface': raw,
          },
        );
        expect(
          SurfaceRules.derive(area).reason,
          AnalysisReason.conflictingSurface,
        );
      }
    },
  );

  test('surface interpretation cannot influence candidate scores, selection or GPS', () {
    List<Object?> geometricResults(String raw) {
      final route = RouteMatcher.analyze(straight(), [
        straightPath(tags: {'highway': 'footway', 'surface': raw}),
        straightPath(
          id: 2,
          north: 14,
          tags: {'highway': 'residential', 'surface': 'asphalt'},
        ),
      ]);
      expect(route.samples[4].selected?.feature.key, 'way/1');
      return [
        for (final sample in route.samples)
          [
            sample.selected?.feature.key,
            sample.confidence,
            sample.reason,
            sample.gps.state,
            sample.gps.reasons,
            for (final candidate in sample.candidates)
              [
                candidate.feature.key,
                candidate.reason,
                candidate.distanceMeters,
                candidate.directionDegrees,
                candidate.proximityScore,
                candidate.pedestrianScore,
                candidate.directionScore,
                candidate.gpsScore,
                candidate.continuityScore,
              ],
          ],
      ];
    }

    final baseline = geometricResults('grass');
    for (final raw in [...expected.values.expand((v) => v), ...unsupported]) {
      expect(geometricResults(raw), baseline, reason: raw);
    }
  });
}
