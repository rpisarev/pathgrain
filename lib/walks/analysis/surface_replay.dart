import 'dart:convert';

import '../../map/evidence/evidence_assembly.dart';
import '../../map/evidence/geographic_cell.dart';
import '../../map/evidence/osm_evidence.dart';
import '../walk_models.dart';
import 'match_audit.dart';
import 'route_matcher.dart';
import 'surface_diagnostics.dart';
import 'walk_surface_summary.dart';

/// Fixed local input. No provider, clock, SQLite or platform dependency.
/// Retains only cells required by these saved points, not unrelated cache history.
class SurfaceReplayInput {
  SurfaceReplayInput({
    required Iterable<WalkPoint> points,
    required Map<GeographicCell, CachedEvidence> cells,
    required this.namespace,
  }) : points = List.unmodifiable(points) {
    if (this.points.map((p) => p.walkId).toSet().length > 1) {
      throw const FormatException('Replay input must contain one saved walk');
    }
    if (this.points.any((p) => !p.accuracyMeters.isFinite)) {
      throw const FormatException(
        'Replay accuracy must be finite for JSON export',
      );
    }
    requiredCells = List.unmodifiable(
      GeographicCell.covering(
        this.points.map((p) => GeoCoordinate(p.latitude, p.longitude)),
      ),
    );
    this.cells = Map.unmodifiable({
      for (final cell in requiredCells)
        if (cells.containsKey(cell)) cell: cells[cell]!,
    });
  }

  static const schemaVersion = 1;
  final List<WalkPoint> points;
  final String namespace;
  late final List<GeographicCell> requiredCells;
  late final Map<GeographicCell, CachedEvidence> cells;

  factory SurfaceReplayInput.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != 'pathgrain.surface-replay-input' ||
        json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported replay input schema');
    }
    final cells = <GeographicCell, CachedEvidence>{};
    for (final raw in json['cells'] as List) {
      final key = (raw['key'] as String).split('/').map(int.parse).toList();
      if (key.length != 3 ||
          key[0] < 0 ||
          key[0] > 22 ||
          key[1] < 0 ||
          key[1] >= 1 << key[0] ||
          key[2] < 0 ||
          key[2] >= 1 << key[0]) {
        throw const FormatException('Invalid replay cell');
      }
      final cell = GeographicCell(key[1], key[2], zoom: key[0]);
      if (cells.containsKey(cell)) {
        throw const FormatException('Duplicate replay cell');
      }
      cells[cell] = CachedEvidence(
        fetchedAt: DateTime.fromMicrosecondsSinceEpoch(
          raw['fetchedAtMicroseconds'] as int,
          isUtc: true,
        ),
        evidence: OsmEvidence.parse(jsonEncode(raw['evidence'])),
      );
    }
    return SurfaceReplayInput(
      namespace: json['namespace'] as String,
      cells: cells,
      points: [
        for (final raw in json['points'] as List)
          WalkPoint(
            walkId: 0,
            sequence: raw['sequence'] as int,
            latitude: (raw['latitude'] as num).toDouble(),
            longitude: (raw['longitude'] as num).toDouble(),
            accuracyMeters: (raw['accuracyMeters'] as num).toDouble(),
            recordedAt: DateTime.fromMicrosecondsSinceEpoch(
              raw['elapsedMicroseconds'] as int,
              isUtc: true,
            ),
          ),
      ],
    );
  }

  /// Sensitive local artifact: contains exact route and real OSM geometry.
  /// No walk ID, device metadata or absolute recording timestamps are exported.
  Map<String, Object?> toJson() => {
    'schema': 'pathgrain.surface-replay-input',
    'schemaVersion': schemaVersion,
    'namespace': namespace,
    'points': [
      for (final p in points)
        {
          'sequence': p.sequence,
          'latitude': p.latitude,
          'longitude': p.longitude,
          'accuracyMeters': p.accuracyMeters,
          'elapsedMicroseconds': p.recordedAt
              .difference(points.first.recordedAt)
              .inMicroseconds,
        },
    ],
    'cells': [
      for (final e in cells.entries)
        {
          'key': e.key.key,
          'fetchedAtMicroseconds': e.value.fetchedAt.microsecondsSinceEpoch,
          'evidence': e.value.evidence.raw,
        },
    ],
  };
}

class SurfaceReplayResult {
  SurfaceReplayResult._(
    this.input,
    this.evidence,
    this.complete,
    this.diagnostics,
  );

  final SurfaceReplayInput input;
  final EvidenceAssembly evidence;
  final bool complete;
  final SurfaceDiagnostics diagnostics;

  Map<String, Object?> toJson({String? implementationRevision}) => {
    ...diagnostics.toJson(),
    'implementationRevision': implementationRevision,
    'evidence': {
      'namespace': input.namespace,
      'complete': complete,
      'requiredCells': input.requiredCells.map((c) => c.key).toList(),
      'availableCells': input.cells.keys.map((c) => c.key).toList(),
      'unparsedElements': evidence.unparsedElements,
      'featureOccurrences': evidence.featureOccurrences,
      'uniqueFeatures': evidence.features.length,
      'duplicateOccurrences': evidence.duplicateOccurrences,
      'cells': [
        for (final e in input.cells.entries)
          {
            'key': e.key.key,
            'fetchedAtMicroseconds': e.value.fetchedAt.microsecondsSinceEpoch,
            'osmBaseTimestamp': e.value.evidence.osmBaseTimestamp,
            'parsedFeatures': e.value.evidence.features.length,
            'unparsedElements': e.value.evidence.unparsedElements,
          },
      ],
    },
  };
}

abstract final class SurfaceReplay {
  static SurfaceReplayResult run(SurfaceReplayInput input) {
    final evidence = EvidenceAssembly(input.cells);
    // Terminal fixed snapshot: same all-cell/unparsed gate as EvidenceSnapshot.
    final complete = evidenceCoverageIsComplete(
      totalCells: input.requiredCells.length,
      availableCells: input.cells.length,
      unparsedElements: evidence.unparsedElements,
    );
    final audits = <SampleMatchAudit>[];
    final analysis = RouteMatcher.analyze(
      input.points,
      evidence.features,
      evidenceComplete: complete,
      onAudit: audits.add,
    );
    return SurfaceReplayResult._(
      input,
      evidence,
      complete,
      SurfaceDiagnostics(WalkSurfaceSummary.fromAnalysis(analysis), audits),
    );
  }
}
