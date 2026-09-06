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

  @override
  String get surfaceEvidence => 'Дані OSM про покриття';

  @override
  String get evidenceOpen => 'Відкрити тестовий перегляд';

  @override
  String get evidencePrivacyNotice =>
      'Цей тестовий перегляд запитує фіксовані комірки карти в Overpass і завантажує базову карту з OpenFreeMap. Постачальники можуть дізнатися приблизні запитані райони, вашу IP-адресу та час запиту. Впорядкований GPS-трек, часові мітки, ідентифікатор прогулянки й точність залишаються на пристрої. Фіксовані комірки зменшують деталізацію, але не роблять доступ до карти анонімним.';

  @override
  String get evidenceRefresh => 'Оновити дані OSM';

  @override
  String get evidenceCalculating =>
      'Обчислення фіксованих географічних комірок…';

  @override
  String get evidenceReadingCache => 'Читання локального кешу OSM…';

  @override
  String get evidenceUsingCache => 'Використання наявних даних із кешу…';

  @override
  String get evidenceFetching => 'Завантаження даних OSM по одній комірці…';

  @override
  String get evidenceRefreshing =>
      'Запитано оновлення; дані кешу зберігаються до заміни…';

  @override
  String get evidenceLoaded =>
      'Дані OSM завантажено. Покриття цієї прогулянки ще не визначено.';

  @override
  String get evidenceEmpty =>
      'Відповідних даних OSM не знайдено. Покриття не визначено.';

  @override
  String evidencePartialFailure(int count) {
    return 'Частковий результат: не вдалося завантажити або оновити $count комірок. Показано наявні дані.';
  }

  @override
  String get evidenceTotalFailure =>
      'Немає доступних комірок OSM. Збережену прогулянку не змінено.';

  @override
  String evidenceCellCounts(
    int available,
    int total,
    int cached,
    int fetched,
    int features,
  ) {
    return 'Комірки: $available/$total · з кешу: $cached · завантажено: $fetched · об’єкти OSM: $features';
  }

  @override
  String get evidenceOffline =>
      'Мережа недоступна; можливо, немає інтернету. Комірки кешу збережено.';

  @override
  String get evidenceTimeout =>
      'Час очікування OSM вичерпано. Зачекайте щонайменше 30 секунд перед ручним оновленням.';

  @override
  String get evidenceRateLimited =>
      'Постачальник просить зачекати. Зачекайте щонайменше 30 секунд (або довше, якщо вимагає сервер), потім оновіть вручну.';

  @override
  String get evidenceServiceUnavailable =>
      'Сервіс OSM недоступний. Зачекайте перед ручним оновленням.';

  @override
  String get evidenceInvalidResponse =>
      'Відповідь OSM некоректна або неповна. Попередні дані кешу збережено.';

  @override
  String get evidenceResponseTooLarge =>
      'Відповідь для комірки перевищила тестовий ліміт завантаження. Попередні дані кешу збережено.';

  @override
  String get evidenceCacheFailure =>
      'Частину кешу не вдалося прочитати або зберегти. Наявні дані показано, але повторне використання може бути неповним.';

  @override
  String get evidenceLocalFailure =>
      'Не вдалося завантажити локальні дані для перегляду. Збережену прогулянку не змінено.';

  @override
  String evidenceOldestCache(String time) {
    return 'Найстарішу доступну комірку завантажено: $time. Кеш використовується до ручного оновлення.';
  }

  @override
  String evidenceGeometryWarnings(int count, int unparsed) {
    return 'Обмеження геометрії: $count об’єктів. Нерозібраних елементів збережено в кеші: $unparsed. Подробиці — у списку об’єктів.';
  }

  @override
  String get evidenceLegend =>
      'Синій: збережений GPS-трек · точки: прийняті відліки · зелений: шляхи й пішохідні об’єкти OSM · помаранчевий: дороги · бірюзовий: площі · фіолетовий: контури відношень. Торкніться для перегляду.';

  @override
  String get evidenceAccuracyToggle => 'Кола точності GPS';

  @override
  String get evidenceBrowse => 'Переглянути дані';

  @override
  String get evidenceAbout => 'Про цей експеримент';

  @override
  String get evidenceProviderNotice =>
      'Базова карта: OpenFreeMap (наявний тестовий стиль). Сирі дані OSM: overpass-api.de. Обидва сервіси обрано для розробки, а не для промислового використання. Після помилки запити припиняються; автоматичних повторів немає.';

  @override
  String get evidenceAccuracyNotice =>
      'Кола приблизно відображають збережену точність у метрах на сферичній Землі. Це не межі достовірності й не класифікація покриття. Позначки точок лише вказують розташування.';

  @override
  String get evidenceAttribution =>
      'Дані OSM: © учасники OpenStreetMap · ODbL\nhttps://www.openstreetmap.org/copyright\nБазова карта: OpenFreeMap · Сервіс даних: overpass-api.de';

  @override
  String get evidenceMapUnavailable =>
      'Тестову карту не вдалося повністю завантажити. «Переглянути дані» показує наявні сирі теги OSM і точність GPS.';

  @override
  String get evidenceUsePlainMap =>
      'Карта без підкладки (без мережевих запитів базової карти)';

  @override
  String get evidenceInspectorHint =>
      'Це лише перегляд вихідних даних. Об’єкти поблизу не зіставлено з прогулянкою. Розгорніть об’єкт OSM, щоб побачити сирі теги.';

  @override
  String evidenceGpsPoint(int sequence) {
    return 'Прийнята GPS-точка №$sequence';
  }

  @override
  String evidenceAccuracy(num meters) {
    final intl.NumberFormat metersNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String metersString = metersNumberFormat.format(meters);

    return 'Заявлена точність: $metersString м';
  }

  @override
  String evidenceFeatureTitle(String type, int id) {
    return 'OSM $type $id';
  }

  @override
  String get evidenceTagMissing => 'тег відсутній';

  @override
  String get evidenceGeometryPoint => 'Геометрія: точка';

  @override
  String get evidenceGeometryLine => 'Геометрія: лінія / частини шляху';

  @override
  String get evidenceGeometryArea => 'Геометрія: замкнена площа';

  @override
  String get evidenceGeometryRelation =>
      'Геометрія: контури / точки учасників відношення';

  @override
  String get evidenceGeometryUnavailable =>
      'Геометрія: недоступна для відображення';

  @override
  String get evidenceAreaTagged => 'Сирі теги позначають площу.';

  @override
  String get evidenceAreaNotTagged => 'Сирі теги не позначають площу.';

  @override
  String get evidenceRelationLimitation =>
      'Учасників відношення показано окремо. Кільця й отвори не з’єднано та не залито; вкладені відношення не розібрано.';

  @override
  String get evidenceIncompleteGeometry =>
      'Частина геометрії відсутня або не підтримується. Наявні частини показано без з’єднання розривів.';

  @override
  String evidenceRelationMembers(int count) {
    return 'Сирі учасники відношення: $count (тип, ID, роль)';
  }
}
