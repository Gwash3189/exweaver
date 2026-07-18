defmodule ExweaverWeb.RoleControllerSpec do
  use ESpec

  import Plug.Test
  import Plug.Conn

  alias Exweaver.Accounts.Seeds
  alias ExweaverWeb.RoleController

  defp with_actor(conn, actor), do: assign(conn, :current_customer, actor)

  defp json(conn), do: Jason.decode!(conn.resp_body)

  defp actor_with_seeded_role do
    Seeds.run()
    admin_role = Exweaver.Repo.get_by(Exweaver.Accounts.Role, name: "admin")
    Exweaver.Factory.insert(:customer, role: admin_role)
  end

  describe "index/2" do
    it "returns the seeded roles" do
      actor = actor_with_seeded_role()

      conn = conn(:get, "/") |> with_actor(actor) |> RoleController.index(%{})

      expect(length(json(conn)["data"])) |> to(eq(4))
    end

    it "renders each role's id and name" do
      actor = actor_with_seeded_role()

      conn = conn(:get, "/") |> with_actor(actor) |> RoleController.index(%{})

      names = json(conn)["data"] |> Enum.map(& &1["name"]) |> Enum.sort()
      expect(names) |> to(eq(["admin", "automated", "developer", "read-only"]))
    end
  end
end
