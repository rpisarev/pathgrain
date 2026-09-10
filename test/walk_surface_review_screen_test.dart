import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/l10n/app_localizations.dart';
import 'package:pathgrain/map/evidence/evidence_debug_screen.dart';
import 'package:pathgrain/map/evidence/evidence_repository.dart';
import 'package:pathgrain/map/evidence/geographic_cell.dart';
import 'package:pathgrain/map/evidence/osm_evidence.dart';
import 'package:pathgrain/map/evidence/osm_evidence_provider.dart';
import 'package:pathgrain/map/evidence/surface_summary_details.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/route_matcher.dart';
import 'package:pathgrain/walks/analysis/walk_surface_summary.dart';
import 'package:pathgrain/walks/app_database.dart';
import 'package:pathgrain/walks/walk_detail_screen.dart';
import 'package:pathgrain/walks/walk_distance.dart';
import 'package:pathgrain/walks/walk_models.dart';
import 'package:pathgrain/walks/walk_repository.dart';
import 'package:pathgrain/walks/walk_surface_map.dart';
import 'package:pathgrain/walks/walk_surface_review_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/analysis_fixtures.dart';
import 'support/evidence_fakes.dart';
import 'support/surface_fixtures.dart';

Widget localized(Widget child, {String locale = 'en'}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Walk savedWalk(List<WalkPoint> points, {double? distance}) => Walk(
  id: 17,
  startedAt: DateTime.utc(2026, 1, 1),
  endedAt: DateTime.utc(2026, 1, 1, 0, 10),
  durationMilliseconds: 600000,
  distanceMeters: distance ?? WalkDistance.total(points),
  status: WalkStatus.completed,
  pointCount: points.length,
);

void main() {
  for (final locale in ['en', 'uk']) {
    testWidgets('$locale several surfaces and UNKNOWN use the original route', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final l = await AppLocalizations.delegate.load(Locale(locale));
      final points = straight(count: 30);
      final provider = FakeEvidenceProvider(
        (_) async => mixedSurfaceEvidence(),
      );
      WalkSurfaceMap? latest;
      var loads = 0;
      await tester.pumpWidget(
        localized(
          WalkSurfaceReviewScreen(
            walk: savedWalk(points),
            loadPoints: () async {
              loads++;
              return points;
            },
            evidenceRepository: EvidenceRepository(
              provider: provider,
              cache: MemoryEvidenceCache(),
            ),
            mapBuilder: (map) {
              latest = map;
              return const SizedBox.expand();
            },
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l.surfaceAccessNotice), findsOneWidget);
      expect(provider.calls, isEmpty);
      expect(latest, isNull);
      await tester.ensureVisible(find.text(l.surfaceAnalyze));
      await tester.tap(find.text(l.surfaceAnalyze));
      await tester.pumpAndSettle();
      final summary = latest!.summary;
      expect(
        summary.distanceBySurface.keys,
        containsAll([
          CanonicalSurface.asphalt,
          CanonicalSurface.pavingStones,
          CanonicalSurface.grass,
          CanonicalSurface.unknown,
        ]),
      );
      for (final surface in summary.distanceBySurface.keys) {
        expect(find.text(l.analysisSurface(surface.name)), findsOneWidget);
      }
      expect(summary.reconcilesWith(savedWalk(points).distanceMeters), isTrue);
      for (var i = 0; i < points.length; i++) {
        expect(summary.analysis.samples[i].original, same(points[i]));
      }
      expect(find.text(l.surfaceDistanceMismatch), findsNothing);
      expect(find.text(l.analysisSelected('way/1')), findsNothing);
      expect(find.byType(SurfaceSummaryDetails), findsNothing);
      expect(find.text(l.evidenceAttribution), findsOneWidget);
      expect(loads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      '$locale UNKNOWN reason distances are inspectable in debug UI',
      (tester) async {
        final l = await AppLocalizations.delegate.load(Locale(locale));
        final path = straightPath(tags: {'highway': 'footway'});
        final evidence = OsmEvidence(
          features: [path],
          raw: {
            'elements': [path.raw],
          },
          unparsedElements: 0,
        );
        final provider = FakeEvidenceProvider((_) async => evidence);
        await tester.pumpWidget(
          localized(
            EvidenceDebugScreen(
              loadPoints: () async => straight(),
              evidenceRepository: EvidenceRepository(
                provider: provider,
                cache: MemoryEvidenceCache(),
              ),
              mapBuilder: (_) => const SizedBox.expand(),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.analysisUnknownDistances));
        await tester.pumpAndSettle();
        expect(find.text(l.analysisCopyDiagnostics), findsOneWidget);
        Navigator.of(tester.element(find.byType(SurfaceSummaryDetails))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.evidenceBrowse));
        await tester.pumpAndSettle();
        expect(find.byType(SurfaceSummaryDetails), findsOneWidget);
        final summary = tester
            .widget<SurfaceSummaryDetails>(find.byType(SurfaceSummaryDetails))
            .summary;
        expect(
          summary.unknownDistanceByReason.keys,
          containsAll([
            AnalysisReason.uncertainEndpoint,
            AnalysisReason.missingSurface,
          ]),
        );
        await tester.tap(
          find.descendant(
            of: find.byType(SurfaceSummaryDetails),
            matching: find.text(l.analysisUnknownDistances),
          ),
        );
        await tester.pumpAndSettle();
        for (final entry in summary.unknownDistanceByReason.entries) {
          final meters = l.distanceMeters(
            double.parse(entry.value.toStringAsFixed(1)),
          );
          final row = find.byKey(ValueKey('unknown-reason-${entry.key.name}'));
          final percentage = l.analysisDiagnosticsPercentage(
            double.parse(
              (entry.value / summary.unknownDistanceMeters * 100)
                  .toStringAsFixed(1),
            ),
          );
          expect(
            find.descendant(
              of: row,
              matching: find.text(l.analysisReason(entry.key.name)),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: row,
              matching: find.text('$meters ($percentage)'),
            ),
            findsOneWidget,
          );
        }
        expect(provider.calls, hasLength(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final count in [0, 1]) {
    testWidgets(
      '$count saved points give an honest empty state without evidence access',
      (tester) async {
        final l = await AppLocalizations.delegate.load(const Locale('en'));
        final points = straight(count: count);
        final provider = FakeEvidenceProvider(
          (_) async => mixedSurfaceEvidence(),
        );
        await tester.pumpWidget(
          localized(
            WalkSurfaceReviewScreen(
              walk: savedWalk(points),
              loadPoints: () async => points,
              evidenceRepository: EvidenceRepository(
                provider: provider,
                cache: MemoryEvidenceCache(),
              ),
              mapBuilder: (_) => const Text('Unexpected map'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(l.routeUnavailable), findsOneWidget);
        expect(find.text(l.surfaceAnalyze), findsNothing);
        expect(find.text('Unexpected map'), findsNothing);
        expect(provider.calls, isEmpty);
      },
    );
  }

  testWidgets(
    'saved detail reaches normal review without a debug action or fetch',
    (tester) async {
      final repository = ReadOnlyWalkRepository();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        localized(
          WalkDetailScreen(walk: savedWalk([]), repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.surfaceReview));
      await tester.pumpAndSettle();
      expect(find.byType(WalkSurfaceReviewScreen), findsOneWidget);
      expect(find.text(l.routeUnavailable), findsOneWidget);
      expect(find.byType(EvidenceDebugScreen), findsNothing);
    },
  );

  testWidgets('point-load failure offers retry and no evidence requests', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final points = straight();
    var attempts = 0;
    final provider = FakeEvidenceProvider((_) async => mixedSurfaceEvidence());
    await tester.pumpWidget(
      localized(
        WalkSurfaceReviewScreen(
          walk: savedWalk(points),
          loadPoints: () async {
            if (attempts++ == 0) throw StateError('Synthetic local failure');
            return points;
          },
          evidenceRepository: EvidenceRepository(
            provider: provider,
            cache: MemoryEvidenceCache(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.surfaceReviewFailed), findsOneWidget);
    await tester.tap(find.text(l.surfaceRetry));
    await tester.pumpAndSettle();
    expect(find.text(l.surfaceAnalyze), findsOneWidget);
    expect(provider.calls, isEmpty);
    expect(attempts, 2);
  });

  testWidgets(
    'pending points and evidence show loading; leaving stops later cells',
    (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final points = [sample(0, 0, 0), sample(1, 5000, 0), sample(2, 10000, 0)];
      final local = Completer<List<WalkPoint>>();
      final response = Completer<OsmEvidence>();
      final provider = FakeEvidenceProvider((_) => response.future);
      await tester.pumpWidget(
        localized(
          WalkSurfaceReviewScreen(
            walk: savedWalk(points),
            loadPoints: () => local.future,
            evidenceRepository: EvidenceRepository(
              provider: provider,
              cache: MemoryEvidenceCache(),
            ),
            mapBuilder: (_) => const SizedBox.expand(),
          ),
        ),
      );
      expect(find.text(l.mapLoading), findsOneWidget);
      local.complete(points);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.surfaceAnalyze));
      await tester.pump();
      await tester.pump();
      expect(find.text(l.surfaceAnalyzing), findsOneWidget);
      expect(provider.calls, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      response.complete(mixedSurfaceEvidence());
      await tester.pumpAndSettle();
      expect(provider.calls, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'offline missing coverage retains complete UNKNOWN distance; retry reuses cache',
    (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final points = straight(count: 30);
      var offline = true;
      final provider = FakeEvidenceProvider((_) async {
        if (offline) throw const EvidenceException(EvidenceFailure.offline);
        return mixedSurfaceEvidence();
      });
      final repository = EvidenceRepository(
        provider: provider,
        cache: MemoryEvidenceCache(),
      );
      WalkSurfaceMap? latest;
      Widget review() => localized(
        WalkSurfaceReviewScreen(
          walk: savedWalk(points),
          loadPoints: () async => points,
          evidenceRepository: repository,
          mapBuilder: (map) {
            latest = map;
            return const SizedBox.expand();
          },
        ),
      );
      await tester.pumpWidget(review());
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.surfaceAnalyze));
      await tester.pumpAndSettle();
      expect(find.text(l.surfaceEvidenceIncomplete), findsOneWidget);
      expect(
        latest!.summary.unknownDistanceMeters,
        closeTo(WalkDistance.total(points), 1e-6),
      );
      offline = false;
      await tester.tap(find.text(l.surfaceRetry));
      await tester.pumpAndSettle();
      expect(find.text(l.surfaceEvidenceIncomplete), findsNothing);
      expect(
        latest!.summary.distanceBySurface[CanonicalSurface.asphalt],
        greaterThan(0),
      );
      final calls = provider.calls.length;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(review());
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.surfaceAnalyze));
      await tester.pumpAndSettle();
      expect(provider.calls, hasLength(calls));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'unparsed evidence suppresses classifications and discloses saved mismatch',
    (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final points = straight();
      final evidence = mixedSurfaceEvidence();
      final provider = FakeEvidenceProvider(
        (_) async => OsmEvidence(
          features: evidence.features,
          raw: evidence.raw,
          unparsedElements: 1,
        ),
      );
      WalkSurfaceMap? latest;
      await tester.pumpWidget(
        localized(
          WalkSurfaceReviewScreen(
            walk: savedWalk(points, distance: 999),
            loadPoints: () async => points,
            evidenceRepository: EvidenceRepository(
              provider: provider,
              cache: MemoryEvidenceCache(),
            ),
            mapBuilder: (map) {
              latest = map;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.surfaceAnalyze));
      await tester.pumpAndSettle();
      expect(find.text(l.surfaceEvidenceIncomplete), findsOneWidget);
      expect(find.text(l.surfaceDistanceMismatch), findsOneWidget);
      expect(
        latest!.summary.unknownDistanceMeters,
        closeTo(WalkDistance.total(points), 1e-6),
      );
    },
  );

  testWidgets(
    'invalid saved coordinates fail before evidence or native map access',
    (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final point = WalkPoint(
        walkId: 17,
        sequence: 0,
        latitude: double.infinity,
        longitude: 2,
        recordedAt: DateTime.utc(2026),
        accuracyMeters: 7,
      );
      final provider = FakeEvidenceProvider(
        (_) async => mixedSurfaceEvidence(),
      );
      await tester.pumpWidget(
        localized(
          WalkSurfaceReviewScreen(
            walk: savedWalk([]),
            loadPoints: () async => [point],
            evidenceRepository: EvidenceRepository(
              provider: provider,
              cache: MemoryEvidenceCache(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l.surfaceReviewFailed), findsOneWidget);
      expect(provider.calls, isEmpty);
      expect(find.byType(WalkSurfaceMap), findsNothing);
    },
  );

  testWidgets('analysis loading failure offers a successful manual retry', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final points = straight();
    final repository = FailingOnceEvidenceRepository();
    WalkSurfaceMap? latest;
    await tester.pumpWidget(
      localized(
        WalkSurfaceReviewScreen(
          walk: savedWalk(points),
          loadPoints: () async => points,
          evidenceRepository: repository,
          mapBuilder: (map) {
            latest = map;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.surfaceAnalyze));
    await tester.pumpAndSettle();
    expect(find.text(l.surfaceReviewFailed), findsOneWidget);
    expect(latest, isNull);
    await tester.tap(find.text(l.surfaceRetry));
    await tester.pumpAndSettle();
    expect(find.text(l.surfaceReviewFailed), findsNothing);
    expect(latest!.summary.reconcilesWith(WalkDistance.total(points)), isTrue);
    expect(repository.attempts, 2);
  });

  testWidgets('plain-map fallback is available after native style timeout', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final summary = WalkSurfaceSummary.fromAnalysis(
      RouteMatcher.analyze(straight(), []),
    );
    await tester.pumpWidget(
      localized(Scaffold(body: WalkSurfaceMap(summary: summary))),
    );
    await tester.pump(const Duration(seconds: 21));
    expect(find.text(l.surfaceMapUnavailable), findsOneWidget);
    expect(find.text(l.surfacePlainMap), findsOneWidget);
    await tester.tap(find.text(l.surfacePlainMap));
    await tester.pump();
    expect(find.text(l.surfaceMapUnavailable), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class FailingOnceEvidenceRepository extends EvidenceRepository {
  FailingOnceEvidenceRepository()
    : super(
        provider: FakeEvidenceProvider((_) async => mixedSurfaceEvidence()),
        cache: MemoryEvidenceCache(),
      );
  int attempts = 0;
  @override
  Stream<EvidenceSnapshot> inspect(
    Iterable<GeoCoordinate> coordinates, {
    bool refresh = false,
  }) async* {
    if (attempts++ == 0) throw StateError('Synthetic analysis load failure');
    yield* super.inspect(coordinates, refresh: refresh);
  }
}

class ReadOnlyWalkRepository extends WalkRepository {
  ReadOnlyWalkRepository()
    : super(
        AppDatabase(
          databaseFactory: databaseFactoryFfi,
          databasePath: inMemoryDatabasePath,
        ),
      );
  @override
  Future<List<WalkPoint>> pointsForWalk(int walkId) async => [];
}
