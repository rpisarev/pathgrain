import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/map/evidence/evidence_assembly.dart';
import 'package:pathgrain/map/evidence/geographic_cell.dart';
import 'package:pathgrain/map/evidence/osm_evidence.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/route_matcher.dart';
import 'package:pathgrain/walks/analysis/surface_diagnostics.dart';
import 'package:pathgrain/walks/analysis/surface_replay.dart';
import 'package:pathgrain/walks/analysis/walk_surface_summary.dart';
import 'package:pathgrain/walks/walk_models.dart';

import 'support/analysis_fixtures.dart';
import 'support/replay_fixtures.dart';

void main() {
  test(
    'JSON retains submillisecond cache ordering instead of creating a cell tie',
    () {
      final points = [sample(0, 0, 0), sample(1, 1800, 0), sample(2, 1810, 0)];
      final source = replayInput(points, [straightPath()]);
      final keys = source.requiredCells;
      expect(keys, hasLength(2));
      final asphalt = replayInput(straight(), [
        straightPath(tags: {'highway': 'footway', 'surface': 'asphalt'}),
      ]).cells.values.single.evidence;
      final input = SurfaceReplayInput(
        points: points,
        namespace: source.namespace,
        cells: {
          keys.first: CachedEvidence(
            evidence: source.cells.values.first.evidence,
            fetchedAt: DateTime.fromMicrosecondsSinceEpoch(1200, isUtc: true),
          ),
          keys.last: CachedEvidence(
            evidence: asphalt,
            fetchedAt: DateTime.fromMicrosecondsSinceEpoch(1100, isUtc: true),
          ),
        },
      );
      final restored = SurfaceReplayInput.fromJson(input.toJson());
      expect(
        restored.cells[keys.first]!.fetchedAt.microsecondsSinceEpoch,
        1200,
      );
      expect(
        SurfaceReplay.run(restored).evidence.features.single.tags['surface'],
        'grass',
      );
      expect(
        diagnosticJson(SurfaceReplay.run(restored).toJson()),
        diagnosticJson(SurfaceReplay.run(input).toJson()),
      );
    },
  );

  test('relative input timestamps retain microseconds and sequence gaps', () {
    final points = [
      for (final p in straight())
        WalkPoint(
          walkId: p.walkId,
          sequence: p.sequence < 4 ? p.sequence : p.sequence + 1,
          latitude: p.latitude,
          longitude: p.longitude,
          accuracyMeters: p.accuracyMeters,
          recordedAt: p.recordedAt.add(
            Duration(microseconds: p.sequence * 123),
          ),
        ),
    ];
    final input = replayInput(points, [straightPath()]);
    final restored = SurfaceReplayInput.fromJson(input.toJson());
    expect(
      restored.points[1].recordedAt
          .difference(restored.points[0].recordedAt)
          .inMicroseconds,
      8000123,
    );
    final result = SurfaceReplay.run(restored);
    expect(result.diagnostics.edges[3].edge.reason, AnalysisReason.sequenceGap);
    expect(
      diagnosticJson(result.toJson()),
      diagnosticJson(SurfaceReplay.run(input).toJson()),
    );
  });

  test(
    'replay, JSON roundtrip and reordered evidence are byte deterministic',
    () {
      final input = replayInput(straight(), [
        straightPath(),
        straightPath(id: 2, north: 30),
      ]);
      final expected = diagnosticJson(SurfaceReplay.run(input).toJson());
      final decoded =
          jsonDecode(diagnosticJson(input.toJson())) as Map<String, dynamic>;
      final roundtrip = SurfaceReplayInput.fromJson(decoded);
      for (var i = 0; i < 3; i++) {
        expect(diagnosticJson(SurfaceReplay.run(roundtrip).toJson()), expected);
      }
      for (final cell in decoded['cells'] as List) {
        cell['evidence']['elements'] = (cell['evidence']['elements'] as List)
            .reversed
            .toList();
      }
      expect(
        diagnosticJson(
          SurfaceReplay.run(SurfaceReplayInput.fromJson(decoded)).toJson(),
        ),
        expected,
      );
      final report = jsonDecode(expected) as Map;
      expect(report['schemaVersion'], 1);
      expect(report['policyVersion'], 'mvp-0.1-37e28cc');
      expect(expected, isNot(contains('latitude')));
      expect(expected, isNot(contains('recorded_at')));
      expect(expected, isNot(contains('Infinity')));
      expect(decoded['points'].first['elapsedMicroseconds'], 0);
      expect(decoded['points'].first, isNot(contains('walkId')));
    },
  );

  test(
    'opt-in audit preserves ordinary matcher outputs and segment provenance',
    () {
      final points = straight();
      final features = [straightPath(), straightPath(id: 2, north: 8)];
      final plain = RouteMatcher.analyze(points, features);
      final replay = SurfaceReplay.run(replayInput(points, features));
      final traced = replay.diagnostics.summary.analysis;
      expect(
        segmentRows(replay.diagnostics.summary),
        segmentRows(WalkSurfaceSummary.fromAnalysis(plain)),
      );
      for (var i = 0; i < points.length; i++) {
        final a = plain.samples[i];
        final b = traced.samples[i];
        expect(b.original, same(points[i]));
        expect(
          [
            b.reason,
            b.confidence,
            b.selected?.feature.key,
            b.surface.surface,
            b.surface.reason,
          ],
          [
            a.reason,
            a.confidence,
            a.selected?.feature.key,
            a.surface.surface,
            a.surface.reason,
          ],
        );
        expect(
          b.candidates.map(
            (c) => [
              c.feature.key,
              c.reason,
              c.score,
              c.distanceMeters,
              c.directionDegrees,
            ],
          ),
          a.candidates.map(
            (c) => [
              c.feature.key,
              c.reason,
              c.score,
              c.distanceMeters,
              c.directionDegrees,
            ],
          ),
        );
      }
    },
  );

  test('shared assembly deduplicates identity; timestamp and numeric cell ties are stable', () {
    final older = replayInput(straight(), [straightPath()]).cells.values.single;
    final newer = replayInput(straight(), [
      straightPath(tags: {'highway': 'footway', 'surface': 'asphalt'}),
    ]).cells.values.single;
    const low = GeographicCell(2, 3);
    const high = GeographicCell(10, 3);
    for (final entries in [
      {high: newer, low: older},
      {low: older, high: newer},
    ]) {
      final assembled = EvidenceAssembly(entries);
      expect(assembled.features, hasLength(1));
      expect(assembled.featureOccurrences, 2);
      expect(assembled.duplicateOccurrences, 1);
      expect(assembled.features.single.tags['surface'], 'asphalt');
    }
    final assembled = EvidenceAssembly({
      high: newer,
      low: CachedEvidence(
        evidence: older.evidence,
        fetchedAt: DateTime.utc(2027),
      ),
    });
    expect(assembled.features.single.tags['surface'], 'grass');
    // Same numeric ID, distinct element types are distinct identities.
    final node = OsmEvidence.parse(
      '{"elements":[{"type":"node","id":1,"lat":1,"lon":2}]}',
    );
    final distinct = EvidenceAssembly({
      low: older,
      high: CachedEvidence(evidence: node, fetchedAt: DateTime.utc(2026)),
    });
    expect(distinct.features.map((f) => f.key), ['node/1', 'way/1']);
  });

  test('overlapping route cells yield one candidate per feature and ignore unrelated history', () {
    // Fabricated points straddle a cell boundary; duplicate objects retain identity.
    final points = [sample(0, 0, 0), sample(1, 1800, 0), sample(2, 1810, 0)];
    final input = replayInput(points, [straightPath()]);
    expect(input.requiredCells.length, greaterThan(1));
    final withHistory = SurfaceReplayInput(
      points: points,
      namespace: input.namespace,
      cells: {
        ...input.cells,
        const GeographicCell(1, 1): input.cells.values.first,
      },
    );
    expect(withHistory.cells.length, input.cells.length);
    final result = SurfaceReplay.run(withHistory);
    expect(result.evidence.features, hasLength(1));
    expect(result.evidence.duplicateOccurrences, input.cells.length - 1);
    for (final s in result.diagnostics.samples) {
      expect(
        s.sample.candidates.length,
        s.sample.candidates.map((c) => c.feature.key).toSet().length,
      );
    }
  });

  test('missing cell and unparsed evidence keep supported potential distinct from coverage', () {
    final input = replayInput(straight(), [straightPath()]);
    final empty = SurfaceReplay.run(
      SurfaceReplayInput(
        points: input.points,
        cells: {},
        namespace: input.namespace,
      ),
    );
    expect(empty.complete, isFalse);
    expect(empty.diagnostics.aggregate.known.meters, 0);
    expect(
      empty.diagnostics.samples[4].sample.reason,
      AnalysisReason.evidenceIncomplete,
    );
    final cell = input.cells.keys.single;
    final partial = SurfaceReplay.run(
      SurfaceReplayInput(
        points: input.points,
        namespace: input.namespace,
        cells: {
          cell: CachedEvidence(
            fetchedAt: DateTime.utc(2026),
            evidence: OsmEvidence.parse(
              jsonEncode({
                'elements': [
                  straightPath().raw,
                  {'type': 'unrecognized', 'id': 90},
                ],
              }),
            ),
          ),
        },
      ),
    );
    expect(partial.complete, isFalse);
    expect(partial.evidence.unparsedElements, 1);
    expect(partial.diagnostics.aggregate.known.meters, 0);
    expect(
      partial
          .diagnostics
          .aggregate
          .observations[EdgeEvidenceFlag.supportedAtBothEndpoints]!
          .edges,
      9,
    );
    expect(partial.diagnostics.samples[4].audit.independent, isNull);
  });

  test('empty/single/stationary routes account for zero meters without JSON nonfinite values', () {
    for (final points in [
      <Never>[],
      [sample(0, 0, 0)],
      [sample(0, 0, 0), sample(1, 0, 0)],
    ]) {
      // Typed below to retain the empty-route case without fabricated analysis.
      final input = replayInput(points.cast(), [straightPath()]);
      final report = SurfaceReplay.run(input);
      expect(report.diagnostics.aggregate.total.meters, 0);
      expect(
        () => jsonDecode(diagnosticJson(report.toJson())),
        returnsNormally,
      );
    }
  });

  test('version and duplicate-cell errors are explicit', () {
    final json = replayInput(straight(), []).toJson();
    expect(
      () => SurfaceReplayInput.fromJson({...json, 'schemaVersion': 99}),
      throwsFormatException,
    );
    final cells = json['cells'] as List;
    expect(
      () => SurfaceReplayInput.fromJson({
        ...json,
        'cells': [...cells, ...cells],
      }),
      throwsFormatException,
    );
  });
}
