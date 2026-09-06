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

  @override
  String get surfaceEvidence => 'Surface evidence';

  @override
  String get evidenceOpen => 'Open development view';

  @override
  String get evidencePrivacyNotice =>
      'This development view requests fixed map cells from Overpass and loads a visual basemap from OpenFreeMap. Providers can learn the approximate areas requested, your IP address, and request time. Your ordered GPS track, timestamps, walk ID, and accuracy values stay on this device. Fixed cells reduce detail; remote map access is not anonymous.';

  @override
  String get evidenceRefresh => 'Refresh OSM evidence';

  @override
  String get evidenceCalculating => 'Calculating fixed geographic cells…';

  @override
  String get evidenceReadingCache => 'Reading local OSM cache…';

  @override
  String get evidenceUsingCache => 'Using available cached evidence…';

  @override
  String get evidenceFetching => 'Fetching OSM evidence, one cell at a time…';

  @override
  String get evidenceRefreshing =>
      'Refresh requested; keeping cached evidence until replaced…';

  @override
  String get evidenceLoaded =>
      'OSM evidence loaded. No surface has been assigned to this walk.';

  @override
  String get evidenceEmpty =>
      'No relevant OSM evidence returned. No surface has been assigned.';

  @override
  String evidencePartialFailure(int count) {
    return 'Partial result: $count cells could not be fetched or refreshed. Available evidence is shown.';
  }

  @override
  String get evidenceTotalFailure =>
      'No OSM cells are available. The saved walk is unchanged.';

  @override
  String evidenceCellCounts(
    int available,
    int total,
    int cached,
    int fetched,
    int features,
  ) {
    return 'Cells: $available/$total · cached: $cached · fetched: $fetched · OSM objects: $features';
  }

  @override
  String get evidenceOffline =>
      'Network could not be reached; the device may be offline. Cached cells are kept.';

  @override
  String get evidenceTimeout =>
      'The OSM request timed out. Wait at least 30 seconds before a manual refresh.';

  @override
  String get evidenceRateLimited =>
      'The provider asked us to pause. Wait at least 30 seconds (or longer if requested by the server), then refresh manually.';

  @override
  String get evidenceServiceUnavailable =>
      'The OSM service is unavailable. Wait before refreshing manually.';

  @override
  String get evidenceInvalidResponse =>
      'The OSM response was invalid or incomplete. Previous cached evidence was kept.';

  @override
  String get evidenceResponseTooLarge =>
      'The cell response exceeded the development download limit. Previous cached evidence was kept.';

  @override
  String get evidenceCacheFailure =>
      'Some cache data could not be read or saved. Available evidence is shown, but reuse may be incomplete.';

  @override
  String get evidenceLocalFailure =>
      'The local inspection data could not be loaded. The saved walk is unchanged.';

  @override
  String evidenceOldestCache(String time) {
    return 'Oldest available cell fetched: $time. Cached cells are reused until you refresh.';
  }

  @override
  String evidenceGeometryWarnings(int count, int unparsed) {
    return 'Geometry limitations: $count objects. Unparsed elements retained in cache: $unparsed. Inspect the object list for details.';
  }

  @override
  String get evidenceLegend =>
      'Blue: saved GPS track · dots: accepted samples · green: OSM paths/pedestrian features · orange: roads · teal: areas · purple: relation outlines. Tap to inspect.';

  @override
  String get evidenceAccuracyToggle => 'GPS accuracy circles';

  @override
  String get evidenceBrowse => 'Inspect data';

  @override
  String get evidenceAbout => 'About this experiment';

  @override
  String get evidenceProviderNotice =>
      'Visual basemap: OpenFreeMap (existing development style). Raw OSM evidence overlay: overpass-api.de. Both are development choices; neither selects a production provider. Requests stop after a failure; there are no automatic retries.';

  @override
  String get evidenceAccuracyNotice =>
      'Accuracy circles approximate the saved reported accuracy in meters on a spherical Earth. They are not certainty boundaries or surface classifications. Point markers are only location symbols.';

  @override
  String get evidenceAttribution =>
      'OSM evidence: © OpenStreetMap contributors · ODbL\nhttps://www.openstreetmap.org/copyright\nBasemap: OpenFreeMap · Evidence service: overpass-api.de';

  @override
  String get evidenceMapUnavailable =>
      'The debug map could not fully load. Inspect data still shows available raw OSM tags and GPS accuracy.';

  @override
  String get evidenceUsePlainMap => 'Use plain map (no basemap network access)';

  @override
  String get evidenceInspectorHint =>
      'Inspect source evidence only. Nearby objects are not matched to this walk. Expand an OSM object to see its raw tags.';

  @override
  String evidenceGpsPoint(int sequence) {
    return 'Accepted GPS sample #$sequence';
  }

  @override
  String evidenceAccuracy(num meters) {
    final intl.NumberFormat metersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String metersString = metersNumberFormat.format(meters);

    return 'Reported accuracy: $metersString m';
  }

  @override
  String evidenceFeatureTitle(String type, int id) {
    return 'OSM $type $id';
  }

  @override
  String get evidenceTagMissing => 'not tagged';

  @override
  String get evidenceGeometryPoint => 'Geometry: point';

  @override
  String get evidenceGeometryLine => 'Geometry: line / way pieces';

  @override
  String get evidenceGeometryArea => 'Geometry: closed area';

  @override
  String get evidenceGeometryRelation =>
      'Geometry: relation member outlines / points';

  @override
  String get evidenceGeometryUnavailable =>
      'Geometry: unavailable for rendering';

  @override
  String get evidenceAreaTagged =>
      'Area semantics are present in the raw tags.';

  @override
  String get evidenceAreaNotTagged =>
      'No area semantics are declared in the raw tags.';

  @override
  String get evidenceRelationLimitation =>
      'Relation members are shown separately. Rings and holes are not assembled or filled; nested relations are not resolved.';

  @override
  String get evidenceIncompleteGeometry =>
      'Some geometry is missing or unsupported. Available pieces are shown without joining gaps.';

  @override
  String evidenceRelationMembers(int count) {
    return 'Raw relation members: $count (type, ID, role)';
  }
}
