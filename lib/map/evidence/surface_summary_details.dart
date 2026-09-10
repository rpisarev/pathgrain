import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../walks/analysis/walk_surface_summary.dart';

/// Whole-route diagnostics, distinct from the selected samples in the sheet.
class SurfaceSummaryDetails extends StatelessWidget {
  const SurfaceSummaryDetails({
    super.key,
    required this.summary,
    this.initiallyExpanded = false,
  });
  final WalkSurfaceSummary summary;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String meters(double value) =>
        l.distanceMeters(double.parse(value.toStringAsFixed(1)));
    String percentage(double value, double total) =>
        l.analysisDiagnosticsPercentage(
          double.parse(
            (total > 0 ? value / total * 100 : 0).toStringAsFixed(1),
          ),
        );
    final reasons =
        summary.unknownDistanceByReason.entries
            .where((entry) => entry.value > 0)
            .toList()
          ..sort((a, b) {
            final distanceOrder = b.value.compareTo(a.value);
            return distanceOrder != 0
                ? distanceOrder
                : a.key.index.compareTo(b.key.index);
          });
    // Format once so the visible rows and clipboard report use identical data.
    final rows = [
      for (final entry in reasons)
        (
          reason: entry.key,
          label: l.analysisReason(entry.key.name),
          value:
              '${meters(entry.value)} '
              '(${percentage(entry.value, summary.unknownDistanceMeters)})',
        ),
    ];
    final totalText = l.surfaceTotal(meters(summary.totalDistanceMeters));
    final unknownText =
        '${l.analysisUnknownTotal(meters(summary.unknownDistanceMeters))} '
        '(${percentage(summary.unknownDistanceMeters, summary.totalDistanceMeters)})';
    final report = [
      l.analysisDiagnosticsTitle,
      '',
      totalText,
      unknownText,
      '',
      '${l.analysisUnknownDistances}:',
      for (final row in rows) '- ${row.label}: ${row.value}',
    ].join('\n');
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      title: Text(l.analysisUnknownDistances),
      subtitle: Text(unknownText),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(totalText),
        Text(l.analysisSegmentCount(summary.segments.length)),
        TextButton.icon(
          onPressed: () => _copyDiagnostics(context, report),
          icon: const Icon(Icons.copy_outlined, size: 18),
          label: Text(l.analysisCopyDiagnostics),
        ),
        for (final row in rows)
          Padding(
            key: ValueKey('unknown-reason-${row.reason.name}'),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(row.label)),
                const SizedBox(width: 12),
                Text(row.value),
              ],
            ),
          ),
        Text(l.analysisUnknownReasonNotice),
      ],
    );
  }

  Future<void> _copyDiagnostics(BuildContext context, String report) async {
    final l = AppLocalizations.of(context);
    var message = l.analysisDiagnosticsCopied;
    try {
      await Clipboard.setData(ClipboardData(text: report));
    } on PlatformException {
      message = l.analysisDiagnosticsCopyFailed;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
