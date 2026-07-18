defmodule ExweaverCli.Commands.EndUsersSpec do
  use ESpec

  alias ExweaverCli.Client
  alias ExweaverCli.Commands.EndUsers
  alias ExweaverCli.Credentials
  alias ExweaverCli.Prompt

  defp login do
    Credentials.save(%Credentials{server: "https://flags.internal", token: "exw_t"})
  end

  describe "list/1" do
    context "when end users exist" do
      it "renders each identifier" do
        login()

        allow(Client)
        |> to(accept(:list, fn "/end_users", _opts -> {:ok, [%{"identifier" => "user-1"}]} end))

        {:ok, output} = EndUsers.list([])

        expect(output) |> to(match("user-1"))
      end
    end
  end

  describe "create/2" do
    context "when given an identifier" do
      it "posts it" do
        login()

        allow(Client)
        |> to(
          accept(:request, fn :post, "/end_users", opts ->
            Process.put(:posted, opts[:json])
            {:ok, %{"identifier" => "user-1"}}
          end)
        )

        EndUsers.create("user-1", [])

        expect(Process.get(:posted)) |> to(eq(%{identifier: "user-1"}))
      end
    end
  end

  describe "delete/2" do
    context "when --yes is passed" do
      it "deletes the end user without prompting" do
        login()

        allow(Client)
        |> to(
          accept(:list, fn "/end_users", _opts ->
            {:ok, [%{"identifier" => "user-1", "id" => "eu-1"}]}
          end)
        )

        allow(Client)
        |> to(accept(:request, fn :delete, "/end_users/eu-1", _opts -> {:ok, ""} end))

        expect(EndUsers.delete("user-1", yes: true)) |> to(eq({:ok, "Deleted end user user-1"}))
      end
    end

    context "when the user declines" do
      it "aborts" do
        login()

        allow(Client)
        |> to(
          accept(:list, fn "/end_users", _opts ->
            {:ok, [%{"identifier" => "user-1", "id" => "eu-1"}]}
          end)
        )

        allow(Prompt) |> to(accept(:confirm?, fn _question -> false end))

        expect(EndUsers.delete("user-1", [])) |> to(eq({:ok, "Aborted."}))
      end
    end
  end
end
