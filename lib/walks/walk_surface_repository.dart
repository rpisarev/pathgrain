import 'package:sqflite/sqflite.dart';

import 'analysis/route_analysis.dart';
import 'analysis/surface_journal.dart';
import 'analysis/surface_segmenter.dart';
import 'analysis/walk_surface_summary.dart';
import 'app_database.dart';
import 'walk_models.dart';

/// Durable journal data in the walk database, independent of the OSM cache.
class WalkSurfaceRepository {
  WalkSurfaceRepository(this._appDatabase);
  final AppDatabase _appDatabase;

  Future<SurfaceJournal?> load(int walkId, List<WalkPoint> points) async {
    final database = await _appDatabase.database;
    return database.transaction((txn) => _load(txn, walkId, points));
  }

  Future<SurfaceJournal> saveAnalysis(
    int walkId,
    WalkSurfaceSummary summary, {
    required bool evidenceComplete,
  }) async {
    if (!evidenceComplete) {
      throw const FormatException(
        'Incomplete evidence cannot replace a snapshot',
      );
    }
    final automatic = AutomaticSurfaceSnapshot.fromSummary(summary);
    if (automatic.points.length < 2) {
      throw const FormatException('No original edges');
    }
    final database = await _appDatabase.database;
    return database.transaction((txn) async {
      await _verifyPoints(txn, walkId, automatic.points);
      final headers = await txn.query(
        'walk_surface_analyses',
        where: 'walk_id = ?',
        whereArgs: [walkId],
      );
      final corrections = await _corrections(
        txn,
        walkId,
        automatic.points.length - 1,
      );
      // A damaged automatic snapshot can be replaced, but observations cannot
      // be reassigned to a changed point sequence or silently discarded.
      if (corrections.isNotEmpty) {
        if (headers.length != 1) {
          throw const FormatException('Missing journal identity');
        }
        _validateHeader(headers.single, automatic.points.length);
      }
      final journal = SurfaceJournal(automatic, corrections);
      final header = {
        'point_count': automatic.points.length,
        'points_valid': 1,
      };
      if (headers.isEmpty) {
        await txn.insert('walk_surface_analyses', {
          'walk_id': walkId,
          ...header,
        });
      } else {
        await txn.update(
          'walk_surface_analyses',
          header,
          where: 'walk_id = ?',
          whereArgs: [walkId],
        );
      }
      // Never REPLACE the parent row: that would cascade-delete corrections.
      await txn.delete(
        'walk_surface_segments',
        where: 'walk_id = ?',
        whereArgs: [walkId],
      );
      final batch = txn.batch();
      for (var i = 0; i < automatic.segments.length; i++) {
        final segment = automatic.segments[i];
        batch.insert('walk_surface_segments', {
          'walk_id': walkId,
          'ordinal': i,
          'start_edge': segment.startEdgeIndex,
          'end_edge': segment.endEdgeIndex,
          'surface': segment.surface.surface.name,
          'assignment': segment.surface.assignment.name,
          'surface_reason': segment.surface.reason.name,
          'edge_reason': segment.reason.name,
          // Existing C merge boundaries use this ordered pair; retain it to
          // reconstruct that snapshot faithfully, without matcher candidates.
          'from_feature_key': segment.fromFeatureKey,
          'to_feature_key': segment.toFeatureKey,
        });
      }
      await batch.commit(noResult: true);
      return journal;
    });
  }

  Future<SurfaceJournal> saveCorrection(
    int walkId,
    List<WalkPoint> points,
    SurfaceCorrection correction,
  ) async {
    final database = await _appDatabase.database;
    return database.transaction((txn) async {
      final current = await _load(txn, walkId, points);
      if (current == null) {
        throw const FormatException('Missing automatic snapshot');
      }
      final corrections = [
        ...current.corrections.where((c) => !c.sameRange(correction)),
        correction,
      ]..sort((a, b) => a.startEdgeIndex.compareTo(b.startEdgeIndex));
      // Reject partial overlaps. An exact-range edit replaces one observation.
      final journal = SurfaceJournal(current.automatic, corrections);
      if (correction.matchesAutomatic(current.automatic)) {
        return _restoreAutomatic(txn, walkId, current, correction);
      }
      await txn.delete(
        'walk_surface_corrections',
        where: 'walk_id = ? AND start_edge = ? AND end_edge = ?',
        whereArgs: [walkId, correction.startEdgeIndex, correction.endEdgeIndex],
      );
      await txn.insert('walk_surface_corrections', {
        'walk_id': walkId,
        'start_edge': correction.startEdgeIndex,
        'end_edge': correction.endEdgeIndex,
        'surface': correction.surface.name,
      });
      return journal;
    });
  }

  Future<SurfaceJournal> restoreAutomatic(
    int walkId,
    List<WalkPoint> points,
    SurfaceCorrection correction,
  ) async {
    final database = await _appDatabase.database;
    return database.transaction((txn) async {
      final current = await _load(txn, walkId, points);
      if (current == null) {
        throw const FormatException('Missing automatic snapshot');
      }
      return _restoreAutomatic(txn, walkId, current, correction);
    });
  }

  Future<SurfaceJournal> _restoreAutomatic(
    Transaction txn,
    int walkId,
    SurfaceJournal current,
    SurfaceCorrection correction,
  ) async {
    final journal = SurfaceJournal(
      current.automatic,
      current.corrections.where((c) => !c.sameRange(correction)),
    );
    await txn.delete(
      'walk_surface_corrections',
      where: 'walk_id = ? AND start_edge = ? AND end_edge = ?',
      whereArgs: [walkId, correction.startEdgeIndex, correction.endEdgeIndex],
    );
    return journal;
  }

  Future<SurfaceJournal?> _load(
    Transaction txn,
    int walkId,
    List<WalkPoint> points,
  ) async {
    try {
      final headers = await txn.query(
        'walk_surface_analyses',
        where: 'walk_id = ?',
        whereArgs: [walkId],
      );
      if (headers.isEmpty) return null;
      await _verifyPoints(txn, walkId, points);
      _validateHeader(headers.single, points.length);
      final rows = await txn.query(
        'walk_surface_segments',
        where: 'walk_id = ?',
        whereArgs: [walkId],
        orderBy: 'ordinal ASC',
      );
      final segments = <SurfaceSegment>[];
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (row['ordinal'] != i) {
          throw const FormatException('Unordered segments');
        }
        segments.add(
          SurfaceSegment.fromRange(
            points: points,
            startEdgeIndex: row['start_edge'] as int,
            endEdgeIndex: row['end_edge'] as int,
            surface: SurfaceAssessment(
              _enum(CanonicalSurface.values, row['surface']),
              _enum(SurfaceAssignment.values, row['assignment']),
              _enum(AnalysisReason.values, row['surface_reason']),
            ),
            reason: _enum(AnalysisReason.values, row['edge_reason']),
            fromFeatureKey: row['from_feature_key'] as String?,
            toFeatureKey: row['to_feature_key'] as String?,
          ),
        );
      }
      return SurfaceJournal(
        AutomaticSurfaceSnapshot(points: points, segments: segments),
        await _corrections(txn, walkId, points.length - 1),
      );
    } on TypeError {
      throw const FormatException('Invalid journal data types');
    }
  }

  static void _validateHeader(Map<String, Object?> header, int pointCount) {
    if (pointCount < 2 ||
        header['point_count'] != pointCount ||
        header['points_valid'] != 1) {
      throw const FormatException('Journal point sequence changed');
    }
  }

  static T _enum<T extends Enum>(List<T> values, Object? value) {
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    throw const FormatException('Invalid journal enum');
  }

  Future<List<SurfaceCorrection>> _corrections(
    Transaction txn,
    int walkId,
    int edgeCount,
  ) async {
    try {
      final rows = await txn.query(
        'walk_surface_corrections',
        where: 'walk_id = ?',
        whereArgs: [walkId],
        orderBy: 'start_edge ASC, end_edge ASC',
      );
      final corrections = [
        for (final row in rows)
          SurfaceCorrection(
            startEdgeIndex: row['start_edge'] as int,
            endEdgeIndex: row['end_edge'] as int,
            surface: _enum(CanonicalSurface.values, row['surface']),
          ),
      ];
      SurfaceCorrection.validate(corrections, edgeCount);
      return corrections;
    } on TypeError {
      throw const FormatException('Invalid correction data types');
    }
  }

  /// Compare the analysis input with the database inside the writing/reading
  /// transaction. The persistent invalidation flag detects earlier mutations.
  Future<void> _verifyPoints(
    Transaction txn,
    int walkId,
    List<WalkPoint> points,
  ) async {
    final walks = await txn.query(
      'walks',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [walkId],
    );
    if (walks.length != 1 ||
        walks.single['status'] == WalkStatus.recording.name) {
      throw const FormatException('Surface journal requires a saved walk');
    }
    final rows = await txn.query(
      'walk_points',
      where: 'walk_id = ?',
      whereArgs: [walkId],
      orderBy: 'sequence ASC',
    );
    if (rows.length != points.length) {
      throw const FormatException('Point count changed');
    }
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final point = points[i];
      if (point.walkId != walkId ||
          row['sequence'] != point.sequence ||
          row['latitude'] != point.latitude ||
          row['longitude'] != point.longitude ||
          row['recorded_at_ms'] != point.recordedAt.millisecondsSinceEpoch ||
          row['accuracy_meters'] != point.accuracyMeters) {
        throw const FormatException('Point sequence changed');
      }
    }
  }
}
