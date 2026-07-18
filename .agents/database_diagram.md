# Database Model

All ids are UUIDv7. All tables have `inserted_at` / `updated_at` (omitted below for brevity in comments only — they are listed). Unique constraints are enforced at the database level.

```mermaid
erDiagram
    %% a company = one tenant; multi-company per install is supported.
    %% created via POST /companies by an admin (D24); no read/list endpoints
    company {
        uuid id
        datetime inserted_at
        datetime updated_at
        string name
    }

    %% seeded per company with "production" and "development"
    environment {
        uuid id
        datetime inserted_at
        datetime updated_at
        string name
        %% slug, unique (company_id, key)
        string key
        uuid company_id
    }

    %% a flag exists once per company; its STATE varies per environment
    flag {
        uuid id
        datetime inserted_at
        datetime updated_at
        %% display name
        string name
        %% slug SDKs evaluate by, unique (company_id, key)
        string key
        %% boolean | percentage
        enum type
        uuid company_id
    }

    %% exactly one row per (flag, environment) — created for every
    %% environment when a flag is created; defaults to state=off
    flag_state {
        uuid id
        datetime inserted_at
        datetime updated_at
        %% on | off
        enum state
        %% 0-100, only meaningful when flag.type = percentage
        number percentage
        uuid flag_id
        uuid environment_id
    }

    %% per-end-user override ("turn it on just for me"),
    %% scoped to an environment. unique (flag_id, environment_id, end_user_id)
    flag_assignment {
        uuid id
        datetime inserted_at
        datetime updated_at
        boolean state
        uuid flag_id
        uuid environment_id
        uuid end_user_id
    }

    %% our customer's customer — identified by an opaque string
    %% the SDK passes in. unique (company_id, identifier)
    end_user {
        uuid id
        datetime inserted_at
        datetime updated_at
        string identifier
        uuid company_id
    }

    %% a team member of a company (our direct user).
    %% unique (email). exactly one role.
    %% hashed_password is bcrypt; NULL means pre-approved
    %% (invited) but not yet signed up
    customer {
        uuid id
        datetime inserted_at
        datetime updated_at
        string email
        string hashed_password
        uuid company_id
        uuid role_id
    }

    %% seeded globally: developer, admin, read-only, automated
    role {
        uuid id
        datetime inserted_at
        datetime updated_at
        string name
    }

    %% seeded globally: create, read, update, delete
    permission {
        uuid id
        datetime inserted_at
        datetime updated_at
        string name
    }

    %% join table. unique (role_id, permission_id)
    role_permission {
        uuid id
        datetime inserted_at
        datetime updated_at
        uuid role_id
        uuid permission_id
    }

    %% bearer tokens. kind=personal → CLI token owned by a customer,
    %% inherits that customer's role (role_id null, customer_id set).
    %% kind=sdk → environment-scoped evaluation key (customer_id null,
    %% environment_id set, role_id = automated).
    %% value stored hashed (sha256); plaintext shown once at creation.
    %% expired_at NULL = never expires
    access_key {
        uuid id
        datetime inserted_at
        datetime updated_at
        datetime expired_at
        string name
        %% personal | sdk
        enum kind
        string hashed_value
        uuid company_id
        uuid customer_id
        uuid environment_id
        uuid role_id
    }

    company ||--o{ environment : "has many"
    company ||--o{ customer : "has many"
    company ||--o{ end_user : "has many"
    company ||--o{ flag : "has many"
    company ||--o{ access_key : "has many"

    flag ||--o{ flag_state : "one per environment"
    environment ||--o{ flag_state : "has many"

    flag ||--o{ flag_assignment : "has many"
    environment ||--o{ flag_assignment : "has many"
    end_user ||--o{ flag_assignment : "has many"

    role ||--o{ customer : "has many"
    role ||--o{ role_permission : "has many"
    permission ||--o{ role_permission : "has many"

    customer ||--o{ access_key : "personal tokens"
    environment ||--o{ access_key : "sdk keys"
    role ||--o{ access_key : "has many"
```

## Unique constraints (database-enforced)
- `environment (company_id, key)`
- `flag (company_id, key)`
- `flag_state (flag_id, environment_id)`
- `flag_assignment (flag_id, environment_id, end_user_id)`
- `end_user (company_id, identifier)`
- `customer (email)`
- `role (name)`, `permission (name)`, `role_permission (role_id, permission_id)`

## Deletion rules
- Deleting a flag cascades its states and assignments.
- Deleting an environment cascades its states, assignments, and sdk keys; the last environment of a company cannot be deleted.
- Deleting a customer cascades their personal access keys.
- Roles and permissions are seed data; not deletable via API.
