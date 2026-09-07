import '../../walks/analysis/route_analysis.dart';
import 'evidence_geojson.dart';

/// Diagnostic overlays only; original route and sample sources stay intact.
abstract final class AnalysisGeoJson {
  static Map<String, dynamic> matches(
    RouteAnalysis? analysis,
    int? selectedSequence,
  ) {
    if (analysis == null) return EvidenceGeoJson.collection([]);
    String? selectedKey;
    final features = {
      for (final sample in analysis.samples)
        if (sample.selected != null)
          sample.selected!.feature.key: sample.selected!.feature,
    };
    for (final sample in analysis.samples) {
      if (sample.original.sequence == selectedSequence) {
        selectedKey = sample.selected?.feature.key;
      }
    }
    final geoJson = EvidenceGeoJson.osm(features.values);
    for (final feature in geoJson['features'] as List) {
      final properties = feature['properties'] as Map;
      properties['color'] = properties['evidenceKey'] == selectedKey
          ? '#AD1457'
          : '#00ACC1';
    }
    return geoJson;
  }

  static Map<String, dynamic> unknown(RouteAnalysis? analysis) =>
      EvidenceGeoJson.collection([
        if (analysis != null) ...[
          for (final edge in analysis.edges)
            if (edge.surface.assignment == SurfaceAssignment.unknown)
              {
                'type': 'Feature',
                'properties': {
                  'sequence': edge.to.original.sequence,
                  'fromSequence': edge.from.original.sequence,
                },
                'geometry': {
                  'type': 'LineString',
                  'coordinates': [
                    [edge.from.original.longitude, edge.from.original.latitude],
                    [edge.to.original.longitude, edge.to.original.latitude],
                  ],
                },
              },
          ...(EvidenceGeoJson.samples([
                    for (final sample in analysis.samples)
                      if (sample.surface.assignment ==
                          SurfaceAssignment.unknown)
                        sample.original,
                  ])['features']
                  as List)
              .cast<Map<String, dynamic>>(),
        ],
      ]);

  static Map<String, dynamic> focus(RouteAnalysis? analysis, int? sequence) =>
      EvidenceGeoJson.samples([
        if (analysis != null)
          for (final sample in analysis.samples)
            if (sample.original.sequence == sequence) sample.original,
      ]);
}
