# Glossary

Use these terms exactly — in docs, code, and API — never synonyms.

| Term | Meaning | Not to be confused with |
|---|---|---|
| **company** | A tenant. One self-host install usually has one. Everything is scoped to it. | — |
| **customer** | A team member of a company — OUR direct user. Authenticates via CLI. Has exactly one role. A customer with a NULL password is "pre-approved" (invited, not yet signed up). | end_user |
| **end_user** | The customer's customer — the person whose flags get evaluated. Identified only by an opaque `identifier` string the SDK supplies. Never logs in. | customer |
| **environment** | A deployment context (production, development, …) owned by a company. Flag *state* is per-environment; flag *definitions* are not. | — |
| **flag** | A feature flag definition: key, name, type. Exists once per company. | flag_state |
| **flag state** | The on/off + percentage of one flag in one environment. | flag |
| **flag assignment** | A per-end-user override of a flag in an environment ("turn it on just for me"). | flag_state |
| **flag key** | The stable slug SDKs evaluate by (`new-checkout`). Immutable after creation. `name` is the mutable display label. | flag name |
| **access key** | A bearer token. `personal` kind = a customer's CLI token (optional expiry); `sdk` kind = environment-scoped evaluation key. | password |
| **password** | The customer's login secret, set once at CLI signup, bcrypt-hashed. Used only to mint access keys — never sent on API calls. | access key |
| **role** | Named permission bundle: developer, admin, read-only, automated. Global seed data. | permission |
| **permission** | Atomic capability: create, read, update, delete. Global seed data. | role |

Decision: we keep `customer` (rather than renaming to `member`/`user`) — see decisions.md D3.
