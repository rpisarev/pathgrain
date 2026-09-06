import 'dart:convert';

import 'geographic_cell.dart';

enum OsmElementType { node, way, relation }

enum OsmGeometryKind { point, line, closedArea, relation, unavailable }

enum OsmGeometryLimitation { incompleteGeometry, relationOutlinesOnly }

class OsmFeature {
  const OsmFeature({
    required this.type,
    required this.id,
    required this.tags,
    required this.geometryKind,
    required this.parts,
    required this.isArea,
    required this.limitations,
    required this.raw,
  });

  final OsmElementType type;
  final int id;
  final Map<String, String> tags;
  final OsmGeometryKind geometryKind;

  /// Points, contiguous way pieces, or individual relation member pieces.
  /// Relation members are not assembled into polygons or joined across gaps.
  final List<List<GeoCoordinate>> parts;
  final bool isArea;
  final Set<OsmGeometryLimitation> limitations;

  /// Retains member IDs/roles, missing geometry, and other returned OSM fields.
  final Map<String, dynamic> raw;

  String get key => '${type.name}/$id';
}

class OsmEvidence {
  const OsmEvidence({
    required this.features,
    required this.raw,
    required this.unparsedElements,
  });

  final List<OsmFeature> features;
  final Map<String, dynamic> raw;
  final int unparsedElements;

  String? get osmBaseTimestamp =>
      (raw['osm3s'] as Map?)?['timestamp_osm_base'] as String?;
  String? get generator => raw['generator'] as String?;

  factory OsmEvidence.parse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic> ||
        decoded['elements'] is! List ||
        decoded.containsKey('remark')) {
      // Overpass can return HTTP 200 with a timeout/partial-data remark.
      // Such a response must not replace a complete cached cell.
      throw const FormatException('Incomplete or invalid Overpass response');
    }
    final features = <OsmFeature>[];
    var unparsed = 0;
    for (final element in decoded['elements'] as List) {
      if (element is! Map<String, dynamic>) {
        unparsed++;
        continue;
      }
      final feature = _parseElement(element);
      if (feature == null) {
        unparsed++;
      } else {
        features.add(feature);
      }
    }
    return OsmEvidence(
      features: List.unmodifiable(features),
      raw: decoded,
      unparsedElements: unparsed,
    );
  }

  static OsmFeature? _parseElement(Map<String, dynamic> raw) {
    final type = switch (raw['type']) {
      'node' => OsmElementType.node,
      'way' => OsmElementType.way,
      'relation' => OsmElementType.relation,
      _ => null,
    };
    final id = raw['id'];
    if (type == null || id is! int) return null;
    final tags = <String, String>{};
    if (raw['tags'] case final Map rawTags) {
      for (final entry in rawTags.entries) {
        if (entry.key is String && entry.value is String) {
          tags[entry.key as String] = entry.value as String;
        }
      }
    }
    final isArea =
        tags['area'] != 'no' &&
        (tags['area'] == 'yes' ||
            (tags.containsKey('area:highway') &&
                tags['area:highway'] != 'no') ||
            (type == OsmElementType.relation &&
                tags['type'] == 'multipolygon'));
    final limitations = <OsmGeometryLimitation>{};
    final parts = <List<GeoCoordinate>>[];
    var kind = OsmGeometryKind.unavailable;

    if (type == OsmElementType.node) {
      final coordinate = _coordinate(raw);
      if (coordinate != null) {
        parts.add([coordinate]);
        kind = OsmGeometryKind.point;
      }
    } else if (type == OsmElementType.way) {
      parts.addAll(_geometryParts(raw['geometry'], limitations));
      if (parts.isNotEmpty) {
        kind = OsmGeometryKind.line;
        if (isArea &&
            parts.length == 1 &&
            parts.single.length >= 4 &&
            parts.single.first == parts.single.last &&
            limitations.isEmpty) {
          kind = OsmGeometryKind.closedArea;
        } else if (isArea) {
          limitations.add(OsmGeometryLimitation.incompleteGeometry);
        }
      }
    } else {
      kind = OsmGeometryKind.relation;
      limitations.add(OsmGeometryLimitation.relationOutlinesOnly);
      if (raw['members'] case final List members) {
        for (final member in members) {
          if (member is! Map) {
            limitations.add(OsmGeometryLimitation.incompleteGeometry);
          } else if (member['type'] == 'node') {
            final coordinate = _coordinate(member);
            if (coordinate != null) {
              parts.add([coordinate]);
            } else {
              limitations.add(OsmGeometryLimitation.incompleteGeometry);
            }
          } else {
            parts.addAll(_geometryParts(member['geometry'], limitations));
          }
        }
      }
    }
    if (parts.isEmpty) {
      limitations.add(OsmGeometryLimitation.incompleteGeometry);
    }
    return OsmFeature(
      type: type,
      id: id,
      tags: Map.unmodifiable(tags),
      geometryKind: kind,
      parts: List.unmodifiable(parts.map(List<GeoCoordinate>.unmodifiable)),
      isArea: isArea,
      limitations: Set.unmodifiable(limitations),
      raw: raw,
    );
  }

  static GeoCoordinate? _coordinate(Map raw) {
    if (raw['lat'] is! num || raw['lon'] is! num) return null;
    final point = GeoCoordinate(
      (raw['lat'] as num).toDouble(),
      (raw['lon'] as num).toDouble(),
    );
    return point.isValid ? point : null;
  }

  static List<List<GeoCoordinate>> _geometryParts(
    dynamic geometry,
    Set<OsmGeometryLimitation> limitations,
  ) {
    if (geometry is! List || geometry.isEmpty) {
      limitations.add(OsmGeometryLimitation.incompleteGeometry);
      return [];
    }
    final parts = <List<GeoCoordinate>>[];
    var current = <GeoCoordinate>[];
    void finishPart() {
      if (current.isNotEmpty) parts.add(current);
      current = [];
    }

    for (final rawPoint in geometry) {
      final point = rawPoint is Map ? _coordinate(rawPoint) : null;
      if (point == null) {
        limitations.add(OsmGeometryLimitation.incompleteGeometry);
        finishPart();
      } else {
        current.add(point);
      }
    }
    finishPart();
    return parts;
  }
}
