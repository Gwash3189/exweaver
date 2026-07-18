defmodule ExweaverWeb.CustomerControllerSpec do
  use ESpec

  import Exweaver.Factory
  import Plug.Test
  import Plug.Conn

  alias Exweaver.Accounts.{Role, Seeds}
  alias Exweaver.Repo
  alias ExweaverWeb.CustomerController

  defp with_actor(conn, actor), do: assign(conn, :current_customer, actor)

  defp json(conn), do: Jason.decode!(conn.resp_body)

  defp admin_actor do
    Seeds.run()
    admin_role = Repo.get_by(Role, name: "admin")
    insert(:customer, role: admin_role)
  end

  describe "index/2" do
    it "returns only customers in the actor's company" do
      actor = insert(:customer)
      insert(:customer, company: actor.company)
      insert(:customer)

      conn = conn(:get, "/") |> with_actor(actor) |> CustomerController.index(%{})

      expect(length(json(conn)["data"])) |> to(eq(2))
    end

    it "marks a customer with no password as pending" do
      actor = insert(:customer)
      insert(:customer, company: actor.company, hashed_password: nil)

      conn = conn(:get, "/") |> with_actor(actor) |> CustomerController.index(%{})

      statuses = Enum.map(json(conn)["data"], & &1["status"])
      expect("pending" in statuses) |> to(be_true())
    end

    it "never renders a hashed_password field" do
      actor = insert(:customer)

      conn = conn(:get, "/") |> with_actor(actor) |> CustomerController.index(%{})

      [rendered] = json(conn)["data"]
      expect(Map.has_key?(rendered, "hashed_password")) |> to(be_false())
    end
  end

  # Method-permission RBAC (POST→:create) is enforced by the Authorize plug
  # (D28/D29), covered in ExweaverWeb.Plugs.AuthorizeSpec. Controllers run below
  # the plug and trust it ran, so no in-controller RBAC case here.
  describe "create/2" do
    context "when the attrs are valid" do
      it "returns a 201" do
        actor = insert(:customer)
        role_to_assign = insert(:role)

        conn =
          conn(:post, "/")
          |> with_actor(actor)
          |> CustomerController.create(%{"email" => "dev@example.com", "role_id" => role_to_assign.id})

        expect(conn.status) |> to(eq(201))
      end
    end
  end

  describe "update/2" do
    context "when the customer belongs to the actor's company" do
      it "updates the role" do
        actor = insert(:customer)
        new_role = insert(:role)
        target = insert(:customer, company: actor.company)

        conn =
          conn(:patch, "/")
          |> with_actor(actor)
          |> CustomerController.update(%{"id" => target.id, "role_id" => new_role.id})

        expect(json(conn)["role_id"]) |> to(eq(new_role.id))
      end
    end

    context "when the customer belongs to a different company" do
      it "returns a 404" do
        actor = insert(:customer)
        other_customer = insert(:customer)

        conn =
          conn(:patch, "/")
          |> with_actor(actor)
          |> CustomerController.update(%{"id" => other_customer.id, "role_id" => actor.role_id})

        expect(conn.status) |> to(eq(404))
      end
    end
  end

  describe "reset/2" do
    context "when the actor is an admin" do
      it "clears the customer's password and returns a 200" do
        actor = admin_actor()
        target = insert(:customer, company: actor.company, hashed_password: "hash")

        conn = conn(:post, "/") |> with_actor(actor) |> CustomerController.reset(%{"id" => target.id})

        expect(conn.status) |> to(eq(200))
      end
    end

    context "when the actor is not an admin" do
      it "returns a 403" do
        actor = insert(:customer)
        target = insert(:customer, company: actor.company)

        conn = conn(:post, "/") |> with_actor(actor) |> CustomerController.reset(%{"id" => target.id})

        expect(conn.status) |> to(eq(403))
      end
    end
  end

  describe "delete/2" do
    context "when the customer belongs to the actor's company" do
      it "returns a 204" do
        actor = insert(:customer)
        target = insert(:customer, company: actor.company)

        conn = conn(:delete, "/") |> with_actor(actor) |> CustomerController.delete(%{"id" => target.id})

        expect(conn.status) |> to(eq(204))
      end
    end

    context "when the customer belongs to a different company" do
      it "returns a 404" do
        actor = insert(:customer)
        other_customer = insert(:customer)

        conn =
          conn(:delete, "/")
          |> with_actor(actor)
          |> CustomerController.delete(%{"id" => other_customer.id})

        expect(conn.status) |> to(eq(404))
      end
    end
  end
end
