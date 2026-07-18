defmodule Exweaver.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        ExweaverWeb.Telemetry,
        Exweaver.Repo,
        {Ecto.Migrator,
         repos: Application.fetch_env!(:exweaver, :ecto_repos), skip: skip_migrations?()}
      ] ++
        bootstrap_children() ++
        [
          {DNSCluster, query: Application.get_env(:exweaver, :dns_cluster_query) || :ignore},
          {Phoenix.PubSub, name: Exweaver.PubSub},
          Exweaver.Auth.RateLimiter,
          # Start a worker by calling: Exweaver.Worker.start_link(arg)
          # {Exweaver.Worker, arg},
          # Start to serve requests, typically the last entry
          ExweaverWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Exweaver.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ExweaverWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations? do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end

  # Disabled in :test (config/test.exs) — Bootstrap writes outside the ESpec
  # sandbox transaction if it runs during Application boot.
  defp bootstrap_children do
    if Application.get_env(:exweaver, :run_bootstrap, true) do
      [Exweaver.Bootstrap]
    else
      []
    end
  end
end
