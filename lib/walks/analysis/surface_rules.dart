import '../../map/evidence/osm_evidence.dart';
import 'route_analysis.dart';

abstract final class SurfaceRules {
  /// Explicit allowlist. Broad, mixed, misspelled and unrecognized values do
  /// not silently become OTHER. OTHER is a known material outside this taxonomy.
  static const directMapping = <String, CanonicalSurface>{
    'grass': CanonicalSurface.grass,
    'asphalt': CanonicalSurface.asphalt,
    'concrete': CanonicalSurface.concrete,
    'concrete:plates': CanonicalSurface.concrete,
    'ground': CanonicalSurface.ground,
    'dirt': CanonicalSurface.ground,
    'earth': CanonicalSurface.ground,
    'soil': CanonicalSurface.ground,
    'gravel': CanonicalSurface.gravel,
    'fine_gravel': CanonicalSurface.gravel,
    'pebblestone': CanonicalSurface.gravel,
    'paving_stones': CanonicalSurface.pavingStones,
    'sett': CanonicalSurface.pavingStones,
    'unhewn_cobblestone': CanonicalSurface.other,
    'cobblestone': CanonicalSurface.other,
    'wood': CanonicalSurface.other,
    'metal': CanonicalSurface.other,
    'sand': CanonicalSurface.other,
    'mud': CanonicalSurface.other,
    'rock': CanonicalSurface.other,
    'rubber': CanonicalSurface.other,
  };

  /// Call only after a supported geometric assignment. Area inference also
  /// requires the matcher's convex-area interior/accuracy-margin check.
  static SurfaceAssessment derive(OsmFeature feature) {
    final tags = feature.tags;
    final raw = tags['surface'];
    if (tags.containsKey('surface:conditional') ||
        tags.containsKey('surface:forward') ||
        tags.containsKey('surface:backward') ||
        tags.containsKey('surface:lanes') ||
        tags.containsKey('surface:left') ||
        tags.containsKey('surface:right')) {
      return const SurfaceAssessment.unknown(AnalysisReason.conflictingSurface);
    }
    if (raw != null) {
      final value = raw.trim().toLowerCase();
      final surface = directMapping[value];
      if (surface == null) {
        return SurfaceAssessment.unknown(
          value.contains(';')
              ? AnalysisReason.conflictingSurface
              : AnalysisReason.unsupportedSurface,
        );
      }
      if (feature.isArea &&
          tags['landcover'] == 'grass' &&
          surface != CanonicalSurface.grass) {
        return const SurfaceAssessment.unknown(
          AnalysisReason.conflictingSurface,
        );
      }
      return SurfaceAssessment(
        surface,
        SurfaceAssignment.direct,
        AnalysisReason.explicitSurface,
      );
    }
    final highway = tags['area:highway'] ?? tags['highway'];
    if (feature.type == OsmElementType.way &&
        feature.geometryKind == OsmGeometryKind.closedArea &&
        feature.limitations.isEmpty &&
        (highway == 'pedestrian' || highway == 'footway') &&
        tags['landcover'] == 'grass') {
      return const SurfaceAssessment(
        CanonicalSurface.grass,
        SurfaceAssignment.inferred,
        AnalysisReason.grassLandcover,
      );
    }
    return const SurfaceAssessment.unknown(AnalysisReason.missingSurface);
  }
}
