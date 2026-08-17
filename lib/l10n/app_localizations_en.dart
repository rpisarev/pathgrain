// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pathgrain';

  @override
  String get startWalk => 'Start walk';

  @override
  String get stopWalk => 'Stop walk';

  @override
  String get startingWalk => 'Starting…';

  @override
  String get stoppingWalk => 'Saving…';

  @override
  String get activeWalk => 'Walk in progress';

  @override
  String get savedWalks => 'Saved walks';

  @override
  String get noSavedWalks => 'Your completed walks will appear here.';

  @override
  String get walkDetails => 'Walk details';

  @override
  String get durationLabel => 'Duration';

  @override
  String get distanceLabel => 'Distance';

  @override
  String get pointsLabel => 'GPS points';

  @override
  String distanceMeters(num meters) {
    final intl.NumberFormat metersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String metersString = metersNumberFormat.format(meters);

    return '$metersString m';
  }

  @override
  String distanceKilometers(num kilometers) {
    final intl.NumberFormat kilometersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String kilometersString = kilometersNumberFormat.format(kilometers);

    return '$kilometersString km';
  }

  @override
  String pointCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
      zero: 'No points',
    );
    return '$_temp0';
  }

  @override
  String get startExplanationTitle => 'Record this walk?';

  @override
  String get startExplanationBody =>
      'Pathgrain needs precise location while this walk is active. On Android it also starts a foreground service with an ongoing notification so recording can continue after Home or screen lock.';

  @override
  String get startExplanationNotification =>
      'On Android 13 and newer, notification permission makes the recording notice visible in the notification drawer. If you decline it, Android can still run the foreground service, but the notice may only appear in system task controls.';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueAction => 'Continue';

  @override
  String get recordingNotificationTitle => 'Pathgrain is recording a walk';

  @override
  String get recordingNotificationText =>
      'Location points stay on this device. Return to Pathgrain to stop.';

  @override
  String get recordingNotificationChannel => 'Walk recording';

  @override
  String get notificationDeniedTitle => 'Recording notification is limited';

  @override
  String get notificationDeniedBody =>
      'Notification permission is off. Android permits the foreground location service to continue, but its notice might only be visible in system task controls. Do not force-stop the app during the walk.';

  @override
  String get notificationUnavailableBody =>
      'Pathgrain could not check notification permission. Recording will continue if Android allows the foreground location service.';

  @override
  String get locationServicesDisabled =>
      'Turn on Location services, then try again.';

  @override
  String get locationPermissionDenied =>
      'Location permission is required to record a walk.';

  @override
  String get locationPermissionDeniedForever =>
      'Location permission is blocked. Enable it in Android settings and try again.';

  @override
  String get recordingFailed =>
      'Recording stopped unexpectedly. Points already written to this device were kept.';

  @override
  String get storageFailed =>
      'The walk could not be saved. Recording was stopped.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get waitingForGps => 'Waiting for an accurate GPS point…';

  @override
  String get interruptedWalk => 'Interrupted recording';

  @override
  String get completedWalk => 'Completed walk';

  @override
  String get routeUnavailable =>
      'There are not enough saved GPS points to draw this route.';

  @override
  String get mapLoading => 'Loading saved route…';

  @override
  String get developmentMapNotice => 'Development basemap';

  @override
  String get preciseLocationRecommended =>
      'Precise location is recommended. Approximate location may not produce a usable route.';
}
