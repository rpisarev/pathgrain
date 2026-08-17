import 'app_database.dart';
import 'walk_distance.dart';
import 'walk_models.dart';

class WalkRepository {
  WalkRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  static const String _walkSelect = '''
    SELECT
      w.id,
      w.started_at_ms,
      w.ended_at_ms,
      w.duration_ms,
      w.distance_meters,
      w.status,
      COUNT(p.id) AS point_count
    FROM walks w
    LEFT JOIN walk_points p ON p.walk_id = w.id
  ''';

  Future<Walk> createWalk(DateTime startedAt) async {
    final database = await _appDatabase.database;
    final normalizedStart = startedAt.toUtc();
    final id = await database.insert('walks', {
      'started_at_ms': normalizedStart.millisecondsSinceEpoch,
      'distance_meters': 0.0,
      'status': WalkStatus.recording.databaseValue,
    });
    return Walk(
      id: id,
      startedAt: normalizedStart,
      endedAt: null,
      durationMilliseconds: null,
      distanceMeters: 0,
      status: WalkStatus.recording,
      pointCount: 0,
    );
  }

  Future<WalkPoint> appendPoint(int walkId, LocationSample sample) async {
    final database = await _appDatabase.database;
    return database.transaction((transaction) async {
      final sequenceRows = await transaction.rawQuery(
        '''
        SELECT COALESCE(MAX(sequence), -1) + 1 AS next_sequence
        FROM walk_points
        WHERE walk_id = ?
        ''',
        [walkId],
      );
      final sequence = sequenceRows.single['next_sequence']! as int;
      final recordedAt = sample.recordedAt.toUtc();

      await transaction.insert('walk_points', {
        'walk_id': walkId,
        'sequence': sequence,
        'latitude': sample.latitude,
        'longitude': sample.longitude,
        'recorded_at_ms': recordedAt.millisecondsSinceEpoch,
        'accuracy_meters': sample.accuracyMeters,
      });

      return WalkPoint(
        walkId: walkId,
        sequence: sequence,
        latitude: sample.latitude,
        longitude: sample.longitude,
        recordedAt: recordedAt,
        accuracyMeters: sample.accuracyMeters,
      );
    });
  }

  Future<List<WalkPoint>> pointsForWalk(int walkId) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'walk_points',
      where: 'walk_id = ?',
      whereArgs: [walkId],
      orderBy: 'sequence ASC',
    );
    return rows.map(_pointFromRow).toList(growable: false);
  }

  Future<List<Walk>> listWalks() async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery(
      '''
      $_walkSelect
      WHERE w.status != ?
      GROUP BY w.id
      ORDER BY w.started_at_ms DESC
      ''',
      [WalkStatus.recording.databaseValue],
    );
    return rows.map(_walkFromRow).toList(growable: false);
  }

  Future<Walk?> walkById(int walkId) async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery(
      '''
      $_walkSelect
      WHERE w.id = ?
      GROUP BY w.id
      ''',
      [walkId],
    );
    return rows.isEmpty ? null : _walkFromRow(rows.single);
  }

  Future<Walk> finishWalk({
    required int walkId,
    required DateTime endedAt,
    required WalkStatus status,
  }) async {
    assert(status != WalkStatus.recording);
    final database = await _appDatabase.database;
    final walk = await walkById(walkId);
    if (walk == null) {
      throw StateError('Walk $walkId does not exist.');
    }

    final points = await pointsForWalk(walkId);
    var normalizedEnd = endedAt.toUtc();
    if (normalizedEnd.isBefore(walk.startedAt)) {
      normalizedEnd = walk.startedAt;
    }
    final duration = normalizedEnd.difference(walk.startedAt);
    final distance = WalkDistance.total(points);

    await database.update(
      'walks',
      {
        'ended_at_ms': normalizedEnd.millisecondsSinceEpoch,
        'duration_ms': duration.inMilliseconds,
        'distance_meters': distance,
        'status': status.databaseValue,
      },
      where: 'id = ?',
      whereArgs: [walkId],
    );

    return (await walkById(walkId))!;
  }

  Future<void> recoverInterruptedWalks() async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery(
      '''
      $_walkSelect
      WHERE w.status = ?
      GROUP BY w.id
      ORDER BY w.started_at_ms ASC
      ''',
      [WalkStatus.recording.databaseValue],
    );

    for (final row in rows) {
      final walk = _walkFromRow(row);
      final points = await pointsForWalk(walk.id);
      final recoveredEnd = points.isEmpty
          ? walk.startedAt
          : points.last.recordedAt;
      await finishWalk(
        walkId: walk.id,
        endedAt: recoveredEnd,
        status: WalkStatus.interrupted,
      );
    }
  }

  Walk _walkFromRow(Map<String, Object?> row) {
    final endedAtMilliseconds = row['ended_at_ms'] as int?;
    return Walk(
      id: row['id']! as int,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        row['started_at_ms']! as int,
        isUtc: true,
      ),
      endedAt: endedAtMilliseconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              endedAtMilliseconds,
              isUtc: true,
            ),
      durationMilliseconds: row['duration_ms'] as int?,
      distanceMeters: (row['distance_meters']! as num).toDouble(),
      status: WalkStatus.fromDatabase(row['status']! as String),
      pointCount: row['point_count']! as int,
    );
  }

  WalkPoint _pointFromRow(Map<String, Object?> row) {
    return WalkPoint(
      walkId: row['walk_id']! as int,
      sequence: row['sequence']! as int,
      latitude: (row['latitude']! as num).toDouble(),
      longitude: (row['longitude']! as num).toDouble(),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        row['recorded_at_ms']! as int,
        isUtc: true,
      ),
      accuracyMeters: (row['accuracy_meters']! as num).toDouble(),
    );
  }
}
