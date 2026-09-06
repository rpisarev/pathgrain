import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/l10n/app_localizations.dart';
import 'package:pathgrain/map/evidence/evidence_cache.dart';
import 'package:pathgrain/map/evidence/evidence_debug_screen.dart';
import 'package:pathgrain/map/evidence/evidence_inspector.dart';
import 'package:pathgrain/map/evidence/evidence_map.dart';
import 'package:pathgrain/map/evidence/evidence_repository.dart';
import 'package:pathgrain/map/evidence/geographic_cell.dart';
import 'package:pathgrain/map/evidence/osm_evidence.dart';
import 'package:pathgrain/map/evidence/osm_evidence_provider.dart';
import 'package:pathgrain/walks/app_database.dart';
import 'package:pathgrain/walks/walk_detail_screen.dart';
import 'package:pathgrain/walks/walk_models.dart';
import 'package:pathgrain/walks/walk_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/evidence_fakes.dart';

Widget localized(Widget child, {String locale = 'en'}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  final point = WalkPoint(
    walkId: 123,
    sequence: 0,
    latitude: 1,
    longitude: 2,
    recordedAt: DateTime.utc(2026, 9, 1),
    accuracyMeters: 7.25,
  );
  late OsmEvidence evidence;
  setUp(() => evidence = OsmEvidence.parse(evidenceFixture()));

  for (final locale in ['en', 'uk']) {
    testWidgets(
      '$locale inspection shows raw tags, missing surface, GPS accuracy and attribution',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final l = await AppLocalizations.delegate.load(Locale(locale));
        final provider = FakeEvidenceProvider((_) async => evidence);
        EvidenceMap? latestMap;
        await tester.pumpWidget(
          localized(
            EvidenceDebugScreen(
              loadPoints: () async => [point],
              evidenceRepository: EvidenceRepository(
                provider: provider,
                cache: MemoryEvidenceCache(),
              ),
              mapBuilder: (map) {
                latestMap = map;
                return TextButton(
                  onPressed: () => map.onInspect({'way/101', 'way/102'}, {0}),
                  child: const Text('Synthetic map tap'),
                );
              },
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(l.surfaceEvidence), findsOneWidget);
        expect(find.text(l.evidenceLoaded), findsOneWidget);
        expect(find.text(l.evidenceAttribution), findsOneWidget);
        expect(latestMap!.points.single, same(point));
        expect(latestMap!.features, hasLength(evidence.features.length));
        expect(provider.calls, hasLength(1));
        await tester.tap(find.text(l.evidenceAccuracyToggle));
        await tester.pumpAndSettle();
        expect(latestMap!.showAccuracy, isTrue);
        await tester.tap(find.text('Synthetic map tap'));
        await tester.pumpAndSettle();
        expect(find.text(l.evidenceAccuracy(7.25)), findsOneWidget);
        expect(
          find.text('highway: footway\nsurface: paving_stones'),
          findsOneWidget,
        );
        expect(
          find.text('highway: path\nsurface: ${l.evidenceTagMissing}'),
          findsOneWidget,
        );
        await tester.tap(find.text(l.evidenceFeatureTitle('way', 101)));
        await tester.pumpAndSettle();
        expect(find.text('surface = paving_stones'), findsOneWidget);
        expect(find.text('footway = sidewalk'), findsOneWidget);
        expect(provider.calls, hasLength(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'failed refresh keeps available evidence and reports offline partial result',
    (tester) async {
      final cache = MemoryEvidenceCache();
      final provider = FakeEvidenceProvider(
        (_) async => throw const EvidenceException(EvidenceFailure.offline),
      );
      await cache.write(
        provider.cacheNamespace,
        GeographicCell.fromCoordinate(const GeoCoordinate(1, 2)),
        CachedEvidence(evidence: evidence, fetchedAt: DateTime.utc(2026, 9, 1)),
      );
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      EvidenceMap? latestMap;
      await tester.pumpWidget(
        localized(
          EvidenceDebugScreen(
            loadPoints: () async => [point],
            evidenceRepository: EvidenceRepository(
              provider: provider,
              cache: cache,
            ),
            mapBuilder: (map) {
              latestMap = map;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(provider.calls, isEmpty);
      expect(
        find.text(l.evidenceCellCounts(1, 1, 1, 0, evidence.features.length)),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip(l.evidenceRefresh));
      await tester.pumpAndSettle();
      expect(provider.calls, hasLength(1));
      expect(find.text(l.evidencePartialFailure(1)), findsOneWidget);
      expect(find.text(l.evidenceOffline), findsOneWidget);
      expect(latestMap!.features, hasLength(evidence.features.length));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'debug action is deliberate; ordinary saved detail opens without evidence',
    (tester) async {
      final repository = _ReadOnlyWalkRepository();
      final walk = Walk(
        id: 123,
        startedAt: DateTime.utc(2026),
        endedAt: DateTime.utc(2026),
        durationMilliseconds: 0,
        distanceMeters: 0,
        status: WalkStatus.completed,
        pointCount: 0,
      );
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        localized(WalkDetailScreen(walk: walk, repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(repository.pointLoads, 1);
      expect(find.byType(EvidenceDebugScreen), findsNothing);
      expect(find.text(l.surfaceEvidence), findsNothing);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.surfaceEvidence));
      await tester.pumpAndSettle();
      expect(find.text(l.evidencePrivacyNotice), findsOneWidget);
      expect(find.byType(EvidenceDebugScreen), findsNothing);
      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();
      expect(repository.pointLoads, 1);
      expect(find.byType(EvidenceDebugScreen), findsNothing);
    },
  );

  testWidgets(
    'unsupported relation geometry has a visible inspector limitation',
    (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: EvidenceInspector(
              points: const [],
              features: [
                evidence.features.singleWhere((feature) => feature.id == 200),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l.evidenceRelationLimitation), findsOneWidget);
      expect(find.text(l.evidenceIncompleteGeometry), findsOneWidget);
    },
  );
}

class _ReadOnlyWalkRepository extends WalkRepository {
  _ReadOnlyWalkRepository()
    : super(
        AppDatabase(
          databaseFactory: databaseFactoryFfi,
          databasePath: inMemoryDatabasePath,
        ),
      );

  int pointLoads = 0;
  @override
  Future<List<WalkPoint>> pointsForWalk(int walkId) async {
    pointLoads++;
    return [];
  }
}
