# C17 — End-to-end suite: implementation plan

Finalized approach for the C17 card (see tasks.md). The scenario **is** the test:
a single scripted run drives the **real server** and the **real CLI** against a
**fresh database**, asserting the full product loop from authentication.md /
evaluation.md / rest_api.md. Every step's exit code / HTTP response is an
assertion; any failure fails the run.

## Fidelity decisions (and why)

- **No Docker.** The stack has no external services to orchestrate: the DB is
  SQLite (a file), the server is a self-contained `mix release`, and the CLI is a
  self-contained binary. "Spin up / down" is a backgrounded process + a temp dir,
  handled by a `trap`. A Dockerfile would wrap a single process for no gain.
  Revisit **only** if the project later decides its distribution artifact should
  be a container image — that's a C18 scope question, not C17.
- **CLI in CI = the real Burrito binary; CLI locally = `mix run`.** The CLI's
  argv comes through `Burrito.Util.Args.argv()`
  (`cli/lib/exweaver_cli/application.ex`), which is Burrito-specific — so testing
  the *shipped* artifact genuinely requires a Burrito build (→ zig). CI builds the
  host-target binary and validates the real thing. Locally, forcing every dev to
  `brew install zig xz p7zip` is not worth it, so the script is **binary-agnostic**
  (see below) and falls back to driving the CLI via `mix run`, which exercises all
  CLI logic + real HTTP — everything except the Burrito wrapper, which is C18's
  deliverable to build+smoke-test across all four targets anyway.
- **Server = prod `mix release`.** Boot it the way an operator will
  (`PHX_SERVER=true bin/exweaver start`). This also de-risks C18's release work.

## Binary-agnostic CLI indirection

The script never hard-codes how to invoke the CLI. One env var resolves it:

```bash
# CI sets this to the built Burrito binary:
#   EXWEAVER_CLI="$PWD/cli/burrito_out/exweaver_linux_x86"   (confirm exact name at build time)
# Local default: a wrapper that drives the CLI via mix run under MIX_ENV=dev, so
# run_cli stays false and the Burrito.Util.Args path is never hit — our -e code
# calls CLI.main(System.argv()) directly and main/1 halts with the exit code.
exw() {
  if [ -n "${EXWEAVER_CLI:-}" ]; then
    "$EXWEAVER_CLI" "$@"
  else
    ( cd cli && MIX_ENV=dev mix run -e 'ExweaverCli.CLI.main(System.argv())' -- "$@" )
  fi
}
```

The 15 assertions are identical whichever way `exw` resolves.

## Layout

```
test/e2e/
  scenario.sh     # the run: boot server, drive the 15 beats, assert, tear down
  lib.sh          # assert_ok / assert_fail / assert_json_eq helpers + exw() + server lifecycle
```

## Server lifecycle (in scenario.sh)

```bash
WORK="$(mktemp -d)"
export XDG_CONFIG_HOME_BASE="$WORK/cfg"     # per-identity dirs created under here
DB="$WORK/e2e.db"
PORT="${PORT:-4111}"
BASE="http://127.0.0.1:$PORT"
SECRET_KEY_BASE="$(mix phx.gen.secret 2>/dev/null || openssl rand -base64 48)"

MIX_ENV=prod mix release --overwrite            # build once; produces _build/prod/rel/exweaver
PHX_SERVER=true PORT="$PORT" DATABASE_PATH="$DB" SECRET_KEY_BASE="$SECRET_KEY_BASE" \
  EXWEAVER_ADMIN_EMAIL=admin@e2e.test \
  _build/prod/rel/exweaver/bin/exweaver start &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null; rm -rf "$WORK"' EXIT

# Readiness: no health route yet (that's C18). Poll POST /auth/login until it
# answers HTTP 422 (app + router up), with a timeout.
until [ "$(curl -s -o /dev/null -w '%{http_code}' -XPOST "$BASE/api/v1/auth/signup" \
          -H 'content-type: application/json' -d '{}')" != "000" ]; do
  sleep 0.3   # bounded by an overall timeout guard
done
```

Migrations + `Bootstrap.run/0` run on boot (already wired into the supervision
tree), so the fresh DB is created, RBAC seeded, and the pending admin created
from `EXWEAVER_ADMIN_EMAIL`.

## Identities

The CLI stores one token per `$XDG_CONFIG_HOME/exweaver/credentials`. Three
identities each get their own config dir so tokens don't collide and a **stale**
token can be reused deliberately at the end:

- `admin@e2e.test` — bootstrapped first-boot admin
- `dev@e2e.test` — invited `developer` (positive RBAC path)
- `ro@e2e.test` — invited `read-only` (negative RBAC path)

Each `exw` call is prefixed with the right `XDG_CONFIG_HOME=$WORK/cfg/<identity>`.
Passwords go in via `printf 'pw\n' | exw signup …` (C14's `Prompt.password` is
best-effort echo-off, so piped stdin on a non-tty works).

## Scenario (15 beats, 3 identities)

| # | Beat | Command / call | Assertion |
|---|---|---|---|
| 1 | bootstrap admin | server boot w/ `EXWEAVER_ADMIN_EMAIL` | server answers; admin pending |
| 2 | admin signup | `printf 'pw\n' \| exw(admin) signup admin@e2e.test` | exit 0, token stored |
| 3 | create flags | `exw(admin) flags create beta --type boolean`; `… flags create gradual --type percentage` | exit 0 |
| 4 | sdk key | `exw(admin) keys create ci --env production --json` → `jq -r .token` | non-empty `exw_…` |
| 5 | evaluate off | `curl -H "Bearer $SDK" $BASE/api/v1/evaluate/beta?end_user=u1` | `.flags.beta == false` |
| 6 | on | `exw(admin) flags on beta --env production` | exit 0 |
| 7 | evaluate on | curl (as #5) | `.flags.beta == true` |
| 8 | rollout 50 | `exw(admin) flags rollout gradual --env production --percentage 50` | exit 0 |
| 9 | assign user | `exw(admin) flags assign gradual u1 --env production --state on` | exit 0 (creates end_user + override) |
| 10 | evaluate override | `curl …/evaluate/gradual?end_user=u1` → `true`; `…/evaluate/gradual` (anon) → `false` | assignment beats % |
| 11 | invite both | `exw(admin) customers invite dev@e2e.test --role developer`; `… ro@e2e.test --role read-only` | exit 0 |
| 12 | both sign up | `printf 'pw\n' \| exw(dev) signup dev@e2e.test`; `… \| exw(ro) signup ro@e2e.test` | exit 0, tokens stored |
| 13a | dev write allowed | `exw(dev) flags create dev-made --type boolean` | exit 0 (developer holds `:create`) |
| 13b | read-only denied | `exw(ro) flags create nope --type boolean` | non-zero exit (403) |
| 14 | reset password | `exw(admin) customers reset-password dev@e2e.test` | exit 0 |
| 15 | old token dead | `exw(dev) whoami` (dev's pre-reset token still on disk) | non-zero exit (401) |

**Reconciled against the specs:**
- **Evaluate steps use raw `curl`** — there is no CLI `evaluate` command (cli.md
  has none; evaluation is sdk-key-only). Expected, not a gap.
- **Flag typing for determinism:** `beta` is boolean (clean off→on→true).
  `gradual` is percentage but is asserted via the **assignment override**
  (resolution order #1 beats the kill switch/percentage) rather than a raw 50%
  bucket outcome — so the suite never flakes on the hash. Anonymous eval of
  `gradual` → `false` (percentage flags resolve false without an identifier,
  evaluation.md).

## CI job (`e2e`)

New job in `.github/workflows/ci.yml`, `needs: build`:

1. `actions/checkout`, `erlef/setup-beam` (Elixir 1.18 / OTP 27, matching the
   current pin — D27/D31).
2. Install Burrito's build deps: **zig** (pinned, e.g. `mlugg/setup-zig@v2` with a
   fixed version) + `apt-get install -y xz-utils p7zip-full` + `jq`.
3. Cache `deps`, `_build`, `cli/deps`, `cli/_build`, and the zig cache.
4. Build the CLI binary for the host target only:
   `cd cli && BURRITO_TARGET=linux_x86 MIX_ENV=prod mix release` → export
   `EXWEAVER_CLI=<path to burrito_out binary>`.
5. Run `bash test/e2e/scenario.sh` (which builds the server release, boots it,
   runs all 15 beats, tears down). Non-zero exit fails the job.

Building only the host target keeps the Burrito step to ~1–2 min cold, cached
thereafter. All four target binaries + publishing stay in **C18**.

## Local usage

```bash
# zig-free: drives the CLI via mix run (no EXWEAVER_CLI set)
bash test/e2e/scenario.sh

# against the real binary: build it, then point the script at it
cd cli && BURRITO_TARGET=linux_x86 MIX_ENV=prod mix release && cd ..
EXWEAVER_CLI="$PWD/cli/burrito_out/exweaver_linux_x86" bash test/e2e/scenario.sh
```

Hermetic either way: temp `DATABASE_PATH`, per-identity `XDG_CONFIG_HOME` — never
touches the dev's real `~/.config/exweaver/credentials` or a shared DB.

## Out of scope (deferred to C18)

- A real health endpoint (readiness here polls an existing route instead).
- Building/publishing all four Burrito targets + the server release on tag.
- Any container-image distribution decision.

## Risks / watch-items during implementation

- **Exact Burrito output path/filename** — CI expects `cli/burrito_out/exweaver_linux_x86`
  with a glob fallback; confirm on the first CI build.
- **zig version compatibility** with Burrito 1.5.0 — CI pins zig 0.14.0; confirm
  on the first CI run (no zig locally, so the binary path is unverified here —
  the scenario logic itself is fully verified via the `mix run` path).
- **Readiness race** — bootstrap runs before the endpoint serves; the HTTP poll
  (not a fixed sleep) guards it, with an overall timeout so a boot failure fails
  fast instead of hanging.
- **`mix run` fallback must use `MIX_ENV=dev`** (not prod) so `run_cli` stays
  false and `Application.start` doesn't hit the Burrito.Util.Args path.
