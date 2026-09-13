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
  String get walkRouteLoadFailed =>
      'Не вдалося завантажити збережений маршрут. Прогулянка не змінилася. Спробуйте ще раз.';

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
      'Дані OSM завантажено. Локальний аналіз доступний для перегляду.';

  @override
  String get evidenceEmpty =>
      'Відповідних даних OSM немає. Аналіз покриття залишається UNKNOWN.';

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
      'Розгорніть зразок GPS для перегляду локального аналізу та виділення на карті. Розгорніть об’єкти OSM для перегляду сирих тегів.';

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

  @override
  String get analysisToggle => 'Зіставлення / UNKNOWN';

  @override
  String get analysisNotice =>
      'Локальний експеримент 0.1-B. Розгорніть зразки GPS для перегляду попередніх зіставлень; результати не зберігаються.';

  @override
  String get analysisLegend =>
      'Блакитний: зіставлена геометрія OSM · малиновий: вибраний зразок/об’єкт · червоні кільця та зміщені штрихи: UNKNOWN зразки/відрізки. Синій — збережений маршрут GPS.';

  @override
  String get analysisNoObject => 'немає';

  @override
  String analysisSelected(String key) {
    return 'Вибраний об’єкт OSM: $key';
  }

  @override
  String analysisResult(String assignment, String surface) {
    return 'Pathgrain: $assignment · $surface';
  }

  @override
  String analysisCandidates(int count) {
    return 'Кандидати поблизу: $count. Бали — експериментальна підтримка, не ймовірність.';
  }

  @override
  String analysisCandidateSummary(String score, String distance) {
    return 'Бал $score · відстань $distance м';
  }

  @override
  String analysisScoreComponents(
    String proximity,
    String pedestrian,
    String direction,
    String gps,
    String continuity,
  ) {
    return 'Близькість $proximity · придатність для ходьби $pedestrian · напрямок $direction · GPS $gps · безперервність $continuity';
  }

  @override
  String analysisDirection(String angle) {
    return 'Відмінність напрямку: $angle° (в обох напрямках руху)';
  }

  @override
  String get analysisDirectionUnavailable =>
      'Напрямок недоступний або не має значення для ділянки';

  @override
  String analysisEdge(int from, int to, String speed) {
    return 'Збережений відрізок №$from → №$to · $speed м/с';
  }

  @override
  String analysisEdgeGps(String reason) {
    return 'GPS відрізка: $reason';
  }

  @override
  String analysisReason(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'stable': 'Стабільна послідовність',
      'warmingUp': 'Очікування послідовності якісних зразків',
      'recovering': 'Відновлення стабільної послідовності після невизначеності',
      'invalidSample':
          'Некоректна точність, координати або непідтримувана широта',
      'reducedAccuracy': 'Заявлена похибка виходить за стабільний діапазон',
      'poorAccuracy': 'Низька заявлена точність',
      'fastMotion': 'Видимий рух перевищує попередню межу швидкості; обидві кінцеві точки непевні',
      'isolatedSpike': 'Ізольоване відхилення від сусідніх зразків',
      'sequenceGap': 'Некоректний час/порядок або тривалий проміжок',
      'uncertainEndpoint':
          'Принаймні одна кінцева точка не має стабільної довіри до GPS',
      'eligible': 'Придатний кандидат для ходьби',
      'unsupportedGeometry':
          'Геометрія виходить за підтримувані межі експерименту',
      'notPedestrian': 'Придатність для ходьби не встановлена',
      'accessRestricted': 'Теги доступу не підтверджують можливість ходьби тут',
      'conditionalAccess': 'Умовний доступ не інтерпретується',
      'separateSidewalk':
          'Ось дороги не визначає розташування позначеного тротуару',
      'tooFar': 'Поза обмеженим радіусом зіставлення',
      'directionConflict': 'Напрямок кандидата несумісний',
      'areaBoundary': 'Невизначеність GPS сягає межі ділянки',
      'gpsUncertain': 'UNKNOWN: послідовність GPS нестабільна',
      'evidenceIncomplete':
          'UNKNOWN: частина комірок або елементів даних недоступна',
      'noCandidate': 'UNKNOWN: немає придатного кандидата поблизу',
      'weakScore': 'UNKNOWN: підтримка кандидата надто слабка',
      'ambiguousCandidates':
          'UNKNOWN: неможливо розрізнити конкуруючі геометрії',
      'conflictingNeighbors': 'UNKNOWN: незалежні призначення сусідніх зразків суперечать одне одному',
      'matched': 'Обґрунтований вибір серед завантажених даних',
      'continuitySupported': 'Підтримано незалежними збігами сусідніх зразків',
      'differentObjects': 'UNKNOWN для відрізка: різні об’єкти OSM на кінцях',
      'edgeOffGeometry': 'UNKNOWN для відрізка: проміжні перевірки виходять за геометрію кандидата',
      'explicitSurface':
          'Явний підтримуваний тег surface на зіставленому об’єкті',
      'grassLandcover':
          'Виведено з трав’яного покриву на цій самій пішохідній ділянці',
      'missingSurface': 'UNKNOWN: тег surface відсутній і правило виведення не застосовується',
      'unsupportedSurface':
          'UNKNOWN: загальне, змішане або непідтримуване значення surface',
      'conflictingSurface':
          'UNKNOWN: суперечливі або обмежені умовами дані про покриття',
      'legacySurfaceAmbiguous': 'UNKNOWN: збережена стара категорія не дає змоги розрізнити матеріали для ходьби босоніж',
      'other': 'Невідома причина',
    });
    return '$_temp0';
  }

  @override
  String analysisGpsState(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'stable': 'GPS: стабільний',
      'warmingUp': 'GPS: початкова стабілізація',
      'recovering': 'GPS: відновлення',
      'unreliable': 'GPS: ненадійний',
      'other': 'GPS: невідомо',
    });
    return '$_temp0';
  }

  @override
  String analysisSurface(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'asphalt': 'Асфальт',
      'tile': 'Плитка',
      'cobblestone': 'Бруківка',
      'concrete': 'Бетон',
      'ground': 'Ґрунт',
      'sand': 'Пісок',
      'stone': 'Камінь',
      'fineGravel': 'Галька / дрібний гравій',
      'crushedStone': 'Щебінь',
      'grass': 'Трава',
      'artificialTurf': 'Штучна трава',
      'rubber': 'Гума',
      'wood': 'Дерево',
      'metal': 'Метал',
      'unknown': 'Невідомо',
      'other': 'Невідомо',
    });
    return '$_temp0';
  }

  @override
  String analysisAssignment(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'direct': 'DIRECT (явні дані)',
      'inferred': 'INFERRED (виведено)',
      'other': 'UNKNOWN',
    });
    return '$_temp0';
  }

  @override
  String analysisConfidence(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'strong': 'Довіра до зіставлення: сильна підтримка даними (експеримент)',
      'supported': 'Довіра до зіставлення: підтримано даними (експеримент)',
      'other': 'Довіра до зіставлення: немає',
    });
    return '$_temp0';
  }

  @override
  String analysisOsmSurface(String value) {
    return 'Покриття OSM: $value';
  }

  @override
  String get surfaceReview => 'Перегляд покриття';

  @override
  String get surfaceAnalyze => 'Аналізувати покриття';

  @override
  String get surfaceAnalyzing => 'Завантаження даних карти й аналіз покриття…';

  @override
  String get surfaceRetry => 'Спробувати ще раз';

  @override
  String get surfaceAccessNotice =>
      'Pathgrain використовує кешовані дані OpenStreetMap і завантажує відсутні ділянки карти з Overpass. Мапа використовує OpenFreeMap. Постачальники можуть бачити приблизні запитані ділянки, вашу IP-адресу й час запиту. Ваш GPS-маршрут і часові позначки залишаються на цьому пристрої.';

  @override
  String get surfaceReviewNotice =>
      'Оцінки покриття можна виправити нижче. Збережений аналіз і ваші виправлення залишаються на цьому пристрої. Невідоме покриття — допустимий варіант.';

  @override
  String get surfaceReviewFailed =>
      'Не вдалося завантажити аналіз покриття. Збережена прогулянка не змінилася.';

  @override
  String get surfaceEvidenceIncomplete =>
      'Частина даних карти недоступна. Покриття залишається невідомим, доки не буде достатньо даних. Зачекайте перед повторною спробою.';

  @override
  String get surfaceCacheUnavailable =>
      'Частину даних карти не вдалося зберегти в кеші для подальшого використання.';

  @override
  String get surfaceBreakdown => 'Відстань за покриттям';

  @override
  String surfaceTotal(String distance) {
    return 'Загальна відстань за покриттям: $distance';
  }

  @override
  String get surfaceRoundingNotice =>
      'Відстані округлено окремо, тому сума показаних рядків може трохи відрізнятися від загальної.';

  @override
  String get surfaceDistanceMismatch =>
      'Відстань проаналізованого маршруту відрізняється від збереженої. Обидві показано без підгонки відстаней за покриттям.';

  @override
  String get surfaceRouteLegend =>
      'Кольори позначають ваш записаний GPS-маршрут і відповідають списку покриттів вище. Червоний позначає невідоме покриття, зокрема короткі проміжки.';

  @override
  String get surfaceMapUnavailable =>
      'Мапа маршруту завантажилася не повністю. Відстані за покриттям залишаються доступними.';

  @override
  String get surfacePlainMap => 'Використати порожню мапу';

  @override
  String get analysisUnknownDistances => 'Відстань UNKNOWN за причинами';

  @override
  String analysisUnknownTotal(String distance) {
    return 'UNKNOWN за всю прогулянку: $distance';
  }

  @override
  String analysisSegmentCount(int count) {
    return 'Сегменти покриття записаного маршруту: $count';
  }

  @override
  String get analysisUnknownReasonNotice =>
      'Кожен відрізок UNKNOWN враховано за однією наявною причиною невизначеного покриття. Дані GPS кінцевих точок можуть пояснити її докладніше; причини не враховуються двічі.';

  @override
  String get analysisDiagnosticsTitle => 'Діагностика покриття прогулянки';

  @override
  String get analysisCopyDiagnostics => 'Копіювати діагностику';

  @override
  String get analysisDiagnosticsCopied => 'Діагностику скопійовано';

  @override
  String get analysisDiagnosticsCopyFailed =>
      'Не вдалося скопіювати діагностику';

  @override
  String analysisDiagnosticsPercentage(num value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return '$valueString%';
  }

  @override
  String get surfaceReanalyze => 'Повторно аналізувати покриття';

  @override
  String get surfaceJournalInvalid =>
      'Збережені дані покриття некоректні. Записана прогулянка не пошкоджена. Повторний аналіз може відновити автоматичний результат; виправлення не буде видалено.';

  @override
  String get surfaceAnalysisSaveFailed =>
      'Не вдалося зберегти аналіз на пристрої. Попередній збережений перегляд і виправлення не змінилися. Спробуйте ще раз.';

  @override
  String get surfacePreviousKept =>
      'Показано попередній збережений перегляд із виправленнями.';

  @override
  String get surfacePreviewUnsaved =>
      'Цей неповний перегляд не збережено. Виправлення стануть доступними після збереження повного аналізу.';

  @override
  String get surfaceSegments => 'Сегменти маршруту';

  @override
  String get surfaceSelectSegment =>
      'Сегменти впорядковано від початку прогулянки. Натисніть сегмент, щоб виправити його покриття.';

  @override
  String surfaceSegment(int number) {
    return 'Сегмент $number';
  }

  @override
  String surfaceSegmentPosition(String start, String end) {
    return '$start–$end від початку';
  }

  @override
  String get surfaceCorrected => 'Виправлено';

  @override
  String get surfaceAutomatic => 'Автоматично';

  @override
  String get surfaceChooseLabel => 'Покриття';

  @override
  String get surfaceCorrectionNotice =>
      'Ваш вибір діє для всього сегмента й зберігається після повторного аналізу. Виберіть невідоме покриття, якщо жодна підтримувана назва не підходить.';

  @override
  String get surfaceCorrectionSaveFailed =>
      'Не вдалося зберегти зміну. Збережений перегляд не змінився. Спробуйте ще раз.';

  @override
  String get surfaceRestoreAutomatic => 'Відновити автоматичне';

  @override
  String get surfaceSave => 'Зберегти';
}
