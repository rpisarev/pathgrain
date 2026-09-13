import 'dart:convert';

import 'package:pathgrain/map/evidence/evidence_assembly.dart';
import 'package:pathgrain/map/evidence/geographic_cell.dart';
import 'package:pathgrain/map/evidence/osm_evidence.dart';
import 'package:pathgrain/walks/analysis/surface_replay.dart';
import 'package:pathgrain/walks/walk_models.dart';

// Only fabricated meter-grid routes and OSM IDs. Never derived field coordinates.
SurfaceReplayInput replayInput(
  List<WalkPoint> points,
  List<OsmFeature> features,
) => SurfaceReplayInput(
  points: points,
  namespace: 'synthetic-fixture-v1',
  cells: {
    for (final cell in GeographicCell.covering(
      points.map((p) => GeoCoordinate(p.latitude, p.longitude)),
    ))
      cell: CachedEvidence(
        evidence: OsmEvidence.parse(
          jsonEncode({'elements': features.map((f) => f.raw).toList()}),
        ),
        fetchedAt: DateTime.utc(2026),
      ),
  },
);
