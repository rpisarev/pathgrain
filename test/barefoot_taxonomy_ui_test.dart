import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/l10n/app_localizations.dart';
import 'package:pathgrain/map/evidence/analysis_details.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/route_matcher.dart';

import 'support/analysis_fixtures.dart';
import 'walk_surface_corrections_screen_test.dart'
    show ReviewHarness, openSegment, choose;
import 'walk_surface_review_screen_test.dart' show localized, savedWalk;

const labels = {
  CanonicalSurface.asphalt: ('Asphalt', 'Асфальт'),
  CanonicalSurface.tile: ('Tile', 'Плитка'),
  CanonicalSurface.cobblestone: ('Cobblestone', 'Бруківка'),
  CanonicalSurface.concrete: ('Concrete', 'Бетон'),
  CanonicalSurface.ground: ('Ground', 'Ґрунт'),
  CanonicalSurface.sand: ('Sand', 'Пісок'),
  CanonicalSurface.stone: ('Stone', 'Камінь'),
  CanonicalSurface.fineGravel: (
    'Fine gravel / pebbles',
    'Галька / дрібний гравій',
  ),
  CanonicalSurface.crushedStone: ('Crushed stone', 'Щебінь'),
  CanonicalSurface.grass: ('Grass', 'Трава'),
  CanonicalSurface.artificialTurf: ('Artificial turf', 'Штучна трава'),
  CanonicalSurface.rubber: ('Rubber', 'Гума'),
  CanonicalSurface.wood: ('Wood', 'Дерево'),
  CanonicalSurface.metal: ('Metal', 'Метал'),
  CanonicalSurface.unknown: ('Unknown', 'Невідомо'),
};

void main() {
  for (final locale in ['en', 'uk']) {
    testWidgets(
      '$locale chooser saves all 15 canonical labels and updates review provenance',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final l = await AppLocalizations.delegate.load(Locale(locale));
        expect(CanonicalSurface.values, labels.keys.toList());
        final h = ReviewHarness(locale: locale);
        await tester.pumpWidget(h.view());
        await tester.pumpAndSettle();
        final before = h.mapData;
        for (final entry in labels.entries) {
          final surface = entry.key;
          final label = locale == 'en' ? entry.value.$1 : entry.value.$2;
          expect(l.analysisSurface(surface.name), label);
          await openSegment(tester, 0, 2);
          final chooser = tester.widget<DropdownButton<CanonicalSurface>>(
            find.byType(DropdownButton<CanonicalSurface>),
          );
          expect(chooser.items!.map((item) => item.value), labels.keys);
          expect(
            chooser.items!.map((item) => (item.child as Text).data),
            labels.values.map((pair) => locale == 'en' ? pair.$1 : pair.$2),
          );
          expect(find.text('Other known material'), findsNothing);
          expect(find.text('Інший відомий матеріал'), findsNothing);
          await choose(tester, l, surface);
          await tester.tap(find.text(l.surfaceSave));
          await tester.pumpAndSettle();
          final current = h.latest!.summary.segments.first;
          expect(current.surface, surface);
          expect(current.isCorrected, surface != CanonicalSurface.asphalt);
          expect(
            find.byKey(ValueKey('surface-${surface.name}')),
            findsOneWidget,
          );
          final row = find.byKey(const ValueKey('segment-0-2'));
          expect(
            find.descendant(
              of: row,
              matching: find.textContaining(
                surface == CanonicalSurface.asphalt
                    ? l.surfaceAutomatic
                    : l.surfaceCorrected,
              ),
            ),
            findsOneWidget,
          );
          expect(
            h.latest!.summary.reconcilesWith(
              savedWalk(h.automatic.points).distanceMeters,
            ),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        }
        final corrected = h.mapData;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(h.view());
        await tester.pumpAndSettle();
        expect(h.mapData, corrected);
        await openSegment(tester, 0, 2);
        await tester.tap(find.text(l.surfaceRestoreAutomatic));
        await tester.pumpAndSettle();
        expect(h.mapData, before);
        expect(h.store.journal!.corrections, isEmpty);
        expect(h.provider.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    for (final (raw, surface, reason) in [
      ('gravel', CanonicalSurface.unknown, AnalysisReason.unsupportedSurface),
      ('sett', CanonicalSurface.cobblestone, AnalysisReason.explicitSurface),
      ('paving_stones', CanonicalSurface.tile, AnalysisReason.explicitSurface),
      (null, CanonicalSurface.unknown, AnalysisReason.missingSurface),
    ]) {
      testWidgets('$locale debug separates raw $raw from canonical $surface', (
        tester,
      ) async {
        final l = await AppLocalizations.delegate.load(Locale(locale));
        final route = RouteMatcher.analyze(straight(), [
          straightPath(tags: {'highway': 'footway', 'surface': ?raw}),
        ]);
        final sample = route.samples[4];
        await tester.pumpWidget(
          localized(
            Scaffold(
              body: SingleChildScrollView(
                child: AnalysisDetails(sample: sample, edges: const []),
              ),
            ),
            locale: locale,
          ),
        );
        expect(
          find.text(l.analysisOsmSurface(raw ?? l.evidenceTagMissing)),
          findsOneWidget,
        );
        expect(
          find.text(
            l.analysisResult(
              l.analysisAssignment(sample.surface.assignment.name),
              l.analysisSurface(surface.name),
            ),
          ),
          findsOneWidget,
        );
        expect(find.text(l.analysisReason(reason.name)), findsOneWidget);
        expect(sample.selected?.feature.tags['surface'], raw);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
