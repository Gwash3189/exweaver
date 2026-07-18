#!/usr/bin/env bash
# Shared helpers for the C17 end-to-end scenario (see .agents/c17_e2e_plan.md).
#
# Sourced by scenario.sh. Provides: coloured logging, fail-fast assertions, the
# binary-agnostic CLI invoker (`exw`), a curl-based flag evaluator, and the
# server lifecycle (build/boot/readiness/teardown). No Docker — the whole
# topology is one backgrounded process + a temp dir, cleaned up by a trap.

# --- logging ----------------------------------------------------------------

if [ -t 1 ]; then
  _GREEN=$'\033[32m'; _RED=$'\033[31m'; _BLUE=$'\033[34m'; _DIM=$'\033[2m'; _RESET=$'\033[0m'
else
  _GREEN=''; _RED=''; _BLUE=''; _DIM=''; _RESET=''
fi

section() { printf '\n%s== %s ==%s\n' "$_BLUE" "$1" "$_RESET"; }
info()    { printf '%s   %s%s\n' "$_DIM" "$1" "$_RESET"; }
pass()    { printf '   %sPASS%s %s\n' "$_GREEN" "$_RESET" "$1"; }
die()     { printf '   %sFAIL%s %s\n' "$_RED" "$_RESET" "$1" >&2; exit 1; }

# --- assertions (fail-fast: the scenario is linear, so stop at the first break)

# expect_ok "<desc>" <cmd...>   — command must exit 0
expect_ok() {
  local desc="$1"; shift
  if "$@"; then pass "$desc"; else die "$desc (unexpected exit $?)"; fi
}

# expect_fail "<desc>" <cmd...> — command must exit non-zero
expect_fail() {
  local desc="$1"; shift
  if "$@"; then die "$desc (expected failure, got exit 0)"; else pass "$desc"; fi
}

# expect_eq "<desc>" "<expected>" "<actual>"
expect_eq() {
  if [ "$2" = "$3" ]; then pass "$1"; else die "$1 (expected '$2', got '$3')"; fi
}

# --- CLI invocation ---------------------------------------------------------
#
# `exw <identity> <args...>` runs the CLI as the given identity (its own
# XDG_CONFIG_HOME, so tokens never collide). Resolution:
#   * $EXWEAVER_CLI set   -> the real Burrito binary (CI).
#   * otherwise           -> `mix run` under MIX_ENV=dev, so run_cli stays false
#     and Application.start never touches Burrito.Util.Args; we call
#     CLI.main(System.argv()) directly and it halts with the command exit code.

exw() {
  local id="$1"; shift
  if [ -n "${EXWEAVER_CLI:-}" ]; then
    XDG_CONFIG_HOME="$CFG_BASE/$id" "$EXWEAVER_CLI" "$@"
  else
    ( cd "$REPO/cli" \
      && XDG_CONFIG_HOME="$CFG_BASE/$id" \
         MIX_ENV=dev mix run --no-compile -e 'ExweaverCli.CLI.main(System.argv())' -- "$@" )
  fi
}

# --- evaluation over raw HTTP (no CLI evaluate command exists) ---------------
#
# eval_flag <sdk_token> <flag_key> [end_user]  -> echoes the boolean value.

eval_flag() {
  local sdk="$1" flag="$2" end_user="${3:-}"
  local url="$BASE/api/v1/evaluate/$flag"
  [ -n "$end_user" ] && url="$url?end_user=$end_user"
  curl -sS -H "Authorization: Bearer $sdk" "$url" | jq -r ".flags.\"$flag\""
}

# --- server lifecycle -------------------------------------------------------

start_server() {
  section "Server: build + boot (prod release, fresh SQLite)"

  if [ -n "${EXWEAVER_CLI:-}" ] || [ "${E2E_SKIP_RELEASE:-}" != "1" ]; then
    info "building prod release…"
    ( cd "$REPO" && MIX_ENV=prod mix release --overwrite >/dev/null )
  else
    info "reusing existing prod release (E2E_SKIP_RELEASE=1)"
  fi

  local bin="$REPO/_build/prod/rel/exweaver/bin/exweaver"
  [ -x "$bin" ] || die "server release binary not found at $bin"

  PHX_SERVER=true \
  PORT="$PORT" \
  DATABASE_PATH="$DB" \
  SECRET_KEY_BASE="$SECRET_KEY_BASE" \
  EXWEAVER_ADMIN_EMAIL="$ADMIN_EMAIL" \
    "$bin" start >"$WORK/server.log" 2>&1 &
  SERVER_PID=$!
  info "server pid $SERVER_PID, port $PORT, db $DB"

  # Readiness: poll an unauthenticated management route (401 when up). This does
  # NOT touch the auth endpoints, so it never consumes the per-IP auth rate
  # budget the scenario's real signups need.
  local waited=0
  until [ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/v1/environments")" != "000" ]; do
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
      cat "$WORK/server.log" >&2
      die "server exited during boot"
    fi
    sleep 0.3
    waited=$((waited + 1))
    if [ "$waited" -gt 100 ]; then          # ~30s
      cat "$WORK/server.log" >&2
      die "server did not become ready within 30s"
    fi
  done
  pass "server ready on $BASE"
}

stop_server() {
  [ -n "${SERVER_PID:-}" ] && kill "$SERVER_PID" 2>/dev/null
  [ -n "${WORK:-}" ] && rm -rf "$WORK"
}
