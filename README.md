# Wasteless

Flutter + FastAPI + Supabase. Work continues on `codex/wasteless-mvp`.

## Status

**This branch is an incomplete MVP foundation, not a deployable commerce app.**
Email/password registration, login and local logout use Supabase Auth. The Flutter
SDK manages persisted sessions and token refresh. FastAPI validates bearer tokens
with Supabase and exposes only the authenticated identity at `GET /api/me`.
The API client centralizes credentials, timeouts, decoding and Romanian errors.

The former unrestricted database reads fail closed: anonymous requests receive
401; authenticated legacy data requests receive 503. The users admin listing is
not exposed. This is a temporary security boundary, **not completed cart/order
functionality**. Do not remove it until real ownership constraints and RLS are
implemented and verified.

The configured Supabase project could not be resolved and is not accessible
through the connected account. No schema was present in Git. Consequently no
migration or guessed replacement tables were created, and no production data
was changed. Real catalogue/cart/favorites/orders and their integration tests
remain blocked on access to the existing schema. Auth has only been exercised
against mocked Supabase responses, not live accounts or device restarts.

## Backend

Python 3.11:

```sh
python3 -m venv .venv
. .venv/bin/activate
pip install -r fastAPI/requirements.txt
cp fastAPI/.env.example fastAPI/.env # only on a fresh checkout
cd fastAPI
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Use the project's publishable key for authentication validation. Never put a
secret/service-role key in Flutter. Configure explicit `CORS_ORIGINS` for web.
The backend does not need privileged database credentials for the exposed routes.

## Flutter

```sh
cd flutter_application_1
cp config.example.json config.local.json
# Fill in SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and API_BASE_URL.
flutter pub get
flutter run --dart-define-from-file=config.local.json
```

Choose an API address reachable from the target: desktop loopback, Android emulator
host alias or your development machine's LAN address. Use HTTPS outside local
development. Release Android builds have Internet permission; HTTP exceptions
are not enabled globally.

When email confirmation is enabled in Supabase, registration asks the user to
confirm their email, then sign in. It never fakes an authenticated session.

The existing full design prototype is preserved separately for visual review:

```sh
flutter run -t lib/preview_main.dart
```

It contains seeded preview data and must not be shipped as the real application.
Production entry point `lib/main.dart` cannot navigate into its fake checkout.

## Checks

```sh
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=fastAPI python3 -m unittest discover -s fastAPI/tests -v
cd flutter_application_1
flutter analyze
flutter test
```

Existing design tests are retained; additional tests cover SDK authentication,
logout, signup requiring confirmation, protected requests, invalid tokens,
identity spoofing, upstream failures and API error handling. They are not a
substitute for RLS tests or end-to-end commerce tests.
