import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/walks/analysis/match_audit.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/surface_diagnostics.dart';
import 'package:pathgrain/walks/analysis/surface_replay.dart';
import 'package:pathgrain/walks/walk_distance.dart';

import 'support/analysis_fixtures.dart';
import 'support/replay_fixtures.dart';

void main() {
  test(
    'same supported endpoint selections can still fail an interior edge probe',
    () {
      final points = [
        for (final (i, east) in [-22.0, -12.0, -2.0, 32.0, 42.0, 52.0].indexed)
          sample(i, east, 0, accuracy: 3, seconds: i * 12.0),
      ];
      final d = SurfaceReplay.run(
        replayInput(points, [
          way(1, [(-30, 0), (0, 0), (0, 50), (30, 50), (30, 0), (90, 0)]),
        ]),
      ).diagnostics;
      expect(d.edges[2].edge.reason, AnalysisReason.edgeOffGeometry);
      expect(
        d.edges[2].flags,
        contains(EdgeEvidenceFlag.sameSupportedFeatureSelectedButFinalUnknown),
      );
      expect(
        d
            .aggregate
            .observations[EdgeEvidenceFlag
                .sameSupportedFeatureSelectedButFinalUnknown]!
            .edges,
        1,
      );
      expect(d.samples[2].selectedSupported, isTrue);
      expect(d.samples[3].selectedSupported, isTrue);
    },
  );

  test('diagnostic tags retain scoped conflicts and explain unsupported selections', () {
    final d = SurfaceReplay.run(
      replayInput(straight(), [
        straightPath(
          tags: {
            'highway': 'footway',
            'surface': 'asphalt',
            'surface:forward': 'concrete',
            'smoothness': 'good',
            'tracktype': 'grade1',
            'name': 'Unnecessary place name',
          },
        ),
      ]),
    ).diagnostics;
    expect(
      d.samples[4].sample.surface.reason,
      AnalysisReason.conflictingSurface,
    );
    expect(
      d
          .aggregate
          .observations[EdgeEvidenceFlag.selectedUnsupportedSurface]!
          .edges,
      8,
    );
    expect(
      d.aggregate.observations[EdgeEvidenceFlag.selectedMissingSurface]!.edges,
      0,
    );
    final tags = (d.toJson()['features'] as Map)['way/1']['tags'] as Map;
    expect(tags['surface:forward'], 'concrete');
    expect(tags['smoothness'], 'good');
    expect(tags['tracktype'], 'grade1');
    expect(tags, isNot(contains('name')));
  });

  test('final reasons partition original meters; overlapping observations are separate', () {
    final points = straight();
    final d = SurfaceReplay.run(replayInput(points, [straightPath()]))
        .diagnostics;
    expect(d.edges, hasLength(9));
    expect(d.aggregate.total.meters, WalkDistance.total(points));
    expect(d.aggregate.known.edges, 7);
    expect(d.aggregate.unknown.edges, 2);
    expect(
      d.aggregate.byFinalReason[AnalysisReason.uncertainEndpoint]!.edges,
      2,
    );
    expect(d.aggregate.byFinalReason[AnalysisReason.matched]!.edges, 7);
    expect(
      d.aggregate.byFinalReason.values.fold<int>(0, (n, m) => n + m.edges),
      9,
    );
    expect(
      d.aggregate.byFinalReason.values.fold<double>(0, (n, m) => n + m.meters),
      closeTo(d.aggregate.total.meters, 1e-9),
    );
    expect(
      d.aggregate.known.meters + d.aggregate.unknown.meters,
      closeTo(d.aggregate.total.meters, 1e-9),
    );
    expect(
      d
          .aggregate
          .observations[EdgeEvidenceFlag.supportedSelectedButFinalUnknown]!
          .edges,
      1,
    );
    expect(
      d
          .aggregate
          .observations[EdgeEvidenceFlag
              .sameSupportedFeatureSelectedButFinalUnknown]!
          .edges,
      0,
    );
  });

  test(
    'untagged footway wins over asphalt road: missing surface is observable',
    () {
      final d = SurfaceReplay.run(
        replayInput(straight(), [
          straightPath(tags: {'highway': 'footway'}),
          straightPath(
            id: 2,
            north: 8,
            tags: {'highway': 'residential', 'surface': 'asphalt'},
          ),
        ]),
      ).diagnostics;
      expect(d.aggregate.known.edges, 0);
      expect(
        d.aggregate.byFinalReason[AnalysisReason.missingSurface]!.edges,
        7,
      );
      expect(
        d
            .aggregate
            .observations[EdgeEvidenceFlag.selectedMissingSurface]!
            .edges,
        8,
      );
      expect(
        d.aggregate.observations[EdgeEvidenceFlag.failedMatching]!.edges,
        0,
      );
      expect(
        d
            .aggregate
            .observations[EdgeEvidenceFlag.supportedNearbyNotSelected]!
            .edges,
        9,
      );
      expect(
        d
            .aggregate
            .observations[EdgeEvidenceFlag.supportedEligibleAtBothEndpoints]!
            .edges,
        9,
      );
      expect(
        d
            .aggregate
            .observations[EdgeEvidenceFlag.supportedActuallySelected]!
            .edges,
        0,
      );
      expect(d.samples[4].sample.selected!.feature.key, 'way/1');
      expect(d.samples[4].audit.contextual.gates, isEmpty);
    },
  );

  test(
    'strong score margin does not conceal an additional pedestrian veto',
    () {
      final d = SurfaceReplay.run(
        replayInput(straight(north: 0), [
          straightPath(tags: {'highway': 'footway', 'surface': 'asphalt'}),
          straightPath(id: 2, north: 6.5, tags: {'highway': 'footway'}),
        ]),
      ).diagnostics;
      final s = d.samples[4];
      expect(s.sample.reason, AnalysisReason.ambiguousCandidates);
      expect(s.audit.contextual.margin, greaterThan(20));
      expect(s.audit.contextual.gates, [MatchGate.parallelAmbiguity]);
      expect(s.audit.contextual.parallelRivals, ['way/2']);
      expect(
        d
            .aggregate
            .observations[EdgeEvidenceFlag.supportedEligibleAtBothEndpoints]!
            .edges,
        9,
      );
      expect(d.aggregate.known.edges, 0);
    },
  );

  test(
    'weak score without heading does not masquerade as missing source tags',
    () {
      final points = [for (var i = 0; i < 10; i++) sample(i, i * 1.0, 2)];
      final d = SurfaceReplay.run(
        replayInput(points, [
          straightPath(tags: {'highway': 'residential', 'surface': 'asphalt'}),
        ]),
      ).diagnostics;
      final s = d.samples[4];
      expect(s.audit.headingDegrees, isNull);
      expect(s.audit.contextual.leaderScore, lessThan(62));
      expect(s.audit.contextual.runnerUpScore, isNull);
      expect(s.audit.contextual.margin, isNull);
      expect(s.audit.contextual.ambiguityEvaluated, isFalse);
      expect(s.audit.contextual.gates, [MatchGate.minimumScore]);
      expect(d.aggregate.byFinalReason[AnalysisReason.weakScore]!.edges, 7);
      expect(
        d
            .aggregate
            .observations[EdgeEvidenceFlag.selectedMissingSurface]!
            .edges,
        0,
      );
      expect(
        d
            .aggregate
            .observations[EdgeEvidenceFlag.supportedNearbyNotSelected]!
            .edges,
        9,
      );
    },
  );

  test(
    'nearby paving footway can be direction rejected despite usable taxonomy',
    () {
      final d = SurfaceReplay.run(
        replayInput(straight(north: 0), [
          way(
            3,
            [(40, -25), (40, 25)],
            tags: {'highway': 'footway', 'surface': 'paving_stones'},
          ),
        ]),
      ).diagnostics;
      final s = d.samples[4];
      expect(
        s.sample.candidates.single.reason,
        AnalysisReason.directionConflict,
      );
      expect(s.supportedKeys, {'way/3'});
      expect(s.supportedEligibleKeys, isEmpty);
      expect(s.sample.reason, AnalysisReason.noCandidate);
      expect(s.audit.contextual.gates, [MatchGate.noEligibleCandidate]);
      expect(d.edges[4].flags, contains(EdgeEvidenceFlag.noEligibleCandidate));
      expect(
        d.edges[4].flags,
        isNot(contains(EdgeEvidenceFlag.noNearbyCandidate)),
      );
      expect(
        d.edges[4].flags,
        contains(EdgeEvidenceFlag.supportedAtBothEndpoints),
      );
      expect(
        d.edges[4].flags,
        isNot(contains(EdgeEvidenceFlag.supportedEligibleAtBothEndpoints)),
      );
    },
  );

  test('concave tagged pedestrian area is visible as unsupported geometry and a veto', () {
    final d = SurfaceReplay.run(
      replayInput(straight(north: 0), [
        straightPath(tags: {'highway': 'footway'}),
        way(
          4,
          [
            (-30, -20),
            (150, -20),
            (150, 20),
            (45, 20),
            (40, 4),
            (35, 20),
            (-30, 20),
            (-30, -20),
          ],
          tags: {'area:highway': 'pedestrian', 'surface': 'paving_stones'},
        ),
      ]),
    ).diagnostics;
    final s = d.samples[4];
    final area = s.sample.candidates.singleWhere(
      (c) => c.feature.key == 'way/4',
    );
    expect(area.reason, AnalysisReason.unsupportedGeometry);
    expect(s.supportedKeys, contains('way/4'));
    expect(s.supportedEligibleKeys, isEmpty);
    expect(s.audit.contextual.unsupportedRivals, ['way/4']);
    expect(s.audit.contextual.gates, contains(MatchGate.unsupportedRival));
    final json = d.toJson();
    expect(
      ((json['features'] as Map)['way/4']['mappedSurface'] as Map)['surface'],
      'tile',
    );
  });

  test(
    'missing and unsupported surface are distinct from absence of candidates',
    () {
      for (final surface in [null, 'gravel']) {
        final d = SurfaceReplay.run(
          replayInput(straight(), [
            straightPath(tags: {'highway': 'footway', 'surface': ?surface}),
          ]),
        ).diagnostics;
        final reason = surface == null
            ? AnalysisReason.missingSurface
            : AnalysisReason.unsupportedSurface;
        expect(d.aggregate.byFinalReason[reason]!.edges, 7);
        expect(
          d
              .aggregate
              .observations[EdgeEvidenceFlag.selectedUnusableSurface]!
              .edges,
          8,
        );
        expect(
          d
              .aggregate
              .observations[EdgeEvidenceFlag.selectedMissingSurface]!
              .edges,
          surface == null ? 8 : 0,
        );
        expect(
          d
              .aggregate
              .observations[EdgeEvidenceFlag
                  .noSupportedEvidenceInCandidateEnvelope]!
              .edges,
          9,
        );
        expect(
          d.aggregate.observations[EdgeEvidenceFlag.noNearbyCandidate]!.edges,
          0,
        );
      }
      final empty = SurfaceReplay.run(replayInput(straight(), [])).diagnostics;
      expect(
        empty.aggregate.byFinalReason[AnalysisReason.noCandidate]!.edges,
        7,
      );
      expect(
        empty.aggregate.observations[EdgeEvidenceFlag.noNearbyCandidate]!.edges,
        9,
      );
      expect(
        empty
            .aggregate
            .observations[EdgeEvidenceFlag.selectedMissingSurface]!
            .edges,
        0,
      );
    },
  );
}
