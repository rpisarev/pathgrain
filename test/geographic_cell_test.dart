import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/map/evidence/evidence_settings.dart';
import 'package:pathgrain/map/evidence/geographic_cell.dart';

void main() {
  test('known z15 identities and Web Mercator latitude limits', () {
    expect(EvidenceSettings.cellZoom, 15);
    expect(
      GeographicCell.fromCoordinate(const GeoCoordinate(0, 0)),
      const GeographicCell(16384, 16384),
    );
    expect(
      GeographicCell.fromCoordinate(const GeoCoordinate(45, 90)),
      const GeographicCell(24576, 11787),
    );
    expect(
      GeographicCell.fromCoordinate(const GeoCoordinate(90, 180)),
      const GeographicCell(32767, 0),
    );
    expect(
      GeographicCell.fromCoordinate(const GeoCoordinate(-90, -180)),
      const GeographicCell(0, 32767),
    );
    expect(
      () => GeographicCell.fromCoordinate(const GeoCoordinate(double.nan, 0)),
      throwsFormatException,
    );
    expect(
      () => GeographicCell.fromCoordinate(const GeoCoordinate(0, 181)),
      throwsFormatException,
    );
  });

  test(
    'cell set is deduplicated and ordered independently of walking order',
    () {
      const points = [
        GeoCoordinate(1, 2),
        GeoCoordinate(0, 0),
        GeoCoordinate(0.0001, 0.0001),
        GeoCoordinate(1, 2),
        GeoCoordinate(-1, -2),
      ];
      final cells = GeographicCell.covering(points);
      expect(cells, hasLength(4));
      expect(GeographicCell.covering(points.reversed), cells);
      expect(cells, orderedEquals(cells.toList()..sort()));
      expect(GeographicCell.covering([]), isEmpty);
    },
  );

  test('cell bounding box and 30 meter padding depend only on the cell', () {
    const cell = GeographicCell(16384, 16384);
    final box = cell.bounds;
    expect(box.north, closeTo(0, 1e-10));
    expect(box.west, 0);
    expect(box.east, closeTo(0.010986328125, 1e-12));
    expect(box.south, closeTo(-0.0109863280577, 1e-10));
    final padded = cell.paddedBounds().single;
    expect(padded.north, closeTo(0.000269494585, 1e-10));
    expect(padded.west, closeTo(-0.000269494590, 1e-10));
    expect(padded.south, lessThan(box.south));
    expect(padded.east, greaterThan(box.east));
    expect(cell.paddedBounds(paddingMeters: 0).single.overpass, box.overpass);
    final fartherNorth = GeographicCell.fromCoordinate(
      const GeoCoordinate(60, 0),
    );
    expect(
      fartherNorth.bounds.west - fartherNorth.paddedBounds().single.west,
      closeTo(0.000539, 0.000001),
    );
  });

  test(
    'padding wraps both antimeridian edges into bounded canonical boxes',
    () {
      for (final cell in [
        const GeographicCell(0, 16384),
        const GeographicCell(32767, 16384),
      ]) {
        final boxes = cell.paddedBounds();
        expect(boxes, hasLength(2));
        expect(boxes.first.west, -180);
        expect(boxes.last.east, 180);
        for (final box in boxes) {
          expect(box.east - box.west, lessThan(0.02));
          expect(box.south, lessThan(box.north));
        }
      }
    },
  );
}
