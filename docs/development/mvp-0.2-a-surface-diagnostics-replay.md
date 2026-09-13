# MVP 0.2-A — Surface diagnostics, replay and documentation reconciliation

Status: implemented after the completed MVP 0.1 baseline
`37e28cc43b97b34c3a46a0f28eac464e9cde4e7a` (tag `0.1`). The initial audit found
HEAD at that exact commit and a clean working tree. No matcher/classifier policy
change belongs to this slice. [Scope](../product/mvp-0.2-a.md) and
[current pipeline/schema reference](../reference/surface-pipeline.md) are separate
from the field and development record below.

## What walk 8 established

The supplied physical Pixel 8 capture contains a completed walk with **191
points, 190 original edges, 1,446.423 m and about 15m40s**. The main database is
schema 3. Before Surface Review/explicit analysis there was no automatic header
and no segment for this walk. Afterwards there was one header
(`point_count=191`, `points_valid=1`) and **80 segments**, all
`surface=unknown`, `assignment=unknown`. The original points did not change.

The offline production replay matches every persisted segment field, including
half-open ranges, both endpoint feature keys and both reasons. It already has
zero known meters before segmentation. Persistence, correction overlay and map
presentation preserve that result. `points_valid` is an integrity marker, not
a surface/GPS quality grade. Entering review and pressing Analyze are distinct
code actions; a before/after capture alone does not prove automatic analysis
on screen opening.

| Final reason | Segments | Original edges | Meters |
| --- | ---: | ---: | ---: |
| `ambiguousCandidates` | 29 | 64 | 494.303 |
| `weakScore` | 27 | 47 | 334.874 |
| `missingSurface` | 12 | 43 | 327.083 |
| `noCandidate` | 6 | 23 | 161.552 |
| `uncertainEndpoint` | 3 | 10 | 83.456 |
| `fastMotion` | 1 | 1 | 30.145 |
| `conflictingNeighbors` | 2 | 2 | 15.011 |
| **Total** | **80** | **190** | **1,446.423** |

These are mutually exclusive final reasons. They reflect edge gate precedence,
not an exhaustive count of every failed predicate or every missing tag.

The evidence cache grew from 10 to 11 cells. Only two cells are required by this
route; one already existed and one was newly fetched. Their 708 parsed feature
occurrences become 656 unique type/ID identities. All 52 overlapping IDs have
identical payloads. Repeated cells do **not** explain candidate ambiguity.
There are 84 distinct nearby features and 1,507 sample-candidate occurrences.
All samples have nearby geometry, even those with no eligible candidates.

The independently rechecked distinctions are:

- **Source sparsity:** 50 of 51 nearby footways have no `surface` tag. Every one
  of the 44 final weak-score sample leaders is untagged. Of 58 final sample
  selections, 57 lack material; object selection alone cannot fix this.
- **Matcher policy:** 30 of 55 ambiguous samples pass the ordinary margin gate
  (including the no-runner case) but fail an additional veto. The route's
  original-edge reasons therefore cannot be collapsed into missing tags.
- **Supported evidence rejected:** all eight nearby explicitly tagged features
  map through the F taxonomy. A paving-stones footway has only distance/direction
  rejections; a tagged pedestrian area has unsupported concave geometry. Six
  asphalt roads provide other supported tags, but proximity alone cannot prove
  the walker used a carriageway instead of nearby untagged footways.
- **Endpoint limitation:** one sample selects asphalt. Its two incident edges
  total 20.522 m and remain unknown because neighboring selections are
  unresolved. No edge has both endpoints selecting the same supported feature.
- **GPS limitations:** ten samples are nonstable; ten uncertain-endpoint edges
  and one fast-motion edge account for 113.601 m. The recorder's acceptance
  filter is less strict than analysis confidence. Saved points do not reveal
  every rejected device fix or establish the true path on the ground.

Representative retained diagnostics (sample indices are zero-based, without
coordinates or place names):

| Sample | Actual values | Interpretation |
| --- | --- | --- |
| 17 | Asphalt selection, score ≈76.188, margin ≈20.214 | Supported material reaches one sample but no final edge |
| 26 | Leader ≈1.589 m away, score ≈61.352, margin ≈30.962, heading unavailable | Minimum-score rejection despite proximity; leader also lacks material |
| 53 | Footway leader ≈94.039; runner ≈54.271; another footway ≈38.714 at ≈8.995 m has no direction | A low-ranked pedestrian veto survives a large ordinary margin |
| 98 | Footway scores ≈85.955 and ≈50.268; margin ≈35.687 | Parallel veto is independent of ordinary score margin |

Earlier forensic sensitivity experiments reported that lowering the minimum
score to 50 or removing only the parallel veto still recovered **zero known
meters**. The new baseline regression independently verifies the untagged
leaders and competing gates that explain why such relaxations are insufficient;
it does not ship alternative matching policies or encode relaxed outputs as
desired behavior. Removing more gates risks unsupported road/footway choices
and does not establish truth. This motivates diagnostics before calibration.

## Implementation and behavior boundary

`SurfaceReplay.run(SurfaceReplayInput)` calls `GeographicCell.covering`,
`EvidenceAssembly`, `RouteMatcher.analyze`, `SurfaceRules` through the matcher,
and `WalkSurfaceSummary`/`SurfaceSegmenter`. These are the production functions,
not a copied matcher. The cache-backed repository now uses the extracted pure
assembly too; newest-cell/type-ID deduplication and tie ordering are unchanged.

`RouteMatcher.analyze` accepts an optional `onAudit` callback. It records the
existing chooser's independent and contextual decisions, all relevant rival
identities and failing predicates. No callback is supplied by normal app UI;
verbose reports are built only by explicit replay. The trace records the chooser
before the existing GPS/evidence/conflicting-neighbor overrides; the final
`SampleAnalysis` records the actual resulting selection and material.

Minimum-score/no-candidate rejection still precedes ambiguity. Above that gate,
diagnostics enumerate failing predicates, even when the old short-circuit would
return at the first unsupported rival. Enumerating pure predicates changes no
selection. The unsupported-rival veto still has priority; neither the ordinary
margin nor the two ambiguity exceptions changed.

`SurfaceDiagnostics` exposes typed `SampleDiagnostic`, `EdgeDiagnostic`,
`DiagnosticMeasure` and `SurfaceDiagnosticAggregate` models. Meters use the
production haversine utility over original edges. Reports hold candidate IDs and
scores once per sample, with edge references to both samples and a shared feature
tag dictionary. They do not expand the normal walk schema or persist automatically.

`tool/capture_input.dart` is a development adapter. A small Python standard-library
helper reads SQLite using `mode=ro&immutable=1`; it refuses a nonempty WAL/journal
instead of silently reading an inconsistent capture. Dart selects required cells
before requesting their JSON. Only the requested walk and its required cells are
loaded, with no live provider, network fallback, raw log parsing or database writes.

No dependency, Android configuration, GPS filter, threshold, scoring weight,
confidence rule, geometry support, taxonomy mapping, segment merge key, persistence
rule or product UI changed. Recorder-rejected fixes cannot be reconstructed from
this input. Replay diagnoses the automatic layer; persisted-equivalent rows can
be compared, but user corrections are not folded into matcher metrics.

## Running a replay

From the repository root, use the Dart SDK bundled with the configured Flutter
SDK. `flutter pub get` is needed once for package resolution; replay itself has
no Flutter engine or Overpass dependency. Direct `dart tool/...` invocation
avoids unrelated native package build hooks from `dart run`. Python 3 is needed only for SQLite
capture input, not for a saved replay JSON file.

```sh
dart tool/replay_surface.dart --help

dart tool/replay_surface.dart \
  --walk-db /path/to/extracted/databases/pathgrain.sqlite \
  --cache-db /path/to/extracted/databases/pathgrain_osm_evidence_cache.sqlite \
  --walk-id 8 \
  --output /tmp/pathgrain-walk8-report.json \
  --save-input /tmp/pathgrain-walk8-input.json \
  --revision 37e28cc-plus-local-0.2-A

dart tool/replay_surface.dart \
  --input /tmp/pathgrain-walk8-input.json \
  --output /tmp/pathgrain-walk8-repeated.json \
  --revision 37e28cc-plus-local-0.2-A
```

Output directories must exist; output paths must be distinct new files.
`--save-input` is optional. Supply `--namespace` if the cache contains multiple
provider/query namespaces. Missing required cells remain missing: replay exports
an incomplete all-unknown analysis rather than fetching anything. The CLI also
prints the aggregate JSON to stdout. Use a truthful revision/dirty-state label
when comparing implementations; a missing label is serialized as null.

For another field walk, preserve a consistent post-analysis main DB and cache
snapshot locally, run the command with that walk ID, and compare final reasons,
overlapping evidence observations, candidate scores/gates and persisted segments.
Retain pre-analysis snapshots when investigating cache acquisition or first-save
behavior. Exporting diagnostics is an explicit developer action, not a new app
feature or telemetry stream.

## JSON contracts and accounting

Both schemas currently use integer `schemaVersion: 1`. Consumers must check the
schema name/version. Output also identifies `policyVersion: mvp-0.1-37e28cc` and
an optional caller-provided `implementationRevision`. A later policy change must
update the policy identifier; breaking export changes require a schema increment.
Elapsed route times and evidence fetch times retain microseconds, so exporting
cannot change GPS speeds or collapse distinct cache times into a tie. Canonical
serialization sorts object keys, preserves ordered arrays and retains
unrounded doubles. Null represents an unavailable numeric value or absent runner;
it never means zero. Reports contain no generated-at clock value, so identical
input and revision labels produce byte-identical JSON.

| Contract | Contents |
| --- | --- |
| `pathgrain.surface-replay-input` | `namespace`; ordered `points` with integer `sequence`, finite `latitude`/`longitude`/`accuracyMeters`, and integer `elapsedMicroseconds` relative to the first point; `cells` with `key`, integer `fetchedAtMicroseconds`, raw OSM `evidence` object |
| `pathgrain.surface-diagnostics` | Schema/policy/revision, metric `definitions`, settings, point/segment counts, `evidence`, `features`, `samples`, `edges`, persisted-equivalent `segments`, and `aggregate` |
| Sample row | Index/sequence, accuracy/GPS state and reasons, route heading/radius, counts, ranked candidates, independent/contextual choices, anchor IDs, final selected ID/confidence/reason/surface |
| Candidate row | Feature key, distance, relative direction, eligibility and reason, independent/total score, five score components; type/highway/material-related raw tags and mapped assessment in `features[key]` |
| Choice row | Leader ID/score, runner score, nullable margin, selected/supported IDs, ambiguity-evaluated flag, failed gates and parallel/unsupported rival IDs |
| Edge row | Index, endpoint sample indices, original meters, elapsed microseconds, speed/GPS reason, final reason/surface/provenance, overlapping flags and common supported candidate IDs |
| Aggregate | `total`/`known`/`unknown`, `byFinalReason`, overlapping `observations`, candidate eligibility occurrence counts, contextual/independent score and margin distributions, including by final sample reason |

Every measure is `{edges: integer, meters: double}`. Final reasons partition all
edges/meters exactly up to floating-point summation; observations are overlapping
and **must not be added together**. For example, a missing-surface selection at
one endpoint can coexist with failed matching at the other. A primary
`noCandidate` count is not the same as all edges touching an ineligible endpoint.
Sample-score summaries are sample counts, not distance-weighted scores; missing
values are counted separately, and p50/p90 use nearest-rank quantiles.

“Supported” in these diagnostics means the existing surface derivation returns
a non-unknown assignment, including its narrow grass-area inference. Calling it
on rejected candidates measures potential tag interpretation; it does not assign
that material to the route. Material-related/access tags are exported; names and
unrelated tags are omitted from the report. The optional replay input retains raw
required-cell responses because node membership and unsupported competitors can
affect matching even when they cannot be selected.

Two explicit evidence ceilings complement final known meters:

- `supportedAtBothEndpoints`: the **same** supported feature occurs in both
  endpoint candidate lists under the 40 m geometry envelope. This broad bound
  includes ineligible/unsupported geometry and ignores GPS, score, vetoes,
  continuity and interior probes. It is deliberately optimistic.
- `supportedEligibleAtBothEndpoints`: the same supported feature is also
  eligible at both endpoints. This tighter ceiling still ignores GPS,
  chooser policy and interior probes; it is not attainable/verified coverage.

Other observations separate no nearby geometry from no eligible geometry,
matching rejection, selected missing/unsupported material, supported candidates
not selected, actual supported endpoint selections, and final edge losses after
one or two supported selections. `noSupportedEvidenceInCandidateEnvelope` means
neither endpoint has a supported mapped candidate; it describes source scarcity
only within the captured envelope and current material rules. None proves what
material exists on the ground. Always read `evidence.complete` alongside them.

Walk-8 examples from the maintained report:

| Observation (overlapping) | Edges | Meters |
| --- | ---: | ---: |
| No nearby candidate at either endpoint | 0 | 0 |
| At least one endpoint has no eligible candidate | 29 | 199.153 |
| At least one endpoint fails matching | 121 | 912.228 |
| At least one selected endpoint lacks material | 71 | 541.921 |
| Supported nearby feature not selected at an endpoint | 160 | 1,203.968 |
| Same supported feature in both candidate lists | 154 | 1,157.440 |
| Same supported eligible feature at both endpoints | 38 | 288.784 |
| At least one supported endpoint actually selected | 2 | 20.522 |
| Same supported feature selected at both endpoints | 0 | 0 |
| Neither endpoint has a supported mapped candidate | 30 | 242.456 |

The wide difference between the two ceilings is itself diagnostic: nearby
material tags are much more common than eligible evidence. The eligible ceiling
is about 19.97% of the walk, not a promise of a 19.97% recoverable surface result.

## Regression and privacy

`captures/` remains untracked; repository `.gitignore` explicitly excludes it
and local `diagnostics/` exports. The original 50 capture files were hashed before
work and checked for changes after validation. No raw GPS coordinates, geometry,
logs, screenshots, DB dumps or historical walks were added to tracked fixtures.
The private capture's SQLite files are read in place without modification.

Normal tests use fabricated meter-grid routes near the existing test origin,
with invented IDs and geometry. These preserve diagnostic failure classes:
untagged footway versus asphalt road, large-margin pedestrian veto, weak score
without heading, direction-rejected paving footway, concave tagged pedestrian
area and interior edge-probe rejection. They do not claim to reproduce the
entire real route's 80 segments.

Exact reproduction is a separate explicit opt-in test:

```sh
PATHGRAIN_WALK8_CAPTURE=captures/walk-20260913-131600 \
  flutter test --no-pub test/walk8_field_replay_test.dart

flutter test --no-pub test/surface_replay_test.dart \
  test/surface_diagnostic_report_test.dart

python3 -m unittest tool/test_read_surface_capture.py
```

Without the environment variable the field test reports a skip, not a simulated
pass. With it, the test verifies 191 points, all 80 persisted-equivalent rows,
all-unknown assignments, reason/meter accounting, deduplication, the eight mapped
features, untagged-footway sparsity, tagged geometry rejection, veto/margin
distinction, the lone asphalt selection and deterministic JSON roundtrip.

Privacy tradeoff: exact local replay necessarily uses the real location already
in the user's private capture. Translating a full route could retain an identifying
shape and perturb projection, headings, cell boundaries and threshold ties, so it
was not presented as anonymization. There is **no real geographic fixture in Git**.
Exported input still encodes an exact geographic location even with recording
times removed. Reports also remain location-sensitive because OSM IDs/cell keys
identify places. Keep both local; they are not automatically shareable artifacts.

## Documentation audit and roles

The audit inventoried active Markdown, the ignored legacy agent backup and the
iOS asset README, then compared status/schema/taxonomy/lifecycle descriptions to
`AppDatabase`, repositories, recorder, evidence provider/cache, matcher, rules,
segmenter, journal, UI and tests. Existing build instructions match `pubspec.yaml`
(Dart ^3.13.0), Gradle's `com.pathgrain.pathgrain` application ID and current APK
output. No dependency/toolchain migration was needed.

| Document | Role and reconciliation |
| --- | --- |
| `README.md` | Current project overview; retained accurate Android/F acceptance, added 0.2-A and the coverage problem plus canonical reference/guide links |
| `AGENTS.md` | Current engineering/privacy rules; replaced stale “current target 0.1” and progress pointers, preserved recorder foundation and scope limits |
| `docs/product/mvp-0.1.md` | Completed milestone specification/acceptance; linked current scope and clarified implemented provider/cache choices versus future reevaluation |
| `docs/product/mvp-0.2-a.md` | New current milestone scope/status and proposed next decision boundary |
| `docs/product/vision.md` | Future direction; changed only current-scope pointer |
| `docs/product/decisions.md` | Accepted decisions; changed scope pointer, preserved D001–D010 |
| `docs/reference/surface-pipeline.md` | New current architecture/schema/behavior reference linked to implementation and F's complete mapping |
| `docs/development/android-walk-recording.md` | Historical foundation; made original pending physical verification explicitly historical and linked E's completed Home/lock evidence |
| `docs/development/mvp-0.1-a-osm-map-evidence.md` | Historical A implementation/provider review; later-status note resolves old deferred matching/segmentation/persistence claims |
| `docs/development/mvp-0.1-b-route-surface-matching.md` | Historical experiment/field fixes; later-status note points to current pipeline and F instead of treating its old taxonomy as current |
| `docs/development/mvp-0.1-c-surface-segments-review.md` | Historical read-only/in-memory slice; later-status note points to durable D journal/corrections and F schema/taxonomy |
| `docs/development/mvp-0.1-d-surface-corrections-persistence.md` | Historical schema-2 implementation/Pixel spot-check; later-status note points to schema 3 and completed E/F acceptance |
| `docs/development/mvp-0.1-e-final-integration-acceptance.md` | Historical final acceptance; retained new-walk evidence and schema-2-at-E record, linked F and current reference |
| `docs/development/mvp-0.1-f-barefoot-surface-taxonomy.md` | Current mapping/migration reference plus historical implementation/acceptance; retained all 15 categories/29 raw mappings and linked subsequent field diagnostics |
| This note | Current replay usage/schema contract plus field, audit and 0.2-A validation record |
| Ignored `AGENTS_old.md` | Local historical backup, not active contributor guidance; conflicts such as old social scope are superseded by `AGENTS.md`; left untracked and untouched |
| iOS launch-image asset `README.md` | Template-specific asset replacement instructions; not a project status/acceptance source; unchanged |

Historical test counts, provider reviews and original handoff checklists were
not rewritten to imply later behavior existed at earlier completion. The old
eight-category/schema-2 descriptions remain explicitly historical, with a clear
path to the current source of truth.

## Validation and next slice

Verified on 2026-09-13:

- Formatter check: all 13 changed/new Dart files unchanged by `dart format`.
- `flutter analyze --no-pub`: no issues. New import/style lints found during
  implementation were corrected; no analyzer warning remains.
- Existing matcher/parallel/crossing/evidence targeted suite: 64 tests passed.
- Final replay/report plus durable SQLite persistence targets: 73 tests passed.
- Python read-only capture adapter: all 3 synthetic tests passed.
- Full Flutter suite, private field test enabled, with `--concurrency=1`:
  **328 tests passed**, including all original matcher/taxonomy/segment/journal
  coverage and 19 new Dart tests. No timeout limit or assertion was weakened.
- Direct Dart capture replay and saved-input replay produced byte-identical
  version-1 reports. A separate baseline comparison checked all **1,507**
  candidate records (scores/components/order/eligibility/mapped tags), **190**
  edges and **80** persisted-equivalent rows exactly.
- Debug Android APK built at `build/app/outputs/flutter-apk/app-debug.apk`.
  The existing Gradle Java native-access and MapLibre Kotlin-plugin migration
  warnings also appear in the A/F historical build records; they are not new
  diagnostics failures. No package/platform change was made to hide them.
- Capture hashes: all 50 original files unchanged; no `captures/` file tracked.
  Local Markdown links/anchors and Git whitespace checks passed.

Two default-worker full-suite reruns failed during a busy host session, one
alongside the Android build. The retained expanded output identifies a
30-second timeout in the existing `walk_surface_persistence_test.dart`
`CanonicalSurface.artificialTurf` reopen/correction test, followed by a
database-closed cleanup error. That test and its SQLite implementation are
unchanged. The same complete persistence target passed in the 73-test run and
the full single-worker run passed in about 38 seconds. This records a host/test
timing limitation, not proof of its underlying cause or a matcher defect. Use
one worker on a busy development host; no product/test policy change is included.

To repeat the complete local validation with the private field case:

```sh
PATHGRAIN_WALK8_CAPTURE=captures/walk-20260913-131600 \
  flutter test --no-pub --concurrency=1
flutter analyze --no-pub
python3 -m unittest tool/test_read_surface_capture.py
flutter build apk --debug --no-pub
```

These checks establish deterministic behavior and observability; they do not
prove matching quality or constitute new physical acceptance. No commit or push
is part of this work.

Recommended next work is a bounded multi-walk evaluation with observed surface
labels and these fixed inputs. Separately evaluate complete simple concave areas,
low-ranked pedestrian rivals, heading loss during ordinary GPS motion and useful
versus unavailable material. Compare incorrect assignments and stable unknowns
as well as known meters. Keep missing-material improvements distinct from object
matching improvements. Do not infer material from highway class or propagate the
lone asphalt sample through unresolved neighbors to make this test look better.
