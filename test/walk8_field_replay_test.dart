import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/walks/analysis/match_audit.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/surface_diagnostics.dart';
import 'package:pathgrain/walks/analysis/surface_replay.dart';
import 'package:pathgrain/walks/analysis/surface_rules.dart';

import '../tool/capture_input.dart';

void main() {
  final capture = Platform.environment['PATHGRAIN_WALK8_CAPTURE'];
  test(
    'private walk 8 reproduces the field failure and explains evidence loss',
    () async {
      final post =
          '$capture/post-surface-review-20260913-132603/extracted/databases';
      final before = await readSurfaceCapture(
        walkDatabase: '$capture/raw/databases/pathgrain.sqlite',
        evidenceDatabase:
            '$capture/raw/databases/pathgrain_osm_evidence_cache.sqlite',
        walkId: 8,
      );
      final saved = await readSurfaceCapture(
        walkDatabase: '$post/pathgrain.sqlite',
        evidenceDatabase: '$post/pathgrain_osm_evidence_cache.sqlite',
        walkId: 8,
      );
      expect(before.headers, isEmpty);
      expect(before.persistedSegments, isEmpty);
      expect(saved.headers, [
        {'point_count': 191, 'points_valid': 1},
      ]);
      // Compare without dumping a private coordinate sequence on assertion failure.
      expect(
        diagnosticJson(before.input.toJson()['points']) ==
            diagnosticJson(saved.input.toJson()['points']),
        isTrue,
        reason: 'Stored route changed between before/after snapshots',
      );
      expect(saved.input.points, hasLength(191));
      expect(
        saved.input.points.map((p) => p.sequence),
        List.generate(191, (i) => i),
      );
      expect(before.input.cells.length, 1);
      expect(saved.input.cells.length, 2);
      final result = SurfaceReplay.run(saved.input);
      final d = result.diagnostics;
      expect(result.complete, isTrue);
      expect(result.evidence.featureOccurrences, 708);
      expect(result.evidence.features, hasLength(656));
      expect(result.evidence.duplicateOccurrences, 52);
      final versions = <String, List<String>>{};
      for (final cell in saved.input.cells.values) {
        for (final feature in cell.evidence.features) {
          (versions[feature.key] ??= []).add(diagnosticJson(feature.raw));
        }
      }
      expect(versions.values.where((v) => v.length > 1).length, 52);
      expect(versions.values.every((v) => v.toSet().length == 1), isTrue);
      expect(d.summary.segments, hasLength(80));
      expect(segmentRows(d.summary), saved.persistedSegments);
      expect(d.aggregate.total.edges, 190);
      expect(d.aggregate.total.meters, closeTo(1446.4233576907043, 1e-6));
      expect(d.aggregate.known.meters, 0);
      expect(
        d.edges.every(
          (e) => e.edge.surface.assignment == SurfaceAssignment.unknown,
        ),
        isTrue,
      );
      const reasons = {
        AnalysisReason.ambiguousCandidates: (64, 494.30300716896267),
        AnalysisReason.weakScore: (47, 334.8736432464541),
        AnalysisReason.missingSurface: (43, 327.082911161872),
        AnalysisReason.noCandidate: (23, 161.5517681170357),
        AnalysisReason.uncertainEndpoint: (10, 83.45600946165489),
        AnalysisReason.fastMotion: (1, 30.144973279886507),
        AnalysisReason.conflictingNeighbors: (2, 15.01104525483744),
      };
      expect(d.aggregate.byFinalReason.keys.toSet(), reasons.keys.toSet());
      for (final entry in reasons.entries) {
        expect(d.aggregate.byFinalReason[entry.key]!.edges, entry.value.$1);
        expect(
          d.aggregate.byFinalReason[entry.key]!.meters,
          closeTo(entry.value.$2, 1e-6),
        );
      }
      final candidates = [for (final s in d.samples) ...s.sample.candidates];
      final nearby = {for (final c in candidates) c.feature.key: c.feature};
      final footways = nearby.values.where(
        (f) => f.tags['highway'] == 'footway',
      );
      expect(footways, hasLength(51));
      expect(
        footways.where((f) => !f.tags.containsKey('surface')),
        hasLength(50),
      );
      final tagged = nearby.values.where((f) => f.tags.containsKey('surface'));
      expect(tagged, hasLength(8));
      expect(
        tagged.every(
          (f) => SurfaceRules.derive(f).assignment != SurfaceAssignment.unknown,
        ),
        isTrue,
      );
      final pavingFootway = tagged.singleWhere(
        (f) => f.tags['highway'] == 'footway',
      );
      expect(
        candidates
            .where((c) => c.feature.key == pavingFootway.key)
            .map((c) => c.reason)
            .toSet(),
        {AnalysisReason.tooFar, AnalysisReason.directionConflict},
      );
      final pavingArea = tagged.singleWhere((f) => f.isArea);
      expect(
        candidates
            .where((c) => c.feature.key == pavingArea.key)
            .every((c) => c.reason == AnalysisReason.unsupportedGeometry),
        isTrue,
      );
      final weak = d.samples.where(
        (s) => s.sample.reason == AnalysisReason.weakScore,
      );
      expect(weak, hasLength(44));
      expect(
        weak.every(
          (s) => !s.sample.candidates.first.feature.tags.containsKey('surface'),
        ),
        isTrue,
      );
      final ambiguous = d.samples.where(
        (s) => s.sample.reason == AnalysisReason.ambiguousCandidates,
      );
      expect(ambiguous, hasLength(55));
      expect(
        ambiguous.where(
          (s) => !s.audit.contextual.gates.contains(MatchGate.scoreMargin),
        ),
        hasLength(30),
      );
      expect(d.samples.where((s) => s.selectedSupported), hasLength(1));
      expect(d.samples[17].sample.surface.surface, CanonicalSurface.asphalt);
      expect(
        d
            .aggregate
            .observations[EdgeEvidenceFlag.supportedActuallySelected]!
            .meters,
        closeTo(20.522298625573516, 1e-6),
      );
      expect(
        d
            .aggregate
            .observations[EdgeEvidenceFlag.supportedEligibleAtBothEndpoints]!
            .edges,
        38,
      );
      expect(
        d
            .aggregate
            .observations[EdgeEvidenceFlag.supportedEligibleAtBothEndpoints]!
            .meters,
        closeTo(288.78414474540455, 1e-6),
      );
      expect(
        d
            .aggregate
            .observations[EdgeEvidenceFlag.supportedAtBothEndpoints]!
            .meters,
        closeTo(1157.4396480324456, 1e-6),
      );
      for (final s in d.samples) {
        expect(
          s.sample.candidates.map((c) => c.feature.key).toSet().length,
          s.sample.candidates.length,
        );
      }
      final repeated = SurfaceReplay.run(
        SurfaceReplayInput.fromJson(
          jsonDecode(diagnosticJson(saved.input.toJson()))
              as Map<String, dynamic>,
        ),
      );
      expect(
        diagnosticJson(repeated.toJson()),
        diagnosticJson(result.toJson()),
      );
    },
    skip: capture == null
        ? 'Private capture opt-in: set PATHGRAIN_WALK8_CAPTURE; raw tracks are never fixtures.'
        : false,
  );
}
