import 'dart:convert';
import 'dart:math' as math;

import 'package:pathgrain/map/evidence/geographic_cell.dart';
import 'package:pathgrain/map/evidence/osm_evidence.dart';
import 'package:pathgrain/walks/walk_models.dart';

// Entirely synthetic local meter grid near (1, 2), unrelated to field tracks.
GeoCoordinate grid(double east, double north) => GeoCoordinate(
  1 + north / 6371000 * 180 / math.pi,
  2 + east / (6371000 * math.cos(math.pi / 180)) * 180 / math.pi,
);

WalkPoint sample(
  int sequence,
  double east,
  double north, {
  double accuracy = 7,
  double? seconds,
}) {
  final p = grid(east, north);
  return WalkPoint(
    walkId: 17,
    sequence: sequence,
    latitude: p.latitude,
    longitude: p.longitude,
    recordedAt: DateTime.utc(
      2026,
      1,
      1,
    ).add(Duration(milliseconds: ((seconds ?? sequence * 8) * 1000).round())),
    accuracyMeters: accuracy,
  );
}

OsmFeature way(
  int id,
  List<(double, double)> vertices, {
  Map<String, String> tags = const {'highway': 'footway', 'surface': 'grass'},
}) => OsmEvidence.parse(
  jsonEncode({
    'elements': [
      {
        'type': 'way',
        'id': id,
        'tags': tags,
        'geometry': [
          for (final (east, north) in vertices)
            {
              'lat': grid(east, north).latitude,
              'lon': grid(east, north).longitude,
            },
        ],
      },
    ],
  }),
).features.single;

List<WalkPoint> straight({
  int count = 10,
  double north = 2,
  double accuracy = 7,
}) => [
  for (var i = 0; i < count; i++)
    sample(i, i * 10.0, north, accuracy: accuracy),
];

OsmFeature straightPath({
  int id = 1,
  double north = 0,
  Map<String, String> tags = const {'highway': 'footway', 'surface': 'grass'},
}) => way(id, [(-30, north), (150, north)], tags: tags);
