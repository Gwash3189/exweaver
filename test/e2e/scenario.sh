#!/usr/bin/env bash
# C17 end-to-end scenario (see .agents/c17_e2e_plan.md). The scenario IS the
# test: it drives the real server (prod release) and the real CLI against a
# fresh SQLite DB, asserting the full product loop. Any failed assertion exits
# non-zero and fails the run / CI job.
#
#   Local (zig-free):   bash test/e2e/scenario.sh
#   Against the binary: EXWEAVER_CLI=/path/to/exweaver bash test/e2e/scenario.sh
#
# Hermetic: throwaway DATABASE_PATH + per-identity XDG_CONFIG_HOME under a temp
# dir. Never touches your real ~/.config/exweaver/credentials or a shared DB.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=test/e2e/lib.sh
source "$REPO/test/e2e/lib.sh"

# --- config -----------------------------------------------------------------

WORK="$(mktemp -d)"
CFG_BASE="$WORK/cfg"
DB="$WORK/e2e.db"
PORT="${PORT:-4111}"
BASE="http://127.0.0.1:$PORT"
SECRET_KEY_BASE="$( (cd "$REPO" && mix phx.gen.secret) 2>/dev/null || openssl rand -base64 48 )"

ADMIN_EMAIL="admin@e2e.test"
DEV_EMAIL="dev@e2e.test"
RO_EMAIL="ro@e2e.test"
PASSWORD="e2e-password-123"

trap stop_server EXIT

# --- setup ------------------------------------------------------------------

for id in admin dev ro; do mkdir -p "$CFG_BASE/$id"; done

if [ -z "${EXWEAVER_CLI:-}" ]; then
  section "CLI: precompile (mix run fallback, no zig)"
  ( cd "$REPO/cli" && MIX_ENV=dev mix compile >/dev/null ) || die "CLI compile failed"
  pass "CLI compiled"
else
  info "using CLI binary: $EXWEAVER_CLI"
fi

start_server

section "CLI: point every identity at the server"
for id in admin dev ro; do
  expect_ok "config set-server ($id)" exw "$id" config set-server "$BASE"
done

# --- scenario ---------------------------------------------------------------

section "1–2. Bootstrap admin + signup"
# The server booted with EXWEAVER_ADMIN_EMAIL, so the admin exists pending.
# signup sets the password and mints the first personal token.
printf '%s\n' "$PASSWORD" | expect_ok "admin signs up (sets password, mints token)" \
  exw admin signup "$ADMIN_EMAIL"

section "3. Create flags"
expect_ok "create boolean flag 'beta'"       exw admin flags create beta --type boolean
expect_ok "create percentage flag 'gradual'" exw admin flags create gradual --type percentage

section "4. Mint an sdk key for production"
sdk_json="$(exw admin keys create ci --env production --json)" || die "keys create failed"
SDK="$(printf '%s' "$sdk_json" | jq -r '.token')"
if [ -n "$SDK" ] && [ "$SDK" != "null" ]; then pass "minted sdk key"; else die "no token in: $sdk_json"; fi

section "5. Evaluate with the flag off"
expect_eq "beta evaluates false (state off)" "false" "$(eval_flag "$SDK" beta u1)"

section "6–7. Turn beta on, evaluate again"
expect_ok "turn beta on in production" exw admin flags on beta --env production
expect_eq "beta evaluates true (state on)" "true" "$(eval_flag "$SDK" beta u1)"

section "8. Percentage rollout"
expect_ok "roll gradual out to 50% in production" \
  exw admin flags rollout gradual --env production --percentage 50
# Anonymous evaluation of a percentage flag is always false (no identifier).
expect_eq "gradual anonymous -> false" "false" "$(eval_flag "$SDK" gradual)"

section "9–10. Per-user assignment overrides the rollout"
expect_ok "assign u1=on for gradual" \
  exw admin flags assign gradual u1 --env production --state on
expect_eq "gradual for u1 -> true (assignment beats %)" "true" "$(eval_flag "$SDK" gradual u1)"

section "11–12. Invite a developer and a read-only member; both sign up"
expect_ok "invite $DEV_EMAIL as developer" exw admin customers invite "$DEV_EMAIL" --role developer
expect_ok "invite $RO_EMAIL as read-only"  exw admin customers invite "$RO_EMAIL" --role read-only
printf '%s\n' "$PASSWORD" | expect_ok "developer signs up" exw dev signup "$DEV_EMAIL"
printf '%s\n' "$PASSWORD" | expect_ok "read-only signs up" exw ro  signup "$RO_EMAIL"

section "13. RBAC: developer may write, read-only may not"
expect_ok   "developer creates a flag (has :create)" \
  exw dev flags create dev-made --type boolean
expect_fail "read-only is denied creating a flag (403)" \
  exw ro flags create nope --type boolean

section "14–15. Reset the developer's password; their old token is dead"
expect_ok   "admin resets developer's password (revokes tokens)" \
  exw admin customers reset-password "$DEV_EMAIL"
expect_fail "developer's pre-reset token no longer works (401)" \
  exw dev whoami

section "Done"
printf '%s✔ all end-to-end assertions passed%s\n' "$_GREEN" "$_RESET"
