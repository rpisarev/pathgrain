import 'dart:math' as math;

import '../../map/evidence/geographic_cell.dart';
import '../../map/evidence/osm_evidence.dart';
import '../walk_models.dart';
import 'analysis_settings.dart';
import 'gps_confidence.dart';
import 'match_audit.dart';
import 'route_analysis.dart';
import 'route_geometry.dart';
import 'surface_rules.dart';

/// Pure, synchronous, local experiment over already loaded evidence.
/// Has no database, provider, clock, logger, or serialization dependency.
abstract final class RouteMatcher {
  static const _roadHighways = {
    'residential',
    'service',
    'unclassified',
    'track',
    'tertiary',
    'secondary',
    'primary',
  };

  static RouteAnalysis analyze(
    List<WalkPoint> points,
    List<OsmFeature> features, {
    bool evidenceComplete = true,
    void Function(SampleMatchAudit)? onAudit,
  }) {
    final gps = GpsConfidence.assess(points);
    // Retained OSM IDs establish membership, including parents whose geometry
    // cannot produce a nearby candidate. This is not route reconstruction.
    final crossingWays = <int, Set<String>>{
      for (final feature in features)
        if (feature.type == OsmElementType.node &&
            feature.tags['highway'] == 'crossing')
          feature.id: <String>{},
    };
    for (final feature in features) {
      final nodes = feature.raw['nodes'];
      if (feature.type == OsmElementType.way && nodes is List) {
        for (final id in nodes.whereType<int>()) {
          crossingWays[id]?.add(feature.key);
        }
      }
    }
    final candidates = <List<MatchCandidate>>[];
    final headings = onAudit == null ? null : <double?>[];
    final independentAudits = onAudit == null
        ? null
        : List<MatchChoiceAudit?>.filled(points.length, null);
    for (var i = 0; i < points.length; i++) {
      final heading = _heading(points, gps.edges, i);
      headings?.add(heading);
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
            ? _choose(
                candidates[i],
                points[i],
                crossingWays,
                onAudit: independentAudits == null
                    ? null
                    : (audit) => independentAudits[i] = audit,
              ).candidate?.feature.key
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
      MatchChoiceAudit? contextualAudit;
      final choice = _choose(
        scored,
        points[i],
        crossingWays,
        supportedKey: previous != null && previous == next ? previous : null,
        onAudit: onAudit == null ? null : (audit) => contextualAudit = audit,
      );
      if (onAudit != null) {
        onAudit(
          SampleMatchAudit(
            index: i,
            headingDegrees: headings![i],
            matchRadiusMeters: _radius(points[i]),
            independent: independentAudits![i],
            contextual: contextualAudit!,
            previousAnchor: previous,
            nextAnchor: next,
          ),
        );
      }
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
    if (length < requiredLength) return null;
    for (var j = start + 1; j < end; j++) {
      if (RouteGeometry.lateralOffset(points[start], points[j], points[end]) >
          points[j].accuracyMeters) {
        // A long chord alone does not establish a heading through a turn or
        // deviation. Such a heading could contaminate neighboring anchors.
        return null;
      }
    }
    return RouteGeometry.bearing(points[start], points[end]);
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
    final angle = heading == null || hit.bearing == null || !hit.supported
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
      directionScore: angle == null
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
          : AnalysisSettings.reducedGpsWeight,
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
    if (_roadHighways.contains(highway)) {
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

  static bool _footwayOutweighsRoad(
    MatchCandidate first,
    MatchCandidate other,
  ) {
    // Class alone cannot break a parallel tie. Require a closer, aligned
    // footway meeting the ordinary score and margin gates without context.
    final independentScore = first.score - first.continuityScore;
    final otherIndependentScore = other.score - other.continuityScore;
    return !first.feature.isArea &&
        first.feature.tags['highway'] == 'footway' &&
        !other.feature.isArea &&
        _roadHighways.contains(other.feature.tags['highway']) &&
        first.directionDegrees != null &&
        other.directionDegrees != null &&
        first.directionDegrees! <= AnalysisSettings.parallelDirectionDegrees &&
        first.distanceMeters +
                AnalysisSettings.geometryDistanceToleranceMeters <
            other.distanceMeters &&
        independentScore >= AnalysisSettings.minimumScore &&
        independentScore - otherIndependentScore >=
            AnalysisSettings.minimumMargin;
  }

  static bool _redundantCrossingNode(
    MatchCandidate node,
    MatchCandidate first,
    List<MatchCandidate> candidates,
    Map<int, Set<String>> crossingWays,
  ) {
    final feature = node.feature;
    final way = first.feature;
    if (node.reason != AnalysisReason.unsupportedGeometry ||
        feature.type != OsmElementType.node ||
        feature.geometryKind != OsmGeometryKind.point ||
        feature.tags['highway'] != 'crossing' ||
        feature.tags.keys.any(
          (key) =>
              !const {'highway', 'crossing', 'crossing:markings'}.contains(key),
        ) ||
        way.type != OsmElementType.way ||
        way.geometryKind != OsmGeometryKind.line ||
        way.isArea ||
        !const {'footway', 'path'}.contains(way.tags['highway'])) {
      return false;
    }
    final nodes = way.raw['nodes'];
    if (nodes is! List ||
        nodes.any((id) => id is! int) ||
        way.parts.length != 1 ||
        nodes.length != way.parts.single.length ||
        feature.parts.length != 1 ||
        feature.parts.single.length != 1) {
      return false;
    }
    final index = nodes.indexOf(feature.id);
    if (index < 0 || way.parts.single[index] != feature.parts.single.single) {
      return false;
    }
    // Context must not manufacture the independent score or margin needed to
    // waive this veto. Only distance/heading-rejected pedestrian diagnostics
    // are harmless; eligible rivals keep the veto even below minimum score.
    final independentScore = first.score - first.continuityScore;
    if (independentScore < AnalysisSettings.minimumScore ||
        candidates.any(
          (c) =>
              c.feature.key != way.key &&
              ((c.feature.type == OsmElementType.way &&
                      c.pedestrianScore == AnalysisSettings.pedestrianWeight &&
                      c.reason != AnalysisReason.tooFar &&
                      c.reason != AnalysisReason.directionConflict) ||
                  (c.eligible &&
                      independentScore - (c.score - c.continuityScore) <
                          AnalysisSettings.minimumMargin)),
        )) {
      return false;
    }
    final parents = crossingWays[feature.id];
    // A road crossing is redundant only when that parent is already rejected
    // by heading. Pedestrian branches, eligible roads and absent/unsupported
    // parent geometry keep the veto, regardless of shared surface labels.
    return parents != null &&
        parents.contains(way.key) &&
        parents.every(
          (key) =>
              key == way.key ||
              candidates.any(
                (c) =>
                    c.feature.key == key &&
                    _roadHighways.contains(c.feature.tags['highway']) &&
                    c.reason == AnalysisReason.directionConflict,
              ),
        );
  }

  static ({MatchCandidate? candidate, AnalysisReason reason}) _choose(
    List<MatchCandidate> candidates,
    WalkPoint p,
    Map<int, Set<String>> crossingWays, {
    String? supportedKey,
    void Function(MatchChoiceAudit)? onAudit,
  }) {
    final eligible = candidates.where((c) => c.eligible).toList();
    final parallelRivals = <String>[];
    final unsupportedRivals = <String>[];
    var ambiguityEvaluated = false;
    ({MatchCandidate? candidate, AnalysisReason reason}) finish(
      MatchCandidate? candidate,
      AnalysisReason reason,
      List<MatchGate> gates,
    ) {
      onAudit?.call(
        MatchChoiceAudit(
          reason: reason,
          leaderKey: eligible.firstOrNull?.feature.key,
          leaderScore: eligible.firstOrNull?.score,
          runnerUpScore: eligible.length < 2 ? null : eligible[1].score,
          selectedKey: candidate?.feature.key,
          ambiguityEvaluated: ambiguityEvaluated,
          supportedKey: supportedKey,
          gates: gates,
          parallelRivals: parallelRivals,
          unsupportedRivals: unsupportedRivals,
        ),
      );
      return (candidate: candidate, reason: reason);
    }

    if (eligible.isEmpty) {
      return finish(null, AnalysisReason.noCandidate, [
        MatchGate.noEligibleCandidate,
      ]);
    }
    final first = eligible.first;
    if (first.score < AnalysisSettings.minimumScore) {
      return finish(null, AnalysisReason.weakScore, [MatchGate.minimumScore]);
    }
    final uncertainty = math.max(
      p.accuracyMeters.isFinite ? p.accuracyMeters : 0.0,
      AnalysisSettings.minimumAmbiguityMeters,
    );
    ambiguityEvaluated = true;
    final ambiguous = eligible
        .skip(1)
        .where(
          (other) =>
              (first.distanceMeters - other.distanceMeters).abs() <=
                  uncertainty &&
              (first.directionDegrees == null ||
                  other.directionDegrees == null ||
                  (first.directionDegrees! - other.directionDegrees!).abs() <=
                      AnalysisSettings.parallelDirectionDegrees) &&
              !_footwayOutweighsRoad(first, other),
        )
        .toList();
    parallelRivals.addAll(ambiguous.map((c) => c.feature.key));
    // Unsupported pedestrian geometry and area edges in the accuracy envelope
    // are unresolved rivals, even though they cannot win a match themselves.
    final unresolved = candidates
        .where(
          (c) =>
              (c.reason == AnalysisReason.areaBoundary ||
                  (c.reason == AnalysisReason.unsupportedGeometry &&
                      c.pedestrianScore > 0)) &&
              c.distanceMeters <= uncertainty &&
              // Waiving the node must not rely on context to resolve geometry.
              (ambiguous.isNotEmpty ||
                  !_redundantCrossingNode(c, first, candidates, crossingWays)),
        )
        .toList();
    unsupportedRivals.addAll(unresolved.map((c) => c.feature.key));
    final gates = <MatchGate>[
      if (unresolved.isNotEmpty) MatchGate.unsupportedRival,
      if (_margin(candidates) < AnalysisSettings.minimumMargin)
        MatchGate.scoreMargin,
      if (ambiguous.isNotEmpty && supportedKey != first.feature.key)
        MatchGate.parallelAmbiguity,
    ];
    if (gates.isNotEmpty) {
      return finish(null, AnalysisReason.ambiguousCandidates, gates);
    }
    return finish(first, AnalysisReason.matched, const []);
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
