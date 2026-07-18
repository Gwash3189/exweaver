import Config

# The Burrito binary is built and run under the :prod release. Only then do we
# want `ExweaverCli.Application.start/2` to parse argv and run a command; under
# :dev/:test the app boots as an idle supervisor so the test suite can run.
if config_env() == :prod do
  config :exweaver_cli, run_cli: true
end
