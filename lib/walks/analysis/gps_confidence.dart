import 'dart:math' as math;

import '../walk_models.dart';
import 'analysis_settings.dart';
import 'route_analysis.dart';
import 'route_geometry.dart';

abstract final class GpsConfidence {
  static ({List<GpsAssessment> samples, List<GpsEdgeAssessment> edges}) assess(
    List<WalkPoint> points,
  ) {
    final reasons = List.generate(points.length, (_) => <AnalysisReason>[]);
    final edges = <GpsEdgeAssessment>[];
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (!RouteGeometry.valid(p) ||
          !p.accuracyMeters.isFinite ||
          p.accuracyMeters <= 0) {
        reasons[i].add(AnalysisReason.invalidSample);
      } else if (p.accuracyMeters > AnalysisSettings.goodAccuracyMeters) {
        reasons[i].add(
          p.accuracyMeters > AnalysisSettings.poorAccuracyMeters
              ? AnalysisReason.poorAccuracy
              : AnalysisReason.reducedAccuracy,
        );
      }
      if (i == 0) continue;
      final a = points[i - 1];
      final seconds =
          p.recordedAt.difference(a.recordedAt).inMicroseconds / 1e6;
      var reason = AnalysisReason.stable;
      double? speed;
      if (!RouteGeometry.valid(a) || !RouteGeometry.valid(p)) {
        reason = AnalysisReason.invalidSample;
      } else if (seconds <= 0 ||
          seconds > AnalysisSettings.maximumGapSeconds ||
          p.sequence != a.sequence + 1 ||
          p.walkId != a.walkId) {
        reason = AnalysisReason.sequenceGap;
        reasons[i].add(reason);
      } else {
        speed = RouteGeometry.distance(a, p) / seconds;
        if (speed > AnalysisSettings.maximumSpeedMetersPerSecond) {
          reason = AnalysisReason.fastMotion;
          reasons[i - 1].add(reason);
          reasons[i].add(reason);
        }
      }
      edges.add(GpsEdgeAssessment(reason: reason, speed: speed));
    }
    for (var i = 1; i + 1 < points.length; i++) {
      // Test the original triplet, including ordinary-accuracy anomalies.
      if ([edges[i - 1], edges[i]].any((e) => e.speed == null)) continue;
      final a = points[i - 1];
      final b = points[i];
      final c = points[i + 1];
      final bypass = RouteGeometry.distance(a, c);
      final detour =
          RouteGeometry.distance(a, b) + RouteGeometry.distance(b, c);
      final seconds =
          c.recordedAt.difference(a.recordedAt).inMicroseconds / 1e6;
      final offset = RouteGeometry.lateralOffset(a, b, c);
      if (b.accuracyMeters.isFinite &&
          offset >
              math.max(
                AnalysisSettings.spikeOffsetMeters,
                b.accuracyMeters * AnalysisSettings.spikeAccuracyFactor,
              ) &&
          detour > AnalysisSettings.spikeDetourRatio * math.max(bypass, 1.0) &&
          bypass / seconds <= AnalysisSettings.maximumSpeedMetersPerSecond) {
        reasons[i].add(AnalysisReason.isolatedSpike);
      }
    }
    var run = 0;
    var everStable = false;
    final samples = <GpsAssessment>[];
    for (var i = 0; i < points.length; i++) {
      if (reasons[i].isNotEmpty) {
        run = 0;
        samples.add(GpsAssessment(GpsState.unreliable, reasons[i].toSet()));
      } else {
        run = i > 0 && edges[i - 1].isStable ? run + 1 : 1;
        if (run >= AnalysisSettings.stableSamples) {
          everStable = true;
          samples.add(GpsAssessment(GpsState.stable, [AnalysisReason.stable]));
        } else {
          samples.add(
            GpsAssessment(
              everStable ? GpsState.recovering : GpsState.warmingUp,
              [
                everStable
                    ? AnalysisReason.recovering
                    : AnalysisReason.warmingUp,
              ],
            ),
          );
        }
      }
    }
    for (var i = 0; i < edges.length; i++) {
      var reason = edges[i].reason;
      if (reasons[i].contains(AnalysisReason.isolatedSpike) ||
          reasons[i + 1].contains(AnalysisReason.isolatedSpike)) {
        reason = AnalysisReason.isolatedSpike;
      } else if (reason == AnalysisReason.stable &&
          (!samples[i].isStable || !samples[i + 1].isStable)) {
        reason = AnalysisReason.uncertainEndpoint;
      }
      edges[i] = GpsEdgeAssessment(reason: reason, speed: edges[i].speed);
    }
    return (
      samples: List.unmodifiable(samples),
      edges: List.unmodifiable(edges),
    );
  }
}
