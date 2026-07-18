defmodule ExweaverCli.CLISpec do
  use ESpec

  alias ExweaverCli.CLI
  alias ExweaverCli.Credentials

  describe "run/1" do
    context "when given `config set-server <url>`" do
      it "returns an ok result confirming the server" do
        expect(CLI.run(["config", "set-server", "https://flags.internal"]))
        |> to(match_pattern({:ok, _}))
      end

      it "persists the server to the credentials file" do
        CLI.run(["config", "set-server", "https://flags.internal"])

        expect(Credentials.load().server) |> to(eq("https://flags.internal"))
      end

      it "confirms the configured server in its output" do
        {:ok, output} = CLI.run(["config", "set-server", "https://flags.internal"])

        expect(output) |> to(match("https://flags.internal"))
      end
    end

    context "when `config set-server` is given an invalid URL" do
      it "returns a usage-level error with exit code 2" do
        expect(CLI.run(["config", "set-server", "not-a-url"]))
        |> to(match_pattern({:error, _, 2}))
      end
    end

    context "when `config set-server` is missing its argument" do
      it "returns a usage-level error with exit code 2" do
        expect(CLI.run(["config", "set-server"])) |> to(match_pattern({:error, _, 2}))
      end
    end

    context "when given no arguments" do
      it "returns usage text" do
        expect(CLI.run([])) |> to(match_pattern({:ok, _}))
      end
    end

    context "when given --help" do
      it "returns usage text mentioning the config command" do
        {:ok, output} = CLI.run(["--help"])

        expect(output) |> to(match("config set-server"))
      end
    end

    context "when given an unknown command" do
      it "returns a usage-level error with exit code 2" do
        expect(CLI.run(["frobnicate"])) |> to(match_pattern({:error, _, 2}))
      end
    end

    context "when given `login <email>`" do
      it "routes to the auth login command with the email" do
        allow(ExweaverCli.Commands.Auth)
        |> to(accept(:login, fn email, _opts -> {:ok, "routed:#{email}"} end))

        expect(CLI.run(["login", "dev@example.com"])) |> to(eq({:ok, "routed:dev@example.com"}))
      end

      it "passes --expires through as an option" do
        allow(ExweaverCli.Commands.Auth)
        |> to(accept(:login, fn _email, opts -> {:ok, "expires:#{opts[:expires]}"} end))

        expect(CLI.run(["login", "dev@example.com", "--expires", "7d"]))
        |> to(eq({:ok, "expires:7d"}))
      end
    end

    context "when `signup` is missing its email" do
      it "returns a usage-level error with exit code 2" do
        expect(CLI.run(["signup"])) |> to(match_pattern({:error, _, 2}))
      end
    end

    context "when `login` is missing its email" do
      it "returns a usage-level error with exit code 2" do
        expect(CLI.run(["login"])) |> to(match_pattern({:error, _, 2}))
      end
    end

    context "when given `flags on <key> --env <env>`" do
      it "routes to set_state with the key, state, and env option" do
        allow(ExweaverCli.Commands.Flags)
        |> to(
          accept(:set_state, fn key, state, opts -> {:ok, "#{key}:#{state}:#{opts[:env]}"} end)
        )

        expect(CLI.run(["flags", "on", "beta", "--env", "production"]))
        |> to(eq({:ok, "beta:on:production"}))
      end
    end

    context "when given `flags rollout` with a percentage" do
      it "parses --percentage as an integer" do
        allow(ExweaverCli.Commands.Flags)
        |> to(accept(:rollout, fn _key, opts -> {:ok, "pct:#{inspect(opts[:percentage])}"} end))

        expect(CLI.run(["flags", "rollout", "beta", "--env", "production", "--percentage", "25"]))
        |> to(eq({:ok, "pct:25"}))
      end
    end

    context "when given `flags assign <key> <id>`" do
      it "routes both positional arguments" do
        allow(ExweaverCli.Commands.Flags)
        |> to(accept(:assign, fn key, id, _opts -> {:ok, "#{key}/#{id}"} end))

        expect(CLI.run(["flags", "assign", "beta", "user-1", "--env", "prod", "--state", "on"]))
        |> to(eq({:ok, "beta/user-1"}))
      end
    end

    context "when given `envs list`" do
      it "routes to the environments list command" do
        allow(ExweaverCli.Commands.Environments)
        |> to(accept(:list, fn _opts -> {:ok, "envs"} end))

        expect(CLI.run(["envs", "list"])) |> to(eq({:ok, "envs"}))
      end
    end

    context "when given `end-users create <id>`" do
      it "routes to the end-users create command" do
        allow(ExweaverCli.Commands.EndUsers)
        |> to(accept(:create, fn id, _opts -> {:ok, "created:#{id}"} end))

        expect(CLI.run(["end-users", "create", "user-1"])) |> to(eq({:ok, "created:user-1"}))
      end
    end

    context "when given an unknown flags subcommand" do
      it "returns a usage-level error with exit code 2" do
        expect(CLI.run(["flags", "frobnicate"])) |> to(match_pattern({:error, _, 2}))
      end
    end

    context "when given `companies create <name> --admin-email <email>`" do
      it "routes name and the admin-email option" do
        allow(ExweaverCli.Commands.Companies)
        |> to(accept(:create, fn name, opts -> {:ok, "#{name}:#{opts[:admin_email]}"} end))

        expect(CLI.run(["companies", "create", "Acme", "--admin-email", "boss@acme.com"]))
        |> to(eq({:ok, "Acme:boss@acme.com"}))
      end
    end

    context "when given `customers invite <email> --role <role>`" do
      it "routes the email and role option" do
        allow(ExweaverCli.Commands.Customers)
        |> to(accept(:invite, fn email, opts -> {:ok, "#{email}:#{opts[:role]}"} end))

        expect(CLI.run(["customers", "invite", "dev@example.com", "--role", "developer"]))
        |> to(eq({:ok, "dev@example.com:developer"}))
      end
    end

    context "when given `customers reset-password <email>`" do
      it "routes to the reset_password command" do
        allow(ExweaverCli.Commands.Customers)
        |> to(accept(:reset_password, fn email, _opts -> {:ok, "reset:#{email}"} end))

        expect(CLI.run(["customers", "reset-password", "dev@example.com"]))
        |> to(eq({:ok, "reset:dev@example.com"}))
      end
    end

    context "when given `customers remove <email>`" do
      it "routes to the remove command" do
        allow(ExweaverCli.Commands.Customers)
        |> to(accept(:remove, fn email, _opts -> {:ok, "removed:#{email}"} end))

        expect(CLI.run(["customers", "remove", "dev@example.com"]))
        |> to(eq({:ok, "removed:dev@example.com"}))
      end
    end

    context "when given an unknown customers subcommand" do
      it "returns a usage-level error with exit code 2" do
        expect(CLI.run(["customers", "frobnicate"])) |> to(match_pattern({:error, _, 2}))
      end
    end

    context "when given `keys create <name> --env <env>`" do
      it "routes the name and env option" do
        allow(ExweaverCli.Commands.Keys)
        |> to(accept(:create, fn name, opts -> {:ok, "#{name}:#{opts[:env]}"} end))

        expect(CLI.run(["keys", "create", "ci", "--env", "production"]))
        |> to(eq({:ok, "ci:production"}))
      end
    end

    context "when given `keys revoke <id>`" do
      it "routes the id to the revoke command" do
        allow(ExweaverCli.Commands.Keys)
        |> to(accept(:revoke, fn id, _opts -> {:ok, "revoked:#{id}"} end))

        expect(CLI.run(["keys", "revoke", "key-1"])) |> to(eq({:ok, "revoked:key-1"}))
      end
    end

    context "when given `roles list`" do
      it "routes to the roles list command" do
        allow(ExweaverCli.Commands.Roles)
        |> to(accept(:list, fn _opts -> {:ok, "roles"} end))

        expect(CLI.run(["roles", "list"])) |> to(eq({:ok, "roles"}))
      end
    end

    context "when given `companies` with no subcommand" do
      it "returns a usage-level error with exit code 2" do
        expect(CLI.run(["companies"])) |> to(match_pattern({:error, _, 2}))
      end
    end
  end
end
