# MVP 0.1-F — Barefoot surface taxonomy V1

Status: complete and physically spot-checked on a Pixel for its defined scope.

## Purpose and scope

This follow-up gives Pathgrain its own vocabulary for materials that feel
meaningfully different when walking barefoot. The clean starting point was
pushed `1986348` (`master` and remote `master` were checked before editing).
The completed MVP 0.1 Android acceptance in 0.1-E remains historical evidence;
it is not physical acceptance of this taxonomy upgrade.

The existing recorder, automatic snapshot + optional correction = effective
surface architecture, immutable original-edge ranges, explicit analysis and
local persistence remain intact. No packages, platform settings, GPS filters,
matcher scoring, thresholds, margins, geometry, crossing-node behavior,
continuity or route selection changed. This slice does not redesign segment
selection, merge presentation runs or reduce segment counts.

## Canonical taxonomy and complete supported OSM mapping

Raw OSM `surface=*` values and Pathgrain categories are separate layers:
**raw OSM tag → explicit Pathgrain mapping → barefoot canonical surface**.
Support is an allowlist, not an attempt to cover every OSM value. Unknown is
preferable to false precision.

The table below records the accepted Pathgrain barefoot taxonomy V1.

| Serialized canonical value | English | Ukrainian | Supported raw OSM values |
| --- | --- | --- | --- |
| `asphalt` | Asphalt | Асфальт | `asphalt`, `chipseal` |
| `tile` | Tile | Плитка | `paving_stones`, `bricks` |
| `cobblestone` | Cobblestone | Бруківка | `sett`, `cobblestone`, `unhewn_cobblestone` |
| `concrete` | Concrete | Бетон | `concrete`, `concrete:plates` |
| `ground` | Ground | Ґрунт | `ground`, `dirt`, `earth`, `soil`, `clay`, `compacted` |
| `sand` | Sand | Пісок | `sand` |
| `stone` | Stone | Камінь | `rock`, `stone`, `stepping_stones` |
| `fineGravel` | Fine gravel / pebbles | Галька / дрібний гравій | `fine_gravel`, `pebblestone` |
| `crushedStone` | Crushed stone | Щебінь | `crushed_stone` |
| `grass` | Grass | Трава | `grass` |
| `artificialTurf` | Artificial turf | Штучна трава | `artificial_turf` |
| `rubber` | Rubber | Гума | `rubber`, `tartan` |
| `wood` | Wood | Дерево | `wood` |
| `metal` | Metal | Метал | `metal`, `metal_grid` |
| `unknown` | Unknown | Невідомо | Unsupported, insufficient or conflicting evidence as described below |

The 29 supported raw values are trimmed and lowercased for lookup. Existing
raw evidence is retained verbatim. Assignments remain DIRECT only after a
supported geometric match. Existing scoped/conditional surface conflicts and
same-area grass-landcover conflicts still produce UNKNOWN. Semicolon mixtures
are not resolved, even when their individual values are supported.

Important distinctions:

- `paving_stones` now means **Tile / Плитка**, not Бруківка. Cobblestone is the
  more pronounced, uneven stone paving represented by `sett`, `cobblestone`
  and `unhewn_cobblestone`. Concrete plates remain Concrete.
- Fine gravel / pebbles represents relatively fine or rounded loose stone;
  crushed stone represents sharper broken aggregate. Generic `gravel` cannot
  distinguish them and is UNKNOWN.
- Artificial turf is separate from natural grass.
- **`compacted → ground` is an intentional, PROVISIONAL Pathgrain choice**.
  Barefoot field experience should revisit it.
- Only `concrete` and `concrete:plates` are supported concrete values.
  Other variants, including the previously unsupported `concrete:lanes`,
  remain UNKNOWN. No prefix-based concrete inference or additional variant
  mapping was introduced.

## Explicit UNKNOWN values and conditions

| Raw OSM value(s) | Pathgrain result | Boundary |
| --- | --- | --- |
| `gravel` | UNKNOWN | Fine/rounded gravel versus sharp crushed stone is not established |
| `paved`, `unpaved` | UNKNOWN | Too broad to select a barefoot material |
| `grass_paver` | UNKNOWN | No supported V1 mapping |
| `plastic`, `woodchips` | UNKNOWN | No supported V1 mapping |
| `mud`, `ice`, `snow` | UNKNOWN | Deferred condition modeling, not new V1 base surfaces |
| `acrylic`, `synthetic`, `carpet` | UNKNOWN | No supported V1 mapping |
| `shells`, `salt` | UNKNOWN | No supported V1 mapping |
| Every other unrecognized value, including empty values and typos | UNKNOWN | Never choose the nearest-sounding material or fall back to OTHER |

**Base surface != temporary condition.** This slice adds no wet asphalt,
muddy ground, icy pavement, snow-covered grass, temperature, puddles or
weather-derived state. Raw `mud`, `ice` and `snow` remain visible in existing
debug evidence where available.

An explicit unsupported value has `unsupportedSurface` provenance; a missing
`surface` tag retains `missingSurface` unless the existing narrow same-object
pedestrian-area grass-landcover inference applies. Unsupported explicit tags
never trigger that inference. Mixtures/scoped conflicts retain
`conflictingSurface`.

`other` and generic `gravel` are no longer canonical or selectable. Legacy
serialized names occur only in the migration and its fixtures. ICU's required
`other` localization fallback now says Unknown, not Other known material.

## Schema 2 → 3 and exact legacy conversions

The durable v2 schema stored canonical enum names, assignments/reasons and
endpoint OSM feature IDs for automatic segments. It stored only a canonical
label and original-edge range for a correction. Raw OSM tags, candidate objects
and the correction chooser's locale were not durably stored. Feature IDs alone
cannot recover an old material. Migration uses neither the disposable evidence
cache nor a provider.

The old chooser and automatic classifier were inspected separately:

| Legacy serialized value | Raw values collapsed by the old automatic classifier | Old chooser English / Ukrainian | Automatic v3 | Correction v3 |
| --- | --- | --- | --- | --- |
| `grass` | `grass`; also the narrow grass-landcover inference | Grass / Трава | `grass` | `grass` |
| `asphalt` | `asphalt` | Asphalt / Асфальт | `asphalt` | `asphalt` |
| `concrete` | `concrete`, `concrete:plates` | Concrete / Бетон | `concrete` | `concrete` |
| `ground` | `ground`, `dirt`, `earth`, `soil` | Soil / ground / Ґрунт / земля | `ground` | `ground` |
| `gravel` | `gravel`, `fine_gravel`, `pebblestone` | Gravel / Гравій | **`unknown`** | **`unknown`** |
| `pavingStones` | `paving_stones`, `sett` | Paving stones / Бруківка | **`unknown`** | **`unknown`** |
| `other` | `unhewn_cobblestone`, `cobblestone`, `wood`, `metal`, `sand`, `mud`, `rock`, `rubber` | Other known material / Інший відомий матеріал | **`unknown`** | **`unknown`** |
| `unknown` | All other/insufficient/conflicting evidence | Unknown surface / Невідоме покриття | `unknown` | `unknown` |

**Specificity is deliberately lost for legacy `gravel`, `pavingStones` and
`other`.** Automatic paving stones had combined Tile and Cobblestone inputs;
gravel had included the now-ambiguous generic tag; OTHER combined several
materials and mud. The correction labels were also insufficient, especially
the English/Ukrainian paving-stones discrepancy. Neither a correction's
underlying automatic value nor a present-day cache entry establishes what
the user meant.

`AppDatabase.schemaVersion` advances to **3**. sqflite's upgrade transaction
performs two narrow updates:

- Automatic rows with one of the three ambiguous names become
  `surface=unknown`, `assignment=unknown`,
  `surface_reason=legacySurfaceAmbiguous`. Their edge reasons, OSM endpoint
  keys, ordinals and ranges remain unchanged.
- Correction rows with those names change only `surface` to `unknown`.
  Their existence, ranges and correction precedence remain unchanged.

The five unambiguous names are unchanged, including existing UNKNOWN reasons
and grass inference provenance. Unrecognized corrupt names remain invalid;
migration is not a destructive repair mechanism. No table, index or trigger
is rebuilt. Walks, point IDs/order/coordinates/accuracy/timestamps, durations,
distances, completion states, journal identity markers and AUTOINCREMENT
state remain unchanged.

The v1 → v3 path first creates D's surface tables, then applies the empty
taxonomy migration. Fresh databases use schema 3 directly. Tests cover these
paths and a forced correction-update failure rolling back both automatic
changes and the schema version.

## Journal and correction compatibility

Migration preserves the automatic and correction layers independently. It
does not re-analyze, repartition ranges, recalculate saved walk totals, or
delete observations that now happen to equal the automatic UNKNOWN result.

An ambiguous old correction can therefore show **Unknown · Corrected**.
Re-analysis may recover automatic Tile from raw `paving_stones`, but that
UNKNOWN correction still takes precedence until the user chooses a new label
or selects Restore automatic. Old automatic `pavingStones` does not become
Tile merely by reopening the upgraded database.

The existing explicit-Save invariant is unchanged for every new category:
when the chosen value equals the current automatic value over the entire
range, Save removes/avoids a redundant correction. Equality must hold across
every automatic piece beneath that range. Re-analysis itself preserves
corrections, including newly equal values; Restore exposes the current
automatic result. Deletion retains the existing foreign-key cascades.

## Review, chooser, map and debug evidence

The existing enum-driven breakdown, overlay, review and simple dropdown chooser
now support all 15 canonical values, including Unknown. English and Ukrainian
labels are generated through the existing ARBs. No groups, search, favorites,
map picking, freehand editing, presentation-run merging or automatic grouping
were added.

The shared map/legend color switch has a deterministic distinct color for
every category. UNKNOWN retains red `#C62828`; the existing original-point
GeoJSON, white halo, corrected flag and MapLibre style remain. Every original
edge is counted once. New labels change category allocation, never saved
distance, geometry or the existing rounding/reconciliation rules.

In debug sample details, the selected object's existing raw tag is shown as
**OSM surface: gravel**, alongside **Pathgrain: UNKNOWN · Unknown**, for example.
A supported `sett` result displays Cobblestone. Missing tags use the existing
not-tagged label. Raw feature/candidate tags remain inspectable without new
requests. Normal Surface Review exposes no raw OSM internals.

## Verification

Verification on **2026-09-13**:

- `flutter gen-l10n`: succeeded for English/Ukrainian.
- `dart format`: changed/new Dart files formatted.
- Focused mapping, migration, persistence, summary, map and matcher tests passed;
  the final focused chooser/debug/correction UI run passed **28 tests**.
- Final full `flutter test --no-pub`: **309 tests passed**.
- `flutter analyze --no-pub`: **no issues found**.
- Tracked and new-file whitespace checks: clean.
- `flutter build apk --debug --no-pub`: **succeeded**.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`.

New coverage explicitly exercises all 29 supported raw values, the unsupported
set, normalization with verbatim raw-tag retention, missing versus unsupported
reasons, grass inference boundaries and unchanged candidate scores/selection.
Real v1 and frozen v2 fixtures cover migration; every canonical category is
saved, reopened, re-analyzed, restored and checked for automatic equality in
real SQLite. Summary/GeoJSON tests cover every category and original-edge
allocation. Localized widget tests exercise all chooser labels at mobile width,
review/provenance updates and raw-versus-canonical debug output.

Existing recorder, integration, crossing-node, parallel-road, pedestrian-rival,
heading, GPS-confidence, continuity, corruption and transaction regressions
remain green. The first focused run exposed a test-only dropdown API mistake
and scrolling/layout assumptions for offscreen options; these were corrected.
The analyzer's one test brace-style finding was also corrected. The rollback
test intentionally emits a synthetic SQLite migration error while asserting
that no partial upgrade survives; it is not a remaining test failure.

The existing Gradle Java native-access warning and MapLibre Kotlin Gradle
Plugin / future Built-in Kotlin migration warning remain; neither blocked the
build. The first build invocation was blocked by the environment's sandbox
helper; approved execution succeeded. No dependency or toolchain configuration
was changed.

Automated tests and the frozen comparison alone do not verify physical Android
background delivery or native map appearance. The subsequent F Pixel spot-check
is recorded separately below; E's successful new-walk acceptance remains
historical evidence.

## Frozen Pixel comparison

The existing ignored `local_datasets/pixel_2026-09-08/` dataset was available.
After focused tests passed, its databases were opened read-only without
migration or network access. Analysis used the same six required cached cells
and the repository's existing newest-cell/tie-order deduplication policy.
The baseline used the pure Dart source from pushed `1986348`; the after run
used the F code. Temporary inputs/results stayed outside the repository.
Hashes confirmed all dataset files, including journal sidecars, were unchanged.

For the **3,775.4 m** reference walk:

| Category | Before (m) | After (m) |
| --- | ---: | ---: |
| Asphalt | 404.654 | 404.654 |
| Concrete | 225.068 | 225.068 |
| Paving stones (legacy) | 781.567 | — |
| Tile | — | 781.567 |
| UNKNOWN | 2364.139 | 2364.139 |
| Total | 3775.429 | 3775.429 |

All changed labels came from raw `surface=paving_stones`. The **1,411.290 m**
classified distance is unchanged. All **546** sample matching results,
candidate scores/order, confidence and GPS assessments match the baseline.
Original-edge distances/GPS results, UNKNOWN reason totals and **171** segments
are unchanged. Totals reconcile with the original saved distance at the
existing floating-point tolerance. No surprising matching or coverage change
was found. This compares fresh interpretation of frozen evidence, not the
migration of an old canonical-only snapshot or correction, and is not a
surface-accuracy benchmark.

## Limitations and deferred work

The V1 taxonomy and mapping remain product choices, not surveyed ground truth.
Generic gravel and unsupported materials deliberately stay UNKNOWN.
`compacted → ground` needs field feedback. Lost legacy specificity cannot be
recovered without new evidence or a new user choice. OSM completeness,
conservative matcher coverage, provider availability/performance and native
map behavior retain A–E's limits. Colors and the larger dropdown are functional
MVP presentation, not a final visual system or mature correction UX.

Explicitly deferred:

- surface-condition/weather layer, including mud/ice/snow modeling;
- wet/icy/snow-covered surfaces, temperature, puddles and hazards;
- large-segment-list UX, presentation-run merging and segment count reduction;
- map-based correction selection and freehand corrections;
- smarter presentation grouping, correction search, favorites and richer chooser UX;
- broader matcher research or new heuristics, provider/performance hardening;
- backend, sync, community data and automatic taxonomy learning;
- broader production/device validation and iOS recording acceptance.

No uninterrupted recording promise is added for force-stop, process termination,
vendor battery killing or reboot. Existing interrupted recovery, storage-failure
and corrupt-user-data limits remain. No production or Play Store readiness is
claimed.

## Physical Pixel acceptance

The user reports that all planned 0.1-F Pixel checklist steps completed
successfully after installing the F debug APK over the existing application
without clearing app data. This physical spot-check followed the automated
verification and frozen-dataset comparison recorded above.

Verified on the physical Pixel:

- In-place schema v2 → v3 migration preserved existing walks and journal data;
  the existing saved walk opened normally.
- The expanded barefoot correction chooser and old/new surface presentation
  worked, including OSM `surface=paving_stones` → **Плитка / Tile**.
- The known reference walk showed approximately **782 m of Плитка**, while
  total route distance remained unchanged.
- Representative new categories could be selected as corrections; a correction
  to **Штучна трава / Artificial turf** correctly changed the effective breakdown.
- Correction persistence and restart/reopen worked. Explicit re-analysis
  preserved correction precedence.
- Restore automatic and redundant-correction removal worked. Total surface
  distance remained consistent.

This verifies the intended F upgrade and local correction flow on the Pixel.
It does not imply that every raw OSM mapping was physically encountered,
exhaustive production/device validation or iOS acceptance.

### Checklist used for the completed spot-check

The original handoff checklist is retained below.

Install the F debug APK **over the existing application without clearing data**.
Keep real tracks and coordinate-bearing artifacts out of repository files.
There is no requirement to physically find all 14 known material types.

1. Confirm existing walks, metadata and route geometry survive the upgrade.
2. Open old journals and corrections. Unambiguous labels should remain; legacy
   `pavingStones`, `gravel` and `other` should become Unknown, with correction
   ranges and Corrected provenance retained.
3. On an old walk that displayed Бруківка from `paving_stones`, expect the saved
   legacy automatic value to be Unknown immediately after migration.
4. Explicitly analyze/re-analyze supported known `paving_stones` evidence:
   automatic coverage should now say **Плитка / Tile**. A migrated UNKNOWN
   correction still overrides it until changed or restored.
5. If practical, inspect another available raw value such as `sett`,
   `pebblestone` or `metal_grid` and compare its canonical category.
6. Check every chooser label in English/Ukrainian, including Unknown and the
   absence of Other known material/generic Gravel.
7. Save at least Tile, Cobblestone, Fine gravel / pebbles, Crushed stone,
   Artificial turf and Metal on suitable ranges. Check review, colors,
   breakdown and Corrected provenance.
8. Restart the app and verify saved analysis/corrections. Re-analyze and verify
   the same corrected original-edge ranges remain authoritative.
9. Restore automatic. Also select the current automatic value over a uniform
   range and Save; it should leave no redundant correction.
10. Compare saved distance/duration and original geometry throughout. Surface
    totals must remain consistent apart from the documented display rounding.
11. Record and stop an ordinary new walk, including Home and screen lock/unlock,
    and reopen it as a recorder regression. Report actual F device behavior
    separately from the automated and frozen-data results.
