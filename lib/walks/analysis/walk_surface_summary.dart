import 'dart:math' as math;

import 'route_analysis.dart';
import 'surface_segmenter.dart';

/// In-memory whole-walk result; all distances are unrounded original meters.
class WalkSurfaceSummary {
  WalkSurfaceSummary._({
    required this.analysis,
    required this.segments,
    required this.totalDistanceMeters,
    required Map<CanonicalSurface, double> distanceBySurface,
    required Map<AnalysisReason, double> unknownDistanceByReason,
  }) : distanceBySurface = Map.unmodifiable(distanceBySurface),
       unknownDistanceByReason = Map.unmodifiable(unknownDistanceByReason);

  factory WalkSurfaceSummary.fromAnalysis(RouteAnalysis analysis) {
    final segments = SurfaceSegmenter.segment(analysis);
    final surfaces = <CanonicalSurface, double>{};
    final unknownReasons = <AnalysisReason, double>{};
    var total = 0.0;
    for (final segment in segments) {
      final surface = segment.surface.surface;
      final meters = segment.distanceMeters;
      total += meters;
      surfaces.update(
        surface,
        (value) => value + meters,
        ifAbsent: () => meters,
      );
      if (surface == CanonicalSurface.unknown) {
        unknownReasons.update(
          segment.surface.reason,
          (value) => value + meters,
          ifAbsent: () => meters,
        );
      }
    }
    return WalkSurfaceSummary._(
      analysis: analysis,
      segments: segments,
      totalDistanceMeters: total,
      // Canonical order is independent of first encounter.
      distanceBySurface: {
        for (final surface in CanonicalSurface.values)
          if (surfaces.containsKey(surface)) surface: surfaces[surface]!,
      },
      unknownDistanceByReason: {
        for (final reason in AnalysisReason.values)
          if (unknownReasons.containsKey(reason))
            reason: unknownReasons[reason]!,
      },
    );
  }

  final RouteAnalysis analysis;
  final List<SurfaceSegment> segments;
  final double totalDistanceMeters;
  final Map<CanonicalSurface, double> distanceBySurface;

  /// One canonical surface reason per UNKNOWN edge, never overlapping causes.
  /// Detailed endpoint GPS reasons remain available in [analysis].
  final Map<AnalysisReason, double> unknownDistanceByReason;

  double get unknownDistanceMeters =>
      distanceBySurface[CanonicalSurface.unknown] ?? 0;

  /// Allows only floating-point grouping differences, not display rounding or
  /// rescaling. A stale/corrupt saved total must be disclosed by presentation.
  bool reconcilesWith(double distanceMeters) =>
      distanceMeters.isFinite &&
      (totalDistanceMeters - distanceMeters).abs() <=
          math.max(1e-6, distanceMeters.abs() * 1e-12);
}
