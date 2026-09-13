# Pathgrain

Pathgrain is a privacy-first Flutter app for people who walk barefoot and want
to understand the surfaces they encounter. Personal walk history, ordered GPS
tracks, and point timestamps remain on the user's device.

## Current status

**MVP 0.1 is complete and accepted on Android for its defined scope.** The full
**Record → Analyze surfaces → Review → Correct → Save** loop builds on the
Prototype 0.0 recorder. Final integration acceptance included a newly recorded
physical Pixel walk with Home, screen lock/unlock, Stop/save, analysis,
correction persistence, re-analysis and Restore automatic.

**MVP 0.1-F — Barefoot surface taxonomy V1 is also complete and physically
spot-checked on a Pixel.** Its acceptance covered an in-place database upgrade,
the expanded taxonomy, saved journals and correction behavior. Automated
verification, the frozen Pixel dataset comparison and physical observations are
recorded separately in the development notes.

These milestones establish the documented Android MVP scope. Broader device
validation, production/Play Store readiness and iOS acceptance remain outside
that result.

**MVP 0.2-A adds local diagnostics and deterministic offline replay.** A later
Pixel walk (191 points / ~1.446 km) produced 80 unknown segments despite valid
recording and persistence. Reliable surface coverage is now the main technical
problem; this slice explains evidence loss before changing matching policy.
See the [current scope](docs/product/mvp-0.2-a.md) and
[replay/field guide](docs/development/mvp-0.2-a-surface-diagnostics-replay.md).

## What the app does

- Records walks with filtered GPS points and an Android location foreground
  service; stores route geometry, duration, distance and history in SQLite.
- Explicitly analyzes saved walks against locally cached or fetched
  OpenStreetMap evidence.
- Shows surface segments on a MapLibre route map and a distance breakdown that
  includes Unknown and reconciles with the saved distance.
- Persists automatic analysis separately from user corrections. Corrections
  survive restart and re-analysis; Restore automatic removes the override.
- Supports 15 barefoot surface categories, with English and Ukrainian labels.
- Provides a debug evidence inspector for raw OSM tags and matching results.

## Barefoot surface taxonomy

The accepted V1 categories are Asphalt, Tile, Cobblestone, Concrete, Ground,
Sand, Stone, Fine gravel / pebbles, Crushed stone, Grass, Artificial turf,
Rubber, Wood, Metal and Unknown.

Pathgrain maps raw OSM tags explicitly into these categories. For example,
`paving_stones` means Tile / Плитка, while `sett` means Cobblestone / Бруківка.
Generic `gravel` and unsupported values remain Unknown: unknown is preferable
to false precision. `compacted → ground` remains provisional.

Schema v3 preserves existing walks and journals during upgrade. Ambiguous
legacy `pavingStones`, `gravel` and `other` values become Unknown in both
automatic snapshots and corrections because their original meaning cannot be
recovered reliably. Migrated corrections retain precedence until changed or
restored. See the [F development note](docs/development/mvp-0.1-f-barefoot-surface-taxonomy.md)
for the complete mapping and migration rules.

## Local data and network access

Walks, saved analysis and corrections stay in local SQLite storage. Saved
analysis and corrections can be reopened without the OSM evidence cache or
new evidence requests.
There are no accounts, backend, cloud sync, analytics or community features.

The basemap uses OpenFreeMap, and explicit surface analysis can fetch OSM
evidence through a provisional Overpass provider. Evidence requests contain
fixed geographic cell bounding boxes, without an ordered track or point
timestamps. Map and evidence providers can still observe requested areas,
network addresses and request times. There are no offline tile packages;
provider choice and production hardening remain open.

## Development

Use a Flutter SDK satisfying the Dart constraint in [pubspec.yaml](pubspec.yaml)
(currently `^3.13.0`) and a configured Android toolchain. With an Android device
connected or an emulator running:

```sh
flutter pub get
flutter gen-l10n
flutter run
```

To run checks and build a debug APK:

```sh
flutter test --no-pub
flutter analyze --no-pub
flutter build apk --debug --no-pub
```

The offline developer harness accepts a fixed replay JSON file or read-only
captured SQLite databases:

```sh
dart tool/replay_surface.dart --help
```

Commands, report contracts and the private walk-8 test opt-in are in the
[diagnostic guide](docs/development/mvp-0.2-a-surface-diagnostics-replay.md).
`captures/` and local `diagnostics/` exports must remain untracked. Normal tests
use synthetic geometry; exact field replay is explicitly enabled locally.

APK output: `build/app/outputs/flutter-apk/app-debug.apk`. Physical recorder and
upgrade verification steps are recorded in the E and F notes below.

## Limitations and deferred work

OSM coverage and conservative matching can leave substantial distance Unknown.
Further matcher research and provider/performance hardening remain separate
work. Recording is not guaranteed through force-stop, process termination,
vendor battery killing or reboot.

Richer correction chooser UX, large-segment-list usability, map-based segment
selection and presentation grouping are deferred. Base surface is separate
from temporary condition: mud, ice and snow remain Unknown pending a future
condition/weather layer. Weather, hazards, backend/sync/community features and
route recommendations remain outside the implemented scope.

## Documentation

- [Agent and engineering rules](AGENTS.md) — privacy, engineering, Git, quality
  and scope rules.
- [MVP 0.2-A scope](docs/product/mvp-0.2-a.md) — current diagnostics/replay slice.
- [Current local pipeline and schema](docs/reference/surface-pipeline.md) —
  implemented recorder, SQLite, evidence, matcher and surface journal reference.
- [MVP 0.1 specification](docs/product/mvp-0.1.md) — accepted Android scope,
  acceptance history and deferred work.
- [Product vision](docs/product/vision.md) — long-term direction.
- [Product decisions](docs/product/decisions.md) — accepted product choices.
- [Prototype 0.0 Android walk recording](docs/development/android-walk-recording.md)
  — recorder foundation and its original verification boundary.

Development notes preserve the sequence of implementation and verification:

- [0.1-A — OSM map evidence](docs/development/mvp-0.1-a-osm-map-evidence.md)
- [0.1-B — Route surface matching](docs/development/mvp-0.1-b-route-surface-matching.md)
- [0.1-C — Surface segments and review](docs/development/mvp-0.1-c-surface-segments-review.md)
- [0.1-D — Surface corrections and persistence](docs/development/mvp-0.1-d-surface-corrections-persistence.md)
- [0.1-E — Final integration and acceptance](docs/development/mvp-0.1-e-final-integration-acceptance.md)
- [0.1-F — Barefoot surface taxonomy V1](docs/development/mvp-0.1-f-barefoot-surface-taxonomy.md)
- [0.2-A — Diagnostics, replay and field record](docs/development/mvp-0.2-a-surface-diagnostics-replay.md)
