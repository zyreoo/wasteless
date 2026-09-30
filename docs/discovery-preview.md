# Wasteless discovery experience

Romanian discovery UI inspired by Foodsi's public surplus-food journey, with Wasteless branding and locally bundled illustrative photography.

## Pages

`/explore` and `/search` provide merchant search, category filters and favorites. `/map` provides an interactive OpenStreetMap with price markers, zoom and merchant selection. `/merchant` displays details (opened with an ID argument). `/settings` persists city, reduced motion and demo visibility on this device. `/business` provides a local profile draft; `/help` and `/about` provide Romanian product information.

Discovery is accessible from login without an account. Production cart, orders and purchases retain authentication requirements.

## Demo boundary

The four merchants, locations, pickup windows and prices are illustrative, labelled and cannot be purchased. No database records are created. The real catalog continues using the existing API. There is no production merchant onboarding endpoint; the business form saves only a local draft and explicitly says so.

Bucharest is the default, with Cluj-Napoca selectable. This does not request GPS location. Favorites and settings are device-local, not account-synced.

## Maps

Uses the standard HTTPS OpenStreetMap tile endpoint with visible clickable attribution, browser caching/referer and no bulk prefetch. CSP permits the tile origin. `MAP_TILE_URL` can override the template at Flutter build time; another provider requires matching CSP and attribution changes. Traffic must comply with the selected provider's usage policy.

## Verification

Run `flutter analyze` and `flutter test` in the frontend directory. Tests cover discovery filters, absence of demo checkout, persistent preferences and information layouts at 320, 768 and 1440 pixels. Manual browser checks cover desktop split map/list, mobile map/list switching and marker-to-detail navigation.

The Docker build runs `dart run tool/version_web_assets.dart` after compilation. This versions the Flutter asset base so previously cached, tree-shaken icon fonts cannot hide new icons. For a matching local production preview, run the same script after a fresh web build.
