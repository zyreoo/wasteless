# Wasteless

Flutter, FastAPI and Supabase. Development branch: `codex/wasteless-mvp`.

## Implemented

- Supabase email/password authentication, confirmation-required signup, SDK session
  persistence/refresh, logout and auth-aware routing. Backend validates each token
  with Supabase Auth and derives identity from the verified response.
- Real product list/detail, persistent cart CRUD, favorites by product ID,
  transactional order creation and owner-scoped order history/detail.
- User-token PostgREST requests, server owner filters and database RLS. Admin user
  listing is removed. Direct commerce writes are revoked in favor of authenticated
  RPCs with ownership checks. No service-role credential is used by these routes.
- Checkout locks the cart and products, checks stock, snapshots prices/names,
  decrements stock and clears the cart in one transaction. A per-user idempotency
  key prevents duplicate orders; retries reuse the key. Prices are RON with two
  decimals. There is no payment gateway: payment is at pickup, not online.
- Romanian errors, loading/empty states, accessibility text scaling and the existing
  colors/fonts/design assets. Old artboards remain available for design review only.
- Real Supabase password recovery with a configurable web redirect and neutral
  account-enumeration-safe messaging.
- Single-instance MVP API rate limiting, request timing logs and production Docker
  paths for the API and Flutter/nginx frontend.

## Deployment status — important

Both migrations were applied to `ueurvamkhwkgoydplnfe` on 2026-09-28 after
explicit user approval. Live checks confirmed six owner/catalog SELECT policies,
RLS on commerce and legacy cart tables, denied anonymous access, and unchanged
business-row counts. Local migration versions match the remote migration history.

Existing products 1 and 2 have unknown (`NULL`) stock. They remain unchanged and
are hidden from the orderable catalogue until real stock is entered. The existing
favorite has no product or owner; it is preserved but not assigned to an account.
No fake products or guessed stock are inserted.

Tests cover local PostgreSQL semantics, API contracts and Flutter interactions.
Live registration, real-device restart/session restoration and a complete live
purchase have **not** been verified. The database tests use isolated test users and
products, never production rows.

## Database

See [migration notes](docs/database-handoff.md). The migrations adapt the existing
schema captured in `docs/schema-before-mvp.json`; they do not create duplicate
commerce tables. For new environments, apply in filename order through the Supabase migration
workflow after review/approval. These migrations are already applied to WasteLess. Take a schema backup first; do not blindly rerun applied
migrations or use these against an unrelated schema.

## Backend

Python 3.11:

```sh
python3 -m venv .venv
. .venv/bin/activate
pip install -r fastAPI/requirements.txt
cp fastAPI/.env.example fastAPI/.env # fresh checkout only
cd fastAPI
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Set `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` and explicit `CORS_ORIGINS`.
Never put secret/service-role credentials in Flutter. `/health` is public;
`/api/me` and every commerce route require a bearer session token.

## Flutter

```sh
cd flutter_application_1
cp config.example.json config.local.json
# Fill SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and API_BASE_URL.
flutter pub get
flutter run --dart-define-from-file=config.local.json
```

Use an API address reachable from the target device and HTTPS outside local
web/desktop development. Android release has Internet permission but does not
permit arbitrary cleartext HTTP. Choose a HTTPS development endpoint for mobile.
Supabase email-confirmation settings are respected: registration may require
confirming the email and then logging in. No success is faked.

Production deployment, HTTPS proxy, Auth redirect, rate limits, caching and security
headers are documented in [production deployment](docs/production-deployment.md).

The design-only prototype (seeded preview data, never the production entry point):

```sh
flutter run -t lib/preview_main.dart
```

## Checks

```sh
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=fastAPI python3 -m unittest discover -s fastAPI/tests -v
npm ci --prefix tests/database
node tests/database/test.mjs
cd flutter_application_1
flutter analyze
flutter test
flutter build web --dart-define-from-file=config.local.json
```

PostgreSQL tests use PGlite and reconstruct the inspected legacy schema before
applying the migration. They cover cross-user reads/mutations, anonymous access,
price snapshots, stock failure rollback, idempotency and preservation of incomplete
legacy rows. They do not simulate concurrent PostgreSQL connections.
