# Exweaver

A self-hosted feature flag service. The server exposes a JSON REST API under
`/api/v1`, and the `exweaver` CLI is the primary way to manage flags.

## Requirements

- Elixir and Erlang/OTP
- SQLite (the database file is created automatically)

## Getting started

Install dependencies and set up the database:

```sh
mix setup
```

Start the server. On first boot, set `EXWEAVER_ADMIN_EMAIL` to seed a company
and a pre-approved admin. This is idempotent and only takes effect while no
customers exist:

```sh
EXWEAVER_ADMIN_EMAIL=admin@acme.com mix phx.server
```

The API is now available at http://localhost:4000. Set `PORT` to change the
port.

The server speaks plain HTTP. For anything beyond localhost, run it behind a
reverse proxy (Caddy, nginx) that terminates TLS — passwords and tokens are
bearer secrets and must never cross plain HTTP.

## Using the CLI

Point the CLI at your server, then complete signup for the pre-approved admin
email. Signup sets the password and prints a personal token, stored locally:

```sh
exweaver config set-server http://localhost:4000
exweaver signup admin@acme.com
```

From then on, manage flags:

```sh
exweaver flags create new-checkout --name "New checkout" --type boolean
exweaver flags list
exweaver flags on new-checkout --env production
```

Later sessions re-authenticate with:

```sh
exweaver login admin@acme.com
```

Add `--json` to any command for machine-readable output. Run `exweaver --help`
for the full command list.

## Building the CLI

The CLI is a standalone project in `cli/`, packaged as a self-contained binary
(via Burrito) so users don't need Elixir or Erlang installed.

```sh
cd cli
mix deps.get
MIX_ENV=prod mix release
```

This produces binaries for macOS and Linux (arm64 and x86_64) under the release
output directory. Distribute the binary for the target platform and place it on
users' `PATH` as `exweaver`.

## Development

- `mix precommit` — compile with warnings as errors, format, lint, and test
- `mix test` — run the test suite

Run these from the server project and from `cli/` independently, as each is its
own mix project.
