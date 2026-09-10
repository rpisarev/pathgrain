import '../../map/evidence/geographic_cell.dart';
import '../walk_distance.dart';
import '../walk_models.dart';
import 'route_analysis.dart';

/// A half-open range of original route edges. Contains no derived geometry.
class SurfaceSegment {
  /// Reconstructs meters from recorded points, never stored meters.
  factory SurfaceSegment.fromRange({
    required List<WalkPoint> points,
    required int startEdgeIndex,
    required int endEdgeIndex,
    required SurfaceAssessment surface,
    required AnalysisReason reason,
    required String? fromFeatureKey,
    required String? toFeatureKey,
  }) {
    if (startEdgeIndex < 0 ||
        endEdgeIndex <= startEdgeIndex ||
        endEdgeIndex >= points.length) {
      throw const FormatException('Invalid surface range');
    }
    return SurfaceSegment._(
      startEdgeIndex: startEdgeIndex,
      endEdgeIndex: endEdgeIndex,
      surface: surface,
      reason: reason,
      fromFeatureKey: fromFeatureKey,
      toFeatureKey: toFeatureKey,
      distanceMeters: WalkDistance.total(
        points.getRange(startEdgeIndex, endEdgeIndex + 1),
      ),
    );
  }

  const SurfaceSegment._({
    required this.startEdgeIndex,
    required this.endEdgeIndex,
    required this.surface,
    required this.reason,
    required this.fromFeatureKey,
    required this.toFeatureKey,
    required this.distanceMeters,
  });

  final int startEdgeIndex;
  final int endEdgeIndex;
  final SurfaceAssessment surface;
  final AnalysisReason reason;

  /// Ordered endpoint selections, including nulls and object transitions.
  /// These are evidence provenance, not a claim of a matched UNKNOWN edge.
  final String? fromFeatureKey;
  final String? toFeatureKey;
  final double distanceMeters;

  int get edgeCount => endEdgeIndex - startEdgeIndex;
  String? get sourceFeatureKey =>
      fromFeatureKey == toFeatureKey ? fromFeatureKey : null;
}

abstract final class SurfaceSegmenter {
  /// Preserves every edge, including stationary edges and uncertain GPS gaps.
  /// Rejects incomplete/reordered input rather than inventing missing analysis.
  static List<SurfaceSegment> segment(RouteAnalysis analysis) {
    final samples = analysis.samples;
    final edges = analysis.edges;
    final expectedEdges = samples.isEmpty ? 0 : samples.length - 1;
    if (edges.length != expectedEdges) {
      throw const FormatException('Analysis does not cover the original route');
    }
    for (final sample in samples) {
      final point = sample.original;
      if (!GeoCoordinate(point.latitude, point.longitude).isValid) {
        throw const FormatException('Route contains invalid coordinates');
      }
    }
    for (var i = 0; i < edges.length; i++) {
      final edge = edges[i];
      if (!identical(edge.from, samples[i]) ||
          !identical(edge.to, samples[i + 1])) {
        throw const FormatException('Analysis edges are not in original order');
      }
      if ((edge.surface.surface == CanonicalSurface.unknown) !=
          (edge.surface.assignment == SurfaceAssignment.unknown)) {
        throw const FormatException('Inconsistent surface assignment');
      }
    }

    final segments = <SurfaceSegment>[];
    var start = 0;
    var distance = 0.0;
    void finish(int end) {
      final first = edges[start];
      segments.add(
        SurfaceSegment._(
          startEdgeIndex: start,
          endEdgeIndex: end,
          surface: first.surface,
          reason: first.reason,
          fromFeatureKey: first.from.selected?.feature.key,
          toFeatureKey: first.to.selected?.feature.key,
          distanceMeters: distance,
        ),
      );
    }

    for (var i = 0; i < edges.length; i++) {
      if (i > start && !_compatible(edges[start], edges[i])) {
        finish(i);
        start = i;
        distance = 0;
      }
      final a = edges[i].from.original;
      final b = edges[i].to.original;
      // The same haversine utility as WalkDistance.total / finishWalk.
      // Never use the matcher's local projection for distance allocation.
      distance += WalkDistance.betweenCoordinates(
        latitudeA: a.latitude,
        longitudeA: a.longitude,
        latitudeB: b.latitude,
        longitudeB: b.longitude,
      );
    }
    if (edges.isNotEmpty) finish(edges.length);
    return List.unmodifiable(segments);
  }

  static bool _compatible(EdgeAnalysis a, EdgeAnalysis b) =>
      a.surface.surface == b.surface.surface &&
      a.surface.assignment == b.surface.assignment &&
      a.surface.reason == b.surface.reason &&
      a.reason == b.reason &&
      a.from.selected?.feature.key == b.from.selected?.feature.key &&
      a.to.selected?.feature.key == b.to.selected?.feature.key;
}
