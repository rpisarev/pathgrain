import 'dart:math' as math;

import '../../map/evidence/geographic_cell.dart';
import '../../map/evidence/osm_evidence.dart';
import '../walk_models.dart';
import 'analysis_settings.dart';
import 'gps_confidence.dart';
import 'route_analysis.dart';
import 'route_geometry.dart';
import 'surface_rules.dart';

/// Pure, synchronous, local experiment over already loaded evidence.
/// Has no database, provider, clock, logger, or serialization dependency.
abstract final class RouteMatcher {
  static RouteAnalysis analyze(
    List<WalkPoint> points,
    List<OsmFeature> features, {
    bool evidenceComplete = true,
  }) {
    final gps = GpsConfidence.assess(points);
    final candidates = <List<MatchCandidate>>[];
    for (var i = 0; i < points.length; i++) {
      final heading = _heading(points, gps.edges, i);
      candidates.add(
        [
          if (RouteGeometry.valid(points[i]))
            for (final feature in features)
              if (_candidate(points[i], gps.samples[i], heading, feature)
                  case final MatchCandidate candidate)
                candidate,
        ]..sort(_compare),
      );
    }
    // Independent winners only. Context never promotes another context winner:
    // there is no recursive propagation or arbitrary initial nearest-way snap.
    final anchors = [
      for (var i = 0; i < points.length; i++)
        gps.samples[i].isStable && evidenceComplete
            ? _choose(candidates[i], points[i]).candidate?.feature.key
            : null,
    ];
    final samples = <SampleAnalysis>[];
    for (var i = 0; i < points.length; i++) {
      final previous = i > 0 && gps.edges[i - 1].isStable
          ? anchors[i - 1]
          : null;
      final next = i + 1 < points.length && gps.edges[i].isStable
          ? anchors[i + 1]
          : null;
      final neighbors = [?previous, ?next];
      final scored =
          candidates[i]
              .map(
                (candidate) => candidate.withContinuity(
                  neighbors.fold<double>(
                    0,
                    (score, key) =>
                        score +
                        (key == candidate.feature.key
                            ? AnalysisSettings.neighborSupportWeight
                            : -AnalysisSettings.neighborConflictWeight),
                  ),
                ),
              )
              .toList()
            ..sort(_compare);
      final choice = _choose(
        scored,
        points[i],
        supportedKey: previous != null && previous == next ? previous : null,
      );
      var reason = choice.reason;
      MatchCandidate? selected = choice.candidate;
      if (!gps.samples[i].isStable) {
        selected = null;
        reason = AnalysisReason.gpsUncertain;
      } else if (!evidenceComplete) {
        selected = null;
        reason = AnalysisReason.evidenceIncomplete;
      } else if (previous != null && next != null && previous != next) {
        selected = null;
        reason = AnalysisReason.conflictingNeighbors;
      }
      final independentlyChosen =
          selected != null && anchors[i] == selected.feature.key;
      if (selected != null && !independentlyChosen) {
        reason = AnalysisReason.continuitySupported;
      }
      final confidence = selected == null
          ? MatchConfidence.none
          : independentlyChosen &&
                points[i].accuracyMeters <=
                    AnalysisSettings.strongAccuracyMeters &&
                _margin(candidates[i]) >= AnalysisSettings.strongMargin &&
                (selected.directionDegrees != null || selected.feature.isArea)
          ? MatchConfidence.strong
          : MatchConfidence.supported;
      samples.add(
        SampleAnalysis(
          original: points[i],
          gps: gps.samples[i],
          candidates: scored,
          selected: selected,
          confidence: confidence,
          reason: reason,
          surface: selected == null
              ? SurfaceAssessment.unknown(reason)
              : SurfaceRules.derive(selected.feature),
        ),
      );
    }
    final edges = <EdgeAnalysis>[];
    for (var i = 1; i < samples.length; i++) {
      final a = samples[i - 1];
      final b = samples[i];
      var reason = AnalysisReason.matched;
      if (!gps.edges[i - 1].isStable) {
        reason = gps.edges[i - 1].reason;
      } else if (a.selected == null || b.selected == null) {
        reason = a.selected == null ? a.reason : b.reason;
      } else if (a.selected!.feature.key != b.selected!.feature.key) {
        reason = AnalysisReason.differentObjects;
      } else if (!_edgeOnFeature(a, b)) {
        reason = AnalysisReason.edgeOffGeometry;
      } else if (a.surface.assignment == SurfaceAssignment.unknown ||
          b.surface.assignment == SurfaceAssignment.unknown) {
        reason = a.surface.assignment == SurfaceAssignment.unknown
            ? a.surface.reason
            : b.surface.reason;
      }
      edges.add(
        EdgeAnalysis(
          from: a,
          to: b,
          gps: gps.edges[i - 1],
          reason: reason,
          surface: reason == AnalysisReason.matched
              ? a.surface
              : SurfaceAssessment.unknown(reason),
        ),
      );
    }
    return RouteAnalysis(samples: samples, edges: edges);
  }

  static double _radius(WalkPoint p) =>
      (p.accuracyMeters.isFinite
              ? p.accuracyMeters + AnalysisSettings.accuracyAllowanceMeters
              : 0.0)
          .clamp(
            AnalysisSettings.minimumMatchRadiusMeters,
            AnalysisSettings.maximumMatchRadiusMeters,
          );

  static double? _heading(
    List<WalkPoint> points,
    List<GpsEdgeAssessment> edges,
    int i,
  ) {
    var start = i;
    var end = i;
    while (start > 0 &&
        i - start < AnalysisSettings.headingWindowSamples &&
        edges[start - 1].isStable) {
      start--;
    }
    while (end + 1 < points.length &&
        end - i < AnalysisSettings.headingWindowSamples &&
        edges[end].isStable) {
      end++;
    }
    if (start == end) return null;
    final length = RouteGeometry.distance(points[start], points[end]);
    final requiredLength = math.max(
      AnalysisSettings.minimumHeadingMeters,
      math.max(points[start].accuracyMeters, points[end].accuracyMeters) *
          AnalysisSettings.headingAccuracyFactor,
    );
    return length >= requiredLength
        ? RouteGeometry.bearing(points[start], points[end])
        : null;
  }

  static MatchCandidate? _candidate(
    WalkPoint p,
    GpsAssessment gps,
    double? heading,
    OsmFeature feature,
  ) {
    final hit = RouteGeometry.inspect(feature, RouteGeometry.coordinate(p));
    if (!hit.distance.isFinite ||
        hit.distance > AnalysisSettings.candidateRadiusMeters) {
      return null;
    }
    final pedestrian = _pedestrian(feature);
    final angle = heading == null || hit.bearing == null
        ? null
        : RouteGeometry.directionDifference(heading, hit.bearing!);
    var reason = pedestrian.reason;
    if (!hit.supported) {
      reason = AnalysisReason.unsupportedGeometry;
    } else if (reason == AnalysisReason.eligible) {
      if (hit.distance > _radius(p)) {
        reason = AnalysisReason.tooFar;
      } else if (feature.isArea &&
          (!hit.insideArea ||
              hit.boundaryDistance <=
                  p.accuracyMeters +
                      AnalysisSettings.areaBoundaryAllowanceMeters)) {
        reason = AnalysisReason.areaBoundary;
      } else if (angle != null &&
          angle > AnalysisSettings.maximumDirectionDegrees) {
        reason = AnalysisReason.directionConflict;
      }
    }
    return MatchCandidate(
      feature: feature,
      distanceMeters: hit.distance,
      directionDegrees: angle,
      proximityScore:
          AnalysisSettings.proximityWeight *
          (1 - hit.distance / _radius(p)).clamp(0.0, 1.0),
      pedestrianScore: pedestrian.score,
      directionScore: feature.isArea
          ? AnalysisSettings.areaDirectionWeight
          : angle == null
          ? 0
          : AnalysisSettings.directionWeight *
                (1 - angle / AnalysisSettings.maximumDirectionDegrees).clamp(
                  0.0,
                  1.0,
                ),
      gpsScore: !gps.isStable
          ? 0
          : p.accuracyMeters <= AnalysisSettings.strongAccuracyMeters
          ? AnalysisSettings.gpsWeight
          : AnalysisSettings.gpsWeight / 2,
      reason: reason,
    );
  }

  static ({double score, AnalysisReason reason}) _pedestrian(
    OsmFeature feature,
  ) {
    final tags = feature.tags;
    final foot = tags['foot'];
    final allowedFoot = const {
      'yes',
      'designated',
      'permissive',
      'official',
    }.contains(foot);
    if (tags.containsKey('foot:conditional') ||
        tags.containsKey('access:conditional')) {
      return (score: 0, reason: AnalysisReason.conditionalAccess);
    }
    if ((foot != null && !allowedFoot) ||
        (!allowedFoot &&
            tags['access'] != null &&
            !const {
              'yes',
              'permissive',
              'designated',
            }.contains(tags['access']))) {
      return (score: 0, reason: AnalysisReason.accessRestricted);
    }
    final highway = feature.isArea
        ? tags['area:highway'] ?? tags['highway']
        : tags['highway'];
    if (const {
          'footway',
          'path',
          'pedestrian',
          'steps',
          'living_street',
          'crossing',
        }.contains(highway) ||
        (allowedFoot && const {'cycleway', 'bridleway'}.contains(highway))) {
      return (
        score: AnalysisSettings.pedestrianWeight,
        reason: AnalysisReason.eligible,
      );
    }
    if (const {
      'residential',
      'service',
      'unclassified',
      'track',
      'tertiary',
      'secondary',
      'primary',
    }.contains(highway)) {
      if (tags.entries.any(
        (e) =>
            (e.key == 'sidewalk' || e.key.startsWith('sidewalk:')) &&
            !const {'no', 'none'}.contains(e.value),
      )) {
        return (score: 0, reason: AnalysisReason.separateSidewalk);
      }
      return (
        score: AnalysisSettings.roadWeight,
        reason: AnalysisReason.eligible,
      );
    }
    return (score: 0, reason: AnalysisReason.notPedestrian);
  }

  static int _compare(MatchCandidate a, MatchCandidate b) {
    final eligible = (b.eligible ? 1 : 0).compareTo(a.eligible ? 1 : 0);
    if (eligible != 0) return eligible;
    final score = b.score.compareTo(a.score);
    return score != 0 ? score : a.feature.key.compareTo(b.feature.key);
  }

  static double _margin(List<MatchCandidate> candidates) {
    final eligible = candidates.where((c) => c.eligible).toList();
    return eligible.length < 2
        ? double.infinity
        : eligible[0].score - eligible[1].score;
  }

  static ({MatchCandidate? candidate, AnalysisReason reason}) _choose(
    List<MatchCandidate> candidates,
    WalkPoint p, {
    String? supportedKey,
  }) {
    final eligible = candidates.where((c) => c.eligible).toList();
    if (eligible.isEmpty) {
      return (candidate: null, reason: AnalysisReason.noCandidate);
    }
    final first = eligible.first;
    if (first.score < AnalysisSettings.minimumScore) {
      return (candidate: null, reason: AnalysisReason.weakScore);
    }
    final uncertainty = math.max(
      p.accuracyMeters.isFinite ? p.accuracyMeters : 0.0,
      AnalysisSettings.minimumAmbiguityMeters,
    );
    // Unsupported pedestrian geometry and area edges in the accuracy envelope
    // are unresolved rivals, even though they cannot win a match themselves.
    if (candidates.any(
      (c) =>
          (c.reason == AnalysisReason.areaBoundary ||
              (c.reason == AnalysisReason.unsupportedGeometry &&
                  c.pedestrianScore > 0)) &&
          c.distanceMeters <= uncertainty,
    )) {
      return (candidate: null, reason: AnalysisReason.ambiguousCandidates);
    }
    final ambiguous = eligible
        .skip(1)
        .any(
          (other) =>
              (first.distanceMeters - other.distanceMeters).abs() <=
                  uncertainty &&
              (first.directionDegrees == null ||
                  other.directionDegrees == null ||
                  (first.directionDegrees! - other.directionDegrees!).abs() <=
                      AnalysisSettings.parallelDirectionDegrees),
        );
    if (_margin(candidates) < AnalysisSettings.minimumMargin ||
        (ambiguous && supportedKey != first.feature.key)) {
      return (candidate: null, reason: AnalysisReason.ambiguousCandidates);
    }
    return (candidate: first, reason: AnalysisReason.matched);
  }

  static bool _edgeOnFeature(SampleAnalysis a, SampleAnalysis b) {
    final first = a.original;
    final last = b.original;
    final feature = a.selected!.feature;
    final longitudeDelta = (last.longitude - first.longitude + 540) % 360 - 180;
    // Local probes only; never stored or sent to the evidence provider.
    for (final t in AnalysisSettings.edgeProbeFractions) {
      final point = GeoCoordinate(
        first.latitude + (last.latitude - first.latitude) * t,
        (first.longitude + longitudeDelta * t + 540) % 360 - 180,
      );
      final hit = RouteGeometry.inspect(feature, point);
      if (!hit.supported ||
          hit.distance > math.min(_radius(first), _radius(last)) ||
          (feature.isArea &&
              (!hit.insideArea ||
                  hit.boundaryDistance <=
                      math.max(first.accuracyMeters, last.accuracyMeters) +
                          AnalysisSettings.areaBoundaryAllowanceMeters))) {
        return false;
      }
    }
    return true;
  }
}
