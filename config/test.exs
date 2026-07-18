import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :exweaver, Exweaver.Repo,
  database: Path.expand("../exweaver_test.db", __DIR__),
  # SQLite allows only one writer at a time; a single pooled connection avoids
  # SQLITE_BUSY errors from the sandbox checking out concurrent connections.
  pool_size: 1,
  pool: Ecto.Adapters.SQL.Sandbox

# Exweaver.Bootstrap writes outside the ESpec sandbox transaction (it runs once at
# Application boot, before spec_helper.exs switches Sandbox to :manual). Disable it
# for the test env so it can't permanently seed the test db; its logic is exercised
# directly (and sandboxed) by spec/exweaver/bootstrap_spec.exs instead.
config :exweaver, :run_bootstrap, false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :exweaver, ExweaverWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "23GbNtvihG2RCZJK1zOXwr9DYoGjpOCB7a25RLT6v3TjPdUgXDurTk/e+G8lE5tQ",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
