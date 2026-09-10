import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/l10n/app_localizations.dart';
import 'package:pathgrain/map/evidence/surface_summary_details.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/walk_surface_summary.dart';

import 'support/analysis_fixtures.dart';
import 'support/surface_fixtures.dart';

Widget diagnostics(WalkSurfaceSummary summary, String locale) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      child: SurfaceSummaryDetails(summary: summary, initiallyExpanded: true),
    ),
  ),
);

void main() {
  for (final locale in ['en', 'uk']) {
    testWidgets(
      '$locale sorts UNKNOWN meters, uses UNKNOWN denominator and copies visible totals',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final l = await AppLocalizations.delegate.load(Locale(locale));
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = call.arguments['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        // 60 known meters; UNKNOWN has 30 + 20 meters, plus a zero-meter reason.
        final summary = WalkSurfaceSummary.fromAnalysis(
          surfaceAnalysis(
            [
              CanonicalSurface.asphalt,
              ...List.filled(4, CanonicalSurface.unknown),
            ],
            points: [
              sample(0, 0, 0),
              sample(1, 60, 0),
              sample(2, 70, 0),
              sample(3, 100, 0),
              sample(4, 100, 0),
              sample(5, 110, 0),
            ],
            reasons: [
              AnalysisReason.matched,
              AnalysisReason.missingSurface,
              AnalysisReason.differentObjects,
              AnalysisReason.noCandidate,
              AnalysisReason.missingSurface,
            ],
          ),
        );
        await tester.pumpWidget(diagnostics(summary, locale));
        await tester.pumpAndSettle();
        final dominant = find.byKey(
          const ValueKey('unknown-reason-differentObjects'),
        );
        final smaller = find.byKey(
          const ValueKey('unknown-reason-missingSurface'),
        );
        expect(
          tester.getTopLeft(dominant).dy,
          lessThan(tester.getTopLeft(smaller).dy),
        );
        expect(
          find.byKey(const ValueKey('unknown-reason-noCandidate')),
          findsNothing,
        );
        final dominantValue =
            '${l.distanceMeters(30)} (${l.analysisDiagnosticsPercentage(60)})';
        final smallerValue =
            '${l.distanceMeters(20)} (${l.analysisDiagnosticsPercentage(40)})';
        expect(
          find.descendant(of: dominant, matching: find.text(dominantValue)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: smaller, matching: find.text(smallerValue)),
          findsOneWidget,
        );
        final unknownTotal =
            '${l.analysisUnknownTotal(l.distanceMeters(50))} '
            '(${l.analysisDiagnosticsPercentage(45.5)})';
        final total = l.surfaceTotal(l.distanceMeters(110));
        expect(find.text(unknownTotal), findsOneWidget);
        expect(find.text(total), findsOneWidget);
        await tester.tap(find.text(l.analysisCopyDiagnostics));
        await tester.pumpAndSettle();
        expect(
          copied,
          [
            l.analysisDiagnosticsTitle,
            '',
            total,
            unknownTotal,
            '',
            '${l.analysisUnknownDistances}:',
            '- ${l.analysisReason('differentObjects')}: $dominantValue',
            '- ${l.analysisReason('missingSurface')}: $smallerValue',
          ].join('\n'),
        );
        expect(find.text(l.analysisDiagnosticsCopied), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$locale zero UNKNOWN and zero route totals remain copyable without invalid percentages',
      (tester) async {
        final l = await AppLocalizations.delegate.load(Locale(locale));
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = call.arguments['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        for (final analysis in [
          surfaceAnalysis([CanonicalSurface.asphalt]),
          surfaceAnalysis([], points: []),
          surfaceAnalysis(
            [CanonicalSurface.unknown],
            points: [sample(0, 0, 0), sample(1, 0, 0)],
          ),
        ]) {
          final summary = WalkSurfaceSummary.fromAnalysis(analysis);
          await tester.pumpWidget(diagnostics(summary, locale));
          await tester.pumpAndSettle();
          final unknownTotal =
              '${l.analysisUnknownTotal(l.distanceMeters(0))} '
              '(${l.analysisDiagnosticsPercentage(0)})';
          expect(find.text(unknownTotal), findsOneWidget);
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith(
                    'unknown-reason-',
                  ),
            ),
            findsNothing,
          );
          await tester.tap(find.text(l.analysisCopyDiagnostics));
          await tester.pumpAndSettle();
          expect(copied, contains(unknownTotal));
          expect(copied, isNot(contains('NaN')));
          expect(copied, isNot(contains('Infinity')));
          expect(copied, isNot(contains('\n- ')));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
    );
  }
}
