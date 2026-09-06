import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/map/evidence/evidence_geojson.dart';
import 'package:pathgrain/map/evidence/osm_evidence.dart';
import 'package:pathgrain/walks/walk_distance.dart';
import 'package:pathgrain/walks/walk_models.dart';

import 'support/evidence_fakes.dart';

void main() {
  late OsmEvidence evidence;
  setUp(() => evidence = OsmEvidence.parse(evidenceFixture()));
  OsmFeature feature(int id) =>
      evidence.features.singleWhere((element) => element.id == id);

  test(
    'road keeps all raw tags including independent sidewalk surface variants',
    () {
      final road = feature(100);
      expect(road.type, OsmElementType.way);
      expect(road.geometryKind, OsmGeometryKind.line);
      expect(road.tags['surface'], 'asphalt');
      expect(road.tags['sidewalk:left:surface'], 'paving_stones');
      expect(road.tags['sidewalk:right:surface'], 'concrete');
      expect(road.tags['sidewalk:both:surface'], 'paving_stones');
      expect(road.tags, road.raw['tags']);
      expect(evidence.osmBaseTimestamp, '2026-09-01T00:00:00Z');
    },
  );

  test(
    'separate sidewalk, untagged path, and crossing remain raw evidence',
    () {
      expect(feature(101).tags['footway'], 'sidewalk');
      expect(feature(101).tags['surface'], 'paving_stones');
      expect(feature(102).tags['highway'], 'path');
      expect(feature(102).tags.containsKey('surface'), isFalse);
      expect(feature(103).geometryKind, OsmGeometryKind.point);
      expect(feature(103).tags['crossing'], 'uncontrolled');
      expect(feature(107).tags['footway'], 'crossing');
    },
  );

  test(
    'explicit pedestrian and area:highway areas fill; closed roads do not',
    () {
      expect(feature(104).geometryKind, OsmGeometryKind.closedArea);
      expect(feature(105).geometryKind, OsmGeometryKind.closedArea);
      expect(feature(106).geometryKind, OsmGeometryKind.line);
      expect(feature(106).isArea, isFalse);
      final geoJson = EvidenceGeoJson.osm(evidence.features);
      final polygons = (geoJson['features'] as List).where(
        (element) => element['geometry']['type'] == 'Polygon',
      );
      expect(polygons, hasLength(2));
    },
  );

  test(
    'relation member roles and nested references persist without invented fill',
    () {
      final relation = feature(200);
      expect(relation.geometryKind, OsmGeometryKind.relation);
      expect(relation.parts, hasLength(3));
      expect(relation.limitations, containsAll(OsmGeometryLimitation.values));
      expect((relation.raw['members'] as List).last['ref'], 204);
      final geometry = EvidenceGeoJson.osm([relation])['features'] as List;
      expect(geometry, hasLength(3));
      expect(
        geometry.every((part) => part['geometry']['type'] == 'LineString'),
        isTrue,
      );
    },
  );

  test(
    'missing geometry splits lines, unavailable elements remain inspectable',
    () {
      expect(feature(107).parts, hasLength(2));
      expect(feature(107).parts.map((part) => part.length), [2, 2]);
      expect(feature(108).geometryKind, OsmGeometryKind.unavailable);
      expect(feature(108).tags['highway'], 'steps');
      expect(evidence.unparsedElements, 1);
      expect((evidence.raw['elements'] as List).last['type'], 'derived');
      expect(EvidenceGeoJson.osm([feature(108)])['features'], isEmpty);
    },
  );

  test(
    'incomplete HTTP-200 Overpass results and malformed documents are rejected',
    () {
      for (final body in [
        '{}',
        '[]',
        '<html>unavailable</html>',
        '{"elements": [], "remark": "runtime error: Query timed out"}',
      ]) {
        expect(() => OsmEvidence.parse(body), throwsFormatException);
      }
      expect(OsmEvidence.parse('{"elements": []}').features, isEmpty);
      expect(
        OsmEvidence.parse(jsonEncode(evidence.raw)).features.map((f) => f.key),
        evidence.features.map((f) => f.key),
      );
    },
  );

  test('local GPS geometry uses exactly the persisted samples; accuracy is in meters', () {
    final points = [
      WalkPoint(
        walkId: 987,
        sequence: 3,
        latitude: 1,
        longitude: 2,
        recordedAt: DateTime.utc(2026),
        accuracyMeters: 7.25,
      ),
      WalkPoint(
        walkId: 987,
        sequence: 8,
        latitude: 1.001,
        longitude: 2.001,
        recordedAt: DateTime.utc(2026, 1, 1, 0, 1),
        accuracyMeters: 25,
      ),
    ];
    final route = (EvidenceGeoJson.route(points)['features'] as List).single;
    expect(route['geometry']['coordinates'], [
      [2.0, 1.0],
      [2.001, 1.001],
    ]);
    final samples = EvidenceGeoJson.samples(points)['features'] as List;
    expect(samples.map((point) => point['properties']['sequence']), [3, 8]);
    for (final point in points) {
      final ring = EvidenceGeoJson.accuracyRing(point);
      expect(ring.first, ring.last);
      for (final vertex in ring) {
        final meters = WalkDistance.betweenCoordinates(
          latitudeA: point.latitude,
          longitudeA: point.longitude,
          latitudeB: vertex[1],
          longitudeB: vertex[0],
        );
        expect(meters, closeTo(point.accuracyMeters, 0.001));
      }
    }
  });
}
