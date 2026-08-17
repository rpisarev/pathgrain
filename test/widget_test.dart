import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/app.dart';
import 'package:pathgrain/platform/notification_permission.dart';
import 'package:pathgrain/walks/app_database.dart';
import 'package:pathgrain/walks/walk_recording_controller.dart';
import 'package:pathgrain/walks/walk_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_doubles.dart';

void main() {
  setUpAll(sqfliteFfiInit);

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
