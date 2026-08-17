import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/platform/notification_permission.dart';
import 'package:pathgrain/walks/app_database.dart';
import 'package:pathgrain/walks/walk_models.dart';
import 'package:pathgrain/walks/walk_recording_controller.dart';
import 'package:pathgrain/walks/walk_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_doubles.dart';

void main() {
  setUpAll(sqfliteFfiInit);

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
