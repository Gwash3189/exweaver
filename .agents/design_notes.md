# Design Notes & Open Questions

All prior open questions were resolved 2026-07-12 (self-signup → pre-approved emails D17; bootstrap → EXWEAVER_ADMIN_EMAIL D18; token expiry D19; rate limiting → ETS D20; email delivery → dropped, CLI-only D15). Only what follows is open.

All four remaining questions resolved 2026-07-12: Burrito binary in `cli/` (D22), TLS via reverse proxy only (D23), multi-company supported via operator mix task (D24).

## Open questions
None blocking. Design is settled; next step is scaffolding the Phoenix app per conventions.md.

## Doc map
- AGENTS.md — project overview, principles (root)
- database_diagram.md — schema, unique constraints, deletion rules
- rest_api.md — endpoint surface
- authentication.md — CLI/SDK auth flows (password + tokens)
- cli.md — CLI command surface
- evaluation.md — canonical flag resolution + bucketing semantics
- glossary.md — terminology (customer vs end_user etc.)
- decisions.md — ADR-lite log + v0 non-goals
- conventions.md — contexts, testing, migrations, API conventions
