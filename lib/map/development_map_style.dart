/// Development-only basemap configuration for the initial vertical slice.
///
/// OpenFreeMap is not a production provider decision. Replace this single
/// value after tile licensing, availability, privacy, and offline requirements
/// have been evaluated. The saved GPS route is rendered as a local MapLibre
/// layer; only ordinary style/tile requests go to this endpoint.
abstract final class DevelopmentMapStyle {
  static const String styleUrl = 'https://tiles.openfreemap.org/styles/liberty';
}
