# MVP 0.1-A — OSM map evidence

> **Later-status / document role**
>
> Historical completion note (0.1-A). Later status: B added matching, C added
> segments/review, D added durable snapshots/corrections, E completed the new-walk
> Android acceptance, and F expanded taxonomy/schema. The deferred features below
> describe A's boundary; analysis after Stop is still intentionally not automatic.
> The provisional provider/cache now also serve explicit normal Surface Review.
> See the [current pipeline](../reference/surface-pipeline.md) and
> [0.2-A replay guide](mvp-0.2-a-surface-diagnostics-replay.md).

Status: implemented for development inspection. Focused physical Pixel testing
of saved-walk analysis is recorded in the subsequent
[0.1-B matching experiment](mvp-0.1-b-route-surface-matching.md). That investigation
does not establish comprehensive native-map/cache or Home/screen-lock
verification. The full MVP 0.1 loop was not complete at 0.1-A.

This development slice makes OSM evidence observable around an already saved
walk. On its own, 0.1-A does not match a walk to an OSM object or assign a surface;
0.1-B extends the same diagnostic view with local experimental analysis.
Prototype 0.0 recording, filtering, foreground location service, walk SQLite schema,
history, and ordinary MapLibre route review remain the foundation.

## Flow and boundaries

The saved-walk overflow menu exposes **Surface evidence** only in debug builds.
A localized notice explains the network access; **Open development view** opens
a separate diagnostic screen. Opening normal walk details or stopping a walk
does not start Overpass requests. The diagnostic screen also refuses to load
data in profile/release builds.

`WalkRepository.pointsForWalk` reads accepted points locally. `GeographicCell`
derives a unique cell set. `EvidenceRepository` reads the separate cache first,
then calls `OsmEvidenceProvider.fetchCell` for missing cells, sequentially.
`OverpassEvidenceProvider` builds HTTP requests and parses responses;
`EvidenceMap` builds local GeoJSON layers. The inspector reads the raw OSM model
and original `WalkPoint.accuracyMeters`. No evidence component can write walks.

There are no new packages. HTTP uses Dart `HttpClient`; cache storage reuses
sqflite. The pure cell/model/query/GeoJSON logic is separate from widgets.

## Provisional development provider

Reviewed on 2026-09-06 against the current
[OSM public Overpass instance guidance](https://wiki.openstreetmap.org/wiki/Overpass_API#Public_Overpass_API_instances)
and [Overpass QL reference](https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL).
The endpoint is `https://overpass-api.de/api/interpreter`, isolated in
`lib/map/evidence/evidence_settings.dart` and injectable at the provider boundary.
This is a **development-only field-test choice**, not the final MVP or production
provider decision. No Pathgrain backend is introduced.

Current instance guidance asks apps to identify themselves, cache and limit
calls, and avoid parallel scripts. It distinguishes occasional use from regular
use: its regular-use guidance is fewer than 100 queries and 10 MB per day,
counted across an app's users. Public capacity is shared and unreliable; this
experiment is for small manual trials, not deployment to an app audience. These
aggregate daily limits are not enforced by this client. Monitor the displayed
cell counts, reuse cache, and keep trials small; manual refresh consumes the
same public capacity as a first fetch.

Requests identify the application with the static header:

```text
User-Agent: Pathgrain/0.1-A (development OSM evidence)
Accept: application/json
Content-Type: application/x-www-form-urlencoded; charset=utf-8
```

The shared development provider serializes callers, waits one second after a
completed request before the next, and never retries automatically. Each query
declares 25 seconds and 16 MiB of server working memory. Client IO has a
45-second deadline and a 2 MiB decoded response-body limit. Deadline expiration
closes the actual HTTP client, and redirects are disabled.

Any provider failure stops that inspection's network batch, while all previously
read cached cells remain available. HTTP 429/406 are reported as throttling;
timeouts, network-unreachable errors, invalid/partial responses, oversized
responses, and server failures have separate messages. The shared provider
enforces at least a 30-second cooldown after failure, honoring a longer
`Retry-After` (seconds or HTTP date). Refresh during cooldown makes no HTTP call.
The cooldown survives closing/reopening the screen, but not process restart.
Do not restart the app to bypass provider throttling.

## Fixed-cell request and privacy model

Experimental constants are centralized in `EvidenceSettings`:

- Web Mercator zoom **15** (cell identity `z/x/y`).
- **30 meters** of geographic padding per cell edge.
- Query/cache version **highways-raw-geometry-v1**.

Only cells occupied by saved samples are selected: there is no interpolation,
resampling, route corridor, or request based on GPS accuracy. Cells are
deduplicated and sorted by numeric zoom, x, then y, independently of visit order.
Latitude is clamped to the Web Mercator limit for tile calculation. Padding uses
a spherical meter conversion based only on the cell bounds, with conservative
longitude padding at the cell's highest absolute latitude. Dateline padding is
split into two canonical bounding boxes inside the same cell query.

Each HTTPS POST body has only a form-encoded `data` field containing static QL
and padded cell bounding boxes. Ordinary HTTP/TLS connection metadata and the
static application identity are also visible to the provider. The client sends
no ordered point list, per-point timestamps, walk ID, start/end time, route
GeoJSON/polyline, accuracy values, analytics ID, account ID, or user identifier.
The provider interface accepts a cell rather than any walk data. GPS/OSM
coordinates, requests, response bodies, and exception details are not logged.

A remote OSM provider can still learn the approximate geographic cells
requested and the request time. Fixed-cell requests reduce detail but do not
make remote map access anonymous. The provider also sees the network address;
the set of requested cells can suggest an approximate route area. Cache hits
avoid new evidence requests, but do not anonymize prior requests or basemap use.

## OSM query, model, and rendering

For each padded bounding box, the union requests `nwr["highway"]`,
`way["area:highway"]`, and `rel["area:highway"]`, followed by `out body geom;`.
No `surface` or access filter is applied. Footways, separate sidewalks, paths,
steps, node/way crossings, pedestrian ways/areas, service/residential roads,
and other tagged highways are included. No matching, surface interpretation,
sidewalk inference, or surface-based styling occurs.

The domain model retains OSM type + ID, complete string tags, geometry pieces,
area semantics, and explicit geometry limitations. The complete response is
cached, including generator/base-data timestamp, member IDs/roles, unsupported
elements, and raw values such as `surface=paving_stones`. A missing surface is
shown as **not tagged** (localized), not synthesized from nearby features.

Supported presentation:

- Nodes as points; ordinary ways as lines.
- Complete closed ways explicitly tagged `area=yes` or `area:highway` as filled
  areas. `area=no` overrides area semantics. A closed road is not automatically
  an area.
- Relation member ways as separate outlines and member nodes as points. Parent
  tags and member type/ID/role remain inspectable. Relations are always marked
  as outlines only: outer/inner rings are not assembled or filled, and nested
  relations are not resolved.
- Missing way coordinates split geometry into contiguous pieces; gaps are
  never bridged. Objects without renderable geometry remain in the inspector.
  Unrecognized element types stay in the cached raw response and are counted.

The blue/white GPS line uses exactly the stored point sequence; sample markers
are separate from OSM green paths, orange roads, teal areas, and purple relation
outlines. A map tap queries nearby rendered features and offers all returned
OSM objects/GPS samples, without ranking or choosing a walked-on object.
**Inspect data** also opens a scrollable inspector for all loaded objects and
GPS samples, independent of map availability.

**GPS accuracy circles** toggles 48-vertex spherical polygons with radius equal
to each accepted sample's saved reported accuracy in meters. These are
approximate visualizations, not certainty boundaries or matcher thresholds.
The small fixed-size sample dots are location markers, not accuracy radii.

Known geographic/rendering limits: Overpass bbox selection can miss ways with
no node inside the padded box, including very large enclosing areas. Returned
geometry can extend outside the cell; it is not clipped. Complex relation
topology, malformed/self-intersecting polygons, general GIS validation, and
arbitrary derived OSM geometry are unsupported. Polar routes beyond the Web
Mercator limit are not faithfully covered. Camera fitting for walks spanning
the antimeridian can zoom out too far. Very large walks/dense cells can be slow
or exceed the response limit; this is not a production GIS renderer.

## Disposable local cache

`pathgrain_osm_evidence_cache.sqlite` is separate from `pathgrain.sqlite`.
Entries are keyed by endpoint + query version + zoom + padding + cell identity,
with their fetch time and complete JSON response. There are no walk IDs or
foreign keys. The walk schema/migration remains unchanged.

All successful cells, including empty results, are reused indefinitely until
manual refresh; the oldest available fetch time and cached/fetched counts are
displayed. Refresh requests every required cell again, replacing a cell only
after successful complete parsing. HTTP-200 Overpass `remark` responses are
treated as incomplete and never overwrite cache. A failed fetch never deletes
old evidence. Cache read/write failure is reported without discarding successful
in-memory results. Leaving the screen stops subsequent cell requests; an
in-flight cell may finish and cache before its connection closes.

Overlapping cells are deduplicated by OSM type + ID for display. The newest
fetched cell wins if versions disagree; canonical cell order breaks timestamp
ties. The displayed evidence is a mixture of cell snapshots, not a synchronized
OSM dataset. No automatic eviction or cache-management interface is included.
The cache is disposable and must never be treated as the authoritative walk.

## Basemap and attribution

The visual basemap remains the existing **OpenFreeMap** Liberty style configured
in `DevelopmentMapStyle`; the raw evidence overlay comes from **overpass-api.de**.
Both choices are provisional and independent. Basemap viewport/style/tile
requests disclose approximate viewed areas separately from evidence requests.
The GPS route and overlay GeoJSON are local MapLibre sources, not uploaded data.

The diagnostic screen visibly credits OpenStreetMap contributors, names ODbL,
and shows the selectable copyright URL, following
[OSM attribution guidance](https://www.openstreetmap.org/copyright). Existing
MapLibre basemap attribution remains enabled.

If map initialization fails or takes over 20 seconds, **Use plain map** creates
a local background style without basemap network access and adds the same local
layers. This is a diagnostic fallback, not an offline tile system. The inspector
remains available even if the native map fails. Broader native drawing,
tapping, style and Android performance coverage is not established by the
focused 0.1-B matching field work.

## Android field-test procedure

1. Run/install a debug build (`flutter run --debug` or the debug APK). Record a
   normal walk through a mix of sidewalk, path, road crossing, and square/park.
   Include Home and screen-lock intervals to regression-test Prototype 0.0.
2. Stop, return to history, and open the saved walk. Verify its ordinary route,
   duration, distance, and point count before opening any evidence view.
3. Open the overflow menu → **Surface evidence** → **Open development view**
   (Ukrainian: **Дані OSM про покриття** → **Відкрити тестовий перегляд**).
   Observe cached/fetched/available cell counts and loading/error status.
4. Compare the blue GPS track and samples with nearby OSM lines/areas. Tap
   overlapping features, expand their inspector entries, and inspect `highway`,
   `surface`, `footway`, crossing, and sidewalk tags. Check a missing `surface`
   stays visibly absent. Inspect relation warnings where present.
5. Tap a GPS sample to read its accuracy; toggle **GPS accuracy circles** and
   zoom to confirm geographic radius stays consistent. Try **Inspect data**.
6. Leave/reopen the view; confirm cached cells are reused with zero new fetches.
   Record a second short walk in the same cells and check reuse across walks.
7. Disable connectivity and reopen: cached evidence must remain available.
   If needed, wait for the map warning and choose **Use plain map**. Request a
   manual refresh and check the partial/offline message and retained evidence.
   Re-enable connectivity, wait out any cooldown, then refresh once.
8. Reopen normal walk details and verify the saved route/statistics are intact.
   Record actual observations, especially Home/screen-lock recording, native
   tapping, overlapping features, readability, accuracy-circle behavior, and
   cache reuse. Automated checks do not establish those physical behaviors.

## Verification and deferred work

Deterministic fixture/fake tests cover tile conversion, canonical ordering,
padding, request content, raw parsing, geometry limitations, type/ID dedup,
cache/reopen/refresh, sequential transport/cooldown, partial/offline failure,
meter-radius polygons, localization, and inspector interaction. Tests do not
contact the public Overpass service or fetch live basemap tiles. UI tests use a
substitute for the native map; they do not establish native rendering behavior.

Run `dart format` on changed Dart files, `flutter analyze`, `flutter test`, and
`flutter build apk --debug`. Report command outcomes and physical observations
separately. The existing recorder/database tests must continue to pass.

Initial 0.1-A verification on 2026-09-07: localization generation succeeded;
changed Dart files were formatted (including a clean generated-localization
format check); `flutter analyze` reported no issues; all **44** tests passed,
including the existing recorder/database tests; and `flutter build apk --debug`
succeeded.
The APK is at `build/app/outputs/flutter-apk/app-debug.apk`. The Android build
reported Gradle's Java native-access warning and a warning that `maplibre_gl`
still applies Kotlin Gradle Plugin and needs future Built-in Kotlin migration.
No physical device test or live Overpass query was performed during that
implementation verification. Subsequent physical Pixel testing used saved walks
in the 0.1-B view to investigate GPS deviations and parallel footway/road matching.
Those focused observations are recorded in the 0.1-B note; they do not establish
that every native-map/cache scenario in the procedure above has passed.

The subsequent [0.1-B experiment](mvp-0.1-b-route-surface-matching.md) adds local
candidate/direction/continuity scoring, GPS confidence, DIRECT/INFERRED/UNKNOWN
assignment and a provisional canonical taxonomy in this diagnostic view.
Final segmentation, surface distance breakdown, user corrections, derived-data
persistence and automatic analysis after Stop remain deferred.
Backend, community, synchronization, and production map infrastructure are
outside this slice. The full MVP 0.1 loop is not complete merely because this
diagnostic evidence view exists.
