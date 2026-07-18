defmodule ExweaverCli.CLI do
  @moduledoc """
  Command-line entrypoint and dispatcher.

  `run/1` is the testable core: it parses argv and returns
  `{:ok, output}` or `{:error, message, exit_code}` without touching stdout or
  halting. `main/1` is the real entrypoint used by the Burrito binary — it runs
  a command, prints the result, and halts with the exit code.

  Scaffolded in C13 (`config set-server`, usage banner); C14 adds auth, C15
  adds the flags/environments/end-users groups, and C16 adds the
  companies/customers/keys/roles groups.
  """

  alias ExweaverCli.Commands
  alias ExweaverCli.Config

  @usage_error 2

  @usage """
  exweaver — feature flag management CLI

  Usage:
    exweaver <command> [options]

  Commands:
    signup <email> [--expires 30d]                 Set your password, mint first token
    login <email> [--expires 30d]                  Mint a new personal token
    logout                                         Revoke the current token, forget it
    whoami                                         Show the authenticated customer

    flags list                                     List flags
    flags create <key> [--name --type]             Create a flag
    flags delete <key> [--yes]                     Delete a flag
    flags on|off <key> --env <env>                 Turn a flag on/off in an environment
    flags rollout <key> --env <env> --percentage N Percentage rollout
    flags assign <key> <id> --env <env> --state on|off   Per-user override
    flags unassign <key> <id> --env <env>          Remove a per-user override

    envs list|create <key>|delete <key>            Manage environments
    end-users list|create <id>|delete <id>         Manage end users

    companies create <name> --admin-email <email>  Create a company + admin
    customers list                                 List team members
    customers invite <email> --role <role>         Pre-approve a team member
    customers reset-password <email>               Clear a member's password
    customers remove <email> [--yes]               Remove a team member
    keys list                                      List access keys
    keys create <name> --env <env>                 Mint an sdk key (shown once)
    keys revoke <id> [--yes]                        Revoke an access key
    roles list                                     List roles

    config set-server <url>                         Set the API server URL

  Global options:
    --json                           Machine-readable JSON output
    --yes                            Skip confirmation prompts
    --help                           Show this help
  """

  @doc "Real entrypoint: run a command, print its result, and halt."
  @spec main([String.t()]) :: no_return()
  def main(argv) do
    case run(argv) do
      {:ok, ""} ->
        System.halt(0)

      {:ok, output} ->
        ExweaverCli.Output.puts(output)
        System.halt(0)

      {:error, message, exit_code} ->
        IO.puts(:stderr, "error: " <> message)
        System.halt(exit_code)
    end
  end

  @doc "Parse argv and run the command, returning a result without side effects on stdout."
  @spec run([String.t()]) :: {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def run(argv) do
    {opts, args, _invalid} =
      OptionParser.parse(argv,
        switches: [
          json: :boolean,
          help: :boolean,
          yes: :boolean,
          expires: :string,
          name: :string,
          type: :string,
          env: :string,
          state: :string,
          percentage: :integer,
          admin_email: :string,
          role: :string
        ]
      )

    if Keyword.get(opts, :help, false) do
      {:ok, String.trim_trailing(@usage)}
    else
      dispatch(args, opts)
    end
  end

  defp dispatch([], _opts), do: {:ok, String.trim_trailing(@usage)}

  defp dispatch(["signup", email], opts), do: Commands.Auth.signup(email, opts)

  defp dispatch(["signup" | _], _opts),
    do: {:error, "usage: exweaver signup <email>", @usage_error}

  defp dispatch(["login", email], opts), do: Commands.Auth.login(email, opts)
  defp dispatch(["login" | _], _opts), do: {:error, "usage: exweaver login <email>", @usage_error}

  defp dispatch(["logout"], opts), do: Commands.Auth.logout(opts)

  defp dispatch(["whoami"], opts), do: Commands.Auth.whoami(opts)

  defp dispatch(["flags", "list"], opts), do: Commands.Flags.list(opts)
  defp dispatch(["flags", "create", key], opts), do: Commands.Flags.create(key, opts)
  defp dispatch(["flags", "delete", key], opts), do: Commands.Flags.delete(key, opts)
  defp dispatch(["flags", "on", key], opts), do: Commands.Flags.set_state(key, "on", opts)
  defp dispatch(["flags", "off", key], opts), do: Commands.Flags.set_state(key, "off", opts)
  defp dispatch(["flags", "rollout", key], opts), do: Commands.Flags.rollout(key, opts)

  defp dispatch(["flags", "assign", key, identifier], opts),
    do: Commands.Flags.assign(key, identifier, opts)

  defp dispatch(["flags", "unassign", key, identifier], opts),
    do: Commands.Flags.unassign(key, identifier, opts)

  defp dispatch(["flags" | _], _opts),
    do:
      {:error, "usage: exweaver flags <list|create|delete|on|off|rollout|assign|unassign>",
       @usage_error}

  defp dispatch(["envs", "list"], opts), do: Commands.Environments.list(opts)
  defp dispatch(["envs", "create", key], opts), do: Commands.Environments.create(key, opts)
  defp dispatch(["envs", "delete", key], opts), do: Commands.Environments.delete(key, opts)

  defp dispatch(["envs" | _], _opts),
    do: {:error, "usage: exweaver envs <list|create <key>|delete <key>>", @usage_error}

  defp dispatch(["end-users", "list"], opts), do: Commands.EndUsers.list(opts)

  defp dispatch(["end-users", "create", identifier], opts),
    do: Commands.EndUsers.create(identifier, opts)

  defp dispatch(["end-users", "delete", identifier], opts),
    do: Commands.EndUsers.delete(identifier, opts)

  defp dispatch(["end-users" | _], _opts),
    do: {:error, "usage: exweaver end-users <list|create <id>|delete <id>>", @usage_error}

  defp dispatch(["companies", "create", name], opts), do: Commands.Companies.create(name, opts)

  defp dispatch(["companies" | _], _opts),
    do: {:error, "usage: exweaver companies create <name> --admin-email <email>", @usage_error}

  defp dispatch(["customers", "list"], opts), do: Commands.Customers.list(opts)
  defp dispatch(["customers", "invite", email], opts), do: Commands.Customers.invite(email, opts)

  defp dispatch(["customers", "reset-password", email], opts),
    do: Commands.Customers.reset_password(email, opts)

  defp dispatch(["customers", "remove", email], opts), do: Commands.Customers.remove(email, opts)

  defp dispatch(["customers" | _], _opts),
    do:
      {:error,
       "usage: exweaver customers <list|invite <email>|reset-password <email>|remove <email>>",
       @usage_error}

  defp dispatch(["keys", "list"], opts), do: Commands.Keys.list(opts)
  defp dispatch(["keys", "create", name], opts), do: Commands.Keys.create(name, opts)
  defp dispatch(["keys", "revoke", id], opts), do: Commands.Keys.revoke(id, opts)

  defp dispatch(["keys" | _], _opts),
    do:
      {:error, "usage: exweaver keys <list|create <name> --env <env>|revoke <id>>", @usage_error}

  defp dispatch(["roles", "list"], opts), do: Commands.Roles.list(opts)

  defp dispatch(["roles" | _], _opts),
    do: {:error, "usage: exweaver roles list", @usage_error}

  defp dispatch(["config", "set-server", url], _opts), do: config_set_server(url)

  defp dispatch(["config", "set-server"], _opts) do
    {:error, "usage: exweaver config set-server <url>", @usage_error}
  end

  defp dispatch(["config" | rest], _opts) do
    {:error, "unknown config subcommand: #{Enum.join(rest, " ")}", @usage_error}
  end

  defp dispatch([command | _], _opts) do
    {:error, "unknown command: #{command}", @usage_error}
  end

  defp config_set_server(url) do
    case Config.set_server(url) do
      {:ok, url} ->
        {:ok, "Server set to #{url}"}

      {:error, :invalid_server} ->
        {:error, "invalid server URL: #{url} (expected e.g. https://flags.internal)",
         @usage_error}
    end
  end
end
