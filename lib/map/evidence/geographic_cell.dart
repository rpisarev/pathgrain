import 'dart:math' as math;

import 'evidence_settings.dart';

class GeoCoordinate {
  const GeoCoordinate(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  List<double> get geoJson => [longitude, latitude];

  @override
  bool operator ==(Object other) =>
      other is GeoCoordinate &&
      latitude == other.latitude &&
      longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

class GeographicBounds {
  const GeographicBounds(this.south, this.west, this.north, this.east);

  final double south;
  final double west;
  final double north;
  final double east;

  /// Only fixed cell bounds belong in a remote query. Never log this string.
  String get overpass => [
    south,
    west,
    north,
    east,
  ].map((value) => value.toStringAsFixed(7)).join(',');
}

class GeographicCell implements Comparable<GeographicCell> {
  const GeographicCell(this.x, this.y, {this.zoom = EvidenceSettings.cellZoom})
    : assert(zoom >= 0 && zoom <= 22),
      assert(x >= 0 && x < (1 << zoom)),
      assert(y >= 0 && y < (1 << zoom));

  static const double mercatorLatitudeLimit = 85.0511287798066;
  static const double earthRadiusMeters = 6378137;

  final int x;
  final int y;
  final int zoom;

  factory GeographicCell.fromCoordinate(GeoCoordinate point) {
    if (!point.isValid) {
      throw const FormatException('Invalid geographic coordinate');
    }
    const count = 1 << EvidenceSettings.cellZoom;
    final latitude =
        point.latitude.clamp(-mercatorLatitudeLimit, mercatorLatitudeLimit) *
        math.pi /
        180;
    final x = ((point.longitude + 180) / 360 * count).floor();
    final y =
        ((1 - math.log(math.tan(latitude) + 1 / math.cos(latitude)) / math.pi) /
                2 *
                count)
            .floor();
    return GeographicCell(x.clamp(0, count - 1), y.clamp(0, count - 1));
  }

  /// Numeric z/x/y order, never the order in which a walker visited cells.
  static List<GeographicCell> covering(Iterable<GeoCoordinate> points) =>
      (points.map(GeographicCell.fromCoordinate).toSet().toList()..sort());

  String get key => '$zoom/$x/$y';

  GeographicBounds get bounds {
    final count = 1 << zoom;
    double latitude(int row) {
      final n = math.pi * (1 - 2 * row / count);
      return math.atan((math.exp(n) - math.exp(-n)) / 2) * 180 / math.pi;
    }

    return GeographicBounds(
      latitude(y + 1),
      x / count * 360 - 180,
      latitude(y),
      (x + 1) / count * 360 - 180,
    );
  }

  /// A fixed meter padding computed solely from the cell. Split at the
  /// antimeridian so neither edge loses its neighboring evidence.
  List<GeographicBounds> paddedBounds({
    double paddingMeters = EvidenceSettings.cellPaddingMeters,
  }) {
    if (!paddingMeters.isFinite || paddingMeters < 0 || paddingMeters > 1000) {
      throw ArgumentError('Invalid cell padding');
    }
    final box = bounds;
    final latitudePadding = paddingMeters / earthRadiusMeters * 180 / math.pi;
    final extremeLatitude = math.max(box.south.abs(), box.north.abs());
    final longitudePadding =
        latitudePadding / math.cos(extremeLatitude * math.pi / 180);
    final south = (box.south - latitudePadding).clamp(-90.0, 90.0);
    final north = (box.north + latitudePadding).clamp(-90.0, 90.0);
    final west = box.west - longitudePadding;
    final east = box.east + longitudePadding;
    if (west < -180) {
      return [
        GeographicBounds(south, -180, north, east),
        GeographicBounds(south, west + 360, north, 180),
      ];
    }
    if (east > 180) {
      return [
        GeographicBounds(south, -180, north, east - 360),
        GeographicBounds(south, west, north, 180),
      ];
    }
    return [GeographicBounds(south, west, north, east)];
  }

  @override
  int compareTo(GeographicCell other) {
    final zOrder = zoom.compareTo(other.zoom);
    if (zOrder != 0) return zOrder;
    final xOrder = x.compareTo(other.x);
    return xOrder != 0 ? xOrder : y.compareTo(other.y);
  }

  @override
  bool operator ==(Object other) =>
      other is GeographicCell &&
      zoom == other.zoom &&
      x == other.x &&
      y == other.y;

  @override
  int get hashCode => Object.hash(zoom, x, y);
}
