# Prototype 0.0: Android walk recording foundation

Status at Prototype 0.0 completion: implemented foundation; physical-device
verification was still pending. Later Home/screen-lock acceptance is recorded in
[0.1-E](mvp-0.1-e-final-integration-acceptance.md#final-physical-pixel-acceptance).
This historical note does not override that completed Pixel acceptance. See the
[current recorder/schema reference](../reference/surface-pipeline.md).

This is the implementation note for Prototype 0.0, the deliberately small
Android-first recorder built for the original 10-minute walk vertical slice. It
documents the foundation that later milestones extend; it is not the current
milestone specification and is not a general background-location architecture.

The current milestone is defined in
[MVP 0.2-A](../product/mvp-0.2-a.md). The completed MVP 0.1 extended this recorder;
later work must preserve that foundation.

## What the foundation does during a walk

- The user starts recording while the Pathgrain activity is visible.
- geolocator subscribes to Android location updates with a foreground
  notification configuration. The plugin keeps a location foreground service
  active while the Dart stream subscription remains alive.
- Each point that passes the simple accuracy, displacement, and speed filter is
  inserted into SQLite before it is reflected in the live UI.
- Stopping the walk cancels location updates and recalculates distance from the
  ordered SQLite points. The route screen also loads its geometry from SQLite.
- If the process is gone before a normal stop, the next launch converts any
  recording row to interrupted and retains its already-written points.

The filtering values are intentionally centralized in
`lib/walks/location_recording_settings.dart` for adjustment after device tests.

## Permissions and Android behavior

The app requests precise foreground location when the user starts a walk. It
declares the location foreground-service permissions required by recent Android
versions. It deliberately does **not** declare `ACCESS_BACKGROUND_LOCATION`.

On Android 13 and newer, Pathgrain asks for `POST_NOTIFICATIONS` immediately
before starting the recording stream. Android's documented behavior is:

- denial does not prevent an app from starting a foreground service;
- the foreground-service notice is not shown in the notification drawer after
  denial, but Android still exposes the running app in Task Manager/Active apps.

Pathgrain therefore continues after denial and displays an in-app warning. The
walk row and every accepted point remain local and are not deleted because
notification permission was denied. See Android's
[notification permission documentation](https://developer.android.com/develop/ui/views/notifications/notification-permission#exemptions).

This implementation is intended to continue after Home and screen lock, but it
does not promise survival after force-stop, app process termination, device
vendor battery killing, or reboot. Those cases were outside Prototype 0.0.

At Prototype 0.0 completion, the repository did not record a completed
physical-device Home/screen-lock test. That original gap was closed for the
initial Android cycle by E's new Pixel walk, linked above. Simulators and
automated tests alone still cannot establish vendor/device background behavior;
later acceptance records must state what was actually observed.

## Basemap boundary

The route is a local MapLibre line made from SQLite points. The development
basemap URL is isolated in `lib/map/development_map_style.dart`. OpenFreeMap is
only a development convenience, not a production provider decision. Provider
terms, availability, privacy, and offline behavior must be evaluated separately
before production.

This note does not choose the geographic data source or matching approach for
MVP 0.1 surface analysis.
