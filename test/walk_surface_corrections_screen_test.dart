import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/l10n/app_localizations.dart';
import 'package:pathgrain/map/evidence/evidence_repository.dart';
import 'package:pathgrain/map/evidence/osm_evidence_provider.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/surface_journal.dart';
import 'package:pathgrain/walks/analysis/walk_surface_summary.dart';
import 'package:pathgrain/walks/surface_correction_dialog.dart';
import 'package:pathgrain/walks/surface_route_geojson.dart';
import 'package:pathgrain/walks/walk_surface_map.dart';
import 'package:pathgrain/walks/walk_surface_review_screen.dart';

import 'support/evidence_fakes.dart';
import 'support/surface_fixtures.dart';
import 'support/surface_journal_fakes.dart';
import 'walk_surface_review_screen_test.dart' show localized, savedWalk;

const asphalt = CanonicalSurface.asphalt;
const unknown = CanonicalSurface.unknown;
const grass = CanonicalSurface.grass;
const paving = CanonicalSurface.tile;

class ReviewHarness {
  ReviewHarness({bool saved = true, this.locale = 'en'}) {
    store = MemorySurfaceRepository(
      journal: saved ? SurfaceJournal(automatic, const []) : null,
    );
  }
  final String locale;
  final automatic = AutomaticSurfaceSnapshot.fromSummary(
    WalkSurfaceSummary.fromAnalysis(
      surfaceAnalysis([asphalt, asphalt, unknown, unknown, paving, paving]),
    ),
  );
  late final MemorySurfaceRepository store;
  bool offline = false;
  WalkSurfaceMap? latest;
  late final provider = FakeEvidenceProvider((_) async {
    if (offline) throw const EvidenceException(EvidenceFailure.offline);
    return mixedSurfaceEvidence();
  });
  late final evidence = EvidenceRepository(
    provider: provider,
    cache: MemoryEvidenceCache(),
  );

  Widget view() => localized(
    WalkSurfaceReviewScreen(
      walk: savedWalk(automatic.points),
      loadPoints: () async => automatic.points,
      surfaceRepository: store,
      evidenceRepository: evidence,
      mapBuilder: (map) {
        latest = map;
        return const SizedBox.expand();
      },
    ),
    locale: locale,
  );

  Map<String, Object?> get mapData =>
      SurfaceRouteGeoJson.build(latest!.summary);
}

Future<void> openSegment(WidgetTester tester, int start, int end) async {
  final row = find.byKey(ValueKey('segment-$start-$end'));
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
  expect(find.byType(SurfaceCorrectionDialog), findsOneWidget);
}

Future<void> choose(
  WidgetTester tester,
  AppLocalizations l,
  CanonicalSurface surface,
) async {
  final selected = tester
      .widget<DropdownButton<CanonicalSurface>>(
        find.byType(DropdownButton<CanonicalSurface>),
      )
      .value!;
  await tester.tap(find.byKey(const ValueKey('surface-chooser')));
  await tester.pumpAndSettle();
  final menu = find.byType(ListView).last;
  final option = find.descendant(
    of: menu,
    matching: find.text(l.analysisSurface(surface.name)),
  );
  await tester.scrollUntilVisible(
    option,
    surface.index < selected.index ? -120 : 120,
    scrollable: find.descendant(of: menu, matching: find.byType(Scrollable)),
  );
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  for (final saved in [false, true]) {
    testWidgets('rapid repeated analysis starts once (saved: $saved)', (
      tester,
    ) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final h = ReviewHarness(saved: saved);
      await tester.pumpWidget(h.view());
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(
          FilledButton,
          saved ? l.surfaceReanalyze : l.surfaceAnalyze,
        ),
      );
      // Two actions delivered before the disabled/loading UI has rebuilt.
      button.onPressed!();
      button.onPressed!();
      await tester.pumpAndSettle();
      expect(h.store.analysisSaves, 1);
      expect(h.provider.calls, hasLength(1));
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  }

  testWidgets('rapid segment selection opens only one editor', (tester) async {
    final h = ReviewHarness();
    await tester.pumpWidget(h.view());
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('segment-0-2'));
    await tester.ensureVisible(row);
    final tap = tester.widget<ListTile>(row).onTap!;
    tap();
    tap();
    await tester.pumpAndSettle();
    expect(
      find.byType(SurfaceCorrectionDialog, skipOffstage: false),
      findsOneWidget,
    );
  });

  for (final restore in [false, true]) {
    testWidgets(
      'pending ${restore ? "Restore" : "Save"} prevents duplicate or conflicting edits',
      (tester) async {
        final l = await AppLocalizations.delegate.load(const Locale('en'));
        final h = ReviewHarness();
        final segment = SurfaceJournal(h.automatic, const [
          SurfaceCorrection(startEdgeIndex: 0, endEdgeIndex: 2, surface: grass),
        ]).effective.segments.first;
        final gate = Completer<void>();
        final choices = <CanonicalSurface?>[];
        await tester.pumpWidget(
          localized(
            Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => SurfaceCorrectionDialog(
                      segment: segment,
                      number: 1,
                      save: (surface) async {
                        choices.add(surface);
                        await gate.future;
                      },
                    ),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
        final save = tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, l.surfaceSave),
            )
            .onPressed!;
        final remove = tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, l.surfaceRestoreAutomatic),
            )
            .onPressed!;
        final action = restore ? remove : save;
        action();
        action();
        (restore ? save : remove)();
        await tester.pump();
        expect(choices, [restore ? null : grass]);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(SurfaceCorrectionDialog), findsOneWidget);
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.byType(SurfaceCorrectionDialog), findsNothing);
        expect(find.text('Open editor'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final locale in ['en', 'uk']) {
    testWidgets(
      '$locale persisted review opens locally; correct, restart and restore',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final l = await AppLocalizations.delegate.load(Locale(locale));
        final h = ReviewHarness(locale: locale)..offline = true;
        await tester.pumpWidget(h.view());
        await tester.pumpAndSettle();
        expect(find.text(l.surfaceAnalyze), findsNothing);
        expect(find.text(l.surfaceReanalyze), findsOneWidget);
        expect(h.provider.calls, isEmpty);
        final before = h.mapData;
        await openSegment(tester, 0, 2);
        expect(find.text(l.surfaceSegment(1)), findsOneWidget);
        expect(find.text(l.surfaceRestoreAutomatic), findsNothing);
        await choose(tester, l, grass);
        await tester.tap(find.text(l.surfaceSave));
        await tester.pumpAndSettle();
        expect(find.byType(SurfaceCorrectionDialog), findsNothing);
        expect(h.mapData, isNot(before));
        expect(
          h.latest!.summary.distanceBySurface.containsKey(asphalt),
          isFalse,
        );
        expect(
          h.latest!.summary.distanceBySurface[grass],
          h.automatic.segments.first.distanceMeters,
        );
        expect(find.textContaining(l.surfaceCorrected), findsOneWidget);
        expect(
          h.store.journal!.automatic.segments.first.surface.surface,
          asphalt,
        );
        expect(
          h.store.journal!.effective.reconcilesWith(
            savedWalk(h.automatic.points).distanceMeters,
          ),
          isTrue,
        );
        final corrected = h.mapData;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(h.view());
        await tester.pumpAndSettle();
        expect(h.mapData, corrected);
        expect(h.provider.calls, isEmpty);
        await openSegment(tester, 0, 2);
        await tester.tap(find.text(l.surfaceRestoreAutomatic));
        await tester.pumpAndSettle();
        expect(h.mapData, before);
        expect(h.store.journal!.corrections, isEmpty);
        expect(find.textContaining(l.surfaceCorrected), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$locale saving automatic labels clears provenance and stays automatic after reopen',
      (tester) async {
        final l = await AppLocalizations.delegate.load(Locale(locale));
        final h = ReviewHarness(locale: locale)..offline = true;
        await tester.pumpWidget(h.view());
        await tester.pumpAndSettle();
        final before = h.mapData;
        for (final (start, end, surface) in [
          (0, 2, asphalt),
          (2, 4, unknown),
        ]) {
          await openSegment(tester, start, end);
          await tester.tap(find.text(l.surfaceSave));
          await tester.pumpAndSettle();
          expect(h.store.journal!.corrections, isEmpty);
          expect(h.mapData, before);
          await openSegment(tester, start, end);
          await choose(tester, l, grass);
          await tester.tap(find.text(l.surfaceSave));
          await tester.pumpAndSettle();
          expect(find.textContaining(l.surfaceCorrected), findsOneWidget);
          await openSegment(tester, start, end);
          await choose(tester, l, surface);
          await tester.tap(find.text(l.surfaceSave));
          await tester.pumpAndSettle();
          expect(h.store.journal!.corrections, isEmpty);
          expect(find.textContaining(l.surfaceCorrected), findsNothing);
          expect(
            find.descendant(
              of: find.byKey(ValueKey('segment-$start-$end')),
              matching: find.textContaining(l.surfaceAutomatic),
            ),
            findsOneWidget,
          );
          expect(h.mapData, before);
          expect(
            h.latest!.summary.reconcilesWith(
              savedWalk(h.automatic.points).distanceMeters,
            ),
            isTrue,
          );
          await openSegment(tester, start, end);
          expect(find.text(l.surfaceRestoreAutomatic), findsNothing);
          await tester.tap(find.text(l.cancel));
          await tester.pumpAndSettle();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(h.view());
        await tester.pumpAndSettle();
        expect(h.mapData, before);
        expect(find.textContaining(l.surfaceCorrected), findsNothing);
        expect(h.provider.calls, isEmpty);
        await openSegment(tester, 0, 2);
        expect(find.text(l.surfaceRestoreAutomatic), findsNothing);
        await tester.tap(find.text(l.cancel));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$locale UNKNOWN can become known and known can become UNKNOWN',
      (tester) async {
        final l = await AppLocalizations.delegate.load(Locale(locale));
        final h = ReviewHarness(locale: locale);
        await tester.pumpWidget(h.view());
        await tester.pumpAndSettle();
        await openSegment(tester, 2, 4);
        await choose(tester, l, grass);
        await tester.tap(find.text(l.surfaceSave));
        await tester.pumpAndSettle();
        expect(h.latest!.summary.unknownDistanceMeters, 0);
        await openSegment(tester, 0, 2);
        await choose(tester, l, unknown);
        await tester.tap(find.text(l.surfaceSave));
        await tester.pumpAndSettle();
        expect(
          h.latest!.summary.unknownDistanceMeters,
          h.automatic.segments.first.distanceMeters,
        );
        expect(h.store.journal!.corrections, hasLength(2));
        expect(find.byKey(const ValueKey('surface-unknown')), findsOneWidget);
        expect(find.textContaining(l.surfaceCorrected), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$locale failed save/restore stays recoverable and does not update the review',
      (tester) async {
        final l = await AppLocalizations.delegate.load(Locale(locale));
        final h = ReviewHarness(locale: locale);
        await tester.pumpWidget(h.view());
        await tester.pumpAndSettle();
        final before = h.mapData;
        await openSegment(tester, 0, 2);
        await choose(tester, l, paving);
        h.store.failSave = true;
        await tester.tap(find.text(l.surfaceSave));
        await tester.pumpAndSettle();
        expect(find.text(l.surfaceCorrectionSaveFailed), findsOneWidget);
        expect(h.store.journal!.corrections, isEmpty);
        expect(h.mapData, before);
        h.store.failSave = false;
        await tester.tap(find.text(l.surfaceSave));
        await tester.pumpAndSettle();
        final corrected = h.mapData;
        await openSegment(tester, 0, 2);
        h.store.failSave = true;
        await tester.tap(find.text(l.surfaceRestoreAutomatic));
        await tester.pumpAndSettle();
        expect(find.text(l.surfaceCorrectionSaveFailed), findsOneWidget);
        expect(h.mapData, corrected);
        expect(h.store.journal!.corrections, hasLength(1));
        h.store.failSave = false;
        await tester.tap(find.text(l.surfaceRestoreAutomatic));
        await tester.pumpAndSettle();
        expect(h.mapData, before);
      },
    );
  }

  testWidgets(
    'explicit first analysis saves; reopening does not analyze or fetch',
    (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final h = ReviewHarness(saved: false);
      await tester.pumpWidget(h.view());
      await tester.pumpAndSettle();
      expect(h.provider.calls, isEmpty);
      expect(h.latest, isNull);
      await tester.tap(find.text(l.surfaceAnalyze));
      await tester.pumpAndSettle();
      expect(h.store.analysisSaves, 1);
      final before = h.mapData;
      final calls = h.provider.calls.length;
      h.offline = true;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(h.view());
      await tester.pumpAndSettle();
      expect(h.store.analysisSaves, 1);
      expect(h.provider.calls.length, calls);
      expect(h.mapData, before);
      expect(find.text(l.surfaceAnalyze), findsNothing);
    },
  );

  testWidgets(
    'explicit re-analysis changes automatic results but preserves correction',
    (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final h = ReviewHarness();
      await tester.pumpWidget(h.view());
      await tester.pumpAndSettle();
      await openSegment(tester, 0, 2);
      await choose(tester, l, grass);
      await tester.tap(find.text(l.surfaceSave));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l.surfaceReanalyze));
      await tester.tap(find.text(l.surfaceReanalyze));
      await tester.pumpAndSettle();
      expect(h.store.analysisSaves, 1);
      expect(
        h.store.journal!.automatic.segments.first.surface.surface,
        unknown,
      );
      expect(h.store.journal!.corrections.single.startEdgeIndex, 0);
      expect(h.store.journal!.corrections.single.endEdgeIndex, 2);
      expect(h.latest!.summary.segments.first.surface, grass);
      expect(h.latest!.summary.segments.first.isCorrected, isTrue);
      await openSegment(tester, 0, 2);
      await tester.tap(find.text(l.surfaceRestoreAutomatic));
      await tester.pumpAndSettle();
      expect(h.latest!.summary.segments.first.surface, unknown);
    },
  );

  testWidgets(
    'failed/incomplete re-analysis keeps the saved map and corrections',
    (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final h = ReviewHarness()..offline = true;
      h.store.journal = SurfaceJournal(h.automatic, const [
        SurfaceCorrection(startEdgeIndex: 2, endEdgeIndex: 4, surface: grass),
      ]);
      await tester.pumpWidget(h.view());
      await tester.pumpAndSettle();
      final before = h.mapData;
      await tester.tap(find.text(l.surfaceReanalyze));
      await tester.pumpAndSettle();
      expect(find.text(l.surfacePreviousKept), findsOneWidget);
      expect(h.mapData, before);
      expect(h.store.analysisSaves, 0);
      expect(h.store.journal!.corrections, hasLength(1));
      h.offline = false;
      h.store.failSave = true;
      await tester.tap(find.text(l.surfaceRetry));
      await tester.pumpAndSettle();
      expect(find.text(l.surfaceAnalysisSaveFailed), findsOneWidget);
      expect(h.mapData, before);
      expect(h.store.journal!.corrections, hasLength(1));
    },
  );

  testWidgets(
    'incomplete first preview stays unsaved with no correction controls',
    (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final h = ReviewHarness(saved: false)..offline = true;
      await tester.pumpWidget(h.view());
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.surfaceAnalyze));
      await tester.pumpAndSettle();
      expect(find.text(l.surfacePreviewUnsaved), findsOneWidget);
      expect(find.text(l.surfaceSegments), findsNothing);
      expect(h.store.journal, isNull);
      expect(
        h.latest!.summary.unknownDistanceMeters,
        closeTo(savedWalk(h.automatic.points).distanceMeters, 1e-6),
      );
    },
  );

  testWidgets(
    'corrupt journal offers explicit recovery; database read errors retry locally',
    (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final h = ReviewHarness(saved: false);
      h.store.failLoad = true;
      await tester.pumpWidget(h.view());
      await tester.pumpAndSettle();
      expect(find.text(l.surfaceReviewFailed), findsOneWidget);
      expect(find.text(l.surfaceAnalyze), findsNothing);
      h.store.failLoad = false;
      h.store.corrupt = true;
      await tester.tap(find.text(l.surfaceRetry));
      await tester.pumpAndSettle();
      expect(find.text(l.surfaceJournalInvalid), findsOneWidget);
      expect(h.provider.calls, isEmpty);
      expect(h.latest, isNull);
      // A diagnosed corrupt snapshot is a different recoverable state than IO failure.
      expect(find.text(l.surfaceAnalyze), findsOneWidget);
      await tester.tap(find.text(l.surfaceAnalyze));
      await tester.pumpAndSettle();
      expect(find.text(l.surfaceJournalInvalid), findsNothing);
      expect(h.store.analysisSaves, 1);
    },
  );
}
