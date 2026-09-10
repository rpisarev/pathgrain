import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/map/evidence/osm_evidence.dart';
import 'package:pathgrain/walks/analysis/analysis_settings.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/route_matcher.dart';

import 'support/analysis_fixtures.dart';

void main() {
  for (final other in [
    (feature: straightPath(id: 2, north: 20), reason: AnalysisReason.tooFar),
    (
      feature: way(2, [(44, -30), (44, 30)]),
      reason: AnalysisReason.directionConflict,
    ),
  ]) {
    test(
      'a non-member pedestrian way rejected as ${other.reason.name} does not block the exception',
      () {
        final features = [_memberPath(), other.feature];
        final beforeNode = RouteMatcher.analyze(
          straight(),
          features,
        ).samples[4];
        expect(beforeNode.reason, AnalysisReason.matched);
        final s = RouteMatcher.analyze(straight(), [
          ...features,
          _node(),
        ]).samples[4];
        final rejected = s.candidates.singleWhere(
          (c) => c.feature.key == other.feature.key,
        );
        expect(rejected.reason, other.reason);
        expect(rejected.eligible, isFalse);
        expect(s.selected?.feature.key, 'way/1');
        expect(s.reason, AnalysisReason.matched);
        expect(s.surface.surface, CanonicalSurface.pavingStones);
        expect(s.surface.assignment, SurfaceAssignment.direct);
        expect(
          s.selected!.score - s.selected!.continuityScore,
          greaterThan(AnalysisSettings.minimumScore),
        );
      },
    );
  }

  test('an eligible low-scoring pedestrian rival is not harmless', () {
    final points = straight(north: 0);
    final features = [_memberPath(), straightPath(id: 2, north: 11)];
    expect(
      RouteMatcher.analyze(points, features).samples[4].reason,
      AnalysisReason.matched,
    );
    final s = RouteMatcher.analyze(points, [...features, _node()]).samples[4];
    final rival = s.candidates.singleWhere((c) => c.feature.key == 'way/2');
    expect(rival.reason, AnalysisReason.eligible);
    expect(
      rival.score - rival.continuityScore,
      lessThan(AnalysisSettings.minimumScore),
    );
    expect(s.reason, AnalysisReason.ambiguousCandidates);
    expect(s.selected, isNull);
  });

  test('neighbor support cannot waive a node when independent geometry is ambiguous', () {
    final points = straight(north: 0);
    final features = [
      _memberPath(highway: 'path'),
      way(2, [(39, 6.5), (41, 6.5)], tags: {'highway': 'service'}),
    ];
    final withoutNode = RouteMatcher.analyze(points, features);
    expect(withoutNode.samples[4].reason, AnalysisReason.continuitySupported);
    final result = RouteMatcher.analyze(points, [...features, _node()]);
    for (final i in [3, 5]) {
      expect(result.samples[i].reason, AnalysisReason.matched);
      expect(result.samples[i].selected?.feature.key, 'way/1');
    }
    final s = result.samples[4];
    final eligible = s.candidates.where((c) => c.eligible).toList();
    expect(
      eligible.first.score - eligible.first.continuityScore,
      greaterThan(AnalysisSettings.minimumScore),
    );
    expect(
      (eligible.first.score - eligible.first.continuityScore) -
          (eligible[1].score - eligible[1].continuityScore),
      greaterThan(AnalysisSettings.minimumMargin),
    );
    expect(s.reason, AnalysisReason.ambiguousCandidates);
    expect(s.selected, isNull);
  });

  for (final highway in ['footway', 'path']) {
    test(
      'a member crossing node does not veto an independently supported $highway',
      () {
        final path = _memberPath(highway: highway);
        final withoutNode = RouteMatcher.analyze(straight(), [path]);
        final result = RouteMatcher.analyze(straight(), [path, _node()]);
        final s = result.samples[4];
        expect(withoutNode.samples[4].reason, AnalysisReason.matched);
        expect(s.selected?.feature.key, 'way/1');
        expect(s.reason, AnalysisReason.matched);
        expect(s.confidence, MatchConfidence.strong);
        expect(
          s.selected!.score - s.selected!.continuityScore,
          greaterThan(AnalysisSettings.minimumScore),
        );
        // The node remains visible as rejected evidence; it never becomes a way.
        expect(
          s.candidates
              .singleWhere((c) => c.feature.type == OsmElementType.node)
              .reason,
          AnalysisReason.unsupportedGeometry,
        );
        for (final edge in result.edges.skip(2)) {
          expect(edge.surface.surface, CanonicalSurface.pavingStones);
          expect(edge.surface.assignment, SurfaceAssignment.direct);
        }
        expect(result.samples.take(2).every((s) => s.selected == null), isTrue);
      },
    );
  }

  test('a shared vehicle road rejected by heading does not make a crossing a rival', () {
    final road = _withNodes(
      way(2, [(40, -30), (40, 0), (40, 30)], tags: {'highway': 'service'}),
      [21, 99, 22],
    );
    final path = _memberPath();
    final expected = RouteMatcher.analyze(straight(), [path, road]);
    for (final features in [
      [path, road, _node()],
      [_node(), road, _memberPath(reverse: true)],
    ]) {
      final result = RouteMatcher.analyze(straight(), features);
      expect(
        result.samples.map(
          (s) => (s.selected?.feature.key, s.reason, s.surface.surface),
        ),
        expected.samples.map(
          (s) => (s.selected?.feature.key, s.reason, s.surface.surface),
        ),
      );
      expect(
        result.samples[4].candidates
            .singleWhere((c) => c.feature.key == road.key)
            .reason,
        AnalysisReason.directionConflict,
      );
    }
  });

  test('membership does not fabricate a surface on an untagged footway', () {
    final result = RouteMatcher.analyze(straight(), [
      _memberPath(surface: null),
      _node(),
      straightPath(id: 2, north: 20),
      way(3, [(44, -30), (44, 30)]),
    ]);
    expect(result.samples[4].selected?.feature.key, 'way/1');
    expect(result.edges[4].surface.assignment, SurfaceAssignment.unknown);
    expect(result.edges[4].reason, AnalysisReason.missingSurface);
  });

  test('a node belonging only to a different way still vetoes the leader', () {
    final other = _withNodes(way(2, [(40, -30), (40, 0), (40, 30)]), [
      21,
      99,
      22,
    ]);
    final leading = _withNodes(_memberPath(), [11, 98, 12]);
    final s = RouteMatcher.analyze(straight(), [
      leading,
      other,
      _node(),
    ]).samples[4];
    expect(s.candidates.first.feature.key, leading.key);
    expect(s.reason, AnalysisReason.ambiguousCandidates);
    expect(s.selected, isNull);
  });

  for (final tags in [
    {'highway': 'footway', 'surface': 'paving_stones'},
    {'highway': 'footway', 'surface': 'asphalt'},
    {'highway': 'steps', 'surface': 'concrete'},
    {
      'highway': 'footway',
      'surface': 'paving_stones',
      'tunnel': 'yes',
      'layer': '-1',
    },
  ]) {
    test('a shared pedestrian branch retains the veto: $tags', () {
      final branch = _withNodes(way(2, [(40, 0), (40, 30)], tags: tags), [
        99,
        22,
      ]);
      final withoutNode = RouteMatcher.analyze(straight(), [
        _memberPath(),
        branch,
      ]);
      expect(withoutNode.samples[4].selected?.feature.key, 'way/1');
      final s = RouteMatcher.analyze(straight(), [
        _memberPath(),
        branch,
        _node(),
      ]).samples[4];
      // Even a rejected perpendicular branch may carry a different transition.
      expect(s.reason, AnalysisReason.ambiguousCandidates);
      expect(s.selected, isNull);
    });
  }

  test('a shared eligible vehicle way remains an unresolved parent', () {
    final road = _withNodes(
      way(
        2,
        [(10, -30), (40, 0), (70, 30)],
        tags: {'highway': 'service', 'surface': 'asphalt'},
      ),
      [21, 99, 22],
    );
    final s = RouteMatcher.analyze(straight(), [
      _memberPath(),
      road,
      _node(),
    ]).samples[4];
    expect(
      s.candidates.singleWhere((c) => c.feature.key == road.key).eligible,
      isTrue,
    );
    expect(s.reason, AnalysisReason.ambiguousCandidates);
    expect(s.selected, isNull);
  });

  test('an unrenderable shared parent cannot be silently omitted', () {
    final parent = _parse({
      'type': 'way',
      'id': 2,
      'tags': {'highway': 'steps'},
      'nodes': [99, 22],
    });
    final s = RouteMatcher.analyze(straight(), [
      _memberPath(),
      parent,
      _node(),
    ]).samples[4];
    expect(s.candidates.any((c) => c.feature.key == parent.key), isFalse);
    expect(s.reason, AnalysisReason.ambiguousCandidates);
    expect(s.selected, isNull);
  });

  test('a distinct parallel pedestrian rival stays ambiguous despite a strong lead', () {
    final s = RouteMatcher.analyze(straight(north: 0), [
      _memberPath(),
      _node(),
      straightPath(id: 2, north: 6.5),
    ]).samples[4];
    final eligible = s.candidates.where((c) => c.eligible).toList();
    expect(
      eligible[0].score - eligible[1].score,
      greaterThan(AnalysisSettings.strongMargin),
    );
    expect(s.reason, AnalysisReason.ambiguousCandidates);
    expect(s.selected, isNull);
  });

  test(
    'ordinary independent margin is still required against a parallel road',
    () {
      final s = RouteMatcher.analyze(straight(north: 5), [
        _memberPath(),
        _node(),
        straightPath(id: 2, north: 8, tags: {'highway': 'residential'}),
      ]).samples[4];
      final eligible = s.candidates.where((c) => c.eligible).toList();
      expect(
        eligible[0].score - eligible[1].score,
        lessThan(AnalysisSettings.minimumMargin),
      );
      expect(s.reason, AnalysisReason.ambiguousCandidates);
      expect(s.selected, isNull);
    },
  );

  test('a same-way node does not rescue a weak candidate without heading', () {
    final points = [for (var i = 0; i < 10; i++) sample(i, i * 1.0, 4.6)];
    final s = RouteMatcher.analyze(points, [
      _memberPath(east: 4),
      _node(east: 4),
    ]).samples[4];
    expect(s.candidates.first.directionDegrees, isNull);
    expect(s.candidates.first.score, lessThan(AnalysisSettings.minimumScore));
    expect(s.reason, AnalysisReason.weakScore);
    expect(s.selected, isNull);
  });

  test('nearby nodes require valid IDs and consistent member geometry', () {
    for (final ids in [
      null,
      [11, 98, 12],
      ['11', '99', '12'],
      [11, 99.0, 12],
      [11, 99],
      [11, 12, 99],
    ]) {
      final s = RouteMatcher.analyze(straight(), [
        _withNodes(_memberPath(), ids),
        _node(),
      ]).samples[4];
      expect(s.reason, AnalysisReason.ambiguousCandidates, reason: '$ids');
      expect(s.selected, isNull);
    }
  });

  for (final extra in [
    {'surface': 'concrete'},
    {'surface': 'paving_stones'},
    {'entrance': 'yes'},
    {'level': '-1'},
    {'tunnel': 'yes'},
    {'highway': 'steps'},
  ]) {
    test(
      'a node with additional route or surface semantics keeps its veto: $extra',
      () {
        final s = RouteMatcher.analyze(straight(), [
          _memberPath(),
          _node(extra: extra),
        ]).samples[4];
        expect(s.reason, AnalysisReason.ambiguousCandidates);
        expect(s.selected, isNull);
      },
    );
  }
}

OsmFeature _parse(Map<String, Object?> raw) => OsmEvidence.parse(
  jsonEncode({
    'elements': [raw],
  }),
).features.single;

OsmFeature _withNodes(OsmFeature feature, Object? nodes) =>
    _parse({...feature.raw, 'nodes': nodes});

OsmFeature _memberPath({
  String highway = 'footway',
  String? surface = 'paving_stones',
  double east = 40,
  bool reverse = false,
}) {
  final vertices = [(-30.0, 0.0), (east, 0.0), (150.0, 0.0)];
  final nodes = [11, 99, 12];
  return _withNodes(
    way(
      1,
      reverse ? vertices.reversed.toList() : vertices,
      tags: {'highway': highway, 'surface': ?surface},
    ),
    reverse ? nodes.reversed.toList() : nodes,
  );
}

OsmFeature _node({double east = 40, Map<String, String> extra = const {}}) =>
    _parse({
      'type': 'node',
      'id': 99,
      'lat': grid(east, 0).latitude,
      'lon': grid(east, 0).longitude,
      'tags': {'highway': 'crossing', 'crossing:markings': 'no', ...extra},
    });
