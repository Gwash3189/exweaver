# REST API Design
Prefix: `/api/v1`
Format: JSON

## Global Behaviors
- **Multi-tenancy:** All endpoints (except public auth/eval) require a valid JWT. The `company_id` is strictly inferred from the JWT. It is never passed in the URL.
- **Pagination:** Collection endpoints (`GET`) accept `?page=` and `?page_size=` query parameters.

## Authentication & Registration
- `POST /auth/register` (Creates initial `company` and admin `team_member`)
- `POST /auth/login` (Generate passwordless OTP)
- `POST /auth/verify` (Exchange OTP for JWT/Session)

## Flags
- `GET /flags`
- `POST /flags`
- `GET /flags/:id`
- `PUT /flags/:id`
- `DELETE /flags/:id`

## Flag States (per Environment)
- `GET /flags/:flag_id/environments/:env_id/state`
- `PUT /flags/:flag_id/environments/:env_id/state` (Update state enum or percentage)

## Flag Assignments (Overrides)
- `GET /flags/:flag_id/environments/:env_id/assignments`
- `POST /flags/:flag_id/environments/:env_id/assignments` (Payload requires `end_user_id` UUID)
- `DELETE /flags/:flag_id/environments/:env_id/assignments/:id`

## Environments
- `GET /environments`
- `POST /environments`
- `GET /environments/:id`
- `PUT /environments/:id`
- `DELETE /environments/:id`

## Access Keys
- `GET /environments/:env_id/keys`
- `POST /environments/:env_id/keys`
- `DELETE /environments/:env_id/keys/:id`

## End Users
- `GET /users`
- `POST /users` (Upsert via string `identifier`)
- `GET /users/:id` (Path parameter must be the `id` UUID)

## Team & Roles
- `GET /team-members`
- `POST /team-members` (Invites a new member to the company)
- `DELETE /team-members/:id`
- `GET /roles` (Lists seeded roles for UI population)
- `GET /permissions` (Lists seeded permissions)
- `PUT /team-members/:id/roles` (Assigns roles to a member)

## Audit
- `GET /audit-logs` (Filterable via query params: `?entity_id=`, `?env_id=`, `?team_member_id=`)

## Evaluation API (For SDKs)
*Requires `Authorization: Bearer <access_key>`*
- `GET /evaluate` (Server keys only: returns all flags and states for the environment for local caching)
- `POST /evaluate` (Payload: `{ "user_identifier": "..." }`. Evaluates and creates/upserts the `end_user` implicitly. Returns evaluated flag states considering assignments/percentage rollouts)
