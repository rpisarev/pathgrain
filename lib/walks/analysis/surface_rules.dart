import '../../map/evidence/osm_evidence.dart';
import 'route_analysis.dart';

abstract final class SurfaceRules {
  /// Raw OSM tags and barefoot categories are separate layers. Only this
  /// explicit allowlist supplies a material; insufficient evidence stays UNKNOWN.
  static const directMapping = <String, CanonicalSurface>{
    'asphalt': CanonicalSurface.asphalt,
    'chipseal': CanonicalSurface.asphalt,
    'paving_stones': CanonicalSurface.tile,
    'bricks': CanonicalSurface.tile,
    'sett': CanonicalSurface.cobblestone,
    'cobblestone': CanonicalSurface.cobblestone,
    'unhewn_cobblestone': CanonicalSurface.cobblestone,
    'concrete': CanonicalSurface.concrete,
    'concrete:plates': CanonicalSurface.concrete,
    'ground': CanonicalSurface.ground,
    'dirt': CanonicalSurface.ground,
    'earth': CanonicalSurface.ground,
    'soil': CanonicalSurface.ground,
    'clay': CanonicalSurface.ground,
    // Provisional Pathgrain choice; revisit with barefoot field experience.
    'compacted': CanonicalSurface.ground,
    'sand': CanonicalSurface.sand,
    'rock': CanonicalSurface.stone,
    'stone': CanonicalSurface.stone,
    'stepping_stones': CanonicalSurface.stone,
    'fine_gravel': CanonicalSurface.fineGravel,
    'pebblestone': CanonicalSurface.fineGravel,
    'crushed_stone': CanonicalSurface.crushedStone,
    // Generic gravel cannot distinguish rounded gravel from sharp aggregate.
    'grass': CanonicalSurface.grass,
    'artificial_turf': CanonicalSurface.artificialTurf,
    'rubber': CanonicalSurface.rubber,
    'tartan': CanonicalSurface.rubber,
    'wood': CanonicalSurface.wood,
    'metal': CanonicalSurface.metal,
    'metal_grid': CanonicalSurface.metal,
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
