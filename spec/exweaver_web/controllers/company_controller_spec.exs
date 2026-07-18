defmodule ExweaverWeb.CompanyControllerSpec do
  use ESpec

  import Exweaver.Factory
  import Plug.Test
  import Plug.Conn

  alias Exweaver.Accounts.{Company, Role, Seeds}
  alias Exweaver.Flags
  alias Exweaver.Repo
  alias ExweaverWeb.CompanyController

  defp with_actor(conn, actor), do: assign(conn, :current_customer, actor)

  defp admin_actor do
    Seeds.run()
    admin_role = Repo.get_by(Role, name: "admin")
    insert(:customer, role: admin_role)
  end

  defp developer_actor do
    Seeds.run()
    developer_role = Repo.get_by(Role, name: "developer")
    insert(:customer, role: developer_role)
  end

  describe "create/2" do
    context "when the actor is an admin" do
      it "returns a 201" do
        actor = admin_actor()

        conn =
          conn(:post, "/")
          |> with_actor(actor)
          |> CompanyController.create(%{"name" => "Acme", "admin_email" => "admin@acme.example"})

        expect(conn.status) |> to(eq(201))
      end

      it "creates the company" do
        actor = admin_actor()

        CompanyController.create(
          conn(:post, "/") |> with_actor(actor),
          %{"name" => "Acme", "admin_email" => "admin@acme.example"}
        )

        expect(Repo.get_by(Company, name: "Acme")) |> to_not(be_nil())
      end

      it "seeds the company's default environments" do
        actor = admin_actor()

        CompanyController.create(
          conn(:post, "/") |> with_actor(actor),
          %{"name" => "Acme", "admin_email" => "admin@acme.example"}
        )

        company = Repo.get_by(Company, name: "Acme")

        expect(length(Flags.list_environments(company))) |> to(eq(2))
      end
    end

    context "when the actor is a developer" do
      it "returns a 403" do
        actor = developer_actor()

        conn =
          conn(:post, "/")
          |> with_actor(actor)
          |> CompanyController.create(%{"name" => "Acme", "admin_email" => "admin@acme.example"})

        expect(conn.status) |> to(eq(403))
      end
    end
  end
end
