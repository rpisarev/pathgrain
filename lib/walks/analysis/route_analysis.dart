import '../../map/evidence/osm_evidence.dart';
import '../walk_models.dart';

enum CanonicalSurface {
  asphalt,
  tile,
  cobblestone,
  concrete,
  ground,
  sand,
  stone,
  fineGravel,
  crushedStone,
  grass,
  artificialTurf,
  rubber,
  wood,
  metal,
  unknown,
}

enum SurfaceAssignment { direct, inferred, unknown }

class SurfaceAssessment {
  const SurfaceAssessment(this.surface, this.assignment, this.reason);
  const SurfaceAssessment.unknown(AnalysisReason reason)
    : this(CanonicalSurface.unknown, SurfaceAssignment.unknown, reason);

  final CanonicalSurface surface;
  final SurfaceAssignment assignment;
  final AnalysisReason reason;
}

enum GpsState { stable, warmingUp, recovering, unreliable }

/// Stable codes translated by the diagnostic UI; no geometry in messages.
enum AnalysisReason {
  stable,
  warmingUp,
  recovering,
  invalidSample,
  reducedAccuracy,
  poorAccuracy,
  fastMotion,
  isolatedSpike,
  sequenceGap,
  uncertainEndpoint,
  eligible,
  unsupportedGeometry,
  notPedestrian,
  accessRestricted,
  conditionalAccess,
  separateSidewalk,
  tooFar,
  directionConflict,
  areaBoundary,
  gpsUncertain,
  evidenceIncomplete,
  noCandidate,
  weakScore,
  ambiguousCandidates,
  conflictingNeighbors,
  matched,
  continuitySupported,
  differentObjects,
  edgeOffGeometry,
  explicitSurface,
  grassLandcover,
  missingSurface,
  unsupportedSurface,
  conflictingSurface,
  legacySurfaceAmbiguous,
}

class GpsAssessment {
  GpsAssessment(this.state, Iterable<AnalysisReason> reasons)
    : reasons = List.unmodifiable(reasons);

  final GpsState state;
  final List<AnalysisReason> reasons;
  bool get isStable => state == GpsState.stable;
}

class GpsEdgeAssessment {
  const GpsEdgeAssessment({required this.reason, required this.speed});
  final AnalysisReason reason;
  final double? speed;
  bool get isStable => reason == AnalysisReason.stable;
}

class MatchCandidate {
  const MatchCandidate({
    required this.feature,
    required this.distanceMeters,
    required this.directionDegrees,
    required this.proximityScore,
    required this.pedestrianScore,
    required this.directionScore,
    required this.gpsScore,
    required this.reason,
    this.continuityScore = 0,
  });

  final OsmFeature feature;
  final double distanceMeters;
  final double? directionDegrees;
  final double proximityScore;
  final double pedestrianScore;
  final double directionScore;
  final double gpsScore;
  final double continuityScore;
  final AnalysisReason reason;
  bool get eligible => reason == AnalysisReason.eligible;
  double get score =>
      proximityScore +
      pedestrianScore +
      directionScore +
      gpsScore +
      continuityScore;

  MatchCandidate withContinuity(double value) => MatchCandidate(
    feature: feature,
    distanceMeters: distanceMeters,
    directionDegrees: directionDegrees,
    proximityScore: proximityScore,
    pedestrianScore: pedestrianScore,
    directionScore: directionScore,
    gpsScore: gpsScore,
    continuityScore: value,
    reason: reason,
  );
}

/// Evidence support levels, deliberately not numerical probabilities.
enum MatchConfidence { none, supported, strong }

class SampleAnalysis {
  SampleAnalysis({
    required this.original,
    required this.gps,
    required Iterable<MatchCandidate> candidates,
    required this.selected,
    required this.confidence,
    required this.reason,
    required this.surface,
  }) : candidates = List.unmodifiable(candidates);

  final WalkPoint original;
  final GpsAssessment gps;
  final List<MatchCandidate> candidates;
  final MatchCandidate? selected;
  final MatchConfidence confidence;
  final AnalysisReason reason;
  final SurfaceAssessment surface;
}

/// One original stored edge, not a resampled route or a final surface segment.
class EdgeAnalysis {
  const EdgeAnalysis({
    required this.from,
    required this.to,
    required this.gps,
    required this.reason,
    required this.surface,
  });
  final SampleAnalysis from;
  final SampleAnalysis to;
  final GpsEdgeAssessment gps;
  final AnalysisReason reason;
  final SurfaceAssessment surface;
}

class RouteAnalysis {
  RouteAnalysis({
    required Iterable<SampleAnalysis> samples,
    required Iterable<EdgeAnalysis> edges,
  }) : samples = List.unmodifiable(samples),
       edges = List.unmodifiable(edges);

  final List<SampleAnalysis> samples;
  final List<EdgeAnalysis> edges;
}
