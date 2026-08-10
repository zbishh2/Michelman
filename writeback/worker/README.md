# Michelman Writeback Worker

A single Cloudflare Worker over one D1 database (`michelman-writeback`) that
backs two Power BI custom visuals: the **Revision Log Editor** (overrides on
`FactScheduleChange` revision events) and **Order Line Comments** (comment
threads at the `Orders[Order Line ID]` grain). It is the writeback tier of the
solution described in [`../ARCHITECTURE.md`](../ARCHITECTURE.md).

- `src/index.ts` — the whole API (single-file router).
- `schema.sql` — the 6 D1 tables + indexes.
- `wrangler.toml` — Worker + D1 binding config.

## Auth model

- Every route except `GET /health` requires the `x-secret` header to equal the
  Worker's `SHARED_SECRET`. The secret ships inside the `.pbiviz` artifacts, so
  this is a gate against casual/anonymous access, not a hard trust boundary —
  the report is internal and tenant-gated. Rotate the secret if it leaks.
- Identity is the self-asserted `x-actor-email` header (the visual sends
  `USERPRINCIPALNAME()`). Roles resolve server-side against the `people` table;
  an email with no active `people` row has no role.

### Role matrix

| Capability | admin | editor | restricted | unlisted |
|---|:---:|:---:|:---:|:---:|
| Read overrides / comments / history / reason codes / people | ✅ | ✅ | ✅ | ✅ (needs `x-secret`) |
| `PUT` / `DELETE` revision override (reason, note, exclude) | ✅ | ✅ | ❌ | ❌ |
| Post a comment | ✅ | ✅ | ✅ | ❌ |
| Edit / delete **own** comment | ✅ | ✅ | ✅ | ❌ |
| Edit / delete **any** comment | ✅ | ❌ | ❌ | ❌ |
| Manage people (email / role / active) | ✅ | ❌ | ❌ | ❌ |
| Manage reason codes | ✅ | ❌ | ❌ | ❌ |
| Read / write **own** layout | ✅ | ✅ | ✅ | ✅ (needs `x-actor-email`) |

Read routes only need `x-secret`, so the model refresh (which sends the secret
but no actor email) can pull `GET /revision-overrides` and `GET /comments/latest`.

## Deploy runbook — brand-new Cloudflare account

This assumes a fresh, Michelman-dedicated Cloudflare account (nothing exists yet).

### 1. Create the account

1. Go to <https://dash.cloudflare.com/sign-up>, sign up with the Michelman IT
   mailbox, and verify the email. The free plan covers Workers + D1.
2. (Recommended) enable 2FA on the account under **My Profile → Authentication**.

### 2. Install tooling

```bash
node --version   # need Node 18+
npm install      # from this worker/ directory — installs wrangler locally
```

All commands below use the locally-installed wrangler via `npx`/`npm run`, so a
global install is not required.

### 3. Authenticate

The deploy credential is an API token stored at `../CF Token.txt` (i.e.
`writeback/CF Token.txt`, gitignored). Rather than the interactive
`wrangler login`, pass it to every wrangler command via the
`CLOUDFLARE_API_TOKEN` env var. Read it straight from the file (stripping any
trailing newline) so the token never lands in your shell history:

```bash
CLOUDFLARE_API_TOKEN=$(tr -d '\r\n' < "../CF Token.txt") npx wrangler whoami
```

`whoami` should report the Michelman account (id `90b8807948312a9dc357d690babd40ff`,
already pinned as `account_id` in `wrangler.toml`). Prefix each wrangler command
below the same way. To avoid repeating it, export it for the session instead:

```bash
export CLOUDFLARE_API_TOKEN=$(tr -d '\r\n' < "../CF Token.txt")
```

The `npm run` scripts pick up an exported `CLOUDFLARE_API_TOKEN` automatically.

### 4. Create the D1 database

```bash
npx wrangler d1 create michelman-writeback
```

Copy the `database_id` it prints and paste it into `wrangler.toml`, replacing
`REPLACE_AFTER_wrangler_d1_create`:

```toml
[[d1_databases]]
binding = "DB"
database_name = "michelman-writeback"
database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### 5. Create the tables

```bash
npm run db:init          # runs schema.sql against the REMOTE D1
# npm run db:init-local  # same, but against the local dev D1 (for wrangler dev)
```

### 6. Set the shared secret

```bash
npm run secret:set       # wrangler secret put SHARED_SECRET — paste a long random string
```

Generate one with e.g. `openssl rand -hex 32`. Record it in the team password
vault; the visuals' `config.ts` uses the same value.

### 7. Deploy

```bash
npm run deploy
```

Wrangler prints the Worker URL, e.g.
`https://michelman-writeback.<subdomain>.workers.dev`. That origin is the
`baseUrl` for the visuals' `config.ts` and must be whitelisted in each visual's
`capabilities.json` `privileges.WebAccess`.

### 8. Smoke test

Replace `BASE`, `SECRET`, and `ADMIN` below. Bootstrap yourself as an admin
first (the `people` table starts empty, so nothing can be written until one
admin exists — insert it directly):

```bash
npx wrangler d1 execute michelman-writeback --remote --command \
  "INSERT INTO people (person_key, person_name, email, role) VALUES ('YOU','You','you@michelman.com','admin');"
```

```bash
BASE=https://michelman-writeback.<subdomain>.workers.dev
SECRET=<the shared secret>
ADMIN=you@michelman.com

# health (no auth)
curl -s $BASE/health

# seed a reason code (admin)
curl -s -X POST $BASE/reason-codes \
  -H "x-secret: $SECRET" -H "x-actor-email: $ADMIN" \
  -H 'content-type: application/json' \
  -d '{"code":"RFRV","label":"Requested revision","sortOrder":10}'

# write a revision override (editor+)
curl -s -X PUT $BASE/revision-override \
  -H "x-secret: $SECRET" -H "x-actor-email: $ADMIN" \
  -H 'content-type: application/json' \
  -d '{"revisionKey":"00010,74,CM,4.000|2026-03-14|143502","orderLineId":"00010,74,CM,4.000","changeDate":"2026-03-14","changeTime":"143502","revisionReason":"RFRV","note":"customer pulled in","excludeFlag":false}'

# read them back (secret only)
curl -s $BASE/revision-overrides -H "x-secret: $SECRET"

# post + read a comment
curl -s -X POST $BASE/comment \
  -H "x-secret: $SECRET" -H "x-actor-email: $ADMIN" \
  -H 'content-type: application/json' \
  -d '{"orderLineId":"00010,74,CM,4.000","body":"Following up with planning."}'
curl -s "$BASE/comments/thread?orderLineId=00010,74,CM,4.000" -H "x-secret: $SECRET"
curl -s $BASE/comments/latest -H "x-secret: $SECRET"
```

## API reference

All routes require `x-secret` except `GET /health`. `x-actor-email` supplies
identity for role checks. `revision_key` is always in the JSON body (it contains
commas and pipes) — never in the URL path.

| Method | Path | Auth | Body / query | Notes |
|---|---|---|---|---|
| GET | `/health` | none | — | `{ ok: true }` |
| GET | `/revision-overrides` | secret | — | `{ [revisionKey]: {...} }` map (model refresh) |
| PUT | `/revision-override` | editor+ | `{ revisionKey, orderLineId?, changeDate?, changeTime?, revisionReason?, note?, excludeFlag?, createdAt? }` | Partial upsert; omitted fields preserved; diffs into history |
| DELETE | `/revision-override` | editor+ | `{ revisionKey }` | Hard delete |
| GET | `/history` | secret | `?revisionKey=&since=&limit=` | `limit` ≤ 500 (default 100), newest first |
| GET | `/comments/latest` | secret | — | `{ [orderLineId]: {...} }` latest non-deleted (model refresh) |
| GET | `/comments/thread` | secret | `?orderLineId=` | Full thread, oldest first |
| POST | `/comment` | listed | `{ orderLineId, body, createdAt? }` | Any active listed person |
| PATCH | `/comment/:id` | listed | `{ body }` | Own comment only unless admin |
| DELETE | `/comment/:id` | listed | — | Soft delete; own only unless admin |
| GET | `/people` | secret | — | Array of people |
| POST | `/people` | admin | `{ personName, displayName?, email?, role?, active? }` | Upsert by `person_key` (name uppercased) |
| PUT | `/people/:key` | admin | `{ personName?, displayName?, email?, role?, active? }` | Partial update |
| DELETE | `/people/:key` | admin | — | Soft delete (`active = 0`) |
| GET | `/reason-codes` | secret | — | Array; visual dropdown source |
| POST | `/reason-codes` | admin | `{ code, label?, sortOrder?, active? }` | `code` unique |
| PUT | `/reason-codes/:id` | admin | `{ code?, label?, sortOrder?, active? }` | `code` rename cascades to `revision_overrides` |
| DELETE | `/reason-codes/:id` | admin | — | Soft delete (`active = 0`) |
| GET | `/layout` | secret | `?visual=revisions\|comments` | `{ columnOrder }` for the actor |
| PUT | `/layout` | actor | `?visual=` + `{ columnOrder: [...] }` | Upsert per (email, visual) |
| DELETE | `/layout` | actor | `?visual=` | Reset to default |

`editor+` = role `admin` or `editor`. `listed` = any active `people` row.
`actor` = any `x-actor-email` (layout is per-user, not role-gated).

## Local development

```bash
npm run db:init-local    # create tables in the local D1
npm run dev              # wrangler dev — serves on http://localhost:8787
```

Set a dev secret in `.dev.vars` (gitignored):

```
SHARED_SECRET=dev-secret
```

## Adding a schema migration

Follow the DeliveryReliability convention: add a `migrate-<change>.sql` file
with `CREATE TABLE IF NOT EXISTS` / `ALTER TABLE`, add a `db:migrate-<change>`
script to `package.json`, and run it with `--remote`. Keep `schema.sql` as the
full from-scratch definition so a fresh account only needs `npm run db:init`.
