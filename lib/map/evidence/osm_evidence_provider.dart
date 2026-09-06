import 'geographic_cell.dart';
import 'osm_evidence.dart';

enum EvidenceFailure {
  offline,
  timeout,
  rateLimited,
  unavailable,
  invalidResponse,
  responseTooLarge,
}

/// Deliberately contains no URL, query, coordinates, or server response text.
class EvidenceException implements Exception {
  const EvidenceException(this.failure, {this.retryAfter});

  final EvidenceFailure failure;
  final Duration? retryAfter;
}

abstract interface class OsmEvidenceProvider {
  String get cacheNamespace;

  /// This boundary accepts a fixed cell, never a walk or a GPS point list.
  Future<OsmEvidence> fetchCell(GeographicCell cell);
}
