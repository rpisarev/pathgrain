import 'package:pathgrain/walks/analysis/surface_journal.dart';
import 'package:pathgrain/walks/analysis/walk_surface_summary.dart';
import 'package:pathgrain/walks/app_database.dart';
import 'package:pathgrain/walks/walk_models.dart';
import 'package:pathgrain/walks/walk_surface_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Widget boundary double; actual transactions/restarts have SQLite tests.
class MemorySurfaceRepository extends WalkSurfaceRepository {
  MemorySurfaceRepository({this.journal})
    : super(
        AppDatabase(
          databaseFactory: databaseFactoryFfi,
          databasePath: inMemoryDatabasePath,
        ),
      );
  SurfaceJournal? journal;
  bool failSave = false;
  bool failLoad = false;
  bool corrupt = false;
  int analysisSaves = 0;

  @override
  Future<SurfaceJournal?> load(int walkId, List<WalkPoint> points) async {
    if (corrupt) throw const FormatException('Synthetic corruption');
    if (failLoad) throw StateError('Synthetic local failure');
    return journal;
  }

  @override
  Future<SurfaceJournal> saveAnalysis(
    int walkId,
    WalkSurfaceSummary summary, {
    required bool evidenceComplete,
  }) async {
    if (failSave) throw StateError('Synthetic write failure');
    if (!evidenceComplete) throw const FormatException('Incomplete evidence');
    analysisSaves++;
    corrupt = false;
    return journal = SurfaceJournal(
      AutomaticSurfaceSnapshot.fromSummary(summary),
      journal?.corrections ?? const [],
    );
  }

  @override
  Future<SurfaceJournal> saveCorrection(
    int walkId,
    List<WalkPoint> points,
    SurfaceCorrection correction,
  ) async {
    if (failSave) throw StateError('Synthetic write failure');
    final corrections = [
      ...journal!.corrections.where((c) => !c.sameRange(correction)),
      correction,
    ]..sort((a, b) => a.startEdgeIndex.compareTo(b.startEdgeIndex));
    final updated = SurfaceJournal(journal!.automatic, corrections);
    if (correction.matchesAutomatic(journal!.automatic)) {
      return restoreAutomatic(walkId, points, correction);
    }
    return journal = updated;
  }

  @override
  Future<SurfaceJournal> restoreAutomatic(
    int walkId,
    List<WalkPoint> points,
    SurfaceCorrection correction,
  ) async {
    if (failSave) throw StateError('Synthetic write failure');
    return journal = SurfaceJournal(
      journal!.automatic,
      journal!.corrections.where((c) => !c.sameRange(correction)),
    );
  }
}
