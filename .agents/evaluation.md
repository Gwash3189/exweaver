# Flag Evaluation Semantics (canonical)

Server-side evaluation only in v0 — SDKs call the API, they never evaluate locally. This document is the single source of truth; rest_api.md links here.

## Inputs
- Environment: taken from the sdk access key. Never a request parameter.
- End user: `end_user` query param (the opaque `identifier`). Optional — anonymous evaluation gets no assignments and no percentage bucketing (percentage flags resolve to `false` without an identifier).
- Unknown end_user identifiers are NOT auto-created; they simply have no assignments. (`POST /end_users` is the only way to create them — revisit post-v0.)

## Resolution order (per flag)
1. **Assignment override** — a `flag_assignment` row for (flag, environment, end_user) → return its `state`. Checked even when the flag is off.
2. **Kill switch** — `flag_state.state = off` → `false`.
3. **Boolean flag** — `flag.type = boolean` and state is on → `true`.
4. **Percentage flag** — `flag.type = percentage` and state is on → `bucket(flag, end_user) < percentage`.

## Bucketing (stickiness)
```
bucket = rem(
  :binary.decode_unsigned(:crypto.hash(:sha256, flag.key <> ":" <> end_user.identifier)),
  100
)
```
- Deterministic: same user + same flag → same result every request.
- Independent across flags (flag key is in the hash input).
- Same across environments (environment is deliberately excluded — a user in the 30% bucket in dev is in it in prod).
- Raising the percentage only ever adds users; lowering removes the most recently included ones. Nobody flaps.

## Response shape
```json
{ "flags": { "new-checkout": true, "dark-mode": false } }
```
Flags are keyed by `flag.key`. Values are always booleans in v0.
