import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/platform/notification_permission.dart';
import 'package:pathgrain/walks/app_database.dart';
import 'package:pathgrain/walks/walk_models.dart';
import 'package:pathgrain/walks/walk_recording_controller.dart';
import 'package:pathgrain/walks/walk_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_doubles.dart';
import 'support/analysis_fixtures.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  for (final failWrite in [false, true]) {
    for (final interrupt in [false, true]) {
      test(
        'one completion drains Stop or interrupts (write failure: $failWrite, stream error: $interrupt)',
        () async {
          final app = AppDatabase(
            databaseFactory: databaseFactoryFfi,
            databasePath: inMemoryDatabasePath,
          );
          final repository = DelayedPointRepository(app, failWrite: failWrite);
          final location = TestLocationRecorder();
          final originals = straight(count: 3);
          var now = originals.first.recordedAt;
          final controller = WalkRecordingController(
            repository: repository,
            locationRecorder: location,
            notificationPermissionGateway:
                const TestNotificationPermissionGateway(
                  NotificationPermissionState.notRequired,
                ),
            now: () => now,
          );
          addTearDown(() async {
            controller.dispose();
            await location.close();
            await app.close();
          });
          await controller.initialize();
          await controller.startWalk(
            notificationTitle: 'Recording',
            notificationText: 'Local only',
            notificationChannelName: 'Walk recording',
          );
          final id = controller.activeWalk!.id;
          for (final p in originals) {
            location.emit(
              LocationSample(
                latitude: p.latitude,
                longitude: p.longitude,
                recordedAt: p.recordedAt,
                accuracyMeters: p.accuracyMeters,
              ),
            );
          }
          await repository.writeEntered.future;
          expect(controller.activePointCount, 1);
          now = now.add(const Duration(minutes: 1));
          Future<Walk?> finish() async {
            if (!interrupt) return controller.stopWalk();
            final ended = Completer<void>();
            void check() {
              if (controller.phase == WalkRecordingPhase.error &&
                  !ended.isCompleted) {
                ended.complete();
              }
            }

            controller.addListener(check);
            location.emitError();
            await ended.future.timeout(const Duration(seconds: 5));
            controller.removeListener(check);
            return controller.walks.single;
          }

          final stopping = finish();
          expect(controller.phase, WalkRecordingPhase.stopping);
          expect(await controller.stopWalk(), isNull);
          repository.releaseWrite.complete();
          final walk = await stopping;
          expect(repository.finishCalls, 1);
          expect(
            walk!.status,
            failWrite || interrupt
                ? WalkStatus.interrupted
                : WalkStatus.completed,
          );
          expect(walk.pointCount, failWrite ? 1 : (interrupt ? 2 : 3));
          expect(walk.duration, const Duration(minutes: 1));
          expect(controller.walks.single.id, id);
          expect(
            controller.phase,
            failWrite || interrupt
                ? WalkRecordingPhase.error
                : WalkRecordingPhase.idle,
          );
          expect(
            controller.problem,
            failWrite
                ? WalkRecordingProblem.storageFailed
                : (interrupt ? WalkRecordingProblem.recordingFailed : isNull),
          );
          final points = await repository.pointsForWalk(id);
          expect(
            points.map((p) => p.sequence),
            failWrite ? [0] : (interrupt ? [0, 1] : [0, 1, 2]),
          );
          expect(
            await (await app.database).query('walk_surface_analyses'),
            isEmpty,
          );
        },
      );
    }
  }

  test('notification denial does not block or discard a local walk', () async {
    final appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final repository = WalkRepository(appDatabase);
    final locationRecorder = TestLocationRecorder();
    var now = DateTime.utc(2026, 8, 16, 10);
    final controller = WalkRecordingController(
      repository: repository,
      locationRecorder: locationRecorder,
      notificationPermissionGateway: const TestNotificationPermissionGateway(
        NotificationPermissionState.denied,
      ),
      now: () => now,
    );
    addTearDown(() async {
      controller.dispose();
      await locationRecorder.close();
      await appDatabase.close();
    });

    await controller.initialize();
    await controller.startWalk(
      notificationTitle: 'Recording',
      notificationText: 'Local only',
      notificationChannelName: 'Walk recording',
    );

    expect(controller.phase, WalkRecordingPhase.recording);
    expect(
      controller.notificationPermissionState,
      NotificationPermissionState.denied,
    );
    expect(locationRecorder.positionStreamCalls, 1);

    final twoPointsPersisted = Completer<void>();
    controller.addListener(() {
      if (controller.activePointCount == 2 && !twoPointsPersisted.isCompleted) {
        twoPointsPersisted.complete();
      }
    });
    locationRecorder.emit(
      LocationSample(
        latitude: 50.4501,
        longitude: 30.5234,
        recordedAt: now.add(const Duration(seconds: 5)),
        accuracyMeters: 5,
      ),
    );
    locationRecorder.emit(
      LocationSample(
        latitude: 50.45015,
        longitude: 30.5234,
        recordedAt: now.add(const Duration(seconds: 10)),
        accuracyMeters: 4,
      ),
    );
    await twoPointsPersisted.future.timeout(const Duration(seconds: 2));

    final walkId = controller.activeWalk!.id;
    expect(await repository.pointsForWalk(walkId), hasLength(2));

    now = now.add(const Duration(minutes: 10));
    final completed = await controller.stopWalk();

    expect(completed, isNotNull);
    expect(completed!.status, WalkStatus.completed);
    expect(completed.pointCount, 2);
    expect(completed.duration, const Duration(minutes: 10));
    expect(completed.distanceMeters, greaterThan(5));
    expect(controller.phase, WalkRecordingPhase.idle);
    expect(controller.walks.single.id, walkId);
    expect(await repository.pointsForWalk(walkId), hasLength(2));
  });
}

class DelayedPointRepository extends WalkRepository {
  DelayedPointRepository(super.appDatabase, {required this.failWrite});

  final bool failWrite;
  final writeEntered = Completer<void>();
  final releaseWrite = Completer<void>();
  int writes = 0;
  int finishCalls = 0;

  @override
  Future<WalkPoint> appendPoint(int walkId, LocationSample sample) async {
    if (++writes == 2) {
      writeEntered.complete();
      await releaseWrite.future;
      if (failWrite) throw StateError('Synthetic point write failure');
    }
    return super.appendPoint(walkId, sample);
  }

  @override
  Future<Walk> finishWalk({
    required int walkId,
    required DateTime endedAt,
    required WalkStatus status,
  }) {
    finishCalls++;
    return super.finishWalk(walkId: walkId, endedAt: endedAt, status: status);
  }
}
