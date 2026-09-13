import 'dart:convert';
import 'dart:io';

import 'package:pathgrain/map/evidence/evidence_assembly.dart';
import 'package:pathgrain/map/evidence/geographic_cell.dart';
import 'package:pathgrain/map/evidence/osm_evidence.dart';
import 'package:pathgrain/walks/analysis/surface_replay.dart';
import 'package:pathgrain/walks/walk_models.dart';

/// Development-only adapter. Python stdlib provides read-only SQLite access;
/// route cell selection, parsing and deduplication stay in production Dart.
class CapturedSurfaceInput {
  CapturedSurfaceInput(this.input, this.persistedSegments, this.headers);
  final SurfaceReplayInput input;
  final List<dynamic> persistedSegments;
  final List<dynamic> headers;
}

Future<CapturedSurfaceInput> readSurfaceCapture({
  required String walkDatabase,
  required String evidenceDatabase,
  required int walkId,
  String? namespace,
  String readerPath = 'tool/read_surface_capture.py',
}) async {
  Future<Map<String, dynamic>> read(Map<String, Object?> request) async {
    final process = await Process.start('python3', [readerPath]);
    // Drain both pipes while the child runs, including large cache payloads.
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    process.stdin.write(jsonEncode(request));
    await process.stdin.close();
    final code = await process.exitCode;
    final body = await output;
    final error = await errors;
    if (code != 0) throw FormatException(error.trim());
    return jsonDecode(body) as Map<String, dynamic>;
  }

  final route = await read({
    'kind': 'walk',
    'database': walkDatabase,
    'walkId': walkId,
  });
  final points = [
    for (final p in route['points'] as List)
      WalkPoint(
        walkId: walkId,
        sequence: p['sequence'] as int,
        latitude: (p['latitude'] as num).toDouble(),
        longitude: (p['longitude'] as num).toDouble(),
        recordedAt: DateTime.fromMillisecondsSinceEpoch(
          p['recorded_at_ms'] as int,
          isUtc: true,
        ),
        accuracyMeters: (p['accuracy_meters'] as num).toDouble(),
      ),
  ];
  final requiredCells = GeographicCell.covering(
    points.map((p) => GeoCoordinate(p.latitude, p.longitude)),
  );
  final evidence = await read({
    'kind': 'cells',
    'database': evidenceDatabase,
    'namespace': namespace,
    'cells': requiredCells.map((c) => c.key).toList(),
  });
  return CapturedSurfaceInput(
    SurfaceReplayInput(
      points: points,
      namespace: evidence['namespace'] as String,
      cells: {
        for (final row in evidence['cells'] as List)
          requiredCells.singleWhere(
            (c) => c.key == row['cell'],
          ): CachedEvidence(
            evidence: OsmEvidence.parse(row['evidence_json'] as String),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(
              row['fetched_at_ms'] as int,
              isUtc: true,
            ),
          ),
      },
    ),
    route['segments'] as List,
    route['header'] as List,
  );
}
