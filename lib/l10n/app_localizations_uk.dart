// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Pathgrain';

  @override
  String get startWalk => 'Почати прогулянку';

  @override
  String get stopWalk => 'Зупинити прогулянку';

  @override
  String get startingWalk => 'Запуск…';

  @override
  String get stoppingWalk => 'Збереження…';

  @override
  String get activeWalk => 'Прогулянка записується';

  @override
  String get savedWalks => 'Збережені прогулянки';

  @override
  String get noSavedWalks => 'Завершені прогулянки з’являться тут.';

  @override
  String get walkDetails => 'Деталі прогулянки';

  @override
  String get durationLabel => 'Тривалість';

  @override
  String get distanceLabel => 'Дистанція';

  @override
  String get pointsLabel => 'GPS-точки';

  @override
  String distanceMeters(num meters) {
    final intl.NumberFormat metersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String metersString = metersNumberFormat.format(meters);

    return '$metersString м';
  }

  @override
  String distanceKilometers(num kilometers) {
    final intl.NumberFormat kilometersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String kilometersString = kilometersNumberFormat.format(kilometers);

    return '$kilometersString км';
  }

  @override
  String pointCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count точки',
      many: '$count точок',
      few: '$count точки',
      one: '1 точка',
      zero: 'Немає точок',
    );
    return '$_temp0';
  }

  @override
  String get startExplanationTitle => 'Записати цю прогулянку?';

  @override
  String get startExplanationBody =>
      'Pathgrain потрібна точна геолокація, поки прогулянка активна. На Android застосунок також запускає foreground service з постійним сповіщенням, щоб запис міг тривати після Home або блокування екрана.';

  @override
  String get startExplanationNotification =>
      'На Android 13 і новіших дозвіл на сповіщення робить індикатор запису видимим у шторці. Якщо відмовити, Android усе одно може виконувати foreground service, але індикатор може бути видимий лише в системному керуванні активними застосунками.';

  @override
  String get cancel => 'Скасувати';

  @override
  String get continueAction => 'Продовжити';

  @override
  String get recordingNotificationTitle => 'Pathgrain записує прогулянку';

  @override
  String get recordingNotificationText =>
      'GPS-точки залишаються на цьому пристрої. Поверніться в Pathgrain, щоб зупинити запис.';

  @override
  String get recordingNotificationChannel => 'Запис прогулянки';

  @override
  String get notificationDeniedTitle => 'Сповіщення про запис обмежене';

  @override
  String get notificationDeniedBody =>
      'Дозвіл на сповіщення вимкнений. Android дозволяє foreground location service продовжувати роботу, але його індикатор може бути видимий лише в системному керуванні активними застосунками. Не робіть force-stop під час прогулянки.';

  @override
  String get notificationUnavailableBody =>
      'Pathgrain не зміг перевірити дозвіл на сповіщення. Запис триватиме, якщо Android дозволить foreground location service.';

  @override
  String get locationServicesDisabled =>
      'Увімкніть геолокацію та спробуйте ще раз.';

  @override
  String get locationPermissionDenied =>
      'Для запису прогулянки потрібен дозвіл на геолокацію.';

  @override
  String get locationPermissionDeniedForever =>
      'Дозвіл на геолокацію заблоковано. Увімкніть його в налаштуваннях Android і спробуйте ще раз.';

  @override
  String get recordingFailed =>
      'Запис несподівано зупинився. Уже записані на пристрій точки збережено.';

  @override
  String get storageFailed => 'Не вдалося зберегти прогулянку. Запис зупинено.';

  @override
  String get openSettings => 'Відкрити налаштування';

  @override
  String get dismiss => 'Закрити';

  @override
  String get waitingForGps => 'Очікування достатньо точної GPS-точки…';

  @override
  String get interruptedWalk => 'Перерваний запис';

  @override
  String get completedWalk => 'Завершена прогулянка';

  @override
  String get routeUnavailable =>
      'Збережених GPS-точок недостатньо, щоб показати маршрут.';

  @override
  String get mapLoading => 'Завантаження збереженого маршруту…';

  @override
  String get developmentMapNotice => 'Тестова базова карта';

  @override
  String get preciseLocationRecommended =>
      'Рекомендовано точну геолокацію. Приблизна геолокація може не дати придатного маршруту.';
}
