# Decisions Log (ADR-lite)

One line per decision, with why. Append-only; supersede with a new entry rather than editing. Newest at the bottom.

- **D1** SQLite, not Postgres — single-node self-host target; zero-dependency install beats horizontal scale for v0.
- **D2** UUIDv7 primary keys — time-ordered, so index-friendly in SQLite and doubles as a free pagination cursor.
- **D3** Keep the term `customer` for team members (vs renaming to `member`) — AGENTS.md and existing docs already use it; glossary.md disambiguates from `end_user`. Less churn wins.
- **D4** Environments added as a first-class table; flag definitions are company-wide, flag *state* and *assignments* are per-environment. SDK keys are environment-scoped, so evaluation never takes an environment parameter.
- **D5** Every company is seeded with `production` and `development` environments; new flags get an `off` state row in every environment at creation (no missing-state case at evaluation time).
- **D6** One `access_key` table for both CLI tokens and SDK keys, split by `kind` enum — same hashing, display-once, and revocation code path.
- **D7** Access tokens hashed with SHA-256 (not bcrypt) — tokens are high-entropy random, brute force is infeasible, and evaluation-path lookups must be fast. One-time codes (6 digits, low entropy) are compensated by expiry + attempt limits + rate limiting instead.
- **D8** Token format `exw_<key_uuid>_<secret>` — lookup by embedded id, then constant-time hash compare. No table scan.
- **D9** Server-side evaluation only in v0 — SDKs are thin HTTP clients. Local evaluation/streaming is post-v0.
- **D10** Bucketing hash = SHA-256 of `flag.key <> ":" <> end_user.identifier`, mod 100. Environment excluded so bucketing is consistent across environments. See evaluation.md.
- **D11** A customer has exactly one role (column on `customer`), not many — RBAC stays trivially explainable. Roles and permissions are global seed data, not editable per company in v0.
- **D12** Flag `key` is immutable after creation — SDKs reference it in code; renaming keys silently breaks callers. `name` is the mutable display label.
- **D13** Unknown end_user identifiers at evaluation time are not auto-created — keeps the eval path read-only and abuse-proof. Revisit post-v0.
- **D14** ~~CLI auth reuses the email OTP flow in-terminal~~ — superseded by D15/D16.
- **D15** Web UI and email delivery dropped entirely for v0 — the CLI is the only interface. Removes the OTP flow, sessions, and the mailer dependency.
- **D16** Auth is email + password (bcrypt-hashed), CLI-driven: `signup` sets the password and mints the first token; `login` mints more. Supersedes "passwordless" in the original principles — no email delivery means no OTP.
- **D17** Pre-approved email list = customer rows with `hashed_password = NULL` (created by admin invite). No separate pending table; signup only succeeds against a NULL-password row.
- **D18** First-boot bootstrap: `EXWEAVER_ADMIN_EMAIL` env var seeds one admin customer (no password) on startup when no customers exist. Idempotent.
- **D19** Personal token expiry chosen at mint: `1d|7d|14d|30d|90d|never`, default 30d, stored in `access_key.expired_at` (NULL = never). Sdk keys default to never.
- **D20** Rate limiting counters live in ETS — single node, no persistence needed; reset-on-restart is acceptable for v0.
- **D21** Password reset is admin-driven (clear password + revoke tokens, user re-signs-up) — no email means no self-service reset.
- **D22** CLI ships as a Burrito standalone binary (no Erlang required on user machines). Lives in `cli/` as its own mix project in the same repo.
- **D23** TLS is the operator's job: document "run behind a reverse proxy (Caddy/nginx) with TLS" — no built-in cert support. Passwords and tokens must never traverse plain HTTP outside localhost.
- **D24** Multi-company IS supported in v0. New companies are created via POST /company/:create and are creatable via anyone with an `admin` role . `EXWEAVER_ADMIN_EMAIL` (D18) is just sugar for creating the first company on first boot. There are no `/companies` READ API endpoints; all API auth stays company-scoped.
- **D25** Test stack is ESpec + ExMachina (per testing_guidlines.md), specs under `spec/**/*_spec.exs`. `mix test` is aliased to `mix espec` so the working-agreement/CI command still works. Supersedes the "DataCase/ConnCase" (ExUnit) wording in tasks.md C0 — controller specs will use `Phoenix.ConnTest` helpers directly rather than a generated ConnCase.
- **D26** Timestamps use Ecto's default `inserted_at`/`updated_at` columns (`:utc_datetime`), set via `Exweaver.Schema`. Every schema does `use Exweaver.Schema`, which also sets the `Exweaver.UUIDv7` primary/foreign key type. (database_diagram.md updated to `inserted_at` to match — earlier `created_at` remap reverted to avoid fighting Ecto conventions.)
- **D27** Known caveat: ESpec 1.10 emits a `return_diagnostics: true` compiler warning under Elixir 1.20 (specs still pass). Non-blocking; revisit if a newer ESpec release fixes it. CI is pinned to Elixir 1.18/OTP 27 where this is quieter.
- **D28** RBAC enforcement model (resolves K2). The `ExweaverWeb.Plugs.Authorize` plug is the single authoritative gate for *permission-by-method* on management endpoints (POST=create, GET=read, PATCH/PUT=update, DELETE=delete), calling `Accounts.authorize/2`. Contexts own *company scoping*, not method-permission RBAC — so `Flags` functions (which take pre-scoped structs, not an actor) correctly do no `authorize/2` and rely on the plug. *Role-specific* rules that permission-by-method cannot express live in the context function performing the privileged action: `Accounts.create_company/3` requires the actor's role be `admin` (D24) — a `developer` holds `:create` and would otherwise pass the generic plug. The actor-less `create_company/2` remains for first-boot bootstrap (D18). `Accounts`' in-context `authorize/2` calls on `invite/update/delete/reset` are kept as intentional defense-in-depth (these take an actor); where the plug's method-permission and the context gate disagree (e.g. `POST /customers/:id/reset` → plug `:create` vs context `:update`), the stricter context gate is authoritative.

- **D29** RBAC decision consolidated into `Exweaver.Accounts.Authorization` (amends D28). `authorize/2` (role→permission) and `require_admin/1` moved out of `Accounts` into this one module — the single home and single test surface for "can this actor act?". `Accounts.authorize/2` remains as a thin `defdelegate` facade so the web layer still calls a context public function; the `Authorize` plug is unchanged and stays the **sole** permission-by-method gate. The in-context "defense in depth" `authorize/2` calls on `invite_customer`/`update_customer`/`delete_customer` are **removed** — they only duplicated the plug's method-permission check (all four seeded roles that hold e.g. `:create` also pass the plug), so they added no enforcement the plug didn't already provide, and having two gates for one decision was the friction D28 had to legislate around. Role-specific rules that permission-by-method can't express stay in-context via `Authorization.require_admin/1` (`create_company/3` and `reset_customer/2`, D24). Net: one authoritative gate per concern (plug for method-permission, context for admin-only), no duplicated logic. Supersedes D28's "kept as intentional defense-in-depth" stance.

## Non-goals for v0 (do not build without a new decision here)
- Web UI (CLI only — D15)
- Email delivery of any kind (D15)
- Self-service password reset (D21)
- Audit log / change history
- Webhooks and integrations
- Targeting rules (segments, attributes, percentages per rule)
- Multi-variant / string / number flags (booleans only)
- Custom roles or per-company permissions
- Local SDK evaluation, streaming updates
- Scheduled flag changes
- Multi-region / HA deployment
- Built-in TLS (reverse proxy only — D23)
- `/companies` read/list API endpoints (create-only via API — D24)
