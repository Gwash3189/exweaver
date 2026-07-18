defmodule ExweaverCli.Commands.RolesSpec do
  use ESpec

  alias ExweaverCli.Client
  alias ExweaverCli.Commands.Roles
  alias ExweaverCli.Credentials

  defp login do
    Credentials.save(%Credentials{server: "https://flags.internal", token: "exw_t"})
  end

  describe "list/1" do
    context "when roles exist" do
      it "renders each role's name" do
        login()

        allow(Client)
        |> to(
          accept(:list, fn "/roles", _opts ->
            {:ok, [%{"id" => "role-1", "name" => "developer"}]}
          end)
        )

        {:ok, output} = Roles.list([])

        expect(output) |> to(match("developer"))
      end
    end

    context "when not logged in" do
      it "returns a not-logged-in error" do
        expect(Roles.list([])) |> to(match_pattern({:error, _, 1}))
      end
    end
  end
end
