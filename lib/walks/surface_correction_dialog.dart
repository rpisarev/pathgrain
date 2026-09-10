import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'analysis/route_analysis.dart';
import 'analysis/surface_journal.dart';

class SurfaceCorrectionDialog extends StatefulWidget {
  const SurfaceCorrectionDialog({
    super.key,
    required this.segment,
    required this.number,
    required this.save,
  });

  final EffectiveSurfaceSegment segment;
  final int number;
  final Future<void> Function(CanonicalSurface? surface) save;

  @override
  State<SurfaceCorrectionDialog> createState() =>
      _SurfaceCorrectionDialogState();
}

class _SurfaceCorrectionDialogState extends State<SurfaceCorrectionDialog> {
  late CanonicalSurface _surface = widget.segment.surface;
  bool _saving = false;
  bool _failed = false;

  Future<void> _save(CanonicalSurface? surface) async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.save(surface);
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop();
    } catch (_) {
      // Keep the selection and allow retry; never show raw SQLite exceptions.
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(l.surfaceSegment(widget.number)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.surfaceCorrectionNotice),
              const SizedBox(height: 12),
              DropdownButtonFormField<CanonicalSurface>(
                key: const ValueKey('surface-chooser'),
                initialValue: _surface,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.surfaceChooseLabel),
                items: [
                  for (final surface in CanonicalSurface.values)
                    DropdownMenuItem(
                      value: surface,
                      child: Text(l.analysisSurface(surface.name)),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _surface = value!),
              ),
              if (_saving) const LinearProgressIndicator(),
              if (_failed) Text(l.surfaceCorrectionSaveFailed),
            ],
          ),
        ),
        actions: [
          if (widget.segment.isCorrected)
            TextButton(
              onPressed: _saving ? null : () => _save(null),
              child: Text(l.surfaceRestoreAutomatic),
            ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: _saving ? null : () => _save(_surface),
            child: Text(l.surfaceSave),
          ),
        ],
      ),
    );
  }
}
