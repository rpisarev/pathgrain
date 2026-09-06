import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('uk'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Pathgrain'**
  String get appTitle;

  /// No description provided for @startWalk.
  ///
  /// In en, this message translates to:
  /// **'Start walk'**
  String get startWalk;

  /// No description provided for @stopWalk.
  ///
  /// In en, this message translates to:
  /// **'Stop walk'**
  String get stopWalk;

  /// No description provided for @startingWalk.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get startingWalk;

  /// No description provided for @stoppingWalk.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get stoppingWalk;

  /// No description provided for @activeWalk.
  ///
  /// In en, this message translates to:
  /// **'Walk in progress'**
  String get activeWalk;

  /// No description provided for @savedWalks.
  ///
  /// In en, this message translates to:
  /// **'Saved walks'**
  String get savedWalks;

  /// No description provided for @noSavedWalks.
  ///
  /// In en, this message translates to:
  /// **'Your completed walks will appear here.'**
  String get noSavedWalks;

  /// No description provided for @walkDetails.
  ///
  /// In en, this message translates to:
  /// **'Walk details'**
  String get walkDetails;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationLabel;

  /// No description provided for @distanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distanceLabel;

  /// No description provided for @pointsLabel.
  ///
  /// In en, this message translates to:
  /// **'GPS points'**
  String get pointsLabel;

  /// No description provided for @distanceMeters.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String distanceMeters(num meters);

  /// No description provided for @distanceKilometers.
  ///
  /// In en, this message translates to:
  /// **'{kilometers} km'**
  String distanceKilometers(num kilometers);

  /// No description provided for @pointCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No points} =1{1 point} other{{count} points}}'**
  String pointCount(int count);

  /// No description provided for @startExplanationTitle.
  ///
  /// In en, this message translates to:
  /// **'Record this walk?'**
  String get startExplanationTitle;

  /// No description provided for @startExplanationBody.
  ///
  /// In en, this message translates to:
  /// **'Pathgrain needs precise location while this walk is active. On Android it also starts a foreground service with an ongoing notification so recording can continue after Home or screen lock.'**
  String get startExplanationBody;

  /// No description provided for @startExplanationNotification.
  ///
  /// In en, this message translates to:
  /// **'On Android 13 and newer, notification permission makes the recording notice visible in the notification drawer. If you decline it, Android can still run the foreground service, but the notice may only appear in system task controls.'**
  String get startExplanationNotification;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @recordingNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Pathgrain is recording a walk'**
  String get recordingNotificationTitle;

  /// No description provided for @recordingNotificationText.
  ///
  /// In en, this message translates to:
  /// **'Location points stay on this device. Return to Pathgrain to stop.'**
  String get recordingNotificationText;

  /// No description provided for @recordingNotificationChannel.
  ///
  /// In en, this message translates to:
  /// **'Walk recording'**
  String get recordingNotificationChannel;

  /// No description provided for @notificationDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording notification is limited'**
  String get notificationDeniedTitle;

  /// No description provided for @notificationDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Notification permission is off. Android permits the foreground location service to continue, but its notice might only be visible in system task controls. Do not force-stop the app during the walk.'**
  String get notificationDeniedBody;

  /// No description provided for @notificationUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Pathgrain could not check notification permission. Recording will continue if Android allows the foreground location service.'**
  String get notificationUnavailableBody;

  /// No description provided for @locationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Turn on Location services, then try again.'**
  String get locationServicesDisabled;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to record a walk.'**
  String get locationPermissionDenied;

  /// No description provided for @locationPermissionDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location permission is blocked. Enable it in Android settings and try again.'**
  String get locationPermissionDeniedForever;

  /// No description provided for @recordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording stopped unexpectedly. Points already written to this device were kept.'**
  String get recordingFailed;

  /// No description provided for @storageFailed.
  ///
  /// In en, this message translates to:
  /// **'The walk could not be saved. Recording was stopped.'**
  String get storageFailed;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @waitingForGps.
  ///
  /// In en, this message translates to:
  /// **'Waiting for an accurate GPS point…'**
  String get waitingForGps;

  /// No description provided for @interruptedWalk.
  ///
  /// In en, this message translates to:
  /// **'Interrupted recording'**
  String get interruptedWalk;

  /// No description provided for @completedWalk.
  ///
  /// In en, this message translates to:
  /// **'Completed walk'**
  String get completedWalk;

  /// No description provided for @routeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'There are not enough saved GPS points to draw this route.'**
  String get routeUnavailable;

  /// No description provided for @mapLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading saved route…'**
  String get mapLoading;

  /// No description provided for @developmentMapNotice.
  ///
  /// In en, this message translates to:
  /// **'Development basemap'**
  String get developmentMapNotice;

  /// No description provided for @preciseLocationRecommended.
  ///
  /// In en, this message translates to:
  /// **'Precise location is recommended. Approximate location may not produce a usable route.'**
  String get preciseLocationRecommended;

  /// No description provided for @surfaceEvidence.
  ///
  /// In en, this message translates to:
  /// **'Surface evidence'**
  String get surfaceEvidence;

  /// No description provided for @evidenceOpen.
  ///
  /// In en, this message translates to:
  /// **'Open development view'**
  String get evidenceOpen;

  /// No description provided for @evidencePrivacyNotice.
  ///
  /// In en, this message translates to:
  /// **'This development view requests fixed map cells from Overpass and loads a visual basemap from OpenFreeMap. Providers can learn the approximate areas requested, your IP address, and request time. Your ordered GPS track, timestamps, walk ID, and accuracy values stay on this device. Fixed cells reduce detail; remote map access is not anonymous.'**
  String get evidencePrivacyNotice;

  /// No description provided for @evidenceRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh OSM evidence'**
  String get evidenceRefresh;

  /// No description provided for @evidenceCalculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating fixed geographic cells…'**
  String get evidenceCalculating;

  /// No description provided for @evidenceReadingCache.
  ///
  /// In en, this message translates to:
  /// **'Reading local OSM cache…'**
  String get evidenceReadingCache;

  /// No description provided for @evidenceUsingCache.
  ///
  /// In en, this message translates to:
  /// **'Using available cached evidence…'**
  String get evidenceUsingCache;

  /// No description provided for @evidenceFetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching OSM evidence, one cell at a time…'**
  String get evidenceFetching;

  /// No description provided for @evidenceRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refresh requested; keeping cached evidence until replaced…'**
  String get evidenceRefreshing;

  /// No description provided for @evidenceLoaded.
  ///
  /// In en, this message translates to:
  /// **'OSM evidence loaded. No surface has been assigned to this walk.'**
  String get evidenceLoaded;

  /// No description provided for @evidenceEmpty.
  ///
  /// In en, this message translates to:
  /// **'No relevant OSM evidence returned. No surface has been assigned.'**
  String get evidenceEmpty;

  /// No description provided for @evidencePartialFailure.
  ///
  /// In en, this message translates to:
  /// **'Partial result: {count} cells could not be fetched or refreshed. Available evidence is shown.'**
  String evidencePartialFailure(int count);

  /// No description provided for @evidenceTotalFailure.
  ///
  /// In en, this message translates to:
  /// **'No OSM cells are available. The saved walk is unchanged.'**
  String get evidenceTotalFailure;

  /// No description provided for @evidenceCellCounts.
  ///
  /// In en, this message translates to:
  /// **'Cells: {available}/{total} · cached: {cached} · fetched: {fetched} · OSM objects: {features}'**
  String evidenceCellCounts(
    int available,
    int total,
    int cached,
    int fetched,
    int features,
  );

  /// No description provided for @evidenceOffline.
  ///
  /// In en, this message translates to:
  /// **'Network could not be reached; the device may be offline. Cached cells are kept.'**
  String get evidenceOffline;

  /// No description provided for @evidenceTimeout.
  ///
  /// In en, this message translates to:
  /// **'The OSM request timed out. Wait at least 30 seconds before a manual refresh.'**
  String get evidenceTimeout;

  /// No description provided for @evidenceRateLimited.
  ///
  /// In en, this message translates to:
  /// **'The provider asked us to pause. Wait at least 30 seconds (or longer if requested by the server), then refresh manually.'**
  String get evidenceRateLimited;

  /// No description provided for @evidenceServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The OSM service is unavailable. Wait before refreshing manually.'**
  String get evidenceServiceUnavailable;

  /// No description provided for @evidenceInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The OSM response was invalid or incomplete. Previous cached evidence was kept.'**
  String get evidenceInvalidResponse;

  /// No description provided for @evidenceResponseTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The cell response exceeded the development download limit. Previous cached evidence was kept.'**
  String get evidenceResponseTooLarge;

  /// No description provided for @evidenceCacheFailure.
  ///
  /// In en, this message translates to:
  /// **'Some cache data could not be read or saved. Available evidence is shown, but reuse may be incomplete.'**
  String get evidenceCacheFailure;

  /// No description provided for @evidenceLocalFailure.
  ///
  /// In en, this message translates to:
  /// **'The local inspection data could not be loaded. The saved walk is unchanged.'**
  String get evidenceLocalFailure;

  /// No description provided for @evidenceOldestCache.
  ///
  /// In en, this message translates to:
  /// **'Oldest available cell fetched: {time}. Cached cells are reused until you refresh.'**
  String evidenceOldestCache(String time);

  /// No description provided for @evidenceGeometryWarnings.
  ///
  /// In en, this message translates to:
  /// **'Geometry limitations: {count} objects. Unparsed elements retained in cache: {unparsed}. Inspect the object list for details.'**
  String evidenceGeometryWarnings(int count, int unparsed);

  /// No description provided for @evidenceLegend.
  ///
  /// In en, this message translates to:
  /// **'Blue: saved GPS track · dots: accepted samples · green: OSM paths/pedestrian features · orange: roads · teal: areas · purple: relation outlines. Tap to inspect.'**
  String get evidenceLegend;

  /// No description provided for @evidenceAccuracyToggle.
  ///
  /// In en, this message translates to:
  /// **'GPS accuracy circles'**
  String get evidenceAccuracyToggle;

  /// No description provided for @evidenceBrowse.
  ///
  /// In en, this message translates to:
  /// **'Inspect data'**
  String get evidenceBrowse;

  /// No description provided for @evidenceAbout.
  ///
  /// In en, this message translates to:
  /// **'About this experiment'**
  String get evidenceAbout;

  /// No description provided for @evidenceProviderNotice.
  ///
  /// In en, this message translates to:
  /// **'Visual basemap: OpenFreeMap (existing development style). Raw OSM evidence overlay: overpass-api.de. Both are development choices; neither selects a production provider. Requests stop after a failure; there are no automatic retries.'**
  String get evidenceProviderNotice;

  /// No description provided for @evidenceAccuracyNotice.
  ///
  /// In en, this message translates to:
  /// **'Accuracy circles approximate the saved reported accuracy in meters on a spherical Earth. They are not certainty boundaries or surface classifications. Point markers are only location symbols.'**
  String get evidenceAccuracyNotice;

  /// No description provided for @evidenceAttribution.
  ///
  /// In en, this message translates to:
  /// **'OSM evidence: © OpenStreetMap contributors · ODbL\nhttps://www.openstreetmap.org/copyright\nBasemap: OpenFreeMap · Evidence service: overpass-api.de'**
  String get evidenceAttribution;

  /// No description provided for @evidenceMapUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The debug map could not fully load. Inspect data still shows available raw OSM tags and GPS accuracy.'**
  String get evidenceMapUnavailable;

  /// No description provided for @evidenceUsePlainMap.
  ///
  /// In en, this message translates to:
  /// **'Use plain map (no basemap network access)'**
  String get evidenceUsePlainMap;

  /// No description provided for @evidenceInspectorHint.
  ///
  /// In en, this message translates to:
  /// **'Inspect source evidence only. Nearby objects are not matched to this walk. Expand an OSM object to see its raw tags.'**
  String get evidenceInspectorHint;

  /// No description provided for @evidenceGpsPoint.
  ///
  /// In en, this message translates to:
  /// **'Accepted GPS sample #{sequence}'**
  String evidenceGpsPoint(int sequence);

  /// No description provided for @evidenceAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Reported accuracy: {meters} m'**
  String evidenceAccuracy(num meters);

  /// No description provided for @evidenceFeatureTitle.
  ///
  /// In en, this message translates to:
  /// **'OSM {type} {id}'**
  String evidenceFeatureTitle(String type, int id);

  /// No description provided for @evidenceTagMissing.
  ///
  /// In en, this message translates to:
  /// **'not tagged'**
  String get evidenceTagMissing;

  /// No description provided for @evidenceGeometryPoint.
  ///
  /// In en, this message translates to:
  /// **'Geometry: point'**
  String get evidenceGeometryPoint;

  /// No description provided for @evidenceGeometryLine.
  ///
  /// In en, this message translates to:
  /// **'Geometry: line / way pieces'**
  String get evidenceGeometryLine;

  /// No description provided for @evidenceGeometryArea.
  ///
  /// In en, this message translates to:
  /// **'Geometry: closed area'**
  String get evidenceGeometryArea;

  /// No description provided for @evidenceGeometryRelation.
  ///
  /// In en, this message translates to:
  /// **'Geometry: relation member outlines / points'**
  String get evidenceGeometryRelation;

  /// No description provided for @evidenceGeometryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Geometry: unavailable for rendering'**
  String get evidenceGeometryUnavailable;

  /// No description provided for @evidenceAreaTagged.
  ///
  /// In en, this message translates to:
  /// **'Area semantics are present in the raw tags.'**
  String get evidenceAreaTagged;

  /// No description provided for @evidenceAreaNotTagged.
  ///
  /// In en, this message translates to:
  /// **'No area semantics are declared in the raw tags.'**
  String get evidenceAreaNotTagged;

  /// No description provided for @evidenceRelationLimitation.
  ///
  /// In en, this message translates to:
  /// **'Relation members are shown separately. Rings and holes are not assembled or filled; nested relations are not resolved.'**
  String get evidenceRelationLimitation;

  /// No description provided for @evidenceIncompleteGeometry.
  ///
  /// In en, this message translates to:
  /// **'Some geometry is missing or unsupported. Available pieces are shown without joining gaps.'**
  String get evidenceIncompleteGeometry;

  /// No description provided for @evidenceRelationMembers.
  ///
  /// In en, this message translates to:
  /// **'Raw relation members: {count} (type, ID, role)'**
  String evidenceRelationMembers(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
