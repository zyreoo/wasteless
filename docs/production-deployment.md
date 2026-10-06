# Wasteless production deployment

The repository contains two production containers:

- `fastAPI/Dockerfile`: FastAPI on Python 3.11, one worker, non-root user, process
  health check, structured HTTP status/timing logs and in-process rate limiting.
- `flutter_application_1/Dockerfile`: pinned Flutter 3.47.2 build followed by nginx
  static hosting, SPA fallback, compression, cache rules and security headers.

Run the containers behind a managed HTTPS reverse proxy or container platform. The
MVP limiter deliberately uses one API instance/worker. Before scaling to multiple
instances, replace it with a shared gateway or Redis-backed limiter; otherwise each
instance enforces an independent quota.

## Environment

Copy `.env.production.example` outside source control and provide real values:

```text
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_REPLACE_ME
API_ORIGIN=https://api.example.com
FRONTEND_ORIGIN=https://app.example.com
TRUSTED_PROXY_IPS=YOUR_PROXY_IP_OR_CIDR
```

The publishable key is intentionally embedded in Flutter web and is protected by
RLS. No service-role/secret key is needed by this architecture. Never add one to
Flutter build arguments or public hosting configuration.

For local development, use `flutter_application_1/config.local.json` with localhost
values. For a direct production build without Docker:

```sh
cd flutter_application_1
flutter build web --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_REPLACE_ME \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=AUTH_REDIRECT_URL=https://app.example.com/#/reset-password
```

All four values are required. Build-time validation fails closed and shows a generic
configuration screen if any URL/key is absent or malformed.

## Start and verify

After the domains terminate TLS and point to the containers:

```sh
docker compose --env-file .env.production -f docker-compose.production.yml up -d --build
curl --fail https://api.example.com/health
curl --fail https://app.example.com/
```

The API must use a single worker while the in-process limiter is active. Set explicit
`CORS_ORIGINS` (the compose file uses `FRONTEND_ORIGIN`); never use `*`.

## Supabase Auth URLs

In Supabase Dashboard → Authentication → URL Configuration:

1. Set the site URL to the exact HTTPS frontend origin.
2. Add `https://app.example.com/#/reset-password` to allowed redirect URLs.
3. Keep `http://127.0.0.1:5173/#/reset-password` only for development.
4. Configure production SMTP before relying on signup/recovery delivery.

The reset request always uses neutral copy, so it does not reveal whether an account
exists. Expired or invalid recovery sessions cannot update a password.

## Rate limits

Defaults are enforced by client IP at the edge and again by verified user ID on
authenticated commerce routes:

- reads: 120 requests/minute;
- cart/favorite writes: 30 requests/minute;
- checkout: 6 requests/minute.

Override with `RATE_LIMIT_READS_PER_MINUTE`,
`RATE_LIMIT_WRITES_PER_MINUTE`, and `RATE_LIMIT_CHECKOUT_PER_MINUTE`. Exceeded
requests return `429` with `Retry-After`. `/health` is exempt.

## Headers and caching

nginx enables gzip for JS/WASM/SVG/JSON/CSS, immutable one-year caching for assets
and CanvasKit, no-cache for `index.html`, HSTS, `nosniff`, referrer, frame and
permissions policies. The CSP permits only the configured API/Supabase origins,
Supabase WebSockets, local assets/data images, inline Flutter styles and WASM
evaluation required by the renderer. Verify the CSP after changing providers.

## Operational checks

- Stream API stdout/stderr to the platform log service. Requests log method, path,
  status and duration, never authorization headers or request bodies.
- Alert on health-check failures and sustained `5xx`/`429` rates.
- Keep at least one recent database backup before migrations.
- Re-run the Supabase security/performance advisors after database changes.
- Core Web Vitals remain unmeasured until browser performance instrumentation is
  available; do not infer them from build-directory size.

## Password recovery

Recovery mode is entered only when the Supabase SDK emits `passwordRecovery`,
which happens after it exchanges the PKCE code from a reset email. Opening
`/#/reset-password` without that exchange shows sign-in (or the catalogue when
already signed in), never the new-password form. PKCE ties the link to the
browser that requested it: a link opened in another browser or reused after a
successful reset is rejected, and the sign-in screen explains that a new link is
needed.

## Mobile release (Android / iOS)

Mobile store builds are **not ready** until the permanent app identifier is chosen.
It cannot change after the first store upload, so pick a reverse-domain ID the
project controls.

Android release builds read their identity and signing from
`flutter_application_1/android/key.properties` (git-ignored; template in
`key.properties.example`) or from CI environment variables:

| Setting | Environment variable |
| --- | --- |
| `applicationId` | `WASTELESS_APPLICATION_ID` |
| `storeFile` (relative to `android/app/`) | `WASTELESS_ANDROID_KEYSTORE` |
| `storePassword` | `WASTELESS_ANDROID_STORE_PASSWORD` |
| `keyAlias` | `WASTELESS_ANDROID_KEY_ALIAS` |
| `keyPassword` | `WASTELESS_ANDROID_KEY_PASSWORD` |

A release build stops with an explicit error if any value is missing or the ID is
still `com.example.*`; it never falls back to the debug key. Debug builds keep the
placeholder ID. Never commit the keystore or `key.properties`.

The iOS project is committed (`flutter_application_1/ios/`), with display name
Wasteless, but `PRODUCT_BUNDLE_IDENTIFIER` is still `com.example.flutterApplication1`
and no signing team is configured. Set both in Xcode once the identifier is chosen.

Neither platform registers a custom URL scheme, so password-reset links open the
web app (`AUTH_REDIRECT_URL`); on mobile the user resets the password in the
browser and then signs in from the app.
