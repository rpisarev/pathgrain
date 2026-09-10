import 'dart:math' as math;

import '../../map/evidence/geographic_cell.dart';
import '../walk_distance.dart';
import '../walk_models.dart';
import 'route_analysis.dart';
import 'surface_segmenter.dart';
import 'walk_surface_summary.dart';

/// Compact automatic result. The low-level matcher graph stays transient.
class AutomaticSurfaceSnapshot {
  AutomaticSurfaceSnapshot({
    required Iterable<WalkPoint> points,
    required Iterable<SurfaceSegment> segments,
  }) : points = List.unmodifiable(points),
       segments = List.unmodifiable(segments) {
    if (this.points.any(
      (p) => !GeoCoordinate(p.latitude, p.longitude).isValid,
    )) {
      throw const FormatException('Invalid route coordinates');
    }
    var next = 0;
    for (final segment in this.segments) {
      if (segment.startEdgeIndex != next ||
          segment.endEdgeIndex <= next ||
          segment.endEdgeIndex >= this.points.length ||
          (segment.surface.surface == CanonicalSurface.unknown) !=
              (segment.surface.assignment == SurfaceAssignment.unknown)) {
        throw const FormatException('Invalid automatic surface coverage');
      }
      next = segment.endEdgeIndex;
    }
    if (next != math.max(0, this.points.length - 1)) {
      throw const FormatException('Incomplete automatic surface coverage');
    }
  }

  factory AutomaticSurfaceSnapshot.fromSummary(WalkSurfaceSummary summary) =>
      AutomaticSurfaceSnapshot(
        points: summary.analysis.samples.map((s) => s.original),
        segments: summary.segments,
      );

  final List<WalkPoint> points;
  final List<SurfaceSegment> segments;
}

/// A user's observation on original edges, not OSM IDs or segment ordinals.
/// UNKNOWN is also an explicit observation.
class SurfaceCorrection {
  const SurfaceCorrection({
    required this.startEdgeIndex,
    required this.endEdgeIndex,
    required this.surface,
  });

  final int startEdgeIndex;
  final int endEdgeIndex;
  final CanonicalSurface surface;

  bool sameRange(SurfaceCorrection other) =>
      startEdgeIndex == other.startEdgeIndex &&
      endEdgeIndex == other.endEdgeIndex;

  /// Equality must hold across the whole original range, even when automatic
  /// provenance splits it into several segments. Used only on an explicit Save.
  bool matchesAutomatic(AutomaticSurfaceSnapshot automatic) {
    validate([this], math.max(0, automatic.points.length - 1));
    return automatic.segments
        .where(
          (segment) =>
              segment.startEdgeIndex < endEdgeIndex &&
              segment.endEdgeIndex > startEdgeIndex,
        )
        .every((segment) => segment.surface.surface == surface);
  }

  static void validate(List<SurfaceCorrection> corrections, int edgeCount) {
    var end = 0;
    for (final correction in corrections) {
      if (correction.startEdgeIndex < end ||
          correction.endEdgeIndex <= correction.startEdgeIndex ||
          correction.endEdgeIndex > edgeCount) {
        throw const FormatException('Invalid surface correction ranges');
      }
      end = correction.endEdgeIndex;
    }
  }
}

class EffectiveSurfaceSegment {
  const EffectiveSurfaceSegment({
    required this.startEdgeIndex,
    required this.endEdgeIndex,
    required this.surface,
    required this.correction,
    required this.distanceMeters,
  });

  final int startEdgeIndex;
  final int endEdgeIndex;
  final CanonicalSurface surface;
  final SurfaceCorrection? correction;
  final double distanceMeters;
  bool get isCorrected => correction != null;
}

/// Normal journal presentation; never used to rewrite automatic diagnostics.
class EffectiveSurfaceSummary {
  EffectiveSurfaceSummary._(this.points, List<EffectiveSurfaceSegment> segments)
    : segments = List.unmodifiable(segments),
      totalDistanceMeters = segments.fold(
        0,
        (sum, s) => sum + s.distanceMeters,
      ),
      distanceBySurface = Map.unmodifiable({
        for (final surface in CanonicalSurface.values)
          if (segments.any((s) => s.surface == surface))
            surface: segments
                .where((s) => s.surface == surface)
                .fold<double>(0, (sum, s) => sum + s.distanceMeters),
      });

  factory EffectiveSurfaceSummary.overlay(
    AutomaticSurfaceSnapshot automatic,
    List<SurfaceCorrection> corrections,
  ) {
    final points = automatic.points;
    SurfaceCorrection.validate(corrections, math.max(0, points.length - 1));
    final result = <EffectiveSurfaceSegment>[];
    var edge = 0;
    var automaticIndex = 0;
    var correctionIndex = 0;
    while (edge < points.length - 1) {
      while (automatic.segments[automaticIndex].endEdgeIndex <= edge) {
        automaticIndex++;
      }
      final source = automatic.segments[automaticIndex];
      final nextCorrection = correctionIndex < corrections.length
          ? corrections[correctionIndex]
          : null;
      final correction = nextCorrection?.startEdgeIndex == edge
          ? nextCorrection
          : null;
      final end =
          correction?.endEdgeIndex ??
          math.min(
            source.endEdgeIndex,
            nextCorrection?.startEdgeIndex ?? points.length - 1,
          );
      // Automatic boundaries remain. One correction spans any new automatic
      // boundaries; distinct corrections never merge, even with equal labels.
      result.add(
        EffectiveSurfaceSegment(
          startEdgeIndex: edge,
          endEdgeIndex: end,
          surface: correction?.surface ?? source.surface.surface,
          correction: correction,
          distanceMeters: WalkDistance.total(points.getRange(edge, end + 1)),
        ),
      );
      edge = end;
      if (correction != null) correctionIndex++;
    }
    return EffectiveSurfaceSummary._(points, result);
  }

  final List<WalkPoint> points;
  final List<EffectiveSurfaceSegment> segments;
  final Map<CanonicalSurface, double> distanceBySurface;
  final double totalDistanceMeters;
  double get unknownDistanceMeters =>
      distanceBySurface[CanonicalSurface.unknown] ?? 0;

  bool reconcilesWith(double distanceMeters) =>
      distanceMeters.isFinite &&
      (totalDistanceMeters - distanceMeters).abs() <=
          math.max(1e-6, distanceMeters.abs() * 1e-12);
}

class SurfaceJournal {
  SurfaceJournal(this.automatic, Iterable<SurfaceCorrection> corrections)
    : corrections = List.unmodifiable(corrections) {
    effective = EffectiveSurfaceSummary.overlay(automatic, this.corrections);
  }

  final AutomaticSurfaceSnapshot automatic;
  final List<SurfaceCorrection> corrections;
  late final EffectiveSurfaceSummary effective;
}
