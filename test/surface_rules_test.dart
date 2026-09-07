import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/surface_rules.dart';

import 'support/analysis_fixtures.dart';

void main() {
  final expected = {
    CanonicalSurface.grass: ['grass'],
    CanonicalSurface.asphalt: ['asphalt'],
    CanonicalSurface.concrete: ['concrete', 'concrete:plates'],
    CanonicalSurface.ground: ['ground', 'dirt', 'earth', 'soil'],
    CanonicalSurface.gravel: ['gravel', 'fine_gravel', 'pebblestone'],
    CanonicalSurface.pavingStones: ['paving_stones', 'sett'],
    CanonicalSurface.other: [
      'wood',
      'metal',
      'sand',
      'mud',
      'rock',
      'rubber',
      'cobblestone',
      'unhewn_cobblestone',
    ],
  };
  for (final entry in expected.entries) {
    test('explicit surface aliases for ${entry.key.name}', () {
      for (final tag in entry.value) {
        final result = SurfaceRules.derive(
          straightPath(tags: {'highway': 'footway', 'surface': tag}),
        );
        expect(result.surface, entry.key);
        expect(result.assignment, SurfaceAssignment.direct);
        expect(result.reason, AnalysisReason.explicitSurface);
      }
    });
  }
  test('conflicting scoped tags and same-area landcover stay unknown', () {
    for (final tags in [
      {
        'highway': 'footway',
        'surface': 'asphalt',
        'surface:conditional': 'grass @ (wet)',
      },
      {'highway': 'footway', 'surface': 'asphalt', 'surface:forward': 'gravel'},
    ]) {
      expect(
        SurfaceRules.derive(straightPath(tags: tags)).assignment,
        SurfaceAssignment.unknown,
      );
    }
    final area = way(
      3,
      [(0, 0), (100, 0), (100, 100), (0, 100), (0, 0)],
      tags: {
        'area:highway': 'pedestrian',
        'landcover': 'grass',
        'surface': 'asphalt',
      },
    );
    expect(SurfaceRules.derive(area).reason, AnalysisReason.conflictingSurface);
  });
}
