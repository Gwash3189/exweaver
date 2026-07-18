    erDiagram
        %% all uuid's are UUIDv7

        %% Root tenant. Groups all data for a single B2B customer.
        company {
            uuid id
            datetime created_at
            datetime updated_at
        }

        %% Direct users (devs, PMs) logging into CLI/Dashboard.
        %% unique: (email)
        team_member {
            uuid id
            datetime created_at
            datetime updated_at
            string email
            uuid company_id
        }

        %% Passwordless auth. Stores hashed OTPs sent via email.
        team_member_one_time_code {
            uuid id
            datetime created_at
            datetime updated_at
            datetime expired_at
            string hashed_value
            uuid team_member_id
        }

        %% Customers of the company. Used for targeted user overrides.
        %% unique: (company_id, identifier)
        end_user {
            uuid id
            datetime created_at
            datetime updated_at
            string identifier
            uuid company_id
        }

        %% Deployment stages (Dev, Staging, Prod). Allows safe testing.
        %% unique: (company_id, name)
        environment {
            uuid id
            datetime created_at
            datetime updated_at
            string name
            uuid company_id
        }

        %% Feature toggle identity/metadata.
        %% `exposable` prevents leaking backend secrets to public frontend SDKs.
        %% unique: (company_id, name)
        flag {
            uuid id
            datetime created_at
            datetime updated_at
            string name
            %% simple, percentage
            enum type
            uuid company_id
            boolean exposable
        }

        %% Runtime behavior. Decouples flag identity from state.
        %% Example: Flag is ON at 100% in Dev, OFF at 0% in Prod.
        %% unique: (flag_id, environment_id)
        flag_environment_state {
            uuid id
            datetime created_at
            datetime updated_at
            uuid flag_id
            uuid environment_id
            %% on, off
            enum state
            %% 0 - 100
            number percentage
        }

        %% Manual overrides.
        %% "Turn this flag ON for just this end_user in Staging".
        %% unique: (flag_id, environment_id, end_user_id)
        flag_assignment {
            uuid id
            datetime created_at
            datetime updated_at
            uuid end_user_id
            boolean state
            uuid team_member_id
            uuid flag_id
            uuid environment_id
        }

        %% API Keys for SDKs to evaluate flags. Scoped to environment.
        %% Client type: Public, read-only. Server type: Secret, full access.
        access_key {
            uuid id
            datetime created_at
            datetime updated_at
            string name
            %% client (public), server (secret)
            enum type
            %% hashed value for server keys; plain prefix/public string for client keys
            string hashed_value
            uuid environment_id
        }

        %% Security history. Tracks who changed what flag state and when.
        audit_log {
            uuid id
            datetime created_at
            datetime updated_at
            %% create, update, delete, read
            enum action
            uuid team_member_id
            uuid company_id
            uuid entity_id
            uuid environment_id
            %% nullable
            jsonb old_state
            %% nullable
            jsonb new_state
        }

        %% RBAC: Seeded roles ("admin", "developer").
        %% unique: (name)
        role {
            uuid id
            datetime created_at
            datetime updated_at
            string name
        }

        %% RBAC: Seeded permissions ("create", "read").
        %% unique: (name)
        permission {
            uuid id
            datetime created_at
            datetime updated_at
            string name
        }

        %% RBAC: Joins roles to permissions.
        %% unique: (role_id, permission_id)
        role_permission {
            uuid id
            datetime created_at
            datetime updated_at
            uuid role_id
            uuid permission_id
        }

        %% RBAC: Joins team members to roles.
        %% unique: (team_member_id, role_id)
        team_member_role {
            uuid id
            datetime created_at
            datetime updated_at
            uuid team_member_id
            uuid role_id
        }

        %% Relationships
        company ||--o{ team_member : "has many"
        company ||--o{ end_user : "has many"
        company ||--o{ flag : "has many"
        company ||--o{ environment : "has many"

        environment ||--o{ flag_environment_state : "has many"
        environment ||--o{ access_key : "has many"
        environment ||--o{ flag_assignment : "has many"

        flag ||--o{ flag_environment_state : "has many"
        flag ||--o{ flag_assignment : "has many"

        end_user ||--o{ flag_assignment : "has many"
        team_member ||--o{ audit_log : "performs"

        team_member ||--o{ team_member_role : "has many"
        team_member ||--o{ team_member_one_time_code : "has many"
        role ||--o{ team_member_role : "has many"
        role ||--o{ role_permission : "has many"
        permission ||--o{ role_permission : "has many"
