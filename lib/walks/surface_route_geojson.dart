import 'analysis/route_analysis.dart';
import 'analysis/surface_journal.dart';

/// Shared legend/map colors. UNKNOWN has its own visible color.
abstract final class SurfaceRouteGeoJson {
  static String color(CanonicalSurface surface) => switch (surface) {
    CanonicalSurface.grass => '#2E7D32',
    CanonicalSurface.asphalt => '#263238',
    CanonicalSurface.concrete => '#546E7A',
    CanonicalSurface.ground => '#795548',
    CanonicalSurface.gravel => '#B26A00',
    CanonicalSurface.pavingStones => '#1565C0',
    CanonicalSurface.other => '#7B1FA2',
    CanonicalSurface.unknown => '#C62828',
  };

  /// Local MapLibre data: each line is an exact slice of the original samples.
  /// Adjacent segments share a boundary point, never an edge. No OSM geometry.
  static Map<String, Object?> build(EffectiveSurfaceSummary summary) => {
    'type': 'FeatureCollection',
    'features': [
      for (final segment in summary.segments)
        {
          'type': 'Feature',
          'properties': {
            'surface': segment.surface.name,
            'color': color(segment.surface),
            'startEdge': segment.startEdgeIndex,
            'endEdge': segment.endEdgeIndex,
            'corrected': segment.isCorrected,
          },
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (
                var i = segment.startEdgeIndex;
                i <= segment.endEdgeIndex;
                i++
              )
                [summary.points[i].longitude, summary.points[i].latitude],
            ],
          },
        },
    ],
  };
}
