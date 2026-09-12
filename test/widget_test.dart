import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/app.dart';
import 'package:pathgrain/platform/notification_permission.dart';
import 'package:pathgrain/walks/app_database.dart';
import 'package:pathgrain/walks/walk_detail_screen.dart';
import 'package:pathgrain/walks/walk_map.dart';
import 'package:pathgrain/walks/walk_models.dart';
import 'package:pathgrain/walks/walk_recording_controller.dart';
import 'package:pathgrain/walks/walk_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_doubles.dart';
import 'support/analysis_fixtures.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets(
    'new walk stays active across Flutter lifecycle events and reaches history/detail',
    (tester) async {
      // Stub only the native map boundary; route data still comes from SQLite.
      // No style-loaded callback is sent, so this is not a native drawing test.
      final messenger = tester.binding.defaultBinaryMessenger;
      final mapChannels = <MethodChannel>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final channel = MethodChannel(
            'plugins.flutter.io/maplibre_gl_${call.arguments['id']}',
          );
          mapChannels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
          return 0;
        }
        if (call.method == 'resize') {
          return {
            'width': call.arguments['width'],
            'height': call.arguments['height'],
          };
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in mapChannels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      tester.platformDispatcher.localeTestValue = const Locale('en');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      final app = AppDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final repository = WalkRepository(app);
      final location = TestLocationRecorder();
      final originals = straight(count: 3);
      var now = originals.first.recordedAt;
      final controller = WalkRecordingController(
        repository: repository,
        locationRecorder: location,
        notificationPermissionGateway: const TestNotificationPermissionGateway(
          NotificationPermissionState.notRequired,
        ),
        now: () => now,
      );
      addTearDown(() async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        controller.dispose();
        await location.close();
        await app.close();
      });
      Future<void> until(bool Function() ready) async {
        // Drain both widget microtasks and real FFI work without a fixed sleep.
        for (var turn = 0; turn < 100 && !ready(); turn++) {
          await tester.pump();
          await tester.runAsync(repository.listWalks);
        }
        expect(ready(), isTrue);
      }

      await tester.runAsync(controller.initialize);
      await tester.pumpWidget(
        PathgrainApp(controller: controller, repository: repository),
      );
      await tester.tap(find.text('Start walk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await until(() => controller.phase == WalkRecordingPhase.recording);
      await tester.pumpAndSettle();
      expect(find.text('Stop walk'), findsOneWidget);
      final id = controller.activeWalk!.id;
      // Synthetic events only test Flutter/controller ownership. They do not
      // establish Android foreground-service delivery during Home or screen lock.
      for (var i = 0; i < originals.length; i++) {
        if (i == 1) {
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
        }
        if (i == 2) {
          for (final state in [
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
        }
        final p = originals[i];
        location.emit(
          LocationSample(
            latitude: p.latitude,
            longitude: p.longitude,
            recordedAt: p.recordedAt,
            accuracyMeters: p.accuracyMeters,
          ),
        );
        await until(() => controller.activePointCount == i + 1);
        expect(controller.phase, WalkRecordingPhase.recording);
        expect(controller.activeWalk!.id, id);
      }
      await tester.pump();
      expect(location.positionStreamCalls, 1);
      now = now.add(const Duration(minutes: 1));
      await tester.tap(find.text('Stop walk'));
      await until(() => controller.phase == WalkRecordingPhase.idle);
      await until(() => find.byType(WalkRouteMap).evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      expect(find.byType(WalkDetailScreen), findsOneWidget);
      expect(find.text('Surface review'), findsOneWidget);
      expect(
        tester.widget<WalkRouteMap>(find.byType(WalkRouteMap)).points,
        hasLength(3),
      );
      expect(controller.walks.single.pointCount, 3);
      await tester.runAsync(() async {
        expect(
          await (await app.database).query('walk_surface_analyses'),
          isEmpty,
        );
      });
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Start walk'), findsOneWidget);
      expect(find.textContaining('Completed walk'), findsOneWidget);
      expect(find.textContaining('3 points'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('shows the walk start action and local history', (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    final appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final repository = WalkRepository(appDatabase);
    final locationRecorder = TestLocationRecorder();
    final controller = WalkRecordingController(
      repository: repository,
      locationRecorder: locationRecorder,
      notificationPermissionGateway: const TestNotificationPermissionGateway(
        NotificationPermissionState.notRequired,
      ),
    );
    await tester.runAsync(controller.initialize);
    addTearDown(() async {
      controller.dispose();
      await locationRecorder.close();
      await appDatabase.close();
    });

    await tester.pumpWidget(
      PathgrainApp(controller: controller, repository: repository),
    );
    await tester.pump();

    expect(find.text('Start walk'), findsOneWidget);
    expect(find.text('Saved walks'), findsOneWidget);
    expect(find.text('Your completed walks will appear here.'), findsOneWidget);
  });
}
