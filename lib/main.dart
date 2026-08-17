import 'package:flutter/widgets.dart';

import 'app.dart';
import 'platform/notification_permission.dart';
import 'walks/app_database.dart';
import 'walks/location_recorder.dart';
import 'walks/walk_recording_controller.dart';
import 'walks/walk_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = await AppDatabase.openDefault();
  final repository = WalkRepository(database);
  final controller = WalkRecordingController(
    repository: repository,
    locationRecorder: GeolocatorLocationRecorder(),
    notificationPermissionGateway: MethodChannelNotificationPermissionGateway(),
  );
  await controller.initialize();

  runApp(PathgrainApp(controller: controller, repository: repository));
}
