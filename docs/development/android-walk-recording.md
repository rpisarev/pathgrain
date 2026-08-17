# Android walk recording: first vertical slice

This note describes the deliberately small Android implementation used for the
10-minute walk milestone. It is not a general background-location architecture.

## What runs during a walk

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
lib/walks/location_recording_settings.dart for adjustment after device tests.

## Permissions and Android behavior

The app requests precise foreground location when the user starts a walk. It
declares the location foreground-service permissions required by recent Android
versions. It deliberately does **not** declare ACCESS_BACKGROUND_LOCATION.

On Android 13 and newer, Pathgrain asks for POST_NOTIFICATIONS immediately
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
vendor battery killing, or reboot. Those cases are outside this milestone. The
actual Home/lock behavior still needs the physical-device test; a simulator and
automated tests cannot establish it.

## Basemap boundary

The route is a local MapLibre line made from SQLite points. The development
basemap URL is isolated in lib/map/development_map_style.dart.
OpenFreeMap is only a development convenience, not a production provider
decision. Provider terms, availability, privacy, and offline behavior must be
evaluated separately before production.
