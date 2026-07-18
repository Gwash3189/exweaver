# Initial Setup Flow (Self-Hosted)

For a developer or sysadmin spinning up ExWeaver for the first time in their infrastructure.

## 1. Infrastructure Boot
1. Start the Phoenix application (via Docker or `mix phx.server`). SQLite database will be created automatically.

## 2. Database Initialization
1. Run migrations: `mix ecto.migrate`
2. Run seeds: `mix run priv/repo/seeds.exs`
   - *This step guarantees core RBAC records (`role`, `permission`) exist in the database.*

## 3. Root Tenant Bootstrap
Since SMTP might not be configured immediately, the system provides a CLI task to bypass the email loop for the first user.

1. **Run Bootstrap Task:** 
   `mix exweaver.bootstrap --company "Acme Corp" --email "admin@acme.com"`
2. **System Behavior:**
   - Creates the `company` record.
   - Creates the `team_member` record.
   - Assigns the "admin" role.
   - Generates and outputs a **One-Time Password (OTP)** directly to the terminal stdout.
3. **Login:**
   - The developer takes the OTP from stdout.
   - Submits `POST /api/v1/auth/verify` with the email and OTP.
   - Receives the initial JWT to access the system.

> [!NOTE]
> If SMTP is pre-configured and the `ALLOW_PUBLIC_REGISTRATION=true` environment variable is set, the developer can skip the CLI task entirely and use `POST /api/v1/auth/register` directly from the UI.
