# Sign-Up Flow (Passwordless)

## 1. Registration (`POST /api/v1/auth/register`)

> [!NOTE]
> For self-hosted instances, this endpoint should be disabled by default via an environment variable (e.g., `ALLOW_PUBLIC_REGISTRATION=false`) to prevent unauthorized tenant creation. If disabled, tenants must be created via the CLI bootstrap task (see `initial_setup_flow.md`), and new users must be invited by an admin.
**Payload**: `{ "email": "admin@example.com", "company_name": "Acme Corp" }`

1. **Database TX Start:**
   - Insert new `company` (UUID generated).
   - Insert new `team_member` linked to `company_id`.
   - Insert new `team_member_role` linking the new member to the seeded "admin" `role_id`.
2. **Database TX Commit.**
3. Generate a secure 6-digit One Time Password (OTP).
4. Hash the OTP (e.g., via Argon2/Bcrypt) and insert into `team_member_one_time_code` with an expiration time.
5. Dispatch email containing the plaintext OTP via background job (e.g., Oban).
6. Return `202 Accepted` to client.

## 2. Verification (`POST /api/v1/auth/verify`)
**Payload**: `{ "email": "admin@example.com", "otp": "123456" }`

1. Lookup `team_member` by email.
2. Lookup unexpired `team_member_one_time_code` for the member.
3. Hash the provided OTP and compare against the stored hash.
4. **Database TX Start:**
   - If match: Delete the `team_member_one_time_code` record.
5. **Database TX Commit.**
6. Generate JWT containing `{ "sub": team_member_id, "company_id": company_id }`.
7. Return `200 OK` with `{ "token": "jwt_string" }` to client.
