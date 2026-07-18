defmodule ExweaverCli.Commands.FlagsSpec do
  use ESpec

  alias ExweaverCli.Client
  alias ExweaverCli.Commands.Flags
  alias ExweaverCli.Credentials
  alias ExweaverCli.Prompt

  # Common.session/0 reads server + token from the credentials file; every
  # example that reaches the API needs a logged-in session on disk.
  defp login do
    Credentials.save(%Credentials{server: "https://flags.internal", token: "exw_t"})
  end

  defp stub_flag_lookup do
    allow(Client)
    |> to(accept(:list, fn "/flags", _opts -> {:ok, [%{"key" => "beta", "id" => "flag-1"}]} end))
  end

  # A single `:list` stub covering every collection a command resolves against.
  # meck replaces the whole function per `accept`, so all paths must be in one.
  defp stub_lookups do
    allow(Client)
    |> to(
      accept(:list, fn
        "/flags", _opts -> {:ok, [%{"key" => "beta", "id" => "flag-1"}]}
        "/environments", _opts -> {:ok, [%{"key" => "production", "id" => "env-1"}]}
        "/end_users", _opts -> {:ok, [%{"identifier" => "user-1", "id" => "eu-1"}]}
      end)
    )
  end

  describe "list/1" do
    context "when flags exist" do
      it "renders each flag's key" do
        login()

        allow(Client)
        |> to(
          accept(:list, fn "/flags", _opts ->
            {:ok, [%{"key" => "beta", "name" => "Beta", "type" => "boolean"}]}
          end)
        )

        {:ok, output} = Flags.list([])

        expect(output) |> to(match("beta"))
      end
    end

    context "when not logged in" do
      it "returns a not-logged-in error" do
        expect(Flags.list([])) |> to(match_pattern({:error, _, 1}))
      end
    end
  end

  describe "create/2" do
    context "when name and type are omitted" do
      it "defaults name to the key and type to boolean" do
        login()

        allow(Client)
        |> to(
          accept(:request, fn :post, "/flags", opts ->
            Process.put(:posted, opts[:json])
            {:ok, %{"key" => "beta"}}
          end)
        )

        Flags.create("beta", [])

        expect(Process.get(:posted)) |> to(eq(%{key: "beta", name: "beta", type: "boolean"}))
      end
    end

    context "when name and type are given" do
      it "forwards them" do
        login()

        allow(Client)
        |> to(
          accept(:request, fn :post, "/flags", opts ->
            Process.put(:posted, opts[:json])
            {:ok, %{"key" => "beta"}}
          end)
        )

        Flags.create("beta", name: "Beta flag", type: "percentage")

        expect(Process.get(:posted))
        |> to(eq(%{key: "beta", name: "Beta flag", type: "percentage"}))
      end
    end
  end

  describe "delete/2" do
    context "when the user confirms" do
      it "deletes the flag" do
        login()
        stub_flag_lookup()
        allow(Prompt) |> to(accept(:confirm?, fn _question -> true end))
        allow(Client) |> to(accept(:request, fn :delete, "/flags/flag-1", _opts -> {:ok, ""} end))

        expect(Flags.delete("beta", [])) |> to(eq({:ok, "Deleted flag beta"}))
      end
    end

    context "when the user declines" do
      it "aborts without calling delete" do
        login()
        stub_flag_lookup()
        allow(Prompt) |> to(accept(:confirm?, fn _question -> false end))

        expect(Flags.delete("beta", [])) |> to(eq({:ok, "Aborted."}))
      end
    end

    context "when --yes is passed" do
      it "deletes without prompting" do
        login()
        stub_flag_lookup()
        allow(Client) |> to(accept(:request, fn :delete, "/flags/flag-1", _opts -> {:ok, ""} end))

        expect(Flags.delete("beta", yes: true)) |> to(eq({:ok, "Deleted flag beta"}))
      end
    end

    context "when the flag key is unknown" do
      it "returns a not-found error" do
        login()
        allow(Client) |> to(accept(:list, fn "/flags", _opts -> {:ok, []} end))

        expect(Flags.delete("ghost", yes: true)) |> to(match_pattern({:error, _, 1}))
      end
    end
  end

  describe "set_state/3" do
    context "when --env is given" do
      it "puts the new state and confirms it" do
        login()
        stub_lookups()

        allow(Client)
        |> to(
          accept(:request, fn :put, "/flags/flag-1/environments/env-1/state", opts ->
            Process.put(:put_body, opts[:json])
            {:ok, %{"state" => "on"}}
          end)
        )

        {:ok, output} = Flags.set_state("beta", "on", env: "production")

        expect(output) |> to(eq("Set flag beta to on in production"))
      end
    end

    context "when --env is missing" do
      it "returns an env-required error" do
        login()

        expect(Flags.set_state("beta", "on", [])) |> to(match_pattern({:error, _, 1}))
      end
    end
  end

  describe "rollout/2" do
    context "when --percentage and --env are given" do
      it "puts an on state with the percentage" do
        login()
        stub_lookups()

        allow(Client)
        |> to(
          accept(:request, fn :put, "/flags/flag-1/environments/env-1/state", opts ->
            Process.put(:put_body, opts[:json])
            {:ok, %{"state" => "on", "percentage" => 25}}
          end)
        )

        Flags.rollout("beta", env: "production", percentage: 25)

        expect(Process.get(:put_body)) |> to(eq(%{state: "on", percentage: 25}))
      end
    end

    context "when --percentage is missing" do
      it "returns a percentage-required error" do
        login()

        expect(Flags.rollout("beta", env: "production")) |> to(match_pattern({:error, _, 1}))
      end
    end

    context "when --percentage is out of range" do
      it "returns an invalid-percentage error" do
        login()

        expect(Flags.rollout("beta", env: "production", percentage: 150))
        |> to(match_pattern({:error, _, 1}))
      end
    end
  end

  describe "assign/3" do
    context "when --state on is given" do
      it "puts a true assignment for the resolved end user" do
        login()
        stub_lookups()

        allow(Client)
        |> to(
          accept(:request, fn :put, "/flags/flag-1/environments/env-1/assignments/eu-1", opts ->
            Process.put(:put_body, opts[:json])
            {:ok, %{"state" => true}}
          end)
        )

        Flags.assign("beta", "user-1", env: "production", state: "on")

        expect(Process.get(:put_body)) |> to(eq(%{state: true}))
      end
    end

    context "when --state is missing" do
      it "returns a state-required error" do
        login()

        expect(Flags.assign("beta", "user-1", env: "production"))
        |> to(match_pattern({:error, _, 1}))
      end
    end
  end

  describe "unassign/3" do
    context "when the assignment exists" do
      it "deletes it and confirms" do
        login()
        stub_lookups()

        allow(Client)
        |> to(
          accept(:request, fn :delete,
                              "/flags/flag-1/environments/env-1/assignments/eu-1",
                              _opts ->
            {:ok, ""}
          end)
        )

        {:ok, output} = Flags.unassign("beta", "user-1", env: "production")

        expect(output) |> to(eq("Unassigned flag beta from user-1 in production"))
      end
    end
  end
end
