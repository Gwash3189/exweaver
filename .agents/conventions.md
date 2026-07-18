# Code, Testing & Migration Conventions

## Project layout (Phoenix contexts)
| Context | Owns tables | Responsibility |
|---|---|---|
| `Exweaver.Accounts` | company, customer, role, permission, role_permission | tenancy, team members, password set/verify (bcrypt), RBAC checks |
| `Exweaver.Auth` | access_key | token mint/verify/revoke (both kinds), expiry, the `exw_` format, ETS rate limiting |
| `Exweaver.Flags` | flag, flag_state, flag_assignment, environment | all flag CRUD + environment CRUD |
| `Exweaver.Evaluation` | (reads flags tables) | the eval path only — kept separate so the hot path stays small and obviously read-only |
| `ExweaverWeb` | — | REST controllers (`/api/v1`) and plugs for auth + RBAC. No HTML/LiveView in v0 (D15) |
| `ExweaverCli` | — | the `exweaver` CLI: arg parsing, credential file, HTTP client, table output. Own mix project in `cli/`, shipped as a Burrito binary (D22) |

Rules:
- Controllers never call `Repo` — everything goes through a context.
- Cross-context calls go through public context functions only.
- Company scoping happens in context functions (every public function takes the company or an authed actor struct) — never trust ids from params.

## Testing
- Context tests are the backbone: business rules, constraints, evaluation semantics live here.
- Controller tests cover: auth required, RBAC enforced, company isolation (a resource from another company 404s), and response shape. Not business logic.
- evaluation.md semantics get an exhaustive test module (`EvaluationTest`) — every branch of the resolution order, plus bucketing determinism/monotonicity.
- Fixtures via plain functions in `test/support/fixtures/` (Phoenix generator style), no factories library.
- Every unique constraint in database_diagram.md gets a test asserting the friendly changeset error.

## Migrations
- Additive-only once a version is released — self-hosters upgrade in place; never rename/drop columns in the same release that stops writing them.
- Destructive cleanup allowed only two releases later, and noted in the changelog.
- Seed data (roles, permissions, default environments) is idempotent — safe to run on every deploy.

## API conventions
- Errors: `{"error": {"code": snake_case, "message": human}}`; 401 unauthenticated, 403 wrong role, 404 wrong company or missing, 422 validation.
- Pagination: `?after=<uuid>&limit=<n>` on all list endpoints (UUIDv7 order).
- Timestamps in responses are UTC ISO8601.
