defmodule ExweaverCli.MixProject do
  use Mix.Project

  def project do
    [
      app: :exweaver_cli,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: releases()
    ]
  end

  # The CLI is a standalone escript-like OTP app. `ExweaverCli.Application`
  # only dispatches to `ExweaverCli.CLI.main/1` when packaged as the release
  # binary (see `config/runtime.exs`), so `mix test`/`mix format` can start the
  # app without invoking the command line.
  def application do
    [
      extra_applications: [:logger],
      mod: {ExweaverCli.Application, []}
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test, espec: :test, test: :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "spec/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      # Burrito packages the CLI as a standalone binary (D22). Build-only —
      # never needed at runtime once the binary is assembled.
      {:burrito, "~> 1.3", runtime: false},
      {:espec, "~> 1.9", only: :test},
      # `Req.Test`'s in-process stub adapter (`plug: {Req.Test, …}`) needs Plug.
      {:plug, "~> 1.16", only: :test},
      # A real HTTP server for the one end-to-end integration spec (card C14).
      {:bandit, "~> 1.5", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      # `mix test` is aliased to `mix espec` so the working-agreement command
      # still works (mirrors the server project).
      test: ["espec"],
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format",
        "credo --strict",
        "test"
      ]
    ]
  end

  # Burrito standalone binary targets (D22): macOS + Linux, arm64 + x86_64.
  defp releases do
    [
      exweaver: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            macos_arm: [os: :darwin, cpu: :aarch64],
            macos_x86: [os: :darwin, cpu: :x86_64],
            linux_arm: [os: :linux, cpu: :aarch64],
            linux_x86: [os: :linux, cpu: :x86_64]
          ]
        ]
      ]
    ]
  end
end
