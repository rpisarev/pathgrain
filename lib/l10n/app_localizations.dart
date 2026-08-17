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
