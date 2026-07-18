defmodule ExweaverWeb.EndUserControllerSpec do
  use ESpec

  import Exweaver.Factory
  import Plug.Test
  import Plug.Conn

  alias Exweaver.Flags.EndUser
  alias Exweaver.Repo
  alias ExweaverWeb.EndUserController

  defp with_actor(conn, actor), do: assign(conn, :current_customer, actor)

  defp json(conn), do: Jason.decode!(conn.resp_body)

  describe "index/2" do
    it "returns only end_users belonging to the actor's company" do
      actor = insert(:customer)
      insert(:end_user, company: actor.company)
      insert(:end_user)

      conn = conn(:get, "/") |> with_actor(actor) |> EndUserController.index(%{})

      expect(length(json(conn)["data"])) |> to(eq(1))
    end

    context "when an identifier filter is given" do
      it "returns only the matching end_user" do
        actor = insert(:customer)
        insert(:end_user, company: actor.company, identifier: "user-a")
        insert(:end_user, company: actor.company, identifier: "user-b")

        conn =
          conn(:get, "/") |> with_actor(actor) |> EndUserController.index(%{"identifier" => "user-a"})

        [rendered] = json(conn)["data"]
        expect(rendered["identifier"]) |> to(eq("user-a"))
      end
    end
  end

  describe "create/2" do
    context "when the identifier is valid" do
      it "returns a 201" do
        actor = insert(:customer)

        conn =
          conn(:post, "/") |> with_actor(actor) |> EndUserController.create(%{"identifier" => "user-123"})

        expect(conn.status) |> to(eq(201))
      end

      it "creates the end_user scoped to the actor's company" do
        actor = insert(:customer)

        EndUserController.create(
          conn(:post, "/") |> with_actor(actor),
          %{"identifier" => "user-123"}
        )

        end_user = Repo.get_by(EndUser, identifier: "user-123")

        expect(end_user.company_id) |> to(eq(actor.company_id))
      end
    end

    context "when the identifier is already taken in the company" do
      it "returns a 422" do
        actor = insert(:customer)
        insert(:end_user, company: actor.company, identifier: "user-123")

        conn =
          conn(:post, "/") |> with_actor(actor) |> EndUserController.create(%{"identifier" => "user-123"})

        expect(conn.status) |> to(eq(422))
      end
    end
  end

  describe "delete/2" do
    context "when the end_user belongs to the actor's company" do
      it "returns a 204" do
        actor = insert(:customer)
        end_user = insert(:end_user, company: actor.company)

        conn = conn(:delete, "/") |> with_actor(actor) |> EndUserController.delete(%{"id" => end_user.id})

        expect(conn.status) |> to(eq(204))
      end
    end

    context "when the end_user belongs to a different company" do
      it "returns a 404" do
        actor = insert(:customer)
        other_end_user = insert(:end_user)

        conn =
          conn(:delete, "/")
          |> with_actor(actor)
          |> EndUserController.delete(%{"id" => other_end_user.id})

        expect(conn.status) |> to(eq(404))
      end
    end
  end
end
