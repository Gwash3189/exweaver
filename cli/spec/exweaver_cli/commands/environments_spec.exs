defmodule ExweaverCli.Commands.EnvironmentsSpec do
  use ESpec

  alias ExweaverCli.Client
  alias ExweaverCli.Commands.Environments
  alias ExweaverCli.Credentials
  alias ExweaverCli.Prompt

  defp login do
    Credentials.save(%Credentials{server: "https://flags.internal", token: "exw_t"})
  end

  describe "list/1" do
    context "when environments exist" do
      it "renders each environment's key" do
        login()

        allow(Client)
        |> to(
          accept(:list, fn "/environments", _opts ->
            {:ok, [%{"key" => "production", "name" => "Production"}]}
          end)
        )

        {:ok, output} = Environments.list([])

        expect(output) |> to(match("production"))
      end
    end
  end

  describe "create/2" do
    context "when name is omitted" do
      it "defaults the name to the key" do
        login()

        allow(Client)
        |> to(
          accept(:request, fn :post, "/environments", opts ->
            Process.put(:posted, opts[:json])
            {:ok, %{"key" => "staging"}}
          end)
        )

        Environments.create("staging", [])

        expect(Process.get(:posted)) |> to(eq(%{key: "staging", name: "staging"}))
      end
    end
  end

  describe "delete/2" do
    context "when the user confirms" do
      it "deletes the environment" do
        login()

        allow(Client)
        |> to(
          accept(:list, fn "/environments", _opts ->
            {:ok, [%{"key" => "staging", "id" => "env-9"}]}
          end)
        )

        allow(Prompt) |> to(accept(:confirm?, fn _question -> true end))

        allow(Client)
        |> to(accept(:request, fn :delete, "/environments/env-9", _opts -> {:ok, ""} end))

        expect(Environments.delete("staging", [])) |> to(eq({:ok, "Deleted environment staging"}))
      end
    end
  end
end
