# Authentication (v0)

CLI-only. No web UI, no email delivery (decisions.md D15). Two credential types:

| Credential | Used by | Storage |
|---|---|---|
| Personal access token | CLI | `access_key` row, `kind=personal`, `customer_id` set; inherits the customer's role; optional expiry |
| SDK access key | SDKs | `access_key` row, `kind=sdk`, `environment_id` set, role `automated`; no expiry by default |

Tokens stored SHA-256 hashed (high-entropy — D7). Passwords stored bcrypt hashed (low-entropy — D16). Token plaintext shown exactly once. Token format `exw_<key_uuid>_<secret>` — fetch by embedded id, constant-time hash compare (D8).

## Pre-approval (invite)
There is no open signup. An admin pre-approves an email:
```sh
exweaver customers invite dev@example.com --role developer
```
→ `POST /customers` creates a customer row with `hashed_password = NULL`. A NULL password means "pre-approved, not yet signed up" — no separate pending table (D17).

## First-boot bootstrap & new companies
On first startup, if `EXWEAVER_ADMIN_EMAIL` is set and no customers exist, seed a company + admin customer (no password). That admin then runs `exweaver signup`. Idempotent (D18).

Additional companies: any customer with the `admin` role calls `POST /companies` `{name, admin_email}` (D24). Same effect — the new company gets a pre-approved admin who completes signup via CLI.

## Transport
The server itself speaks plain HTTP; self-hosters MUST put it behind a TLS reverse proxy (Caddy/nginx) for anything beyond localhost (D23) — passwords and tokens are bearer secrets.

## Signup (one-time, sets password + mints first token)
```sh
exweaver signup email@email.com
password: ****
Login successful ✅
Copy this access key, it won't be displayed again:
exw_...
```
`POST /auth/signup` `{email, password, expires_in}` — succeeds only if the customer row exists AND `hashed_password` is NULL. Sets the bcrypt hash, mints a personal token, returns plaintext once. Unknown email or already-signed-up → generic 422 (no enumeration).

## Login (mint a new token any time)
```sh
exweaver login email@email.com [--expires 30d]
```
`POST /auth/login` `{email, password, expires_in}` — verifies bcrypt hash, mints a new personal token.

- `expires_in`: `1d | 7d | 14d | 30d | 90d | never` (server validates the enum). Default `30d` (D19). Stored as `access_key.expired_at` (NULL = never).
- CLI writes token to `~/.config/exweaver/credentials` (mode 0600); all API calls send `Authorization: Bearer <token>`.
- `exweaver logout` deletes the local file and calls `DELETE /access_keys/:id`.
- Expired tokens → 401 with code `token_expired` so the CLI can prompt re-login.

## Rate limiting
ETS-backed counters (D20), single-node: max 5 failed password attempts per email per 15 min, and per-IP caps on `/auth/*`. Counters reset on restart — acceptable for v0.

## SDK / evaluation auth
- Sdk keys created via `POST /access_keys` `{kind: "sdk", environment_id}` (or `exweaver keys create`); the key determines the environment — evaluation requests never pass one.
- Valid only on `/api/v1/evaluate*`; rejected on all management endpoints. Personal tokens are rejected on `/evaluate*`.

## Password reset
No self-service reset in v0 (no email). An admin runs `exweaver customers reset-password <email>` → `POST /customers/:id/reset` clears `hashed_password`, revokes the customer's personal tokens; the user signs up again.
