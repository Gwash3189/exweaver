defmodule ExweaverCli.Commands.KeysSpec do
  use ESpec

  alias ExweaverCli.Client
  alias ExweaverCli.Commands.Keys
  alias ExweaverCli.Credentials
  alias ExweaverCli.Prompt

  defp login do
    Credentials.save(%Credentials{server: "https://flags.internal", token: "exw_t"})
  end

  describe "list/1" do
    context "when keys exist" do
      it "renders each key's name" do
        login()

        allow(Client)
        |> to(
          accept(:list, fn "/access_keys", _opts ->
            {:ok, [%{"id" => "key-1", "name" => "ci", "kind" => "sdk"}]}
          end)
        )

        {:ok, output} = Keys.list([])

        expect(output) |> to(match("ci"))
      end

      it "does not render any token value" do
        login()

        allow(Client)
        |> to(
          accept(:list, fn "/access_keys", _opts ->
            {:ok, [%{"id" => "key-1", "name" => "ci", "kind" => "sdk", "token" => nil}]}
          end)
        )

        {:ok, output} = Keys.list([])

        expect(output) |> to_not(match("token"))
      end
    end
  end

  describe "create/2" do
    context "when name and --env are given" do
      it "resolves the environment and posts an sdk key" do
        login()

        allow(Client)
        |> to(
          accept(:list, fn "/environments", _opts ->
            {:ok, [%{"key" => "production", "id" => "env-1"}]}
          end)
        )

        allow(Client)
        |> to(
          accept(:request, fn :post, "/access_keys", opts ->
            Process.put(:posted, opts[:json])
            {:ok, %{"id" => "key-1", "name" => "ci", "token" => "exw_secret"}}
          end)
        )

        Keys.create("ci", env: "production")

        expect(Process.get(:posted))
        |> to(eq(%{name: "ci", kind: "sdk", environment_id: "env-1"}))
      end

      it "shows the plaintext token once" do
        login()

        allow(Client)
        |> to(
          accept(:list, fn "/environments", _opts ->
            {:ok, [%{"key" => "production", "id" => "env-1"}]}
          end)
        )

        allow(Client)
        |> to(
          accept(:request, fn :post, "/access_keys", _opts ->
            {:ok, %{"id" => "key-1", "name" => "ci", "token" => "exw_secret"}}
          end)
        )

        {:ok, output} = Keys.create("ci", env: "production")

        expect(output) |> to(match("exw_secret"))
      end
    end

    context "when --env is missing" do
      it "returns a precondition error without calling the API" do
        login()

        expect(Keys.create("ci", [])) |> to(match_pattern({:error, _, 1}))
      end
    end
  end

  describe "revoke/2" do
    context "when --yes is passed" do
      it "revokes the key by id without prompting" do
        login()

        allow(Client)
        |> to(accept(:request, fn :delete, "/access_keys/key-1", _opts -> {:ok, ""} end))

        expect(Keys.revoke("key-1", yes: true)) |> to(eq({:ok, "Revoked key key-1"}))
      end
    end

    context "when the user declines" do
      it "aborts without deleting" do
        login()

        allow(Prompt) |> to(accept(:confirm?, fn _question -> false end))

        expect(Keys.revoke("key-1", [])) |> to(eq({:ok, "Aborted."}))
      end
    end
  end
end
