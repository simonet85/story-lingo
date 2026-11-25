# Storylingo content API

FastAPI service that exposes the Storylingo book catalogue, manifests, chapters
and audio files, and synchronises learning progress for signed-in users.
SQLite is used by default. The service never stores emails or passwords; sync
rows hold only learning data (reading positions, saved words, SRS cards,
program sessions, preferences) keyed by the verified auth subject. In dev mode
the user id is a SHA-256 hash of the email.

## Setup

```bash
python -m venv .venv-server
.venv-server/Scripts/pip install -r server/requirements-dev.txt
```

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `STORYLINGO_DATABASE_URL` | `sqlite:///server/data/storylingo.db` | SQLAlchemy URL (PostgreSQL supported). |
| `STORYLINGO_CONTENT_DIR` | `server/data/packs` | Folder containing one directory per published pack. |
| `STORYLINGO_PUBLIC_BASE_URL` | empty | CDN/base URL prepended to chapter and audio URLs. |
| `STORYLINGO_SUPABASE_JWKS_URL` | empty | Supabase JWKS endpoint (RS256/ES256 tokens). |
| `STORYLINGO_SUPABASE_JWT_SECRET` | empty | Legacy Supabase JWT secret (HS256 tokens). |
| `STORYLINGO_SUPABASE_ISSUER` | empty | Expected `iss`, e.g. `https://<project>.supabase.co/auth/v1`. |
| `STORYLINGO_SUPABASE_AUDIENCE` | `authenticated` | Expected `aud`. |
| `STORYLINGO_DEV_AUTH` | off | Enables `POST /v1/auth/dev/login` for local development. |
| `STORYLINGO_DEV_AUTH_SECRET` | random per process | HS256 secret for dev tokens (32+ bytes). |
| `STORYLINGO_REVENUECAT_WEBHOOK_SECRET` | empty | Shared secret expected in the webhook `Authorization` header. |
| `STORYLINGO_MONEYFUSION_API_URL` | empty | MoneyFusion API link used by the server to create payments. **Secret** (the link embeds the account token). |
| `STORYLINGO_MONEYFUSION_STATUS_BASE_URL` | `https://pay.moneyfusion.net` | Base URL for `paiementNotif/{token}` status checks. |
| `STORYLINGO_MONEYFUSION_PRICE_MONTHLY_XOF` | `3500` | Monthly product price in XOF (FCFA). Development default, confirm before production. |
| `STORYLINGO_MONEYFUSION_PRICE_YEARLY_XOF` | `30000` | Yearly product price in XOF (FCFA). Development default, confirm before production. |
| `STORYLINGO_ADMIN_TOKEN` | empty | Enables the `/admin` back-office; empty means every admin route returns 404. |
| `STORYLINGO_ADMIN_SESSION_SECRET` | random per process | HS256 key for admin session cookies (32+ bytes recommended). |
| `STORYLINGO_ADMIN_MAX_UPLOAD_MB` | `200` | Maximum size of a pack ZIP uploaded from the back-office. |

Never enable `STORYLINGO_DEV_AUTH` in production. Without
`STORYLINGO_DEV_AUTH_SECRET` a random secret is generated at startup, so dev
tokens stop working after a restart. CORS only allows `localhost` and
`127.0.0.1` origins.

## MoneyFusion payments

`POST /v1/payments/moneyfusion` (Bearer token) accepts
`{productId, numeroSend, nomclient}` and returns `{token, url, productId,
amount}`. The server keeps the API link and the prices; amounts sent to
MoneyFusion always come from the server configuration.

`POST /v1/webhooks/moneyfusion` accepts a JSON or form body carrying `token`.
The webhook is only a trigger: the server re-checks
`GET {STATUS_BASE}/paiementNotif/{token}` and grants the subscription
(`source = "moneyfusion"`) only when the remote status is `paid` and the amount
matches the stored payment. Applying is idempotent per token, so a replayed
callback never extends the expiry.

`GET /v1/payments/moneyfusion/return` is the minimal return page used as
`return_url`; it never mutates payment state.

`GET /v1/payments/moneyfusion/products` is public and read-only. It returns
`{products: [{productId, amount, days, currency}]}` for the monthly and yearly
offers, with amounts read from `STORYLINGO_MONEYFUSION_PRICE_*`. It answers
`503` when a configured price is zero and never exposes the MoneyFusion API
link.

The Flutter app reads its configuration from `--dart-define`:

```bash
# Local dev auth
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   # emulator

# Supabase auth (tokens verified by this API)
flutter run \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

Debug builds allow cleartext HTTP so native audio can stream from the emulator;
release builds require HTTPS.

## Run

```bash
python -m uvicorn server.app.main:create_app --factory --reload --port 8000
```

`GET /v1/health` returns `{"status": "ok"}`.

Endpoints:

- `GET /v1/catalogue` — published books (ETag + `If-None-Match` → 304).
- `GET /v1/books/{id}` — manifest with chapter `url` values.
- `GET /v1/books/{id}/download` — offline download descriptor (ETag + `If-None-Match` → 304).
- `GET /v1/books/{id}/files/{path}` — canonical JSON bytes hashed by the descriptor.
- `GET /v1/books/{id}/chapters/{chapterId}` — chapter JSON with audio `url`.
- `GET /v1/books/{id}/audio/{file}` — MP3 with HTTP Range (200/206/416).
- `POST /v1/auth/dev/login` — dev token (`404` unless dev auth is enabled).
- `GET /v1/auth/me` — claims of the bearer token.
- `POST /v1/sync/push` — push local records, returns last-write-wins winners.
- `GET /v1/sync/pull?since=<revision>` — records changed after a revision.
- `GET /v1/entitlements` — subscription state of the bearer token (`no-store`).
- `POST /v1/entitlements/dev-grant` — grant access for tests (`404` unless dev auth is enabled).
- `POST /v1/entitlements/dev-revoke` — remove test access.
- `POST /v1/webhooks/revenuecat` — signed RevenueCat events (503 when unconfigured).
- `GET /admin/books` — back-office book list (session required).
- `GET /admin/books/{id}` — metadata and chapter list of a book.
- `GET /admin/books/{id}/edit` — prefilled metadata form.
- `POST /admin/books/{id}/edit` — update metadata and free/paid access
  (session + CSRF required).
- `POST /admin/books/{id}/delete` — archive the pack and remove the book
  (session + CSRF, exact id confirmation required).
- `POST /admin/import` — upload a pack ZIP (session + CSRF required).
- `POST /admin/books/{id}/access` — switch a book between free and paid.

## Accounts and sync

```bash
export STORYLINGO_DEV_AUTH=1
export STORYLINGO_DEV_AUTH_SECRET=dev-secret-at-least-32-bytes-long
python -m uvicorn server.app.main:create_app --factory --port 8000
```

```bash
TOKEN=$(curl -s -X POST http://localhost:8000/v1/auth/dev/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"anna@example.com"}' \
  | python -c "import json,sys;print(json.load(sys.stdin)['accessToken'])")

curl -s http://localhost:8000/v1/auth/me -H "Authorization: Bearer $TOKEN"

curl -s -X POST http://localhost:8000/v1/sync/push \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"records":[{"namespace":"words","id":"sleepy-hollow/mist",
       "updatedAt":1760000000000,"payload":{"word":"mist"}}]}'

curl -s 'http://localhost:8000/v1/sync/pull?since=0' \
  -H "Authorization: Bearer $TOKEN"
```

Namespaces are `reading`, `words`, `srs`, `program` and `prefs`. Deleted records
use `"deleted": true` (word tombstones). A push accepts up to 500 records and
64 KiB per payload; conflicts are resolved by the highest client `updatedAt`.
Each accepted push increments a per-user revision, and `pull?since=` returns the
records written after that revision.

## Subscriptions

New books are paid by default. Publish the two free books (pilot and Night
Train) with `--free`; republishing without a flag keeps the stored status.

```bash
python server/scripts/publish_pack.py path/to/pack --free
python server/scripts/publish_pack.py path/to/pack --paid
```

`GET /v1/entitlements` returns the subscription state of the authenticated
user. RevenueCat must send `app_user_id` equal to the API user id (the JWT
`sub`, e.g. the Supabase user id or the dev `dev_<hash>` id). Configure the
webhook URL as `<api>/v1/webhooks/revenuecat` and set its Authorization header
to `STORYLINGO_REVENUECAT_WEBHOOK_SECRET`; without the secret the endpoint
answers 503. Events are applied only when their `event_timestamp_ms` is newer
than the stored event, so retries and out-of-order deliveries are safe.

For local tests, enable dev auth and grant access to the logged-in user:

```bash
curl -s -X POST http://localhost:8000/v1/entitlements/dev-grant \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"days":30}'
curl -s -X POST http://localhost:8000/v1/entitlements/dev-revoke \
  -H "Authorization: Bearer $TOKEN"
```

The Flutter app enables real billing only when built with
`--dart-define=REVENUECAT_API_KEY=<public SDK key>` on Android/iOS; every other
build (web, tests, keyless debug) uses the local demo gateway.

Content endpoints stay public: the subscription gate is enforced by the client,
which is documented as an anti-piracy limitation until signed content URLs are
introduced.

## Back-office

The admin UI is disabled unless `STORYLINGO_ADMIN_TOKEN` is set:

```bash
export STORYLINGO_ADMIN_TOKEN=choose-a-long-password
export STORYLINGO_ADMIN_SESSION_SECRET=another-secret-at-least-32-bytes
python -m uvicorn server.app.main:create_app --factory --port 8000
```

Open `http://localhost:8000/admin` and sign in with the token. The session is a
JWT in an `HttpOnly`/`SameSite=Lax` cookie (12 h); mutations require a
per-session CSRF token. Without `STORYLINGO_ADMIN_SESSION_SECRET`, sessions end
when the API restarts.

The UI lists published books, imports a pack ZIP (`manifest.json` at the root or
inside a single folder) through the same validation and atomic swap as
`publish_pack.py`, and switches a book between free and paid. Everything happens
immediately in `/v1/catalogue`, `/v1/books/{id}` and downloaded manifests.

Each row links to a detail page (metadata plus chapter list). The edit form
updates `title`, `titleFr`, `author`, `level`, `descriptionFr` and the free/paid
flag: the pack is copied to a temporary folder, its manifest rewritten and
republished with `publish_pack`, so validation runs again and the
`.download.json` sidecar (sizes and SHA-256) is rebuilt atomically.

Deletion is reversible: it requires typing the exact book id, moves the pack
folder to `<STORYLINGO_CONTENT_DIR>/.deleted/<id>-<UTC stamp>-<random suffix>`
and then removes the `books` row (the folder is restored if the database write
fails). Nothing under `.deleted/` is purged automatically; restore a pack by
moving its archive back and publishing it again.

The token and session secret must stay out of the repository and logs. The
back-office is meant for a trusted local or VPN network: put it behind HTTPS, a
reverse proxy and network restrictions before exposing it publicly. Uploads are
extracted in a temporary folder with zip-slip and size checks.

### Visual CRUD scenario

`tools/visual/admin_crud.mjs` drives a running Chrome through the full cycle:
import `tools/visual/fixtures/visual-crud.zip`, screenshot the list and detail,
edit the book from the form, check the manifest, catalogue and every download
descriptor file (size + SHA-256), then delete it from the UI. It fails on any
browser exception, console error or network error. Start a scratch API and a
debuggable Chrome first:

```bash
python -m uvicorn server.app.main:create_app --factory --port 8765   # with admin env vars
chrome.exe --remote-debugging-port=9223 --user-data-dir=.tmp/chrome-crud http://127.0.0.1:8765/admin/login
BASE_URL=http://127.0.0.1:8765 CDP_URL=http://127.0.0.1:9223 \
  ADMIN_TOKEN=<admin-token> node tools/visual/admin_crud.mjs
```

Screenshots land in `.tmp/visual/` (`01-login.png` … `06-list-after-delete.png`).

### Android visibility scenario

`tools/visual/android_visibility.mjs` proves the same cycle reaches the mobile
app. It imports the fixture through the back-office, resets the app data
(minimal onboarding/A2 prefs via `run-as`), then drives the real emulator with
`uiautomator`: the uploaded book must appear in the library, its chapter must
open, an admin edit must change the card, and deletion must remove it. An APK
built with `API_BASE_URL=http://10.0.2.2:8000` can use a scratch API on 8766
through a local `8000 → 8766` relay, or be rebuilt against 8766.

```bash
ADB="$ANDROID_HOME/platform-tools/adb" ADMIN_TOKEN=<admin-token> \
  node tools/visual/android_visibility.mjs
```

Screenshots: `android-10-library-uploaded.png`, `android-11-reader-uploaded.png`,
`android-12-library-edited.png`, `android-13-library-after-delete.png`.

## Publish a pack

```bash
python server/scripts/publish_pack.py path/to/pack
```

The pack folder must contain `manifest.json`, a `chapters/` folder and
optionally `audio/`. Publishing validates ids, chapter numbers and referenced
audio files, copies the pack under `STORYLINGO_CONTENT_DIR/<bookId>` and
upserts the database row (same command can be rerun safely). The swap is atomic
(staging + backup with rollback) and writes a `.download.json` sidecar listing
each downloadable file with its size and SHA-256. The served manifest and the
downloaded pack both include `isFree`.

## Import a book

See `tools/content/import_book.py` (EPUB → pack, deterministic A2/B1 lexicon,
optional edge-tts audio). Publish the generated pack with the command above.

## Tests

```bash
python -m pytest server/tests tools/content/tests
```
