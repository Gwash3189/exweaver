import Config

# By default the OTP application does not run the command line when started
# (so `mix test` / `mix format` can boot it harmlessly). `config/runtime.exs`
# flips this on for the packaged release binary.
config :exweaver_cli, run_cli: false
