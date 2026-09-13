import 'dart:convert';

import '../../map/evidence/osm_evidence.dart';
import '../walk_distance.dart';
import 'analysis_settings.dart';
import 'match_audit.dart';
import 'route_analysis.dart';
import 'surface_rules.dart';
import 'walk_surface_summary.dart';

/// Overlapping observations, NOT a partition or statements of ground truth.
enum EdgeEvidenceFlag {
  noNearbyCandidate,
  noEligibleCandidate,
  failedMatching,
  selectedMissingSurface,
  selectedUnsupportedSurface,
  selectedUnusableSurface,
  supportedNearbyNotSelected,
  supportedActuallySelected,
  supportedSelectedButFinalUnknown,
  sameSupportedFeatureSelectedAtBothEndpoints,
  sameSupportedFeatureSelectedButFinalUnknown,
  supportedAtBothEndpoints,
  supportedEligibleAtBothEndpoints,
  noSupportedEvidenceInCandidateEnvelope,
}

class DiagnosticMeasure {
  const DiagnosticMeasure(this.edges, this.meters);
  final int edges;
  final double meters;
  Map<String, Object> toJson() => {'edges': edges, 'meters': meters};
}

class SampleDiagnostic {
  SampleDiagnostic(this.sample, this.audit)
    : supportedKeys = Set.unmodifiable(_supported(sample, eligibleOnly: false)),
      supportedEligibleKeys = Set.unmodifiable(
        _supported(sample, eligibleOnly: true),
      );

  final SampleAnalysis sample;
  final SampleMatchAudit audit;
  final Set<String> supportedKeys;
  final Set<String> supportedEligibleKeys;
  bool get selectedSupported =>
      sample.selected != null && _known(sample.surface);

  static Set<String> _supported(
    SampleAnalysis sample, {
    required bool eligibleOnly,
  }) => {
    for (final c in sample.candidates)
      if ((!eligibleOnly || c.eligible) &&
          _known(SurfaceRules.derive(c.feature)))
        c.feature.key,
  };

  Map<String, Object?> toJson() => {
    'index': audit.index,
    'sequence': sample.original.sequence,
    'accuracyMeters': sample.original.accuracyMeters,
    'gpsState': sample.gps.state.name,
    'gpsReasons': sample.gps.reasons.map((r) => r.name).toList(),
    'headingDegrees': audit.headingDegrees,
    'matchRadiusMeters': audit.matchRadiusMeters,
    'candidateCount': sample.candidates.length,
    'eligibleCandidateCount': sample.candidates.where((c) => c.eligible).length,
    'candidates': sample.candidates.map(_candidateJson).toList(),
    'independentChoice': _choiceJson(audit.independent),
    'contextualChoice': _choiceJson(audit.contextual),
    'previousAnchor': audit.previousAnchor,
    'nextAnchor': audit.nextAnchor,
    'selectedFeatureKey': sample.selected?.feature.key,
    'confidence': sample.confidence.name,
    'reason': sample.reason.name,
    'surface': surfaceJson(sample.surface),
    'supportedNearbyKeys': supportedKeys.toList()..sort(),
    'supportedEligibleKeys': supportedEligibleKeys.toList()..sort(),
  };
}

class EdgeDiagnostic {
  EdgeDiagnostic(
    this.index,
    this.edge,
    SampleDiagnostic from,
    SampleDiagnostic to,
  ) : meters = WalkDistance.total([edge.from.original, edge.to.original]),
      supportedCommonKeys = Set.unmodifiable(
        from.supportedKeys.intersection(to.supportedKeys),
      ),
      supportedEligibleCommonKeys = Set.unmodifiable(
        from.supportedEligibleKeys.intersection(to.supportedEligibleKeys),
      ) {
    final endpoints = [from, to];
    final selectedSupported = endpoints.any((s) => s.selectedSupported);
    final sameSelected =
        from.selectedSupported &&
        to.selectedSupported &&
        from.sample.selected!.feature.key == to.sample.selected!.feature.key;
    final unknown = !_known(edge.surface);
    flags = Set.unmodifiable({
      if (endpoints.any(
        (s) =>
            s.sample.selected != null &&
            const {
              AnalysisReason.unsupportedSurface,
              AnalysisReason.conflictingSurface,
            }.contains(s.sample.surface.reason),
      ))
        EdgeEvidenceFlag.selectedUnsupportedSurface,
      if (endpoints.any((s) => s.sample.candidates.isEmpty))
        EdgeEvidenceFlag.noNearbyCandidate,
      if (endpoints.any((s) => !s.sample.candidates.any((c) => c.eligible)))
        EdgeEvidenceFlag.noEligibleCandidate,
      if (endpoints.any(
        (s) => const {
          AnalysisReason.weakScore,
          AnalysisReason.ambiguousCandidates,
          AnalysisReason.conflictingNeighbors,
        }.contains(s.sample.reason),
      ))
        EdgeEvidenceFlag.failedMatching,
      if (endpoints.any(
        (s) =>
            s.sample.selected != null &&
            s.sample.surface.reason == AnalysisReason.missingSurface,
      ))
        EdgeEvidenceFlag.selectedMissingSurface,
      if (endpoints.any(
        (s) => s.sample.selected != null && !_known(s.sample.surface),
      ))
        EdgeEvidenceFlag.selectedUnusableSurface,
      if (endpoints.any(
        (s) =>
            s.supportedKeys.any((key) => key != s.sample.selected?.feature.key),
      ))
        EdgeEvidenceFlag.supportedNearbyNotSelected,
      if (selectedSupported) EdgeEvidenceFlag.supportedActuallySelected,
      if (selectedSupported && unknown)
        EdgeEvidenceFlag.supportedSelectedButFinalUnknown,
      if (sameSelected)
        EdgeEvidenceFlag.sameSupportedFeatureSelectedAtBothEndpoints,
      if (sameSelected && unknown)
        EdgeEvidenceFlag.sameSupportedFeatureSelectedButFinalUnknown,
      if (supportedCommonKeys.isNotEmpty)
        EdgeEvidenceFlag.supportedAtBothEndpoints,
      if (supportedEligibleCommonKeys.isNotEmpty)
        EdgeEvidenceFlag.supportedEligibleAtBothEndpoints,
      if (endpoints.every((s) => s.supportedKeys.isEmpty))
        EdgeEvidenceFlag.noSupportedEvidenceInCandidateEnvelope,
    });
  }

  final int index;
  final EdgeAnalysis edge;
  final double meters;
  final Set<String> supportedCommonKeys;
  final Set<String> supportedEligibleCommonKeys;
  late final Set<EdgeEvidenceFlag> flags;

  Map<String, Object?> toJson() => {
    'index': index,
    'fromSampleIndex': index,
    'toSampleIndex': index + 1,
    'meters': meters,
    'elapsedMicroseconds': edge.to.original.recordedAt
        .difference(edge.from.original.recordedAt)
        .inMicroseconds,
    'speedMetersPerSecond': edge.gps.speed,
    'gpsReason': edge.gps.reason.name,
    'reason': edge.reason.name,
    'surface': surfaceJson(edge.surface),
    'fromFeatureKey': edge.from.selected?.feature.key,
    'toFeatureKey': edge.to.selected?.feature.key,
    'flags': flags.map((f) => f.name).toList()..sort(),
    'supportedCommonKeys': supportedCommonKeys.toList()..sort(),
    'supportedEligibleCommonKeys': supportedEligibleCommonKeys.toList()..sort(),
  };
}

class SurfaceDiagnosticAggregate {
  SurfaceDiagnosticAggregate(
    List<SampleDiagnostic> samples,
    List<EdgeDiagnostic> edges,
  ) : total = _measure(edges),
      known = _measure(edges.where((e) => _known(e.edge.surface))),
      unknown = _measure(edges.where((e) => !_known(e.edge.surface))),
      byFinalReason = Map.unmodifiable({
        for (final reason in AnalysisReason.values)
          if (edges.any((e) => e.edge.reason == reason))
            reason: _measure(edges.where((e) => e.edge.reason == reason)),
      }),
      observations = Map.unmodifiable({
        for (final flag in EdgeEvidenceFlag.values)
          flag: _measure(edges.where((e) => e.flags.contains(flag))),
      }),
      scores = Map.unmodifiable({
        'leader': _distribution(
          samples.map((s) => s.audit.contextual.leaderScore),
        ),
        'runnerUp': _distribution(
          samples.map((s) => s.audit.contextual.runnerUpScore),
        ),
        'margin': _distribution(samples.map((s) => s.audit.contextual.margin)),
        'independentLeader': _distribution(
          samples.map((s) => s.audit.independent?.leaderScore),
        ),
        'independentMargin': _distribution(
          samples.map((s) => s.audit.independent?.margin),
        ),
        'bySampleReason': {
          for (final reason in AnalysisReason.values)
            if (samples.any((s) => s.sample.reason == reason))
              reason.name: {
                'leader': _distribution(
                  samples
                      .where((s) => s.sample.reason == reason)
                      .map((s) => s.audit.contextual.leaderScore),
                ),
                'margin': _distribution(
                  samples
                      .where((s) => s.sample.reason == reason)
                      .map((s) => s.audit.contextual.margin),
                ),
              },
        },
      }),
      candidateEligibility = Map.unmodifiable({
        for (final reason in AnalysisReason.values)
          if (samples.any(
            (s) => s.sample.candidates.any((c) => c.reason == reason),
          ))
            reason: samples.fold<int>(
              0,
              (n, s) =>
                  n +
                  s.sample.candidates.where((c) => c.reason == reason).length,
            ),
      });

  final DiagnosticMeasure total;
  final DiagnosticMeasure known;
  final DiagnosticMeasure unknown;
  final Map<AnalysisReason, DiagnosticMeasure> byFinalReason;
  final Map<EdgeEvidenceFlag, DiagnosticMeasure> observations;
  final Map<String, Object?> scores;
  final Map<AnalysisReason, int> candidateEligibility;

  Map<String, Object?> toJson() => {
    'total': total.toJson(),
    'known': known.toJson(),
    'unknown': unknown.toJson(),
    'byFinalReason': {
      for (final e in byFinalReason.entries) e.key.name: e.value.toJson(),
    },
    'observations': {
      for (final e in observations.entries) e.key.name: e.value.toJson(),
    },
    'candidateEligibilityOccurrences': {
      for (final e in candidateEligibility.entries) e.key.name: e.value,
    },
    'sampleScores': scores,
  };
}

/// Local opt-in report; contains OSM identities but no track coordinates or
/// absolute sample timestamps. Never written to the normal walk database.
class SurfaceDiagnostics {
  SurfaceDiagnostics(this.summary, List<SampleMatchAudit> audits) {
    if (audits.length != summary.analysis.samples.length ||
        [for (var i = 0; i < audits.length; i++) audits[i].index != i]
            .contains(true)) {
      throw const FormatException('Audit does not cover the route in order');
    }
    samples = List.unmodifiable([
      for (var i = 0; i < audits.length; i++)
        SampleDiagnostic(summary.analysis.samples[i], audits[i]),
    ]);
    edges = List.unmodifiable([
      for (var i = 0; i < summary.analysis.edges.length; i++)
        EdgeDiagnostic(
          i,
          summary.analysis.edges[i],
          samples[i],
          samples[i + 1],
        ),
    ]);
    aggregate = SurfaceDiagnosticAggregate(samples, edges);
  }

  static const schemaVersion = 1;
  // Change this ID when policy changes, independently of the export schema.
  static const policyVersion = 'mvp-0.1-37e28cc';
  final WalkSurfaceSummary summary;
  late final List<SampleDiagnostic> samples;
  late final List<EdgeDiagnostic> edges;
  late final SurfaceDiagnosticAggregate aggregate;

  Map<String, Object?> toJson() {
    final features = <String, OsmFeature>{
      for (final s in samples)
        for (final c in s.sample.candidates) c.feature.key: c.feature,
    };
    return {
      'schema': 'pathgrain.surface-diagnostics',
      'schemaVersion': schemaVersion,
      'policyVersion': policyVersion,
      'definitions': definitions,
      'settings': {
        'candidateRadiusMeters': AnalysisSettings.candidateRadiusMeters,
        'minimumScore': AnalysisSettings.minimumScore,
        'minimumMargin': AnalysisSettings.minimumMargin,
        'strongMargin': AnalysisSettings.strongMargin,
        'minimumMatchRadiusMeters': AnalysisSettings.minimumMatchRadiusMeters,
        'maximumMatchRadiusMeters': AnalysisSettings.maximumMatchRadiusMeters,
        'accuracyAllowanceMeters': AnalysisSettings.accuracyAllowanceMeters,
        'minimumAmbiguityMeters': AnalysisSettings.minimumAmbiguityMeters,
        'maximumDirectionDegrees': AnalysisSettings.maximumDirectionDegrees,
        'parallelDirectionDegrees': AnalysisSettings.parallelDirectionDegrees,
        'headingWindowSamples': AnalysisSettings.headingWindowSamples,
        'minimumHeadingMeters': AnalysisSettings.minimumHeadingMeters,
        'headingAccuracyFactor': AnalysisSettings.headingAccuracyFactor,
        'goodAccuracyMeters': AnalysisSettings.goodAccuracyMeters,
        'strongAccuracyMeters': AnalysisSettings.strongAccuracyMeters,
        'maximumSpeedMetersPerSecond':
            AnalysisSettings.maximumSpeedMetersPerSecond,
      },
      'pointCount': samples.length,
      'segmentCount': summary.segments.length,
      'aggregate': aggregate.toJson(),
      'features': {
        for (final f in features.values)
          f.key: {
            'type': f.type.name,
            'geometryKind': f.geometryKind.name,
            'isArea': f.isArea,
            'geometryLimitations': f.limitations.map((l) => l.name).toList()
              ..sort(),
            'tags': {
              for (final t in f.tags.entries)
                if (_diagnosticTag(t.key)) t.key: t.value,
            },
            'mappedSurface': surfaceJson(SurfaceRules.derive(f)),
          },
      },
      'samples': samples.map((s) => s.toJson()).toList(),
      'edges': edges.map((e) => e.toJson()).toList(),
      'segments': segmentRows(summary),
    };
  }

  static const definitions = {
    'distances': 'Unrounded haversine meters over original stored edges. No resampling. Final reasons partition edges; observations overlap.',
    'gps': 'Stored points only. Recorder-rejected fixes are absent and cannot be reconstructed. GPS states describe analysis confidence, not points_valid.',
    'supported': 'SurfaceRules.derive returns a non-unknown assignment on that candidate, including the existing narrow grass inference. Tag compatibility is not a verified match.',
    'supportedAtBothEndpoints': 'Broad evidence upper bound: the SAME supported feature occurs in both endpoint candidate lists (current 40 m geometry envelope). Ignores eligibility, GPS, score, vetoes and edge probes. Includes unsupported geometry/access/direction. Not a coverage prediction or ground truth.',
    'supportedEligibleAtBothEndpoints': 'Stricter diagnostic ceiling: the SAME supported feature is eligible at both endpoints. Still ignores GPS, chooser score/vetoes, continuity and interior edge probes.',
    'supportedNearbyNotSelected': 'At either endpoint at least one supported candidate differs from the final selected feature (or no feature is selected). Includes ineligible candidates; can overlap known edges.',
    'supportedActuallySelected': 'At least one endpoint actually selected a supported surface. Counts each incident edge once, not confirmed surface meters.',
    'supportedSelectedButFinalUnknown': 'At least one endpoint selected a supported surface, but the final edge is unknown. Often an unresolved other endpoint, not downstream corruption.',
    'sameSupportedFeatureSelectedButFinalUnknown': 'Both endpoints selected the SAME supported feature, but a later edge gate rejected it.',
    'noSupportedEvidenceInCandidateEnvelope': 'Neither endpoint has a supported mapped candidate. With complete captured evidence this is source scarcity within the current envelope, not proof about the real surface or all OSM.',
    'noNearbyCandidate': 'At least one endpoint has no generated candidates.',
    'noEligibleCandidate': 'At least one endpoint has no eligible candidates, including points that have rejected nearby geometry.',
    'failedMatching': 'At least one endpoint final reason is weakScore, ambiguousCandidates or conflictingNeighbors. GPS/evidence overrides are excluded.',
    'selectedUnsupportedSurface': 'At least one selected endpoint has unsupportedSurface or conflictingSurface; missingSurface is counted separately.',
    'selectedMissingSurface': 'At least one endpoint selected a feature whose surface derivation is missingSurface.',
    'selectedUnusableSurface': 'At least one selected endpoint has unknown surface derivation: missing, unsupported or conflicting tags.',
    'scores': 'Sample-level contextual and independent leaders/margins. Null means absent/not evaluated/no runner, not zero. Summaries exclude null/nonfinite values; p50/p90 use nearest rank.',
    'gates': 'Lists failing predicates from the production chooser after its minimum-score gate. Unsupported-rival rejection takes precedence; subsequent listed predicates do not assert the old short-circuit evaluated them. Parallel rivals can be present yet waived by a same-key neighbor anchor.',
  };
}

List<Map<String, Object?>> segmentRows(WalkSurfaceSummary summary) => [
  for (var i = 0; i < summary.segments.length; i++)
    {
      'ordinal': i,
      'start_edge': summary.segments[i].startEdgeIndex,
      'end_edge': summary.segments[i].endEdgeIndex,
      'surface': summary.segments[i].surface.surface.name,
      'assignment': summary.segments[i].surface.assignment.name,
      'surface_reason': summary.segments[i].surface.reason.name,
      'edge_reason': summary.segments[i].reason.name,
      'from_feature_key': summary.segments[i].fromFeatureKey,
      'to_feature_key': summary.segments[i].toFeatureKey,
    },
];

Map<String, String> surfaceJson(SurfaceAssessment s) => {
  'surface': s.surface.name,
  'assignment': s.assignment.name,
  'reason': s.reason.name,
};

bool _known(SurfaceAssessment s) => s.assignment != SurfaceAssignment.unknown;

DiagnosticMeasure _measure(Iterable<EdgeDiagnostic> edges) => DiagnosticMeasure(
  edges.length,
  edges.fold<double>(0, (meters, e) => meters + e.meters),
);

Map<String, Object?> _distribution(Iterable<double?> values) {
  final finite = values.whereType<double>().where((n) => n.isFinite).toList()
    ..sort();
  double? rank(double p) =>
      finite.isEmpty ? null : finite[(finite.length * p).ceil() - 1];
  return {
    'count': finite.length,
    'absent': values.length - finite.length,
    'minimum': finite.firstOrNull,
    'p50': rank(.5),
    'p90': rank(.9),
    'maximum': finite.lastOrNull,
  };
}

Map<String, Object?>? _choiceJson(MatchChoiceAudit? a) => a == null
    ? null
    : {
        'reason': a.reason.name,
        'leaderKey': a.leaderKey,
        'leaderScore': a.leaderScore,
        'runnerUpScore': a.runnerUpScore,
        'margin': a.margin,
        'selectedKey': a.selectedKey,
        'supportedKey': a.supportedKey,
        'ambiguityEvaluated': a.ambiguityEvaluated,
        'gates': a.gates.map((g) => g.name).toList(),
        'parallelRivals': a.parallelRivals,
        'unsupportedRivals': a.unsupportedRivals,
      };

Map<String, Object?> _candidateJson(MatchCandidate c) => {
  'featureKey': c.feature.key,
  'distanceMeters': c.distanceMeters,
  'directionDegrees': c.directionDegrees,
  'eligible': c.eligible,
  'eligibilityReason': c.reason.name,
  'score': c.score,
  'independentScore': c.score - c.continuityScore,
  'components': {
    'proximity': c.proximityScore,
    'pedestrian': c.pedestrianScore,
    'direction': c.directionScore,
    'gps': c.gpsScore,
    'continuity': c.continuityScore,
  },
};

bool _diagnosticTag(String key) =>
    const {
      'highway',
      'area',
      'area:highway',
      'foot',
      'footway',
      'path',
      'access',
      'smoothness',
      'tracktype',
      'landuse',
      'landcover',
      'natural',
      'type',
      'crossing',
      'crossing:markings',
    }.contains(key) ||
    const [
      'surface',
      'sidewalk',
      'foot',
      'access',
      'footway',
    ].any((prefix) => key == prefix || key.startsWith('$prefix:'));

/// Canonical key ordering makes exports byte-stable, including reordered OSM tags.
/// Nonfinite numeric diagnostics become null; input coordinates must be finite.
String diagnosticJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(_canonical(value));

Object? _canonical(Object? value) {
  if (value is Map<String, dynamic>) {
    return {
      for (final key in value.keys.toList()..sort())
        key: _canonical(value[key]),
    };
  }
  if (value is Iterable) return value.map(_canonical).toList();
  if (value is double && !value.isFinite) return null;
  return value;
}
