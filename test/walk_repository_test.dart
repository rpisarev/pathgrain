import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pathgrain/walks/app_database.dart';
import 'package:pathgrain/walks/walk_models.dart';
import 'package:pathgrain/walks/walk_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('completed walk and ordered points survive a database reopen', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'pathgrain_repository_test.',
    );
    final databasePath = path.join(temporaryDirectory.path, 'walks.sqlite');
    AppDatabase? appDatabase;
    addTearDown(() async {
      await appDatabase?.close();
      await temporaryDirectory.delete(recursive: true);
    });

    final startedAt = DateTime.utc(2026, 8, 16, 8);
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    var repository = WalkRepository(appDatabase);
    final activeWalk = await repository.createWalk(startedAt);
    await repository.appendPoint(
      activeWalk.id,
      LocationSample(
        latitude: 50.4501,
        longitude: 30.5234,
        recordedAt: startedAt.add(const Duration(seconds: 5)),
        accuracyMeters: 5,
      ),
    );
    await repository.appendPoint(
      activeWalk.id,
      LocationSample(
        latitude: 50.45015,
        longitude: 30.5234,
        recordedAt: startedAt.add(const Duration(seconds: 10)),
        accuracyMeters: 4,
      ),
    );
    final completed = await repository.finishWalk(
      walkId: activeWalk.id,
      endedAt: startedAt.add(const Duration(minutes: 10)),
      status: WalkStatus.completed,
    );

    expect(completed.pointCount, 2);
    expect(completed.duration, const Duration(minutes: 10));
    expect(completed.distanceMeters, greaterThan(5));

    await appDatabase.close();
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    repository = WalkRepository(appDatabase);

    final reopenedWalks = await repository.listWalks();
    final reopenedPoints = await repository.pointsForWalk(activeWalk.id);

    expect(reopenedWalks, hasLength(1));
    expect(reopenedWalks.single.status, WalkStatus.completed);
    expect(reopenedWalks.single.pointCount, 2);
    expect(reopenedWalks.single.duration, const Duration(minutes: 10));
    expect(
      reopenedPoints.map((point) => point.sequence),
      orderedEquals([0, 1]),
    );
    expect(reopenedPoints.last.latitude, closeTo(50.45015, 0.0000001));
  });

  test('unfinished database walk is retained as interrupted', () async {
    final appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(appDatabase.close);
    final repository = WalkRepository(appDatabase);
    final startedAt = DateTime.utc(2026, 8, 16, 9);
    final activeWalk = await repository.createWalk(startedAt);
    await repository.appendPoint(
      activeWalk.id,
      LocationSample(
        latitude: 50.4501,
        longitude: 30.5234,
        recordedAt: startedAt.add(const Duration(seconds: 12)),
        accuracyMeters: 5,
      ),
    );

    await repository.recoverInterruptedWalks();

    final recovered = (await repository.listWalks()).single;
    expect(recovered.status, WalkStatus.interrupted);
    expect(recovered.pointCount, 1);
    expect(recovered.duration, const Duration(seconds: 12));
    expect(await repository.pointsForWalk(recovered.id), hasLength(1));
  });
}
