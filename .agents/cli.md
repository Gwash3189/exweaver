# CLI Command Surface (`exweaver`)

The CLI is the only interface in v0. Thin wrapper over the REST API (rest_api.md) — no client-side logic beyond credential storage and output formatting.

## Config
- Credentials: `~/.config/exweaver/credentials` (mode 0600) — token + server URL.
- Server URL: `exweaver config set-server https://flags.internal` (or `EXWEAVER_SERVER` env var).
- Global flags: `--json` for machine-readable output.

## Commands → endpoints
| Command | Endpoint |
|---|---|
| `exweaver signup <email>` (prompts password; `--expires 30d`) | POST /auth/signup |
| `exweaver login <email>` (prompts password; `--expires 30d`) | POST /auth/login |
| `exweaver logout` | DELETE /access_keys/:id + delete local file |
| `exweaver whoami` | GET /customers (self) |
| `exweaver flags list` | GET /flags |
| `exweaver flags create <key> --name "..." --type boolean` | POST /flags |
| `exweaver flags delete <key>` (confirms) | DELETE /flags/:id |
| `exweaver flags on <key> --env <env_key>` | PUT .../state `{state: "on"}` |
| `exweaver flags off <key> --env <env_key>` | PUT .../state `{state: "off"}` |
| `exweaver flags rollout <key> --env <env_key> --percentage 25` | PUT .../state |
| `exweaver flags assign <key> <identifier> --env <env_key> --state on\|off` | PUT .../assignments/:end_user_id |
| `exweaver flags unassign <key> <identifier> --env <env_key>` | DELETE .../assignments/:end_user_id |
| `exweaver end-users list\|create\|delete` | /end_users |
| `exweaver envs list\|create\|delete` | /environments |
| `exweaver companies create <name> --admin-email <email>` | POST /companies |
| `exweaver customers list` | GET /customers |
| `exweaver customers invite <email> --role developer` | POST /customers |
| `exweaver customers reset-password <email>` | POST /customers/:id/reset |
| `exweaver customers remove <email>` | DELETE /customers/:id |
| `exweaver keys list` | GET /access_keys |
| `exweaver keys create <name> --env <env_key>` (sdk key, shown once) | POST /access_keys |
| `exweaver keys revoke <id>` | DELETE /access_keys/:id |
| `exweaver roles list` | GET /roles |

CLI resolves flag/environment keys to ids via lookups; users never type UUIDs except `keys revoke`.

## Behavior conventions
- 401 `token_expired` → print "token expired, run `exweaver login`" and exit 1.
- Destructive commands (`delete`, `remove`, `revoke`) prompt for confirmation unless `--yes`.
- Secrets (tokens, keys) printed once to stdout, everything else to a table; `--json` disables tables.

## Distribution
Burrito standalone binary (D22) — users don't need Erlang/Elixir installed. Source lives in `cli/` as its own mix project in the same repo. Build targets: macOS (arm64/x86_64) and Linux (arm64/x86_64).
