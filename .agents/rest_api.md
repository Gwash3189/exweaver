# REST API (v0)

All endpoints prefixed `/api/v1`, JSON in/out. UUIDv7 ids. Conventions (errors, pagination) in conventions.md; terms in glossary.md.

- Auth: `Authorization: Bearer <token>` — personal token for management, sdk key for evaluation. See authentication.md. CLI command mapping in cli.md.
- All resources implicitly scoped to the caller's company; other companies' ids 404.
- Permission mapping: POST=create, GET=read, PATCH/PUT=update, DELETE=delete, enforced via the caller's role.

## Auth endpoints (unauthenticated; ETS rate-limited)
| Method | Path | Notes |
|---|---|---|
| POST | /auth/signup | `{email, password, expires_in}` — pre-approved email only (NULL password); sets password, returns token plaintext once |
| POST | /auth/login | `{email, password, expires_in}` — mints a new personal token |

`expires_in`: `1d\|7d\|14d\|30d\|90d\|never`, default `30d`.

## Management API (personal-token auth)

### Companies (create-only — D24)
| Method | Path | Notes |
|---|---|---|
| POST | /companies | `{name, admin_email}` — caller must have `admin` role; creates the company, its default environments, and a pre-approved admin customer. No read/list/delete endpoints in v0 |

### Environments
| Method | Path | Notes |
|---|---|---|
| GET | /environments | list |
| POST | /environments | `{name, key}` — key immutable; creates an off flag_state for every existing flag |
| PATCH | /environments/:id | `{name}` |
| DELETE | /environments/:id | cascades states/assignments/sdk keys; last environment not deletable (422) |

### Flags
| Method | Path | Notes |
|---|---|---|
| GET | /flags | list, includes state per environment |
| POST | /flags | `{key, name, type}` — type `boolean` \| `percentage`; key immutable; creates off states in all environments |
| GET | /flags/:id | |
| PATCH | /flags/:id | `{name}` only |
| DELETE | /flags/:id | cascades states + assignments |

### Flag state (one row per flag × environment; created automatically, never POSTed)
| Method | Path | Notes |
|---|---|---|
| GET | /flags/:id/environments/:environment_id/state | |
| PUT | /flags/:id/environments/:environment_id/state | `{state: "on"\|"off", percentage: 0..100}` — percentage only valid for percentage-type flags |

### Flag assignments (per-end-user overrides, per environment)
| Method | Path | Notes |
|---|---|---|
| GET | /flags/:id/environments/:environment_id/assignments | list |
| PUT | /flags/:id/environments/:environment_id/assignments/:end_user_id | `{state: true\|false}` — upsert |
| DELETE | /flags/:id/environments/:environment_id/assignments/:end_user_id | |

### End users
| Method | Path | Notes |
|---|---|---|
| GET | /end_users | `?identifier=` filter |
| POST | /end_users | `{identifier}` — unique per company; not auto-created by evaluation (D13) |
| DELETE | /end_users/:id | cascades assignments |

### Customers (team members)
| Method | Path | Notes |
|---|---|---|
| GET | /customers | list; response indicates pending (no password) vs active |
| POST | /customers | `{email, role_id}` — pre-approve; they complete via `/auth/signup` |
| PATCH | /customers/:id | `{role_id}` |
| POST | /customers/:id/reset | admin-only: clears password, revokes their personal tokens; user signs up again |
| DELETE | /customers/:id | cascades their personal tokens |

### Access keys
| Method | Path | Notes |
|---|---|---|
| GET | /access_keys | both kinds; never returns value |
| POST | /access_keys | `{name, kind: "sdk", environment_id}` — plaintext returned once. (`personal` keys are minted by `/auth/signup` and `/auth/login`, not here) |
| DELETE | /access_keys/:id | revoke |

### Roles (seed data, read-only)
| Method | Path |
|---|---|
| GET | /roles |

## Evaluation API (sdk-key auth only; environment comes from the key)
| Method | Path | Notes |
|---|---|---|
| GET | /evaluate?end_user=<identifier> | all flags resolved |
| GET | /evaluate/:flag_key?end_user=<identifier> | single flag |

Response `{"flags": {"<flag_key>": true, ...}}`. `end_user` optional (anonymous — see evaluation.md). Resolution order, bucketing hash, and stickiness are specified canonically in **evaluation.md** — do not restate them elsewhere.

Sdk keys (role `automated`) are rejected on all management endpoints; personal tokens are rejected on `/evaluate*`. Expired tokens → 401 `token_expired`.
