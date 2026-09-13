import 'route_analysis.dart';

/// Diagnostic gate names, separate from persisted AnalysisReason codes.
enum MatchGate {
  noEligibleCandidate,
  minimumScore,
  unsupportedRival,
  scoreMargin,
  parallelAmbiguity,
}

/// A production chooser decision, before GPS/evidence/context overrides.
/// Later gates are not evaluated after no-candidate/minimum-score rejection.
class MatchChoiceAudit {
  MatchChoiceAudit({
    required this.reason,
    required this.leaderKey,
    required this.leaderScore,
    required this.runnerUpScore,
    required this.selectedKey,
    required this.ambiguityEvaluated,
    required this.supportedKey,
    required Iterable<MatchGate> gates,
    Iterable<String> parallelRivals = const [],
    Iterable<String> unsupportedRivals = const [],
  }) : gates = List.unmodifiable(gates),
       parallelRivals = List.unmodifiable(parallelRivals),
       unsupportedRivals = List.unmodifiable(unsupportedRivals);

  final AnalysisReason reason;
  final String? leaderKey;
  final double? leaderScore;
  final double? runnerUpScore;
  final String? selectedKey;
  final bool ambiguityEvaluated;
  final String? supportedKey;
  final List<MatchGate> gates;
  final List<String> parallelRivals;
  final List<String> unsupportedRivals;
  // No runner is represented by null, never JSON's unsupported Infinity.
  double? get margin =>
      runnerUpScore == null ? null : leaderScore! - runnerUpScore!;
}

/// Only constructed when RouteMatcher's optional audit callback is supplied.
class SampleMatchAudit {
  const SampleMatchAudit({
    required this.index,
    required this.headingDegrees,
    required this.matchRadiusMeters,
    required this.independent,
    required this.contextual,
    required this.previousAnchor,
    required this.nextAnchor,
  });

  final int index;
  final double? headingDegrees;
  final double matchRadiusMeters;
  // Null when GPS/evidence prevented evaluating an independent anchor.
  final MatchChoiceAudit? independent;
  final MatchChoiceAudit contextual;
  final String? previousAnchor;
  final String? nextAnchor;
}
