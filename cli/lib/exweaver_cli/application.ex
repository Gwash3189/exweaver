defmodule ExweaverCli.Application do
  @moduledoc """
  OTP entrypoint for the packaged CLI binary.

  Under the Burrito release (`:prod`) the `:run_cli` flag is set (see
  `config/runtime.exs`), so booting the application parses argv and runs the
  requested command, then halts with the command's exit code. Under `:dev`/
  `:test` the flag is false and the app boots as an idle supervisor, which is
  what lets `mix test`/`mix format` start it without invoking the CLI.
  """

  use Application

  alias Burrito.Util.Args

  @impl true
  def start(_type, _args) do
    {:ok, pid} = Supervisor.start_link([], strategy: :one_for_one, name: ExweaverCli.Supervisor)

    if Application.get_env(:exweaver_cli, :run_cli, false) do
      Args.argv()
      |> ExweaverCli.CLI.main()
    end

    {:ok, pid}
  end
end
